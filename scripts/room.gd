# A child's room for one level (one card row). Open the suitcase, then for
# each round tap the search spot (dresser, basket or toy box), find the row's
# four things, and pack them: rolled into a bundle (clothes) or one by one.
# Then close the lid, zip, and watch the done video. Whatever comes next
# pulses and the helper sibling says it out loud.
# Levels come from data/levels.json; positions from data/room_layout.json in
# background pixels; difficulty and outfit count from Game.kid.
extends Node2D

signal step_changed(step: Step)

enum Step { START, OPENED, FINDING, ROLL, PACK_BUNDLE, PACK_ITEMS, CLOSE, ZIP, DONE }

const LEVELS := "res://data/levels.json"
const LAYOUT := "res://data/room_layout.json"
const BG_SIZE := Vector2(1672, 941)
const CASE_CENTER := Vector2(768, 512)
const STAR_TEXTURE := preload("res://assets/art/star.png")
const ITEM_SCENE := preload("res://scenes/item.tscn")
const SPOT_OPEN := {
	"drawer": "res://assets/props/shared/open-drawer.png",
	"basket": "res://assets/props/shared/basket-open.png",
	"toybox": "res://assets/props/shared/toybox-open.png",
}
const SPOT_CLOSED := {
	"basket": "res://assets/props/shared/basket-closed.png",
	"toybox": "res://assets/props/shared/toybox-closed.png",
}
const STAR_COUNT := 8
const STAR_DISTANCE := 260.0
const STAR_TIME := 0.7
const FLY_TIME := 0.3
const REOPEN_DELAY := 0.8
const FINISH_DELAY := 0.8
const CUE_TIME := 0.45

var step := Step.START
var item_index := 0
## Which round (outfit) of this level is being packed.
var outfit_index := 0
## What's pulsing right now: "suitcase", "spot", "layup", "bundle", "items", "zipper" or "".
var cue := ""

var _layout: Dictionary
var _level: Dictionary
var _items: Array
var _rounds := 1
var _busy := false
var _idle := 0.0
var _hinting := false
var _cue_tween: Tween
var _loose: Array[Draggable] = []

@onready var _stage: Node2D = $Stage
@onready var _background: Sprite2D = $Stage/Background
@onready var _dresser_glow: Sprite2D = $Stage/DresserGlow
@onready var _spot: Sprite2D = $Stage/Spot
@onready var _suitcase: Node2D = $Stage/Suitcase
@onready var _back: Sprite2D = $Stage/Suitcase/Back
@onready var _packed: Node2D = $Stage/Suitcase/Packed
@onready var _front: Sprite2D = $Stage/Suitcase/Front
@onready var _closed: Sprite2D = $Stage/Suitcase/Closed
@onready var _zipper: Zipper = $Stage/Suitcase/Zipper
@onready var _pull: Sprite2D = $Stage/Suitcase/Zipper/Pull
@onready var _layup: Node2D = $Stage/Layup
@onready var _bundle: Draggable = $Stage/Bundle
@onready var _player: Character = $Stage/Player
@onready var _helper: Character = $Stage/Helper
@onready var _drawer_slide: Sprite2D = $Stage/DrawerSlide
@onready var _card: Card = $Card
@onready var _drawer: DrawerView = $DrawerView
@onready var _done_video: CanvasLayer = $DoneVideo
@onready var _done_player: VideoStreamPlayer = $DoneVideo/Player
@onready var _finish: Node2D = $Finish
@onready var _stars: Node2D = $Stars
@onready var _chime: AudioStreamPlayer = $Chime


static func cover_scale(view: Vector2, tex: Vector2) -> float:
	return maxf(view.x / tex.x, view.y / tex.y)


