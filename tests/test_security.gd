# Through security: things into trays, trays through the scanner, the kid
# through the arch, everything back.
extends RefCounted

var _to_screen := Transform2D.IDENTITY
var _said: Array[String] = []


func _make(t, kid_id := "jack") -> Node2D:
	var progress: Node = t.tree.root.get_node("Progress")
	progress.path = "user://test_security_progress.json"
	progress.reset()
	var voice: Node = t.tree.root.get_node("Voice")
	voice.enabled = false
	voice.last_line = ""
	_said.clear()
	if not voice.said.is_connected(_on_said):
		voice.said.connect(_on_said)
	t.tree.root.size = Vector2i(1920, 1080)
	var game: Node = t.tree.root.get_node("Game")
	game.navigate = false
	game.last_scene_request = ""
	game.kid = load("res://data/%s.tres" % kid_id)
	var scene: Node2D = load("res://scenes/security.tscn").instantiate()
	t.tree.root.add_child(scene)
	await t.tree.process_frame
	await t.tree.process_frame
	_to_screen = t.tree.root.get_final_transform() * scene.get_canvas_transform()
	return scene


func _on_said(line: String) -> void:
	_said.append(line)


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


func _tap(t, world: Vector2) -> void:
	await _touch(t, true, world)
	await _touch(t, false, world)
	await t.tree.create_timer(0.1).timeout


func _drag(t, from: Vector2, to: Vector2) -> void:
	await _touch(t, true, from)
	for i in range(1, 6):
		var e := InputEventScreenDrag.new()
		e.position = _to_screen * from.lerp(to, i / 5.0)
		e.relative = Vector2(1, 1)
		await _send(t, e)
	await _touch(t, false, to)
	await t.tree.create_timer(0.4).timeout


func _scan_all(t, scene: Node2D, plan: Dictionary) -> void:
	for id in plan:
		await _drag(t, scene.item_point(id), scene.tray_point(plan[id]))
	var trays := {}
	for id in plan:
		trays[plan[id]] = true
	for tray in trays:
		await _tap(t, scene.tray_point(tray))
		await t.tree.create_timer(scene.SCAN_TIME + 0.6).timeout


func test_says_in_a_tray(t) -> void:
	var scene := await _make(t, "jack")
	t.eq(t.tree.root.get_node("Voice").last_line, "in-a-tray", "put your things in a tray")
	t.eq(scene.item_ids(), ["jack-backpack", "tablet", "buddy", "mommy-purse"] as Array[String], "jack-jack's four things")
	_done(t, scene)


func test_item_goes_in_a_tray(t) -> void:
	var scene := await _make(t, "jack")
	await _drag(t, scene.item_point("jack-backpack"), scene.tray_point(0))
	t.eq(scene.tray_items(0), ["jack-backpack"] as Array[String], "in the first tray")
	_done(t, scene)


func test_tablet_hops_to_its_own_tray(t) -> void:
	var scene := await _make(t, "jack")
	await _drag(t, scene.item_point("jack-backpack"), scene.tray_point(0))
	await _drag(t, scene.item_point("tablet"), scene.tray_point(0))
	t.eq(scene.tray_items(0), ["jack-backpack"] as Array[String], "the backpack stays")
	var alone: Array[String] = ["tablet"]
	t.check(scene.tray_items(1) == alone or scene.tray_items(2) == alone, "the tablet hopped to its own tray")
	t.eq(t.tree.root.get_node("Voice").last_line, "tablet-tray", "the tablet gets its own tray")
	_done(t, scene)
	scene = await _make(t, "jack")
	await _drag(t, scene.item_point("tablet"), scene.tray_point(0))
	await _drag(t, scene.item_point("mommy-purse"), scene.tray_point(0))
	t.eq(scene.tray_items(0), ["tablet"] as Array[String], "the tablet keeps its tray")
	t.check(scene.tray_items(1).has("mommy-purse") or scene.tray_items(2).has("mommy-purse"), "the purse hopped")
	_done(t, scene)


func test_becca_tablet_shares_a_tray(t) -> void:
	var scene := await _make(t, "becca")
	await _drag(t, scene.item_point("becca-backpack"), scene.tray_point(0))
	await _drag(t, scene.item_point("tablet"), scene.tray_point(0))
	t.eq(scene.tray_items(0), ["becca-backpack", "tablet"] as Array[String], "any tray is fine for becca")
	_done(t, scene)


func test_tray_goes_through_the_scanner(t) -> void:
	var scene := await _make(t, "becca")
	for pair in [["becca-backpack", 0], ["tablet", 1], ["buddy", 2]]:
		await _drag(t, scene.item_point(pair[0]), scene.tray_point(pair[1]))
	await _tap(t, scene.tray_point(1))
	await t.tree.create_timer(scene.SCAN_TIME / 2).timeout
	t.check(scene.get_node("Stage/Screen").get_child_count() > 0, "the screen shows what's inside")
	await t.tree.create_timer(scene.SCAN_TIME).timeout
	t.check(scene.tray_sent(1), "out the other side")
	t.eq(scene.get_node("Stage/Screen").get_child_count(), 0, "screen empty again")
	_done(t, scene)


func test_empty_tray_tap_does_nothing(t) -> void:
	var scene := await _make(t, "becca")
	await _tap(t, scene.tray_point(0))
	await t.tree.create_timer(0.3).timeout
	t.check(not scene.tray_sent(0), "nothing to send")
	_done(t, scene)


