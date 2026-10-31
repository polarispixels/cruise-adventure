# Airport, Through security: the kid's things wait on the floor. The child
# drags each into a gray tray, taps a tray to push it through the scanner (the
# screen above shows what's inside as friendly blue shapes), walks through the
# arch when everything is through, then puts everything back: things into the
# backpack, the buddy into their arms for a hug. In Jack-Jack's version the
# tablet needs a tray of its own. Nothing else can go wrong.
extends Node2D

const BG_SIZE := Vector2(1672, 941)
## The 16:10 tablet crops the 16:9 background's sides; keep everything between these x values.
const SAFE_X := Vector2(100, 1572)
## How tall each thing is on the floor and in a tray, in background pixels.
const FLOOR_HEIGHT := 150.0
const TRAY_ITEM_HEIGHT := 64.0
const FLOOR_Y := 860.0
const FLOOR_X := [200.0, 380.0, 560.0, 740.0]
const TRAYS := 3
const TRAY_SCALE := 0.21
const TRAY_BASELINE := 434.0
const LEFT_TRAY_X := [168.0, 300.0, 432.0]
const RIGHT_TRAY_X := [990.0, 1110.0, 1230.0]
const SCANNER_X := 696.0
const SCREEN := Rect2(564, 132, 284, 132)
const ARCH := Rect2(1366, 196, 160, 344)
const DROP_SLACK := 70.0
const SCAN_TIME := 1.4
const SLIDE_TIME := 0.5
const WALK_TIME := 1.2
const GLIDE_TIME := 0.3
const DONE_DELAY := 1.6
const PLAYER_START := Vector2(1290, 600)
const PLAYER_THROUGH := Vector2(1446, 560)
const HELPER_FEET := Vector2(1510, 920)
const KID_SCALE := 0.16
const BACKPACK_SPOT := Vector2(1250, 820)
const SILHOUETTE := Color(0.35, 0.65, 1.0, 0.75)

## "trays" (loading and scanning), "arch" (everything's through), "collect", "done".
var phase := "trays"

var _ids: Array[String] = []
var _items := {}
var _home := {}
var _trays: Array[Sprite2D] = []
var _tray_items: Array = []
var _tray_sent: Array[bool] = []
var _scanning := 0
var _collected: Array[String] = []
var _held: Sprite2D
var _offset := Vector2.ZERO
var _told_push := false
var _idle := 0.0

@onready var _stage: Node2D = $Stage
@onready var _tray_layer: Node2D = $Stage/Trays
@onready var _item_layer: Node2D = $Stage/Items
@onready var _screen: Node2D = $Stage/Screen
@onready var _player: Character = $Stage/Player
@onready var _helper: Character = $Stage/Helper
@onready var _play_home: TextureButton = $PlayHome


func _ready() -> void:
	var kid := Game.kid
	_ids.append_array(kid.security_items)
	for i in TRAYS:
		var tray := Sprite2D.new()
		tray.texture = load("res://assets/airport/tray-empty.png")
		tray.scale = Vector2.ONE * TRAY_SCALE
		tray.position = Vector2(LEFT_TRAY_X[i], TRAY_BASELINE - tray.texture.get_size().y * TRAY_SCALE / 2)
		_tray_layer.add_child(tray)
		_trays.append(tray)
		_tray_items.append([] as Array[String])
		_tray_sent.append(false)
	var ids := item_ids()
	for i in ids.size():
		var item := Sprite2D.new()
		item.name = ids[i]
		item.texture = _texture(ids[i])
		_set_height(item, FLOOR_HEIGHT)
		item.position = Vector2(FLOOR_X[i], FLOOR_Y - FLOOR_HEIGHT / 2)
		_item_layer.add_child(item)
		_items[ids[i]] = item
		_home[item] = item.position
	_player.kid = kid
	_player.height_scale = KID_SCALE
	_player.position = PLAYER_START
	_helper.kid = Game.sibling()
	_helper.height_scale = KID_SCALE
	_helper.mirrored = true
	_helper.position = HELPER_FEET
	_play_home.pressed.connect(func(): Game.goto(Game.TITLE))
	get_viewport().size_changed.connect(_fit)
	_fit()
	_say("in-a-tray")


func item_ids() -> Array[String]:
	return _ids


func tray_items(i: int) -> Array[String]:
	return _tray_items[i]


func tray_sent(i: int) -> bool:
	return _tray_sent[i]


func item_point(id: String) -> Vector2:
	return _stage.to_global(_items[id].position)


func tray_point(i: int) -> Vector2:
	return _stage.to_global(_trays[i].position)


func arch_point() -> Vector2:
	return _stage.to_global(ARCH.get_center())


func backpack_point() -> Vector2:
	return _stage.to_global(BACKPACK_SPOT)


func kid_point() -> Vector2:
	return _player.hit_rect().get_center()