func _ready() -> void:
	_layout = JSON.parse_string(FileAccess.get_file_as_string(LAYOUT))
	var levels: Array = JSON.parse_string(FileAccess.get_file_as_string(LEVELS))
	_level = levels[clampi(Game.level, 0, levels.size() - 1)]
	_items = _level.items
	var kid := Game.kid
	_rounds = kid.outfits if str(_level.rounds) == "outfits" else int(_level.rounds)
	_background.texture = kid.room()
	_back.texture = kid.prop("suitcase-open-back")
	_front.texture = kid.prop("suitcase-open-front")
	_closed.texture = kid.prop("suitcase-closed")
	_bundle.texture = kid.prop("bundle")
	_card.kid = kid
	_player.kid = kid
	_helper.kid = Game.sibling()
	_suitcase.position = _bg("suitcase_center")
	_suitcase.scale = Vector2.ONE * _layout.suitcase_scale
	_zipper.start = _vec("zipper_start") - CASE_CENTER
	_zipper.end = _vec("zipper_end") - CASE_CENTER
	_pull.scale = Vector2.ONE * _layout.zipper_pull_scale
	_zipper.zipped.connect(_on_zipped)
	_player.position = _bg("player_feet")
	_player.height_scale = _layout.character_scale
	_helper.position = _bg("helper_feet")
	_helper.height_scale = _layout.character_scale
	_helper.mirrored = true
	_layup.position = _bg("layup_center")
	_drawer_slide.position = _bg("drawer_from")
	_drawer_slide.scale = Vector2.ONE * _layout.drawer_scale
	_place_dresser_glow()
	_spot.visible = _level.spot != "drawer"
	if _spot.visible:
		_spot.texture = load(SPOT_CLOSED[_level.spot])
		_spot.position = _bg("spot_center")
		_spot.scale = Vector2.ONE * _layout.spot_scale
	_bundle.placed.connect(_on_bundle_placed)
	_drawer.found.connect(on_found)
	_drawer.missed.connect(func(): _say("try-again"))
	_done_player.finished.connect(_show_finish)
	$Finish/ReplayButton.pressed.connect(replay)
	$Finish/HomeButton.pressed.connect(home)
	get_viewport().size_changed.connect(_fit)
	_fit()
	_set_open(false)
	_zipper.visible = false
	_put_bundle_away()
	_card.visible = false
	_finish.visible = false
	_done_video.visible = false
	_drawer_slide.visible = false
	_set_cue("suitcase")
	_say("open-suitcase")


# --- Steps -------------------------------------------------------------------

