extends RefCounted

const TMP := "user://test_progress_unit.json"


func _progress(t) -> Node:
	var p: Node = t.tree.root.get_node("Progress")
	p.path = TMP
	p.reset()
	return p


func _restore(t) -> void:
	var p: Node = t.tree.root.get_node("Progress")
	p.reset()
	p.path = "user://progress.json"


func test_real_path_default(t) -> void:
	var p: Node = t.tree.root.get_node("Progress")
	t.eq(p.path, "user://progress.json", "default path")


func test_empty_at_start(t) -> void:
	var p := _progress(t)
	t.eq(p.levels_done("jack").size(), 0, "none done")
	t.eq(p.next_level("jack"), 0, "next is first")
	t.check(not p.intro_seen("jack"), "intro not seen")
	_restore(t)


func test_mark_done_and_next_level(t) -> void:
	var p := _progress(t)
	p.mark_done("jack", 0)
	t.eq(p.next_level("jack"), 1, "next after 0")
	p.mark_done("jack", 2)
	t.eq(p.next_level("jack"), 1, "lowest not done")
	t.eq(p.levels_done("becca").size(), 0, "other kid untouched")
	p.mark_done("jack", 1)
	p.mark_done("jack", 3)
	t.eq(p.next_level("jack"), 4, "all done")
	_restore(t)


func test_mark_done_idempotent(t) -> void:
	var p := _progress(t)
	p.mark_done("becca", 1)
	p.mark_done("becca", 1)
	t.eq(p.levels_done("becca"), [1] as Array[int], "once")
	_restore(t)


func test_roundtrip_through_file(t) -> void:
	var p := _progress(t)
	p.mark_done("becca", 0)
	p.mark_done("becca", 2)
	p.mark_intro_seen("becca")
	p.load_file()
	t.eq(p.levels_done("becca"), [0, 2] as Array[int], "levels survive reload")
	t.check(p.intro_seen("becca"), "intro survives")
	t.check(not p.intro_seen("jack"), "jack intro separate")
	t.check(FileAccess.file_exists(TMP), "file written")
	_restore(t)


func test_corrupt_file_is_empty(t) -> void:
	var p := _progress(t)
	var f := FileAccess.open(TMP, FileAccess.WRITE)
	f.store_string("{not json at all")
	f.close()
	p.load_file()
	t.eq(p.levels_done("jack").size(), 0, "empty")
	var g := FileAccess.open(TMP, FileAccess.WRITE)
	g.store_string("[1,2,3]")
	g.close()
	p.load_file()
	t.eq(p.next_level("jack"), 0, "wrong shape is empty")
	_restore(t)


func test_missing_file_is_empty(t) -> void:
	var p := _progress(t)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP))
	p.load_file()
	t.eq(p.next_level("becca"), 0, "empty")
	_restore(t)


func test_reset_clears_file(t) -> void:
	var p := _progress(t)
	p.mark_done("jack", 0)
	p.mark_intro_seen("jack")
	p.reset()
	p.load_file()
	t.eq(p.levels_done("jack").size(), 0, "cleared")
	t.check(not p.intro_seen("jack"), "intro cleared")
	_restore(t)


func test_car_done_saved_and_reset(t) -> void:
	var p := _progress(t)
	t.check(not p.car_done("jack"), "not yet")
	p.mark_car_done("jack")
	t.check(p.car_done("jack"), "done")
	t.check(not p.car_done("becca"), "only jack")
	p.load_file()
	t.check(p.car_done("jack"), "saved")
	t.eq(p.next_level("jack"), 0, "rows untouched")
	p.reset()
	t.check(not p.car_done("jack"), "reset clears it")
	_restore(t)


func test_airport_done_saved_and_reset(t) -> void:
	var p := _progress(t)
	t.check(not p.airport_done("becca"), "not yet")
	p.mark_airport_done("becca")
	p.load_file()
	t.check(p.airport_done("becca"), "saved")
	t.check(not p.airport_done("jack"), "only becca")
	p.reset()
	t.check(not p.airport_done("becca"), "reset clears it")
	_restore(t)
