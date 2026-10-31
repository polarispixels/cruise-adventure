# Airport, Goodbye suitcases: the big bags wait on the terminal floor with a
# colored tag for each. The child drags each tag onto the bag of the same color,
# then drags the tagged bag onto the scale. It lifts onto the belt and rides
# away through the rubber flaps. A wrong tag wiggles back; an untagged bag
# slides back and the helper says it needs a tag. Becca has fewer bags; Mommy's
# duffel goes on by itself. When every bag is gone the kids wave goodbye.
extends Node2D

const BG_SIZE := Vector2(1672, 941)
## The 16:10 tablet crops the 16:9 background's sides; keep everything between these x values.
const SAFE_X := Vector2(100, 1572)
const BAG_SCALE := 0.45
const TAG_SCALE := 0.45
const FLOOR_Y := 880.0
## Where each bag waits on the floor (center x), in background pixels.
const FLOOR_X := [220.0, 520.0, 880.0]
const TAG_Y := 760.0
const TAG_X := [1090.0, 1190.0, 1290.0]
const TAG_COLOR := {"jack-suitcase": "blue", "becca-suitcase": "pink", "mommy-yellow": "yellow"}
const SCALE_DROP := Rect2(620, 435, 196, 83)
const SCALE_TOP_Y := 485.0
const SCALE_X := 718.0
const BELT := Rect2(805, 397, 810, 42)
const BELT_BASELINE := 438.0
const FLAPS_X := 1440.0
const RIDE_TIME := 1.8
const DROP_SLACK := 80.0
const BELT_SPEED := 120.0
const GLIDE_TIME := 0.3
const AUTO_DELAY := 0.8
const WAVE_TIME := 2.5
const PLAYER_FEET := Vector2(1400, 900)
const HELPER_FEET := Vector2(1500, 900)
const KID_SCALE := 0.16

var _bags := {}
var _tags := {}
var _home := {}
var _tagged := {}
var _sent: Array[String] = []
var _riding := 0
var _held: Sprite2D
var _offset := Vector2.ZERO
var _idle := 0.0
var _finishing := false

@onready var _stage: Node2D = $Stage
@onready var _bag_layer: Node2D = $Stage/Bags
@onready var _tag_layer: Node2D = $Stage/Tags
@onready var _belt: Sprite2D = $Stage/Belt
@onready var _player: Character = $Stage/Player
@onready var _helper: Character = $Stage/Helper
@onready var _play_home: TextureButton = $PlayHome


func _ready() -> void:
	Music.want(Music.AIRPORT)
	var kid := Game.kid
	var ids := bag_ids()
	for i in ids.size():
		var id := ids[i]
		var bag := Sprite2D.new()
		bag.name = id
		bag.texture = load("res://assets/car/bag-%s.png" % id)
		bag.scale = Vector2.ONE * BAG_SCALE
		bag.position = Vector2(FLOOR_X[i], FLOOR_Y - bag.texture.get_size().y * BAG_SCALE / 2)
		_bag_layer.add_child(bag)
		_bags[id] = bag
		_home[bag] = bag.position
	var colors: Array[String] = []
	for id in kid.airport_bags:
		colors.append(TAG_COLOR[id])
	colors.reverse()
	for i in colors.size():
		_tags[colors[i]] = _make_tag(colors[i], Vector2(TAG_X[i], TAG_Y))
	_player.kid = kid
	_player.height_scale = KID_SCALE
	_player.position = PLAYER_FEET
	_helper.kid = Game.sibling()
	_helper.height_scale = KID_SCALE
	_helper.mirrored = true
	_helper.position = HELPER_FEET
	_play_home.pressed.connect(func(): Game.goto(Game.TITLE))
	get_viewport().size_changed.connect(_fit)
	_fit()
	_say("tag-bags")
	for id in kid.airport_auto_bags:
		get_tree().create_timer(AUTO_DELAY).timeout.connect(func(): _auto_send(id))


## The bags on the floor: the kid's own to tag, then any that go by themselves.
func bag_ids() -> Array[String]:
	var out: Array[String] = []
	out.append_array(Game.kid.airport_bags)
	out.append_array(Game.kid.airport_auto_bags)
	return out


func tag_colors() -> Array:
	return _tags.keys()


func is_tagged(id: String) -> bool:
	return _tagged.has(id)


func sent() -> Array[String]:
	return _sent


func bag_point(id: String) -> Vector2:
	return _stage.to_global(_bags[id].position)


func tag_point(color: String) -> Vector2:
	return _stage.to_global(_tags[color].position)


func scale_point() -> Vector2:
	return _stage.to_global(SCALE_DROP.get_center())


func _exit_tree() -> void:
	Music.want(Music.THEME)


## This part of the airport is finished: on to security.
func done() -> void:
	Game.goto(Game.SECURITY)


func _make_tag(color: String, at: Vector2) -> Sprite2D:
	var tag := Sprite2D.new()
	tag.name = "tag-" + color
	tag.texture = load("res://assets/airport/tag-%s.png" % color)
	tag.scale = Vector2.ONE * TAG_SCALE
	tag.position = at
	_tag_layer.add_child(tag)
	_home[tag] = at
	return tag


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var local := _stage.to_local(get_global_mouse_position())
		if event.pressed:
			_held = _pick(local)
			if _held:
				_offset = _held.position - local
				_held.z_index = 10
				get_viewport().set_input_as_handled()
		elif _held:
			var held := _held
			_held = null
			held.z_index = 0
			_drop(held)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _held:
		_held.position = _stage.to_local(get_global_mouse_position()) + _offset
		get_viewport().set_input_as_handled()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_idle = 0.0


