# What every engine shares (docs/chapters-format.md, "Engines"): it reads its
# settings from Game.segment, draws a background-sized Stage (1672 x 941
# background pixels, scaled to cover the screen; data coordinates are in these
# pixels and stay inside the 16:10 safe area, x 100-1572), the Home button, the
# kid and the helper sibling, the start and done lines, and the idle hint: after
# hint_delay seconds without a touch the engine's _show_hint() runs, and again
# every hint_delay while the kid is stuck. Touches arrive as emulated mouse
# events and reach the engine as _press / _drag / _release in Stage pixels.
class_name EngineBase
extends Node2D

const BG_SIZE := Vector2(1672, 941)
## The part of the background a 16:10 tablet always shows.
const SAFE := Rect2(100, 0, 1472, 941)
const CHARACTER := preload("res://scenes/character.tscn")
const HOME_TEXTURE := preload("res://assets/ui/home.png")
const HOME_SIZE := 130.0
const MARGIN := 24.0
## A press that moves less than this (screen pixels) is a tap.
const TAP_DISTANCE := 20.0
const KID_SCALE := 0.16
const WIGGLE_ANGLE := deg_to_rad(8.0)
const WIGGLE_TIME := 0.3
const GLIDE_TIME := 0.3
const PULSE_TIME := 0.45

## Settings: the engine's defaults with Game.segment laid over them.
var data: Dictionary = {}
## True once the kid has finished (input is over; segment_done follows).
var finished := false
## True once Game.segment_done() has been called.
var completed := false
var stage: Node2D
var background: Sprite2D
var glows: Glows
## Null when the data gives no player_feet.
var player: Character
## Null when the data sets helper_feet to null.
var helper: Character
var home_button: TextureButton

var _idle := 0.0
var _hinting := false
var _pressing := false
var _moved := false
var _press_global := Vector2.ZERO
var _pulses := {}


func _ready() -> void:
	data = _defaults()
	data.merge(Game.segment, true)
	stage = Node2D.new()
	stage.name = "Stage"
	add_child(stage)
	background = Sprite2D.new()
	background.name = "Background"
	background.centered = false
	background.texture = texture_or(str(data.get("background", "")), BG_SIZE, Color("#8fc6e8"))
	background.scale = BG_SIZE / background.texture.get_size()
	stage.add_child(background)
	_build()
	glows = Glows.new()
	glows.name = "Glows"
	stage.add_child(glows)
	player = _character(data.get("player_feet"), Game.kid, false)
	helper = _character(data.get("helper_feet"), Game.sibling(), true)
	home_button = TextureButton.new()
	home_button.name = "Home"
	home_button.texture_normal = HOME_TEXTURE
	home_button.ignore_texture_size = true
	home_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	home_button.pressed.connect(func() -> void: Game.goto(Game.TITLE))
	add_child(home_button)
	var music := str(data.get("music", ""))
	if music != "":
		Music.want(music)
	get_viewport().size_changed.connect(_fit)
	_fit()
	sound(str(data.get("start_sound", "")))
	say(str(data.get("start_line", "")))
	_started()


func _exit_tree() -> void:
	if str(data.get("music", "")) != "":
		Music.want(Music.THEME)


# --- For the engines to override -------------------------------------------

## Default settings, under Game.segment.
func _defaults() -> Dictionary:
	return {}


## Builds the engine's nodes on the stage (after the background, before the glows and characters).
func _build() -> void:
	pass


## After the first layout and the start line.
func _started() -> void:
	pass


## The screen size changed (the stage is already refit).
func _layout() -> void:
	pass


## True while something is moving on its own (no hint countdown).
func _busy() -> bool:
	return false


## A press at a stage point; return true to keep the touch (drag and release follow).
func _press(_local: Vector2) -> bool:
	return false


func _drag(_local: Vector2) -> void:
	pass


## tapped: the finger barely moved since the press.
func _release(_local: Vector2, _tapped: bool) -> void:
	pass


