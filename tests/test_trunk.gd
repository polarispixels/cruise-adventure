# The trunk puzzle, driven the way a child does: real touches and drags.
extends RefCounted

var _to_screen := Transform2D.IDENTITY
var _requests: Array[String] = []


func _make(t, kid_id := "jack", size := Vector2i(1920, 1080), hint_delay := 30.0) -> Node2D:
	var progress: Node = t.tree.root.get_node("Progress")
	progress.path = "user://test_trunk_progress.json"
	progress.reset()
	t.tree.root.get_node("Voice").enabled = false
	t.tree.root.get_node("Voice").last_line = ""
	t.tree.root.size = size
	var game: Node = t.tree.root.get_node("Game")
	game.navigate = false
	game.last_scene_request = ""
	_requests.clear()
	if not game.scene_requested.is_connected(_on_request):
		game.scene_requested.connect(_on_request)
	var kid: KidProfile = load("res://data/%s.tres" % kid_id).duplicate()
	kid.hint_delay = hint_delay
	game.kid = kid
	var trunk: Node2D = load("res://scenes/trunk.tscn").instantiate()
	t.tree.root.add_child(trunk)
	await t.tree.process_frame
	await t.tree.process_frame
	_to_screen = t.tree.root.get_final_transform() * trunk.get_canvas_transform()
	return trunk


func _done(t, trunk: Node) -> void:
	trunk.free()
	var progress: Node = t.tree.root.get_node("Progress")
	progress.reset()
	progress.path = "user://progress.json"


func _on_request(path: String) -> void:
	_requests.append(path)


func _send(t, event: InputEvent) -> void:
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await t.tree.process_frame


func _touch(t, pressed: bool, world: Vector2) -> void:
	var e := InputEventScreenTouch.new()
	e.pressed = pressed
	e.position = _to_screen * world
	await _send(t, e)


