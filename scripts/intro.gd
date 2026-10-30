# Plays the chosen child's intro clip full screen. A tap skips it; the room
# always follows, whether the clip ends, is skipped or doesn't exist.
extends Control

var _left := false

@onready var _player: VideoStreamPlayer = $Player


func _ready() -> void:
	# SPIKE ONLY (spike/video-check): alternate Becca and Jack-Jack clips forever.
	if Game.kid == null:
		Game.kid = load(Game.KIDS["becca"])
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
	Game.kid = Game.sibling()
	get_tree().reload_current_scene.call_deferred()
