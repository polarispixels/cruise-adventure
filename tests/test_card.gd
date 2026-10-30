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
