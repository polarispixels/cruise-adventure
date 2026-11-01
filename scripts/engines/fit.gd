# Fit: the grid puzzle with turning, from the trunk (TrunkModel and Bag). The
# pieces wait outside the container; the kid drags each in. A piece snaps to
# the grid where it fits and slides back where it doesn't; a tap on a waiting
# piece turns it. Becca's easier data preloads big pieces, shows a faded ghost
# of each piece where it goes, and turns a piece by itself when only the turn
# fits. While a piece is held its spot glows. Done when the grid is full.
extends EngineBase

const BAG_SCENE := preload("res://scenes/bag.tscn")
const GHOST_COLOR := Color(1, 1, 1, 0.35)
const GRAB_PADDING := 16.0

var model: TrunkModel
var pieces := {}

var _area := Rect2()
var _cell := 100.0
var _preplaced := PackedStringArray()
var _waiting := {}
var _container: Sprite2D
var _ghosts: Node2D
var _layer: Node2D
var _held: Bag
var _lifted := false
var _offset := Vector2.ZERO
var _cheers := 0
var _hint_bag: Bag
var _hint_rect := Rect2()
var _held_rect := Rect2()


func _defaults() -> Dictionary:
	return {
		"area": [436, 200, 800, 500],
		"outlines": false,
		"auto_turn": false,
		"preplaced": [],
		"place_line": "it-fits",
		"turn_line": "turn-it",
		"wrong_line": "try-another-spot",
		"place_sound": "tray-slide",
		"helper_feet": [1480, 930],
	}


func _build() -> void:
	model = TrunkModel.from_dict(data)
	for id: Variant in data.get("preplaced", []):
		_preplaced.append(str(id))
	_area = _grid_area()
	_cell = minf(_area.size.x / model.cols, _area.size.y / model.rows)
	_area = Rect2(_area.get_center() - Vector2(model.cols, model.rows) * _cell / 2, Vector2(model.cols, model.rows) * _cell)
	if data.has("container_texture"):
		_container = Sprite2D.new()
		_container.name = "Container"
		_container.texture = texture_or(str(data["container_texture"]), _area.size)
		var box := _container_rect()
		_container.position = box.get_center()
		_container.scale = box.size / _container.texture.get_size()
		stage.add_child(_container)
	_ghosts = Node2D.new()
	_ghosts.name = "Ghosts"
	stage.add_child(_ghosts)
	_layer = Node2D.new()
	_layer.name = "Pieces"
	stage.add_child(_layer)
	for p: Variant in data.get("pieces", data.get("bags", [])):
		var d: Dictionary = p
		var id := str(d["id"])
		var bag: Bag = BAG_SCENE.instantiate()
		bag.name = id
		_layer.add_child(bag)
		var tex_path := str(d.get("texture", "res://assets/car/bag-%s.png" % id))
		var size := model.size_of(id, false)
		bag.setup(id, size, _cell, texture_or(tex_path, Vector2(size) * 100, Color(0.6, 0.7, 0.9)))
		bag.set_turned(model.is_turned(id))
		pieces[id] = bag
		if d.has("pos"):
			_waiting[id] = vec(d["pos"])
	_auto_waiting()
	var ref := model.reference_solution()
	model.preplace(_preplaced)
	for id in _preplaced:
		if pieces.has(id):
			(pieces[id] as Bag).locked = true
	if bool(data["outlines"]):
		for id in model.bag_ids:
			if not _preplaced.has(id) and ref.has(id):
				_add_ghost(id, ref[id]["cell"], ref[id]["turned"])


func _layout() -> void:
	sync_pieces()


## Puts every piece where the model says (in the grid, or waiting outside).
func sync_pieces() -> void:
	for id in model.bag_ids:
		var b: Bag = pieces[id]
		if b == _held and _lifted:
			continue
		b.set_turned(model.is_turned(id))
		b.jump_to(_home_of(id))
	_update_ghosts()


## The grid in global pixels.
func grid_rect() -> Rect2:
	return to_global_rect(_area)


