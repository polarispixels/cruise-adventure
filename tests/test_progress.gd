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


func test_chapters_done_by_id(t) -> void:
	var p := _progress(t)
	t.check(not p.chapter_done("jack", "flight"), "not yet")
	p.mark_chapter_done("jack", "flight")
	p.mark_chapter_done("jack", "flight")
	t.check(p.chapter_done("jack", "flight"), "done")
	t.check(not p.chapter_done("becca", "flight"), "only jack")
	t.eq(p.chapters_done("jack"), ["flight"] as Array[String], "once")
	p.load_file()
	t.check(p.chapter_done("jack", "flight"), "saved")
	_restore(t)


func test_row_chapters_follow_the_card(t) -> void:
	var p := _progress(t)
	p.mark_done("becca", 0)
	t.check(p.chapter_done("becca", "routine"), "row 1 is chapter 2")
	p.mark_done("becca", 1)
	p.mark_done("becca", 2)
	t.check(not p.chapter_done("becca", "your-turn"), "rows 2-4 are chapter 3")
	p.mark_done("becca", 3)
	t.check(p.chapter_done("becca", "your-turn"), "the whole card")
	_restore(t)


func test_old_flags_are_chapters(t) -> void:
	var p := _progress(t)
	p.mark_car_done("jack")
	t.check(p.chapter_done("jack", "car"), "the car is chapter 'car'")
	p.mark_chapter_done("jack", "airport")
	t.check(p.airport_done("jack"), "and the airport reads back")
	p.mark_chapter_done("becca", "mission")
	t.check(p.intro_seen("becca"), "the intro is chapter 'mission'")
	_restore(t)


func test_v05_save_migrates(t) -> void:
	var p := _progress(t)
	var file := FileAccess.open(TMP, FileAccess.WRITE)
	file.store_string('{"jack": {"levels_done": [0,1,2,3], "intro_seen": true, "car_done": true, "airport_done": false}, "becca": {"levels_done": [0], "intro_seen": true}}')
	file.close()
	p.load_file()
	t.eq(p.levels_done("jack"), [0, 1, 2, 3] as Array[int], "rows kept")
	t.check(p.intro_seen("jack"), "intro kept")
	t.check(p.car_done("jack") and p.chapter_done("jack", "car"), "the car counts as done")
	t.check(not p.airport_done("jack") and not p.chapter_done("jack", "airport"), "the airport doesn't")
	t.check(p.chapter_done("jack", "your-turn"), "the card counts as done")
	t.eq(p.levels_done("becca"), [0] as Array[int], "becca's row kept")
	t.check(not p.car_done("becca"), "becca's car not done")
	p.mark_chapter_done("jack", "airport")
	p.load_file()
	t.check(p.car_done("jack") and p.airport_done("jack"), "migrated save writes and reads back")
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(TMP))
	t.check(not (saved["jack"] as Dictionary).has("car_done"), "old flags folded in")
	_restore(t)
