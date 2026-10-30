# The Find game: the drawer opens up close, the item to find is pictured
# above it, and the child drags the matching one onto the picture. Becca
# gets fewer, more different choices than Jack-Jack (KidProfile.choices).
class_name DrawerView
extends Node2D

signal found(item: String)

const TARGET_CENTER := Vector2(960, 210)
const ROW_Y := 540.0
const ROW_LEFT := 600.0
const ROW_RIGHT := 1400.0
const ITEM_SCALE := 0.45
const MISSES_BEFORE_HINT := 2
const ITEM_SCENE := preload("res://scenes/item.tscn")

var wrong_count := 0

var _item := ""
var _correct: Draggable

@onready var _slot: Sprite2D = $Slot
@onready var _target: Sprite2D = $Target
@onready var _items: Node2D = $Items
@onready var _helper: Character = $Helper


func _ready() -> void:
	visible = false


func open(kid: KidProfile, helper: KidProfile, item: String, rng_seed: int = -1) -> void:
	close()
	_item = item
	wrong_count = 0
	_helper.kid = helper
	_helper.set_pose("idle")
	var rng := RandomNumberGenerator.new()
	if rng_seed >= 0:
		rng.seed = rng_seed
	else:
		rng.randomize()
	var textures := kid.pick_colors(item, rng)
	var correct_texture := textures[0]
	_target.texture = correct_texture
	for i in range(textures.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap := textures[i]
		textures[i] = textures[j]
		textures[j] = swap
	var zone := Rect2(_slot.global_position - _slot.texture.get_size() / 2, _slot.texture.get_size())
	var n := textures.size()
	for i in n:
		var choice: Draggable = ITEM_SCENE.instantiate()
		choice.texture = textures[i]
		choice.home_scale = ITEM_SCALE
		choice.position = Vector2(lerpf(ROW_LEFT, ROW_RIGHT, (i + 0.5) / n), ROW_Y)
		choice.drop_zone = zone
		choice.snap_point = TARGET_CENTER
		choice.accept_drop = textures[i] == correct_texture
		if choice.accept_drop:
			_correct = choice
			choice.placed.connect(_on_placed)
		else:
			choice.rejected.connect(_on_rejected)
		_items.add_child(choice)
	visible = true


func close() -> void:
	visible = false
	_correct = null
	for child in _items.get_children():
		_items.remove_child(child)
		child.queue_free()


func choices() -> Array[Draggable]:
	var out: Array[Draggable] = []
	for child in _items.get_children():
		out.append(child)
	return out


func correct_choice() -> Draggable:
	return _correct


func is_dragging() -> bool:
	return choices().any(func(c): return c.is_dragging)


func _on_placed(choice: Draggable) -> void:
	_helper.set_pose("idle")
	await get_tree().create_timer(Draggable.SNAP_TIME + 0.15).timeout
	if choice == _correct and is_inside_tree():
		found.emit(_item)


func _on_rejected(_choice: Draggable) -> void:
	wrong_count += 1
	if wrong_count >= MISSES_BEFORE_HINT and _correct:
		_helper.point_at(_correct.global_position)
