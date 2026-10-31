# Autoload: who is playing, and moving between scenes.
extends Node

signal scene_requested(path: String)

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


func sibling() -> KidProfile:
	return load(KIDS["becca" if kid.id == "jack" else "jack"])


func goto(path: String) -> void:
	last_scene_request = path
	scene_requested.emit(path)
	if navigate:
		get_tree().change_scene_to_file.call_deferred(path)
