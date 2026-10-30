# Drives the room the way a child does: real taps and drags through the input
# pipeline, plus direct drags for the drawer game.
extends RefCounted

const Step := preload("res://scripts/room.gd").Step

var _to_screen := Transform2D.IDENTITY
var _requests: Array[String] = []


func _make(t, kid_id := "becca", outfits := 1, done_video := "", level := 0) -> Node2D:
	var progress: Node = t.tree.root.get_node("Progress")
	progress.path = "user://test_room_progress.json"
	progress.reset()
	t.tree.root.get_node("Voice").enabled = false
	var game: Node = t.tree.root.get_node("Game")
	game.level = level
	game.navigate = false
	game.last_scene_request = ""
	_requests.clear()
	if not game.scene_requested.is_connected(_on_request):
		game.scene_requested.connect(_on_request)
	var kid: KidProfile = load("res://data/%s.tres" % kid_id).duplicate()
	kid.outfits = outfits
	kid.done_video = done_video
	game.kid = kid
	var room: Node2D = load("res://scenes/room.tscn").instantiate()
	t.tree.root.add_child(room)
	await t.tree.process_frame
	await t.tree.process_frame
	_to_screen = t.tree.root.get_final_transform() * room.get_canvas_transform()
	return room


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


func _touch_drag(t, world: Vector2) -> void:
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
		await _touch_drag(t, from.lerp(to, i / 5.0))
	await _touch(t, false, to)


func _wait(t, seconds: float) -> void:
	await t.tree.create_timer(seconds).timeout


## Waits (frame by frame) until cond() is true; fails the test after timeout seconds.
func _until(t, cond: Callable, timeout := 5.0) -> bool:
	var end := Time.get_ticks_msec() + timeout * 1000
	while not cond.call():
		if Time.get_ticks_msec() > end:
			t.check(false, "timed out waiting")
			return false
		await t.tree.process_frame
	return true


## Plays the way a child would until the room reaches the target step.
func _advance(t, room: Node2D, target: int) -> void:
	var view: DrawerView = room.get_node("DrawerView")
	var guard := 0
	while room.step != target and room.step != Step.DONE and guard < 200:
		guard += 1
		var at: int = room.step
		match at:
			Step.START:
				await _tap(t, room.suitcase_point())
				await _until(t, func(): return room.step != at)
			Step.OPENED:
				await _tap(t, room.dresser_point())
				await _until(t, func(): return room.step != at)
			Step.FINDING:
				if not await _until(t, func(): return view.visible and view.correct_choice() != null):
					return
				var item := view.correct_choice()
				item.begin_drag(item.global_position)
				item.drag_to(view.TARGET_CENTER)
				item.end_drag(view.TARGET_CENTER)
				var done_id := item.get_instance_id()
				await _until(t, func(): return room.step != at or (view.visible and view.correct_choice() != null \
						and view.correct_choice().get_instance_id() != done_id))
			Step.ROLL:
				await _tap(t, room.layup_point())
				await _until(t, func(): return room.step != at)
			Step.PACK_BUNDLE:
				var bundle: Draggable = room.get_node("Stage/Bundle")
				await _drag(t, bundle.global_position + Vector2(0, 5), bundle.snap_point)
				await _until(t, func(): return room.step != at)
			Step.CLOSE:
				await _tap(t, room.suitcase_point())
				await _until(t, func(): return room.step != at)
			Step.PACK_ITEMS:
				var loose: Array = room.loose_items()
				if loose.is_empty():
					await _until(t, func(): return room.step != at)
				else:
					var item: Draggable = loose[0]
					await _drag(t, item.global_position, item.snap_point)
					var left: int = loose.size() - 1
					await _until(t, func(): return room.step != at or room.loose_items().size() == left)
			Step.ZIP:
				var zipper: Zipper = room.get_node("Stage/Suitcase/Zipper")
				await _drag(t, zipper.to_global(zipper.start), zipper.to_global(zipper.end))
				await _until(t, func(): return room.step != at)


func test_open_suitcase_reveals_card(t) -> void:
	var room := await _make(t)
	t.eq(room.step, Step.START, "starts closed")
	await _tap(t, room.suitcase_point())
	await _wait(t, 0.8)
	t.eq(room.step, Step.OPENED, "opened")
	t.check(room.get_node("Card").visible, "card shown")
	t.check(room.get_node("Card/Glow").visible, "first item glows")
	room.free()


