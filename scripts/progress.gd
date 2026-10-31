# Autoload: which card rows each child has packed, and whether they've seen
# their intro. Saved as JSON on the device. A missing or corrupt file simply
# means a fresh start.
extends Node

const LEVELS := 4

## Tests point this at a temp file.
var path := "user://progress.json"

## {kid_id: {"levels_done": [int], "intro_seen": bool, "car_done": bool}}
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


func intro_seen(kid_id: String) -> bool:
	return bool(_kid(kid_id).get("intro_seen", false))


func mark_intro_seen(kid_id: String) -> void:
	_entry(kid_id)["intro_seen"] = true
	save_file()


## Whether the kid has loaded the car (the trunk puzzle).
func car_done(kid_id: String) -> bool:
	return bool(_kid(kid_id).get("car_done", false))


func mark_car_done(kid_id: String) -> void:
	_entry(kid_id)["car_done"] = true
	save_file()


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
				_data[kid_id] = parsed[kid_id]


func save_file() -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		print("Progress: could not save to ", path)
		return
	file.store_string(JSON.stringify(_data))


func _kid(kid_id: String) -> Dictionary:
	return _data.get(kid_id, {})


func _entry(kid_id: String) -> Dictionary:
	if not _data.has(kid_id):
		_data[kid_id] = {}
	return _data[kid_id]
