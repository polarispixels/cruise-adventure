# Plays a clip or still segment (Game.segment) full screen: the clip when it
# exists, else its still with a slow zoom, else a placeholder card with the
# segment's name. A tap skips any of them, and the chapter always goes on
# (Game.segment_done()), so a missing clip never blocks a chapter. A segment's
# "line" is said by the sibling when the picture is done, before going on.
extends Control

## Seconds a still shows when the segment doesn't say (`seconds`).
const STILL_SECONDS := 6.0
## The still zooms from 1 to this over its time.
const STILL_ZOOM := 1.12
## Seconds the developer placeholder card shows.
const CARD_SECONDS := 3.0

## What's showing: "clip", "still" or "card" (tests read it).
var mode := ""
var _left := false

@onready var _player: VideoStreamPlayer = $Player
@onready var _still: TextureRect = $Still
@onready var _card: ColorRect = $Card


func _ready() -> void:
	_still.visible = false
	_card.visible = false
	if Game.segment.is_empty():
		_leave.call_deferred()
		return
	var media: String = str(Game.segment.get("name", ""))
	var clip := Game.clip_path(media)
	var still := Game.still_path(media)
	if Game.segment.get("kind") == "clip" and ResourceLoader.exists(clip):
		mode = "clip"
		_player.stream = load(clip)
		_player.finished.connect(_leave)
		Music.hold(true)
		_player.play()
	elif ResourceLoader.exists(still):
		mode = "still"
		_still.texture = load(still)
		_still.visible = true
		var seconds := float(Game.segment.get("seconds", STILL_SECONDS))
		_still.pivot_offset = _still.size / 2
		var t := create_tween()
		t.tween_property(_still, "scale", Vector2.ONE * STILL_ZOOM, seconds) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		t.tween_callback(_leave)
	else:
		mode = "card"
		_card.visible = true
		($Card/Name as Label).text = str(Game.segment.get("id", media))
		get_tree().create_timer(CARD_SECONDS).timeout.connect(_leave)


func _exit_tree() -> void:
	Music.hold(false)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_leave()


func _leave() -> void:
	if _left or not is_inside_tree():
		return
	_left = true
	_player.stop()
	# A closing line ("We landed!"), said by the sibling once the picture is done.
	var line := str(Game.segment.get("line", ""))
	if line != "" and Game.kid:
		Voice.say(line, Game.sibling())
		if Voice.is_speaking() and Voice.current_line == line:
			Voice.line_finished.connect(_go_on_after_line, CONNECT_ONE_SHOT)
			return
	_go_on()


func _go_on_after_line(_id: String) -> void:
	_go_on()


func _go_on() -> void:
	if Game.playing():
		Game.segment_done()
	else:
		Game.goto(Game.MAP)
