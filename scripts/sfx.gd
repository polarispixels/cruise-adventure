# Autoload: short sound effects, assets/sfx/<name>.ogg. A missing file is
# skipped quietly, so scenes can name sounds before they exist.
extends Node

const VOLUME_DB := -6.0
## A few players so overlapping sounds don't cut each other off.
const VOICES := 4

## The last sound asked for (tests read it).
var last := ""

var _players: Array[AudioStreamPlayer] = []
var _next := 0


func _ready() -> void:
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		p.volume_db = VOLUME_DB
		add_child(p)
		_players.append(p)


func play(name: String) -> void:
	last = name
	var path := "res://assets/sfx/%s.ogg" % name
	if not ResourceLoader.exists(path):
		return
	var p := _players[_next]
	_next = (_next + 1) % VOICES
	p.stream = load(path)
	p.play()