## Global pixels per cell.
func cell_px() -> float:
	return _cell * stage.scale.x


## Global center of a piece of `size` cells with its top-left at `cell`.
func cell_center(cell: Vector2i, size: Vector2i) -> Vector2:
	return stage.to_global(_area.position + (Vector2(cell) + Vector2(size) / 2) * _cell)


func piece_point(id: String) -> Vector2:
	return (pieces[id] as Bag).global_position


func piece_rect(id: String) -> Rect2:
	return (pieces[id] as Bag).rect()


## Where a waiting piece sits, global.
func waiting_point(id: String) -> Vector2:
	return stage.to_global(_waiting[id] as Vector2)


func is_locked(id: String) -> bool:
	return _preplaced.has(id)


func ghost_ids() -> Array[String]:
	var out: Array[String] = []
	for g in _ghosts.get_children():
		out.append(String(g.name))
	return out


func _press(local: Vector2) -> bool:
	_held = _bag_at(stage.to_global(local))
	if _held == null:
		return false
	_lifted = false
	_offset = _held.global_position - stage.to_global(local)
	return true


func _drag(local: Vector2) -> void:
	if _held == null or not _moved or _held.locked:
		return
	if not _lifted:
		_lifted = true
		_held.lift()
		model.remove(_held.id)
		_update_ghosts()
		_held_rect = _spot_for(_held.id)
	_held.global_position = stage.to_global(local) + _offset


func _release(local: Vector2, tapped: bool) -> void:
	var b := _held
	var lifted := _lifted
	_held = null
	_lifted = false
	_held_rect = Rect2()
	if b == null:
		return
	if b.locked:
		b.wiggle()
	elif tapped or not lifted:
		_turn(b)
	else:
		b.global_position = stage.to_global(local) + _offset
		_drop(b)


func _process(delta: float) -> void:
	super(delta)
	if finished:
		return
	var rects: Array[Rect2] = []
	if _held_rect.has_area():
		rects.append(_held_rect)
	elif _hint_rect.has_area():
		rects.append(_hint_rect)
	glows.show_rects(rects)


func _busy() -> bool:
	return model.is_full()


func _turn(b: Bag) -> void:
	if model.cell_of(b.id) != TrunkModel.NOWHERE:
		b.wiggle()
		return
	model.set_turned(b.id, not model.is_turned(b.id))
	b.set_turned(model.is_turned(b.id))
	b.glide_to(_home_of(b.id))


func _drop(b: Bag) -> void:
	var id := b.id
	var turned := model.is_turned(id)
	if model.place(id, _cell_for(id, b.global_position, turned)):
		_placed(b)
		return
	var other := not turned
	if _fits_at(id, b.global_position, other):
		say(line("turn_line"))
		if bool(data["auto_turn"]):
			model.set_turned(id, other)
			b.set_turned(other)
			model.place(id, _cell_for(id, b.global_position, other))
			_placed(b, false)
			return
	elif grid_rect().grow(cell_px() / 2).has_point(b.global_position):
		say(line("wrong_line"))
	b.glide_to(_home_of(id))


func _placed(b: Bag, cheer := true) -> void:
	var id := b.id
	b.glide_to(cell_center(model.cell_of(id), model.size_of(id, model.is_turned(id))))
	_update_ghosts()
	sound(str(data["place_sound"]))
	if model.is_full():
		if data.has("full_texture") and _container:
			_container.texture = texture_or(str(data["full_texture"]))
		finish()
		return
	if cheer:
		_cheers += 1
		say(line("place_line") if _cheers % 2 == 1 else Voice.found_line())


func _show_hint() -> void:
	var hint := model.hint(_preplaced)
	if hint.is_empty():
		return
	_hint_bag = pieces[hint["id"]]
	point_helper(stage.to_local(_hint_bag.global_position))
	if hint["kind"] == "wrong":
		_hint_bag.wiggle()
		say(line("wrong_line"))
		return
	_hint_bag.pulse()
	var size := Vector2(model.size_of(hint["id"], hint["turned"])) * _cell
	_hint_rect = Rect2(_area.position + Vector2(hint["cell"]) * _cell, size)


