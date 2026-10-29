extends RefCounted

const HOME := Vector2(480, 600)


func _make(t) -> Node2D:
	var main: Node2D = load("res://scenes/main.tscn").instantiate()
	t.tree.root.add_child(main)
	await t.tree.process_frame
	return main


func _wait(t, seconds: float) -> void:
	await t.tree.create_timer(seconds).timeout


func _place_shirt(main: Node2D) -> bool:
	var shirt: Draggable = main.get_node("Shirt")
	shirt.begin_drag(shirt.global_position)
	shirt.drag_to(Vector2(1400, 660))
	return shirt.end_drag(Vector2(1400, 660))


func test_version_stamp(t) -> void:
	var main := await _make(t)
	t.eq(main.get_node("UI/VersionLabel").text, "v0.1.0", "version label")
	main.queue_free()


func test_success_sequence(t) -> void:
	var main := await _make(t)
	t.eq(_place_shirt(main), true, "drop counts")
	t.eq(main.get_node("Stars").get_child_count(), main.STAR_COUNT, "stars burst")
	t.eq(main.get_node("Chime").playing, true, "chime playing")
	await _wait(t, 1.0)
	t.eq(main.get_node("Check").visible, true, "check shown")
	t.eq(main.get_node("ReplayButton").visible, true, "replay shown")
	t.eq(main.get_node("Slot").visible, false, "slot hidden")
	t.eq(main.get_node("Stars").get_child_count(), 0, "stars cleaned up")
	main.queue_free()


func test_reset_during_celebration(t) -> void:
	var main := await _make(t)
	_place_shirt(main)
	await _wait(t, 0.1)
	main.reset_level()
	await _wait(t, 1.0)
	var shirt: Draggable = main.get_node("Shirt")
	t.check(shirt.global_position.distance_to(HOME) < 1.0, "shirt home, at %s" % shirt.global_position)
	t.eq(shirt.is_placed, false, "shirt not placed")
	t.eq(main.get_node("Check").visible, false, "check hidden")
	t.eq(main.get_node("ReplayButton").visible, false, "replay hidden")
	t.eq(main.get_node("Slot").visible, true, "slot shown")
	t.eq(main.get_node("Stars").get_child_count(), 0, "no stars")
	main.queue_free()


func test_replay_repeatable(t) -> void:
	var main := await _make(t)
	var count := [0]
	main.get_node("Shirt").placed.connect(func(_i): count[0] += 1)
	for i in 3:
		t.eq(_place_shirt(main), true, "round %d drop" % i)
		await _wait(t, 0.8)
		main.get_node("ReplayButton").pressed.emit()
		await t.tree.process_frame
	t.eq(count[0], 3, "placed every round")
	main.queue_free()


func test_background_covers_wide_and_tall(t) -> void:
	var main := await _make(t)
	var size: Vector2 = main.get_node("Background").texture.get_size()
	t.check(size.x >= 2400 and size.y >= 1440, "background %s covers 20:9 and 4:3" % size)
	main.queue_free()


func test_drop_zone_matches_suitcase(t) -> void:
	var main := await _make(t)
	t.eq(main.get_node("Shirt").drop_zone, Rect2(1020, 430, 760, 500), "drop zone")
	t.eq(main.get_node("Shirt").snap_point, Vector2(1400, 660), "snap point")
	main.queue_free()
