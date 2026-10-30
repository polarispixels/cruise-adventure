# The child's picture card. Glows around the item to find next and stamps a
# check in its box once it's packed. Positions are in card pixels.
class_name Card
extends Node2D

## The card's four rows, from the video project's verification data. Both
## cards share the layout. Row 0 is shirt, shorts, underwear, socks.
const COLUMNS := [201.0, 467.0, 733.0, 999.0]
const ICON_YS := [386.0, 700.0, 1016.0, 1330.0]
const CHECKBOX_YS := [530.0, 845.0, 1160.0, 1475.0]
## Row 0, kept for callers that only know the first row.
const ICON_CENTERS := [Vector2(201, 386), Vector2(467, 386), Vector2(733, 386), Vector2(999, 386)]
const CHECKBOX_CENTERS := [Vector2(201, 530), Vector2(467, 530), Vector2(733, 530), Vector2(999, 530)]
const CHECK_SCALE := 0.2
const PULSE := 1.08
## A row spans from above the icons to below the checkboxes, and past the outer columns.
const ROW_TOP_PAD := 118.0
const ROW_BOTTOM_PAD := 52.0
const ROW_SIDE_PAD := 129.0
const GLOW_MARGIN := 14.0
const ITEM_GLOW := preload("res://assets/ui/card-glow.png")
const ROW_GLOW := preload("res://assets/ui/row-glow.png")

@export var kid: KidProfile:
	set(value):
		kid = value
		if is_node_ready():
			$Sprite.texture = kid.card() if kid else null

var _pulse: Tween

@onready var _glow: Sprite2D = $Glow
@onready var _checks: Node2D = $Checks
@onready var _row_checks: Node2D = $RowChecks


func _ready() -> void:
	kid = kid
	_glow.visible = false


## Card-pixel rectangle covering a row's icons and checkboxes.
func row_rect(row: int) -> Rect2:
	var left: float = COLUMNS[0] - ROW_SIDE_PAD
	var right: float = COLUMNS[3] + ROW_SIDE_PAD
	var top: float = ICON_YS[row] - ROW_TOP_PAD
	var bottom: float = CHECKBOX_YS[row] + ROW_BOTTOM_PAD
	return Rect2(left, top, right - left, bottom - top)


## Glow around one item's icon.
func highlight(index: int, row := 0) -> void:
	_glow.texture = ITEM_GLOW
	_start_glow(index >= 0, Vector2(COLUMNS[index], ICON_YS[row]) if index >= 0 else Vector2.ZERO, Vector2.ONE)


## Glow stretched over a whole row; -1 hides it.
func highlight_row(row: int) -> void:
	if row < 0 or row >= ICON_YS.size():
		_start_glow(false, Vector2.ZERO, Vector2.ONE)
		return
	_glow.texture = ROW_GLOW
	var rect := row_rect(row)
	# The row glow's ring sits GLOW_MARGIN inside its art, so the art reaches past the row by that much.
	var art_size := rect.size + Vector2.ONE * GLOW_MARGIN * 2
	_start_glow(true, rect.get_center(), art_size / _glow.texture.get_size())


func stamp(index: int, row := 0) -> void:
	_pop(_checks, Vector2(COLUMNS[index], CHECKBOX_YS[row]), CHECK_SCALE)


## A big check over a finished row, separate from the item checks.
func stamp_row(row: int) -> void:
	var rect := row_rect(row)
	var texture: Texture2D = preload("res://assets/props/shared/check-mark.png")
	_pop(_row_checks, rect.get_center(), rect.size.y / texture.get_size().y)


func clear() -> void:
	for layer: Node2D in [_checks, _row_checks]:
		for check in layer.get_children():
			layer.remove_child(check)
			check.queue_free()
	highlight(-1)


func stamped_count() -> int:
	return _checks.get_child_count()


func _start_glow(shown: bool, center: Vector2, base: Vector2) -> void:
	if _pulse:
		_pulse.kill()
	_glow.visible = shown
	_glow.scale = base
	if not shown:
		return
	_glow.position = center
	_pulse = create_tween().set_loops()
	_pulse.tween_property(_glow, "scale", base * PULSE, 0.5).set_trans(Tween.TRANS_SINE)
	_pulse.tween_property(_glow, "scale", base, 0.5).set_trans(Tween.TRANS_SINE)


func _pop(layer: Node2D, at: Vector2, final_scale: float) -> void:
	var check := Sprite2D.new()
	check.texture = preload("res://assets/props/shared/check-mark.png")
	check.position = at
	check.scale = Vector2.ZERO
	layer.add_child(check)
	var pop := create_tween()
	pop.tween_property(check, "scale", Vector2.ONE * final_scale * 1.2, 0.15)
	pop.tween_property(check, "scale", Vector2.ONE * final_scale, 0.1)
