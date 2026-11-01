# Chapters 9-14 played through the registry player from the journey map, for both kids,
# with real touches (tests/play_kit.gd drives engine scenes). One chapter per test.
extends RefCounted

const Kit := preload("res://tests/play_kit.gd")
const EngineKit := preload("res://tests/engine_kit.gd")
## The part of the 1672x941 stage a 16:10 tablet shows, in stage pixels.
const SAFE := Rect2(100, 0, 1472, 941)


func _chapter(id: String) -> Dictionary:
	var parsed: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/chapters.json"))
	for c: Dictionary in parsed["chapters"]:
		if c["id"] == id:
			return c
	return {}


## "chapter/segment" ids of a chapter, minus `once` clips on a replay.
func _expected(id: String, replay := false) -> Array[String]:
	var out: Array[String] = []
	for seg: Dictionary in _chapter(id)["segments"]:
		if replay and seg.get("once", false):
			continue
		out.append("%s/%s" % [id, seg["id"]])
	return out


## The chapter after `id` that has segments, or "".
func _next_built(id: String) -> String:
	var parsed: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/chapters.json"))
	var found := false
	for c: Dictionary in parsed["chapters"]:
		if found and not c.get("dropped", false) and not (c["segments"] as Array).is_empty():
			return c["id"]
		if c["id"] == id:
			found = true
	return ""


## A chapter that isn't on this branch yet (no segments) has nothing to play.
func _built(id: String) -> bool:
	return not (_chapter(id).get("segments", []) as Array).is_empty()


func _play_from_map(t, kid_id: String, id: String) -> void:
	if not _built(id):
		return
	var kit := Kit.new()
	kit.begin(t)
	kit.progress.mark_chapter_done(kid_id, "mission")
	for level in 4:
		kit.progress.mark_done(kid_id, level)
	for c: Dictionary in kit.game.chapters():
		if c["id"] == id:
			break
		if int(c["number"]) >= 7 and not c.get("dropped", false) and not (c["segments"] as Array).is_empty():
			kit.progress.mark_chapter_done(kid_id, c["id"])
	kit.pick(kid_id)
	t.eq(kit.requests.back(), kit.game.MAP, "%s: lands on the map" % kid_id)
	var map: Node2D = await kit.make_map()
	t.eq(map.next_stop(), id, "%s: %s is the next stop" % [kid_id, id])
	var view := Rect2(Vector2.ZERO, map.get_viewport().get_visible_rect().size)
	var stop: TextureButton = map.stop_button(id)
	t.check(stop.visible and view.encloses(Rect2(stop.global_position, stop.size)), "%s: the stop is on screen" % kid_id)
	await kit.tap(map.stop_point(id))
	t.check(kit.game.playing(), "%s: tapping the stop starts the chapter" % kid_id)
	map.free()
	await kit.run()
	t.eq(kit.order(), _expected(id), "%s: segment order follows chapters.json" % kid_id)
	for e in kit.trace:
		if e["kind"] in ["clip", "still"]:
			t.check(e["mode"] in ["clip", "still", "card"], "%s: a clip segment shows something" % kid_id)
	t.check(kit.progress.chapter_done(kid_id, id), "%s: %s marked done" % [kid_id, id])
	t.eq(kit.requests.back(), kit.game.MAP, "%s: the chapter ends on the map" % kid_id)
	# The map checks the stop and offers the next one.
	map = await kit.make_map()
	t.check(map.stop_button(id).get_node_or_null("Check") != null, "%s: the stop is checked" % kid_id)
	t.eq(map.next_stop(), _next_built(id), "%s: the next stop is offered" % kid_id)
	var next := _next_built(id)
	if next != "":
		t.check(map.stop_button(next).visible, "%s: the next stop shows" % kid_id)
	# Replay: tap the checked stop. A `once` clip is skipped.
	await kit.tap(map.stop_point(id))
	map.free()
	t.check(kit.game.playing(), "%s: a finished stop replays" % kid_id)
	kit.trace.clear()
	await kit.run()
	t.eq(kit.order(), _expected(id, true), "%s: the replay skips the once-clip" % kid_id)
	t.check(kit.progress.chapter_done(kid_id, id), "%s: still done after the replay" % kid_id)
	kit.end()


