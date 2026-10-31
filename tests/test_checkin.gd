# Goodbye suitcases: tag each big bag, then put it on the belt.
extends RefCounted

var _to_screen := Transform2D.IDENTITY


func _make(t, kid_id := "jack") -> Node2D:
	var progress: Node = t.tree.root.get_node("Progress")
	progress.path = "user://test_checkin_progress.json"
	progress.reset()
	t.tree.root.get_node("Voice").enabled = false
	t.tree.root.get_node("Voice").last_line = ""
	t.tree.root.size = Vector2i(1920, 1080)
	var game: Node = t.tree.root.get_node("Game")
	game.navigate = false
	game.last_scene_request = ""
	game.kid = load("res://data/%s.tres" % kid_id)
	var scene: Node2D = load("res://scenes/checkin.tscn").instantiate()
	t.tree.root.add_child(scene)
	await t.tree.process_frame
	await t.tree.process_frame
	_to_screen = t.tree.root.get_final_transform() * scene.get_canvas_transform()
	return scene


func _done(t, scene: Node) -> void:
	scene.free()
	var progress: Node = t.tree.root.get_node("Progress")
	progress.reset()
	progress.path = "user://progress.json"


func _send(t, event: InputEvent) -> void:
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await t.tree.process_frame


func _touch(t, pressed: bool, world: Vector2) -> void:
	var e := InputEventScreenTouch.new()
	e.pressed = pressed
	e.position = _to_screen * world
	await _send(t, e)


func _drag(t, from: Vector2, to: Vector2) -> void:
	await _touch(t, true, from)
	for i in range(1, 6):
		var e := InputEventScreenDrag.new()
		e.position = _to_screen * from.lerp(to, i / 5.0)
		e.relative = Vector2(1, 1)
		await _send(t, e)
	await _touch(t, false, to)
	await t.tree.create_timer(0.5).timeout


func _voice(t) -> String:
	return t.tree.root.get_node("Voice").last_line


func test_says_tag_bags_at_start(t) -> void:
	var scene := await _make(t, "jack")
	t.eq(_voice(t), "tag-bags", "put the right tag on each bag")
	t.eq(scene.bag_ids(), ["jack-suitcase", "becca-suitcase", "mommy-yellow"] as Array[String], "jack-jack's three bags")
	t.eq(scene.tag_colors().size(), 3, "three tags")
	_done(t, scene)


func test_matching_tag_sticks(t) -> void:
	var scene := await _make(t, "jack")
	await _drag(t, scene.tag_point("blue"), scene.bag_point("jack-suitcase"))
	t.check(scene.is_tagged("jack-suitcase"), "tagged")
	t.eq(_voice(t), "on-the-belt", "put it on the belt")
	_done(t, scene)


func test_wrong_tag_slides_back(t) -> void:
	var scene := await _make(t, "jack")
	var home: Vector2 = scene.tag_point("pink")
	await _drag(t, home, scene.bag_point("jack-suitcase"))
	await t.tree.create_timer(0.4).timeout  # the wiggle, then the glide home
	t.check(not scene.is_tagged("jack-suitcase"), "not tagged")
	t.check(scene.tag_point("pink").distance_to(home) < 2.0, "the tag went back")
	_done(t, scene)


func test_untagged_bag_needs_a_tag(t) -> void:
	var scene := await _make(t, "jack")
	var home: Vector2 = scene.bag_point("becca-suitcase")
	await _drag(t, home, scene.scale_point())
	t.eq(_voice(t), "needs-tag", "it needs a tag")
	t.check(scene.bag_point("becca-suitcase").distance_to(home) < 2.0, "back on the floor")
	_done(t, scene)


func test_tagged_bag_rides_away(t) -> void:
	var scene := await _make(t, "jack")
	await _drag(t, scene.tag_point("pink"), scene.bag_point("becca-suitcase"))
	await _drag(t, scene.bag_point("becca-suitcase"), scene.scale_point())
	await t.tree.create_timer(scene.RIDE_TIME + 0.8).timeout
	t.check(scene.sent().has("becca-suitcase"), "through the flaps")
	t.check(not scene.get_node("Stage/Bags/becca-suitcase").visible, "gone")
	_done(t, scene)


func test_becca_yellow_goes_by_itself(t) -> void:
	var scene := await _make(t, "becca")
	t.eq(scene.bag_ids(), ["becca-suitcase", "jack-suitcase", "mommy-yellow"] as Array[String], "her two, plus the duffel")
	t.eq(scene.tag_colors().size(), 2, "two tags for becca")
	await t.tree.create_timer(scene.RIDE_TIME + 1.5).timeout
	t.check(scene.sent().has("mommy-yellow"), "the duffel rode away by itself")
	_done(t, scene)


func test_all_gone_goes_to_security(t) -> void:
	var scene := await _make(t, "becca")
	for pair in [["pink", "becca-suitcase"], ["blue", "jack-suitcase"]]:
		await _drag(t, scene.tag_point(pair[0]), scene.bag_point(pair[1]))
		await _drag(t, scene.bag_point(pair[1]), scene.scale_point())
	var game: Node = t.tree.root.get_node("Game")
	var end := Time.get_ticks_msec() + 12000
	while game.last_scene_request == "" and Time.get_ticks_msec() < end:
		await t.tree.process_frame
	t.eq(game.last_scene_request, "res://scenes/security.tscn", "on to security")
	t.check(t.tree.root.get_node("Voice").last_line in ["bye-suitcases"], "bye-bye, suitcases")
	_done(t, scene)
