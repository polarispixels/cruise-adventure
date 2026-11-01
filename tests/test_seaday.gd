# Chapter 13, Sea day: every segment played with real touches for both kids, and
# the whole chapter through the real chapter player. The chapter is data plus the
# Place, Tap moments and Moving targets engines (no chapter-specific scene code).
extends RefCounted

const KIT := preload("res://tests/engine_kit.gd")
## The height line on the sign art: 30.7% down from the top of the 560 px sign (stage y 340).
const LINE_Y := 340.0 + 0.307 * 560.0
const SIGN_TOP_Y := 340.0

var kit := KIT.new()


func _game(t) -> Node:
	return t.tree.root.get_node("Game")


func _entry(game: Node, segment_id: String) -> Dictionary:
	for s: Variant in game.chapter("seaday")["segments"]:
		if str((s as Dictionary).get("id", "")) == segment_id:
			return s as Dictionary
	return {}


## Starts one segment of the chapter for a kid (as the player would), then runs its scene.
func _open(t, segment_id: String, kid_id: String, size := Vector2i(1920, 1080)) -> Node2D:
	var game := _game(t)
	game.navigate = false
	game.stop_chapter()
	game.kid = load("res://data/%s.tres" % kid_id)
	game.segment = game.merge_segment(_entry(game, segment_id), kid_id)
	return await _spawn(t, size)


## Runs the scene for the current Game.segment, with no waiting at the end and no idle hint.
func _spawn(t, size := Vector2i(1920, 1080)) -> Node2D:
	var game := _game(t)
	game.segment["done_delay"] = 0.0
	game.segment["hint_delay"] = 60.0
	game.last_segment_done = false
	var voice: Node = t.tree.root.get_node("Voice")
	voice.enabled = false
	kit.said.clear()
	if not voice.said.is_connected(kit._on_said):
		voice.said.connect(kit._on_said)
	t.tree.root.size = size
	var scene: Node2D = load(str(game.segment["scene"])).instantiate()
	t.tree.root.add_child(scene)
	await t.tree.process_frame
	await t.tree.process_frame
	kit.to_screen = t.tree.root.get_final_transform() * scene.get_canvas_transform()
	return scene


func _close(t, scene: Node2D) -> void:
	scene.free()
	t.tree.root.size = Vector2i(1920, 1080)
	var game := _game(t)
	game.segment = {}
	game.last_segment_done = false


func _until_ready(t, scene: Node2D) -> void:
	for i in 240:
		if scene.state == "ready":
			return
		await t.tree.process_frame


## Waits (in real time) until the segment is finished; the hop or the ride has to play out first.
func _until_finished(t, seconds := 8.0) -> void:
	var waited := 0.0
	while waited < seconds and not kit.finished(t):
		await kit.wait(t, 0.1)
		waited += 0.1


func _no_nulls(t, id: String) -> void:
	var game := _game(t)
	var seg: Dictionary = game.merge_segment(_entry(game, id), "jack")
	t.check(not seg.is_empty(), id + ": segment exists")


# --- Registry ---------------------------------------------------------------

func test_chapter_is_wired(t) -> void:
	var game := _game(t)
	var ch: Dictionary = game.chapter("seaday")
	t.eq(int(ch["number"]), 13, "chapter 13")
	var ids: Array = []
	for s: Variant in ch["segments"]:
		ids.append(str((s as Dictionary).get("id", "")))
	t.eq(ids, ["seaday-intro", "swimsuit", "sign", "ride", "splash", "dinner", "seaday-evening"], "segments in order")
	t.eq(str(_entry(game, "seaday-intro")["name"]), "sea-pool-deck", "intro clip")
	t.eq(str(_entry(game, "seaday-evening")["name"]), "sea-evening-deck", "evening clip")
	var jack: Dictionary = game.merge_segment(_entry(game, "ride"), "jack")
	var becca: Dictionary = game.merge_segment(_entry(game, "ride"), "becca")
	t.eq(str(jack["actor"]), "player", "jack rides")
	t.eq(str(becca["actor"]), "helper", "becca watches her brother ride")
	for id in ["swimsuit", "sign", "ride", "splash", "dinner"]:
		_no_nulls(t, id)


# --- Swimsuit on (Place) ----------------------------------------------------

