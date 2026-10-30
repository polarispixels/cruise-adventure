# A generic item the player picks up and drops into a target slot.
# Drop it over the drop zone and it snaps to the slot; drop it anywhere else
# and it glides back home. An item that doesn't belong (accept_drop off)
# wiggles "no" in the zone and glides back home too. Mouse events only: touch arrives as emulated mouse.
class_name Draggable
extends Node2D

signal placed(item: Draggable)
signal rejected(item: Draggable)

const DROP_MARGIN := 80.0
const GRAB_PADDING := 40.0
const LIFT_SCALE := 1.15
const SNAP_TIME := 0.25
const RETURN_TIME := 0.4
const LIFTED_Z := 10
const WIGGLE_ANGLE := deg_to_rad(8.0)
const WIGGLE_TIME := 0.3

## Global-space rect that counts as "in the target". Set by the level.
@export var drop_zone: Rect2
## Global position the item snaps to when dropped in the zone.
@export var snap_point: Vector2
@export var texture: Texture2D:
	set(value):
		texture = value
		if is_node_ready():
			_apply_texture()
## False for a wrong choice: dropping it in the zone wiggles it back home.
@export var accept_drop := true
## Scale at rest; lifting multiplies it by LIFT_SCALE.
@export var home_scale := 1.0:
	set(value):
		home_scale = value
		if not is_dragging:
			scale = Vector2.ONE * home_scale

var home_position: Vector2
var is_placed := false
var is_dragging := false

var _grab_offset := Vector2.ZERO
var _tween: Tween

@onready var _sprite: Sprite2D = $Sprite
@onready var _shadow: Sprite2D = $Shadow


func _ready() -> void:
	home_position = global_position
	scale = Vector2.ONE * home_scale
	_apply_texture()


static func in_drop_zone(point: Vector2, zone: Rect2, margin: float) -> bool:
	return zone.grow(margin).has_point(point)


func begin_drag(global_point: Vector2) -> bool:
	if is_placed or is_dragging or not _grab_rect().has_point(global_point):
		return false
	_kill_tween()
	rotation = 0.0
	is_dragging = true
	_grab_offset = global_position - global_point
	scale = Vector2.ONE * home_scale * LIFT_SCALE
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
	var rest := Vector2.ONE * home_scale
	if hit and not accept_drop:
		_reject()
		return false
	_tween = create_tween().set_parallel()
	if hit:
		is_placed = true
		_tween.tween_property(self, "global_position", snap_point, SNAP_TIME) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_tween.tween_property(self, "scale", rest, SNAP_TIME)
		placed.emit(self)
	else:
		_tween.tween_property(self, "global_position", home_position, RETURN_TIME) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_tween.tween_property(self, "scale", rest, RETURN_TIME)
	_tween.chain().tween_callback(func(): z_index = 0)
	return hit


func reset() -> void:
	_kill_tween()
	global_position = home_position
	scale = Vector2.ONE * home_scale
	rotation = 0.0
	z_index = 0
	_shadow.visible = false
	is_placed = false
	is_dragging = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_drop_where_it_is()


func _unhandled_input(event: InputEvent) -> void:
	var point := get_global_mouse_position()
	var handled := false
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			# A press while still dragging means the last release was lost.
			_drop_where_it_is()
			handled = begin_drag(point)
		else:
			handled = end_drag(point)
	elif event is InputEventMouseMotion and is_dragging:
		drag_to(point)
		handled = true
	if handled:
		get_viewport().set_input_as_handled()


func _reject() -> void:
	rejected.emit(self)
	_tween = create_tween()
	var step := WIGGLE_TIME / 6
	for i in 3:
		_tween.tween_property(self, "rotation", WIGGLE_ANGLE, step)
		_tween.tween_property(self, "rotation", -WIGGLE_ANGLE, step)
	_tween.tween_property(self, "rotation", 0.0, step / 2)
	_tween.tween_property(self, "global_position", home_position, RETURN_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.parallel().tween_property(self, "scale", Vector2.ONE * home_scale, RETURN_TIME)
	_tween.tween_callback(func(): z_index = 0)


func _apply_texture() -> void:
	_sprite.texture = texture
	_shadow.texture = texture


func _drop_where_it_is() -> void:
	if is_dragging:
		end_drag(global_position - _grab_offset)


func _grab_rect() -> Rect2:
	var rect := _sprite.get_rect()
	var s := _sprite.global_scale
	return Rect2(_sprite.global_position + rect.position * s, rect.size * s).grow(GRAB_PADDING)


func _kill_tween() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
