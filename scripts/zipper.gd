# A zipper pull the child drags along the suitcase seam. Wherever the finger
# goes, the pull follows the closest point on the seam. Reaching the end zips.
class_name Zipper
extends Node2D

signal zipped

const GRAB_RADIUS := 90.0
const DONE_AT := 0.95

## Seam ends in local coordinates.
@export var start: Vector2:
	set(value):
		start = value
		_place()
@export var end: Vector2:
	set(value):
		end = value
		_place()

var progress := 0.0
var is_dragging := false

var _done := false

@onready var _pull: Sprite2D = $Pull


func _ready() -> void:
	_place()


func reset() -> void:
	progress = 0.0
	_done = false
	is_dragging = false
	_place()


func begin(global_point: Vector2) -> bool:
	if _done or is_dragging:
		return false
	if to_local(global_point).distance_to(_pull.position) > GRAB_RADIUS / absf(global_scale.y):
		return false
	is_dragging = true
	return true


func drag(global_point: Vector2) -> void:
	if not is_dragging:
		return
	var seam := end - start
	progress = clampf((to_local(global_point) - start).dot(seam) / seam.length_squared(), 0.0, 1.0)
	if progress >= DONE_AT:
		progress = 1.0
		is_dragging = false
		_done = true
		_place()
		zipped.emit()
		return
	_place()


func release() -> void:
	is_dragging = false


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	var point := get_global_mouse_position()
	var handled := false
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			handled = begin(point)
		elif is_dragging:
			release()
			handled = true
	elif event is InputEventMouseMotion and is_dragging:
		drag(point)
		handled = true
	if handled:
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		release()


func _place() -> void:
	if _pull:
		_pull.position = start.lerp(end, progress)
