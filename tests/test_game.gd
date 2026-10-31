extends RefCounted

var _requests: Array[String] = []


func _setup(t) -> Node:
	var game: Node = t.tree.root.get_node("Game")
	game.navigate = false
	game.last_scene_request = ""
	_requests.clear()
	if not game.scene_requested.is_connected(_on_request):
		game.scene_requested.connect(_on_request)
	return game


func _on_request(path: String) -> void:
	_requests.append(path)


func _click(t, screen: Vector2) -> void:
	for pressed in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = pressed
		e.position = screen
		e.global_position = screen
		Input.parse_input_event(e)
		Input.flush_buffered_events()
		await t.tree.process_frame


func test_profiles_differ_only_in_data(t) -> void:
	var becca: KidProfile = load("res://data/becca.tres")
	var jack: KidProfile = load("res://data/jack.tres")
	t.eq(becca.choices, 2, "becca choices")
	t.eq(becca.hint_delay, 6.0, "becca hint")
	t.eq(jack.choices, 4, "jack choices")
	t.eq(jack.hint_delay, 8.0, "jack hint")
	t.eq(becca.min_color_gap, 3, "becca color gap")
	t.eq(jack.min_color_gap, 1, "jack color gap")
	t.eq(becca.colors("shirt").size(), KidProfile.COLOR_STEPS, "8 colors")


func _pick(kid: KidProfile, seed_value: int) -> Array[Texture2D]:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return kid.pick_colors("shirt", rng)


func test_becca_colors_far_apart(t) -> void:
	var becca: KidProfile = load("res://data/becca.tres")
	var all := becca.colors("shirt")
	for s in 50:
		var pick := _pick(becca, s)
		t.eq(pick.size(), 2, "becca pick size")
		if pick.size() != 2:
			continue
		var d: int = absi(all.find(pick[0]) - all.find(pick[1]))
		d = mini(d, KidProfile.COLOR_STEPS - d)
		t.check(all.has(pick[0]) and d >= 3, "seed %d gap %d" % [s, d])


func test_jack_colors_distinct(t) -> void:
	var jack: KidProfile = load("res://data/jack.tres")
	for s in 50:
		var seen := {}
		for tex in _pick(jack, s):
			seen[tex] = true
		t.eq(seen.size(), 4, "seed %d distinct" % s)


func test_target_color_varies(t) -> void:
	var jack: KidProfile = load("res://data/jack.tres")
	var targets := {}
	for s in 50:
		targets[jack.colors("shirt").find(_pick(jack, s)[0])] = true
	t.check(targets.size() >= 4, "target varies: %d" % targets.size())


func test_profile_textures_load(t) -> void:
	for id in ["jack", "becca"]:
		var kid: KidProfile = load("res://data/%s.tres" % id)
		t.check(kid.character("cheer") != null, id + " cheer")
		t.check(kid.prop("suitcase-closed") != null, id + " suitcase")
		t.check(kid.room() != null, id + " room")
		t.check(kid.card() != null, id + " card")


func _temp_progress(t) -> Node:
	var progress: Node = t.tree.root.get_node("Progress")
	progress.path = "user://test_progress_game.json"
	progress.reset()
	return progress


func _restore_progress(t) -> void:
	var progress: Node = t.tree.root.get_node("Progress")
	progress.reset()
	progress.path = "user://progress.json"


func test_pick_goes_to_intro_first_time(t) -> void:
	var game := _setup(t)
	_temp_progress(t)
	game.pick("becca")
	t.eq(game.kid.id, "becca", "kid")
	t.eq(game.sibling().id, "jack", "sibling")
	t.eq(game.last_scene_request, game.INTRO, "requested intro")
	_restore_progress(t)


func test_pick_goes_to_map_after_intro(t) -> void:
	var game := _setup(t)
	var progress := _temp_progress(t)
	progress.mark_intro_seen("becca")
	game.pick("becca")
	t.eq(game.last_scene_request, game.MAP, "requested map")
	game.pick("jack")
	t.eq(game.last_scene_request, game.INTRO, "jack still new")
	_restore_progress(t)


