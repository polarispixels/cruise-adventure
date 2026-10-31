# The trunk puzzle (To the car): the family's bags wait on the driveway behind
# the black SUV, and the child drags every one into the trunk. A bag snaps to
# the grid where it fits and slides back where it doesn't; tapping a bag on the
# driveway turns it on its side, which some bags need. The rules live in
# TrunkModel; this scene draws them and turns touches into moves. Becca's
# easier version (big bags already in, outlines, bags that turn themselves)
# comes from her KidProfile.
extends Node2D

signal filled

const DATA := "res://data/trunk.json"
const BG_SIZE := Vector2(1672, 941)
## Screen pixels per trunk cell.
const CELL := 100.0
const SUV_TOP_MARGIN := 20.0
const MARGIN := 24.0
const HOME_SIZE := 130.0
const HELPER_SCALE := 0.25
const OUTLINE_COLOR := Color(1, 1, 1, 0.55)
const OUTLINE_WIDTH := 6.0
## A press that moves less than this is a tap.
const TAP_DISTANCE := 20.0
## Grab slack around small bags, in pixels.
const GRAB_PADDING := 16.0
const BAG_SCENE := preload("res://scenes/bag.tscn")
## Where each bag waits on the driveway: [anchor, offset of its center].
## Anchors: "suv" = the SUV's top-center; "bottom-left"/"bottom-right" = view corners.
const GROUND := {
	"daddy-gray": ["suv", Vector2(-790, 430)],
	"jack-suitcase": ["suv", Vector2(-570, 480)],
	"daddy-backpack": ["suv", Vector2(570, 480)],
	"becca-suitcase": ["suv", Vector2(790, 480)],
	"mommy-yellow": ["bottom-left", Vector2(330, -130)],
	"jack-backpack": ["bottom-right", Vector2(-470, -130)],
	"becca-backpack": ["bottom-right", Vector2(-340, -130)],
	"mommy-purse": ["bottom-right", Vector2(-210, -80)],
}

var model: TrunkModel

var _data: Dictionary
var _bags := {}
var _held: Bag
var _moved := false
var _press := Vector2.ZERO
var _grab_offset := Vector2.ZERO
var _cheer := 0

@onready var _background: Sprite2D = $Background
@onready var _suv: Sprite2D = $Suv
@onready var _outlines: Node2D = $Outlines
@onready var _helper: Character = $Helper
@onready var _bag_layer: Node2D = $Bags
@onready var _play_home: TextureButton = $PlayHome


func _ready() -> void:
	_data = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	model = TrunkModel.from_file(DATA)
	var kid := Game.kid
	_suv.texture = load("res://assets/car/suv-open.png")
	_suv.scale = Vector2.ONE * CELL / float(_data["cell_px"])
	_helper.kid = Game.sibling()
	_helper.height_scale = HELPER_SCALE
	_play_home.pressed.connect(func(): Game.goto(Game.TITLE))
	for id in model.bag_ids:
		var bag: Bag = BAG_SCENE.instantiate()
		_bag_layer.add_child(bag)
		bag.setup(id, model.size_of(id, false), CELL, load("res://assets/car/bag-%s.png" % id))
		_bags[id] = bag
	var ref := model.reference_solution()
	for id in kid.trunk_preplaced:
		model.set_turned(id, ref[id]["turned"])
		model.place(id, ref[id]["cell"])
		_bags[id].locked = true
	if kid.trunk_outlines:
		for id in model.bag_ids:
			if not kid.trunk_preplaced.has(id):
				_add_outline(id, ref[id]["cell"], ref[id]["turned"])
	get_viewport().size_changed.connect(_fit)
	_fit()


func bag(id: String) -> Bag:
	return _bags[id]


## Global rect of the trunk's cargo area (the whole grid).
func cargo_rect() -> Rect2:
	var c: Array = _data["cargo_rect"]
	var tex := _suv.texture.get_size()
	var origin := _suv.global_position + (Vector2(c[0], c[1]) - tex / 2) * _suv.scale
	return Rect2(origin, Vector2(c[2], c[3]) * _suv.scale)


## Global center of a bag of `size` cells whose top-left is at `cell`.
func cell_center(cell: Vector2i, size: Vector2i) -> Vector2:
	return cargo_rect().position + (Vector2(cell) + Vector2(size) / 2) * CELL


## Where a bag waits on the driveway (kept on screen when it's turned).
func ground_point(id: String) -> Vector2:
	var spot: Array = GROUND[id]
	var view := _view()
	var anchor: Vector2
	match spot[0]:
		"suv": anchor = Vector2(960, view.position.y + SUV_TOP_MARGIN)
		"bottom-left": anchor = Vector2(view.position.x, view.end.y)
		_: anchor = view.end
	var point: Vector2 = anchor + spot[1]
	var half := Vector2(model.size_of(id, model.is_turned(id))) * CELL / 2
	return point.clamp(view.position + half, view.end - half)


func is_dragging() -> bool:
	return _held != null and _moved