func tap_suitcase() -> void:
	if _busy:
		return
	if step == Step.START:
		_busy = true
		_set_cue("")
		_set_open(true)
		_card.visible = true
		var corner := _card.position
		_card.global_position = suitcase_point()
		_card.scale = Vector2.ONE * 0.02
		var t := create_tween().set_parallel()
		t.tween_property(_card, "position", corner, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.tween_property(_card, "scale", Vector2.ONE * _card_scale(), 0.5)
		t.chain().tween_callback(func():
			_card.highlight(0, Game.level)
			_busy = false
			_go(Step.OPENED))
	elif step == Step.CLOSE:
		_busy = true
		_set_cue("")
		_set_open(false)
		_zipper.reset()
		var rest := _closed.scale
		var t := create_tween()
		t.tween_property(_closed, "scale", rest * Vector2(1.06, 0.94), 0.1)
		t.tween_property(_closed, "scale", rest, 0.15)
		t.tween_callback(func():
			# Show the zipper only once it can count, or an early swipe zips it for nothing.
			_zipper.visible = true
			_busy = false
			_go(Step.ZIP))


## Opens the level's search spot: the dresser drawer, the basket or the toy box.
func tap_spot() -> void:
	if _busy or step != Step.OPENED:
		return
	_busy = true
	_set_cue("")
	var t := create_tween()
	if _level.spot == "drawer":
		_drawer_slide.visible = true
		_drawer_slide.position = _bg("drawer_from")
		t.tween_property(_drawer_slide, "position", _bg("drawer_from") + _vec("drawer_slide"), 0.3) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	else:
		var rest := _spot.scale
		t.tween_property(_spot, "scale", rest * Vector2(1.08, 0.92), 0.12)
		t.tween_property(_spot, "scale", rest, 0.18)
	t.tween_callback(func():
		_busy = false
		_open_drawer()
		_go(Step.FINDING))


## v0.2 name, kept for the drawer levels.
func tap_dresser() -> void:
	tap_spot()


func on_found(_item: String) -> void:
	if step != Step.FINDING or _busy:
		return
	_busy = true
	var texture := _drawer.correct_choice().texture
	var found_item: String = _items[item_index]
	_drawer.close()
	_say(Voice.found_line())
	var index := item_index
	var flyer := Sprite2D.new()
	flyer.texture = texture
	flyer.position = _layup.to_local(DrawerView.TARGET_CENTER)
	flyer.scale = Vector2.ONE * DrawerView.ITEM_SCALE / _stage.scale.x
	_layup.add_child(flyer)
	var t := create_tween().set_parallel()
	t.tween_property(flyer, "position", _vec("layup_step") * index, FLY_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(flyer, "scale", Vector2.ONE * _layout.layup_item_scale, FLY_TIME)
	t.chain().tween_callback(func():
		_card.stamp(index, Game.level)
		_chime.play()
		if found_item == _level.get("hug", ""):
			_player.hug()
		else:
			_player.cheer()
		_helper.clap()
		item_index += 1)
	if found_item == _level.get("hug", ""):
		t.tween_callback(func(): _say("hug-buddy"))
		t.tween_interval(Character.HUG_TIME)
	if index + 1 < _items.size():
		t.tween_callback(func(): _card.highlight(index + 1, Game.level))
		t.tween_interval(REOPEN_DELAY)
		t.tween_callback(func():
			_busy = false
			_open_drawer())
	else:
		t.tween_callback(func():
			_card.highlight(-1)
			_drawer_slide.visible = false)
		t.tween_interval(0.6)
		t.tween_callback(func():
			_busy = false
			if _level.roll:
				_go(Step.ROLL)
			else:
				_loosen_items()
				_go(Step.PACK_ITEMS))


func tap_layup() -> void:
	if _busy or step != Step.ROLL:
		return
	_busy = true
	_set_cue("")
	var t := create_tween().set_parallel()
	for piece in _layup.get_children():
		t.tween_property(piece, "position", Vector2.ZERO, 0.35)
		t.tween_property(piece, "modulate:a", 0.0, 0.35)
	t.chain().tween_callback(func():
		_clear_layup()
		_show_bundle(_bg("layup_center"))
		_busy = false
		_go(Step.PACK_BUNDLE))


func replay() -> void:
	Game.play_level(Game.level)


func home() -> void:
	Game.goto(Game.MAP)


## Things packed so far (bundles and single items).
func packed_count() -> int:
	return _packed.get_child_count()


func layout_value(key: String) -> Variant:
	return _layout[key]


## The items lying on the rug, waiting to be dragged into the suitcase (no-roll levels).
func loose_items() -> Array[Draggable]:
	return _loose.duplicate()


# --- Tap targets (global) ----------------------------------------------------

func suitcase_point() -> Vector2:
	return _suitcase.global_position


func spot_point() -> Vector2:
	return _spot_rect().get_center()


func dresser_point() -> Vector2:
	return spot_point()


func layup_point() -> Vector2:
	return _stage.to_global(_bg("layup_center"))


func hint_target() -> Vector2:
	match step:
		Step.START, Step.CLOSE:
			return suitcase_point()
		Step.OPENED:
			return spot_point()
		Step.ROLL:
			return layup_point()
		Step.PACK_BUNDLE:
			return _bundle.global_position
		Step.PACK_ITEMS:
			return _loose[0].global_position if not _loose.is_empty() else suitcase_point()
		Step.ZIP:
			return _pull.global_position
	return Vector2.INF


# --- Internals ---------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var point := get_global_mouse_position()
	match step:
		Step.START, Step.CLOSE:
			if _suitcase_rect().has_point(point):
				tap_suitcase()
		Step.OPENED:
			if _spot_rect().has_point(point):
				tap_spot()
		Step.ROLL:
			if _layup_rect().has_point(point):
				tap_layup()
		Step.DONE:
			if _done_video.visible:
				_show_finish()


func _input(event: InputEvent) -> void:
	if event is InputEventMouse:
		_reset_idle()


func _process(delta: float) -> void:
	if _busy or step == Step.FINDING or step == Step.DONE or _is_dragging():
		_idle = 0.0
		return
	_idle += delta
	if not _hinting and _idle >= Game.kid.hint_delay:
		_hinting = true
		_helper.point_at(hint_target())
		_say(_line_for(step))


func _reset_idle() -> void:
	_idle = 0.0
	if _hinting:
		_hinting = false
		_helper.set_pose("idle")


func _is_dragging() -> bool:
	if _bundle.is_dragging or _zipper.is_dragging:
		return true
	return _loose.any(func(d): return d.is_dragging)


func _go(next: Step) -> void:
	step = next
	_reset_idle()
	_set_cue(_cue_for(step))
	_say(_line_for(step))
	step_changed.emit(step)


func _say(line: String) -> void:
	if line != "":
		Voice.say(line, Game.sibling())


func _line_for(s: Step) -> String:
	match s:
		Step.START:
			return "open-suitcase"
		Step.OPENED:
			return {"drawer": "open-drawer", "basket": "open-basket", "toybox": "open-toybox"}[_level.spot]
		Step.ROLL:
			return "roll-it"
		Step.PACK_BUNDLE, Step.PACK_ITEMS:
			return "pack-it"
		Step.CLOSE:
			return "close-suitcase"
		Step.ZIP:
			return "zip-it"
	return ""


func _cue_for(s: Step) -> String:
	match s:
		Step.START, Step.CLOSE:
			return "suitcase"
		Step.OPENED:
			return "spot"
		Step.ROLL:
			return "layup"
		Step.PACK_BUNDLE:
			return "bundle"
		Step.PACK_ITEMS:
			return "items"
		Step.ZIP:
			return "zipper"
	return ""


## Pulses the thing to do next, and puts the last one back the way it was.
func _set_cue(next: String) -> void:
	if _cue_tween:
		_cue_tween.kill()
		_cue_tween = null
	_suitcase.scale = Vector2.ONE * _layout.suitcase_scale
	_layup.scale = Vector2.ONE
	_bundle.get_node("Sprite").scale = Vector2.ONE
	_pull.scale = Vector2.ONE * _layout.zipper_pull_scale
	if _level.spot != "drawer":
		_spot.scale = Vector2.ONE * _layout.spot_scale
	for d in _loose:
		d.get_node("Sprite").scale = Vector2.ONE
	_dresser_glow.visible = false
	cue = next
	if next == "":
		return
	var target: Node2D
	var grow := 1.08
	match next:
		"suitcase":
			target = _suitcase
			grow = 1.05
		"spot":
			if _level.spot != "drawer":
				target = _spot
			else:
				_dresser_glow.visible = true
				_dresser_glow.modulate.a = 1.0
				_cue_tween = create_tween().set_loops()
				_cue_tween.tween_property(_dresser_glow, "modulate:a", 0.25, CUE_TIME).set_trans(Tween.TRANS_SINE)
				_cue_tween.tween_property(_dresser_glow, "modulate:a", 1.0, CUE_TIME).set_trans(Tween.TRANS_SINE)
				return
		"layup":
			target = _layup
		"bundle":
			target = _bundle.get_node("Sprite")
			grow = 1.12
		"items":
			if _loose.is_empty():
				return
			target = _loose[0].get_node("Sprite")
			grow = 1.15
		"zipper":
			target = _pull
			grow = 1.3
	var rest := target.scale
	_cue_tween = create_tween().set_loops()
	_cue_tween.tween_property(target, "scale", rest * grow, CUE_TIME).set_trans(Tween.TRANS_SINE)
	_cue_tween.tween_property(target, "scale", rest, CUE_TIME).set_trans(Tween.TRANS_SINE)


func _open_drawer() -> void:
	var item: String = _items[item_index]
	var others: Array[String] = []
	if item in _level.get("locked", []):
		for other in _items:
			if other != item:
				others.append(other)
	_drawer.open(Game.kid, Game.sibling(), item, -1, load(SPOT_OPEN[_level.spot]), others)
	_say("find-" + item)


func _clear_layup() -> void:
	for piece in _layup.get_children():
		_layup.remove_child(piece)
		piece.queue_free()


func _suitcase_zone() -> Rect2:
	var zone := _sprite_rect(_back)
	return zone.grow_individual(-zone.size.x * 0.15, -zone.size.y * 0.15, -zone.size.x * 0.15, -zone.size.y * 0.15)


## No-roll levels: turns the found items on the rug into things to drag into the suitcase.
func _loosen_items() -> void:
	var zone := _suitcase_zone()
	var pieces := _layup.get_children()
	for i in pieces.size():
		var piece: Sprite2D = pieces[i]
		var item: Draggable = ITEM_SCENE.instantiate()
		item.texture = piece.texture
		item.home_scale = _layout.layup_item_scale
		item.drop_zone = zone
		item.snap_point = _suitcase.to_global(_packed_slot(i))
		_stage.add_child(item)
		item.global_position = piece.global_position
		item.home_position = item.global_position
		item.placed.connect(_on_item_packed)
		_loose.append(item)
	_clear_layup()


func _on_item_packed(item: Draggable) -> void:
	_loose.erase(item)
	_set_cue("")
	await get_tree().create_timer(Draggable.SNAP_TIME + 0.05).timeout
	var packed := Sprite2D.new()
	packed.texture = item.texture
	packed.scale = Vector2.ONE * _layout.layup_item_scale / _layout.suitcase_scale
	_packed.add_child(packed)
	packed.global_position = item.global_position
	item.queue_free()
	_chime.play()
	_player.cheer()
	if step != Step.PACK_ITEMS:
		return
	if _loose.is_empty():
		_round_done()
	else:
		_set_cue("items")


func _show_bundle(at: Vector2) -> void:
	_bundle.reset()
	_bundle.process_mode = Node.PROCESS_MODE_INHERIT
	_bundle.position = at
	_bundle.home_position = _bundle.global_position
	_bundle.home_scale = _layout.bundle_scale
	_bundle.visible = true
	_bundle.drop_zone = _suitcase_zone()
	_bundle.snap_point = _suitcase.to_global(_packed_slot(outfit_index))
	var pop := create_tween()
	_bundle.scale = Vector2.ZERO
	pop.tween_property(_bundle, "scale", Vector2.ONE * _layout.bundle_scale, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _put_bundle_away() -> void:
	_bundle.reset()
	_bundle.visible = false
	_bundle.process_mode = Node.PROCESS_MODE_DISABLED


func _packed_slot(index: int) -> Vector2:
	var slots: Array = _layout.packed_slots
	var v: Array = slots[index % slots.size()]
	return Vector2(v[0], v[1]) - CASE_CENTER


func _on_bundle_placed(_item: Draggable) -> void:
	if step != Step.PACK_BUNDLE:
		return
	_busy = true
	_set_cue("")
	await get_tree().create_timer(Draggable.SNAP_TIME + 0.05).timeout
	# Leave a picture of this outfit's bundle in the suitcase and reuse the draggable.
	var packed := Sprite2D.new()
	packed.texture = _bundle.texture
	packed.position = _packed_slot(outfit_index)
	packed.scale = Vector2.ONE * _layout.bundle_scale / _layout.suitcase_scale
	_packed.add_child(packed)
	_put_bundle_away()
	_player.cheer()
	_chime.play()
	_busy = false
	_round_done()


## One round packed: start the next one, or close up.
func _round_done() -> void:
	if outfit_index + 1 < _rounds:
		outfit_index += 1
		item_index = 0
		_card.clear()
		_card.highlight(0, Game.level)
		_go(Step.OPENED)
	else:
		_go(Step.CLOSE)


func _on_zipped() -> void:
	if step != Step.ZIP:
		_zipper.reset()
		return
	Progress.mark_done(Game.kid.id, Game.level)
	_go(Step.DONE)
	_player.cheer()
	_helper.cheer()
	_chime.play()
	for i in STAR_COUNT:
		_spawn_star(TAU * i / STAR_COUNT)
	var t := create_tween()
	t.tween_interval(FINISH_DELAY)
	t.tween_callback(_play_done_video)


func _play_done_video() -> void:
	var path := Game.kid.done_video
	if path == "" or not ResourceLoader.exists(path):
		_show_finish()
		return
	_done_player.stream = load(path)
	_done_video.visible = true
	_done_player.play()


func _show_finish() -> void:
	if _finish.visible:
		return
	_done_player.stop()
	_done_video.visible = false
	_finish.visible = true


func _spawn_star(angle: float) -> void:
	var star := Sprite2D.new()
	star.texture = STAR_TEXTURE
	var from := suitcase_point()
	star.global_position = from
	_stars.add_child(star)
	var t := create_tween().set_parallel()
	t.tween_property(star, "global_position", from + Vector2.from_angle(angle) * STAR_DISTANCE, STAR_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(star, "modulate:a", 0.0, STAR_TIME)
	t.chain().tween_callback(star.queue_free)


func _set_open(open: bool) -> void:
	_back.visible = open
	_packed.visible = open
	_front.visible = open
	_closed.visible = not open


## Scales the room to cover the visible screen and pins the card to its corner.
func _fit() -> void:
	var view := get_viewport().get_visible_rect().size
	var cover := cover_scale(view, BG_SIZE)
	_stage.position = Vector2(960, 540)
	_stage.scale = Vector2.ONE * cover
	var visible_rect := Rect2(Vector2(960, 540) - view / 2, view)
	var margin: float = _layout.card_margin
	var card_size := Vector2(1200, 1600) * _card_scale()
	_card.position = Vector2(visible_rect.end.x - margin - card_size.x, visible_rect.position.y + margin)
	if not _card.visible:
		_card.scale = Vector2.ONE * _card_scale()


func _place_dresser_glow() -> void:
	var v: Array = _layout.dresser_rect
	var pad: float = _layout.dresser_glow_padding
	var rect := Rect2(v[0] - pad, v[1] - pad, v[2] + pad * 2, v[3] + pad * 2)
	_dresser_glow.position = rect.get_center() - BG_SIZE / 2
	_dresser_glow.scale = rect.size / _dresser_glow.texture.get_size()


func _card_scale() -> float:
	return _layout.card_scale


## Background pixel -> stage-local point (stage origin is the image center).
func _bg(key: String) -> Vector2:
	return _vec(key) - BG_SIZE / 2


func _vec(key: String) -> Vector2:
	var v: Array = _layout[key]
	return Vector2(v[0], v[1])


func _sprite_rect(sprite: Sprite2D) -> Rect2:
	var r := sprite.get_rect()
	var a := sprite.global_transform * r.position
	return Rect2(a, Vector2.ZERO).expand(sprite.global_transform * r.end)


func _suitcase_rect() -> Rect2:
	return _sprite_rect(_closed if _closed.visible else _back)


## The level's search spot: the dresser for drawer levels, else the basket/toy box prop.
func _spot_rect() -> Rect2:
	if _level.spot != "drawer":
		return _sprite_rect(_spot)
	var v: Array = _layout.dresser_rect
	var a := _stage.to_global(Vector2(v[0], v[1]) - BG_SIZE / 2)
	var b := _stage.to_global(Vector2(v[0] + v[2], v[1] + v[3]) - BG_SIZE / 2)
	return Rect2(a, b - a)


func _layup_rect() -> Rect2:
	var half := Vector2(150, 110) * _stage.scale
	return Rect2(layup_point() - half, half * 2)