func test_play_level_sets_level_and_goes_to_room(t) -> void:
	var game := _setup(t)
	var progress := _temp_progress(t)
	game.kid = load("res://data/becca.tres")
	progress.mark_done("becca", 2)
	game.play_level(2)
	t.eq(game.level, 2, "level")
	t.eq(game.last_scene_request, game.ROOM, "a finished row replays without its video")
	game.level = 0
	_restore_progress(t)


func test_new_row_plays_its_intro_first(t) -> void:
	var game := _setup(t)
	_temp_progress(t)
	for kid_id in ["becca", "jack"]:
		game.kid = load("res://data/%s.tres" % kid_id)
		for n in [1, 2, 3]:
			game.play_level(n)
			t.eq(game.level, n, "level")
			t.eq(game.last_scene_request, game.INTRO, "%s row %d starts with its video" % [kid_id, n + 1])
	game.play_level(0)
	t.eq(game.last_scene_request, game.ROOM, "row 1 has the kid intro instead")
	game.kid = game.kid.duplicate()
	game.kid.id = "nobody"
	game.play_level(1)
	t.eq(game.last_scene_request, game.ROOM, "no video yet, straight to the room")
	game.level = 0
	game.intro_level = -1
	_restore_progress(t)


func test_level_intro_goes_on_to_the_room(t) -> void:
	var progress := _temp_progress(t)
	var game := _setup(t)
	game.kid = load("res://data/becca.tres")
	game.play_level(1)
	var intro: Node = load("res://scenes/intro.tscn").instantiate()
	t.tree.root.add_child(intro)
	await t.tree.process_frame
	await t.tree.process_frame
	var player: VideoStreamPlayer = intro.get_node("Player")
	t.check(player.is_playing(), "video playing")
	t.eq(player.stream.resource_path, "res://assets/video/becca-level2.ogv", "the row 2 video")
	await _click(t, t.tree.root.get_visible_rect().get_center())
	t.eq(_requests.back(), game.ROOM, "a tap goes on to the room")
	t.eq(game.level, 1, "still row 2")
	t.check(not progress.intro_seen("becca"), "the kid intro isn't marked seen")
	t.eq(game.intro_level, -1, "the next intro is the kid's own again")
	intro.queue_free()
	game.level = 0
	_restore_progress(t)


func _intro(t, kid_id: String, without_video := false) -> Node:
	var game := _setup(t)
	game.kid = load("res://data/%s.tres" % kid_id).duplicate()
	if without_video:
		game.kid.intro_video = ""
	var intro: Node = load("res://scenes/intro.tscn").instantiate()
	t.tree.root.add_child(intro)
	await t.tree.process_frame
	await t.tree.process_frame
	return intro


func test_intro_without_video_goes_to_map_and_is_remembered(t) -> void:
	var progress := _temp_progress(t)
	var intro := await _intro(t, "jack", true)
	t.eq(_requests, [t.tree.root.get_node("Game").MAP] as Array[String], "straight to map")
	t.check(progress.intro_seen("jack"), "remembered")
	t.check(not progress.intro_seen("becca"), "only jack")
	intro.queue_free()
	_restore_progress(t)


func test_intro_tap_skips_to_map(t) -> void:
	var progress := _temp_progress(t)
	var intro := await _intro(t, "becca")
	t.check(intro.get_node("Player").is_playing(), "video playing")
	await _click(t, t.tree.root.get_visible_rect().get_center())
	t.eq(_requests, [t.tree.root.get_node("Game").MAP] as Array[String], "tap skips once")
	t.check(progress.intro_seen("becca"), "remembered")
	intro.queue_free()
	_restore_progress(t)


func test_intro_always_reaches_map(t) -> void:
	_temp_progress(t)
	var intro := await _intro(t, "becca")
	intro.get_node("Player").finished.emit()
	intro.get_node("Player").finished.emit()
	await _click(t, t.tree.root.get_visible_rect().get_center())
	t.eq(_requests, [t.tree.root.get_node("Game").MAP] as Array[String], "finished reaches map exactly once")
	intro.queue_free()
	_restore_progress(t)


func test_car_intro_is_shared_unless_a_kid_has_their_own(t) -> void:
	var jack: KidProfile = load("res://data/jack.tres")
	t.eq(jack.car_intro(), "res://assets/video/car-intro.ogv", "both kids share the car clip")


