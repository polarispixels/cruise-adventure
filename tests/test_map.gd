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
	game.stop_chapter()
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
	var game: Node = t.tree.root.get_node("Game")
	game.stop_chapter()
	game.use_chapters([])
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
	t.eq(t.tree.root.get_node("Game").last_scene_request, "res://scenes/intro.tscn", "the car clip, then the trunk")
	_done(t, map)


func test_airport_button_only_after_the_car(t) -> void:
	var map := await _make(t, "jack", [0, 1, 2, 3])
	t.check(not map.get_node("AirportButton").visible, "hidden until the car is loaded")
	_done(t, map)
	var progress: Node = t.tree.root.get_node("Progress")
	progress.path = TMP
	progress.reset()
	for row in 4:
		progress.mark_done("jack", row)
	progress.mark_car_done("jack")
	var game: Node = t.tree.root.get_node("Game")
	game.navigate = false
	game.kid = load("res://data/jack.tres")
	map = load("res://scenes/map.tscn").instantiate()
	t.tree.root.add_child(map)
	await t.tree.process_frame
	await t.tree.process_frame
	_to_screen = t.tree.root.get_final_transform() * map.get_canvas_transform()
	var button: TextureButton = map.get_node("AirportButton")
	t.check(button.visible, "shown once the car is done")
	var car: TextureButton = map.get_node("CarButton")
	t.check(not Rect2(button.global_position, button.size).intersects(Rect2(car.global_position, car.size)), "clear of the car button")
	await _tap(t, button.global_position + button.size / 2)
	t.eq(game.last_scene_request, "res://scenes/checkin.tscn", "to the airport")
	_done(t, map)


## Every chapter as built: the real registry, with a placeholder segment in each empty one.
func _all_built(t) -> void:
	var game: Node = t.tree.root.get_node("Game")
	game.use_chapters([])
	var list: Array = game.chapters().duplicate(true)
	for c: Dictionary in list:
		if (c["segments"] as Array).is_empty() and not c.get("dropped", false):
			c["segments"] = [{"kind": "clip", "name": "placeholder-" + c["id"]}]
	game.use_chapters(list)


func _map_with(t, kid_id: String, chapters_done: Array) -> Node2D:
	var progress: Node = t.tree.root.get_node("Progress")
	progress.path = TMP
	progress.reset()
	for row in 4:
		progress.mark_done(kid_id, row)
	for id: String in chapters_done:
		progress.mark_chapter_done(kid_id, id)
	var game: Node = t.tree.root.get_node("Game")
	game.navigate = false
	game.last_scene_request = ""
	game.kid = load("res://data/%s.tres" % kid_id)
	var map: Node2D = load("res://scenes/map.tscn").instantiate()
	t.tree.root.add_child(map)
	await t.tree.process_frame
	await t.tree.process_frame
	_to_screen = t.tree.root.get_final_transform() * map.get_canvas_transform()
	return map


const ALL_STOPS := ["car", "airport", "flight", "florida", "aboard", "island1", "island2", "seaday", "beach"]


func test_journey_has_a_stop_per_chapter_7_to_14(t) -> void:
	_all_built(t)
	var map := await _map_with(t, "jack", [])
	t.eq(map.stop_ids, ALL_STOPS as Array[String], "every stop from the car to the beach, in order")
	t.eq(map.stop_button("car"), map.get_node("CarButton"), "the SUV is the car stop")
	t.eq(map.stop_button("airport"), map.get_node("AirportButton"), "the boarding pass is the airport stop")
	t.eq(map.next_stop(), "car", "the car is next")
	_done(t, map)


func test_unbuilt_chapters_have_no_stop(t) -> void:
	# Whatever chapters are built by now, an empty one gets no stop: empty all but car and airport.
	var game: Node = t.tree.root.get_node("Game")
	game.use_chapters([])
	var list: Array = game.chapters().duplicate(true)
	for c: Dictionary in list:
		if not ["car", "airport"].has(c["id"]):
			c["segments"] = []
	game.use_chapters(list)
	var map := await _map_with(t, "jack", ["car", "airport"])
	t.eq(map.stop_ids, ["car", "airport"] as Array[String], "only chapters with segments get a stop")
	_done(t, map)
	game.use_chapters([])


func test_stops_fit_the_tablet_and_never_overlap(t) -> void:
	_all_built(t)
	var window: Window = t.tree.root
	var old_size := window.size
	for size in [Vector2i(1920, 1200), Vector2i(1920, 1080)]:
		window.size = size
		var map := await _map_with(t, "becca", ALL_STOPS)
		var view_size := map.get_viewport().get_visible_rect().size
		var view := Rect2(Vector2(960, 540) - view_size / 2, view_size)
		var card: Node2D = map.get_node("Card")
		var card_rect := Rect2(card.global_position, Vector2(1200, 1600) * card.scale)
		var helper: Character = map.get_node("Helper")
		var rects: Array[Rect2] = []
		for id in map.stop_ids:
			var b: TextureButton = map.stop_button(id)
			var r := Rect2(b.global_position, b.size)
			t.check(b.visible, "%s shows" % id)
			t.check(view.encloses(r), "%s on screen at %s: %s in %s" % [id, size, r, view])
			t.check(not r.intersects(card_rect), "%s clear of the card" % id)
			t.check(not r.has_point(helper.global_position), "%s clear of the helper's feet" % id)
			t.check(b.size.y >= 120.0, "%s big enough to tap" % id)
			for other in rects:
				t.check(not r.intersects(other), "%s clear of the other stops" % id)
			rects.append(r)
		_done(t, map)
	window.size = old_size