func test_aboard_jack(t) -> void:
	await _play_from_map(t, "jack", "aboard")


func test_aboard_becca(t) -> void:
	await _play_from_map(t, "becca", "aboard")


func test_flight_jack(t) -> void:
	await _play_from_map(t, "jack", "flight")


func test_flight_becca(t) -> void:
	await _play_from_map(t, "becca", "flight")


func test_florida_jack(t) -> void:
	await _play_from_map(t, "jack", "florida")


func test_florida_becca(t) -> void:
	await _play_from_map(t, "becca", "florida")


func test_seaday_jack(t) -> void:
	await _play_from_map(t, "jack", "seaday")


func test_seaday_becca(t) -> void:
	await _play_from_map(t, "becca", "seaday")


# --- layout: every tappable thing on a 1920x1200 tablet and inside the 16:10 safe area ---

func _inside(t, scene: Node2D, r: Rect2, what: String) -> void:
	t.check(scene.view_rect().grow(1.0).encloses(r), "%s on screen: %s" % [what, str(r)])
	var local := Rect2(scene.stage.to_local(r.position), r.size / scene.stage.scale)
	t.check(SAFE.grow(1.0).encloses(local), "%s inside the 16:10 safe area: %s" % [what, str(local)])


func _layout(t, id: String) -> void:
	if not _built(id):
		return
	var kit := Kit.new()
	kit.begin(t)
	var ek := EngineKit.new()
	for kid_id in ["jack", "becca"]:
		for seg: Dictionary in _chapter(id)["segments"]:
			if seg["kind"] != "scene" or not str(seg["scene"]).begins_with("res://scenes/engines/"):
				continue
			var entry := seg.duplicate(true)
			entry["done_delay"] = 0.0
			entry["hint_delay"] = 600.0
			var scene: Node2D = await ek.make(t, str(seg["scene"]), entry, kid_id, Vector2i(1920, 1200))
			var tag := "%s/%s %s" % [id, seg["id"], kid_id]
			var engine := str((scene.get_script() as Script).resource_path).get_file()
			match engine:
				"match.gd":
					_inside(t, scene, scene.target_rect(), tag + " target")
					var doors: bool = scene.data.get("layout", "row") == "doors"
					var ids: Array[String] = scene.choice_ids()
					if doors:
						# A hallway scrolls: the first door shows, and the rest can be dragged in.
						_inside(t, scene, scene.choice_rect(ids[0]), tag + " first door")
					else:
						for cid in ids:
							_inside(t, scene, scene.choice_rect(cid), tag + " choice " + cid)
				"moments.gd":
					await kit.until(func(): return scene.state == "ready", 8.0)
					t.eq(scene.state, "ready", tag + " the thing arrived")
					_inside(t, scene, scene.thing_rect(), tag + " thing")
				"maze.gd":
					_inside(t, scene, scene.board_rect(), tag + " board")
				"place.gd":
					for iid: String in scene.item_ids():
						if scene.item_nodes[iid].visible:
							_inside(t, scene, scene.item_rect(iid), tag + " item " + iid)
					for sid: String in scene.slot_ids():
						_inside(t, scene, scene.slot_rect(sid), tag + " slot " + sid)
				"moving.gd":
					# Drifting things start off screen; the still ones (water jets) are tapped where they stand.
					for iid: String in scene.item_ids():
						if scene.data.get("path", "loop") == "still" or scene.data.get("items", [])[scene.item_ids().find(iid)].has("pos"):
							_inside(t, scene, scene.item_rect(iid), tag + " fixed item " + iid)
				"fit.gd":
					_inside(t, scene, scene.grid_rect(), tag + " grid")
					for pid: String in scene.model.bag_ids:
						_inside(t, scene, scene.piece_rect(pid), tag + " piece " + pid)
				_:
					t.check(false, "layout check can't handle the engine " + engine)
			ek.done(t, scene)
	kit.end()


func test_aboard_layout(t) -> void:
	await _layout(t, "aboard")