func _full_flow(t, kid_id: String, choices: int, outfits: int) -> void:
	var room := await _make(t, kid_id, outfits)
	await _advance(t, room, Step.FINDING)
	t.eq(room.get_node("DrawerView").choices().size(), choices, "choices for %s" % kid_id)
	await _advance(t, room, Step.ROLL)
	t.eq(room.get_node("Card").stamped_count(), 4, "four checks")
	await _advance(t, room, Step.DONE)
	t.eq(room.step, Step.DONE, "done")
	t.eq(room.packed_count(), outfits, "every outfit packed")
	await _until(t, func(): return room.get_node("Finish").visible)
	room.free()


func test_full_flow_becca(t) -> void:
	await _full_flow(t, "becca", 2, 2)


func test_full_flow_jack(t) -> void:
	await _full_flow(t, "jack", 4, 1)


func test_outfits_per_kid(t) -> void:
	t.eq(load("res://data/becca.tres").outfits, 4, "becca rolls four")
	t.eq(load("res://data/jack.tres").outfits, 6, "jack rolls six")


func test_next_outfit_starts_fresh(t) -> void:
	var room := await _make(t, "becca", 2)
	await _advance(t, room, Step.PACK_BUNDLE)
	await _advance(t, room, Step.OPENED)
	t.eq(room.step, Step.OPENED, "back to the dresser")
	t.eq(room.outfit_index, 1, "second outfit")
	t.eq(room.packed_count(), 1, "first bundle stays in the suitcase")
	t.eq(room.get_node("Card").stamped_count(), 0, "card checks cleared")
	t.check(room.get_node("Card/Glow").visible, "first item glows again")
	t.eq(room.get_node("Stage/Layup").get_child_count(), 0, "rug empty")
	t.check(not room.get_node("Stage/Bundle").visible, "bundle put away")
	room.free()


func test_done_video_then_finish(t) -> void:
	var room := await _make(t, "becca", 1, "res://assets/video/becca-done.ogv")
	await _advance(t, room, Step.DONE)
	var player: VideoStreamPlayer = room.get_node("DoneVideo/Player")
	await _until(t, func(): return player.is_playing())
	t.check(not room.get_node("Finish").visible, "buttons wait for the video")
	await _tap(t, Vector2(960, 540))
	await _until(t, func(): return room.get_node("Finish").visible)
	t.check(not room.get_node("DoneVideo").visible, "video gone")
	room.free()


func test_done_without_video_shows_finish(t) -> void:
	var room := await _make(t, "becca", 1, "")
	await _advance(t, room, Step.DONE)
	await _until(t, func(): return room.get_node("Finish").visible)
	t.check(not room.get_node("DoneVideo").visible, "no video")
	room.free()


func test_cues_pulse_current_target(t) -> void:
	var room := await _make(t, "becca", 1)
	t.eq(room.cue, "suitcase", "suitcase first")
	await _advance(t, room, Step.OPENED)
	t.eq(room.cue, "spot", "then the dresser")
	t.check(room.get_node("Stage/DresserGlow").visible, "dresser glows")
	var case_scale: float = room.get_node("Stage/Suitcase").scale.x
	t.check(absf(case_scale - room.layout_value("suitcase_scale")) < 0.001, "suitcase pulse undone")
	await _advance(t, room, Step.FINDING)
	t.eq(room.cue, "", "no room cue in the drawer")
	t.check(not room.get_node("Stage/DresserGlow").visible, "glow off")
	await _advance(t, room, Step.ROLL)
	t.eq(room.cue, "layup", "the pile")
	await _advance(t, room, Step.PACK_BUNDLE)
	t.eq(room.cue, "bundle", "the bundle")
	await _advance(t, room, Step.CLOSE)
	t.eq(room.cue, "suitcase", "close the lid")
	await _advance(t, room, Step.ZIP)
	t.eq(room.cue, "zipper", "the zipper")
	await _advance(t, room, Step.DONE)
	t.eq(room.cue, "", "nothing left")
	room.free()


func test_drawer_reopens_by_itself(t) -> void:
	var room := await _make(t)
	await _advance(t, room, Step.FINDING)
	var view: DrawerView = room.get_node("DrawerView")
	await _until(t, func(): return view.visible)
	var found := [false]
	view.found.connect(func(_i): found[0] = true)
	var item := view.correct_choice()
	item.begin_drag(item.global_position)
	item.drag_to(view.TARGET_CENTER)
	item.end_drag(view.TARGET_CENTER)
	await _until(t, func(): return found[0])
	t.check(not view.visible, "drawer closes for the flight")
	await _wait(t, 1.3)
	t.check(view.visible, "drawer back for the next item")
	t.eq(room.item_index, 1, "on item two")
	room.free()


