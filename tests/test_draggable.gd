extends RefCounted

const ZONE := Rect2(1020, 430, 760, 500)
const SNAP := Vector2(1400, 660)
const HOME := Vector2(480, 600)


func _make(t) -> Node2D:
	var item: Node2D = load("res://scenes/item.tscn").instantiate()
	item.texture = load("res://assets/props/jack/shirt-card.png")
	item.position = HOME
	item.drop_zone = ZONE
	item.snap_point = SNAP
	t.tree.root.add_child(item)
	await t.tree.process_frame
	return item


func _wait(t, seconds: float) -> void:
	await t.tree.create_timer(seconds).timeout


func _drop_in_suitcase(item: Node2D) -> bool:
	item.begin_drag(HOME)
	item.drag_to(Vector2(1400, 650))
	return item.end_drag(Vector2(1400, 650))


func test_drop_zone_margin(t) -> void:
	var script: GDScript = load("res://scripts/draggable.gd")
	t.check(script.in_drop_zone(Vector2(1000, 600), ZONE, 80.0), "just left of suitcase counts")
	t.check(not script.in_drop_zone(Vector2(930, 600), ZONE, 80.0), "beyond the margin misses")
	t.check(script.in_drop_zone(Vector2(1400, 680), ZONE, 80.0), "center counts")


func test_begin_drag_outside_does_nothing(t) -> void:
	var item := await _make(t)
	t.eq(item.begin_drag(Vector2(100, 100)), false, "begin_drag result")
	t.eq(item.is_dragging, false, "is_dragging")
	t.eq(item.position, HOME, "position")
	item.queue_free()


func test_drag_follows_pointer(t) -> void:
	var item := await _make(t)
	t.eq(item.begin_drag(Vector2(490, 610)), true, "begin_drag result")
	item.drag_to(Vector2(800, 400))
	t.eq(item.position, Vector2(790, 390), "keeps grab offset")
	t.eq(item.scale, Vector2.ONE * item.LIFT_SCALE, "lifted")
	item.queue_free()


func test_drop_in_suitcase_snaps(t) -> void:
	var item := await _make(t)
	var count := [0]
	item.placed.connect(func(_i): count[0] += 1)
	t.eq(_drop_in_suitcase(item), true, "end_drag result")
	t.eq(count[0], 1, "placed emitted once")
	await _wait(t, item.SNAP_TIME + 0.1)
	t.check(item.position.distance_to(SNAP) < 1.0, "snapped to slot, at %s" % item.position)
	t.eq(item.scale, Vector2.ONE, "scale restored")
	item.queue_free()


func test_missed_drop_returns_home_quickly(t) -> void:
	var item := await _make(t)
	item.begin_drag(HOME)
	item.drag_to(Vector2(900, 200))
	t.eq(item.end_drag(Vector2(900, 200)), false, "end_drag result")
	await _wait(t, 0.5)
	t.check(item.position.distance_to(HOME) < 1.0, "back home within 0.5 s, at %s" % item.position)
	item.queue_free()


func test_cannot_drag_after_placed(t) -> void:
	var item := await _make(t)
	_drop_in_suitcase(item)
	await _wait(t, item.SNAP_TIME + 0.1)
	t.eq(item.begin_drag(SNAP), false, "placed item is locked")
	item.queue_free()


func test_reset_restores(t) -> void:
	var item := await _make(t)
	_drop_in_suitcase(item)
	await _wait(t, item.SNAP_TIME + 0.1)
	item.reset()
	t.eq(item.position, HOME, "home")
	t.eq(item.is_placed, false, "not placed")
	t.eq(item.begin_drag(HOME), true, "draggable again")
	item.queue_free()


func test_rejected_drop_returns_home(t) -> void:
	var item: Node2D = await _make(t)
	item.accept_drop = false
	var placed := [0]
	var rejected := [0]
	item.placed.connect(func(_i): placed[0] += 1)
	item.rejected.connect(func(_i): rejected[0] += 1)
	t.eq(_drop_in_suitcase(item), false, "drop refused")
	t.eq(rejected[0], 1, "rejected once")
	t.eq(placed[0], 0, "never placed")
	t.eq(item.is_placed, false, "not placed")
	await _wait(t, 0.8)
	t.check(item.global_position.distance_to(HOME) < 1.0, "home, at %s" % item.global_position)
	t.eq(item.rotation, 0.0, "wiggle settled")
	item.free()


func test_home_scale_respected(t) -> void:
	var item: Node2D = await _make(t)
	item.home_scale = 0.5
	item.begin_drag(HOME)
	t.eq(item.scale, Vector2.ONE * 0.5 * item.LIFT_SCALE, "lifted from rest scale")
	item.end_drag(Vector2(100, 1000))
	await _wait(t, 0.6)
	t.eq(item.scale, Vector2.ONE * 0.5, "back to rest scale")
	item.free()


func test_tap_places_item(t) -> void:
	var item: Node2D = await _make(t)
	var placed := [0]
	item.placed.connect(func(_i): placed[0] += 1)
	item.begin_drag(HOME)
	t.eq(item.end_drag(HOME + Vector2(5, 5)), true, "a tap places it")
	t.eq(placed[0], 1, "placed once")
	await _wait(t, 0.5)
	t.check(item.global_position.distance_to(SNAP) < 1.0, "glided to the slot, at %s" % item.global_position)
	item.free()


func test_tap_on_wrong_item_wiggles(t) -> void:
	var item: Node2D = await _make(t)
	item.accept_drop = false
	var rejected := [0]
	item.rejected.connect(func(_i): rejected[0] += 1)
	item.begin_drag(HOME)
	t.eq(item.end_drag(HOME), false, "not placed")
	t.eq(rejected[0], 1, "says no")
	await _wait(t, 0.8)
	t.check(item.global_position.distance_to(HOME) < 1.0, "stays home")
	item.free()
