# The card as the level map. The child's own card fills the screen: finished
# rows wear a big check, the next row pulses, and tapping a finished or next
# row plays it. Later rows stay locked.
extends Node2D

const BG_SIZE := Vector2(1672, 941)
const CARD_SIZE := Vector2(1200, 1600)
const MARGIN := 24.0
const HELPER_SCALE := 0.35
const HELPER_MARGIN := Vector2(150, 24)
const HOME_SIZE := 150.0

var _started := false
var _idle := 0.0

@onready var _background: Sprite2D = $Background
@onready var _dim: Sprite2D = $Dim
@onready var _card: Card = $Card
@onready var _helper: Character = $Helper
@onready var _home: TextureButton = $HomeButton


func _ready() -> void:
	var kid := Game.kid
	_background.texture = kid.room()
	_card.kid = kid
	_helper.kid = Game.sibling()
	_helper.height_scale = HELPER_SCALE
	_helper.mirrored = true
	_home.pressed.connect(func(): Game.goto(Game.TITLE))
	var done := Progress.levels_done(kid.id)
	for row in Progress.LEVELS:
		if done.has(row):
			_card.stamp_row(row)
	_card.highlight_row(Progress.next_level(kid.id))
	Voice.say(_line(), Game.sibling())
	get_viewport().size_changed.connect(_fit)
	_fit()


## Global center of a row, for taps in tests.
func row_point(row: int) -> Vector2:
	return _card.to_global(_card.row_rect(row).get_center())


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if _started:
		return
	_idle = 0.0
	var local := _card.to_local(get_global_mouse_position())
	for row in Progress.LEVELS:
		if _card.row_rect(row).has_point(local) and _playable(row):
			_started = true
			Game.play_level(row)
			return
	# A tap that starts nothing: say again what to do, and show where.
	_prompt()


func _process(delta: float) -> void:
	if _started:
		return
	_idle += delta
	if _idle >= Game.kid.hint_delay:
		_idle = 0.0
		_prompt()


func _prompt() -> void:
	var next := Progress.next_level(Game.kid.id)
	if next < Progress.LEVELS:
		_helper.point_at(row_point(next))
	Voice.say(_line(), Game.sibling())


## "Tap the row that's wiggling", or a cheer once the whole card is packed.
func _line() -> String:
	return "all-packed" if Progress.next_level(Game.kid.id) >= Progress.LEVELS else "pick-a-row"


func _playable(row: int) -> bool:
	var kid_id := Game.kid.id
	return Progress.levels_done(kid_id).has(row) or row == Progress.next_level(kid_id)


func _fit() -> void:
	var view := get_viewport().get_visible_rect().size
	var top := 540.0 - view.y / 2
	var left := 960.0 - view.x / 2
	var cover := maxf(view.x / BG_SIZE.x, view.y / BG_SIZE.y)
	_background.position = Vector2(960, 540)
	_background.scale = Vector2.ONE * cover
	_dim.position = Vector2(960, 540)
	_dim.scale = view / _dim.texture.get_size()
	var s := (view.y - 2 * MARGIN) / CARD_SIZE.y
	_card.scale = Vector2.ONE * s
	_card.position = Vector2(960 - CARD_SIZE.x * s / 2, top + MARGIN)
	_helper.position = Vector2(960 + view.x / 2 - HELPER_MARGIN.x, 540 + view.y / 2 - HELPER_MARGIN.y)
	_home.position = Vector2(left + MARGIN, top + MARGIN)
	_home.size = Vector2.ONE * HOME_SIZE
