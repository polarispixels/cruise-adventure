# Place: the kid drags things to their spots. While a thing is held, the spots
# that take it glow (as at check-in and security). Dropped on a spot that takes
# it, it snaps in (shrinking to the spot when the spot is smaller); dropped on a
# spot that doesn't, it wiggles and slides back; dropped anywhere else it just
# slides back. A tap on a thing sends it to the next spot that takes it. A
# "reusable" thing (the sunscreen) goes back home after each drop and marks the
# spot instead. Ordered slots fill in their listed order. Done when every thing
# is placed (and, with a reusable thing, every spot is filled).
extends EngineBase

const DROP_SLACK := 60.0
const POINT_SLOT := 160.0
const LIFT := 1.12

var item_nodes := {}
var slot_rects := {}

var _items: Array[Dictionary] = []
var _slots: Array[Dictionary] = []
var _home := {}
var _home_scale := {}
## item id -> slot id
var _placed := {}
## slot id -> item id
var _filled := {}
var _held := ""
var _offset := Vector2.ZERO
var _layer: Node2D
var _marks: Node2D
var _hint_item := ""


func _defaults() -> Dictionary:
	return {
		"item_height": 150.0,
		"tray_y": 830.0,
		"ordered": false,
		"tap_places": true,
		"always_glow": false,
		"place_line": "found",
		"wrong_line": "",
		"place_sound": "tag-snap",
		"helper_feet": [1480, 930],
	}


func _build() -> void:
	for s: Variant in data.get("slots", []):
		if s is Dictionary:
			_slots.append(s as Dictionary)
	for it: Variant in data.get("items", []):
		if it is Dictionary:
			_items.append(it as Dictionary)
	_marks = Node2D.new()
	_marks.name = "Slots"
	stage.add_child(_marks)
	for s in _slots:
		var id := str(s.get("id", ""))
		var r := _slot_rect(s)
		slot_rects[id] = r
		if s.has("texture"):
			var marker := Sprite2D.new()
			marker.name = id
			marker.texture = texture_or(str(s["texture"]), r.size)
			marker.position = r.get_center()
			marker.scale = r.size / marker.texture.get_size()
			_marks.add_child(marker)
	_layer = Node2D.new()
	_layer.name = "Items"
	stage.add_child(_layer)
	var free_x: Array[float] = []
	var unplaced := 0
	for it in _items:
		if not it.has("pos"):
			unplaced += 1
	for i in unplaced:
		free_x.append(lerpf(SAFE.position.x + 100, SAFE.end.x - 340, (i + 0.5) / maxf(unplaced, 1)))
	var k := 0
	for it in _items:
		var id := str(it.get("id", ""))
		var sprite := Sprite2D.new()
		sprite.name = id
		var h := float(it.get("height", data["item_height"]))
		sprite.texture = texture_or(str(it.get("texture", "")), Vector2(h, h), Color(0.95, 0.75, 0.4))
		set_height(sprite, h)
		if it.has("pos"):
			sprite.position = vec(it["pos"])
		else:
			sprite.position = Vector2(free_x[k], float(data["tray_y"]))
			k += 1
		# appears_after: waits, hidden, until that slot is filled.
		sprite.visible = str(it.get("appears_after", "")) == ""
		_layer.add_child(sprite)
		item_nodes[id] = sprite
		_home[id] = sprite.position
		_home_scale[id] = sprite.scale


func item_ids() -> Array[String]:
	var out: Array[String] = []
	for it in _items:
		out.append(str(it.get("id", "")))
	return out


func slot_ids() -> Array[String]:
	var out: Array[String] = []
	for s in _slots:
		out.append(str(s.get("id", "")))
	return out


## Global center of a thing (tests drag from here).
func item_point(id: String) -> Vector2:
	return stage.to_global((item_nodes[id] as Sprite2D).position)


func item_rect(id: String) -> Rect2:
	return to_global_rect(sprite_rect(item_nodes[id] as Sprite2D))


