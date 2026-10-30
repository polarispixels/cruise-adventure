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
	t.eq(label.text, "v" + ProjectSettings.get_setting("application/config/version"), "stamp")
	t.check(label.visible, "shown")
	title.free()