func test_swimsuit_on(t) -> void:
	for kid_id in ["becca", "jack"]:
		var scene: Node2D = await _open(t, "swimsuit", kid_id)
		t.check(kit.said.has("sea-swimsuit"), kid_id + ": start line")
		t.eq(scene.glows.shown().size() > 0, kid_id == "becca", kid_id + ": only Becca's kid outline glows from the start")
		# Wrong move: dropped in empty space slides back.
		var start: Vector2 = scene.item_point("swimsuit")
		await kit.drag(t, start, start + Vector2(0, 330))
		await kit.wait(t, 0.5)
		t.check(not scene.is_placed("swimsuit"), kid_id + ": dropped in the air, not on")
		t.check(scene.item_point("swimsuit").distance_to(start) < 2.0, kid_id + ": slid back home")
		t.check(not kit.finished(t), kid_id + ": not done")
		await kit.drag(t, start, scene.slot_point("kid"))
		t.check(scene.is_filled("kid"), kid_id + ": the swimsuit is on")
		t.check(kit.finished(t), kid_id + ": done")
		_close(t, scene)


# --- The big slide: height sign (Tap moments) -------------------------------

func test_height_sign_jack_is_above_the_line_becca_below(t) -> void:
	var tops := {}
	for kid_id in ["jack", "becca"]:
		var scene: Node2D = await _open(t, "sign", kid_id)
		await _until_ready(t, scene)
		t.check(scene.helper == null, kid_id + ": the sign compares one kid at a time")
		tops[kid_id] = scene.stage.to_local(scene.player.hit_rect().position).y
		var sign_h: float = scene.thing_rect().size.y / scene.stage.scale.y
		t.check(abs(sign_h - 560.0) < 2.0, "the sign is 560 px tall")
		t.check(abs(scene.stage.to_local(scene.thing_rect().position).y - SIGN_TOP_Y) < 2.0, "the sign top is where the line is measured from")
		await kit.tap(t, Vector2(960, 540))
		await _until_finished(t)
		t.check(kit.finished(t), kid_id + ": one tap finishes the sign")
		_close(t, scene)
	t.check(float(tops["jack"]) < LINE_Y, "jack-jack's head is above the line")
	t.check(float(tops["becca"]) > LINE_Y, "becca's head is below the line")


func test_becca_hears_next_time_and_jack_hears_tall_enough(t) -> void:
	var scene: Node2D = await _open(t, "sign", "becca")
	await _until_ready(t, scene)
	await kit.tap(t, Vector2(300, 300))
	t.check(kit.said.has("sea-next-time"), "becca: the kind next-time line")
	t.check(not kit.said.has("sea-tall-enough"), "becca: never told to hop on")
	_close(t, scene)
	scene = await _open(t, "sign", "jack")
	await _until_ready(t, scene)
	await kit.tap(t, Vector2(300, 300))
	t.check(kit.said.has("sea-tall-enough"), "jack: tall enough")
	t.check(not kit.said.has("sea-next-time"), "jack: no next-time line")
	_close(t, scene)


func test_becca_does_not_jump_above_the_line_or_hear_tap_to_go(t) -> void:
	var scene: Node2D = await _open(t, "sign", "becca")
	await _until_ready(t, scene)
	t.check(not kit.said.has("sea-tap-go"), "becca: no 'Tap to go!' at the sign")
	await kit.tap(t, Vector2(300, 300))
	for i in 20:
		await kit.wait(t, 0.05)
		t.check(scene.stage.to_local(scene.player.hit_rect().position).y > LINE_Y, "becca: head stays below the line through her tap")
	_close(t, scene)


func test_hint_and_wrong_lines_say_what_to_do(t) -> void:
	var game := _game(t)
	t.eq(str(game.merge_segment(_entry(game, "swimsuit"), "jack")["hint_line"]), "sea-swimsuit", "swimsuit hint")
	t.eq(str(game.merge_segment(_entry(game, "dinner"), "becca")["hint_line"]), "sea-dinner", "dinner hint")
	t.eq(str(game.merge_segment(_entry(game, "splash"), "jack")["wrong_line"]), "sea-ducks", "jack: a decoy toy says to catch the ducks")
	var scene: Node2D = await _open(t, "splash", "jack")
	_park(scene, 400.0)
	await kit.tap(t, scene.item_point("ball"))
	t.check(kit.said.has("sea-ducks"), "tapping a ball says 'Catch the ducks!'")
	_close(t, scene)


func test_becca_dinner_glows_only_the_active_slot(t) -> void:
	var scene: Node2D = await _open(t, "dinner", "becca")
	t.eq(scene.glows.shown().size(), 0, "nothing glows until she picks something up")
	var p: Vector2 = scene.item_point("outfit")
	await kit.touch(t, true, p)
	await kit.move(t, p + Vector2(40, 40))
	await kit.move(t, p + Vector2(80, 80))
	await t.tree.process_frame
	t.eq(scene.glows.shown().size(), 1, "holding the outfit lights only the kid, not the chair")
	await kit.touch(t, false, p + Vector2(80, 80))
	_close(t, scene)


func test_next_time_wording_matches_the_build_spec(t) -> void:
	var text := ""
	for l: Variant in JSON.parse_string(FileAccess.get_file_as_string("res://data/voice_lines.json")):
		if str((l as Dictionary)["id"]) == "sea-next-time":
			text = str((l as Dictionary)["text"])
	t.eq(text, "When you're a little bigger, you can ride it! Let's splash!", "next-time words")


