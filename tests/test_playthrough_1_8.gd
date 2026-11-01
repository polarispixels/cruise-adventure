# Phase 0 regression: chapters 1-3 (room), 7 (trunk) and 8 (check-in, security, maze)
# played for both kids through the registry player, each scene finished with real
# touches (tests/play_kit.gd). Plus resume mid-chapter-8, a v0.5 save, and the media
# fallback.
extends RefCounted

const Kit := preload("res://tests/play_kit.gd")
## The order a child meets the chapters (rows 1-3 of the card are three plays of chapter 3).
const PLAY_ORDER := ["mission", "routine", "your-turn", "your-turn", "your-turn", "car"]
const V05_SAVE := '{"jack": {"levels_done": [0,1,2,3], "intro_seen": true, "car_done": true, "airport_done": false}, "becca": {"levels_done": [0], "intro_seen": true}}'


## chapters.json read directly: the "chapter/segment" order a kid should get.
func _expected(kit, order: Array, kid_id: String) -> Array[String]:
	var parsed: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/chapters.json"))
	var out: Array[String] = []
	var row := {"routine": 0, "your-turn": 0}
	for id: String in order:
		var chapter: Dictionary = {}
		for c: Dictionary in parsed["chapters"]:
			if c["id"] == id:
				chapter = c
		var level := 0
		if id == "your-turn":
			level = 1 + row[id]
			row[id] += 1
		for seg: Dictionary in chapter["segments"]:
			if seg["kind"] == "clip" and seg.get("optional", false):
				var media := str(seg["name"]).replace("{kid}", kid_id).replace("{row}", str(level + 1))
				if not FileAccess.file_exists("res://assets/video/%s.ogv" % media) \
						and not FileAccess.file_exists("res://assets/stills/%s.png" % media):
					continue
			out.append("%s/%s" % [id, seg["id"]])
		if id == "car":  # "after": "next"
			out.append_array(_expected(kit, ["airport"], kid_id))
	return out


func _play_1_to_3(kit, kid_id: String) -> void:
	kit.pick(kid_id)
	kit.t.eq(kit.requests.back(), kit.game.INTRO, "%s: a new kid starts with their intro" % kid_id)
	await kit.run()
	kit.t.check(kit.progress.intro_seen(kid_id), "%s: chapter 1 marked done" % kid_id)
	kit.t.eq(kit.requests.back(), kit.game.MAP, "%s: the intro ends on the map" % kid_id)
	for level in 4:
		kit.game.play_level(level)
		await kit.run()
		kit.t.check(kit.progress.levels_done(kid_id).has(level), "%s: row %d marked" % [kid_id, level])
		kit.t.eq(kit.requests.back(), kit.game.MAP, "%s: a packed row goes back to the card" % kid_id)


