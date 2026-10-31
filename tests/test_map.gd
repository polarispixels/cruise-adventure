# The card map: real touches through the input pipeline.
extends RefCounted

const TMP := "user://test_progress_map.json"

var _to_screen := Transform2D.IDENTITY
var _requests: Array[String] = []


func _make(t, kid_id := "becca", done: Array = []) -> Node2D:
	var progress: Node = t.tree.root.get_node("Progress")
	progress.path = TMP
	progress.reset()
	for level: int in done:
		progress.mark_done(kid_id, level)
	var game: Node = t.tree.root.get_node("Game")
	game.navigate = false
	game.last_scene_request = ""
	game.level = -1
	_requests.clear()
	if not game.scene_requested.is_connected(_on_request):
		game.scene_requested.connect(_on_request)
	game.kid = load("res://data/%s.tres" % kid_id)
	var map: Node2D = load("res://scenes/map.tscn").instantiate()
	t.tree.root.add_child(map)
	await t.tree.process_frame
	await t.tree.process_frame
	_to_screen = t.tree.root.get_final_transform() * map.get_canvas_transform()
	return map


func _done(t, map: Node) -> void:
	map.free()
	var progress: Node = t.tree.root.get_node("Progress")
	progress.reset()
	progress.path = "user://progress.json"


func _on_request(path: String) -> void:
	_requests.append(path)


func _touch(t, pressed: bool, world: Vector2) -> void:
	var e := InputEventScreenTouch.new()
	e.pressed = pressed
	e.position = _to_screen * world
	Input.parse_input_event(e)
	Input.flush_buffered_events()
	await t.tree.process_frame


func _tap(t, world: Vector2) -> void:
	await _touch(t, true, world)
	await _touch(t, false, world)


func test_fresh_map_pulses_first_row(t) -> void:
	var map := await _make(t)
	var card: Card = map.get_node("Card")
	t.eq(card.get_node("RowChecks").get_child_count(), 0, "nothing stamped")
	var glow: Sprite2D = card.get_node("Glow")
	t.check(glow.visible, "glow shown")
	t.eq(glow.position, card.row_rect(0).get_center(), "on row 0")
	_done(t, map)


func test_done_rows_stamped_next_row_pulses(t) -> void:
	var map := await _make(t, "jack", [0, 1])
	var card: Card = map.get_node("Card")
	t.eq(card.get_node("RowChecks").get_child_count(), 2, "two rows stamped")
	t.eq(card.get_node("Glow").position, card.row_rect(2).get_center(), "row 2 pulses")
	_done(t, map)


func test_all_done_stamps_every_row_and_no_pulse(t) -> void:
	var map := await _make(t, "becca", [0, 1, 2, 3])
	var card: Card = map.get_node("Card")
	t.eq(card.get_node("RowChecks").get_child_count(), 4, "four stamped")
	t.check(not card.get_node("Glow").visible, "nothing pulses")
	_done(t, map)


func test_card_fills_height_and_is_centered(t) -> void:
	var map := await _make(t)
	var card: Card = map.get_node("Card")
	var view := map.get_viewport().get_visible_rect().size
	var h: float = 1600.0 * card.scale.y
	t.check(h <= view.y and h >= view.y * 0.9, "fills height: %f of %f" % [h, view.y])
	t.check(absf(card.global_position.x + 600.0 * card.scale.x - 960.0) < 1.0, "centered")
	_done(t, map)


func test_tap_next_row_plays_it(t) -> void:
	var map := await _make(t, "becca", [0])
	await _tap(t, map.row_point(1))
	var game: Node = t.tree.root.get_node("Game")
	t.eq(game.last_scene_request, game.INTRO, "a new row starts with its video, then the room")
	t.eq(game.level, 1, "level 1")
	game.intro_level = -1
	_done(t, map)


func test_tap_locked_row_does_nothing(t) -> void:
	var map := await _make(t, "becca", [0])
	await _tap(t, map.row_point(3))
	await _tap(t, map.row_point(2))
	t.eq(_requests.size(), 0, "no navigation")
	_done(t, map)


func test_tap_done_row_replays_it(t) -> void:
	var map := await _make(t, "jack", [0, 1])
	await _tap(t, map.row_point(0))
	var game: Node = t.tree.root.get_node("Game")
	t.eq(game.last_scene_request, game.ROOM, "to room")
	t.eq(game.level, 0, "level 0")
	_done(t, map)


