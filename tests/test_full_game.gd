# Phase 3: the whole game for each kid from a fresh save, title screen (pick the kid) to the beach
# finale, through the registry player with real touches (tests/play_kit.gd). Plus resume mid-chapter
# 11 and a v0.5 save played on to the finale.
#
# Resume behaviour (documented here): a chapter restarts from its FIRST segment. Quitting after the
# key card in chapter 11 and coming back, the map offers chapter 11 (not 10, not 12) and it plays
# again from aboard-intro.
extends RefCounted

const Kit := preload("res://tests/play_kit.gd")
const V05_SAVE := '{"jack": {"levels_done": [0,1,2,3], "intro_seen": true, "car_done": true, "airport_done": false}, "becca": {"levels_done": [0], "intro_seen": true}}'
## Stops in the order the map offers them once rows 1-3 are packed (the car goes on to the airport by itself).
const STOPS := ["car", "flight", "florida", "aboard", "island1", "island2", "seaday", "beach"]


## Plays the stops from `first_index` of STOPS on, tapping each on the map, asserting the order.
func _play_stops(t, kit, kid_id: String, first_index: int) -> void:
	for i in range(first_index, STOPS.size()):
		var id: String = STOPS[i]
		var map: Node2D = await kit.make_map()
		t.eq(map.next_stop(), id, "%s: the map offers %s next" % [kid_id, id])
		t.check(map.stop_button(id).visible, "%s: the %s stop shows" % [kid_id, id])
		await kit.tap(map.stop_point(id))
		t.check(kit.game.playing(), "%s: tapping %s starts it" % [kid_id, id])
		map.free()
		await kit.run()
		t.check(not kit.game.playing(), "%s: %s ended (no stuck player)" % [kid_id, id])
		t.check(kit.progress.chapter_done(kid_id, id), "%s: %s marked done" % [kid_id, id])
		t.eq(kit.requests.back(), kit.game.MAP, "%s: %s ends on the map" % [kid_id, id])


func _no_dead_ends(t, kit, kid_id: String) -> void:
	var cards := 0
	for e in kit.trace:
		t.check(ResourceLoader.exists(e["scene"]), "%s: %s/%s scene exists" % [kid_id, e["chapter"], e["id"]])
		if e["scene"] == kit.game.INTRO:
			t.check(e["mode"] in ["clip", "still", "card"], "%s: %s/%s shows something" % [kid_id, e["chapter"], e["id"]])
			if e["mode"] == "card":
				cards += 1
				print("NOTE %s: %s/%s has no clip or still (placeholder card)" % [kid_id, e["chapter"], e["id"]])
	t.eq(cards, 0, "%s: no segment fell back to a placeholder card" % kid_id)


func _all_checked_and_replayable(t, kit, kid_id: String) -> void:
	var map: Node2D = await kit.make_map()
	t.eq(map.next_stop(), "", "%s: nothing left to play" % kid_id)
	var ids: Array[String] = map.stop_ids.duplicate()
	map.free()
	for id in ids:
		# A fresh map each time: the first tap hands the screen to the player.
		map = await kit.make_map()
		t.check(map.stop_button(id).visible, "%s: %s shows" % [kid_id, id])
		t.check(map.stop_button(id).get_node_or_null("Check") != null, "%s: %s is checked" % [kid_id, id])
		await kit.tap(map.stop_point(id))
		t.check(kit.game.playing(), "%s: %s replays" % [kid_id, id])
		kit.game.stop_chapter()
		map.free()
	for id: String in ["mission", "routine", "your-turn", "car", "airport", "flight", "florida", "aboard", "island1", "island2", "seaday", "beach"]:
		t.check(kit.progress.chapter_done(kid_id, id), "%s: chapter %s done" % [kid_id, id])