func test_buddy_comes_back_line(t) -> void:
	var scene := await _make(t, "becca")
	for pair in [["buddy", 0], ["tablet", 1], ["becca-backpack", 2]]:
		await _drag(t, scene.item_point(pair[0]), scene.tray_point(pair[1]))
	await _tap(t, scene.tray_point(0))
	await t.tree.create_timer(scene.SCAN_TIME + 0.3).timeout
	t.check(_said.has("comes-back"), "don't worry, it comes right back")
	_done(t, scene)


func test_arch_after_everything_is_through(t) -> void:
	var scene := await _make(t, "becca")
	await _tap(t, scene.arch_point())
	t.eq(scene.phase, "trays", "the arch waits until everything is through")
	await _scan_all(t, scene, {"becca-backpack": 0, "tablet": 1, "buddy": 2})
	t.check(_said.has("walk-through"), "now walk through")
	await _tap(t, scene.arch_point())
	await t.tree.create_timer(scene.WALK_TIME + 0.3).timeout
	t.eq(scene.phase, "collect", "through the arch")
	t.eq(scene.get_node("Stage/Player").pose, "arms-up", "arms up through the arch")
	t.check(_said.has("get-your-things"), "get your things back")
	_done(t, scene)


func test_collecting_everything_goes_to_the_maze(t) -> void:
	var scene := await _make(t, "jack")
	await _scan_all(t, scene, {"tablet": 0, "jack-backpack": 1, "mommy-purse": 1, "buddy": 2})
	await _tap(t, scene.arch_point())
	await t.tree.create_timer(scene.WALK_TIME + 0.3).timeout
	for id in ["tablet", "mommy-purse"]:
		await _drag(t, scene.item_point(id), scene.backpack_point())
	await _drag(t, scene.item_point("buddy"), scene.kid_point())
	t.check(_said.has("hug-buddy"), "give it a big hug")
	var game: Node = t.tree.root.get_node("Game")
	var end := Time.get_ticks_msec() + 6000
	while game.last_scene_request == "" and Time.get_ticks_msec() < end:
		await t.tree.process_frame
	t.eq(game.last_scene_request, "res://scenes/maze.tscn", "on to the gate maze")
	_done(t, scene)


func test_everything_on_screen_on_the_tablet(t) -> void:
	var scene := await _make(t, "jack")
	t.tree.root.size = Vector2i(1920, 1200)
	await t.tree.process_frame
	var view := Rect2(Vector2(960, 540) - scene.get_viewport().get_visible_rect().size / 2, scene.get_viewport().get_visible_rect().size)
	for id in scene.item_ids():
		t.check(view.has_point(scene.item_point(id)), "%s on screen" % id)
	for i in 3:
		var tray: Sprite2D = scene.get_node("Stage/Trays").get_child(i)
		var r := Rect2(tray.global_position - tray.texture.get_size() * tray.global_scale / 2, tray.texture.get_size() * tray.global_scale)
		t.check(view.encloses(r), "tray %d all on screen" % i)
	for kid in ["Stage/Player", "Stage/Helper"]:
		t.check(view.encloses(scene.get_node(kid).hit_rect()), "%s on screen" % kid)
	_done(t, scene)
	t.tree.root.size = Vector2i(1920, 1080)


func test_trays_wait_until_everything_is_in_one(t) -> void:
	var scene := await _make(t, "jack")
	await _drag(t, scene.item_point("jack-backpack"), scene.tray_point(0))
	await _tap(t, scene.tray_point(0))
	await t.tree.create_timer(0.3).timeout
	t.check(not scene.tray_sent(0), "a tray waits until all your things are in trays")
	t.check(not _said.has("push-it"), "no push-it yet")
	await _drag(t, scene.item_point("buddy"), scene.tray_point(1))
	await _drag(t, scene.item_point("mommy-purse"), scene.tray_point(2))
	await _drag(t, scene.item_point("tablet"), scene.tray_point(2))
	var alone: Array[String] = ["tablet"]
	var trays_with_tablet := 0
	for i in 3:
		if scene.tray_items(i).has("tablet"):
			trays_with_tablet += 1
			t.eq(scene.tray_items(i), alone, "the tablet still gets a tray of its own")
	t.eq(trays_with_tablet, 1, "one tray has the tablet")
	t.check(_said.has("push-it"), "push it through, once everything's in")
	_done(t, scene)


func test_one_tray_at_a_time_in_the_scanner(t) -> void:
	var scene := await _make(t, "becca")
	for pair in [["becca-backpack", 0], ["tablet", 1], ["buddy", 2]]:
		await _drag(t, scene.item_point(pair[0]), scene.tray_point(pair[1]))
	await _tap(t, scene.tray_point(0))
	await _tap(t, scene.tray_point(1))
	await t.tree.create_timer(scene.SCAN_TIME / 2).timeout
	t.check(not scene.tray_sent(1), "the second tray waits for the scanner")
	_done(t, scene)


func test_buddy_on_the_backpack_still_gets_a_hug(t) -> void:
	var scene := await _make(t, "becca")
	await _scan_all(t, scene, {"becca-backpack": 0, "tablet": 1, "buddy": 2})
	await _tap(t, scene.arch_point())
	await t.tree.create_timer(scene.WALK_TIME + 0.3).timeout
	await _drag(t, scene.item_point("buddy"), scene.backpack_point())
	t.check(_said.has("hug-buddy"), "the buddy gets a hug either way")
	_done(t, scene)
