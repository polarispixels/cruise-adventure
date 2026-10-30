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
	t.eq(becca.distractors("shirt").size(), 1, "becca distractors")
	t.eq(jack.distractors("shirt").size(), 3, "jack distractors")


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


