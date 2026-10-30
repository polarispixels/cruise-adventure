# Autoload: the helper sibling's spoken lines. Files are assets/voice/<speaker id>/<line id>.ogg.
extends Node

signal said(line_id: String)

## Tests may turn this off: say() then only records last_line and emits said.
var enabled := true
## The last line asked for (recorded even when disabled or waiting).
var last_line := ""
## The line actually playing, or waiting to play next.
var current_line := ""

var _player := AudioStreamPlayer.new()
var _found_index := 0
var _pending := ""
var _pending_speaker: KidProfile


func _ready() -> void:
	add_child(_player)
	_player.finished.connect(_play_pending)


## wait: let the line that's playing finish first (an instruction after a cheer).
## Without it the new line interrupts.
func say(line_id: String, speaker: KidProfile, wait := false) -> void:
	last_line = line_id
	said.emit(line_id)
	if not enabled:
		return
	if wait and _player.playing:
		_pending = line_id
		_pending_speaker = speaker
		return
	_pending = ""
	_play(line_id, speaker)


func _play_pending() -> void:
	if _pending == "":
		return
	var line := _pending
	_pending = ""
	_play(line, _pending_speaker)


func _play(line_id: String, speaker: KidProfile) -> void:
	current_line = line_id
	var path := "res://assets/voice/%s/%s.ogg" % [speaker.id, line_id]
	if not ResourceLoader.exists(path):
		print("Voice: missing ", path)
		_player.stop()
		return
	_player.stream = load(path)
	_player.play()


func stop() -> void:
	_pending = ""
	_player.stop()


func is_speaking() -> bool:
	return _player.playing


## Rotates found-1, found-2, found-3.
func found_line() -> String:
	_found_index += 1
	return "found-%d" % (((_found_index - 1) % 3) + 1)
