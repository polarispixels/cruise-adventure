# Pulsing yellow outlines around the places a child should put something
# next. Scenes call show_rects() every frame with what to light up; nothing
# rebuilds unless the set changes.
class_name Glows
extends Node2D

const TEXTURE := preload("res://assets/ui/card-glow.png")
## Extra room around each target, in the parent's pixels.
const MARGIN := 18.0
const PULSE_TIME := 0.45
const LOW := 0.35

var _rects: Array[Rect2] = []


func _ready() -> void:
	var t := create_tween().set_loops()
	t.tween_property(self, "modulate:a", LOW, PULSE_TIME)
	t.tween_property(self, "modulate:a", 1.0, PULSE_TIME)


func show_rects(rects: Array[Rect2]) -> void:
	if rects == _rects:
		return
	_rects = rects.duplicate()
	for n in get_children():
		n.free()
	for r in rects:
		var glow := Sprite2D.new()
		glow.texture = TEXTURE
		var area := r.grow(MARGIN)
		glow.position = area.get_center()
		glow.scale = area.size / TEXTURE.get_size()
		add_child(glow)


## What's lit up right now (tests read it).
func shown() -> Array[Rect2]:
	return _rects.duplicate()
