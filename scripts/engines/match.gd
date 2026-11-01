# Match: the target is shown at the top, the kid taps the choice that matches
# it. The key is a picture, a color (a sticker dot) or a number (a big digit on
# the choice, the only text allowed). A wrong pick wiggles; the right one hops,
# and after the last round the segment is done. Rounds let the kid find several
# things in a row (shells, clouds). Layouts: a row, a grid, free positions, or
# "doors": a hallway wider than the screen that the kid drags to scroll.
extends EngineBase

## How long a found choice takes to fly to the target before the next round.
const FOUND_TIME := 0.45
const LABEL_COLOR := Color.WHITE
const LABEL_OUTLINE := Color("#263444")

## The choices' nodes by id.
var choice_nodes := {}
## Index into the rounds.
var round_index := 0
var misses := 0

var _choices: Array[Dictionary] = []
var _rounds: Array[Dictionary] = []
var _found := {}
var _strip: Node2D
var _target: Node2D
var _scroll := 0.0
var _scroll_start := 0.0
var _press_at := Vector2.ZERO
var _pressed_choice := ""
var _between := false


func _defaults() -> Dictionary:
	return {
		"key": "picture",
		"layout": "row",
		"choice_height": 220.0,
		"row_y": 560.0,
		"columns": 3,
		"grid_rect": [200, 300, 1272, 560],
		"door_spacing": 420.0,
		"target_pos": [836, 150],
		"target_height": 200.0,
		"right_line": "found",
		"wrong_line": "",
		"right_sound": "tag-snap",
		"helper_feet": [1480, 930],
		"round_delay": 0.6,
	}


