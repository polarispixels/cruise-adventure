# The journey map. The child's own card fills the middle: finished rows wear a
# big check, the next row pulses, and tapping a finished or next row plays it.
# Once the card is packed, the trip's stops (chapter 7 on, from
# data/chapters.json) appear one at a time along a route around the card: the
# SUV, the boarding pass, then a stop icon per chapter. The next stop wiggles,
# finished stops wear a check and replay. Later rows and stops stay locked.
# As a segment with "finale": true, it lights up the whole route and goes on.
extends Node2D

const BG_SIZE := Vector2(1672, 941)
const CARD_SIZE := Vector2(1200, 1600)
const MARGIN := 24.0
const HELPER_SCALE := 0.35
const HELPER_MARGIN := Vector2(150, 24)
const HOME_SIZE := 150.0
## The car button (shown once the card is packed) is this tall, beside the card.
const CAR_HEIGHT := 260.0
const AIRPORT_GAP := 30.0
## Later stops' icons are this big.
const STOP_SIZE := 150.0
## The first three stops sit down the left of the card at these heights (share of the view).
const LEFT_SLOTS: Array[float] = [0.2, 0.5, 0.8]
## The first journey chapter number on the map.
const FIRST_STOP := 7
const CHECK_TEXTURE := preload("res://assets/props/shared/check-mark.png")
const CHECK_SIZE := 90.0
const WIGGLE_ANGLE := 0.12
const WIGGLE_TIME := 0.25
const ROUTE_DIM := Color(1, 1, 1, 0.45)
const ROUTE_LIT := Color(1.0, 0.85, 0.2, 1)
## The finale: one stop lights up every this many seconds, then the chapter goes on.
const LIGHT_STEP := 0.35
const FINALE_HOLD := 2.0

var _started := false
var _idle := 0.0
## Chapter ids of the stops, in route order, and their buttons.
var stop_ids: Array[String] = []
var _stops: Dictionary = {}
var _wiggle: Tween

@onready var _background: Sprite2D = $Background
@onready var _dim: Sprite2D = $Dim
@onready var _card: Card = $Card
@onready var _helper: Character = $Helper
@onready var _home: TextureButton = $HomeButton
@onready var _car: TextureButton = $CarButton
@onready var _airport: TextureButton = $AirportButton
@onready var _route: Line2D = $Route


func _ready() -> void:
	var kid := Game.kid
	_background.texture = kid.room()
	_card.kid = kid
	_helper.kid = Game.sibling()
	_helper.height_scale = HELPER_SCALE
	_helper.mirrored = true
	_home.pressed.connect(func(): Game.goto(Game.TITLE))
	_make_stops()
	var done := Progress.levels_done(kid.id)
	for row in Progress.LEVELS:
		if done.has(row):
			_card.stamp_row(row)
	_card.highlight_row(Progress.next_level(kid.id))
	Voice.say(_line(), Game.sibling())
	get_viewport().size_changed.connect(_fit)
	_fit()
	if Game.playing() and Game.segment.get("finale", false):
		_started = true
		light_up_route()


## The stops, in order: chapters from FIRST_STOP on that are built (have segments).
func _make_stops() -> void:
	var kid_id := Game.kid.id
	var unlocked := Progress.next_level(kid_id) >= Progress.LEVELS
	var next_found := false
	for c: Dictionary in Game.chapters():
		if int(c.get("number", 0)) < FIRST_STOP or c.get("dropped", false) or (c.get("segments", []) as Array).is_empty():
			continue
		var id: String = c["id"]
		var button: TextureButton
		if id == "car":
			button = _car
		elif id == "airport":
			button = _airport
		else:
			button = TextureButton.new()
			button.name = "Stop-" + id
			var icon := "res://assets/map/stop-%s.png" % id
			if ResourceLoader.exists(icon):
				button.texture_normal = load(icon)
			button.ignore_texture_size = true
			button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
			add_child(button)
		stop_ids.append(id)
		_stops[id] = button
		var done := Progress.chapter_done(kid_id, id)
		button.visible = done or unlocked
		button.pressed.connect(_on_stop.bind(id))
		if done:
			var check := TextureRect.new()
			check.name = "Check"
			check.texture = CHECK_TEXTURE
			check.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			check.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			check.mouse_filter = Control.MOUSE_FILTER_IGNORE
			button.add_child(check)
		elif unlocked and not next_found:
			next_found = true
			_start_wiggle(button)
		unlocked = done


## The stop button for chapter `id`, or null.
func stop_button(id: String) -> TextureButton:
	return _stops.get(id)


## Global center of a stop, for taps in tests.
func stop_point(id: String) -> Vector2:
	var b := stop_button(id)
	return b.global_position + b.size / 2 if b else Vector2.ZERO


## The stop that wiggles (the next chapter to play), or "".
func next_stop() -> String:
	for id in stop_ids:
		if (_stops[id] as TextureButton).visible and not Progress.chapter_done(Game.kid.id, id):
			return id
	return ""


