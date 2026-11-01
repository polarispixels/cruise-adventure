# Autoload: who is playing, and moving between scenes.
extends Node

signal scene_requested(path: String)
## A segment scene finished (see segment_done()).
signal segment_finished

const TITLE := "res://scenes/title.tscn"
const INTRO := "res://scenes/intro.tscn"
const MAP := "res://scenes/map.tscn"
const ROOM := "res://scenes/room.tscn"
const TRUNK := "res://scenes/trunk.tscn"
const CHECKIN := "res://scenes/checkin.tscn"
const SECURITY := "res://scenes/security.tscn"
const MAZE := "res://scenes/maze.tscn"
## intro_level for the car clip before the trunk puzzle.
const CAR := 4
## intro_level for the airport clip before check-in.
const AIRPORT := 5
const KIDS := {"jack": "res://data/jack.tres", "becca": "res://data/becca.tres"}

var kid: KidProfile
## Which card row (0-3) the room is playing.
var level := 0
## The row whose video the intro scene plays next (CAR: the car clip); -1 means the kid's own intro.
var intro_level := -1
## Tests turn this off to observe navigation without changing scenes.
var navigate := true
var last_scene_request := ""
## The current segment's data, already merged for the current kid (docs/chapters-format.md).
var segment: Dictionary = {}
## Set by segment_done(); tests reset it to false and read it.
var last_segment_done := false
## The chapter the segment player is running, or "".
var _chapter_id := ""


func pick(kid_id: String) -> void:
	kid = load(KIDS[kid_id])
	goto(MAP if Progress.intro_seen(kid_id) else INTRO)


## A row not packed yet starts with its video, when there is one.
func play_level(n: int) -> void:
	level = n
	var video := kid.level_intro(n)
	if n > 0 and not Progress.levels_done(kid.id).has(n) and ResourceLoader.exists(video):
		intro_level = n
		goto(INTRO)
	else:
		goto(ROOM)


## The trunk puzzle, after the kid's car clip the first time.
func play_car() -> void:
	if not Progress.car_done(kid.id) and ResourceLoader.exists(kid.car_intro()):
		intro_level = CAR
		goto(INTRO)
	else:
		goto(TRUNK)


## The airport chapter: the kid's airport clip the first time, then check-in.
func play_airport() -> void:
	if not Progress.airport_done(kid.id) and ResourceLoader.exists(kid.airport_intro()):
		intro_level = AIRPORT
		goto(INTRO)
	else:
		goto(CHECKIN)


## A segment scene calls this once when it is finished. If a chapter is running,
## the player moves on to the next segment (scene changes still obey `navigate`).
func segment_done() -> void:
	last_segment_done = true
	segment_finished.emit()
	if _chapter_id != "":
		_advance()


## Forgets the running chapter.
func stop_chapter() -> void:
	_chapter_id = ""


## A segment entry merged for one kid: the kid's block over the common keys, then
## the data file (if any) the same way, then {kid}/{sibling}/{row} filled in.
func merge_segment(entry: Dictionary, kid_id: String) -> Dictionary:
	var out := _for_kid(entry, kid_id)
	var data_path: String = str(out.get("data", ""))
	if data_path != "":
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(data_path))
		if parsed is Dictionary:
			out.merge(_for_kid(parsed as Dictionary, kid_id), true)
		else:
			push_error("segment data unreadable: " + data_path)
	var subs := {"{kid}": kid_id, "{sibling}": "becca" if kid_id == "jack" else "jack", "{row}": str(level + 1)}
	return _fill(out, subs) as Dictionary


func _for_kid(entry: Dictionary, kid_id: String) -> Dictionary:
	var out := entry.duplicate(true)
	out.erase("jack")
	out.erase("becca")
	var own: Variant = entry.get(kid_id, {})
	if own is Dictionary:
		out.merge((own as Dictionary).duplicate(true), true)
	return out


func _fill(value: Variant, subs: Dictionary) -> Variant:
	if value is String:
		var s: String = value
		for key: String in subs:
			s = s.replace(key, str(subs[key]))
		return s
	if value is Array:
		var arr: Array = []
		for v: Variant in value:
			arr.append(_fill(v, subs))
		return arr
	if value is Dictionary:
		var d: Dictionary = {}
		for k: Variant in value:
			d[k] = _fill(value[k], subs)
		return d
	return value


## Filled in by the segment player.
func _advance() -> void:
	pass


func sibling() -> KidProfile:
	return load(KIDS["becca" if kid.id == "jack" else "jack"])


func goto(path: String) -> void:
	last_scene_request = path
	scene_requested.emit(path)
	if navigate:
		get_tree().change_scene_to_file.call_deferred(path)
