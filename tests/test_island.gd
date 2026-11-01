# Chapter 12, Island days: every segment played with real touches for both kids, island
# day 2 compared with day 1 (the same code, different data), and both days played through
# the real chapter player. The chapter is data plus the Place and Match engines.
extends RefCounted

const KIT := preload("res://tests/engine_kit.gd")
const SEGMENTS := ["sunscreen", "dress", "shells", "castle", "decorate"]

var kit := KIT.new()


func _game(t) -> Node:
	return t.tree.root.get_node("Game")


func _entry(game: Node, chapter: String, segment_id: String) -> Dictionary:
	for s: Variant in game.chapter(chapter)["segments"]:
		if str((s as Dictionary).get("id", "")) == segment_id:
			return s as Dictionary
	return {}


## Starts one segment of a chapter for a kid (as the player would), then runs its scene.
func _open(t, segment_id: String, kid_id: String, chapter := "island1", size := Vector2i(1920, 1080)) -> Node2D:
	var game := _game(t)
	game.navigate = false
	game.stop_chapter()
	game.kid = load("res://data/%s.tres" % kid_id)
	game.segment = game.merge_segment(_entry(game, chapter, segment_id), kid_id)
	return await _spawn(t, size)


## Runs the scene for the current Game.segment, with no waiting at the end and no idle hint.
func _spawn(t, size := Vector2i(1920, 1080)) -> Node2D:
	var game := _game(t)
	game.segment["done_delay"] = 0.0
	game.segment["hint_delay"] = 60.0
	game.segment["round_delay"] = 0.0
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


## Plays a segment's done path with real drags and taps.
func _solve(t, scene: Node2D, id: String) -> void:
	match id:
		"sunscreen":
			for slot_id in scene.slot_ids():
				await kit.drag(t, scene.item_point("sunscreen"), scene.slot_point(slot_id))
				await kit.wait(t, 0.1)
		"dress":
			await kit.drag(t, scene.item_point("hat"), scene.slot_point("head"))
			await kit.drag(t, scene.item_point("sandals"), scene.slot_point("feet"))
		"shells":
			for guard in 12:
				if scene.finished:
					break
				for choice in scene.choice_ids():
					if scene.is_right(choice):
						await kit.tap(t, scene.choice_point(choice))
						break
				await kit.wait(t, 0.05)
		"castle":
			for item in scene.item_ids():
				await kit.drag(t, scene.item_point(item), scene.slot_point(item))
				await kit.wait(t, 0.1)
		"decorate":
			var dots: Array[String] = []
			for slot_id in scene.slot_ids():
				if slot_id.begins_with("dot-"):
					dots.append(slot_id)
			for i in scene.item_ids().size():
				await kit.drag(t, scene.item_point("sh%d" % (i + 1)), scene.slot_point(dots[i]))
				await kit.wait(t, 0.1)


# --- Registry ---------------------------------------------------------------

func test_chapters_are_wired(t) -> void:
	var game := _game(t)
	for chapter in ["island1", "island2"]:
		var ch: Dictionary = game.chapter(chapter)
		t.eq(int(ch["number"]), 12, chapter + ": chapter 12")
		var ids: Array = []
		for s: Variant in ch["segments"]:
			ids.append(str((s as Dictionary).get("id", "")))
		t.eq(ids, ["island-arrival", "sunscreen", "dress", "shells", "castle", "decorate", "island-splash"], chapter + ": segments in order")
		t.eq(str(_entry(game, chapter, "island-arrival")["name"]), "island-arrival", chapter + ": arrival clip")
		t.eq(str(_entry(game, chapter, "island-splash")["name"]), "island-splash", chapter + ": splash clip")
		t.check(str(_entry(game, chapter, "island-arrival")["line"]) != "", chapter + ": never opens in silence")
		t.check(str(_entry(game, chapter, "island-splash")["line"]) != "", chapter + ": never ends in silence")
		for id in SEGMENTS:
			t.check(not _entry(game, chapter, id).is_empty(), chapter + ": has " + id)
	t.eq(str(_entry(game, "island1", "castle")["scene"]), "res://scenes/engines/place.tscn", "castle is Place")
	t.eq(str(_entry(game, "island1", "shells")["scene"]), "res://scenes/engines/match.tscn", "shell hunt is Match")