## This part of the airport is finished: on to the gate maze.
func done() -> void:
	Game.goto(Game.MAZE)


func _texture(id: String) -> Texture2D:
	if id == "tablet" or id == "buddy":
		return Game.kid.prop(id + "-card")
	return load("res://assets/car/bag-%s.png" % id)


func _set_height(item: Sprite2D, height: float) -> void:
	item.scale = Vector2.ONE * height / item.texture.get_size().y


func _backpack_id() -> String:
	for id in item_ids():
		if id.ends_with("-backpack"):
			return id
	return ""


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton or event is InputEventMouseMotion):
		return
	var local := _stage.to_local(get_global_mouse_position())
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_held = _pick(local)
			if _held:
				_offset = _held.position - local
				_held.z_index = 10
				get_viewport().set_input_as_handled()
				return
			_tap(local)
		elif _held:
			var held := _held
			_held = null
			held.z_index = 0
			_drop(held)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _held:
		_held.position = local + _offset
		get_viewport().set_input_as_handled()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_idle = 0.0


func _process(delta: float) -> void:
	if phase == "done":
		return
	_idle += delta
	if _idle >= Game.kid.hint_delay:
		_idle = 0.0
		_hint()


## What a press picks up: a thing on the floor (loading), or one waiting on the far table (collecting).
func _pick(local: Vector2) -> Sprite2D:
	for id in item_ids():
		var item: Sprite2D = _items[id]
		if not item.visible or not _rect(item).grow(20).has_point(local):
			continue
		if phase == "trays" and _tray_of(id) < 0:
			return item
		if phase == "collect" and id != _backpack_id() and not _collected.has(id):
			return item
	return null


func _tap(local: Vector2) -> void:
	if phase == "trays":
		var i := _nearest_tray(local, 40.0)
		if i >= 0 and not _tray_items[i].is_empty():
			_scan(i)
	elif phase == "arch" and ARCH.grow(40).has_point(local):
		_walk_through()


func _drop(item: Sprite2D) -> void:
	var id := String(item.name)
	if phase == "collect":
		_collect(item, id)
		return
	var i := _nearest_tray(item.position, DROP_SLACK)
	if i >= 0:
		_put_in_tray(id, i)
		return
	_glide(item, _home[item])


func _put_in_tray(id: String, i: int) -> void:
	if Game.kid.tablet_own_tray:
		var has_tablet: bool = _tray_items[i].has("tablet")
		if (id == "tablet" and not _tray_items[i].is_empty()) or (id != "tablet" and has_tablet):
			var other := _free_tray(id)
			if other >= 0:
				_say("tablet-tray")
				i = other
	_tray_items[i].append(id)
	Sfx.play("tray-slide")
	_arrange(i)
	if not _told_push:
		_told_push = true
		_say("push-it", true)


## The closest tray still on the left table whose (grown) area holds the point; -1 if none.
func _nearest_tray(local: Vector2, slack: float) -> int:
	var best := -1
	for i in TRAYS:
		if _tray_sent[i] or not _rect(_trays[i]).grow(slack).has_point(local):
			continue
		if best < 0 or local.distance_to(_trays[i].position) < local.distance_to(_trays[best].position):
			best = i
	return best


## Another tray for an item the tablet rule moved: an empty one, else one without the tablet.
func _free_tray(id: String) -> int:
	for i in TRAYS:
		if not _tray_sent[i] and _tray_items[i].is_empty():
			return i
	if id != "tablet":
		for i in TRAYS:
			if not _tray_sent[i] and not _tray_items[i].has("tablet"):
				return i
	return -1


## Lines the tray's things up inside it.
func _arrange(i: int) -> void:
	var tray := _trays[i]
	var ids: Array[String] = _tray_items[i]
	for k in ids.size():
		var item: Sprite2D = _items[ids[k]]
		_set_height(item, TRAY_ITEM_HEIGHT)
		var x := tray.position.x + (k - (ids.size() - 1) / 2.0) * 34.0
		_glide(item, Vector2(x, TRAY_BASELINE - 8 - TRAY_ITEM_HEIGHT / 2))


func _scan(i: int) -> void:
	_tray_sent[i] = true
	_scanning += 1
	var tray := _trays[i]
	var ids: Array[String] = _tray_items[i]
	var into := Vector2(SCANNER_X, tray.position.y)
	var out := Vector2(RIGHT_TRAY_X[_sent_count() - 1], tray.position.y)
	var t := create_tween()
	t.tween_callback(func(): Sfx.play("belt"))
	t.tween_method(func(p: Vector2): _move_tray(i, p), tray.position, into, SLIDE_TIME)
	t.tween_callback(func(): _show_on_screen(ids))
	t.tween_interval(SCAN_TIME - 2 * SLIDE_TIME)
	t.tween_callback(func(): _screen_clear())
	t.tween_method(func(p: Vector2): _move_tray(i, p), into, out, SLIDE_TIME)
	t.tween_callback(func(): _scanned())