## The idle nudge. Runs after hint_delay seconds without a touch, then again every hint_delay.
func _show_hint() -> void:
	pass


## A touch came: take the nudge down.
func _hide_hint() -> void:
	pass


# --- Shared behavior --------------------------------------------------------

## Says a line id from data/voice_lines.json in the helper's voice. "" says nothing; an unknown id is harmless.
func say(line_id: String, wait := false) -> void:
	if line_id != "":
		Voice.say(line_id, Game.sibling(), wait)


func sound(name: String) -> void:
	if name != "":
		Sfx.play(name)


## The data line for `key`; "found" means the rotating found-1/2/3 cheer.
func line(key: String) -> String:
	var id := str(data.get(key, ""))
	return Voice.found_line() if id == "found" else id


func hint_delay() -> float:
	return float(data.get("hint_delay", Game.kid.hint_delay))


## Ends the segment: cheers, the done line, then Game.segment_done() after done_delay seconds.
func finish() -> void:
	if finished:
		return
	finished = true
	_clear_hint()
	glows.show_rects([] as Array[Rect2])
	if helper:
		helper.cheer()
	if player:
		player.cheer()
	sound(str(data.get("done_sound", "")))
	say(str(data.get("done_line", "")), true)
	var delay := float(data.get("done_delay", 1.6))
	if delay <= 0.0:
		_complete()
	else:
		get_tree().create_timer(delay).timeout.connect(_complete)


func _complete() -> void:
	if completed:
		return
	completed = true
	Game.segment_done()


## The world rect the camera shows (the camera is centered on 960, 540).
func view_rect() -> Rect2:
	var size := get_viewport().get_visible_rect().size
	return Rect2(Vector2(960, 540) - size / 2, size)


## The part of the stage on screen, in stage pixels.
func stage_view() -> Rect2:
	var v := view_rect()
	return Rect2(stage.to_local(v.position), v.size / stage.scale)


func to_global_point(local: Vector2) -> Vector2:
	return stage.to_global(local)


func to_global_rect(local: Rect2) -> Rect2:
	return Rect2(stage.to_global(local.position), local.size * stage.scale)


## A texture by path; a flat placeholder of `size` when the file is missing (never a crash).
static func texture_or(path: String, size := Vector2(256, 256), color := Color(0.8, 0.8, 0.85)) -> Texture2D:
	if path != "" and ResourceLoader.exists(path):
		var res: Resource = load(path)
		if res is Texture2D:
			return res
	if path != "":
		print("Engine: missing texture ", path)
	var img := Image.create(maxi(int(size.x), 1), maxi(int(size.y), 1), false, Image.FORMAT_RGBA8)
	img.fill(color)
	return ImageTexture.create_from_image(img)


## [x, y] from data as a Vector2 (fallback when absent or malformed).
static func vec(value: Variant, fallback := Vector2.ZERO) -> Vector2:
	if value is Array and (value as Array).size() >= 2:
		var a: Array = value
		return Vector2(float(a[0]), float(a[1]))
	if value is Vector2:
		return value
	return fallback


## [x, y, w, h] from data as a Rect2.
static func rect_of(value: Variant, fallback := Rect2()) -> Rect2:
	if value is Array and (value as Array).size() >= 4:
		var a: Array = value
		return Rect2(float(a[0]), float(a[1]), float(a[2]), float(a[3]))
	if value is Rect2:
		return value
	return fallback


static func color_of(value: Variant, fallback := Color.WHITE) -> Color:
	if value is String and Color.html_is_valid(value as String):
		return Color.html(value as String)
	if value is Color:
		return value
	return fallback


## A sprite's rect in its parent's pixels (centered sprites).
static func sprite_rect(sprite: Sprite2D) -> Rect2:
	var size := sprite.texture.get_size() * sprite.scale.abs()
	return Rect2(sprite.position - size / 2, size)


## Scales a sprite to `height` pixels tall.
static func set_height(sprite: Sprite2D, height: float) -> void:
	sprite.scale = Vector2.ONE * height / sprite.texture.get_size().y


