# Autoload: who is playing, and moving between scenes.
extends Node

signal scene_requested(path: String)

const TITLE := "res://scenes/title.tscn"
const INTRO := "res://scenes/intro.tscn"
const ROOM := "res://scenes/room.tscn"
const KIDS := {"jack": "res://data/jack.tres", "becca": "res://data/becca.tres"}

var kid: KidProfile
## Tests turn this off to observe navigation without changing scenes.
var navigate := true
var last_scene_request := ""


func pick(kid_id: String) -> void:
	kid = load(KIDS[kid_id])
	goto(INTRO)


func sibling() -> KidProfile:
	return load(KIDS["becca" if kid.id == "jack" else "jack"])


func goto(path: String) -> void:
	last_scene_request = path
	scene_requested.emit(path)
	if navigate:
		get_tree().change_scene_to_file.call_deferred(path)