func test_per_child_counts(t) -> void:
	var game := _game(t)
	for kid in [["jack", 5, 10, 5, 5, 5], ["becca", 3, 3, 3, 3, 3]]:
		var kid_id: String = kid[0]
		var scene: Node2D = await _open(t, "sunscreen", kid_id)
		t.eq(scene.slot_ids().size(), kid[1], kid_id + ": sunscreen spots")
		t.eq(scene.glows.shown().size(), kid[1], kid_id + ": every spot glows")
		_close(t, scene)
		scene = await _open(t, "shells", kid_id)
		t.eq(scene.choice_ids().size(), kid[2], kid_id + ": shells on the sand")
		t.eq(scene.rounds(), kid[3], kid_id + ": shells to find")
		_close(t, scene)
		scene = await _open(t, "castle", kid_id)
		var waiting := 0
		for item in scene.item_ids():
			waiting += 1
		t.eq(waiting, kid[4], kid_id + ": castle pieces")
		_close(t, scene)
		scene = await _open(t, "decorate", kid_id)
		t.eq(scene.item_ids().size(), kid[5], kid_id + ": shells to decorate with")
		_close(t, scene)
	var jack: Dictionary = game.merge_segment(_entry(game, "island1", "shells"), "jack")
	var becca: Dictionary = game.merge_segment(_entry(game, "island1", "shells"), "becca")
	t.check(float(becca["choice_height"]) > float(jack["choice_height"]), "becca's shells are larger")


# --- Sun safe ---------------------------------------------------------------

func test_sunscreen(t) -> void:
	for kid_id in ["becca", "jack"]:
		var scene: Node2D = await _open(t, "sunscreen", kid_id)
		t.check(kit.said.has("isle-sunscreen"), kid_id + ": start line")
		t.check(scene.player != null, kid_id + ": the kid is there")
		# Wrong move: dropped on empty sand slides back.
		var home: Vector2 = scene.item_point("sunscreen")
		await kit.drag(t, home, Vector2(1200, 300))
		await kit.wait(t, 0.5)
		t.check(scene.item_point("sunscreen").distance_to(home) < 2.0, kid_id + ": slid back home")
		for slot_id in scene.slot_ids():
			t.check(not scene.is_filled(slot_id), kid_id + ": nothing dabbed from a miss")
		var spots: Array[String] = scene.slot_ids()
		for i in spots.size():
			t.check(not kit.finished(t), kid_id + ": not done before the last spot")
			await kit.drag(t, scene.item_point("sunscreen"), scene.slot_point(spots[i]))
			await kit.wait(t, 0.1)
			t.check(scene.is_filled(spots[i]), "%s: spot %s dabbed" % [kid_id, spots[i]])
		t.check(kit.finished(t), kid_id + ": done after every spot")
		t.check(kit.said.has("isle-hat-sandals"), kid_id + ": hat and sandals next")
		_close(t, scene)


func test_hat_and_sandals(t) -> void:
	for kid_id in ["becca", "jack"]:
		var scene: Node2D = await _open(t, "dress", kid_id)
		t.eq(scene.glows.shown().size() > 0, kid_id == "becca", kid_id + ": only Becca's outline glows from the start")
		var home: Vector2 = scene.item_point("hat")
		await kit.drag(t, home, scene.slot_point("feet"))
		await t.tree.process_frame
		t.check(absf((scene.item_nodes["hat"] as Node2D).rotation) > 0.0, kid_id + ": the hat on the feet wiggles")
		await kit.wait(t, 0.5)
		t.check(not scene.is_placed("hat"), kid_id + ": the hat is not on")
		t.check(scene.item_point("hat").distance_to(home) < 2.0, kid_id + ": slid back")
		await kit.drag(t, home, scene.slot_point("head"))
		await kit.wait(t, 0.2)
		t.check(scene.is_placed("hat"), kid_id + ": the hat is on")
		t.check(not kit.finished(t), kid_id + ": sandals still to go")
		await kit.drag(t, scene.item_point("sandals"), scene.slot_point("feet"))
		t.check(kit.finished(t), kid_id + ": done")
		t.check(kit.said.has("isle-sun-safe"), kid_id + ": now we're sun safe")
		_close(t, scene)