func test_all_done_any_row_tappable(t) -> void:
	var map := await _make(t, "becca", [0, 1, 2, 3])
	await _tap(t, map.row_point(3))
	t.eq(t.tree.root.get_node("Game").level, 3, "level 3")
	_done(t, map)


func test_tap_outside_card_does_nothing(t) -> void:
	var map := await _make(t)
	await _tap(t, Vector2(100, 700))
	t.eq(_requests.size(), 0, "no navigation")
	_done(t, map)


func test_double_tap_plays_once(t) -> void:
	var map := await _make(t)
	await _tap(t, map.row_point(0))
	await _tap(t, map.row_point(0))
	t.eq(_requests.size(), 1, "once")
	_done(t, map)


func test_home_button_goes_to_title(t) -> void:
	var map := await _make(t)
	var button: TextureButton = map.get_node("HomeButton")
	t.check(button.global_position.x < 400 and button.global_position.y < 400, "top left")
	await _tap(t, button.global_position + button.size / 2)
	t.eq(t.tree.root.get_node("Game").last_scene_request, "res://scenes/title.tscn", "to title")
	_done(t, map)


func test_helper_is_the_sibling_bottom_right(t) -> void:
	var map := await _make(t, "becca")
	var helper: Character = map.get_node("Helper")
	t.eq(helper.kid.id, "jack", "sibling helps")
	t.check(helper.mirrored, "mirrored")
	t.check(helper.global_position.x > 1400 and helper.global_position.y > 800, "bottom right")
	_done(t, map)


func test_helper_says_pick_a_row(t) -> void:
	var voice: Node = t.tree.root.get_node("Voice")
	voice.enabled = false
	voice.last_line = ""
	var map := await _make(t)
	t.eq(voice.last_line, "pick-a-row", "helper explains the card")
	map.free()


func test_tap_locked_row_repeats_the_hint(t) -> void:
	var voice: Node = t.tree.root.get_node("Voice")
	voice.enabled = false
	var map := await _make(t, "becca", [0])
	voice.last_line = ""
	await _tap(t, map.row_point(3))
	t.eq(voice.last_line, "pick-a-row", "says it again")
	t.eq(map.get_node("Helper").pose, "point", "and points")
	voice.enabled = true
	_done(t, map)


func test_idle_map_repeats_the_hint(t) -> void:
	var voice: Node = t.tree.root.get_node("Voice")
	voice.enabled = false
	var map := await _make(t, "becca")
	voice.last_line = ""
	await t.tree.create_timer(load("res://data/becca.tres").hint_delay + 0.5).timeout
	t.eq(voice.last_line, "pick-a-row", "says it again")
	t.eq(map.get_node("Helper").pose, "point", "and points")
	voice.enabled = true
	_done(t, map)


func test_all_done_map_cheers(t) -> void:
	var voice: Node = t.tree.root.get_node("Voice")
	voice.enabled = false
	voice.last_line = ""
	var map := await _make(t, "becca", [0, 1, 2, 3])
	t.eq(voice.last_line, "all-packed", "everything packed")
	voice.enabled = true
	_done(t, map)


func test_car_button_only_when_card_done(t) -> void:
	var map := await _make(t, "jack", [0, 1, 2])
	t.check(not map.get_node("CarButton").visible, "hidden while rows are left")
	_done(t, map)
	var window: Window = t.tree.root
	var old_size := window.size
	for size in [Vector2i(1920, 1080), Vector2i(1920, 1200)]:
		window.size = size
		map = await _make(t, "jack", [0, 1, 2, 3])
		var car: TextureButton = map.get_node("CarButton")
		t.check(car.visible, "shown when the card is packed")
		t.check(car.size.y >= 220.0, "big enough to tap")
		var view_size := map.get_viewport().get_visible_rect().size
		var view := Rect2(Vector2(960, 540) - view_size / 2, view_size)
		var rect := Rect2(car.global_position, car.size)
		t.check(view.encloses(rect), "on screen at %s: %s in %s" % [size, rect, view])
		var card: Node2D = map.get_node("Card")
		t.check(rect.end.x <= card.global_position.x, "left of the card")
		_done(t, map)
	window.size = old_size


func test_tap_car_button_goes_to_trunk(t) -> void:
	var map := await _make(t, "becca", [0, 1, 2, 3])
	await _tap(t, map.car_button_point())
	t.eq(t.tree.root.get_node("Game").last_scene_request, "res://scenes/trunk.tscn", "to the trunk (no car clip yet)")
	_done(t, map)
