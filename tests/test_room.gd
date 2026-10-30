# Drives the room the way a child does: real taps and drags through the input
# pipeline, plus direct drags for the drawer game.
extends RefCounted

const Step := preload("res://scripts/room.gd").Step

var _to_screen := Transform2D.IDENTITY
var _requests: Array[String] = []


func _make(t, kid_id := "becca") -> Node2D:
	var game: Node = t.tree.root.get_node("Game")
	game.navigate = false
	game.last_scene_request = ""
	_requests.clear()
	if not game.scene_requested.is_connected(_on_request):
		game.scene_requested.connect(_on_request)
	game.kid = load("res://data/%s.tres" % kid_id)
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


## Taps through to the given step, the way a child would.
func _advance(t, room: Node2D, target: int) -> void:
	if room.step == Step.START and target > Step.START:
		await _tap(t, room.suitcase_point())
		await _wait(t, 0.8)
	if room.step == Step.OPENED and target > Step.OPENED:
		await _tap(t, room.dresser_point())
		await _wait(t, 0.6)
	while room.step == Step.FINDING and target > Step.FINDING:
		var view: DrawerView = room.get_node("DrawerView")
		var item := view.correct_choice()
		item.begin_drag(item.global_position)
		item.drag_to(view.TARGET_CENTER)
		item.end_drag(view.TARGET_CENTER)
		await _wait(t, 2.0)
	if room.step == Step.ROLL and target > Step.ROLL:
		await _tap(t, room.layup_point())
		await _wait(t, 0.8)
	if room.step == Step.PACK_BUNDLE and target > Step.PACK_BUNDLE:
		var bundle: Draggable = room.get_node("Stage/Bundle")
		await _drag(t, bundle.global_position, bundle.snap_point)
		await _wait(t, 0.8)
	if room.step == Step.CLOSE and target > Step.CLOSE:
		await _tap(t, room.suitcase_point())
		await _wait(t, 0.6)
	if room.step == Step.ZIP and target > Step.ZIP:
		var zipper: Zipper = room.get_node("Stage/Suitcase/Zipper")
		await _drag(t, zipper.to_global(zipper.start), zipper.to_global(zipper.end))
		await _wait(t, 0.2)


func test_open_suitcase_reveals_card(t) -> void:
	var room := await _make(t)
	t.eq(room.step, Step.START, "starts closed")
	await _tap(t, room.suitcase_point())
	await _wait(t, 0.8)
	t.eq(room.step, Step.OPENED, "opened")
	t.check(room.get_node("Card").visible, "card shown")
	t.check(room.get_node("Card/Glow").visible, "first item glows")
	room.free()


func _full_flow(t, kid_id: String, choices: int) -> void:
	var room := await _make(t, kid_id)
	await _advance(t, room, Step.FINDING)
	t.eq(room.step, Step.FINDING, "finding")
	t.eq(room.get_node("DrawerView").choices().size(), choices, "choices for %s" % kid_id)
	await _advance(t, room, Step.ROLL)
	t.eq(room.get_node("Card").stamped_count(), 4, "four checks")
	t.eq(room.step, Step.ROLL, "ready to roll")
	await _advance(t, room, Step.DONE)
	t.eq(room.step, Step.DONE, "done")
	await _wait(t, 1.0)
	t.check(room.get_node("Finish").visible, "finish shown")
	room.free()


func test_full_flow_becca(t) -> void:
	await _full_flow(t, "becca", 2)


func test_full_flow_jack(t) -> void:
	await _full_flow(t, "jack", 4)


func test_drawer_reopens_by_itself(t) -> void:
	var room := await _make(t)
	await _advance(t, room, Step.FINDING)
	var view: DrawerView = room.get_node("DrawerView")
	var found := [false]
	view.found.connect(func(_i): found[0] = true)
	var item := view.correct_choice()
	item.begin_drag(item.global_position)
	item.drag_to(view.TARGET_CENTER)
	item.end_drag(view.TARGET_CENTER)
	while not found[0]:
		await t.tree.process_frame
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
	await _wait(t, 1.0)
	room.get_node("Finish/ReplayButton").pressed.emit()
	t.eq(_requests.back(), "res://scenes/room.tscn", "replay reloads the room")
	room.free()
	room = await _make(t)
	t.eq(room.get_node("Card").stamped_count(), 0, "no checks")
	t.eq(room.step, Step.START, "back to start")
	t.eq(room.get_node("Stage/Layup").get_child_count(), 0, "layup empty")
	t.check(not room.get_node("Stage/Bundle").visible, "bundle hidden")
	room.free()


func test_home_goes_to_title(t) -> void:
	var room := await _make(t)
	room.get_node("Finish/HomeButton").pressed.emit()
	t.eq(_requests.back(), "res://scenes/title.tscn", "home")
	room.free()


func test_background_covers_tall_screens(t) -> void:
	var script: GDScript = load("res://scripts/room.gd")
	t.check(absf(script.cover_scale(Vector2(1920, 1200), Vector2(1672, 941)) - 1.2752) < 0.001, "16:10")
	t.check(absf(script.cover_scale(Vector2(1920, 1080), Vector2(1672, 941)) - 1.1483) < 0.001, "16:9")
