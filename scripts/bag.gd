# One family bag in the trunk puzzle. Drawn standing; turned, the picture
# rotates a quarter turn. The node sits at the bag's center. The trunk scene
# does the dragging; this only draws, moves and wiggles.
class_name Bag
extends Node2D

const LIFT_SCALE := 1.08
const LIFTED_Z := 10
const GLIDE_TIME := 0.3
const WIGGLE_ANGLE := deg_to_rad(6.0)
const WIGGLE_TIME := 0.3
const PULSE_SCALE := 1.08
const PULSE_TIME := 0.45

var id := ""
var locked := false
## Size in cells, standing.
var cells := Vector2i.ONE
## Screen pixels per cell.
var cell_px := 100.0
var turned := false

var _tween: Tween
var _wiggle: Tween
var _pulse: Tween

@onready var _sprite: Sprite2D = $Sprite


func setup(bag_id: String, size: Vector2i, px: float, texture: Texture2D) -> void:
	id = bag_id
	cells = size
	_sprite.texture = texture
	set_cell_px(px)


func set_cell_px(px: float) -> void:
	cell_px = px
	var tex := _sprite.texture.get_size()
	_sprite.scale = Vector2(cells) * cell_px / tex


func set_turned(on: bool) -> void:
	turned = on
	_sprite.rotation = PI / 2 if on else 0.0


## Global rect the bag covers.
func rect() -> Rect2:
	var s := Vector2(cells.y, cells.x) if turned else Vector2(cells)
	var size := s * cell_px * global_scale
	return Rect2(global_position - size / 2, size)


func lift() -> void:
	_kill()
	stop_pulse()
	scale = Vector2.ONE * LIFT_SCALE
	rotation = 0.0
	z_index = LIFTED_Z


func glide_to(point: Vector2) -> void:
	_kill()
	_tween = create_tween().set_parallel()
	_tween.tween_property(self, "global_position", point, GLIDE_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "scale", Vector2.ONE, GLIDE_TIME)
	_tween.chain().tween_callback(func(): z_index = 0)


func jump_to(point: Vector2) -> void:
	_kill()
	global_position = point
	scale = Vector2.ONE
	z_index = 0


## A "no" shake on its own tween, so a bag still gliding into place keeps going.
func wiggle() -> void:
	if _wiggle and _wiggle.is_valid():
		_wiggle.kill()
	_wiggle = create_tween()
	var step := WIGGLE_TIME / 6
	for i in 3:
		_wiggle.tween_property(self, "rotation", WIGGLE_ANGLE, step)
		_wiggle.tween_property(self, "rotation", -WIGGLE_ANGLE, step)
	_wiggle.tween_property(self, "rotation", 0.0, step / 2)


func pulse() -> void:
	stop_pulse()
	_pulse = create_tween().set_loops()
	_pulse.tween_property(_sprite, "modulate", Color(1.3, 1.3, 1.1), PULSE_TIME)
	_pulse.tween_property(_sprite, "modulate", Color.WHITE, PULSE_TIME)


func stop_pulse() -> void:
	if _pulse and _pulse.is_valid():
		_pulse.kill()
	_sprite.modulate = Color.WHITE


func is_pulsing() -> bool:
	return _pulse != null and _pulse.is_valid()


func _kill() -> void:
	for tween in [_tween, _wiggle]:
		if tween and tween.is_valid():
			tween.kill()
	rotation = 0.0