func _process(delta: float) -> void:
	for id in _tagged:
		var bag: Sprite2D = _bags[id]
		var tag: Sprite2D = _tagged[id]
		tag.position = bag.position + Vector2(0, -bag.texture.get_size().y * BAG_SCALE / 2 + 20)
		tag.visible = bag.visible
	if _riding > 0:
		_belt.region_rect.position.x -= BELT_SPEED * delta
	if _finishing:
		return
	_idle += delta
	if _idle >= Game.kid.hint_delay:
		_idle = 0.0
		_hint()


## A free tag first (they're smaller and sit on top), then a bag on the floor.
func _pick(local: Vector2) -> Sprite2D:
	for color in _tags:
		var tag: Sprite2D = _tags[color]
		if not _tagged.values().has(tag) and _rect(tag).grow(20).has_point(local):
			return tag
	for id in Game.kid.airport_bags:
		var bag: Sprite2D = _bags[id]
		if not _sent.has(id) and _riding_bag(bag) == false and _rect(bag).grow(20).has_point(local):
			return bag
	return null


func _drop(item: Sprite2D) -> void:
	if _tags.values().has(item):
		var color := String(item.name).trim_prefix("tag-")
		for id in Game.kid.airport_bags:
			if not _tagged.has(id) and _rect(_bags[id]).grow(DROP_SLACK / 2).has_point(item.position):
				if TAG_COLOR[id] == color:
					_tagged[id] = item
					Sfx.play("tag-snap")
					_say("on-the-belt")
					return
				_wiggle_home(item)
				return
		_glide(item, _home[item])
		return
	var id := String(item.name)
	if SCALE_DROP.grow(DROP_SLACK).has_point(item.position):
		if _tagged.has(id):
			_ride(id)
			return
		_say("needs-tag")
	_glide(item, _home[item])


func _auto_send(id: String) -> void:
	if not is_inside_tree():
		return
	_tagged[id] = _make_tag(TAG_COLOR[id], _bags[id].position)
	_ride(id)


## Onto the scale, up onto the belt, along it and through the flaps.
func _ride(id: String) -> void:
	var bag: Sprite2D = _bags[id]
	var half := bag.texture.get_size().y * BAG_SCALE / 2
	_riding += 1
	bag.set_meta("riding", true)
	var t := create_tween()
	t.tween_property(bag, "position", Vector2(SCALE_X, SCALE_TOP_Y - half), GLIDE_TIME)
	t.tween_callback(func(): Sfx.play("thump"))
	t.tween_property(bag, "position", Vector2(BELT.position.x + 120, BELT_BASELINE - half), 0.35)
	t.tween_callback(func(): Sfx.play("belt"))
	t.tween_property(bag, "position:x", FLAPS_X + 120, RIDE_TIME)
	t.tween_callback(func(): _gone(id))


func _gone(id: String) -> void:
	_riding -= 1
	_bags[id].visible = false
	Sfx.play("flaps")
	_sent.append(id)
	if _sent.size() == bag_ids().size():
		_goodbye()


func _goodbye() -> void:
	_finishing = true
	_say("bye-suitcases", true)
	_player.wave()
	_helper.wave()
	get_tree().create_timer(WAVE_TIME).timeout.connect(func():
		if is_inside_tree():
			done())


func _hint() -> void:
	for id in Game.kid.airport_bags:
		if _sent.has(id) or _riding_bag(_bags[id]):
			continue
		if not _tagged.has(id):
			_helper.point_at(tag_point(TAG_COLOR[id]))
			_say("tag-bags")
		else:
			_helper.point_at(bag_point(id))
			_say("on-the-belt")
		return


func _riding_bag(bag: Sprite2D) -> bool:
	return bag.has_meta("riding")


func _rect(sprite: Sprite2D) -> Rect2:
	var size := sprite.texture.get_size() * sprite.scale
	return Rect2(sprite.position - size / 2, size)


func _glide(item: Sprite2D, to: Vector2) -> void:
	create_tween().tween_property(item, "position", to, GLIDE_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _wiggle_home(item: Sprite2D) -> void:
	var t := create_tween()
	for i in 3:
		t.tween_property(item, "rotation", 0.15, 0.05)
		t.tween_property(item, "rotation", -0.15, 0.05)
	t.tween_property(item, "rotation", 0.0, 0.03)
	t.tween_property(item, "position", _home[item], GLIDE_TIME)


func _say(line: String, wait := false) -> void:
	Voice.say(line, Game.sibling(), wait)


func _fit() -> void:
	var view := get_viewport().get_visible_rect().size
	var s := maxf(view.x / BG_SIZE.x, view.y / BG_SIZE.y)
	_stage.scale = Vector2.ONE * s
	_stage.position = Vector2(960, 540) - BG_SIZE * s / 2
	_play_home.position = Vector2(960, 540) - view / 2 + Vector2(24, 24)
	_play_home.size = Vector2.ONE * 130.0