func _playthrough(t, kid_id: String) -> void:
	var kit := Kit.new()
	kit.begin(t)
	# This is the playthrough of chapters 1-8: chapters 9 and up count as unbuilt here, however far they are.
	kit.game.use_chapters([])
	var list: Array = kit.game.chapters().duplicate(true)
	for c: Dictionary in list:
		if int(c["number"]) >= 9:
			c["segments"] = []
	kit.game.use_chapters(list)
	await _play_1_to_3(kit, kid_id)
	t.check(kit.progress.chapter_done(kid_id, "routine"), "%s: chapter 2 done" % kid_id)
	t.check(kit.progress.chapter_done(kid_id, "your-turn"), "%s: chapter 3 done" % kid_id)
	t.check(not kit.progress.car_done(kid_id), "%s: the car isn't done yet" % kid_id)
	# The map now shows the SUV as the next stop, the airport still hidden.
	var map: Node2D = await kit.make_map()
	t.eq(map.next_stop(), "car", "%s: the next stop is the car" % kid_id)
	t.check(map.stop_button("car").visible and not map.stop_button("airport").visible, "%s: only the SUV shows" % kid_id)
	t.eq(map.stop_ids.slice(0, 2), ["car", "airport"] as Array[String], "%s: the first stops are the car and the airport" % kid_id)
	map.free()
	t.eq(kit.trace[0]["mode"], "clip", "%s: the intro is the real clip" % kid_id)
	# Tap the SUV on the map: chapter 7, which goes on to chapter 8 by itself.
	map = await kit.make_map()
	await kit.tap(map.stop_point("car"))
	t.eq(kit.game.last_scene_request, kit.game.INTRO, "%s: the SUV starts its clip first" % kid_id)
	map.free()
	await kit.run()
	t.check(kit.progress.car_done(kid_id), "%s: chapter 7 marked done" % kid_id)
	t.check(kit.progress.airport_done(kid_id), "%s: chapter 8 marked done" % kid_id)
	t.eq(kit.requests.back(), kit.game.MAP, "%s: the gate ends on the map" % kid_id)
	# Segment order matches data/chapters.json (a missing optional clip is skipped).
	t.eq(kit.order(), _expected(kit, PLAY_ORDER, kid_id), "%s: segment order follows chapters.json" % kid_id)
	t.eq(kit.order().size(), 13, "%s: every segment played" % kid_id)
	# What the kid saw and heard.
	var scenes: Array[String] = []
	for e in kit.trace:
		if e["scene"] != kit.game.INTRO:
			scenes.append(e["scene"])
	t.eq(scenes, [kit.game.ROOM, kit.game.ROOM, kit.game.ROOM, kit.game.ROOM, kit.game.TRUNK, kit.game.CHECKIN,
			kit.game.SECURITY, kit.game.MAZE] as Array[String], "%s: the scenes in order" % kid_id)
	for line in ["load-car", "close-trunk", "lets-go", "tag-bags", "bye-suitcases", "comes-back", "walk-through",
			"get-your-things", "hug-buddy", "found-gate"]:
		t.check(kit.said.has(line), "%s: said %s" % [kid_id, line])
	# The map afterwards: both stops checked, nothing left to wiggle.
	map = await kit.make_map()
	t.check(map.stop_button("car").get_node_or_null("Check") != null, "%s: the SUV is checked" % kid_id)
	t.check(map.stop_button("airport").get_node_or_null("Check") != null, "%s: the boarding pass is checked" % kid_id)
	t.check(map.next_stop() not in ["car", "airport"], "%s: nothing left to play in chapters 7 and 8" % kid_id)
	t.eq(kit.progress.chapters_done(kid_id), ["mission", "car", "airport"] as Array[String], "%s: chapters saved" % kid_id)
	# A replay of the car skips its once-clip and goes straight to play.
	map.free()
	kit.game.play_chapter("car")
	t.eq(kit.game.last_scene_request, kit.game.TRUNK, "%s: replaying the car goes straight to the trunk" % kid_id)
	kit.game.stop_chapter()
	kit.game.use_chapters([])
	kit.end()


func test_playthrough_jack(t) -> void:
	await _playthrough(t, "jack")


func test_playthrough_becca(t) -> void:
	await _playthrough(t, "becca")


## Quit in the middle of chapter 8, come back: the map offers chapter 8, not chapter 7.
func _resume(t, kid_id: String) -> void:
	var kit := Kit.new()
	kit.begin(t)
	kit.progress.mark_chapter_done(kid_id, "mission")
	for level in 4:
		kit.progress.mark_done(kid_id, level)
	kit.pick(kid_id)
	t.eq(kit.requests.back(), kit.game.MAP, "%s: a returning kid goes straight to the map" % kid_id)
	var map: Node2D = await kit.make_map()
	t.eq(map.next_stop(), "car", "%s: before the car" % kid_id)
	map.free()
	kit.game.play_chapter("car")
	await kit.run("security")  # check-in done, security asked for but not played
	t.eq(kit.order().slice(-2), ["car/trunk", "airport/checkin"] as Array[String], "%s: stopped after check-in" % kid_id)
	t.check(kit.game.playing(), "%s: the airport is running" % kid_id)
	t.check(kit.progress.car_done(kid_id) and not kit.progress.airport_done(kid_id), "%s: the car done, the airport not" % kid_id)
	# The app is closed here: forget the player, reload the file from disk.
	kit.game.stop_chapter()
	kit.progress.load_file()
	t.check(kit.progress.car_done(kid_id), "%s: the car survives a reload" % kid_id)
	t.check(not kit.progress.airport_done(kid_id), "%s: the airport is still to do" % kid_id)
	kit.pick(kid_id)
	t.eq(kit.requests.back(), kit.game.MAP, "%s: reopening lands on the map" % kid_id)
	map = await kit.make_map()
	t.eq(map.next_stop(), "airport", "%s: the map offers chapter 8" % kid_id)
	t.check(map.stop_button("car").get_node_or_null("Check") != null, "%s: the SUV keeps its check" % kid_id)
	t.check(map.stop_button("airport").get_node_or_null("Check") == null, "%s: the boarding pass has none" % kid_id)
	await kit.tap(map.stop_point("airport"))
	var game: Node = kit.game
	# The airport clip (jack-airport) doesn't exist, so chapter 8 opens on check-in again.
	t.eq(game.last_scene_request, game.CHECKIN, "%s: chapter 8 starts again at check-in" % kid_id)
	map.free()
	await kit.run()
	t.check(kit.progress.airport_done(kid_id), "%s: finished after the resume" % kid_id)
	t.eq(kit.order().slice(-4), ["airport/checkin", "airport/checkin", "airport/security", "airport/maze"] as Array[String],
			"%s: the whole airport played again, the trunk did not" % kid_id)
	kit.end()