# --- Shell hunt -------------------------------------------------------------

func test_shell_hunt(t) -> void:
	for kid_id in ["becca", "jack"]:
		var scene: Node2D = await _open(t, "shells", kid_id)
		t.check(kit.said.has("isle-shells"), kid_id + ": start line")
		var decoys: Array[String] = []
		var right: Array[String] = []
		for id in scene.choice_ids():
			(right if scene.is_right(id) else decoys).append(id)
		t.eq(right.size(), 5 if kid_id == "jack" else 3, kid_id + ": matching shells")
		t.eq(decoys.size(), 5 if kid_id == "jack" else 0, kid_id + ": decoys")
		if not decoys.is_empty():
			await kit.tap(t, scene.choice_point(decoys[0]))
			await t.tree.process_frame
			t.check(absf((scene.choice_nodes[decoys[0]] as Node2D).rotation) > 0.0, kid_id + ": a decoy wiggles")
			t.check(not scene.is_found(decoys[0]), kid_id + ": a decoy counts nothing")
			t.check(kit.said.has("try-again"), kid_id + ": hmm, try another one")
			t.eq(scene.round_index, 0, kid_id + ": no progress from a decoy")
		await _solve(t, scene, "shells")
		t.check(kit.finished(t), kid_id + ": done")
		t.check(kit.said.has("isle-all-shells"), kid_id + ": look at all our shells")
		t.eq(scene.round_index, right.size(), kid_id + ": every matching shell found")
		_close(t, scene)


# --- Sandcastle -------------------------------------------------------------

func test_sandcastle(t) -> void:
	var scene: Node2D = await _open(t, "castle", "jack")
	# Wrong move: a left tower in the gate's slot wiggles back.
	var home: Vector2 = scene.item_point("p2")
	await kit.drag(t, home, scene.slot_point("p1"))
	await t.tree.process_frame
	t.check(absf((scene.item_nodes["p2"] as Node2D).rotation) > 0.0, "jack: a piece in the wrong slot wiggles")
	await kit.wait(t, 0.5)
	t.check(not scene.is_placed("p2"), "jack: not placed")
	t.check(scene.item_point("p2").distance_to(home) < 2.0, "jack: slid back")
	# Dropped on the outline (an inert slot) is not a wrong slot either: it just slides back.
	await kit.drag(t, home, scene.slot_point("outline"))
	await kit.wait(t, 0.5)
	t.check(not scene.is_placed("p2"), "jack: the outline takes nothing")
	await _solve(t, scene, "castle")
	t.check(kit.finished(t), "jack: castle built")
	t.check(kit.said.has("isle-decorate"), "jack: now decorate it")
	_close(t, scene)
	scene = await _open(t, "castle", "becca")
	t.eq(scene.item_ids(), ["p1", "p4", "p5"] as Array[String], "becca: three pieces")
	t.check(not (scene.item_nodes["p4"] as Node2D).visible, "becca: one piece waits at a time")
	t.check(scene.slot_ids().has("b2") and scene.slot_ids().has("b3"), "becca: the two towers are already built")
	await kit.drag(t, scene.item_point("p1"), scene.slot_point("p1"))
	await kit.wait(t, 0.1)
	t.check((scene.item_nodes["p4"] as Node2D).visible, "becca: the next piece arrives")
	await _solve_rest(t, scene)
	t.check(kit.finished(t), "becca: castle built")
	_close(t, scene)


func _solve_rest(t, scene: Node2D) -> void:
	for item in scene.item_ids():
		if not scene.is_placed(item):
			await kit.drag(t, scene.item_point(item), scene.slot_point(item))
			await kit.wait(t, 0.1)


