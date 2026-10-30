# Autoload: the helper sibling's spoken lines. Files are assets/voice/<speaker id>/<line id>.ogg.
extends Node

signal said(line_id: String)

## Tests may turn this off: say() then only records last_line and emits said.
var enabled := true
var last_line := ""

var _player := AudioStreamPlayer.new()
var _found_index := 0


func _ready() -> void:
	add_child(_player)


func say(line_id: String, speaker: KidProfile) -> void:
	last_line = line_id
	said.emit(line_id)
	if not enabled:
		return
	var path := "res://assets/voice/%s/%s.ogg" % [speaker.id, line_id]
	if not ResourceLoader.exists(path):
		print("Voice: missing ", path)
		_player.stop()
		return
	_player.stream = load(path)
	_player.play()


func stop() -> void:
	_player.stop()


func is_speaking() -> bool:
	return _player.playing


## Rotates found-1, found-2, found-3.
func found_line() -> String:
	_found_index += 1
	return "found-%d" % (((_found_index - 1) % 3) + 1)