func test_flight_layout(t) -> void:
	await _layout(t, "flight")


func test_florida_layout(t) -> void:
	await _layout(t, "florida")


func test_seaday_layout(t) -> void:
	await _layout(t, "seaday")


# --- chapter 13 specifics ---

func kit_wait_finished(t, ek) -> void:
	var end := Time.get_ticks_msec() + 8000
	while not ek.finished(t) and Time.get_ticks_msec() < end:
		await t.tree.process_frame


func _seg(file: String) -> Dictionary:
	return {"data": "res://data/chapters/seaday/%s.json" % file, "done_delay": 0.0, "hint_delay": 600.0}


## The slide: Jack rides, Becca never does, and Becca sees Jack's ride (the sibling's outcome shows).
func test_seaday_slide_each_kid(t) -> void:
	if not _built("seaday"):
		return
	var ek := EngineKit.new()
	var moments := "res://scenes/engines/moments.tscn"
	for kid_id in ["jack", "becca"]:
		var scene: Node2D = await ek.make(t, moments, _seg("ride"), kid_id, Vector2i(1920, 1200))
		var rider: Character = scene.player if kid_id == "jack" else scene.helper
		var watcher: Character = scene.helper if kid_id == "jack" else scene.player
		t.eq(rider.kid.id, "jack", kid_id + ": it is always Jack who slides")
		var rider_home := rider.position
		var watcher_home := watcher.position
		await ek.wait(t, 2.0)
		await ek.tap(t, scene.thing_point())
		var rider_far := 0.0
		var watcher_far := 0.0
		var rider_seen := true
		var end := Time.get_ticks_msec() + 10000
		while not ek.finished(t) and Time.get_ticks_msec() < end:
			rider_far = maxf(rider_far, rider.position.distance_to(rider_home))
			watcher_far = maxf(watcher_far, watcher.position.distance_to(watcher_home))
			rider_seen = rider_seen and scene.view_rect().has_point(scene.stage.to_global(rider.position)) and rider.visible
			await t.tree.process_frame
		t.check(ek.finished(t), kid_id + ": the slide ends")
		t.check(rider_far > 300.0, "%s: the rider slides down (moved %.0f)" % [kid_id, rider_far])
		t.check(rider_seen, kid_id + ": the ride stays on screen")
		t.check(watcher_far < 5.0, "%s: the one watching stays put (moved %.0f)" % [kid_id, watcher_far])
		if kid_id == "becca":
			t.check(scene.player.kid.id == "becca" and scene.player.position == watcher_home, "becca never rides")
		ek.done(t, scene)
	# The height sign: both hop; only Jack is told he's tall enough.
	for kid_id in ["jack", "becca"]:
		var scene: Node2D = await ek.make(t, moments, _seg("sign"), kid_id, Vector2i(1920, 1200))
		var home: Vector2 = scene.player.position
		await ek.wait(t, 1.2)
		await ek.tap(t, scene.thing_point())
		await kit_wait_finished(t, ek)
		t.check(ek.finished(t), kid_id + ": the sign ends")
		t.check(ek.said.has("sea-tall-enough") == (kid_id == "jack"), kid_id + ": tall-enough line only for Jack")
		t.check(ek.said.has("sea-next-time") == (kid_id == "becca"), kid_id + ": next-time line only for Becca")
		t.check(scene.player.position.distance_to(home) < 5.0, kid_id + ": back at the sign, never on the slide")
		ek.done(t, scene)


