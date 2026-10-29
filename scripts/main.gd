# The bedroom level: wires the shirt to the suitcase, celebrates a success,
# resets on replay and stamps the build version in the corner.
extends Node2D

const STAR_COUNT := 8
const STAR_DISTANCE := 250.0
const STAR_TIME := 0.7
const REPLAY_DELAY := 0.6
const STAR_TEXTURE := preload("res://assets/art/star.png")

var _tweens: Array[Tween] = []

@onready var _shirt: Draggable = $Shirt
@onready var _suitcase: Sprite2D = $Suitcase
@onready var _slot: Sprite2D = $Slot
@onready var _stars: Node2D = $Stars
@onready var _check: Sprite2D = $Check
@onready var _replay: TextureButton = $ReplayButton
@onready var _chime: AudioStreamPlayer = $Chime


static func version_text() -> String:
	return "v" + str(ProjectSettings.get_setting("application/config/version"))


func _ready() -> void:
	$UI/VersionLabel.text = version_text()
	var rect := _suitcase.get_rect()
	_shirt.drop_zone = Rect2(_suitcase.global_position + rect.position, rect.size)
	_shirt.snap_point = _slot.global_position
	_shirt.placed.connect(_on_item_placed)
	_replay.pressed.connect(reset_level)


func _on_item_placed(_item: Draggable) -> void:
	_slot.visible = false
	_chime.play()
	for i in STAR_COUNT:
		_spawn_star(TAU * i / STAR_COUNT)
	_check.scale = Vector2.ZERO
	_check.visible = true
	var pop := _track(create_tween())
	pop.tween_property(_check, "scale", Vector2.ONE * 1.2, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop.tween_property(_check, "scale", Vector2.ONE, 0.1)
	var replay := _track(create_tween())
	replay.tween_interval(REPLAY_DELAY)
	replay.tween_callback(func(): _replay.visible = true)


func reset_level() -> void:
	for tween in _tweens:
		if tween.is_valid():
			tween.kill()
	_tweens.clear()
	for star in _stars.get_children():
		_stars.remove_child(star)
		star.queue_free()
	_check.visible = false
	_replay.visible = false
	_slot.visible = true
	_shirt.reset()


func _spawn_star(angle: float) -> void:
	var star := Sprite2D.new()
	star.texture = STAR_TEXTURE
	star.global_position = _slot.global_position
	_stars.add_child(star)
	var tween := _track(create_tween().set_parallel())
	tween.tween_property(star, "global_position", _slot.global_position + Vector2.from_angle(angle) * STAR_DISTANCE, STAR_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(star, "modulate:a", 0.0, STAR_TIME)
	tween.chain().tween_callback(star.queue_free)


func _track(tween: Tween) -> Tween:
	_tweens.append(tween)
	return tween
