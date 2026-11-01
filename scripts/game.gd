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
const CHAPTERS := "res://data/chapters.json"
const KIDS := {"jack": "res://data/jack.tres", "becca": "res://data/becca.tres"}

var kid: KidProfile
## Which card row (0-3) the room is playing.
var level := 0
## Tests turn this off to observe navigation without changing scenes.
var navigate := true
var last_scene_request := ""
## The current segment's data, already merged for the current kid (docs/chapters-format.md).
var segment: Dictionary = {}
## Set by segment_done(); tests reset it to false and read it.
var last_segment_done := false
## The chapter the segment player is running, or "".
var _chapter_id := ""
## Which of its segments is playing.
var _segment_index := -1
## The running segment hasn't called segment_done() yet.
var _waiting := false
## The frame of the last advance: a second segment_done() in it is ignored.
var _advanced_frame := -1
## The chapter (or card row) was already done when it started: `once` clips are skipped.
var _replay := false
## Where stills live (tests point it at their fixtures).
var stills_dir := "res://assets/stills/"
## data/chapters.json, loaded on first use.
var _chapters: Array = []


## The title screen picked a kid: their intro the first time, then the map.
func pick(kid_id: String) -> void:
	kid = load(KIDS[kid_id])
	if Progress.intro_seen(kid_id):
		goto(MAP)
	else:
		play_chapter("mission")


## A card row: chapter 2 (row 0) or 3 (rows 1-3). A row not packed yet starts with its video.
func play_level(n: int) -> void:
	level = n
	for c: Dictionary in chapters():
		if (c.get("rows", []) as Array).has(float(n)):
			_start(c["id"], 0, Progress.levels_done(kid.id).has(n))
			return
	goto(ROOM)


## Every chapter in order, dropped ones included.
func chapters() -> Array:
	if _chapters.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CHAPTERS))
		if parsed is Dictionary and parsed.get("chapters") is Array:
			_chapters = parsed["chapters"]
		else:
			push_error("unreadable " + CHAPTERS)
	return _chapters


## Tests swap in their own chapter list; an empty list reloads the file.
func use_chapters(list: Array) -> void:
	_chapters = list


func chapter(id: String) -> Dictionary:
	for c: Dictionary in chapters():
		if c.get("id") == id:
			return c
	return {}


## Starts chapter `id` at segment `from`.
func play_chapter(id: String, from := 0) -> void:
	_start(id, from, Progress.chapter_done(kid.id, id))


## Whether the segment player is running a chapter.
func playing() -> bool:
	return _chapter_id != ""


## res:// paths of a clip or still segment's media.
func clip_path(media_name: String) -> String:
	return "res://assets/video/%s.ogv" % media_name


func still_path(media_name: String) -> String:
	return "%s%s.png" % [stills_dir, media_name]


func _start(id: String, from: int, replay: bool) -> void:
	_chapter_id = id
	_replay = replay
	_run(from)


func _run(from: int) -> void:
	var segs: Array = chapter(_chapter_id).get("segments", [])
	var i := from
	while i < segs.size():
		var seg := merge_segment(segs[i], kid.id)
		seg["chapter"] = _chapter_id
		seg["index"] = i
		if _skip(seg):
			i += 1
			continue
		_segment_index = i
		_waiting = true
		segment = seg
		last_segment_done = false
		goto(str(seg["scene"]) if seg.get("kind") == "scene" else INTRO)
		return
	_finish()


## A replayed chapter skips its `once` clips; an `optional` clip with no clip or still is skipped.
func _skip(seg: Dictionary) -> bool:
	var kind: String = seg.get("kind", "")
	if kind != "clip" and kind != "still":
		return false
	if _replay and seg.get("once", false):
		return true
	var media: String = seg.get("name", "")
	var has_media := ResourceLoader.exists(clip_path(media)) or ResourceLoader.exists(still_path(media))
	return seg.get("optional", false) and not has_media


func _finish() -> void:
	var c := chapter(_chapter_id)
	_chapter_id = ""
	_segment_index = -1
	_waiting = false
	segment = {}
	if (c.get("segments", []) as Array).is_empty():
		goto(MAP)
		return
	if not c.has("rows"):
		Progress.mark_chapter_done(kid.id, c["id"])
	if c.get("after", "map") == "next":
		var next := _next_chapter(c["id"])
		if next != "":
			play_chapter(next)
			return
	goto(MAP)


## The chapter after `id` that is neither dropped nor empty, or "".
func _next_chapter(id: String) -> String:
	var found := false
	for c: Dictionary in chapters():
		if found and not c.get("dropped", false) and not (c.get("segments", []) as Array).is_empty():
			return c["id"]
		if c.get("id") == id:
			found = true
	return ""


## A segment scene calls this once when it is finished. If a chapter is running,
## the player moves on to the next segment; if not, the map follows. (Scene
## changes still obey `navigate`.)
func segment_done() -> void:
	last_segment_done = true
	segment_finished.emit()
	if _chapter_id == "":
		goto(MAP)
	elif _waiting and not (navigate and Engine.get_process_frames() == _advanced_frame):
		# The old scene stays until the frame ends: a second tap on its Continue
		# in that frame must not skip the next segment.
		_advanced_frame = Engine.get_process_frames()
		_waiting = false
		_run(_segment_index + 1)


## Forgets the running chapter.
func stop_chapter() -> void:
	_chapter_id = ""
	_segment_index = -1
	_waiting = false
	segment = {}


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


func sibling() -> KidProfile:
	return load(KIDS["becca" if kid.id == "jack" else "jack"])


func goto(path: String) -> void:
	last_scene_request = path
	scene_requested.emit(path)
	if navigate:
		get_tree().change_scene_to_file.call_deferred(path)