func test_resume_mid_airport_jack(t) -> void:
	await _resume(t, "jack")


func test_resume_mid_airport_becca(t) -> void:
	await _resume(t, "becca")


func test_v05_save_shows_the_same_map(t) -> void:
	var kit := Kit.new()
	kit.begin(t)
	var file := FileAccess.open(Kit.TMP, FileAccess.WRITE)
	file.store_string(V05_SAVE)
	file.close()
	kit.progress.load_file()
	# Jack: card packed, car done, airport not.
	kit.pick("jack")
	t.eq(kit.requests.back(), kit.game.MAP, "v0.5 Jack: intro already seen, straight to the map")
	var map: Node2D = await kit.make_map()
	t.eq(map.get_node("Card/RowChecks").get_child_count(), 4, "v0.5 Jack: four rows stamped")
	t.check(map.stop_button("car").visible and map.stop_button("car").get_node_or_null("Check") != null, "v0.5 Jack: the SUV is checked")
	t.check(map.stop_button("airport").visible and map.stop_button("airport").get_node_or_null("Check") == null, "v0.5 Jack: the boarding pass is next")
	t.eq(map.next_stop(), "airport", "v0.5 Jack: next stop")
	map.free()
	# Becca: one row, nothing else.
	kit.pick("becca")
	t.eq(kit.requests.back(), kit.game.MAP, "v0.5 Becca: straight to the map")
	map = await kit.make_map()
	t.eq(map.get_node("Card/RowChecks").get_child_count(), 1, "v0.5 Becca: one row stamped")
	t.check(not map.stop_button("car").visible and not map.stop_button("airport").visible, "v0.5 Becca: no stops yet")
	t.eq(map.next_stop(), "", "v0.5 Becca: no stop yet")
	map.free()
	# A chapter-7 replay on the old save skips the car clip, as before.
	kit.pick("jack")
	kit.game.play_chapter("car")
	t.eq(kit.game.last_scene_request, kit.game.TRUNK, "v0.5 Jack: the SUV replays straight to the trunk")
	kit.game.stop_chapter()
	kit.end()


## A clip whose file is missing shows the still, or a placeholder card, and never blocks.
func test_missing_clip_falls_back_and_does_not_block(t) -> void:
	var kit := Kit.new()
	kit.begin(t)
	kit.pick("jack")
	kit.game.stop_chapter()
	kit.game.stills_dir = "res://tests/fixtures/"
	kit.game.use_chapters([{"id": "mission", "number": 1, "title": "t", "segments": [
		{"kind": "clip", "id": "has-still", "name": "test-still"},
		{"kind": "clip", "id": "no-still", "name": "nobody-intro"},
		{"kind": "clip", "id": "skipped", "name": "nobody-either", "optional": true}]}])
	kit.game.play_chapter("mission")
	await kit.run()
	t.eq(kit.order(), ["mission/has-still", "mission/no-still"] as Array[String], "the optional missing clip is skipped, the others show")
	t.eq(kit.trace[0]["mode"], "still", "the still when the clip is missing")
	t.eq(kit.trace[1]["mode"], "card", "the placeholder card when the still is missing too")
	t.check(kit.progress.intro_seen("jack"), "the chapter still finishes")
	t.eq(kit.requests.back(), kit.game.MAP, "and goes on to the map")
	kit.end()
