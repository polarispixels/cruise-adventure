extends RefCounted

var _requests: Array[String] = []


func _setup(t) -> Node:
	var game: Node = t.tree.root.get_node("Game")
	game.navigate = false
	game.last_scene_request = ""
	game.stop_chapter()
	game.use_chapters([])
	game.level = 0
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
	var game: Node = t.tree.root.get_node("Game")
	game.stop_chapter()
	game.use_chapters([])
	game.level = 0
	game.stills_dir = "res://assets/stills/"
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
	t.eq(game.segment.get("name"), "becca-intro", "the kid's own clip")
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


func test_registry_lists_every_chapter_in_order(t) -> void:
	var game := _setup(t)
	var numbers: Array = []
	var ids: Array = []
	for c: Dictionary in game.chapters():
		numbers.append(int(c["number"]))
		ids.append(c["id"])
		t.check(c.has("title") and c["segments"] is Array, "%s has a title and segments" % c["id"])
		t.eq(c.get("dropped", false), int(c["number"]) in [4, 5, 6], "%s dropped only if 4-6" % c["id"])
	t.eq(numbers, [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 12, 13, 14], "chapters 1-14, 12 twice")
	for id in ["flight", "florida", "aboard", "island1", "island2", "seaday", "beach"]:
		t.check(ids.has(id), "has " + id)
	for c: Dictionary in game.chapters():
		for seg: Dictionary in c["segments"]:
			if seg["kind"] == "scene":
				t.check(ResourceLoader.exists(seg["scene"]), "scene exists: %s" % seg["scene"])
				if seg.has("data"):
					t.check(FileAccess.file_exists(seg["data"]), "data exists: %s" % seg["data"])
	_restore_progress(t)


func test_merge_segment_lays_the_kid_block_over(t) -> void:
	var game := _setup(t)
	var entry := {"kind": "scene", "scene": "res://x.tscn", "choices": 4, "art": "{kid}-{sibling}",
		"list": ["{kid}"], "becca": {"choices": 3}, "jack": {"extra": true}}
	var becca: Dictionary = game.merge_segment(entry, "becca")
	t.eq(becca, {"kind": "scene", "scene": "res://x.tscn", "choices": 3, "art": "becca-jack", "list": ["becca"]}, "becca")
	var jack: Dictionary = game.merge_segment(entry, "jack")
	t.eq([jack["choices"], jack["extra"], jack["art"]], [4, true, "jack-becca"], "jack")
	t.eq(entry["choices"], 4, "the entry itself is untouched")
	_restore_progress(t)


func test_merge_segment_reads_the_data_file(t) -> void:
	var game := _setup(t)
	var path := "user://test_segment_data.json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string('{"choices": 4, "target": "{kid}-card", "becca": {"choices": 2}}')
	file.close()
	var entry := {"kind": "scene", "scene": "res://x.tscn", "data": path, "choices": 9, "keep": 1}
	var becca: Dictionary = game.merge_segment(entry, "becca")
	t.eq([becca["choices"], becca["target"], becca["keep"]], [2.0, "becca-card", 1], "data file wins, kid block on top")
	t.eq(game.merge_segment(entry, "jack")["choices"], 4.0, "jack")
	DirAccess.remove_absolute(path)
	_restore_progress(t)


func test_play_level_sets_level_and_goes_to_room(t) -> void:
	var game := _setup(t)
	var progress := _temp_progress(t)
	game.kid = load("res://data/becca.tres")
	progress.mark_done("becca", 2)
	game.play_level(2)
	t.eq(game.level, 2, "level")
	t.eq(game.last_scene_request, game.ROOM, "a finished row replays without its video")
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
			t.eq(game.segment.get("name"), "%s-level%d" % [kid_id, n + 1], "the row's clip")
	game.play_level(0)
	t.eq(game.last_scene_request, game.ROOM, "row 1 has the kid intro instead")
	game.kid = game.kid.duplicate()
	game.kid.id = "nobody"
	game.play_level(1)
	t.eq(game.last_scene_request, game.ROOM, "no video yet, straight to the room")
	_restore_progress(t)


func _intro(t) -> Node:
	var intro: Node = load("res://scenes/intro.tscn").instantiate()
	t.tree.root.add_child(intro)
	await t.tree.process_frame
	await t.tree.process_frame
	return intro


func test_level_intro_goes_on_to_the_room(t) -> void:
	var progress := _temp_progress(t)
	var game := _setup(t)
	game.kid = load("res://data/becca.tres")
	game.play_level(1)
	var intro := await _intro(t)
	var player: VideoStreamPlayer = intro.get_node("Player")
	t.check(player.is_playing(), "video playing")
	t.eq(intro.mode, "clip", "the clip")
	t.eq(player.stream.resource_path, "res://assets/video/becca-level2.ogv", "the row 2 video")
	await _click(t, t.tree.root.get_visible_rect().get_center())
	t.eq(_requests.back(), game.ROOM, "a tap goes on to the room")
	t.eq(game.level, 1, "still row 2")
	t.check(not progress.intro_seen("becca"), "the kid intro isn't marked seen")
	intro.queue_free()
	game.segment_done()
	t.eq(game.last_scene_request, game.MAP, "the room's Continue goes back to the card")
	t.check(not game.playing(), "the row is over")
	_restore_progress(t)