## Puts every bag where the model says: in the trunk or on the driveway.
func sync_bags() -> void:
	for id in model.bag_ids:
		var b: Bag = _bags[id]
		b.set_turned(model.is_turned(id))
		b.jump_to(_home_of(id))
	_update_outlines()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var point := get_global_mouse_position()
		if event.pressed:
			if _held:
				_release(_held.global_position - _grab_offset)
			_held = _bag_at(point)
			if _held:
				_moved = false
				_press = point
				_grab_offset = _held.global_position - point
				get_viewport().set_input_as_handled()
		elif _held:
			_release(point)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _held:
		var point := get_global_mouse_position()
		if not _moved and point.distance_to(_press) >= TAP_DISTANCE:
			_moved = true
			if not _held.locked:
				_held.lift()
				model.remove(_held.id)
				_update_outlines()
		if _moved and not _held.locked:
			_held.global_position = point + _grab_offset
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and _held:
		_release(_held.global_position - _grab_offset)


func _release(point: Vector2) -> void:
	var b := _held
	var was_drag := _moved
	_held = null
	_moved = false
	if b.locked:
		b.wiggle()
	elif not was_drag:
		_tap(b)
	else:
		b.global_position = point + _grab_offset
		_drop(b)


func _tap(b: Bag) -> void:
	if model.cell_of(b.id) != TrunkModel.NOWHERE:
		b.wiggle()
		return
	model.set_turned(b.id, not model.is_turned(b.id))
	b.set_turned(model.is_turned(b.id))
	b.glide_to(ground_point(b.id))


func _drop(b: Bag) -> void:
	var id := b.id
	if _try_place(id, b.global_position, model.is_turned(id)):
		_placed(b)
		return
	var turned := not model.is_turned(id)
	if _fits_at(id, b.global_position, turned):
		if Game.kid.trunk_auto_turn:
			model.set_turned(id, turned)
			b.set_turned(turned)
			_try_place(id, b.global_position, turned)
			_say("turn-it")
			_placed(b)
			return
		_say("turn-it")
	elif cargo_rect().grow(CELL / 2).has_point(b.global_position):
		_say("try-another-spot")
	b.glide_to(ground_point(id))


func _placed(b: Bag) -> void:
	var id := b.id
	b.glide_to(cell_center(model.cell_of(id), model.size_of(id, model.is_turned(id))))
	_update_outlines()
	if model.is_full():
		filled.emit()
		return
	_cheer += 1
	_say("it-fits" if _cheer % 2 == 1 else Voice.found_line())


## The cell a bag of that turn would sit at with its center at `center`.
func _cell_for(id: String, center: Vector2, turned: bool) -> Vector2i:
	var size := Vector2(model.size_of(id, turned))
	var top_left := (center - cargo_rect().position) / CELL - size / 2
	return Vector2i(roundi(top_left.x), roundi(top_left.y))


func _fits_at(id: String, center: Vector2, turned: bool) -> bool:
	var was := model.is_turned(id)
	model.set_turned(id, turned)
	var ok := model.can_place(id, _cell_for(id, center, turned))
	model.set_turned(id, was)
	return ok


func _try_place(id: String, center: Vector2, turned: bool) -> bool:
	if model.is_turned(id) != turned:
		return false
	return model.place(id, _cell_for(id, center, turned))


func _home_of(id: String) -> Vector2:
	var cell := model.cell_of(id)
	if cell == TrunkModel.NOWHERE:
		return ground_point(id)
	return cell_center(cell, model.size_of(id, model.is_turned(id)))


## Smallest bag under the point (small bags sit in front of big ones).
func _bag_at(point: Vector2) -> Bag:
	var best: Bag
	var best_area := INF
	for id in model.bag_ids:
		var b: Bag = _bags[id]
		var r := b.rect()
		if r.grow(GRAB_PADDING).has_point(point) and r.get_area() < best_area:
			best = b
			best_area = r.get_area()
	return best


func _say(line: String) -> void:
	Voice.say(line, Game.sibling())


func _add_outline(id: String, cell: Vector2i, turned: bool) -> void:
	var line := Line2D.new()
	line.name = id
	line.width = OUTLINE_WIDTH
	line.default_color = OUTLINE_COLOR
	line.closed = true
	line.set_meta("cell", cell)
	line.set_meta("turned", turned)
	_outlines.add_child(line)


func _update_outlines() -> void:
	for line: Line2D in _outlines.get_children():
		var id := String(line.name)
		var cell: Vector2i = line.get_meta("cell")
		var size := Vector2(model.size_of(id, line.get_meta("turned"))) * CELL
		var origin := cargo_rect().position + Vector2(cell) * CELL
		line.points = PackedVector2Array([origin, origin + Vector2(size.x, 0), origin + size, origin + Vector2(0, size.y)])
		line.visible = model.cell_of(id) == TrunkModel.NOWHERE


func _view() -> Rect2:
	var size := get_viewport().get_visible_rect().size
	return Rect2(Vector2(960, 540) - size / 2, size)


func _fit() -> void:
	var view := _view()
	_background.position = Vector2(960, 540)
	_background.scale = Vector2.ONE * maxf(view.size.x / BG_SIZE.x, view.size.y / BG_SIZE.y)
	var suv_size := _suv.texture.get_size() * _suv.scale
	_suv.position = Vector2(960, view.position.y + SUV_TOP_MARGIN + suv_size.y / 2)
	_helper.position = Vector2(960 - 260, view.end.y - 10)
	_play_home.position = view.position + Vector2(MARGIN, MARGIN)
	_play_home.size = Vector2.ONE * HOME_SIZE
	if not is_dragging():
		sync_bags()
