# Phase 0 integration: a chapter built only from data and placeholders, played
# end to end through the real segment player for both kids. (Deleted after.)
extends RefCounted

const TMP := "user://test_progress_dummy.json"
const KIT := preload("res://tests/engine_kit.gd")

var kit := KIT.new()


func _setup(t, kid_id: String) -> Node:
	var voice: Node = t.tree.root.get_node("Voice")
	voice.enabled = false
	var progress: Node = t.tree.root.get_node("Progress")
	progress.path = TMP
	progress.reset()
	for row in 4:
		progress.mark_done(kid_id, row)
	progress.mark_chapter_done(kid_id, "car")
	progress.mark_chapter_done(kid_id, "airport")
	var game: Node = t.tree.root.get_node("Game")
	game.navigate = false
	game.stop_chapter()
	game.use_chapters([])
	game.last_scene_request = ""
	game.kid = load("res://data/%s.tres" % kid_id)
	return game


func _restore(t) -> void:
	var game: Node = t.tree.root.get_node("Game")
	game.stop_chapter()
	var progress: Node = t.tree.root.get_node("Progress")
	progress.reset()
	progress.path = "user://progress.json"
	t.tree.root.get_node("Voice").enabled = true


## Runs the scene the player asked for, as the tablet would.
func _open(t, game: Node) -> Node:
	var scene: Node = load(game.last_scene_request).instantiate()
	t.tree.root.add_child(scene)
	await t.tree.process_frame
	await t.tree.process_frame
	kit.to_screen = t.tree.root.get_final_transform() * (scene as CanvasItem).get_canvas_transform()
	return scene


func _wait_for_request(t, game: Node, from: String, seconds: float) -> void:
	var end := Time.get_ticks_msec() + int(seconds * 1000)
	while game.last_scene_request == from and Time.get_ticks_msec() < end:
		await t.tree.process_frame


func _play(t, kid_id: String) -> void:
	var game := _setup(t, kid_id)
	var progress: Node = t.tree.root.get_node("Progress")

	# The map: the dummy's stop is the next one, and a tap starts it.
	game.last_scene_request = game.MAP
	var map: Node = await _open(t, game)
	t.check(map.stop_ids.has("dummy"), "%s: the dummy has a stop" % kid_id)
	t.eq(map.next_stop(), "dummy", "%s: and it's next" % kid_id)
	await kit.tap(t, map.stop_point("dummy"))
	t.eq(game.last_scene_request, game.INTRO, "%s: the intro clip first" % kid_id)
	map.free()

	# The clip is missing: its still shows, and a tap goes on.
	var intro: Node = await _open(t, game)
	t.eq(intro.mode, "still", "%s: the still stands in for the missing clip" % kid_id)
	await kit.tap(t, Vector2(960, 540))
	t.eq(game.last_scene_request, "res://scenes/engines/match.tscn", "%s: on to Match" % kid_id)
	intro.free()

	# Match: Becca sees 2 choices, Jack-Jack 3.
	var matcher: Node = await _open(t, game)
	t.eq(matcher.choice_ids().size(), 2 if kid_id == "becca" else 3, "%s: choices from data" % kid_id)
	await kit.tap(t, matcher.choice_point("hat-1"))
	t.eq(game.last_scene_request, "res://scenes/engines/match.tscn", "%s: a wrong pick waits" % kid_id)
	await kit.wait(t, 0.5)
	await kit.tap(t, matcher.choice_point("shell"))
	await _wait_for_request(t, game, "res://scenes/engines/match.tscn", 3.0)
	t.eq(game.last_scene_request, "res://scenes/engines/place.tscn", "%s: on to Place" % kid_id)
	matcher.free()

	# Place: one thing for Becca, two for Jack-Jack.
	var place: Node = await _open(t, game)
	var items: Array[String] = place.item_ids()
	t.eq(items.size(), 1 if kid_id == "becca" else 2, "%s: things from data" % kid_id)
	for pair in [["hat", "head"], ["shell", "hand"]]:
		if items.has(pair[0]):
			await kit.drag(t, place.item_point(pair[0]), place.slot_point(pair[1]))
			await kit.wait(t, 0.4)
	await _wait_for_request(t, game, "res://scenes/engines/place.tscn", 3.0)
	t.eq(game.last_scene_request, "res://scenes/engines/moments.tscn", "%s: on to Tap moments" % kid_id)
	place.free()

	# Tap moments: any tap counts; one wave for Becca, two for Jack-Jack.
	var moments: Node = await _open(t, game)
	t.eq(moments.moments(), 1 if kid_id == "becca" else 2, "%s: moments from data" % kid_id)
	var end := Time.get_ticks_msec() + 15000
	while game.last_scene_request == "res://scenes/engines/moments.tscn" and Time.get_ticks_msec() < end:
		await kit.tap(t, Vector2(800, 400))
		await kit.wait(t, 0.2)
	t.eq(game.last_scene_request, game.MAP, "%s: on to the finale map" % kid_id)
	moments.free()

	# The finale: the route lights up, then the chapter is over and done.
	var finale: Node = await _open(t, game)
	t.check(finale.route_lit(), "%s: the route lights up" % kid_id)
	end = Time.get_ticks_msec() + 10000
	while game.playing() and Time.get_ticks_msec() < end:
		await t.tree.process_frame
	t.check(not game.playing(), "%s: the chapter finished" % kid_id)
	t.eq(game.last_scene_request, game.MAP, "%s: back to the map" % kid_id)
	t.check(progress.chapter_done(kid_id, "dummy"), "%s: marked done" % kid_id)
	finale.free()

	# The map again: the dummy stop wears its check.
	var after: Node = await _open(t, game)
	t.check(after.stop_button("dummy").get_node_or_null("Check") != null, "%s: the stop has a check" % kid_id)
	after.free()
	_restore(t)


func test_dummy_chapter_jack(t) -> void:
	await _play(t, "jack")


func test_dummy_chapter_becca(t) -> void:
	await _play(t, "becca")