func test_intro_without_video_goes_to_map_and_is_remembered(t) -> void:
	var progress := _temp_progress(t)
	var game := _setup(t)
	game.kid = load("res://data/jack.tres").duplicate()
	game.kid.id = "jack"
	game.use_chapters([{"id": "mission", "number": 1, "title": "t",
		"segments": [{"kind": "clip", "name": "nobody-intro", "optional": true}]}])
	game.play_chapter("mission")
	t.eq(_requests, [game.MAP] as Array[String], "straight to map")
	t.check(progress.intro_seen("jack"), "remembered")
	t.check(not progress.intro_seen("becca"), "only jack")
	_restore_progress(t)


func test_intro_tap_skips_to_map(t) -> void:
	var progress := _temp_progress(t)
	var game := _setup(t)
	game.pick("becca")
	_requests.clear()
	var intro := await _intro(t)
	t.check(intro.get_node("Player").is_playing(), "video playing")
	await _click(t, t.tree.root.get_visible_rect().get_center())
	t.eq(_requests, [game.MAP] as Array[String], "tap skips once")
	t.check(progress.intro_seen("becca"), "remembered")
	intro.queue_free()
	_restore_progress(t)


func test_intro_always_reaches_map(t) -> void:
	_temp_progress(t)
	var game := _setup(t)
	game.pick("becca")
	_requests.clear()
	var intro := await _intro(t)
	intro.get_node("Player").finished.emit()
	intro.get_node("Player").finished.emit()
	await _click(t, t.tree.root.get_visible_rect().get_center())
	t.eq(_requests, [game.MAP] as Array[String], "finished reaches map exactly once")
	intro.queue_free()
	_restore_progress(t)


## F2: a missing clip shows its still with a slow zoom; a missing still, a placeholder card.
func _media_chapter(game: Node, media: String) -> void:
	game.use_chapters([{"id": "test-media", "number": 99, "title": "t", "segments": [
		{"kind": "clip", "id": "test-card", "name": media},
		{"kind": "scene", "scene": "res://scenes/trunk.tscn"}]}])


func test_missing_clip_shows_the_still(t) -> void:
	_temp_progress(t)
	var game := _setup(t)
	game.kid = load("res://data/jack.tres")
	_media_chapter(game, "test-still")
	# The test still lives with the tests, out of the build.
	game.stills_dir = "res://tests/fixtures/"
	var still: String = game.still_path("test-still")
	t.check(not ResourceLoader.exists(game.clip_path("test-still")), "no clip")
	if not ResourceLoader.exists(still):
		t.check(false, "fixture still missing: " + still)
		_restore_progress(t)
		return
	game.play_chapter("test-media")
	t.eq(game.last_scene_request, game.INTRO, "the still plays in the intro scene")
	var intro := await _intro(t)
	t.eq(intro.mode, "still", "still mode")
	var rect: TextureRect = intro.get_node("Still")
	t.check(rect.visible and rect.texture != null, "the still shows")
	var before: Vector2 = rect.scale
	await t.tree.create_timer(1.0).timeout
	t.check(rect.scale.x > before.x, "it zooms slowly: %s" % rect.scale)
	t.check(game.last_scene_request == game.INTRO, "still showing after a second")
	await _click(t, t.tree.root.get_visible_rect().get_center())
	t.eq(game.last_scene_request, game.TRUNK, "a tap goes on")
	intro.queue_free()
	_restore_progress(t)


func test_still_ends_by_itself(t) -> void:
	_temp_progress(t)
	var game := _setup(t)
	game.kid = load("res://data/jack.tres")
	game.stills_dir = "res://tests/fixtures/"
	game.use_chapters([{"id": "test-media", "number": 99, "title": "t", "segments": [
		{"kind": "still", "name": "test-still", "seconds": 0.5},
		{"kind": "scene", "scene": "res://scenes/trunk.tscn"}]}])
	game.play_chapter("test-media")
	var intro := await _intro(t)
	t.eq(intro.mode, "still", "a still segment")
	await t.tree.create_timer(0.8).timeout
	t.eq(game.last_scene_request, game.TRUNK, "goes on after its seconds")
	intro.queue_free()
	_restore_progress(t)


func test_missing_clip_and_still_show_a_placeholder_card(t) -> void:
	_temp_progress(t)
	var game := _setup(t)
	game.kid = load("res://data/jack.tres")
	_media_chapter(game, "no-such-clip")
	game.play_chapter("test-media")
	t.eq(game.last_scene_request, game.INTRO, "a missing clip still plays something")
	var intro := await _intro(t)
	t.eq(intro.mode, "card", "the placeholder card")
	t.check(intro.get_node("Card").visible, "card shows")
	t.eq(intro.get_node("Card/Name").text, "test-card", "with the segment's name")
	await t.tree.create_timer(intro.CARD_SECONDS + 0.3).timeout
	t.eq(game.last_scene_request, game.TRUNK, "and the chapter goes on by itself")
	intro.queue_free()
	_restore_progress(t)


