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
## The row whose video the intro scene plays next; -1 means the kid's own intro.
var intro_level := -1
## Tests turn this off to observe navigation without changing scenes.
var navigate := true
var last_scene_request := ""


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


func sibling() -> KidProfile:
	return load(KIDS["becca" if kid.id == "jack" else "jack"])


func goto(path: String) -> void:
	last_scene_request = path
	scene_requested.emit(path)
	if navigate:
		get_tree().change_scene_to_file.call_deferred(path)