func _build() -> void:
	for c: Variant in data.get("choices", []):
		if c is Dictionary:
			_choices.append(c as Dictionary)
	var rounds: Variant = data.get("rounds", null)
	if rounds is Array:
		for r: Variant in rounds:
			_rounds.append(r as Dictionary if r is Dictionary else {"target": str(r)})
	elif data.has("target"):
		var t: Variant = data["target"]
		_rounds.append(t as Dictionary if t is Dictionary else {"target": str(t)})
	if _rounds.is_empty() and not _choices.is_empty():
		_rounds.append({"target": str(_choices[0].get("id", ""))})
	_trim_choices()
	if bool(data.get("shuffle", false)):
		var rng := RandomNumberGenerator.new()
		if data.has("seed"):
			rng.seed = int(data["seed"])
		else:
			rng.randomize()
		for i in range(_choices.size() - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var tmp := _choices[i]
			_choices[i] = _choices[j]
			_choices[j] = tmp
	_strip = Node2D.new()
	_strip.name = "Choices"
	stage.add_child(_strip)
	for i in _choices.size():
		var node := _make_choice(_choices[i])
		_strip.add_child(node)
		choice_nodes[str(_choices[i].get("id", str(i)))] = node
	_place_choices()
	_target = Node2D.new()
	_target.name = "Target"
	_target.position = vec(data.get("target_pos"))
	stage.add_child(_target)
	_show_target()


func _started() -> void:
	say(_round_line(), true)


## The ids of the choices on screen, in layout order.
func choice_ids() -> Array[String]:
	var out: Array[String] = []
	for c in _choices:
		out.append(str(c.get("id", "")))
	return out


## The current round's target (a choice id or a match group).
func target() -> String:
	if round_index >= _rounds.size():
		return ""
	return str(_rounds[round_index].get("target", ""))


func rounds() -> int:
	return _rounds.size()


## Whether choice `id` is a right answer for the current round.
func is_right(id: String) -> bool:
	if _found.has(id) or not choice_nodes.has(id):
		return false
	var c := _choice(id)
	var want := target()
	return want != "" and (str(c.get("id", "")) == want or str(c.get("match", "")) == want)


## Global point of a choice (tests tap here).
func choice_point(id: String) -> Vector2:
	var node: Node2D = choice_nodes[id]
	return node.global_position


## Global rect of a choice.
func choice_rect(id: String) -> Rect2:
	var node: Node2D = choice_nodes[id]
	var sprite: Sprite2D = node.get_node("Sprite")
	var size := sprite.texture.get_size() * sprite.scale * node.global_scale
	return Rect2(node.global_position - size / 2, size)


func target_rect() -> Rect2:
	var h := float(data.get("target_height"))
	var local := Rect2(_target.position - Vector2(h, h) / 2, Vector2(h, h))
	var back := _target.get_node_or_null("Back") as Sprite2D
	if back:
		local = sprite_rect(back)
		local.position += _target.position
	return to_global_rect(local)


func scroll() -> float:
	return _scroll


func is_found(id: String) -> bool:
	return _found.has(id)


func _busy() -> bool:
	return _between


func _press(local: Vector2) -> bool:
	if _between:
		return false
	_press_at = local
	_scroll_start = _scroll
	_pressed_choice = _choice_at(local)
	return _pressed_choice != "" or str(data["layout"]) == "doors"


func _drag(local: Vector2) -> void:
	if str(data["layout"]) == "doors" and _moved:
		_set_scroll(_scroll_start + local.x - _press_at.x)


func _release(local: Vector2, tapped: bool) -> void:
	if not tapped:
		return
	var id := _choice_at(local)
	if id != "" and id == _pressed_choice:
		_pick(id)


func _pick(id: String) -> void:
	var node: Node2D = choice_nodes[id]
	if not is_right(id):
		misses += 1
		wiggle(node)
		sound(str(data.get("wrong_sound", "")))
		say(line("wrong_line"))
		if misses >= 2:
			_point_at_right()
		return
	misses = 0
	_found[id] = true
	sound(str(data.get("right_sound", "")))
	pop(node)
	if player:
		player.cheer()
	if helper:
		helper.cheer()
	round_index += 1
	var last := round_index >= _rounds.size()
	if last:
		say(line("right_line"))
		if bool(data.get("fly_found", _rounds.size() > 1)):
			_fly_to_target(node)
		finish()
		return
	say(line("right_line"))
	_between = true
	if bool(data.get("fly_found", true)):
		_fly_to_target(node)
	var delay := float(data.get("round_delay"))
	if delay <= 0.0:
		_next_round()
	else:
		get_tree().create_timer(delay).timeout.connect(_next_round)


func _next_round() -> void:
	_between = false
	_show_target()
	say(_round_line(), true)


func _round_line() -> String:
	if round_index < _rounds.size() and _rounds[round_index].has("line"):
		return str(_rounds[round_index]["line"])
	return str(data.get("round_line", ""))


func _fly_to_target(node: Node2D) -> void:
	var t := create_tween().set_parallel()
	t.tween_property(node, "global_position", _target.global_position, FOUND_TIME).set_trans(Tween.TRANS_QUAD)
	t.tween_property(node, "modulate:a", 0.0, FOUND_TIME)
	t.chain().tween_callback(func() -> void: node.visible = false)


func _show_hint() -> void:
	_point_at_right()


func _hide_hint() -> void:
	for id: String in choice_nodes:
		stop_pulse(choice_nodes[id] as Node2D)


func _point_at_right() -> void:
	for id in choice_ids():
		if is_right(id):
			var node: Node2D = choice_nodes[id]
			if str(data["layout"]) == "doors":
				_scroll_into_view(node)
			point_helper(stage.to_local(node.global_position))
			pulse(node)
			return


func _scroll_into_view(node: Node2D) -> void:
	var view := stage_view()
	var x := node.position.x + _scroll
	if x < view.position.x + 150 or x > view.end.x - 150:
		_set_scroll(view.get_center().x - node.position.x)


func _choice(id: String) -> Dictionary:
	for c in _choices:
		if str(c.get("id", "")) == id:
			return c
	return {}


## Keeps the round targets and the first choices up to `count`.
func _trim_choices() -> void:
	if not data.has("count"):
		return
	var count := int(data["count"])
	var need := {}
	for r in _rounds:
		var want := str(r.get("target", ""))
		need[want] = int(need.get(want, 0)) + 1
	var keep: Array[Dictionary] = []
	for c in _choices:
		for want: String in need:
			if int(need[want]) > 0 and (str(c.get("id", "")) == want or str(c.get("match", "")) == want):
				need[want] = int(need[want]) - 1
				keep.append(c)
				break
	for c in _choices:
		if keep.size() >= count:
			break
		if not keep.has(c) and not _is_round_target(c):
			keep.append(c)
	var ordered: Array[Dictionary] = []
	for c in _choices:
		if keep.has(c):
			ordered.append(c)
	_choices = ordered


func _is_round_target(c: Dictionary) -> bool:
	for r in _rounds:
		var want := str(r.get("target", ""))
		if str(c.get("id", "")) == want or str(c.get("match", "")) == want:
			return true
	return false


func _choice_at(local: Vector2) -> String:
	var best := ""
	for id in choice_ids():
		var node: Node2D = choice_nodes[id]
		if _found.has(id) or not node.visible:
			continue
		var r := choice_rect(id)
		var area := Rect2(stage.to_local(r.position), r.size / stage.scale).grow(20)
		if area.has_point(local):
			best = id
	return best


func _make_choice(c: Dictionary) -> Node2D:
	var node := Node2D.new()
	node.name = str(c.get("id", "choice"))
	var height := float(c.get("height", data.get("choice_height")))
	var sprite := Sprite2D.new()
	sprite.name = "Sprite"
	sprite.texture = texture_or(str(c.get("texture", "")), Vector2(height * 0.8, height), Color(0.85, 0.85, 0.9))
	set_height(sprite, height)
	node.add_child(sprite)
	var size := sprite.texture.get_size() * sprite.scale
	if c.has("color"):
		var dot := _disc(color_of(c["color"]), height * 0.16)
		dot.name = "Sticker"
		dot.position = vec(c.get("sticker_at"), Vector2(0, -size.y * 0.15))
		node.add_child(dot)
	if c.has("label"):
		node.add_child(_label(str(c["label"]), height * 0.32, vec(c.get("label_at"), Vector2.ZERO)))
	return node


func _show_target() -> void:
	for n in _target.get_children():
		n.free()
	if round_index >= _rounds.size():
		return
	var r := _rounds[round_index]
	var right := {}
	for c in _choices:
		var want := str(r.get("target", ""))
		if str(c.get("id", "")) == want or str(c.get("match", "")) == want:
			right = c
			break
	var h := float(data.get("target_height"))
	var back_path := str(r.get("texture", data.get("target_texture", "")))
	var key := str(r.get("key", data.get("key")))
	if back_path != "":
		var back := Sprite2D.new()
		back.name = "Back"
		back.texture = texture_or(back_path, Vector2(h, h))
		set_height(back, h)
		_target.add_child(back)
	if key == "picture" and back_path == "":
		var pic := Sprite2D.new()
		pic.name = "Back"
		pic.texture = texture_or(str(right.get("texture", "")), Vector2(h, h))
		set_height(pic, h)
		_target.add_child(pic)
	elif key == "color":
		var dot := _disc(color_of(r.get("color", right.get("color", "#ffffff"))), h * 0.3)
		dot.name = "Sticker"
		_target.add_child(dot)
	elif key == "number":
		_target.add_child(_label(str(r.get("label", right.get("label", ""))), h * 0.5, Vector2.ZERO))
	pop(_target)


func _place_choices() -> void:
	var n := _choices.size()
	var layout := str(data["layout"])
	var row_y := float(data["row_y"])
	for i in n:
		var c := _choices[i]
		var node: Node2D = choice_nodes[str(c.get("id", str(i)))]
		var room := Vector2.INF
		if c.has("pos"):
			node.position = vec(c["pos"])
		elif layout == "grid":
			var cols := maxi(int(data["columns"]), 1)
			var rows := ceili(float(n) / cols)
			var g := rect_of(data["grid_rect"])
			var cell := Vector2(g.size.x / cols, g.size.y / maxi(rows, 1))
			node.position = g.position + Vector2((i % cols) + 0.5, (i / cols) + 0.5) * cell
			room = cell * 0.9
		elif layout == "doors":
			node.position = Vector2(SAFE.position.x + float(data["door_spacing"]) * (i + 0.5), row_y)
			room = Vector2(float(data["door_spacing"]) * 0.9, INF)
		else:
			var width := SAFE.size.x - 160
			node.position = Vector2(SAFE.position.x + 80 + width * (i + 0.5) / n, row_y)
			room = Vector2(width / n * 0.9, INF)
		# Shrink a choice that's wider (or taller) than its place.
		var sprite: Sprite2D = node.get_node("Sprite")
		var size := sprite.texture.get_size() * sprite.scale
		node.scale = Vector2.ONE * minf(1.0, minf(room.x / size.x, room.y / size.y))


func _layout() -> void:
	_set_scroll(_scroll)


## Hallway scroll, kept so the doors always cover the screen.
func _set_scroll(value: float) -> void:
	if str(data.get("layout", "")) != "doors" or _strip == null:
		return
	var view := stage_view()
	var width := float(data["door_spacing"]) * _choices.size()
	var lo := minf(0.0, view.end.x - 40 - (SAFE.position.x + width))
	var hi := maxf(0.0, view.position.x + 40 - SAFE.position.x)
	_scroll = clampf(value, minf(lo, hi), hi)
	_strip.position.x = _scroll


func _disc(color: Color, radius: float) -> Node2D:
	var holder := Node2D.new()
	var ring := Polygon2D.new()
	ring.polygon = _circle(radius * 1.15)
	ring.color = Color.WHITE
	holder.add_child(ring)
	var dot := Polygon2D.new()
	dot.polygon = _circle(radius)
	dot.color = color
	holder.add_child(dot)
	return holder


static func _circle(radius: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for k in 32:
		pts.append(Vector2.from_angle(TAU * k / 32.0) * radius)
	return pts


## A big digit (a door, row or floor number): the only text a kid sees.
func _label(text: String, font_size: float, at: Vector2) -> Label:
	var label := Label.new()
	label.name = "Label"
	label.text = text
	var settings := LabelSettings.new()
	settings.font_size = int(font_size)
	settings.font_color = color_of(data.get("label_color", ""), LABEL_COLOR)
	settings.outline_size = maxi(int(font_size / 8), 4)
	settings.outline_color = LABEL_OUTLINE
	label.label_settings = settings
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size = Vector2(font_size * 3, font_size * 1.5)
	label.position = at - label.size / 2
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