func test_clip_plays_when_it_exists(t) -> void:
	_temp_progress(t)
	var game := _setup(t)
	game.kid = load("res://data/jack.tres")
	_media_chapter(game, "car-intro")
	game.play_chapter("test-media")
	var intro := await _intro(t)
	t.eq(intro.mode, "clip", "the clip")
	t.check(intro.get_node("Player").is_playing(), "playing")
	t.check(not intro.get_node("Still").visible and not intro.get_node("Card").visible, "nothing else")
	await _click(t, t.tree.root.get_visible_rect().get_center())
	t.eq(game.last_scene_request, game.TRUNK, "a tap goes on")
	intro.queue_free()
	_restore_progress(t)


func test_play_car_plays_the_car_clip_first_time(t) -> void:
	var game := _setup(t)
	var progress := _temp_progress(t)
	game.kid = load("res://data/jack.tres")
	game.play_chapter("car")
	t.eq(game.last_scene_request, game.INTRO, "the car clip first")
	t.eq(game.segment.get("name"), "car-intro", "the shared car clip")
	progress.mark_car_done("jack")
	game.play_chapter("car")
	t.eq(game.last_scene_request, game.TRUNK, "once the car's loaded, straight to the trunk")
	_restore_progress(t)


func test_intro_for_car_goes_on_to_the_trunk(t) -> void:
	var game := _setup(t)
	var progress := _temp_progress(t)
	game.kid = load("res://data/becca.tres")
	game.play_chapter("car")
	var intro := await _intro(t)
	var player: VideoStreamPlayer = intro.get_node("Player")
	t.eq(player.stream.resource_path if player.stream else "", "res://assets/video/car-intro.ogv", "the car clip")
	await _click(t, t.tree.root.get_visible_rect().get_center())
	t.eq(_requests.back() if _requests.size() else "", game.TRUNK, "a tap goes on to the trunk")
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


func test_play_airport_without_a_clip_goes_to_checkin(t) -> void:
	var game := _setup(t)
	_temp_progress(t)
	game.kid = load("res://data/jack.tres")
	game.play_chapter("airport")
	t.eq(game.last_scene_request, game.CHECKIN, "no airport clip yet, straight to check-in")
	_restore_progress(t)


func test_car_goes_straight_on_to_the_airport(t) -> void:
	var game := _setup(t)
	var progress := _temp_progress(t)
	game.kid = load("res://data/becca.tres")
	game.play_chapter("car", 1)
	t.eq(game.last_scene_request, game.TRUNK, "the trunk")
	game.segment_done()
	t.check(progress.car_done("becca"), "the car is done")
	t.eq(game.last_scene_request, game.CHECKIN, "the airport follows the car")
	t.eq(game.segment.get("chapter"), "airport", "now in the airport")
	_restore_progress(t)


func test_airport_segments_follow_each_other(t) -> void:
	var game := _setup(t)
	var progress := _temp_progress(t)
	game.kid = load("res://data/becca.tres")
	game.play_chapter("airport")
	for pair in [[game.CHECKIN, game.SECURITY], [game.SECURITY, game.MAZE]]:
		t.eq(game.last_scene_request, pair[0], "at %s" % pair[0])
		var scene: Node = load(pair[0]).instantiate()
		t.tree.root.add_child(scene)
		await t.tree.process_frame
		scene.done()
		t.eq(game.last_scene_request, pair[1], "%s goes on" % pair[0])
		scene.free()
	game.segment_done()
	t.eq(game.last_scene_request, game.MAP, "the gate, then the map")
	t.check(progress.airport_done("becca"), "the airport is done")
	t.check(not game.playing(), "the chapter is over")
	_restore_progress(t)


func test_segment_done_without_a_chapter_goes_to_the_map(t) -> void:
	var game := _setup(t)
	game.last_segment_done = false
	var heard := [false]
	var on_done := func(): heard[0] = true
	game.segment_finished.connect(on_done)
	game.segment_done()
	game.segment_finished.disconnect(on_done)
	t.check(game.last_segment_done and heard[0], "flag and signal")
	t.eq(game.last_scene_request, game.MAP, "the map")
	_restore_progress(t)


func test_empty_chapter_returns_to_the_map_unfinished(t) -> void:
	var game := _setup(t)
	var progress := _temp_progress(t)
	game.kid = load("res://data/jack.tres")
	game.play_chapter("flight")
	t.eq(game.last_scene_request, game.MAP, "nothing to play yet")
	t.check(not progress.chapter_done("jack", "flight"), "not marked done")
	_restore_progress(t)