func test_next_stop_wiggles_done_stops_have_a_check(t) -> void:
	_all_built(t)
	var map := await _map_with(t, "becca", ["car", "airport", "flight"])
	t.eq(map.next_stop(), "florida", "florida is next")
	for id in ["car", "airport", "flight"]:
		t.check(map.stop_button(id).get_node_or_null("Check") != null, "%s has a check" % id)
	t.check(map.stop_button("florida").get_node_or_null("Check") == null, "florida has none")
	t.check(map.stop_button("florida").visible, "florida shows")
	t.check(not map.stop_button("aboard").visible, "later stops wait")
	await t.tree.create_timer(0.3).timeout
	t.check(absf(map.stop_button("florida").rotation) > 0.01, "florida wiggles")
	t.eq(map.stop_button("flight").rotation, 0.0, "a done stop stays still")
	_done(t, map)


func test_tap_next_stop_plays_it(t) -> void:
	_all_built(t)
	var map := await _map_with(t, "jack", ["car", "airport"])
	await _tap(t, map.stop_point("flight"))
	var game: Node = t.tree.root.get_node("Game")
	t.eq(game.last_scene_request, "res://scenes/engines/match.tscn", "the flight starts at the seat")
	t.eq(game.segment.get("chapter"), "flight", "in the flight chapter")
	_done(t, map)


func test_tap_done_stop_replays_it(t) -> void:
	_all_built(t)
	var map := await _map_with(t, "becca", ["car", "airport", "flight", "florida"])
	await _tap(t, map.stop_point("car"))
	var game: Node = t.tree.root.get_node("Game")
	t.eq(game.last_scene_request, "res://scenes/trunk.tscn", "a done chapter replays, without its once-only clip")
	_done(t, map)


func test_light_up_route_lights_every_stop(t) -> void:
	_all_built(t)
	var map := await _map_with(t, "jack", ["car"])
	t.check(not map.route_lit(), "not lit yet")
	map.light_up_route()
	await t.tree.create_timer(0.1).timeout
	t.check(map.route_lit(), "the route is lit")
	for id in map.stop_ids:
		t.check(map.stop_button(id).visible, "%s shows" % id)
	t.eq((map.get_node("Route") as Line2D).points.size(), ALL_STOPS.size(), "the route runs through every stop")
	_done(t, map)


func test_finale_segment_lights_up_and_goes_on(t) -> void:
	_all_built(t)
	var game: Node = t.tree.root.get_node("Game")
	var list: Array = game.chapters()
	for c: Dictionary in list:
		if c["id"] == "beach":
			c["segments"] = [{"kind": "scene", "scene": "res://scenes/map.tscn", "finale": true},
				{"kind": "clip", "name": "placeholder-celebration"}]
	var progress: Node = t.tree.root.get_node("Progress")
	progress.path = TMP
	progress.reset()
	game.navigate = false
	game.kid = load("res://data/becca.tres")
	game.play_chapter("beach")
	t.eq(game.last_scene_request, "res://scenes/map.tscn", "the map is the finale's first segment")
	var map := await _map_with(t, "becca", ALL_STOPS.slice(0, 8))
	t.check(map.route_lit(), "the finale lights the route")
	game.last_scene_request = ""
	await _tap(t, map.stop_point("car"))
	t.eq(game.last_scene_request, "", "taps don't start anything during the finale")
	await t.tree.create_timer(ALL_STOPS.size() * 0.35 + 2.5).timeout
	t.eq(game.last_scene_request, "res://scenes/intro.tscn", "then the celebration")
	_done(t, map)


func test_finale_says_nothing_over_the_light_up(t) -> void:
	_all_built(t)
	var game: Node = t.tree.root.get_node("Game")
	for c: Dictionary in game.chapters():
		if c["id"] == "beach":
			c["segments"] = [{"kind": "scene", "scene": "res://scenes/map.tscn", "finale": true}]
	var voice: Node = t.tree.root.get_node("Voice")
	voice.enabled = false
	var progress: Node = t.tree.root.get_node("Progress")
	progress.path = TMP
	progress.reset()
	game.navigate = false
	game.kid = load("res://data/jack.tres")
	game.play_chapter("beach")
	voice.last_line = ""
	var map := await _map_with(t, "jack", ALL_STOPS.slice(0, 8))
	t.eq(voice.last_line, "", "no all-packed over the finale")
	await t.tree.create_timer(game.kid.hint_delay + 0.5).timeout
	t.eq(voice.last_line, "", "and no idle prompt during it")
	voice.enabled = true
	_done(t, map)


func test_after_the_beach_the_map_offers_replays(t) -> void:
	var voice: Node = t.tree.root.get_node("Voice")
	voice.enabled = false
	_all_built(t)
	var has_replay: bool = voice.has_line("beach-replay")
	voice.last_line = ""
	var map := await _map_with(t, "becca", ALL_STOPS)
	t.eq(voice.last_line, "beach-replay" if has_replay else "all-packed", "the replay line once it exists, else the cheer")
	_done(t, map)
	voice._ids["beach-replay"] = true
	voice.last_line = ""
	_all_built(t)
	map = await _map_with(t, "becca", ALL_STOPS)
	t.eq(voice.last_line, "beach-replay", "after the beach: tap any stop to play it again")
	_done(t, map)
	voice.last_line = ""
	_all_built(t)
	map = await _map_with(t, "becca", ["car"])
	t.eq(voice.last_line, "all-packed", "mid-trip without a next-stop line: the cheer")
	_done(t, map)
	voice._ids.clear()
	voice.enabled = true
