# Everything that differs between Jack-Jack and Becca: art, difficulty and video.
# Game code reads these settings instead of branching on which child is playing.
class_name KidProfile
extends Resource

## Every clothing item exists in this many colors (hue steps of 360/COLOR_STEPS degrees).
const COLOR_STEPS := 8

@export var id: String
@export var ribbon_color: Color
## How many clothes the drawer offers (the target plus distractors).
@export var choices: int
## Seconds of no input before the helper sibling points at what to do next.
@export var hint_delay: float
## res:// path of the intro clip, or "" to go straight to the room.
@export var intro_video: String
## How many outfits get rolled and packed before the suitcase is closed.
@export var outfits: int = 6
## res:// path of the finish clip, or "" to go straight to the replay/home buttons.
@export var done_video: String
## Smallest circular hue-step distance between the target color and any distractor.
@export var min_color_gap: int
## Trunk puzzle: bags that start loaded (at their reference spots) and can't be moved.
@export var trunk_preplaced: PackedStringArray
## Trunk puzzle: a faded picture of each bag shows where it goes (and which way it's turned).
@export var trunk_outlines: bool
## Trunk puzzle: a bag that only fits turned turns itself when dropped there.
@export var trunk_auto_turn: bool
## Airport check-in: the bags the kid tags and sends (car bag ids), and ones that go by themselves.
@export var airport_bags: PackedStringArray
@export var airport_auto_bags: PackedStringArray
## Airport security: what goes through the scanner ("tablet" and "buddy" are the kid's props; the rest are car bags).
@export var security_items: PackedStringArray
## The tablet needs a tray of its own.
@export var tablet_own_tray: bool
## The gate maze: size in cells, share of dead ends opened up, extra loops, most turns on the
## main path (0 = any), how many gates, footprint hints, and the hint delay in seconds.
@export var maze_size: Vector2i
@export var maze_braid: float
@export var maze_loops: int
@export var maze_max_turns: int
@export var maze_gates: int
@export var maze_footprints: bool
@export var maze_hint_delay: float


func character(pose: String) -> Texture2D:
	return load("res://assets/characters/%s/%s.png" % [id, pose])


func prop(name: String) -> Texture2D:
	return load("res://assets/props/%s/%s.png" % [id, name])


## The video before card row `level` (0-3). Row 1 has none: the kid intro covers it.
func level_intro(level: int) -> String:
	return "res://assets/video/%s-level%d.ogv" % [id, level + 1]


## The clip before the trunk puzzle: the kid's own if there is one, else the
## shared one (both kids on the driveway).
func car_intro() -> String:
	var own := "res://assets/video/%s-car.ogv" % id
	return own if ResourceLoader.exists(own) else "res://assets/video/car-intro.ogv"


## The clip before the airport.
func airport_intro() -> String:
	return "res://assets/video/%s-airport.ogv" % id


func room() -> Texture2D:
	return load("res://assets/backgrounds/%s-room.png" % id)


func card() -> Texture2D:
	return load("res://assets/cards/%s.png" % id)


## The item in all COLOR_STEPS colors; index = hue step, 0 = the card color.
func colors(item: String) -> Array[Texture2D]:
	var out: Array[Texture2D] = [prop(item + "-card")]
	for k in range(1, COLOR_STEPS):
		out.append(prop("%s-alt-%d" % [item, k]))
	return out


## `choices` distinct colors: element 0 is the target (random step), the rest
## are distractors at least min_color_gap hue steps (circular) from it.
func pick_colors(item: String, rng: RandomNumberGenerator) -> Array[Texture2D]:
	var all := colors(item)
	var target := rng.randi_range(0, COLOR_STEPS - 1)
	var pool: Array[int] = []
	for k in COLOR_STEPS:
		var d := absi(k - target)
		if k != target and mini(d, COLOR_STEPS - d) >= min_color_gap:
			pool.append(k)
	if pool.size() < choices - 1:
		push_error("%s: only %d colors at gap >= %d, need %d" % [id, pool.size(), min_color_gap, choices - 1])
	var out: Array[Texture2D] = [all[target]]
	for i in range(pool.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap := pool[i]
		pool[i] = pool[j]
		pool[j] = swap
	for k in pool.slice(0, choices - 1):
		out.append(all[k])
	return out