func test_decorate(t) -> void:
	for kid_id in ["becca", "jack"]:
		var scene: Node2D = await _open(t, "decorate", kid_id)
		var home: Vector2 = scene.item_point("sh1")
		await kit.drag(t, home, Vector2(1300, 120))
		await kit.wait(t, 0.5)
		t.check(not scene.is_placed("sh1"), kid_id + ": a shell dropped in the air slides back")
		t.check(scene.item_point("sh1").distance_to(home) < 2.0, kid_id + ": slid back")
		await _solve(t, scene, "decorate")
		t.check(kit.finished(t), kid_id + ": done")
		t.check(kit.said.has("isle-great-castle"), kid_id + ": what a sandcastle")
		t.check(scene.stage.get_node_or_null("DoneOverlay") != null, kid_id + ": the flag pops up")
		_close(t, scene)


# --- Island day 2 is data over day 1 ----------------------------------------

func _strip(value: Variant) -> Variant:
	# The shape of a segment: keys and kinds of values, with every number, string and path blanked.
	if value is Dictionary:
		var out := {}
		for key: Variant in (value as Dictionary).keys():
			if str(key) in ["background", "id", "name", "data", "line"]:
				continue
			out[key] = _strip((value as Dictionary)[key])
		return out
	if value is Array:
		var out2: Array = []
		for v: Variant in value:
			out2.append(_strip(v))
		return out2
	return "x"


func test_day_two_is_data_only(t) -> void:
	var game := _game(t)
	for id in SEGMENTS:
		var one: Dictionary = _entry(game, "island1", id)
		var two: Dictionary = _entry(game, "island2", id)
		t.eq(str(one["scene"]), str(two["scene"]), id + ": the same scene (code)")
		t.check(str(one["background"]) != str(two["background"]), id + ": a different background")
		t.check(str(one["background"]).contains("island/island-"), id + ": from assets/island")
		for kid_id in ["jack", "becca"]:
			var a: Dictionary = game.merge_segment(one, kid_id)
			var b: Dictionary = game.merge_segment(two, kid_id)
			t.eq(a.keys().size(), b.keys().size(), "%s %s: the same settings" % [id, kid_id])
			if id in ["sunscreen", "dress"]:
				t.eq(JSON.stringify(_strip(a)), JSON.stringify(_strip(b)), "%s %s: identical but for the background" % [id, kid_id])
			var ids_a: Array = []
			var ids_b: Array = []
			for key in ["items", "slots", "choices"]:
				for x: Variant in a.get(key, []):
					ids_a.append(str((x as Dictionary).get("id", "")))
				for x: Variant in b.get(key, []):
					ids_b.append(str((x as Dictionary).get("id", "")))
			t.eq(ids_a, ids_b, "%s %s: the same items, slots and choices" % [id, kid_id])
	var shells1: Dictionary = game.merge_segment(_entry(game, "island1", "shells"), "jack")
	var shells2: Dictionary = game.merge_segment(_entry(game, "island2", "shells"), "jack")
	t.check(str(shells1["choices"][0]["texture"]) != str(shells2["choices"][0]["texture"]), "day 2: a different shell set")
	t.check(str(shells1["choices"][9]["texture"]) != str(shells2["choices"][9]["texture"]), "day 2: different decoys")
	var c1: Dictionary = game.merge_segment(_entry(game, "island1", "castle"), "jack")
	var c2: Dictionary = game.merge_segment(_entry(game, "island2", "castle"), "jack")
	t.check(str(c1["slots"][0]["texture"]) != str(c2["slots"][0]["texture"]), "day 2: a different castle outline")
	t.check(str(c1["items"][0]["texture"]) != str(c2["items"][0]["texture"]), "day 2: different bucket shapes")
	# The same scene runs both days.
	var scene: Node2D = await _open(t, "castle", "jack", "island2")
	t.check(scene.slot_ids().has("p4"), "day 2 castle runs on the same scene")
	_close(t, scene)
	scene = await _open(t, "shells", "becca", "island2")
	t.eq(scene.choice_ids().size(), 3, "day 2 shell hunt runs on the same scene")
	_close(t, scene)
	t.eq(str(_entry(game, "island2", "island-arrival")["name"]), str(_entry(game, "island1", "island-arrival")["name"]), "day 2 reuses day 1's arrival clip")
	t.eq(str(_entry(game, "island2", "island-splash")["name"]), str(_entry(game, "island1", "island-splash")["name"]), "day 2 reuses day 1's splash clip")


