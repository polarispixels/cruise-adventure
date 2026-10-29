# Drives the level through real input events (touch and mouse), the same
# path a finger on the tablet or a mouse in the browser takes.
extends RefCounted

const HOME := Vector2(480, 600)

# World -> screen transform. The headless window is tiny, so stretch and the
# camera both matter; compute it per level instance.
var _to_screen := Transform2D.IDENTITY


func _make(t) -> Node2D:
	var main: Node2D = load("res://scenes/main.tscn").instantiate()
	t.tree.root.add_child(main)
	await t.tree.process_frame
	_to_screen = t.tree.root.get_final_transform() * main.get_canvas_transform()
	return main


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


func _drag_shirt_by_touch(t, to: Vector2) -> void:
	await _touch(t, true, HOME)
	await _touch_drag(t, (HOME + to) / 2)
	await _touch_drag(t, to)
	await _touch(t, false, to)


func test_touch_on_floor_does_not_grab(t) -> void:
	var main := await _make(t)
	var shirt: Draggable = main.get_node("Shirt")
	await _touch(t, true, Vector2(100, 1000))
	t.eq(shirt.is_dragging, false, "floor tap grabs nothing")
	await _touch(t, false, Vector2(100, 1000))
	t.eq(shirt.global_position, HOME, "shirt unmoved")
	main.queue_free()


func test_touch_drag_into_suitcase_places_shirt(t) -> void:
	var main := await _make(t)
	await _drag_shirt_by_touch(t, Vector2(1400, 660))
	t.eq(main.get_node("Shirt").is_placed, true, "placed by finger")
	main.queue_free()


func test_touch_miss_returns_home(t) -> void:
	var main := await _make(t)
	var shirt: Draggable = main.get_node("Shirt")
	await _drag_shirt_by_touch(t, Vector2(800, 200))
	t.eq(shirt.is_placed, false, "not placed")
	await t.tree.create_timer(0.5).timeout
	t.check(shirt.global_position.distance_to(HOME) < 1.0, "back home, at %s" % shirt.global_position)
	main.queue_free()


func test_replay_tap_resets(t) -> void:
	var main := await _make(t)
	var shirt: Draggable = main.get_node("Shirt")
	await _drag_shirt_by_touch(t, Vector2(1400, 660))
	await t.tree.create_timer(0.8).timeout
	await _touch(t, true, Vector2(1400, 940))
	await _touch(t, false, Vector2(1400, 940))
	t.eq(shirt.is_placed, false, "reset by replay tap")
	t.eq(shirt.global_position, HOME, "shirt home")
	t.eq(main.get_node("ReplayButton").visible, false, "replay hidden")
	main.queue_free()


func test_lost_release_does_not_teleport(t) -> void:
	# A press whose release never arrives (focus lost mid-drag), then a click on
	# the suitcase: the shirt must not jump there and count as placed.
	var main := await _make(t)
	var shirt: Draggable = main.get_node("Shirt")
	await _click(t, true, HOME)
	await _click(t, true, Vector2(1400, 700))
	await _click(t, false, Vector2(1400, 700))
	t.eq(shirt.is_placed, false, "stray click does not place")
	await t.tree.create_timer(0.5).timeout
	t.check(shirt.global_position.distance_to(HOME) < 1.0, "shirt home, at %s" % shirt.global_position)
	main.queue_free()
