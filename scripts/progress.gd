# Autoload: which card rows each child has packed and which chapters they've
# finished (keyed by chapter id, see data/chapters.json). Saved as JSON on the
# device. A missing or corrupt file simply means a fresh start. A v0.5 save
# (intro_seen / car_done / airport_done flags) is carried over on load.
extends Node

const LEVELS := 4
## Chapters played on the card: done when all their rows are packed.
const ROW_CHAPTERS := {"routine": [0], "your-turn": [1, 2, 3]}
## v0.5 save flags and the chapter each one became.
const OLD_FLAGS := {"intro_seen": "mission", "car_done": "car", "airport_done": "airport"}

## Tests point this at a temp file.
var path := "user://progress.json"

## {kid_id: {"levels_done": [int], "chapters_done": [String]}}
var _data: Dictionary = {}


func _ready() -> void:
	load_file()


func levels_done(kid_id: String) -> Array[int]:
	var out: Array[int] = []
	var raw: Variant = _kid(kid_id).get("levels_done", [])
	if raw is Array:
		for level in raw:
			if level is float or level is int:
				out.append(int(level))
	return out


func mark_done(kid_id: String, level: int) -> void:
	var done := levels_done(kid_id)
	if done.has(level):
		return
	done.append(level)
	done.sort()
	_entry(kid_id)["levels_done"] = done
	save_file()


## The lowest level not done; LEVELS when all are.
func next_level(kid_id: String) -> int:
	var done := levels_done(kid_id)
	for level in LEVELS:
		if not done.has(level):
			return level
	return LEVELS


## Whether the kid has finished chapter `chapter_id`.
func chapter_done(kid_id: String, chapter_id: String) -> bool:
	if ROW_CHAPTERS.has(chapter_id):
		var done := levels_done(kid_id)
		for row: int in ROW_CHAPTERS[chapter_id]:
			if not done.has(row):
				return false
		return true
	return chapters_done(kid_id).has(chapter_id)


func mark_chapter_done(kid_id: String, chapter_id: String) -> void:
	if ROW_CHAPTERS.has(chapter_id):
		for row: int in ROW_CHAPTERS[chapter_id]:
			mark_done(kid_id, row)
		return
	var done := chapters_done(kid_id)
	if done.has(chapter_id):
		return
	done.append(chapter_id)
	_entry(kid_id)["chapters_done"] = done
	save_file()


## Finished chapter ids (rows aside), in the order they were finished.
func chapters_done(kid_id: String) -> Array[String]:
	var out: Array[String] = []
	var raw: Variant = _kid(kid_id).get("chapters_done", [])
	if raw is Array:
		for id: Variant in raw:
			if id is String:
				out.append(id)
	return out


## The kid's own intro clip (chapter 1).
func intro_seen(kid_id: String) -> bool:
	return chapter_done(kid_id, "mission")


func mark_intro_seen(kid_id: String) -> void:
	mark_chapter_done(kid_id, "mission")


## Whether the kid has loaded the car (the trunk puzzle).
func car_done(kid_id: String) -> bool:
	return chapter_done(kid_id, "car")


func mark_car_done(kid_id: String) -> void:
	mark_chapter_done(kid_id, "car")


## Whether the kid has made it through the airport to the gate.
func airport_done(kid_id: String) -> bool:
	return chapter_done(kid_id, "airport")


func mark_airport_done(kid_id: String) -> void:
	mark_chapter_done(kid_id, "airport")


## Forgets everything, on disk too.
func reset() -> void:
	_data = {}
	save_file()


func load_file() -> void:
	_data = {}
	if not FileAccess.file_exists(path):
		return
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		print("Progress: ignoring unreadable ", path)
		return
	var parsed: Variant = json.data
	if parsed is Dictionary:
		for kid_id in parsed:
			if parsed[kid_id] is Dictionary:
				_data[kid_id] = _migrate(parsed[kid_id])


## Writes a temp file, then renames it over the save, so a crash mid-write never
## leaves a half-written save.
func save_file() -> void:
	var tmp := path + ".tmp"
	var file := FileAccess.open(tmp, FileAccess.WRITE)
	if file == null:
		print("Progress: could not save to ", tmp)
		return
	file.store_string(JSON.stringify(_data))
	file.close()
	if DirAccess.rename_absolute(tmp, path) != OK:
		print("Progress: could not move ", tmp, " to ", path)


## A v0.5 entry's flags become chapter ids; nothing already saved is lost.
func _migrate(entry: Dictionary) -> Dictionary:
	var done: Array = entry.get("chapters_done", []) if entry.get("chapters_done", []) is Array else []
	for flag: String in OLD_FLAGS:
		if entry.has(flag):
			if bool(entry[flag]) and not done.has(OLD_FLAGS[flag]):
				done.append(OLD_FLAGS[flag])
			entry.erase(flag)
	entry["chapters_done"] = done
	return entry


func _kid(kid_id: String) -> Dictionary:
	return _data.get(kid_id, {})


func _entry(kid_id: String) -> Dictionary:
	if not _data.has(kid_id):
		_data[kid_id] = {}
	return _data[kid_id]