func test_play_car_plays_the_car_clip_first_time(t) -> void:
	var game := _setup(t)
	var progress := _temp_progress(t)
	game.kid = load("res://data/jack.tres")
	game.play_car()
	t.eq(game.last_scene_request, game.INTRO, "the car clip first")
	t.eq(game.intro_level, game.CAR, "queued as the car clip")
	game.intro_level = -1
	progress.mark_car_done("jack")
	game.play_car()
	t.eq(game.last_scene_request, game.TRUNK, "once the car's loaded, straight to the trunk")
	t.eq(game.intro_level, -1, "no intro queued")
	_restore_progress(t)


func test_intro_for_car_goes_on_to_the_trunk(t) -> void:
	var game := _setup(t)
	var progress := _temp_progress(t)
	game.intro_level = game.CAR
	var intro := await _intro(t, "becca")
	var player: VideoStreamPlayer = intro.get_node("Player")
	t.eq(player.stream.resource_path if player.stream else "", "res://assets/video/car-intro.ogv", "the car clip")
	await _click(t, t.tree.root.get_visible_rect().get_center())
	t.eq(_requests.back() if _requests.size() else "", game.TRUNK, "a tap goes on to the trunk")
	t.eq(game.intro_level, -1, "reset")
	t.check(not progress.intro_seen("becca"), "the kid intro isn't marked seen")
	intro.queue_free()
	_restore_progress(t)


func test_airport_settings_per_kid(t) -> void:
	var jack: KidProfile = load("res://data/jack.tres")
	var becca: KidProfile = load("res://data/becca.tres")
	t.eq(jack.airport_bags, PackedStringArray(["jack-suitcase", "becca-suitcase", "mommy-yellow"]), "jack tags three")
	t.eq(becca.airport_bags, PackedStringArray(["becca-suitcase", "jack-suitcase"]), "becca tags two")
	t.eq(becca.airport_auto_bags, PackedStringArray(["mommy-yellow"]), "the duffel goes by itself for becca")
	t.eq(jack.security_items, PackedStringArray(["jack-backpack", "tablet", "buddy", "mommy-purse"]), "jack's four things")
	t.eq(becca.security_items, PackedStringArray(["becca-backpack", "tablet", "buddy"]), "becca's three things")
	t.check(jack.tablet_own_tray and not becca.tablet_own_tray, "only jack's tablet needs its own tray")
	t.eq([jack.maze_size, jack.maze_gates, jack.maze_hint_delay, jack.maze_footprints], [Vector2i(10, 5), 3, 10.0, false], "jack's maze")
	t.eq([becca.maze_size, becca.maze_gates, becca.maze_hint_delay, becca.maze_footprints, becca.maze_max_turns], [Vector2i(6, 4), 1, 6.0, true, 4], "becca's maze")
	t.eq(jack.airport_intro(), "res://assets/video/jack-airport.ogv", "jack's airport clip")


func test_play_airport_without_a_clip_goes_to_checkin(t) -> void:
	var game := _setup(t)
	_temp_progress(t)
	game.kid = load("res://data/jack.tres")
	game.play_airport()
	t.eq(game.last_scene_request, game.CHECKIN, "no airport clip yet, straight to check-in")
	t.eq(game.intro_level, -1, "no intro queued")
	_restore_progress(t)


func test_airport_intro_goes_on_to_checkin(t) -> void:
	var game := _setup(t)
	_temp_progress(t)
	game.intro_level = game.AIRPORT
	var intro := await _intro(t, "becca")
	t.eq(_requests.back() if _requests.size() else "", game.CHECKIN, "on to check-in")
	t.eq(game.intro_level, -1, "reset")
	intro.queue_free()
	_restore_progress(t)


func test_airport_segments_follow_each_other(t) -> void:
	var game := _setup(t)
	_temp_progress(t)
	game.kid = load("res://data/becca.tres")
	for pair in [[game.CHECKIN, game.SECURITY], [game.SECURITY, game.MAZE]]:
		var scene: Node = load(pair[0]).instantiate()
		t.tree.root.add_child(scene)
		await t.tree.process_frame
		scene.done()
		t.eq(game.last_scene_request, pair[1], "%s goes on" % pair[0])
		scene.free()
	_restore_progress(t)