func test_double_taps_do_not_skip_steps(t) -> void:
	var room := await _make(t)
	await _tap(t, room.suitcase_point())
	await _tap(t, room.suitcase_point())
	await _wait(t, 0.8)
	t.eq(room.step, Step.OPENED, "two taps open once")
	var view: DrawerView = room.get_node("DrawerView")
	var opens := [0]
	view.visibility_changed.connect(func(): if view.visible: opens[0] += 1)
	await _tap(t, room.dresser_point())
	await _tap(t, room.dresser_point())
	await _wait(t, 0.6)
	t.eq(opens[0], 1, "drawer opened once")
	t.eq(room.step, Step.FINDING, "finding")
	room.free()


func test_zip_during_lid_bounce_is_not_stuck(t) -> void:
	var room := await _make(t)
	await _advance(t, room, Step.CLOSE)
	var zipper: Zipper = room.get_node("Stage/Suitcase/Zipper")
	room.tap_suitcase()
	# Swipe the zipper while the lid is still bouncing shut.
	zipper.begin(zipper.to_global(zipper.start))
	zipper.drag(zipper.to_global(zipper.end))
	zipper.release()
	await _wait(t, 0.5)
	t.eq(room.step, Step.ZIP, "ready to zip")
	await _drag(t, zipper.to_global(zipper.start), zipper.to_global(zipper.end))
	await _wait(t, 0.2)
	t.eq(room.step, Step.DONE, "zipping still finishes")
	room.free()


func test_hint_waits_for_idle(t) -> void:
	var room := await _make(t)
	var helper: Character = room.get_node("Stage/Helper")
	await _advance(t, room, Step.OPENED)
	await _wait(t, room.get_node("/root/Game").kid.hint_delay + 0.5)
	t.eq(helper.pose, "point", "helper points when idle")
	room.free()

	room = await _make(t)
	helper = room.get_node("Stage/Helper")
	await _advance(t, room, Step.PACK_BUNDLE)
	var bundle: Draggable = room.get_node("Stage/Bundle")
	await _touch(t, true, bundle.global_position)
	await _touch_drag(t, bundle.global_position + Vector2(30, 0))
	await _wait(t, room.get_node("/root/Game").kid.hint_delay + 0.5)
	t.check(helper.pose != "point", "no hint mid-drag")
	await _touch(t, false, bundle.global_position)
	room.free()


func test_replay_starts_clean(t) -> void:
	var room := await _make(t)
	await _advance(t, room, Step.DONE)
	await _until(t, func(): return room.get_node("Finish").visible)
	room.get_node("Finish/ReplayButton").pressed.emit()
	t.eq(_requests.back(), "res://scenes/room.tscn", "replay reloads the room")
	room.free()
	room = await _make(t)
	t.eq(room.get_node("Card").stamped_count(), 0, "no checks")
	t.eq(room.step, Step.START, "back to start")
	t.eq(room.get_node("Stage/Layup").get_child_count(), 0, "layup empty")
	t.check(not room.get_node("Stage/Bundle").visible, "bundle hidden")
	t.eq(room.packed_count(), 0, "suitcase empty")
	room.free()


func _button_center(room: Node2D, path: String) -> Vector2:
	var b: TextureButton = room.get_node(path)
	return b.global_position + b.size / 2


func test_finish_buttons_continue_home_replay(t) -> void:
	var room := await _make(t)
	await _advance(t, room, Step.DONE)
	await _until(t, func(): return room.get_node("Finish").visible)
	await _tap(t, _button_center(room, "Finish/ContinueButton"))
	t.eq(_requests.back(), "res://scenes/map.tscn", "continue goes on to the card")
	await _tap(t, _button_center(room, "Finish/HomeButton"))
	t.eq(_requests.back(), "res://scenes/title.tscn", "home always goes home")
	await _tap(t, _button_center(room, "Finish/ReplayButton"))
	t.eq(_requests.back(), "res://scenes/room.tscn", "replay plays the row again")
	t.check(not room.get_node("PlayHome").visible, "no second home button at the end")
	room.free()


func test_home_button_while_playing(t) -> void:
	var room := await _make(t)
	t.check(room.get_node("PlayHome").visible, "shown from the start")
	var at := _button_center(room, "PlayHome")
	var view := get_viewport_rect_of(room)
	t.check(at.x < view.position.x + 300 and at.y < view.position.y + 300, "top left: " + str(at))
	await _advance(t, room, Step.FINDING)
	await _until(t, func(): return room.get_node("DrawerView").visible)
	await _tap(t, _button_center(room, "PlayHome"))
	t.eq(_requests.back(), "res://scenes/title.tscn", "escape to the title, even from the drawer")
	room.free()