# --- The big slide: the ride (Tap moments) ----------------------------------

func test_jack_rides_the_slide_and_becca_waves_from_the_pool(t) -> void:
	var scene: Node2D = await _open(t, "ride", "jack")
	await _until_ready(t, scene)
	t.check(kit.said.has("sea-splash-me"), "becca's line plays in jack's game")
	var home: Vector2 = scene.player.position
	var pool_helper: Vector2 = scene.helper.position
	await kit.tap(t, Vector2(960, 540))
	await kit.wait(t, 1.0)
	t.check(scene.player.position.distance_to(home) > 50.0, "jack is sliding")
	t.check(scene.helper.position.distance_to(pool_helper) < 1.0, "becca stays at the pool")
	await _until_finished(t)
	t.check(kit.finished(t), "the ride is over")
	t.check(kit.said.has("sea-whee"), "wheee")
	t.check(scene.player.position.distance_to(Vector2(900, 860)) < 40.0, "jack lands in the splash pool")
	_close(t, scene)


func test_becca_never_rides_she_watches_jack(t) -> void:
	var scene: Node2D = await _open(t, "ride", "becca")
	await _until_ready(t, scene)
	t.check(kit.said.has("sea-watch-me"), "jack's line plays in becca's game")
	var home: Vector2 = scene.player.position
	var rider_home: Vector2 = scene.helper.position
	await kit.tap(t, Vector2(960, 540))
	await kit.wait(t, 1.0)
	t.check(scene.player.position.distance_to(home) < 1.0, "becca does not move down the slide")
	t.check(scene.helper.position.distance_to(rider_home) > 50.0, "jack-jack slides down")
	await _until_finished(t)
	t.check(kit.finished(t), "done after he splashes")
	t.check(scene.player.position.distance_to(home) < 40.0, "becca stayed put (she only cheers)")
	_close(t, scene)


func test_slide_waits_for_a_tap_without_failing(t) -> void:
	var scene: Node2D = await _open(t, "ride", "becca")
	await _until_ready(t, scene)
	await kit.wait(t, 0.5)
	t.check(not kit.finished(t), "no tap, no end, no failure")
	t.eq(scene.state, "ready", "still waiting")
	_close(t, scene)


# --- Splash zone (Moving targets) -------------------------------------------

## Parks the drifting toys on screen.
func _park(scene: Node2D, phase: float) -> void:
	scene.data["speed"] = 0.0
	scene._phase = phase
	scene._move(0.0)


func test_splash_zone_counts(t) -> void:
	var scene: Node2D = await _open(t, "splash", "jack")
	t.eq(scene.targets().size(), 9, "jack-jack: 4 jets and 5 ducks")
	_close(t, scene)
	scene = await _open(t, "splash", "becca")
	t.eq(scene.targets().size(), 7, "becca: 3 jets and 4 toys")
	_close(t, scene)


func test_splash_decoy_only_wiggles_and_misses_come_around(t) -> void:
	var scene: Node2D = await _open(t, "splash", "jack")
	_park(scene, 400.0)
	await kit.tap(t, scene.item_point("ball"))
	t.check(not scene.is_tapped("ball"), "a ball is a decoy: it wiggles, no count")
	t.check(not kit.finished(t), "not done")
	# A missed duck drifts off and comes around again, still untapped.
	var span := maxf(240.0 * scene.item_ids().size(), 1472.0 + 240.0)
	var before: float = scene.item_nodes["duck-0"].position.x
	scene._phase += span
	scene._move(0.0)
	t.check(absf(scene.item_nodes["duck-0"].position.x - before) < 1.0, "a missed duck comes around to the same place")
	t.check(not scene.is_tapped("duck-0"), "nothing is lost")
	_close(t, scene)


func test_splash_zone_done_for_both_kids(t) -> void:
	for kid_id in ["becca", "jack"]:
		var scene: Node2D = await _open(t, "splash", kid_id)
		_park(scene, 400.0)
		t.check(kit.said.has("sea-splash-time"), kid_id + ": start line")
		for id in scene.targets():
			await kit.tap(t, scene.item_point(id))
		t.check(kit.finished(t), kid_id + ": every jet and toy tapped")
		_close(t, scene)


# --- Dress for dinner (Place) -----------------------------------------------