func _full(t, kid_id: String) -> void:
	var kit := Kit.new()
	kit.begin(t)
	kit.pick(kid_id)
	t.eq(kit.requests.back(), kit.game.INTRO, "%s: a fresh kid starts with their intro" % kid_id)
	await kit.run()
	t.check(kit.progress.intro_seen(kid_id), "%s: chapter 1 done" % kid_id)
	for level in 4:
		kit.game.play_level(level)
		await kit.run()
		t.check(kit.progress.levels_done(kid_id).has(level), "%s: row %d marked" % [kid_id, level])
	await _play_stops(t, kit, kid_id, 0)
	_no_dead_ends(t, kit, kid_id)
	t.check(kit.order().has("beach/finale-map"), "%s: the finale map segment played" % kid_id)
	t.check(kit.order().has("beach/celebration"), "%s: the celebration played" % kid_id)
	t.eq(kit.order().back(), "beach/celebration", "%s: the celebration is last" % kid_id)
	t.eq(kit.order().count("island1/island-arrival") + kit.order().count("island2/island-arrival"), 2, "%s: both island days" % kid_id)
	await _all_checked_and_replayable(t, kit, kid_id)
	kit.end()


func test_full_game_jack(t) -> void:
	await _full(t, "jack")


func test_full_game_becca(t) -> void:
	await _full(t, "becca")


## Quit after the key card in chapter 11: chapter 11 is offered again and restarts at its first segment.
func _resume_11(t, kid_id: String) -> void:
	var kit := Kit.new()
	kit.begin(t)
	kit.progress.mark_chapter_done(kid_id, "mission")
	for level in 4:
		kit.progress.mark_done(kid_id, level)
	for id: String in ["car", "airport", "flight", "florida"]:
		kit.progress.mark_chapter_done(kid_id, id)
	kit.pick(kid_id)
	var map: Node2D = await kit.make_map()
	t.eq(map.next_stop(), "aboard", "%s: chapter 11 is next" % kid_id)
	await kit.tap(map.stop_point("aboard"))
	map.free()
	await kit.run("hallway")  # the key card is done, the hallway asked for
	t.eq(kit.order(), ["aboard/aboard-intro", "aboard/keycard"] as Array[String], "%s: stopped after the key card" % kid_id)
	t.check(not kit.progress.chapter_done(kid_id, "aboard"), "%s: chapter 11 isn't done" % kid_id)
	kit.game.stop_chapter()
	kit.progress.load_file()
	kit.trace.clear()
	kit.pick(kid_id)
	t.eq(kit.requests.back(), kit.game.MAP, "%s: reopening lands on the map" % kid_id)
	map = await kit.make_map()
	t.eq(map.next_stop(), "aboard", "%s: the map offers chapter 11 again, not 10 or 12" % kid_id)
	t.check(map.stop_button("florida").get_node_or_null("Check") != null, "%s: chapter 10 keeps its check" % kid_id)
	await kit.tap(map.stop_point("aboard"))
	map.free()
	await kit.run()
	t.eq(kit.order()[0], "aboard/aboard-intro", "%s: chapter 11 restarts from its first segment" % kid_id)
	t.check(not kit.order().any(func(s): return s.begins_with("florida/")), "%s: chapter 10 isn't repeated" % kid_id)
	t.eq(kit.order().size(), 6, "%s: all of chapter 11 played" % kid_id)
	t.check(kit.progress.chapter_done(kid_id, "aboard"), "%s: chapter 11 done after the resume" % kid_id)
	await _play_stops(t, kit, kid_id, 4)
	kit.end()


func test_resume_mid_chapter_11_jack(t) -> void:
	await _resume_11(t, "jack")


func test_resume_mid_chapter_11_becca(t) -> void:
	await _resume_11(t, "becca")


## A v0.5 save (card packed, SUV done, airport not) plays on from the airport to the finale.
func test_v05_save_plays_on_to_the_finale(t) -> void:
	var kit := Kit.new()
	kit.begin(t)
	var file := FileAccess.open(Kit.TMP, FileAccess.WRITE)
	file.store_string(V05_SAVE)
	file.close()
	kit.progress.load_file()
	kit.pick("jack")
	t.eq(kit.requests.back(), kit.game.MAP, "v0.5 Jack: straight to the map")
	var map: Node2D = await kit.make_map()
	t.eq(map.next_stop(), "airport", "v0.5 Jack: the airport is next")
	await kit.tap(map.stop_point("airport"))
	map.free()
	await kit.run()
	t.check(kit.progress.airport_done("jack"), "v0.5 Jack: the airport done")
	await _play_stops(t, kit, "jack", 1)
	t.eq(kit.order().back(), "beach/celebration", "v0.5 Jack: ends on the celebration")
	await _all_checked_and_replayable(t, kit, "jack")
	kit.end()