func get_viewport_rect_of(room: Node2D) -> Rect2:
	var view := room.get_viewport().get_visible_rect().size
	return Rect2(Vector2(960, 540) - view / 2, view)


func test_background_covers_tall_screens(t) -> void:
	var script: GDScript = load("res://scripts/room.gd")
	t.check(absf(script.cover_scale(Vector2(1920, 1200), Vector2(1672, 941)) - 1.2752) < 0.001, "16:10")
	t.check(absf(script.cover_scale(Vector2(1920, 1080), Vector2(1672, 941)) - 1.1483) < 0.001, "16:9")


func test_level_2_rolls_pajamas(t) -> void:
	var room := await _make(t, "becca", 4, "", 1)
	await _advance(t, room, Step.FINDING)
	t.eq(room.get_node("DrawerView").correct_choice().texture in load("res://data/becca.tres").colors("pajamas"), true, "pajamas first")
	await _advance(t, room, Step.DONE)
	t.eq(room.packed_count(), 1, "one round only, whatever the outfit count")
	t.check(1 in t.tree.root.get_node("Progress").levels_done("becca"), "level saved as done")
	room.free()


func test_level_3_packs_items_one_by_one(t) -> void:
	var room := await _make(t, "jack", 1, "", 2)
	t.check(room.get_node("Stage/Spot").visible, "basket on the floor")
	await _advance(t, room, Step.OPENED)
	t.eq(room.cue, "spot", "basket pulses")
	await _advance(t, room, Step.PACK_ITEMS)
	t.eq(room.loose_items().size(), 4, "four things on the rug")
	t.eq(room.cue, "items", "they pulse")
	await _advance(t, room, Step.CLOSE)
	t.eq(room.packed_count(), 4, "all four in the suitcase")
	await _advance(t, room, Step.DONE)
	t.eq(room.step, Step.DONE, "done")
	room.free()


func test_level_4_hugs_the_buddy(t) -> void:
	var room := await _make(t, "becca", 1, "", 3)
	var player: Character = room.get_node("Stage/Player")
	var hugged := [false]
	var watch := func(): if player.pose == "hug": hugged[0] = true
	t.tree.process_frame.connect(watch)
	await _advance(t, room, Step.FINDING)
	var view: DrawerView = room.get_node("DrawerView")
	await _until(t, func(): return view.visible)
	var item := view.correct_choice()
	item.begin_drag(item.global_position)
	item.end_drag(view.TARGET_CENTER)
	await _until(t, func(): return hugged[0], 3.0)
	t.check(hugged[0], "hugs the buddy")
	t.eq(t.tree.root.get_node("Voice").last_line, "hug-buddy", "helper says hug it")
	t.tree.process_frame.disconnect(watch)
	room.free()


func test_voice_follows_steps(t) -> void:
	var room := await _make(t, "becca", 1, "", 0)
	var voice: Node = t.tree.root.get_node("Voice")
	t.eq(voice.last_line, "open-suitcase", "open the suitcase")
	await _advance(t, room, Step.OPENED)
	t.eq(voice.last_line, "open-drawer", "open the drawer")
	await _advance(t, room, Step.FINDING)
	t.eq(voice.last_line, "find-shirt", "find the shirt")
	room.free()
	room = await _make(t, "becca", 1, "", 3)
	await _advance(t, room, Step.OPENED)
	t.eq(voice.last_line, "open-toybox", "toy box level")
	room.free()


func test_last_row_celebrates_the_whole_card(t) -> void:
	var room := await _make(t, "becca", 1, "", 3)
	var progress: Node = t.tree.root.get_node("Progress")
	for level in [0, 1, 2]:
		progress.mark_done("becca", level)
	await _advance(t, room, Step.DONE)
	t.eq(t.tree.root.get_node("Voice").last_line, "all-packed", "we packed everything")
	room.free()


func test_found_cheer_is_not_cut_off(t) -> void:
	var room := await _make(t, "becca", 1, "", 0)
	var voice: Node = t.tree.root.get_node("Voice")
	await _advance(t, room, Step.FINDING)
	voice.enabled = true
	var view: DrawerView = room.get_node("DrawerView")
	await _until(t, func(): return view.visible)
	var item := view.correct_choice()
	item.begin_drag(item.global_position)
	item.end_drag(view.TARGET_CENTER)
	await _until(t, func(): return not view.visible)
	await _until(t, func(): return view.visible)
	t.check(voice.current_line.begins_with("found-"), "the cheer still playing, got " + voice.current_line)
	voice.stop()
	voice.enabled = false
	room.free()
