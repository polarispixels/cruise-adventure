# One child drawn from their pose sheets. The origin is the feet, so swapping
# poses never makes the child jump around.
class_name Character
extends Node2D

const WAVE_FRAME := 0.18
const HOP := 40.0
const HOP_TIME := 0.35
const CHEER_TIME := 1.0
const CLAP_TIME := 0.8

@export var kid: KidProfile:
	set(value):
		kid = value
		if is_node_ready():
			set_pose(pose)
@export var mirrored := false:
	set(value):
		mirrored = value
		_face(mirrored)
@export var height_scale := 0.45:
	set(value):
		height_scale = value
		_face(scale.x < 0)

var pose := "idle"

var _tween: Tween
var _rest_y := 0.0

@onready var _sprite: Sprite2D = $Sprite


func _ready() -> void:
	_face(mirrored)
	set_pose("idle")


## Shows a pose and stops whatever action was playing.
func set_pose(name: String) -> void:
	_stop()
	_show(name)
	if name == "idle":
		_face(mirrored)


func wave() -> void:
	_begin()
	for frame in ["wave-1", "wave-2", "wave-1", "wave-2"]:
		_tween.tween_callback(_show.bind(frame))
		_tween.tween_interval(WAVE_FRAME)
	_tween.tween_callback(_show.bind("idle"))


func cheer() -> void:
	_begin()
	_show("cheer")
	_tween.tween_property(self, "position:y", _rest_y - HOP * height_scale / 0.45, HOP_TIME / 2).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "position:y", _rest_y, HOP_TIME / 2).set_ease(Tween.EASE_IN)
	_tween.tween_interval(CHEER_TIME - HOP_TIME)
	_tween.tween_callback(_show.bind("idle"))


func clap() -> void:
	_begin()
	_show("clap")
	var squash := Vector2(scale.x * 1.05, scale.y * 0.95)
	var rest := scale
	_tween.tween_property(self, "scale", squash, 0.1)
	_tween.tween_property(self, "scale", rest, 0.1)
	_tween.tween_interval(CLAP_TIME - 0.2)
	_tween.tween_callback(_show.bind("idle"))


## Points at a spot until the next action. The pose art points to the right.
func point_at(global_target: Vector2) -> void:
	_stop()
	_show("point")
	_face(global_target.x < global_position.x)


## Global rect around the body, for tapping a child.
func hit_rect() -> Rect2:
	var a := global_transform * Vector2(-260, -1180)
	var b := global_transform * Vector2(260, 0)
	return Rect2(a, Vector2.ZERO).expand(b)


func _begin() -> void:
	_stop()
	_face(mirrored)
	_tween = create_tween()


func _stop() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
		position.y = _rest_y
		_face(scale.x < 0)
	_tween = null
	_rest_y = position.y


func _show(name: String) -> void:
	pose = name
	if kid and _sprite:
		_sprite.texture = kid.character(name)


func _face(left: bool) -> void:
	scale = Vector2(-height_scale if left else height_scale, height_scale)