func slot_point(id: String) -> Vector2:
	return stage.to_global((slot_rects[id] as Rect2).get_center())


func slot_rect(id: String) -> Rect2:
	return to_global_rect(slot_rects[id] as Rect2)


func is_placed(id: String) -> bool:
	return _placed.has(id)


func is_filled(slot_id: String) -> bool:
	return _filled.has(slot_id)


## Whether `slot` would take thing `id` now (free, accepts it, and its turn when ordered).
func takes(slot: Dictionary, id: String) -> bool:
	var sid := str(slot.get("id", ""))
	if _filled.has(sid) or bool(slot.get("inert", false)):
		return false
	if bool(data["ordered"]):
		for s in _slots:
			if not _filled.has(str(s.get("id", ""))):
				if s != slot:
					return false
				break
	var item := _item(id)
	if str(item.get("slot", "")) == sid:
		return true
	var accepts: Variant = slot.get("accepts", "any" if not _any_item_names_slot() else [])
	if accepts is String:
		return accepts == "any"
	return accepts is Array and (accepts as Array).has(id)


func _any_item_names_slot() -> bool:
	for it in _items:
		if it.has("slot"):
			return true
	return false


func _press(local: Vector2) -> bool:
	_held = _item_at(local)
	if _held == "":
		return false
	var sprite: Sprite2D = item_nodes[_held]
	_offset = sprite.position - local
	sprite.z_index = 10
	sprite.scale = (_home_scale[_held] as Vector2) * LIFT
	return true


func _drag(local: Vector2) -> void:
	if _held != "" and _moved:
		(item_nodes[_held] as Sprite2D).position = local + _offset


func _release(local: Vector2, tapped: bool) -> void:
	var id := _held
	_held = ""
	if id == "":
		return
	var sprite: Sprite2D = item_nodes[id]
	sprite.z_index = 0
	if tapped:
		if bool(data["tap_places"]):
			for s in _slots:
				if takes(s, id):
					_put(id, s)
					return
		_back(id)
		return
	sprite.position = local + _offset
	var over := _slot_under(sprite.position)
	if over.is_empty():
		_back(id)
	elif takes(over, id):
		_put(id, over)
	else:
		_back(id)
		wiggle(sprite)
		say(line("wrong_line"))


func _process(delta: float) -> void:
	super(delta)
	_update_glows()


func _update_glows() -> void:
	if finished:
		return
	var rects: Array[Rect2] = []
	var who := _held if _held != "" else _hint_item
	for s in _slots:
		var sid := str(s.get("id", ""))
		if _filled.has(sid) or bool(s.get("inert", false)):
			continue
		if who != "":
			if takes(s, who):
				rects.append(slot_rects[sid] as Rect2)
		elif bool(data["always_glow"]):
			rects.append(slot_rects[sid] as Rect2)
	glows.show_rects(rects)


