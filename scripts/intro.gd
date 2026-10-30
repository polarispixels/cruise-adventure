# Plays the chosen child's intro clip full screen. A tap skips it; the card map
# always follows, whether the clip ends, is skipped or doesn't exist.
extends Control

var _left := false

@onready var _player: VideoStreamPlayer = $Player


func _ready() -> void:
	var path := Game.kid.intro_video if Game.kid else ""
	if path == "" or not ResourceLoader.exists(path):
		_leave.call_deferred()
		return
	_player.stream = load(path)
	_player.finished.connect(_leave)
	_player.play()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_leave()


func _leave() -> void:
	if _left:
		return
	_left = true
	_player.stop()
	if Game.kid:
		Progress.mark_intro_seen(Game.kid.id)
	Game.goto(Game.MAP)