# --- On screen at 1920x1200 -------------------------------------------------

func test_everything_is_on_screen_at_1920x1200(t) -> void:
	for kid_id in ["becca", "jack"]:
		for id in SEGMENTS:
			var scene: Node2D = await _open(t, id, kid_id, "island1", Vector2i(1920, 1200))
			if id == "shells":
				for c in scene.choice_ids():
					t.check(kit.on_screen(scene, scene.choice_rect(c)), "%s shells: %s on screen" % [kid_id, c])
				t.check(kit.on_screen(scene, scene.target_rect()), "%s shells: the shell card is on screen" % kid_id)
				for c in scene.choice_ids():
					t.check(scene.choice_rect(c).size.x >= 120.0, "%s shells: %s is a big enough tap target" % [kid_id, c])
			else:
				for item_id in scene.item_ids():
					t.check(kit.on_screen(scene, scene.item_rect(item_id)), "%s %s: %s on screen" % [kid_id, id, item_id])
					t.check(scene.item_rect(item_id).size.y >= 120.0 * 0.99, "%s %s: %s is a big enough tap target" % [kid_id, id, item_id])
				for slot_id in scene.slot_ids():
					t.check(kit.on_screen(scene, scene.slot_rect(slot_id)), "%s %s: slot %s on screen" % [kid_id, id, slot_id])
			if scene.player:
				t.check(kit.on_screen(scene, scene.player.hit_rect()), "%s %s: the kid is on screen" % [kid_id, id])
			if scene.helper:
				t.check(kit.on_screen(scene, scene.helper.hit_rect()), "%s %s: the sibling is on screen" % [kid_id, id])
			_close(t, scene)


func test_the_sibling_stands_clear(t) -> void:
	for kid_id in ["becca", "jack"]:
		for id in ["sunscreen", "dress", "castle", "decorate"]:
			var scene: Node2D = await _open(t, id, kid_id)
			var label := "%s %s" % [kid_id, id]
			if scene.helper:
				var helper: Rect2 = scene.helper.hit_rect()
				for slot_id in scene.slot_ids():
					t.check(not helper.intersects(scene.slot_rect(slot_id)), "%s: the sibling is clear of slot %s" % [label, slot_id])
				for item_id in scene.item_ids():
					t.check(not helper.intersects(scene.item_rect(item_id)), "%s: the sibling is clear of %s" % [label, item_id])
			_close(t, scene)


# --- The whole chapter, both days, both kids --------------------------------

func test_whole_chapters_for_both_kids(t) -> void:
	var game := _game(t)
	var progress: Node = t.tree.root.get_node("Progress")
	var old_path: String = progress.path
	for chapter in ["island1", "island2"]:
		for kid_id in ["becca", "jack"]:
			progress.path = "user://test_island_progress.json"
			progress.reset()
			game.navigate = false
			game.stop_chapter()
			game.kid = load("res://data/%s.tres" % kid_id)
			game.play_chapter(chapter)
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
				t.check(scene.finished, "%s %s: %s finished" % [chapter, kid_id, id])
				played.append(id)
				scene.free()
			t.eq(played, ["clip", "sunscreen", "dress", "shells", "castle", "decorate", "clip"] as Array[String], "%s %s: played in order" % [chapter, kid_id])
			t.check(not game.playing(), "%s %s: the chapter is over" % [chapter, kid_id])
			t.check(progress.chapter_done(kid_id, chapter), "%s %s: marked done" % [chapter, kid_id])
			t.eq(game.last_scene_request, game.MAP, "%s %s: back to the journey map" % [chapter, kid_id])
			game.stop_chapter()
	DirAccess.remove_absolute("user://test_island_progress.json")
	progress.reset()
	progress.path = old_path
	t.tree.root.size = Vector2i(1920, 1080)
	game.segment = {}
	game.last_segment_done = false
