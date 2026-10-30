# Title: both kids wave in Jack-Jack's room and the game asks "Who do you want
# to play as?" out loud. Tapping a kid picks them; tapping anywhere else
# repeats the question.
extends Node2D

const WAVE_EVERY := 3.0
const PICK_DELAY := 0.6
const BG_SIZE := Vector2(1672, 941)
const JACK_FEET := Vector2(560, 905)
const BECCA_FEET := Vector2(1110, 905)
const KID_SCALE := 0.5
## Name labels float this far above each kid's head, in background pixels.
const NAME_GAP := 40.0
## Holding the version stamp this long wipes saved progress (a grown-up's escape hatch).
const RESET_HOLD := 5.0
const STAMP_PAD := 24.0

var _picked := false
var _next_waver := 0
var _stamp_down_at := -1.0

@onready var _stage: Node2D = $Stage
@onready var _jack: Character = $Stage/Jack
@onready var _becca: Character = $Stage/Becca
@onready var _voice: AudioStreamPlayer = $Voice


func _ready() -> void:
	_jack.kid = load(Game.KIDS["jack"])
	_becca.kid = load(Game.KIDS["becca"])
	$Stage/Background.texture = _jack.kid.room()
	for pair in [[_jack, JACK_FEET, $Stage/JackName], [_becca, BECCA_FEET, $Stage/BeccaName]]:
		var kid: Character = pair[0]
		kid.position = pair[1] - BG_SIZE / 2
		kid.height_scale = KID_SCALE
		var label: Label = pair[2]
		label.label_settings = label.label_settings.duplicate()
		label.label_settings.font_color = kid.kid.ribbon_color
		var head_y: float = kid.position.y - kid.hit_rect().size.y / _stage.scale.y
		label.position = Vector2(kid.position.x - label.size.x / 2, head_y - NAME_GAP - label.size.y)
	_becca.mirrored = true
	get_viewport().size_changed.connect(_fit)
	_fit()
	$VersionLabel.text = "v" + ProjectSettings.get_setting("application/config/version")
	$WaveTimer.wait_time = WAVE_EVERY
	$WaveTimer.timeout.connect(_wave_next)
	$WaveTimer.start()
	_wave_next()
	_voice.play()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var point := get_global_mouse_position()
	var stamp := Rect2($VersionLabel.global_position, $VersionLabel.size).grow(STAMP_PAD)
	if not event.pressed:
		if _stamp_down_at >= 0.0:
			var held := Time.get_ticks_msec() / 1000.0 - _stamp_down_at
			_stamp_down_at = -1.0
			# Only a long, deliberate hold that ends on the stamp counts.
			if held >= RESET_HOLD and stamp.has_point(point):
				Progress.reset()
				$VersionLabel.text += "  progress reset"
			elif not _picked:
				_voice.play()
		return
	if stamp.has_point(point):
		_stamp_down_at = Time.get_ticks_msec() / 1000.0
		return
	if _picked:
		return
	for kid in [_jack, _becca]:
		if kid.hit_rect().has_point(point):
			_pick(kid)
			return
	_voice.play()


func _pick(kid: Character) -> void:
	_picked = true
	$WaveTimer.stop()
	kid.cheer()
	await get_tree().create_timer(PICK_DELAY).timeout
	Game.pick(kid.kid.id)


func _wave_next() -> void:
	var kid: Character = [_jack, _becca][_next_waver]
	_next_waver = 1 - _next_waver
	if not _picked:
		kid.wave()


func _fit() -> void:
	var view := get_viewport().get_visible_rect().size
	_stage.scale = Vector2.ONE * maxf(view.x / BG_SIZE.x, view.y / BG_SIZE.y)
	var top := 540 - view.y / 2
	$Question.position.y = top + 24
	# Version stamp in the bottom-left corner, so you can tell which build is installed.
	$VersionLabel.position = Vector2(960 - view.x / 2 + 16, 540 + view.y / 2 - 16 - $VersionLabel.size.y)
