# Everything that differs between Jack-Jack and Becca: art, difficulty and video.
# Game code reads these settings instead of branching on which child is playing.
class_name KidProfile
extends Resource

const ALTS: Array[String] = ["alt-1", "alt-2", "alt-3"]

@export var id: String
@export var ribbon_color: Color
## How many clothes the drawer offers (the target plus distractors).
@export var choices: int
## Seconds of no input before the helper sibling points at what to do next.
@export var hint_delay: float
## res:// path of the intro clip, or "" to go straight to the room.
@export var intro_video: String


func character(pose: String) -> Texture2D:
	return load("res://assets/characters/%s/%s.png" % [id, pose])


func prop(name: String) -> Texture2D:
	return load("res://assets/props/%s/%s.png" % [id, name])


func room() -> Texture2D:
	return load("res://assets/backgrounds/%s-room.png" % id)


func card() -> Texture2D:
	return load("res://assets/cards/%s.png" % id)


func distractors(item: String) -> Array[Texture2D]:
	var out: Array[Texture2D] = []
	for alt in ALTS.slice(0, choices - 1):
		out.append(prop("%s-%s" % [item, alt]))
	return out
