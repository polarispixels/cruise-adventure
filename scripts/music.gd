# Autoload: a quiet background tune that loops for the whole game. It dips
# while the helper speaks and pauses while a video plays (videos bring their own sound).
extends Node

const THEME := "res://assets/music/theme.ogg"
const NORMAL_DB := -16.0
const DUCKED_DB := -26.0
## Decibels per second when dipping or coming back up.
const FADE_RATE := 40.0

var player := AudioStreamPlayer.new()


func _ready() -> void:
	add_child(player)
	if not ResourceLoader.exists(THEME):
		print("Music: missing ", THEME)
		return
	var stream: AudioStreamOggVorbis = load(THEME)
	stream.loop = true
	player.stream = stream
	player.volume_db = NORMAL_DB
	player.play()


## Pauses the tune (true) or lets it carry on (false).
func hold(on: bool) -> void:
	player.stream_paused = on


func _process(delta: float) -> void:
	var target := DUCKED_DB if Voice.is_speaking() else NORMAL_DB
	player.volume_db = move_toward(player.volume_db, target, FADE_RATE * delta)
