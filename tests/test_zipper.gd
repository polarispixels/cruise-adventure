extends RefCounted

const START := Vector2(100, 500)
const END := Vector2(900, 500)


func _make(t) -> Zipper:
	var z: Zipper = load("res://scenes/zipper.tscn").instantiate()
	z.start = START
	z.end = END
	t.tree.root.add_child(z)
	return z


func test_grab_only_near_pull(t) -> void:
	var z := _make(t)
	t.check(not z.begin(Vector2(600, 900)), "far away misses")
	t.check(z.begin(START + Vector2(20, 10)), "at the pull grabs")
	z.free()


func test_drag_projects_onto_line(t) -> void:
	var z := _make(t)
	z.begin(START)
	z.drag(START.lerp(END, 0.5) + Vector2(0, -200))
	t.check(absf(z.progress - 0.5) < 0.02, "halfway, got %s" % z.progress)
	t.check(z.get_node("Pull").position.distance_to(START.lerp(END, 0.5)) < 1.0, "pull on the line")
	z.free()


func test_zipped_emits_once_at_end(t) -> void:
	var z := _make(t)
	var count := [0]
	z.zipped.connect(func(): count[0] += 1)
	z.begin(START)
	z.drag(END + Vector2(100, 0))
	z.drag(START)
	z.drag(END)
	z.release()
	t.eq(count[0], 1, "zipped once")
	t.eq(z.progress, 1.0, "stays closed")
	t.check(not z.begin(END), "done zippers can't be grabbed")
	z.free()


func test_partial_does_not_zip(t) -> void:
	var z := _make(t)
	var count := [0]
	z.zipped.connect(func(): count[0] += 1)
	z.begin(START)
	z.drag(START.lerp(END, 0.6))
	z.release()
	t.eq(count[0], 0, "not zipped")
	t.check(absf(z.progress - 0.6) < 0.01, "stays at 0.6")
	z.free()


func test_reset_reopens(t) -> void:
	var z := _make(t)
	z.begin(START)
	z.drag(END)
	z.reset()
	t.eq(z.progress, 0.0, "open again")
	t.check(z.begin(START), "grabbable again")
	z.free()