func _move_tray(i: int, p: Vector2) -> void:
	var tray := _trays[i]
	var d := p - tray.position
	tray.position = p
	for id in _tray_items[i]:
		_items[id].position += d


func _show_on_screen(ids: Array[String]) -> void:
	Sfx.play("scanner-chime")
	for k in ids.size():
		var shape := Sprite2D.new()
		shape.texture = _items[ids[k]].texture
		shape.modulate = SILHOUETTE
		shape.scale = Vector2.ONE * (SCREEN.size.y * 0.7) / shape.texture.get_size().y
		shape.position = SCREEN.get_center() + Vector2((k - (ids.size() - 1) / 2.0) * SCREEN.size.x / 3.2, 0)
		_screen.add_child(shape)
	if ids.has("buddy"):
		_say("comes-back")


func _screen_clear() -> void:
	for n in _screen.get_children():
		n.free()


func _scanned() -> void:
	_scanning -= 1
	var all_through := true
	for id in item_ids():
		var tray := _tray_of(id)
		if tray < 0 or not _tray_sent[tray]:
			all_through = false
	if all_through and _scanning == 0 and phase == "trays":
		phase = "arch"
		_say("walk-through", true)


func _sent_count() -> int:
	return _tray_sent.count(true)


func _walk_through() -> void:
	phase = "walking"
	_player.set_pose("arms-up")
	Sfx.play("arch-chime")
	var t := create_tween()
	t.tween_property(_player, "position", PLAYER_THROUGH, WALK_TIME)
	t.tween_callback(_start_collecting)


func _start_collecting() -> void:
	phase = "collect"
	var backpack: Sprite2D = _items[_backpack_id()]
	_set_height(backpack, FLOOR_HEIGHT)
	_glide(backpack, BACKPACK_SPOT)
	_say("get-your-things")


func _collect(item: Sprite2D, id: String) -> void:
	if id == "buddy":
		if _player.hit_rect().grow(40).has_point(get_global_mouse_position()) or _player.hit_rect().grow(40).has_point(_stage.to_global(item.position)):
			item.visible = false
			_collected.append(id)
			_player.hug()
			_say("hug-buddy")
			_check_collected()
			return
	elif Rect2(BACKPACK_SPOT - Vector2(90, 90), Vector2(180, 180)).grow(DROP_SLACK).has_point(item.position):
		item.visible = false
		_collected.append(id)
		Sfx.play("tag-snap")
		_check_collected()
		return
	_glide(item, _tray_spot(id))


func _tray_spot(id: String) -> Vector2:
	var i := _tray_of(id)
	var k: int = _tray_items[i].find(id)
	var n: int = _tray_items[i].size()
	return Vector2(_trays[i].position.x + (k - (n - 1) / 2.0) * 34.0, TRAY_BASELINE - 8 - TRAY_ITEM_HEIGHT / 2)


func _check_collected() -> void:
	if _collected.size() < item_ids().size() - 1:
		return
	phase = "done"
	_helper.cheer()
	get_tree().create_timer(DONE_DELAY).timeout.connect(func():
		if is_inside_tree():
			done())


func _tray_of(id: String) -> int:
	for i in TRAYS:
		if _tray_items[i].has(id):
			return i
	return -1


func _hint() -> void:
	match phase:
		"trays":
			for id in item_ids():
				if _tray_of(id) < 0:
					_helper.point_at(item_point(id))
					_say("in-a-tray")
					return
			for i in TRAYS:
				if not _tray_sent[i] and not _tray_items[i].is_empty():
					_helper.point_at(tray_point(i))
					_say("push-it")
					return
		"arch":
			_helper.point_at(arch_point())
			_say("walk-through")
		"collect":
			for id in item_ids():
				if id != _backpack_id() and not _collected.has(id):
					_helper.point_at(item_point(id))
					_say("get-your-things")
					return


func _rect(sprite: Sprite2D) -> Rect2:
	var size := sprite.texture.get_size() * sprite.scale
	return Rect2(sprite.position - size / 2, size)


func _glide(item: Sprite2D, to: Vector2) -> void:
	create_tween().tween_property(item, "position", to, GLIDE_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _say(line: String, wait := false) -> void:
	Voice.say(line, Game.sibling(), wait)


func _fit() -> void:
	var view := get_viewport().get_visible_rect().size
	var s := maxf(view.x / BG_SIZE.x, view.y / BG_SIZE.y)
	_stage.scale = Vector2.ONE * s
	_stage.position = Vector2(960, 540) - BG_SIZE * s / 2
	_play_home.position = Vector2(960, 540) - view / 2 + Vector2(24, 24)
	_play_home.size = Vector2.ONE * 130.0
