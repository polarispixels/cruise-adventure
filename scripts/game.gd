# Autoload: who is playing, and moving between scenes.
extends Node

signal scene_requested(path: String)

const TITLE := "res://scenes/title.tscn"
const INTRO := "res://scenes/intro.tscn"
const MAP := "res://scenes/map.tscn"
const ROOM := "res://scenes/room.tscn"
const KIDS := {"jack": "res://data/jack.tres", "becca": "res://data/becca.tres"}

var kid: KidProfile
## Which card row (0-3) the room is playing.
var level := 0
## Tests turn this off to observe navigation without changing scenes.
var navigate := true
var last_scene_request := ""


func pick(kid_id: String) -> void:
	kid = load(KIDS[kid_id])
	goto(MAP if Progress.intro_seen(kid_id) else INTRO)


func play_level(n: int) -> void:
	level = n
	goto(ROOM)


func sibling() -> KidProfile:
	return load(KIDS["becca" if kid.id == "jack" else "jack"])


func goto(path: String) -> void:
	last_scene_request = path
	scene_requested.emit(path)
	if navigate:
		get_tree().change_scene_to_file.call_deferred(path)
