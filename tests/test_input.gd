# Drives the drawer game and the room through real input events (touch and
# mouse), the same path a finger on the tablet or a mouse in the browser takes.
extends RefCounted

# World -> screen transform. The headless window is tiny, so stretch and the
# camera both matter; compute it per scene instance.
var _to_screen := Transform2D.IDENTITY


func _make(t) -> DrawerView:
	var view: DrawerView = load("res://scenes/drawer_view.tscn").instantiate()
	t.tree.root.add_child(view)
	view.open(load("res://data/jack.tres"), load("res://data/becca.tres"), "shirt", 3)
	await t.tree.process_frame
	_to_screen = t.tree.root.get_final_transform() * view.get_canvas_transform()
	return view


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


func _click(t, pressed: bool, world: Vector2) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	e.position = _to_screen * world
	e.global_position = e.position
	await _send(t, e)


func _drag_by_touch(t, from: Vector2, to: Vector2) -> void:
	await _touch(t, true, from)
	await _touch_drag(t, (from + to) / 2)
	await _touch_drag(t, to)
	await _touch(t, false, to)


func test_touch_on_floor_does_not_grab(t) -> void:
	var view := await _make(t)
	await _touch(t, true, Vector2(100, 1000))
	t.check(not view.is_dragging(), "floor tap grabs nothing")
	await _touch(t, false, Vector2(100, 1000))
	for c in view.choices():
		t.eq(c.global_position, c.home_position, "item unmoved")
	view.free()


func test_touch_drag_onto_target_places(t) -> void:
	var view := await _make(t)
	var item := view.correct_choice()
	await _drag_by_touch(t, item.global_position, view.TARGET_CENTER)
	t.eq(item.is_placed, true, "placed by finger")
	view.free()


func test_touch_miss_returns_home(t) -> void:
	var view := await _make(t)
	var item := view.correct_choice()
	var home := item.global_position
	await _drag_by_touch(t, home, Vector2(200, 300))
	t.eq(item.is_placed, false, "not placed")
	await t.tree.create_timer(0.5).timeout
	t.check(item.global_position.distance_to(home) < 1.0, "back home, at %s" % item.global_position)
	view.free()


func test_lost_release_does_not_teleport(t) -> void:
	# A press whose release never arrives (focus lost mid-drag), then a click on
	# the target: the item must not jump there and count as placed.
	var view := await _make(t)
	var item := view.correct_choice()
	var home := item.global_position
	await _click(t, true, home)
	await _click(t, true, view.TARGET_CENTER)
	await _click(t, false, view.TARGET_CENTER)
	t.eq(item.is_placed, false, "stray click does not place")
	await t.tree.create_timer(0.5).timeout
	t.check(item.global_position.distance_to(home) < 1.0, "home, at %s" % item.global_position)
	view.free()
