# Autoload: a quiet background tune that loops for the whole game. It dips
# while the helper speaks and pauses while a video plays (videos bring their own sound).
# The airport has its own lighter bed: its scenes ask for it with want(), and
# ask for the theme again as they leave. Switching waits a frame, so going from
# one airport scene to the next doesn't restart the tune.
extends Node

const THEME := "res://assets/music/theme.ogg"
const AIRPORT := "res://assets/music/airport.ogg"
const NORMAL_DB := -16.0
const DUCKED_DB := -26.0
## Decibels per second when dipping or coming back up.
const FADE_RATE := 40.0

var player := AudioStreamPlayer.new()

var _current := ""
var _want := THEME


func _ready() -> void:
	add_child(player)
	player.volume_db = NORMAL_DB
	_switch(THEME)


## The tune that should be playing; it changes on the next frame.
func want(path: String) -> void:
	_want = path


## The tune that is playing.
func current() -> String:
	return _current


func _switch(path: String) -> void:
	_current = path
	if not ResourceLoader.exists(path):
		print("Music: missing ", path)
		player.stop()
		return
	var stream: AudioStreamOggVorbis = load(path)
	stream.loop = true
	var paused := player.stream_paused
	player.stream = stream
	player.play()
	player.stream_paused = paused


## Pauses the tune (true) or lets it carry on (false).
func hold(on: bool) -> void:
	player.stream_paused = on


func _process(delta: float) -> void:
	if _want != _current:
		_switch(_want)
	var target := DUCKED_DB if Voice.is_speaking() else NORMAL_DB
	player.volume_db = move_toward(player.volume_db, target, FADE_RATE * delta)
