# A generic item the player picks up and drops into a target slot.
# Drop it over the drop zone and it snaps to the slot; drop it anywhere else
# and it glides back home. Mouse events only: touch arrives as emulated mouse.
class_name Draggable
extends Node2D

signal placed(item: Draggable)

const DROP_MARGIN := 80.0
const GRAB_PADDING := 40.0
const LIFT_SCALE := 1.15
const SNAP_TIME := 0.25
const RETURN_TIME := 0.4
const LIFTED_Z := 10

## Global-space rect that counts as "in the target". Set by the level.
@export var drop_zone: Rect2
## Global position the item snaps to when dropped in the zone.
@export var snap_point: Vector2

var home_position: Vector2
var is_placed := false
var is_dragging := false

var _grab_offset := Vector2.ZERO
var _tween: Tween

@onready var _sprite: Sprite2D = $Sprite
@onready var _shadow: Sprite2D = $Shadow


func _ready() -> void:
	home_position = global_position


static func in_drop_zone(point: Vector2, zone: Rect2, margin: float) -> bool:
	return zone.grow(margin).has_point(point)


func begin_drag(global_point: Vector2) -> bool:
	if is_placed or is_dragging or not _grab_rect().has_point(global_point):
		return false
	_kill_tween()
	is_dragging = true
	_grab_offset = global_position - global_point
	scale = Vector2.ONE * LIFT_SCALE
	_shadow.visible = true
	z_index = LIFTED_Z
	return true


func drag_to(global_point: Vector2) -> void:
	if is_dragging:
		global_position = global_point + _grab_offset


func end_drag(global_point: Vector2) -> bool:
	if not is_dragging:
		return false
	drag_to(global_point)
	is_dragging = false
	_shadow.visible = false
	var hit := in_drop_zone(global_position, drop_zone, DROP_MARGIN)
	_tween = create_tween().set_parallel()
	if hit:
		is_placed = true
		_tween.tween_property(self, "global_position", snap_point, SNAP_TIME) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_tween.tween_property(self, "scale", Vector2.ONE, SNAP_TIME)
		placed.emit(self)
	else:
		_tween.tween_property(self, "global_position", home_position, RETURN_TIME) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_tween.tween_property(self, "scale", Vector2.ONE, RETURN_TIME)
	_tween.chain().tween_callback(func(): z_index = 0)
	return hit


func reset() -> void:
	_kill_tween()
	global_position = home_position
	scale = Vector2.ONE
	z_index = 0
	_shadow.visible = false
	is_placed = false
	is_dragging = false


func _unhandled_input(event: InputEvent) -> void:
	var point := get_global_mouse_position()
	var handled := false
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		handled = begin_drag(point) if event.pressed else end_drag(point)
	elif event is InputEventMouseMotion and is_dragging:
		drag_to(point)
		handled = true
	if handled:
		get_viewport().set_input_as_handled()


func _grab_rect() -> Rect2:
	var rect := _sprite.get_rect()
	var s := _sprite.global_scale
	return Rect2(_sprite.global_position + rect.position * s, rect.size * s).grow(GRAB_PADDING)


func _kill_tween() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