func _hide_hint() -> void:
	if _hint_bag:
		_hint_bag.stop_pulse()
	_hint_bag = null
	_hint_rect = Rect2()


## Where the held piece can go so the grid still fills (stage rect), or none.
func _spot_for(id: String) -> Rect2:
	var sol := model.solve()
	if not sol.has(id):
		return Rect2()
	var size := Vector2(model.size_of(id, sol[id]["turned"])) * _cell
	return Rect2(_area.position + Vector2(sol[id]["cell"]) * _cell, size)


func _cell_for(id: String, center: Vector2, turned: bool) -> Vector2i:
	var size := Vector2(model.size_of(id, turned))
	var top_left := (stage.to_local(center) - _area.position) / _cell - size / 2
	return Vector2i(roundi(top_left.x), roundi(top_left.y))


func _fits_at(id: String, center: Vector2, turned: bool) -> bool:
	var was := model.is_turned(id)
	model.set_turned(id, turned)
	var ok := model.can_place(id, _cell_for(id, center, turned))
	model.set_turned(id, was)
	return ok


func _home_of(id: String) -> Vector2:
	var cell := model.cell_of(id)
	if cell == TrunkModel.NOWHERE:
		return stage.to_global(_waiting[id] as Vector2)
	return cell_center(cell, model.size_of(id, model.is_turned(id)))


func _bag_at(point: Vector2) -> Bag:
	var best: Bag
	var best_area := INF
	for id in model.bag_ids:
		var b: Bag = pieces[id]
		var r := b.rect()
		if r.grow(GRAB_PADDING).has_point(point) and r.get_area() <= best_area:
			best = b
			best_area = r.get_area()
	return best


## Waiting spots for pieces without a `pos`: a row along the bottom of the safe
## area, under the grid (wrapping to a second row above it when needed).
func _auto_waiting() -> void:
	var todo: Array[String] = []
	for id in model.bag_ids:
		if not _waiting.has(id):
			todo.append(id)
	if todo.is_empty():
		return
	var gap := 30.0
	var lo := SAFE.position.x + 40
	var hi := SAFE.end.x - 40
	var y := float(data.get("tray_y", 860.0))
	var x := lo
	var row_h := 0.0
	for id in todo:
		var longest := float(maxi(model.size_of(id, false).x, model.size_of(id, false).y)) * _cell
		if x + longest > hi and x > lo:
			x = lo
			y -= row_h + gap
			row_h = 0.0
		_waiting[id] = Vector2(x + longest / 2, y - longest / 2)
		x += longest + gap
		row_h = maxf(row_h, longest)


func _grid_area() -> Rect2:
	if data.has("cargo_rect") and data.has("container_rect"):
		# cargo_rect is in the container texture's pixels, as in data/trunk.json.
		var box := rect_of(data["container_rect"])
		var tex := texture_or(str(data.get("container_texture", "")), box.size)
		var k := box.size / tex.get_size()
		var c := rect_of(data["cargo_rect"])
		return Rect2(box.position + c.position * k, c.size * k)
	return rect_of(data["area"])


func _container_rect() -> Rect2:
	if data.has("container_rect"):
		return rect_of(data["container_rect"])
	return _area.grow(_cell * 0.6)


func _add_ghost(id: String, cell: Vector2i, turned: bool) -> void:
	var ghost := Sprite2D.new()
	ghost.name = id
	ghost.texture = (pieces[id] as Bag).get_node("Sprite").texture
	ghost.modulate = GHOST_COLOR
	ghost.rotation = PI / 2 if turned else 0.0
	var size := Vector2(model.size_of(id, false)) * _cell
	ghost.scale = size / ghost.texture.get_size()
	ghost.position = _area.position + (Vector2(cell) + Vector2(model.size_of(id, turned)) / 2) * _cell
	_ghosts.add_child(ghost)


func _update_ghosts() -> void:
	for ghost: Sprite2D in _ghosts.get_children():
		ghost.visible = model.cell_of(String(ghost.name)) == TrunkModel.NOWHERE