func test_dress_for_dinner(t) -> void:
	for kid_id in ["becca", "jack"]:
		var scene: Node2D = await _open(t, "dinner", kid_id)
		t.check(kit.said.has("sea-dinner"), kid_id + ": start line")
		# Wrong moves: sitting down in the street clothes, or the outfit on the chair.
		await kit.drag(t, scene.item_point("me"), scene.slot_point("chair"))
		await kit.wait(t, 0.5)
		t.check(not scene.is_placed("me"), kid_id + ": the chair waits for the outfit")
		await kit.drag(t, scene.item_point("outfit"), scene.slot_point("chair"))
		await kit.wait(t, 0.5)
		t.check(not scene.is_placed("outfit"), kid_id + ": the outfit does not go on the chair")
		await kit.drag(t, scene.item_point("outfit"), scene.slot_point("kid"))
		t.check(scene.is_filled("kid"), kid_id + ": dressed")
		t.check(not kit.finished(t), kid_id + ": still has to sit")
		await kit.drag(t, scene.item_point("me"), scene.slot_point("chair"))
		t.check(scene.is_filled("chair"), kid_id + ": sitting at the table")
		t.check(kit.finished(t), kid_id + ": done")
		_close(t, scene)


# --- Layout -----------------------------------------------------------------

func test_everything_is_on_screen_at_1920x1200(t) -> void:
	for kid_id in ["becca", "jack"]:
		for id in ["swimsuit", "dinner"]:
			var scene: Node2D = await _open(t, id, kid_id, Vector2i(1920, 1200))
			for item_id in scene.item_ids():
				t.check(kit.on_screen(scene, scene.item_rect(item_id)), "%s %s: %s on screen" % [kid_id, id, item_id])
			for slot_id in scene.slot_ids():
				t.check(kit.on_screen(scene, scene.slot_rect(slot_id)), "%s %s: slot %s on screen" % [kid_id, id, slot_id])
			_close(t, scene)
		for id in ["sign", "ride"]:
			var scene: Node2D = await _open(t, id, kid_id, Vector2i(1920, 1200))
			await _until_ready(t, scene)
			t.check(kit.on_screen(scene, scene.player.hit_rect()), "%s %s: the kid is on screen" % [kid_id, id])
			t.check(kit.on_screen(scene, scene.thing_rect()), "%s %s: the sign or splash is on screen" % [kid_id, id])
			if scene.helper:
				t.check(kit.on_screen(scene, scene.helper.hit_rect()), "%s %s: the sibling is on screen" % [kid_id, id])
			_close(t, scene)
		var splash: Node2D = await _open(t, "splash", kid_id, Vector2i(1920, 1200))
		_park(splash, 400.0)
		for id in splash.targets():
			t.check(kit.on_screen(splash, splash.item_rect(id)), "%s splash: %s on screen" % [kid_id, id])
		_close(t, splash)


# --- The whole chapter through the real player ------------------------------

func _solve(t, scene: Node2D, segment_id: String) -> void:
	match segment_id:
		"swimsuit":
			await kit.drag(t, scene.item_point("swimsuit"), scene.slot_point("kid"))
		"sign", "ride":
			await _until_ready(t, scene)
			await kit.tap(t, Vector2(960, 540))
			await _until_finished(t)
		"splash":
			_park(scene, 400.0)
			for id in scene.targets():
				await kit.tap(t, scene.item_point(id))
		"dinner":
			await kit.drag(t, scene.item_point("outfit"), scene.slot_point("kid"))
			await kit.drag(t, scene.item_point("me"), scene.slot_point("chair"))


func test_whole_chapter_for_both_kids(t) -> void:
	var game := _game(t)
	var progress: Node = t.tree.root.get_node("Progress")
	var old_path: String = progress.path
	for kid_id in ["becca", "jack"]:
		progress.path = "user://test_seaday_progress.json"
		progress.reset()
		game.navigate = false
		game.stop_chapter()
		game.kid = load("res://data/%s.tres" % kid_id)
		game.play_chapter("seaday")
		var played: Array[String] = []
		for guard in 20:
			if not game.playing():
				break
			var request: String = game.last_scene_request
			if request == game.INTRO:
				played.append("clip")
				game.segment_done()
				continue
			var id := str(game.segment.get("id", ""))
			var scene: Node2D = await _spawn(t)
			await _solve(t, scene, id)
			t.check(scene.finished, "%s: %s finished" % [kid_id, id])
			played.append(id)
			scene.free()
		t.eq(played, ["clip", "swimsuit", "sign", "ride", "splash", "dinner", "clip"] as Array[String], kid_id + ": played in order")
		t.check(not game.playing(), kid_id + ": the chapter is over")
		t.check(progress.chapter_done(kid_id, "seaday"), kid_id + ": seaday is marked done")
		t.eq(game.last_scene_request, game.MAP, kid_id + ": back to the journey map")
		game.stop_chapter()
	DirAccess.remove_absolute("user://test_seaday_progress.json")
	progress.reset()
	progress.path = old_path
	t.tree.root.size = Vector2i(1920, 1080)
	game.segment = {}
	game.last_segment_done = false
