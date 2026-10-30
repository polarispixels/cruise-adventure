extends RefCounted


func _make(t) -> Node2D:
	var card: Node2D = load("res://scenes/card.tscn").instantiate()
	card.kid = load("res://data/becca.tres")
	t.tree.root.add_child(card)
	return card


func test_stamp_places_check_on_box(t) -> void:
	var card := _make(t)
	card.stamp(2)
	t.eq(card.stamped_count(), 1, "one check")
	var check: Node2D = card.get_node("Checks").get_child(0)
	t.eq(check.position, card.CHECKBOX_CENTERS[2], "on the third box")
	card.free()


func test_highlight_moves_glow(t) -> void:
	var card := _make(t)
	var glow: Node2D = card.get_node("Glow")
	card.highlight(1)
	t.check(glow.visible, "glow shown")
	t.eq(glow.position, card.ICON_CENTERS[1], "on the second icon")
	card.highlight(-1)
	t.check(not glow.visible, "glow hidden")
	card.free()


func test_clear_removes_checks(t) -> void:
	var card := _make(t)
	for i in 4:
		card.stamp(i)
	t.eq(card.stamped_count(), 4, "four checks")
	card.clear()
	t.eq(card.stamped_count(), 0, "cleared")
	card.free()


func test_row_rect_covers_icons_and_boxes(t) -> void:
	var card := _make(t)
	for row in 4:
		var r: Rect2 = card.row_rect(row)
		t.check(r.has_point(Vector2(201, card.ICON_YS[row])), "icon in row %d" % row)
		t.check(r.has_point(Vector2(999, card.CHECKBOX_YS[row])), "box in row %d" % row)
	t.check(not card.row_rect(0).intersects(card.row_rect(1)), "rows don't overlap")
	card.free()


func test_stamp_with_row(t) -> void:
	var card := _make(t)
	card.stamp(1, 2)
	var check: Node2D = card.get_node("Checks").get_child(0)
	t.eq(check.position, Vector2(467, 1160), "row 2 box 1")
	card.free()


func test_highlight_with_row(t) -> void:
	var card := _make(t)
	card.highlight(3, 3)
	t.eq(card.get_node("Glow").position, Vector2(999, 1330), "row 3 icon 3")
	card.free()


func test_highlight_row_stretches_glow_over_row(t) -> void:
	var card := _make(t)
	var glow: Sprite2D = card.get_node("Glow")
	card.highlight_row(2)
	t.check(glow.visible, "shown")
	var r: Rect2 = card.row_rect(2)
	t.eq(glow.position, r.get_center(), "centered on row")
	var covered := glow.texture.get_size() * glow.scale
	t.check(covered.x >= r.size.x - 1.0 and covered.y >= r.size.y - 1.0, "covers row: %s vs %s" % [covered, r.size])
	card.highlight_row(-1)
	t.check(not glow.visible, "hidden")
	card.free()


func test_stamp_row_is_big_and_separate(t) -> void:
	var card := _make(t)
	card.stamp(0)
	card.stamp_row(1)
	t.eq(card.stamped_count(), 1, "item checks unchanged")
	var big: Sprite2D = card.get_node("RowChecks").get_child(0)
	t.eq(big.position, card.row_rect(1).get_center(), "centered on row")
	await t.tree.create_timer(0.4).timeout
	t.check(big.texture.get_size().y * big.scale.y >= card.row_rect(1).size.y * 0.8, "about row height")
	card.free()


func test_clear_removes_row_checks_too(t) -> void:
	var card := _make(t)
	card.stamp_row(0)
	card.stamp_row(1)
	card.highlight_row(2)
	card.clear()
	t.eq(card.get_node("RowChecks").get_child_count(), 0, "row checks gone")
	t.check(not card.get_node("Glow").visible, "glow gone")
	card.free()
