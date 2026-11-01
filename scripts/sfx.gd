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


## Plays a sound and returns its player (null when the file is missing), so a
## caller can wait for its `finished`. An idle player is used when there is
## one; only when all are busy is the oldest cut off (its `finished` still fires).
## duck: the music dips under it, as under a voice line.
func play(name: String, duck := false) -> AudioStreamPlayer:
	last = name
	var path := "res://assets/sfx/%s.ogg" % name
	if not ResourceLoader.exists(path):
		return null
	var p: AudioStreamPlayer = null
	for candidate in _players:
		if not candidate.playing:
			p = candidate
			break
	if p == null:
		p = _players[_next]
		_next = (_next + 1) % VOICES
		p.stop()
		p.finished.emit()
	p.set_meta("duck", duck)
	p.stream = load(path)
	p.play()
	return p


## Whether a sound the music should dip under is playing.
func ducking() -> bool:
	for p in _players:
		if p.playing and bool(p.get_meta("duck", false)):
			return true
	return false


## The players (tests).
func players() -> Array[AudioStreamPlayer]:
	return _players