## The finale: every stop shows and lights up in turn along a golden route.
## As a finale segment, the chapter goes on after.
func light_up_route() -> void:
	if _wiggle and _wiggle.is_valid():
		_wiggle.kill()
	_route.default_color = ROUTE_LIT
	var t := create_tween()
	for id in stop_ids:
		var b: TextureButton = _stops[id]
		b.visible = true
		b.rotation = 0.0
		t.tween_callback(func(): b.modulate = Color(1.4, 1.3, 0.8))
		t.tween_property(b, "scale", Vector2.ONE * 1.15, LIGHT_STEP / 2)
		t.tween_property(b, "scale", Vector2.ONE, LIGHT_STEP / 2)
	_fit()
	if Game.playing() and Game.segment.get("finale", false):
		if str(Game.segment.get("finale_sound", "")) != "":
			t.tween_callback(func(): Sfx.play(str(Game.segment["finale_sound"])))
		t.tween_interval(FINALE_HOLD)
		t.tween_callback(Game.segment_done)


## Whether the route is lit (tests).
func route_lit() -> bool:
	return _route.default_color == ROUTE_LIT


func _start_wiggle(button: TextureButton) -> void:
	_wiggle = create_tween().set_loops()
	_wiggle.tween_property(button, "rotation", WIGGLE_ANGLE, WIGGLE_TIME)
	_wiggle.tween_property(button, "rotation", -WIGGLE_ANGLE, WIGGLE_TIME * 2)
	_wiggle.tween_property(button, "rotation", 0.0, WIGGLE_TIME)


## Global center of a row, for taps in tests.
func row_point(row: int) -> Vector2:
	return _card.to_global(_card.row_rect(row).get_center())


## Global center of the car button, for taps in tests.
func car_button_point() -> Vector2:
	return _car.global_position + _car.size / 2


func _on_stop(id: String) -> void:
	if _started:
		return
	_started = true
	Game.play_chapter(id)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if _started:
		return
	_idle = 0.0
	var local := _card.to_local(get_global_mouse_position())
	for row in Progress.LEVELS:
		if _card.row_rect(row).has_point(local) and _playable(row):
			_started = true
			Game.play_level(row)
			return
	# A tap that starts nothing: say again what to do, and show where.
	_prompt()


func _process(delta: float) -> void:
	if _started:
		return
	_idle += delta
	if _idle >= Game.kid.hint_delay:
		_idle = 0.0
		_prompt()


func _prompt() -> void:
	var next := Progress.next_level(Game.kid.id)
	if next < Progress.LEVELS:
		_helper.point_at(row_point(next))
	elif next_stop() != "":
		_helper.point_at(stop_point(next_stop()))
	Voice.say(_line(), Game.sibling())


## "Tap the row that's wiggling", or a cheer once the whole card is packed.
func _line() -> String:
	return "all-packed" if Progress.next_level(Game.kid.id) >= Progress.LEVELS else "pick-a-row"


func _playable(row: int) -> bool:
	var kid_id := Game.kid.id
	return Progress.levels_done(kid_id).has(row) or row == Progress.next_level(kid_id)


func _fit() -> void:
	var view := get_viewport().get_visible_rect().size
	var top := 540.0 - view.y / 2
	var left := 960.0 - view.x / 2
	var cover := maxf(view.x / BG_SIZE.x, view.y / BG_SIZE.y)
	_background.position = Vector2(960, 540)
	_background.scale = Vector2.ONE * cover
	_dim.position = Vector2(960, 540)
	_dim.scale = view / _dim.texture.get_size()
	var s := (view.y - 2 * MARGIN) / CARD_SIZE.y
	_card.scale = Vector2.ONE * s
	_card.position = Vector2(960 - CARD_SIZE.x * s / 2, top + MARGIN)
	_helper.position = Vector2(960 + view.x / 2 - HELPER_MARGIN.x, 540 + view.y / 2 - HELPER_MARGIN.y)
	_home.position = Vector2(left + MARGIN, top + MARGIN)
	_home.size = Vector2.ONE * HOME_SIZE
	# The route: the SUV, the boarding pass and the next stop down the left of the
	# card, the rest snaking in rows of two down the right, clear of the helper.
	var card_right := 960.0 + CARD_SIZE.x * s / 2
	var left_x := (left + _card.position.x) / 2
	var right_gap := left + view.x - card_right
	var tex := _car.texture_normal.get_size()
	_car.size = Vector2(CAR_HEIGHT * tex.x / tex.y, CAR_HEIGHT)
	var pass_size := _airport.texture_normal.get_size()
	var pass_height := _car.size.x * pass_size.y / pass_size.x
	var rows := ceili(maxf(stop_ids.size() - 3, 0) / 2.0)
	var row_h := (view.y * 0.46 - MARGIN) / maxf(rows, 1)
	var points: Array[Vector2] = []
	for i in stop_ids.size():
		var center: Vector2
		if i < 3:
			center = Vector2(left_x, top + view.y * LEFT_SLOTS[i])
		else:
			var k := i - 3
			var row := int(k / 2.0)
			var col := k % 2 if row % 2 == 0 else 1 - k % 2
			center = Vector2(card_right + right_gap * (0.28 + 0.44 * col), top + MARGIN + row_h * (row + 0.5))
		var b: TextureButton = _stops[stop_ids[i]]
		if b == _car:
			b.size = _car.size
		elif b == _airport:
			b.size = Vector2(_car.size.x, pass_height)
		else:
			b.size = Vector2.ONE * minf(STOP_SIZE, row_h - 10)
		b.position = center - b.size / 2
		b.pivot_offset = b.size / 2
		var check: TextureRect = b.get_node_or_null("Check")
		if check:
			check.size = Vector2.ONE * CHECK_SIZE
			check.position = b.size - check.size * 0.75
		if b.visible:
			points.append(center)
	_route.points = PackedVector2Array(points)
