extends RefCounted

var _to_screen := Transform2D.IDENTITY
var _requests: Array[String] = []


func _make(t) -> Node2D:
	var game: Node = t.tree.root.get_node("Game")
	game.navigate = false
	game.last_scene_request = ""
	game.kid = null
	_requests.clear()
	if not game.scene_requested.is_connected(_on_request):
		game.scene_requested.connect(_on_request)
	var title: Node2D = load("res://scenes/title.tscn").instantiate()
	t.tree.root.add_child(title)
	await t.tree.process_frame
	await t.tree.process_frame
	_to_screen = t.tree.root.get_final_transform() * title.get_canvas_transform()
	return title


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


func _hold(t, world: Vector2, seconds: float) -> void:
	await _touch(t, true, world)
	await t.tree.create_timer(seconds).timeout
	await _touch(t, false, world)


func _pick(t, kid_name: String, kid_id: String) -> void:
	var title := await _make(t)
	var kid: Character = title.get_node("Stage/" + kid_name)
	await _tap(t, kid.hit_rect().get_center())
	await t.tree.create_timer(0.8).timeout
	t.eq(t.tree.root.get_node("Game").kid.id if t.tree.root.get_node("Game").kid else "", kid_id, "picked")
	t.eq(_requests, ["res://scenes/intro.tscn"] as Array[String], "to the intro")
	title.free()


func test_tap_becca_picks_becca(t) -> void:
	await _pick(t, "Becca", "becca")


func test_tap_jack_picks_jack(t) -> void:
	await _pick(t, "Jack", "jack")


func test_tap_empty_space_replays_voice(t) -> void:
	var title := await _make(t)
	var voice: AudioStreamPlayer = title.get_node("Voice")
	voice.stop()
	await _tap(t, Vector2(960, 100))
	t.check(voice.playing, "voice replays")
	await t.tree.create_timer(0.8).timeout
	t.eq(_requests.size(), 0, "no pick")
	title.free()


func test_double_tap_picks_once(t) -> void:
	var title := await _make(t)
	var jack: Character = title.get_node("Stage/Jack")
	await _tap(t, jack.hit_rect().get_center())
	await _tap(t, jack.hit_rect().get_center())
	await t.tree.create_timer(0.8).timeout
	t.eq(_requests.size(), 1, "picked once")
	title.free()


func test_kids_take_turns_waving(t) -> void:
	var title := await _make(t)
	var seen := {}
	var end: float = Time.get_ticks_msec() + (title.WAVE_EVERY * 2 + 0.6) * 1000
	while Time.get_ticks_msec() < end:
		for name in ["Jack", "Becca"]:
			if title.get_node("Stage/" + name).pose.begins_with("wave"):
				seen[name] = true
		await t.tree.process_frame
	t.check(seen.has("Jack") and seen.has("Becca"), "both waved: " + str(seen.keys()))
	title.free()


func test_version_stamp(t) -> void:
	var title := await _make(t)
	var label: Label = title.get_node("VersionLabel")
	t.eq(ProjectSettings.get_setting("application/config/version"), "0.5.0", "the version being built")
	t.eq(ProjectSettings.get_setting("application/config/build", "x"), "", "no build label in the repo (CI stamps it)")
	t.eq(label.text, "v0.5.0", "a release shows just the version")
	t.check(label.visible, "shown")
	title.free()


func test_version_stamp_shows_the_build(t) -> void:
	ProjectSettings.set_setting("application/config/build", "playtest 10")
	var title := await _make(t)
	t.eq(title.get_node("VersionLabel").text, "v0.5.0 playtest 10", "which build is installed")
	title.free()
	ProjectSettings.set_setting("application/config/build", "")


func _label_point(title: Node2D) -> Vector2:
	var label: Label = title.get_node("VersionLabel")
	return label.global_position + label.size / 2


func _temp(t) -> Node:
	var progress: Node = t.tree.root.get_node("Progress")
	progress.path = "user://test_progress_title.json"
	progress.reset()
	return progress


func _restore(t) -> void:
	var progress: Node = t.tree.root.get_node("Progress")
	progress.reset()
	progress.path = "user://progress.json"


func test_long_press_on_version_resets_progress(t) -> void:
	var progress := _temp(t)
	progress.mark_done("jack", 0)
	progress.mark_intro_seen("jack")
	var title := await _make(t)
	await _hold(t, _label_point(title), 5.3)
	t.eq(progress.levels_done("jack").size(), 0, "progress cleared")
	t.check(not progress.intro_seen("jack"), "intro cleared")
	t.check("reset" in title.get_node("VersionLabel").text, "the stamp says so, for the grown-up")
	title.free()
	_restore(t)


func test_short_press_on_version_keeps_progress_and_replays_voice(t) -> void:
	var progress := _temp(t)
	progress.mark_done("jack", 0)
	var title := await _make(t)
	var voice: AudioStreamPlayer = title.get_node("Voice")
	voice.stop()
	await _hold(t, _label_point(title), 0.3)
	t.eq(progress.levels_done("jack").size(), 1, "progress kept")
	t.check(voice.playing, "voice replays")
	title.free()
	_restore(t)


func test_long_press_elsewhere_does_not_reset(t) -> void:
	var progress := _temp(t)
	progress.mark_done("jack", 0)
	var title := await _make(t)
	await _hold(t, Vector2(960, 100), 2.3)
	t.eq(progress.levels_done("jack").size(), 1, "progress kept")
	title.free()
	_restore(t)


func test_two_second_rest_keeps_progress(t) -> void:
	var progress := _temp(t)
	progress.mark_done("jack", 0)
	var title := await _make(t)
	await _hold(t, _label_point(title), 2.3)
	t.eq(progress.levels_done("jack").size(), 1, "a resting thumb doesn't wipe progress")
	title.free()
	_restore(t)


func test_hold_then_slide_off_keeps_progress(t) -> void:
	var progress := _temp(t)
	progress.mark_done("jack", 0)
	var title := await _make(t)
	await _touch(t, true, _label_point(title))
	await t.tree.create_timer(5.3).timeout
	await _touch(t, false, Vector2(960, 540))
	t.eq(progress.levels_done("jack").size(), 1, "releasing away from the stamp cancels")
	title.free()
	_restore(t)