func _move(t, world: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.position = _to_screen * world
	e.relative = Vector2(1, 1)
	await _send(t, e)


func _tap(t, world: Vector2) -> void:
	await _touch(t, true, world)
	await _touch(t, false, world)


func _drag(t, from: Vector2, to: Vector2) -> void:
	await _touch(t, true, from)
	for i in range(1, 6):
		await _move(t, from.lerp(to, i / 5.0))
	await _touch(t, false, to)


func _settle(t) -> void:
	await t.tree.create_timer(0.6).timeout


## Drags a bag so its center lands where it sits at `cell` (turned as it is now).
func _drop_at(t, trunk: Node2D, id: String, cell: Vector2i) -> void:
	var bag: Bag = trunk.bag(id)
	var size: Vector2i = trunk.model.size_of(id, trunk.model.is_turned(id))
	await _drag(t, bag.global_position, trunk.cell_center(cell, size))
	await _settle(t)


func _voice(t) -> String:
	return t.tree.root.get_node("Voice").last_line


func test_jack_starts_empty(t) -> void:
	var trunk := await _make(t, "jack")
	t.eq(trunk.model.placed_ids().size(), 0, "nothing loaded")
	_done(t, trunk)


func test_becca_starts_with_two_bags_in(t) -> void:
	var trunk := await _make(t, "becca")
	t.eq(trunk.model.placed_ids(), ["mommy-yellow", "daddy-gray"] as Array[String], "the big bags are in")
	t.eq(trunk.model.cell_of("daddy-gray"), Vector2i(0, 2), "at its reference spot")
	t.check(trunk.model.is_turned("daddy-gray"), "turned as in the reference")
	t.check(trunk.bag("daddy-gray").global_position.distance_to(trunk.cell_center(Vector2i(0, 2), Vector2i(3, 2))) < 1.0, "drawn there")
	_done(t, trunk)


func test_drag_into_trunk_places_bag(t) -> void:
	var trunk := await _make(t, "jack")
	await _drop_at(t, trunk, "mommy-purse", Vector2i(5, 4))
	t.eq(trunk.model.cell_of("mommy-purse"), Vector2i(5, 4), "placed")
	t.check(trunk.bag("mommy-purse").global_position.distance_to(trunk.cell_center(Vector2i(5, 4), Vector2i(1, 1))) < 1.0, "snapped")
	_done(t, trunk)


func test_drop_that_does_not_fit_slides_back(t) -> void:
	var trunk := await _make(t, "jack")
	var bag: Bag = trunk.bag("mommy-yellow")
	await _drag(t, bag.global_position, trunk.cell_center(Vector2i(3, 0), Vector2i(5, 2)))
	await _settle(t)
	t.eq(trunk.model.cell_of("mommy-yellow"), TrunkModel.NOWHERE, "not placed")
	t.check(bag.global_position.distance_to(trunk.ground_point("mommy-yellow")) < 1.0, "back on the driveway")
	t.eq(_voice(t), "try-another-spot", "the helper says so")
	_done(t, trunk)


func test_tap_on_ground_turns_bag(t) -> void:
	var trunk := await _make(t, "jack")
	var bag: Bag = trunk.bag("daddy-gray")
	await _tap(t, bag.global_position)
	t.check(trunk.model.is_turned("daddy-gray"), "turned")
	t.eq(bag.rect().size, Vector2(300, 200), "lying on its side")
	await _tap(t, bag.global_position)
	t.check(not trunk.model.is_turned("daddy-gray"), "standing again")
	_done(t, trunk)


func test_bag_that_needs_turning_says_turn_it(t) -> void:
	var trunk := await _make(t, "jack")
	trunk.model.place("mommy-yellow", Vector2i(0, 0))
	trunk.model.place("jack-suitcase", Vector2i(5, 0))
	trunk.model.place("becca-suitcase", Vector2i(3, 2))
	trunk.model.place("daddy-backpack", Vector2i(5, 2))
	trunk.model.set_turned("jack-backpack", true)
	trunk.model.place("jack-backpack", Vector2i(1, 4))
	trunk.sync_bags()
	# The gap left is 3 wide and 2 tall: standing (2x3) it can't fit; lying (3x2) it does.
	var bag: Bag = trunk.bag("daddy-gray")
	await _drag(t, bag.global_position, trunk.cell_center(Vector2i(0, 2), Vector2i(3, 2)))
	await _settle(t)
	t.eq(trunk.model.cell_of("daddy-gray"), TrunkModel.NOWHERE, "jack-jack turns it himself")
	t.eq(_voice(t), "turn-it", "the helper tells him how")
	_done(t, trunk)


func test_becca_auto_turns(t) -> void:
	var trunk := await _make(t, "becca")
	var bag: Bag = trunk.bag("jack-backpack")
	await _drag(t, bag.global_position, trunk.cell_center(Vector2i(1, 4), Vector2i(2, 1)))
	await _settle(t)
	t.eq(trunk.model.cell_of("jack-backpack"), Vector2i(1, 4), "placed")
	t.check(trunk.model.is_turned("jack-backpack"), "it turned itself")
	_done(t, trunk)


func test_turned_state_kept_after_slide_back(t) -> void:
	var trunk := await _make(t, "jack")
	var bag: Bag = trunk.bag("daddy-gray")
	await _tap(t, bag.global_position)
	await _drag(t, bag.global_position, trunk.cell_center(Vector2i(5, 0), Vector2i(3, 2)))
	await _settle(t)
	t.eq(trunk.model.cell_of("daddy-gray"), TrunkModel.NOWHERE, "didn't fit")
	t.check(trunk.model.is_turned("daddy-gray"), "still turned")
	_done(t, trunk)


func test_drag_out_of_trunk(t) -> void:
	var trunk := await _make(t, "jack")
	await _drop_at(t, trunk, "mommy-purse", Vector2i(0, 0))
	var bag: Bag = trunk.bag("mommy-purse")
	await _drag(t, bag.global_position, trunk.ground_point("mommy-purse"))
	await _settle(t)
	t.eq(trunk.model.cell_of("mommy-purse"), TrunkModel.NOWHERE, "out again")
	t.check(bag.global_position.distance_to(trunk.ground_point("mommy-purse")) < 1.0, "on the driveway")
	_done(t, trunk)


func test_tap_in_trunk_only_wiggles(t) -> void:
	var trunk := await _make(t, "jack")
	await _drop_at(t, trunk, "daddy-gray", Vector2i(5, 1))
	t.eq(trunk.model.cell_of("daddy-gray"), Vector2i(5, 1), "placed standing")
	await _tap(t, trunk.bag("daddy-gray").global_position)
	await _settle(t)
	t.check(not trunk.model.is_turned("daddy-gray"), "not turned")
	t.eq(trunk.model.cell_of("daddy-gray"), Vector2i(5, 1), "still there")
	_done(t, trunk)


func test_locked_bag_stays_put(t) -> void:
	var trunk := await _make(t, "becca")
	var bag: Bag = trunk.bag("mommy-yellow")
	var at := bag.global_position
	await _drag(t, at, trunk.ground_point("mommy-yellow"))
	await _settle(t)
	t.eq(trunk.model.cell_of("mommy-yellow"), Vector2i(0, 0), "still loaded")
	t.check(bag.global_position.distance_to(at) < 1.0, "didn't move")
	_done(t, trunk)


func test_both_kids_see_a_ghost_of_each_bag_in_its_spot(t) -> void:
	for pair in [["becca", 6], ["jack", 8]]:
		var trunk := await _make(t, pair[0])
		var ghosts: Node2D = trunk.get_node("Outlines")
		t.eq(ghosts.get_child_count(), pair[1], "%s: a ghost for each bag left to load" % pair[0])
		var ghost: Sprite2D = ghosts.get_node("daddy-backpack")
		t.eq(ghost.texture, trunk.bag("daddy-backpack").get_node("Sprite").texture, "the bag's own picture")
		t.check(ghost.modulate.a < 0.5, "faded")
		t.check(ghost.global_position.distance_to(trunk.cell_center(Vector2i(5, 2), Vector2i(2, 2))) < 1.0, "at its spot")
		if pair[0] == "jack":
			var gray: Sprite2D = ghosts.get_node("daddy-gray")
			t.check(is_equal_approx(gray.rotation, PI / 2), "turned, as it must go in")
		await _drop_at(t, trunk, "daddy-backpack", Vector2i(5, 2))
		t.check(not ghost.visible, "gone once the bag's in")
		_done(t, trunk)


func test_lost_release_returns_the_bag(t) -> void:
	var trunk := await _make(t, "jack")
	var bag: Bag = trunk.bag("mommy-purse")
	var home := bag.global_position
	await _touch(t, true, home)
	await _move(t, home + Vector2(0, -150))
	await _move(t, home + Vector2(0, -300))
	trunk.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	await _settle(t)
	t.check(not trunk.is_dragging(), "not stuck to the finger")
	t.check(bag.global_position.distance_to(home) < 1.0, "back on the driveway")
	# The finger does lift eventually; don't leave it down for the next test.
	await _touch(t, false, home + Vector2(0, -300))
	t.eq(trunk.model.cell_of("mommy-purse"), TrunkModel.NOWHERE, "the late release does nothing")
	_done(t, trunk)


func test_layout_fits_16_10_and_16_9(t) -> void:
	for size in [Vector2i(1920, 1080), Vector2i(1920, 1200)]:
		var trunk := await _make(t, "jack", size)
		var view_size: Vector2 = trunk.get_viewport().get_visible_rect().size
		var view := Rect2(Vector2(960, 540) - view_size / 2, view_size)
		var cargo: Rect2 = trunk.cargo_rect()
		var rects: Array[Rect2] = []
		for id in trunk.model.bag_ids:
			var r: Rect2 = trunk.bag(id).rect()
			t.check(view.encloses(r), "%s on screen at %s" % [id, size])
			t.check(not r.intersects(cargo), "%s not over the trunk" % id)
			for other in rects:
				t.check(not r.intersects(other), "%s overlaps another bag" % id)
			rects.append(r)
		t.check(view.encloses(cargo), "trunk on screen")
		_done(t, trunk)
	t.tree.root.size = Vector2i(1920, 1080)


## Loads every bag but `last` at its reference spot, then drags `last` in.
func _fill(t, trunk: Node2D, last := "mommy-purse") -> void:
	var ref: Dictionary = trunk.model.reference_solution()
	for id in ref:
		if id != last and trunk.model.cell_of(id) == TrunkModel.NOWHERE:
			trunk.model.set_turned(id, ref[id]["turned"])
			trunk.model.place(id, ref[id]["cell"])
	trunk.sync_bags()
	trunk.model.set_turned(last, ref[last]["turned"])
	trunk.bag(last).set_turned(ref[last]["turned"])
	await _drop_at(t, trunk, last, ref[last]["cell"])


func test_says_load_car_at_start(t) -> void:
	var trunk := await _make(t, "jack")
	t.eq(_voice(t), "load-car", "the helper says what to do")
	_done(t, trunk)


func test_idle_hint_points_at_a_bag(t) -> void:
	var trunk := await _make(t, "jack", Vector2i(1920, 1080), 0.3)
	await t.tree.create_timer(0.6).timeout
	var pulsing: Array = trunk.model.bag_ids.filter(func(id): return trunk.bag(id).is_pulsing())
	t.eq(pulsing.size(), 1, "one bag pulses")
	t.check(trunk.get_node("HintOutline").visible, "its spot glows")
	t.eq(trunk.get_node("Helper").pose, "point", "the helper points")
	await _tap(t, Vector2(960, 1000))
	t.check(not trunk.get_node("HintOutline").visible, "a touch clears the hint")
	_done(t, trunk)


func test_idle_hint_flags_dead_end(t) -> void:
	var trunk := await _make(t, "jack", Vector2i(1920, 1080), 0.3)
	await _drop_at(t, trunk, "mommy-purse", Vector2i(0, 0))
	await _tap(t, Vector2(960, 1000))  # an empty patch of driveway: starts the idle wait over
	t.tree.root.get_node("Voice").last_line = ""
	await t.tree.create_timer(0.6).timeout
	t.eq(_voice(t), "try-another-spot", "the helper says to move it")
	t.check(not trunk.get_node("HintOutline").visible, "no spot to show")
	_done(t, trunk)


func test_filling_says_close_trunk(t) -> void:
	var trunk := await _make(t, "jack")
	await _fill(t, trunk)
	t.check(trunk.model.is_full(), "full")
	t.eq(_voice(t), "close-trunk", "close the trunk")
	_done(t, trunk)


func test_tap_hatch_closes_and_marks_done(t) -> void:
	var trunk := await _make(t, "becca")
	t.eq(trunk.payoff_video, "res://assets/video/car-drive-off.ogv", "the drive-off clip is the payoff")
	trunk.payoff_video = ""
	await _fill(t, trunk)
	await _tap(t, trunk.hatch_point())
	await t.tree.create_timer(0.3).timeout
	t.eq(trunk.get_node("Suv").texture.resource_path, "res://assets/car/suv-closed.png", "hatch shut")
	t.check(t.tree.root.get_node("Progress").car_done("becca"), "remembered")
	t.eq(_voice(t), "lets-go", "airport, here we come")
	t.check(trunk.get_node("Finish").visible, "finish buttons (straight away without a clip)")
	_done(t, trunk)


func test_tap_hatch_before_full_does_nothing(t) -> void:
	var trunk := await _make(t, "jack")
	await _tap(t, trunk.hatch_point())
	t.eq(trunk.get_node("Suv").texture.resource_path, "res://assets/car/suv-open.png", "still open")
	t.check(not trunk.get_node("Finish").visible, "no finish")
	_done(t, trunk)


func test_hatch_double_tap_finishes_once(t) -> void:
	var trunk := await _make(t, "jack")
	await _fill(t, trunk)
	var said: Array[String] = []
	var voice: Node = t.tree.root.get_node("Voice")
	var record := func(line: String): said.append(line)
	voice.said.connect(record)
	await _tap(t, trunk.hatch_point())
	await _tap(t, trunk.hatch_point())
	await t.tree.create_timer(0.3).timeout
	voice.said.disconnect(record)
	t.eq(said.count("lets-go"), 1, "once")
	t.check(trunk.finished, "finished")
	_done(t, trunk)


func test_finish_buttons_go_home_replay_continue(t) -> void:
	var game: Node = t.tree.root.get_node("Game")
	for pair in [["HomeButton", game.TITLE], ["ReplayButton", game.TRUNK], ["ContinueButton", game.MAP]]:
		var trunk := await _make(t, "jack")
		trunk.payoff_video = ""
		await _fill(t, trunk)
		await _tap(t, trunk.hatch_point())
		await t.tree.create_timer(0.3).timeout
		var button: TextureButton = trunk.get_node("Finish/" + pair[0])
		await _tap(t, button.global_position + button.size / 2)
		t.eq(game.last_scene_request, pair[1], pair[0])
		_done(t, trunk)


func test_home_button_while_playing(t) -> void:
	var trunk := await _make(t, "jack")
	var button: TextureButton = trunk.get_node("PlayHome")
	await _tap(t, button.global_position + button.size / 2)
	t.eq(t.tree.root.get_node("Game").last_scene_request, "res://scenes/title.tscn", "home")
	_done(t, trunk)


func test_double_tap_on_hatch_keeps_the_payoff_clip(t) -> void:
	var trunk := await _make(t, "jack")
	trunk.payoff_video = "res://assets/video/becca-done.ogv"
	await _fill(t, trunk)
	await _tap(t, trunk.hatch_point())
	await _tap(t, trunk.hatch_point())
	await t.tree.create_timer(0.2).timeout
	t.check(trunk.get_node("PayoffVideo").visible, "the clip is still playing")
	t.check(not trunk.get_node("Finish").visible, "not skipped by the second tap")
	await t.tree.create_timer(0.8).timeout
	await _tap(t, Vector2(960, 540))
	t.check(trunk.get_node("Finish").visible, "a later tap skips it")
	_done(t, trunk)


func test_tap_during_the_snap_still_lands_on_the_grid(t) -> void:
	var trunk := await _make(t, "jack")
	var bag: Bag = trunk.bag("mommy-purse")
	var target: Vector2 = trunk.cell_center(Vector2i(5, 4), Vector2i(1, 1))
	await _drag(t, bag.global_position, target)
	await _tap(t, target)
	await _settle(t)
	t.eq(trunk.model.cell_of("mommy-purse"), Vector2i(5, 4), "placed")
	t.check(bag.global_position.distance_to(target) < 1.0, "on its spot, not frozen halfway: %s" % bag.global_position)
	t.check(bag.scale.is_equal_approx(Vector2.ONE), "not left enlarged")
	_done(t, trunk)


func test_resize_mid_drag_keeps_loaded_bags_in_the_trunk(t) -> void:
	var trunk := await _make(t, "jack")
	trunk.model.place("jack-suitcase", Vector2i(5, 0))
	trunk.sync_bags()
	var bag: Bag = trunk.bag("mommy-purse")
	var home := bag.global_position
	await _touch(t, true, home)
	await _move(t, home + Vector2(0, -100))
	t.tree.root.size = Vector2i(1920, 1200)
	await t.tree.process_frame
	await t.tree.process_frame
	_to_screen = t.tree.root.get_final_transform() * trunk.get_canvas_transform()
	await _touch(t, false, trunk.ground_point("mommy-purse"))
	await _settle(t)
	var suitcase: Bag = trunk.bag("jack-suitcase")
	t.check(suitcase.global_position.distance_to(trunk.cell_center(Vector2i(5, 0), Vector2i(2, 2))) < 1.0, "the loaded suitcase moved with the trunk")
	_done(t, trunk)
	t.tree.root.size = Vector2i(1920, 1080)


func test_turned_bags_do_not_overlap_on_the_driveway(t) -> void:
	for size in [Vector2i(1920, 1080), Vector2i(1920, 1200)]:
		var trunk := await _make(t, "jack", size)
		for id in trunk.model.bag_ids:
			trunk.model.set_turned(id, true)
		trunk.sync_bags()
		var view_size: Vector2 = trunk.get_viewport().get_visible_rect().size
		var view := Rect2(Vector2(960, 540) - view_size / 2, view_size)
		var rects: Array[Rect2] = []
		for id in trunk.model.bag_ids:
			var r: Rect2 = trunk.bag(id).rect()
			t.check(view.encloses(r), "%s on screen turned at %s" % [id, size])
			t.check(not r.intersects(trunk.cargo_rect()), "%s clear of the trunk" % id)
			for other in rects:
				t.check(not r.intersects(other), "%s overlaps another turned bag at %s" % [id, size])
			rects.append(r)
		_done(t, trunk)
	t.tree.root.size = Vector2i(1920, 1080)
