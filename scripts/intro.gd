# Plays the chosen child's intro clip full screen, or a card row's video before
# that row, or the car clip before the trunk (Game.intro_level). A tap skips it;
# the card map (or the row's room, or the trunk)
# always follows, whether the clip ends, is skipped or doesn't exist.
extends Control

var _left := false

@onready var _player: VideoStreamPlayer = $Player


func _ready() -> void:
	var path := ""
	if Game.kid:
		if Game.intro_level == Game.CAR:
			path = Game.kid.car_intro()
		elif Game.intro_level >= 0:
			path = Game.kid.level_intro(Game.intro_level)
		else:
			path = Game.kid.intro_video
	if path == "" or not ResourceLoader.exists(path):
		_leave.call_deferred()
		return
	_player.stream = load(path)
	_player.finished.connect(_leave)
	Music.hold(true)
	_player.play()


func _exit_tree() -> void:
	Music.hold(false)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_leave()


func _leave() -> void:
	if _left:
		return
	_left = true
	_player.stop()
	if Game.intro_level >= 0:
		var next := Game.TRUNK if Game.intro_level == Game.CAR else Game.ROOM
		Game.intro_level = -1
		Game.goto(next)
		return
	if Game.kid:
		Progress.mark_intro_seen(Game.kid.id)
	Game.goto(Game.MAP)
