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


func test_pick_goes_to_intro(t) -> void:
	var game := _setup(t)
	game.pick("becca")
	t.eq(game.kid.id, "becca", "kid")
	t.eq(game.sibling().id, "jack", "sibling")
	t.eq(game.last_scene_request, game.INTRO, "requested intro")


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


func test_intro_without_video_goes_to_room(t) -> void:
	var intro := await _intro(t, "jack", true)
	t.eq(_requests, [t.tree.root.get_node("Game").ROOM] as Array[String], "straight to room")
	intro.queue_free()


func test_intro_tap_skips_to_room(t) -> void:
	var intro := await _intro(t, "becca")
	t.check(intro.get_node("Player").is_playing(), "video playing")
	await _click(t, t.tree.root.get_visible_rect().get_center())
	t.eq(_requests, [t.tree.root.get_node("Game").ROOM] as Array[String], "tap skips once")
	intro.queue_free()


func test_intro_always_reaches_room(t) -> void:
	var intro := await _intro(t, "becca")
	intro.get_node("Player").finished.emit()
	intro.get_node("Player").finished.emit()
	await _click(t, t.tree.root.get_visible_rect().get_center())
	t.eq(_requests, [t.tree.root.get_node("Game").ROOM] as Array[String], "finished reaches room exactly once")
	intro.queue_free()