## Scales a sprite to fit inside `box`.
static func fit_into(sprite: Sprite2D, box: Vector2) -> void:
	var tex := sprite.texture.get_size()
	sprite.scale = Vector2.ONE * minf(box.x / tex.x, box.y / tex.y)


## A "no" shake that leaves the node where it is.
func wiggle(node: Node2D) -> void:
	var t := create_tween()
	var step := WIGGLE_TIME / 6
	for i in 3:
		t.tween_property(node, "rotation", WIGGLE_ANGLE, step)
		t.tween_property(node, "rotation", -WIGGLE_ANGLE, step)
	t.tween_property(node, "rotation", 0.0, step / 2)


## A happy hop, by scale.
func pop(node: Node2D) -> void:
	var rest := node.scale
	var t := create_tween()
	t.tween_property(node, "scale", rest * 1.2, 0.12).set_ease(Tween.EASE_OUT)
	t.tween_property(node, "scale", rest, 0.18).set_ease(Tween.EASE_IN)


func pulse(node: CanvasItem) -> void:
	stop_pulse(node)
	var t := create_tween().set_loops()
	t.tween_property(node, "modulate", Color(1.35, 1.35, 1.1), PULSE_TIME)
	t.tween_property(node, "modulate", Color.WHITE, PULSE_TIME)
	_pulses[node] = t


func stop_pulse(node: CanvasItem) -> void:
	if _pulses.has(node):
		var t: Tween = _pulses[node]
		if t.is_valid():
			t.kill()
		_pulses.erase(node)
		if is_instance_valid(node):
			node.modulate = Color.WHITE


func is_pulsing(node: CanvasItem) -> bool:
	return _pulses.has(node)


## The helper points at a stage point.
func point_helper(local: Vector2) -> void:
	if helper:
		helper.point_at(stage.to_global(local))


func _character(feet: Variant, kid: KidProfile, mirrored: bool) -> Character:
	if not (feet is Array):
		return null
	var c: Character = CHARACTER.instantiate()
	c.name = "Helper" if mirrored else "Player"
	stage.add_child(c)
	c.kid = kid
	c.height_scale = float(data.get("kid_scale", KID_SCALE))
	c.mirrored = mirrored and bool(data.get("helper_mirrored", true))
	c.position = vec(feet)
	return c


func _process(delta: float) -> void:
	if finished or _busy() or _pressing:
		_idle = 0.0
		return
	_idle += delta
	if _idle >= hint_delay():
		_idle = 0.0
		_hinting = true
		say(str(data.get("hint_line", "")))
		_show_hint()


func _clear_hint() -> void:
	_idle = 0.0
	if not _hinting:
		return
	_hinting = false
	if helper:
		helper.set_pose("idle")
	_hide_hint()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton or event is InputEventMouseMotion):
		return
	if finished:
		return
	var point := get_global_mouse_position()
	var local := stage.to_local(point)
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		if (event as InputEventMouseButton).pressed:
			_clear_hint()
			if _pressing:
				_pressing = false
				_release(local, false)
			_press_global = point
			_moved = false
			_pressing = _press(local)
			if _pressing:
				get_viewport().set_input_as_handled()
		elif _pressing:
			_pressing = false
			_release(local, not _moved)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _pressing:
		if not _moved and point.distance_to(_press_global) >= TAP_DISTANCE:
			_moved = true
		_drag(local)
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and _pressing:
		_pressing = false
		_release(stage.to_local(get_global_mouse_position()), false)


func _fit() -> void:
	var view := get_viewport().get_visible_rect().size
	var s := maxf(view.x / BG_SIZE.x, view.y / BG_SIZE.y)
	stage.scale = Vector2.ONE * s
	stage.position = Vector2(960, 540) - BG_SIZE * s / 2
	home_button.position = Vector2(960, 540) - view / 2 + Vector2(MARGIN, MARGIN)
	home_button.size = Vector2.ONE * HOME_SIZE
	_layout()
