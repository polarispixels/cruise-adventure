# Moving targets: things move past (around a loop like a baggage carousel, or
# drifting left to right like floating toys, or standing still like water
# jets). The kid taps the right ones; a decoy only wiggles. Nothing is ever
# lost: a target that goes by comes around again (loop) or drifts back in from
# the left. Done when every target has been tapped.
extends EngineBase

const HIT_SLACK := 30.0
const COLLECT_TIME := 0.5

var item_nodes := {}

var _items: Array[Dictionary] = []
var _targets: Array[String] = []
var _tapped := {}
var _phase := 0.0
var _layer: Node2D
var _hint := ""


func _defaults() -> Dictionary:
	return {
		"path": "loop",
		"loop_rect": [300, 380, 1072, 380],
		"lanes": [600.0],
		"spacing": 380.0,
		"speed": 120.0,
		"item_height": 170.0,
		"right_line": "found",
		"wrong_line": "",
		"right_sound": "tag-snap",
		"helper_feet": [1480, 930],
	}


func _build() -> void:
	for it: Variant in data.get("items", []):
		if it is Dictionary:
			_items.append(it as Dictionary)
	for id: Variant in data.get("targets", []):
		_targets.append(str(id))
	for it in _items:
		if bool(it.get("target", false)) and not _targets.has(str(it["id"])):
			_targets.append(str(it["id"]))
	if data.has("track_texture"):
		var track := Sprite2D.new()
		track.name = "Track"
		track.texture = texture_or(str(data["track_texture"]))
		var r := rect_of(data.get("track_rect", data["loop_rect"]))
		track.position = r.get_center()
		track.scale = r.size / track.texture.get_size()
		stage.add_child(track)
	_layer = Node2D.new()
	_layer.name = "Items"
	stage.add_child(_layer)
	for it in _items:
		var id := str(it.get("id", ""))
		var s := Sprite2D.new()
		s.name = id
		var h := float(it.get("height", data["item_height"]))
		s.texture = texture_or(str(it.get("texture", "")), Vector2(h, h), Color(0.9, 0.6, 0.6))
		set_height(s, h)
		_layer.add_child(s)
		item_nodes[id] = s
	_move(0.0)


func item_ids() -> Array[String]:
	var out: Array[String] = []
	for it in _items:
		out.append(str(it.get("id", "")))
	return out


func targets() -> Array[String]:
	return _targets.duplicate()


func item_point(id: String) -> Vector2:
	return stage.to_global((item_nodes[id] as Sprite2D).position)


func item_rect(id: String) -> Rect2:
	return to_global_rect(sprite_rect(item_nodes[id] as Sprite2D))


func is_tapped(id: String) -> bool:
	return _tapped.has(id)


func _process(delta: float) -> void:
	super(delta)
	if not finished:
		_move(delta)


## Places every moving thing for the time that has passed.
func _move(delta: float) -> void:
	_phase += delta * float(data["speed"])
	var path := str(data["path"])
	var n := _items.size()
	for i in n:
		var it := _items[i]
		var id := str(it.get("id", ""))
		if _tapped.has(id):
			continue
		var s: Sprite2D = item_nodes[id]
		if path == "still" or it.has("pos"):
			s.position = vec(it.get("pos"), Vector2(lerpf(SAFE.position.x + 120, SAFE.end.x - 120, (i + 0.5) / n), 600))
		elif path == "drift":
			var lanes: Array = data["lanes"] as Array
			var spacing := float(data["spacing"])
			var span := maxf(spacing * n, SAFE.size.x + spacing)
			var left := SAFE.position.x - spacing
			var x := fposmod(spacing * i + _phase, span)
			s.position = Vector2(left + x, float(lanes[i % lanes.size()]))
		else:
			var r := rect_of(data["loop_rect"])
			var perimeter := PI * (r.size.x + r.size.y) / 2
			var angle := TAU * i / n + _phase / perimeter * TAU
			s.position = r.get_center() + Vector2(cos(angle) * r.size.x / 2, sin(angle) * r.size.y / 2)
			# Things on the far side of the loop are drawn behind.
			s.z_index = 1 if sin(angle) > 0 else 0


func _press(local: Vector2) -> bool:
	var id := _item_at(local)
	if id == "":
		return false
	_tap(id)
	return true


func _tap(id: String) -> void:
	var s: Sprite2D = item_nodes[id]
	if not _targets.has(id):
		wiggle(s)
		sound(str(data.get("wrong_sound", "")))
		say(line("wrong_line"))
		return
	_tapped[id] = true
	stop_pulse(s)
	sound(str(data["right_sound"]))
	if player:
		player.cheer()
	var t := create_tween().set_parallel()
	if data.has("collect_point"):
		var k := _tapped.size() - 1
		var to := vec(data["collect_point"]) + Vector2(k * 60.0, 0)
		t.tween_property(s, "position", to, COLLECT_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.tween_property(s, "scale", s.scale * 0.7, COLLECT_TIME)
	else:
		t.tween_property(s, "scale", s.scale * 1.3, COLLECT_TIME)
		t.tween_property(s, "modulate:a", 0.0, COLLECT_TIME)
	if _tapped.size() >= _targets.size():
		finish()
		return
	say(line("right_line"))


func _show_hint() -> void:
	var best := ""
	var best_d := INF
	var view := stage_view()
	for id in _targets:
		if _tapped.has(id):
			continue
		var p := (item_nodes[id] as Sprite2D).position
		var d := p.distance_to(view.get_center())
		if view.has_point(p) and d < best_d:
			best = id
			best_d = d
	if best == "":
		for id in _targets:
			if not _tapped.has(id):
				best = id
				break
	if best == "":
		return
	_hint = best
	pulse(item_nodes[best] as Sprite2D)
	point_helper((item_nodes[best] as Sprite2D).position)


func _hide_hint() -> void:
	if _hint != "":
		stop_pulse(item_nodes[_hint] as Sprite2D)
	_hint = ""


func _item_at(local: Vector2) -> String:
	var best := ""
	var best_d := INF
	for id in item_ids():
		if _tapped.has(id):
			continue
		var s: Sprite2D = item_nodes[id]
		var r := sprite_rect(s).grow(HIT_SLACK)
		if r.has_point(local) and local.distance_to(s.position) < best_d:
			best = id
			best_d = local.distance_to(s.position)
	return best
