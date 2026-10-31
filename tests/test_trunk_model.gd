extends RefCounted


func _model() -> TrunkModel:
	return TrunkModel.from_file()


func _fill_reference(m: TrunkModel) -> void:
	var ref := m.reference_solution()
	for id in ref:
		m.set_turned(id, ref[id]["turned"])
		m.place(id, ref[id]["cell"])


func test_sizes_turn(t) -> void:
	var m := _model()
	t.eq(m.size_of("mommy-yellow", false), Vector2i(5, 2), "standing")
	t.eq(m.size_of("mommy-yellow", true), Vector2i(2, 5), "turned")


func test_wheel_wells_and_edges_block(t) -> void:
	var m := _model()
	t.check(not m.can_place("mommy-purse", Vector2i(0, 4)), "left wheel well")
	t.check(not m.can_place("mommy-purse", Vector2i(6, 4)), "right wheel well")
	t.check(not m.can_place("mommy-yellow", Vector2i(3, 0)), "sticks out the side")
	t.check(not m.can_place("mommy-purse", Vector2i(-1, 0)), "outside left")
	t.check(m.can_place("mommy-purse", Vector2i(5, 4)), "next to a wheel well is fine")


func test_bags_cannot_overlap(t) -> void:
	var m := _model()
	t.check(m.place("mommy-yellow", Vector2i(0, 0)), "first bag")
	t.check(not m.can_place("mommy-purse", Vector2i(4, 1)), "on top of the yellow bag")
	t.check(not m.place("mommy-purse", Vector2i(4, 1)), "place refuses too")
	t.check(m.can_place("mommy-yellow", Vector2i(0, 1)), "a bag doesn't block itself")


func test_reference_solution_fills_the_trunk(t) -> void:
	var m := _model()
	_fill_reference(m)
	t.eq(m.placed_ids().size(), 8, "all placed")
	t.check(m.is_full(), "full")


func test_trunk_needs_a_turn(t) -> void:
	var m := _model()
	t.eq(m.solve(false), {}, "no full trunk without turning")
	t.eq(m.solve(true).size(), 8, "full trunk with turning")


func test_solve_keeps_placed_bags(t) -> void:
	var m := _model()
	m.place("mommy-yellow", Vector2i(0, 0))
	var sol := m.solve()
	t.eq(sol.size(), 8, "solved")
	t.eq(sol["mommy-yellow"]["cell"], Vector2i(0, 0), "yellow stays")
	t.eq(m.cell_of("daddy-gray"), Vector2i(-1, -1), "solving doesn't move bags")


func test_hint_prefers_a_bag_that_must_turn(t) -> void:
	var m := _model()
	var hint := m.hint()
	t.eq(hint.get("kind", ""), "next", "kind")
	t.check(hint.get("turned", false) != m.is_turned(hint.get("id", "")), "the hinted bag needs turning: " + str(hint))


func test_hint_flags_a_dead_end(t) -> void:
	var m := _model()
	m.place("mommy-purse", Vector2i(0, 0))
	t.eq(m.hint(), {"kind": "wrong", "id": "mommy-purse"}, "the purse blocks a full trunk")


func test_turned_state_survives_remove(t) -> void:
	var m := _model()
	m.set_turned("daddy-gray", true)
	m.place("daddy-gray", Vector2i(0, 2))
	m.remove("daddy-gray")
	t.check(m.is_turned("daddy-gray"), "still turned")
	t.eq(m.cell_of("daddy-gray"), Vector2i(-1, -1), "not placed")


func test_hint_empty_when_full(t) -> void:
	var m := _model()
	_fill_reference(m)
	t.eq(m.hint(), {}, "nothing to hint")


func test_hint_never_picks_a_locked_bag(t) -> void:
	var m := _model()
	m.place("mommy-yellow", Vector2i(0, 0))
	m.set_turned("daddy-gray", true)
	m.place("daddy-gray", Vector2i(0, 2))
	m.place("jack-suitcase", Vector2i(5, 0))
	m.place("becca-suitcase", Vector2i(4, 2))
	m.place("jack-backpack", Vector2i(3, 2))
	m.place("becca-backpack", Vector2i(6, 2))
	var hint := m.hint(PackedStringArray(["mommy-yellow", "daddy-gray"]))
	t.eq(hint.get("kind", ""), "wrong", "a dead end")
	t.check(not ["mommy-yellow", "daddy-gray"].has(hint.get("id", "")), "never a bag she can't move: " + str(hint))
