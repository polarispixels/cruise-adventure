extends RefCounted


func _kid_maze(kid_id: String, seed_value: int) -> MazeModel:
	var kid: KidProfile = load("res://data/%s.tres" % kid_id)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return MazeModel.generate(kid.maze_size, kid.maze_braid, kid.maze_loops, kid.maze_max_turns, kid.maze_gates, rng)


func _open_edges(m: MazeModel) -> int:
	var n := 0
	for y in m.size.y:
		for x in m.size.x:
			var c := Vector2i(x, y)
			if x + 1 < m.size.x and m.open(c, c + Vector2i.RIGHT):
				n += 1
			if y + 1 < m.size.y and m.open(c, c + Vector2i.DOWN):
				n += 1
	return n


func _rules(t, m: MazeModel, kid_id: String, label: String) -> bool:
	var kid: KidProfile = load("res://data/%s.tres" % kid_id)
	var ok := true
	ok = ok and m.size == kid.maze_size
	ok = ok and m.start.x == 0
	ok = ok and m.gates.size() == kid.maze_gates
	var rows := {}
	for g in m.gates:
		ok = ok and g.x == m.size.x - 1
		rows[g.y] = true
	ok = ok and rows.size() == m.gates.size()
	ok = ok and m.correct >= 0 and m.correct < m.gates.size()
	for y in m.size.y:
		for x in m.size.x:
			ok = ok and not m.path(m.start, Vector2i(x, y)).is_empty()
	if kid.maze_max_turns > 0:
		ok = ok and MazeModel.turns(m.path(m.start, m.gates[m.correct])) <= kid.maze_max_turns
	if not ok:
		t.check(false, "%s breaks a rule" % label)
	return ok


func test_every_cell_reachable(t) -> void:
	var m := _kid_maze("jack", 1)
	for y in m.size.y:
		for x in m.size.x:
			t.check(not m.path(m.start, Vector2i(x, y)).is_empty(), "reach %s" % Vector2i(x, y))


func test_gates_on_the_right_edge_distinct_rows(t) -> void:
	var m := _kid_maze("jack", 2)
	t.eq(m.gates.size(), 3, "three gates")
	var rows := {}
	for g in m.gates:
		t.eq(g.x, 9, "right column")
		rows[g.y] = true
	t.eq(rows.size(), 3, "distinct rows")


func test_start_in_the_left_column(t) -> void:
	t.eq(_kid_maze("becca", 3).start.x, 0, "left column")


func test_becca_path_has_at_most_four_turns(t) -> void:
	for s in 20:
		var m := _kid_maze("becca", s)
		t.check(MazeModel.turns(m.path(m.start, m.gates[m.correct])) <= 4, "seed %d" % s)


func test_jack_has_dead_ends_and_loops(t) -> void:
	var m := _kid_maze("jack", 4)
	t.check(m.dead_ends() >= 3, "several dead ends: %d" % m.dead_ends())
	t.check(_open_edges(m) > 10 * 5 - 1, "loops: more passages than a tree")


func test_turns_counts_direction_changes(t) -> void:
	var path: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(2, 1), Vector2i(3, 1)]
	t.eq(MazeModel.turns(path), 2, "right, down, right")


func test_many_seeds_meet_the_rules(t) -> void:
	var bad := 0
	for kid_id in ["jack", "becca"]:
		for s in 200:
			if not _rules(t, _kid_maze(kid_id, s), kid_id, "%s seed %d" % [kid_id, s]):
				bad += 1
	t.eq(bad, 0, "every maze follows the rules")


func test_same_seed_same_maze(t) -> void:
	var a := _kid_maze("jack", 42)
	var b := _kid_maze("jack", 42)
	t.eq([a.start, a.gates, a.correct, _open_edges(a)], [b.start, b.gates, b.correct, _open_edges(b)], "repeatable")
	var c := _kid_maze("jack", 43)
	t.check(a.start != c.start or a.gates != c.gates or a.correct != c.correct or a.dead_ends() != c.dead_ends(), "another seed, another maze")


func test_walls_block_and_neighbors_only(t) -> void:
	var m := _kid_maze("becca", 5)
	t.check(not m.open(Vector2i(0, 0), Vector2i(2, 0)), "not neighbors")
	t.check(not m.open(Vector2i(0, 0), Vector2i(-1, 0)), "outside")