## Putting on the swimsuit and the nice outfit visibly changes the kid (a new picture shows on them).
func test_seaday_place_segments_change_the_kid(t) -> void:
	if not _built("seaday"):
		return
	var ek := EngineKit.new()
	var place := "res://scenes/engines/place.tscn"
	for kid_id in ["jack", "becca"]:
		for file in ["swimsuit", "dinner"]:
			var scene: Node2D = await ek.make(t, place, _seg(file), kid_id, Vector2i(1920, 1200))
			var tag := "%s %s" % [kid_id, file]
			var fill: String = "res://assets/seaday/%s-%s.png" % [kid_id, "swimsuit" if file == "swimsuit" else "nice-outfit"]
			t.check(ResourceLoader.exists(fill), tag + ": the dressed picture exists")
			t.check(scene.find_child("Filled-kid", true, false) == null, tag + ": the kid starts undressed")
			var marker: Sprite2D = scene.find_child("kid", true, false)
			var before: Texture2D = marker.texture if marker else null
			await ek.tap(t, scene.item_point(scene.item_ids()[0]))
			await ek.wait(t, 0.9)
			var filled: Sprite2D = scene.find_child("Filled-kid", true, false)
			t.check(filled != null and filled.visible, tag + ": a dressed picture appears on the kid")
			if filled and before:
				t.check(filled.texture != before, tag + ": and it is a different picture")
				t.eq(filled.texture.resource_path, fill, tag + ": the right outfit for this kid")
			if file == "dinner":
				t.check(not ek.finished(t), tag + ": dressed is not the end, the kid still sits")
				await ek.tap(t, scene.item_point("me"))
				await ek.wait(t, 0.9)
				t.check(scene.is_filled("chair"), tag + ": sat in the chair")
			t.check(ek.finished(t), tag + ": segment done")
			ek.done(t, scene)


# --- the journey map with the chapters built so far ---

func _map_for(kit, kid_id: String, done: Array) -> Node2D:
	kit.progress.reset()
	kit.progress.mark_chapter_done(kid_id, "mission")
	for level in 4:
		kit.progress.mark_done(kid_id, level)
	for id: String in done:
		kit.progress.mark_chapter_done(kid_id, id)
	kit.pick(kid_id)
	return await kit.make_map()


func test_map_stops_for_the_built_chapters(t) -> void:
	var kit := Kit.new()
	kit.begin(t)
	var parsed: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/chapters.json"))
	var built: Array[String] = []
	for c: Dictionary in parsed["chapters"]:
		if int(c["number"]) >= 7 and not c.get("dropped", false) and not (c["segments"] as Array).is_empty():
			built.append(c["id"])
	for kid_id in ["jack", "becca"]:
		# Everything built is done: every stop shows, checked, big enough, on screen; nothing wiggles.
		for size in [Vector2i(1920, 1200), Vector2i(1920, 1080), Vector2i(1280, 800)]:
			kit.t.tree.root.size = size
			var map: Node2D = await _map_for(kit, kid_id, built)
			var view := Rect2(Vector2.ZERO, map.get_viewport().get_visible_rect().size)
			t.eq(map.stop_ids, built, "%s %s: a stop for every built chapter, none for unbuilt ones" % [kid_id, size])
			for id: String in built:
				var b: TextureButton = map.stop_button(id)
				t.check(b.visible, "%s: %s shows" % [id, size])
				t.check(b.size.x >= 120.0 and b.size.y >= 120.0, "%s %s: %s is %s, big enough to tap" % [kid_id, size, id, str(b.size)])
				t.check(view.grow(1.0).encloses(Rect2(b.global_position, b.size)), "%s %s: %s on screen" % [kid_id, size, id])
				t.check(b.get_node_or_null("Check") != null, "%s: %s is checked" % [id, size])
			t.eq(map.next_stop(), "", "%s %s: nothing left to wiggle" % [kid_id, size])
			map.free()
		kit.t.tree.root.size = Vector2i(1920, 1200)
		# The first unfinished built stop wiggles, the ones after it wait (hidden).
		var done: Array = built.slice(0, built.find("aboard"))  # everything before chapter 11
		var map: Node2D = await _map_for(kit, kid_id, done)
		t.eq(map.next_stop(), "aboard", "%s: the next stop is chapter 11, the first unfinished built one" % kid_id)
		await kit.wait(0.45)
		t.check(absf(map.stop_button("aboard").rotation) > 0.01, "%s: it wiggles" % kid_id)
		for id: String in built:
			if id != "aboard":
				t.check(absf(map.stop_button(id).rotation) < 0.001, "%s: %s does not wiggle" % [kid_id, id])
		t.check(not map.stop_button("seaday").visible, "%s: a later stop waits until this one is done" % kid_id)
		map.free()
	kit.end()
