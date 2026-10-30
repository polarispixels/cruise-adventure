# The child's picture card. Glows around the item to find next and stamps a
# check in its box once it's packed. Positions are in card pixels.
class_name Card
extends Node2D

## Row 1 of the card (shirt, shorts, underwear, socks), from the video
## project's "Video cards v0.2 - verification.json". Both cards share it.
const ICON_CENTERS := [Vector2(201, 385), Vector2(467, 385), Vector2(733, 385), Vector2(999, 385)]
const CHECKBOX_CENTERS := [Vector2(201, 530), Vector2(467, 530), Vector2(733, 530), Vector2(999, 530)]
const CHECK_SCALE := 0.2
const PULSE := 1.08

@export var kid: KidProfile:
	set(value):
		kid = value
		if is_node_ready():
			$Sprite.texture = kid.card() if kid else null

var _pulse: Tween

@onready var _glow: Sprite2D = $Glow
@onready var _checks: Node2D = $Checks


func _ready() -> void:
	kid = kid
	_glow.visible = false


func highlight(index: int) -> void:
	if _pulse:
		_pulse.kill()
	_glow.visible = index >= 0
	_glow.scale = Vector2.ONE
	if index < 0:
		return
	_glow.position = ICON_CENTERS[index]
	_pulse = create_tween().set_loops()
	_pulse.tween_property(_glow, "scale", Vector2.ONE * PULSE, 0.5).set_trans(Tween.TRANS_SINE)
	_pulse.tween_property(_glow, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_SINE)


func stamp(index: int) -> void:
	var check := Sprite2D.new()
	check.texture = preload("res://assets/props/shared/check-mark.png")
	check.position = CHECKBOX_CENTERS[index]
	check.scale = Vector2.ZERO
	_checks.add_child(check)
	var pop := create_tween()
	pop.tween_property(check, "scale", Vector2.ONE * CHECK_SCALE * 1.2, 0.15)
	pop.tween_property(check, "scale", Vector2.ONE * CHECK_SCALE, 0.1)


func clear() -> void:
	for check in _checks.get_children():
		_checks.remove_child(check)
		check.queue_free()
	highlight(-1)


func stamped_count() -> int:
	return _checks.get_child_count()