func _put(id: String, slot: Dictionary) -> void:
	var sid := str(slot.get("id", ""))
	var sprite: Sprite2D = item_nodes[id]
	var r: Rect2 = slot_rects[sid]
	var item := _item(id)
	_filled[sid] = id
	sound(str(slot.get("sound", data["place_sound"])))
	if bool(item.get("reusable", false)):
		_mark(slot, item)
		_back(id)
	else:
		_placed[id] = sid
		var target_scale: Vector2 = _home_scale[id]
		if bool(slot.get("shrink", true)):
			var size := sprite.texture.get_size() * target_scale
			var fit := minf(1.0, minf(r.size.x / size.x, r.size.y / size.y))
			target_scale *= fit
		if item.has("place_texture"):
			sprite.texture = texture_or(str(item["place_texture"]))
			target_scale = Vector2.ONE * minf(r.size.x / sprite.texture.get_size().x, r.size.y / sprite.texture.get_size().y)
		var t := create_tween().set_parallel()
		t.tween_property(sprite, "position", r.get_center(), GLIDE_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.tween_property(sprite, "scale", target_scale, GLIDE_TIME)
		if bool(item.get("hide_on_place", false)):
			t.chain().tween_callback(func() -> void: sprite.visible = false)
		if slot.has("fill_texture"):
			# hide_marker_on_fill: the filled picture takes the slot picture's place.
			var own := _marks.get_node_or_null(NodePath(sid))
			if own and bool(slot.get("hide_marker_on_fill", false)):
				(own as CanvasItem).visible = false
			_mark(slot, {})
	for it in _items:
		if str(it.get("appears_after", "")) == sid:
			var waiting: Sprite2D = item_nodes[str(it.get("id", ""))]
			if not waiting.visible:
				waiting.visible = true
				pop(waiting)
	if _all_done():
		finish()
		return
	if player:
		player.cheer()
	say(str(slot.get("line", line("place_line"))))


## Shows the slot's filled picture (or a small copy of the reusable thing).
func _mark(slot: Dictionary, item: Dictionary) -> void:
	var sid := str(slot.get("id", ""))
	var r: Rect2 = slot_rects[sid]
	var mark := Sprite2D.new()
	mark.name = "Filled-" + sid
	var path := str(slot.get("fill_texture", item.get("mark_texture", item.get("texture", ""))))
	mark.texture = texture_or(path, r.size)
	fit_into(mark, r.size)
	mark.position = r.get_center()
	_marks.add_child(mark)
	pop(mark)


func _all_done() -> bool:
	var reusable := false
	for it in _items:
		if bool(it.get("reusable", false)):
			reusable = true
		elif not _placed.has(str(it.get("id", ""))):
			return false
	if reusable:
		for s in _slots:
			if not _filled.has(str(s.get("id", ""))):
				return false
	return true


func _back(id: String) -> void:
	var sprite: Sprite2D = item_nodes[id]
	var t := create_tween().set_parallel()
	t.tween_property(sprite, "position", _home[id] as Vector2, GLIDE_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(sprite, "scale", _home_scale[id] as Vector2, GLIDE_TIME)


func _show_hint() -> void:
	for it in _items:
		var id := str(it.get("id", ""))
		if _placed.has(id) or not (item_nodes[id] as Sprite2D).visible:
			continue
		for s in _slots:
			if takes(s, id):
				_hint_item = id
				var sprite: Sprite2D = item_nodes[id]
				pulse(sprite)
				point_helper(sprite.position)
				return


func _hide_hint() -> void:
	if _hint_item != "":
		stop_pulse(item_nodes[_hint_item] as Sprite2D)
	_hint_item = ""


func _item(id: String) -> Dictionary:
	for it in _items:
		if str(it.get("id", "")) == id:
			return it
	return {}


func _item_at(local: Vector2) -> String:
	var best := ""
	var best_area := INF
	for id in item_ids():
		if _placed.has(id) or not (item_nodes[id] as Sprite2D).visible:
			continue
		var r := sprite_rect(item_nodes[id] as Sprite2D)
		if r.grow(30).has_point(local) and r.get_area() <= best_area:
			best = id
			best_area = r.get_area()
	return best


func _slot_under(local: Vector2) -> Dictionary:
	var best := {}
	var best_d := INF
	for s in _slots:
		if bool(s.get("inert", false)):
			continue
		var r: Rect2 = slot_rects[str(s.get("id", ""))]
		if r.grow(DROP_SLACK).has_point(local):
			var d := local.distance_to(r.get_center())
			if d < best_d:
				best = s
				best_d = d
	return best


func _slot_rect(s: Dictionary) -> Rect2:
	if s.has("rect"):
		return rect_of(s["rect"])
	var size := float(s.get("size", POINT_SLOT))
	return Rect2(vec(s.get("point")) - Vector2(size, size) / 2, Vector2(size, size))
