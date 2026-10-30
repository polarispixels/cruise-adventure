extends RefCounted

var _to_screen := Transform2D.IDENTITY
var _found: Array[String] = []


func _make(t, kid_id: String, item := "shirt") -> DrawerView:
	var view: DrawerView = load("res://scenes/drawer_view.tscn").instantiate()
	t.tree.root.add_child(view)
	_found.clear()
	view.found.connect(func(i): _found.append(i))
	var kid: KidProfile = load("res://data/%s.tres" % kid_id)
	var helper: KidProfile = load("res://data/%s.tres" % ("jack" if kid_id == "becca" else "becca"))
	view.open(kid, helper, item, 1)
	await t.tree.process_frame
	_to_screen = t.tree.root.get_final_transform() * view.get_canvas_transform()
	return view


func _drop(item: Draggable, to: Vector2) -> bool:
	item.begin_drag(item.global_position)
	item.drag_to(to)
	return item.end_drag(to)


func _wrong(view: DrawerView) -> Draggable:
	for c in view.choices():
		if c != view.correct_choice():
			return c
	return null


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


func test_becca_gets_two_choices(t) -> void:
	var view := await _make(t, "becca")
	t.eq(view.choices().size(), 2, "two choices")
	var accepting := view.choices().filter(func(c): return c.accept_drop)
	t.eq(accepting.size(), 1, "exactly one accepts")
	t.eq(view.correct_choice().texture, load("res://data/becca.tres").prop("shirt-card"), "the card shirt")
	view.free()


func test_jack_gets_four_choices(t) -> void:
	var view := await _make(t, "jack")
	t.eq(view.choices().size(), 4, "four choices")
	var textures := {}
	for c in view.choices():
		textures[c.texture] = true
	t.eq(textures.size(), 4, "all different")
	view.free()


func test_correct_match_emits_found(t) -> void:
	var view := await _make(t, "becca")
	t.check(_drop(view.correct_choice(), view.TARGET_CENTER), "drop accepted")
	await t.tree.create_timer(0.5).timeout
	t.eq(_found, ["shirt"] as Array[String], "found once")
	view.free()


func test_wrong_match_wiggles_back(t) -> void:
	var view := await _make(t, "jack")
	var wrong := _wrong(view)
	var home := wrong.global_position
	t.check(not _drop(wrong, view.TARGET_CENTER), "drop refused")
	await t.tree.create_timer(0.8).timeout
	t.eq(_found.size(), 0, "nothing found")
	t.check(wrong.global_position.distance_to(home) < 1.0, "back home")
	t.eq(view.wrong_count, 1, "one miss")
	view.free()


func test_helper_points_after_two_misses(t) -> void:
	var view := await _make(t, "becca")
	var helper: Character = view.get_node("Helper")
	_drop(_wrong(view), view.TARGET_CENTER)
	t.check(helper.pose != "point", "no point after one miss")
	await t.tree.create_timer(0.8).timeout
	_drop(_wrong(view), view.TARGET_CENTER)
	t.eq(helper.pose, "point", "points after two")
	view.free()


func test_drop_outside_returns_home(t) -> void:
	var view := await _make(t, "becca")
	var item := view.correct_choice()
	var home := item.global_position
	t.check(not _drop(item, Vector2(100, 1000)), "not placed")
	await t.tree.create_timer(0.5).timeout
	t.eq(_found.size(), 0, "nothing found")
	t.check(item.global_position.distance_to(home) < 1.0, "home")
	t.eq(view.wrong_count, 0, "not a miss")
	view.free()


func test_touch_match(t) -> void:
	var view := await _make(t, "jack")
	var item := view.correct_choice()
	await _touch(t, true, item.global_position)
	await _touch_drag(t, item.global_position.lerp(view.TARGET_CENTER, 0.5))
	await _touch_drag(t, view.TARGET_CENTER)
	await _touch(t, false, view.TARGET_CENTER)
	await t.tree.create_timer(0.5).timeout
	t.eq(_found, ["shirt"] as Array[String], "found by touch")
	view.free()
