# Chapter 10, Hello Florida: one test per segment (data on the engines), then a
# whole-chapter playthrough for both kids through the real player.
extends RefCounted

const KIT := preload("res://tests/engine_kit.gd")
const DIR := "res://data/chapters/florida/"

var kit := KIT.new()


## A florida segment's data file, with no cheer delay.
func _seg(name: String) -> Dictionary:
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DIR + name + ".json"))
	d["done_delay"] = 0.0
	return d


## Taps a moving bag until it is taken (the carousel may carry a decoy over it for a moment).
func _spot(t, scene: Node2D, id: String) -> void:
	for i in 12:
		if scene.is_tapped(id):
			return
		await kit.tap(t, scene.item_point(id))
		await kit.wait(t, 0.1)


func _solve_trunk(t, scene: Node2D) -> void:
	var m: TrunkModel = scene.model
	var ref := m.reference_solution()
	for id: String in m.bag_ids:
		if m.cell_of(id) != TrunkModel.NOWHERE:
			continue
		var turned: bool = ref[id]["turned"]
		if m.is_turned(id) != turned:
			await kit.tap(t, scene.piece_point(id))
			await kit.wait(t, 0.35)
		await kit.drag(t, scene.piece_point(id), scene.cell_center(ref[id]["cell"], m.size_of(id, turned)))
		await kit.wait(t, 0.05)


func _place_boosters(t, scene: Node2D) -> void:
	var slots: Array[String] = ["seat-left", "seat-right"]
	var ids: Array[String] = scene.item_ids()
	for i in ids.size():
		await kit.drag(t, scene.item_point(ids[i]), scene.slot_point(slots[i]))
		await kit.wait(t, 0.35)


# --- the registry ---

func test_registry_has_the_segments_in_order(t) -> void:
	var c: Dictionary = t.tree.root.get_node("Game").chapter("florida")
	var names: Array = []
	for s: Dictionary in c["segments"]:
		names.append(s["id"])
	t.eq(names, ["arrival", "bags", "boosters", "trunk", "drive", "hotel"], "chapter 10 segments")
	t.eq(c["segments"][0].get("line"), "hello-florida", "the chapter opens with a hello")
	t.eq(c["segments"][5].get("line"), "hotel-night", "and closes with a goodnight")
	t.check(not (c["segments"][5] as Dictionary).get("once", false), "the hotel night is the payoff: it plays on replay")


# --- Spot our bags (Moving targets) ---

func test_bags_per_kid_data(t) -> void:
	var scene: Node2D = await kit.make(t, "res://scenes/engines/moving.tscn", _seg("bags"), "jack")
	t.eq(scene.targets().size(), 3, "jack-jack: three family bags")
	t.eq(scene.item_ids().size(), 8, "jack-jack: eight bags in all")
	t.check(kit.said.has("spot-bags"), "start line")
	kit.done(t, scene)
	scene = await kit.make(t, "res://scenes/engines/moving.tscn", _seg("bags"), "becca")
	t.eq(scene.targets(), ["becca-suitcase"] as Array[String], "becca: her pink suitcase only")
	t.eq(scene.item_ids().size(), 5, "becca: five bags")
	t.check(kit.said.has("spot-pink"), "becca start line")
	kit.done(t, scene)


func test_bags_decoy_wiggles_and_target_taken(t) -> void:
	var scene: Node2D = await kit.make(t, "res://scenes/engines/moving.tscn", _seg("bags"), "becca")
	await kit.tap(t, scene.item_point("decoy-brown-box"))
	await t.tree.process_frame
	t.check(not scene.is_tapped("decoy-brown-box"), "a decoy is not taken")
	t.check(kit.said.has("not-ours"), "the sibling says it is not ours")
	t.check(not kit.finished(t), "not done")
	await _spot(t, scene, "becca-suitcase")
	t.check(scene.is_tapped("becca-suitcase"), "her suitcase is taken")
	kit.done(t, scene)


func test_missed_bag_comes_around_again(t) -> void:
	# Becca's real speed is 70 px/s (a lap takes over 30 s); the test spins the carousel faster.
	var data := _seg("bags")
	data["becca"]["speed"] = 800
	var scene: Node2D = await kit.make(t, "res://scenes/engines/moving.tscn", data, "becca")
	var start: Vector2 = scene.item_point("becca-suitcase")
	var gone := false
	var back := false
	for i in 120:
		await kit.wait(t, 0.1)
		var d: float = scene.item_point("becca-suitcase").distance_to(start)
		gone = gone or d > 400.0
		back = back or (gone and d < 120.0)
	t.check(gone and back, "an untapped bag circles back to where it started")
	t.check(not scene.is_tapped("becca-suitcase"), "never lost")
	kit.done(t, scene)


func test_bags_done_for_both_kids(t) -> void:
	for kid_id in ["becca", "jack"]:
		var scene: Node2D = await kit.make(t, "res://scenes/engines/moving.tscn", _seg("bags"), kid_id)
		for id: String in scene.targets():
			await _spot(t, scene, id)
		t.check(kit.finished(t), kid_id + ": every bag spotted")
		kit.done(t, scene)


# --- the booster seats (Place) ---

func test_boosters_wrong_seat_wiggles_back(t) -> void:
	var scene: Node2D = await kit.make(t, "res://scenes/engines/place.tscn", _seg("boosters"), "jack")
	var home: Vector2 = scene.item_point("booster-blue")
	await kit.drag(t, home, scene.slot_point("seat-right"))
	await t.tree.process_frame
	t.check(absf((scene.item_nodes["booster-blue"] as Node2D).rotation) > 0.0, "wiggles")
	await kit.wait(t, 0.45)
	t.check(not scene.is_placed("booster-blue"), "not placed on the pink seat's spot")
	t.check(scene.item_point("booster-blue").distance_to(home) < 2.0, "slid back")
	await kit.drag(t, home, scene.slot_point("seat-left"))
	await kit.wait(t, 0.35)
	t.check(scene.is_placed("booster-blue"), "the blue seat goes in its own spot")
	kit.done(t, scene)


func test_boosters_becca_either_spot(t) -> void:
	var scene: Node2D = await kit.make(t, "res://scenes/engines/place.tscn", _seg("boosters"), "becca")
	await kit.drag(t, scene.item_point("booster-blue"), scene.slot_point("seat-right"))
	await kit.wait(t, 0.35)
	t.check(scene.is_placed("booster-blue"), "either seat in either spot")
	kit.done(t, scene)


func test_boosters_done_for_both_kids(t) -> void:
	for kid_id in ["becca", "jack"]:
		var scene: Node2D = await kit.make(t, "res://scenes/engines/place.tscn", _seg("boosters"), kid_id)
		await _place_boosters(t, scene)
		t.check(scene.is_filled("seat-left") and scene.is_filled("seat-right"), kid_id + ": both spots")
		t.check(kit.finished(t), kid_id + ": done")
		kit.done(t, scene)


# --- the minivan trunk (Fit) ---

func test_trunk_per_kid_setup(t) -> void:
	var scene: Node2D = await kit.make(t, "res://scenes/engines/fit.tscn", _seg("trunk"), "jack")
	t.eq(Vector2i(scene.model.cols, scene.model.rows), Vector2i(6, 6), "the minivan grid")
	t.eq(scene.model.bag_ids.size(), 8, "all eight bags")
	t.check(not scene.is_locked("mommy-yellow"), "jack-jack: nothing pre-loaded")
	kit.done(t, scene)
	scene = await kit.make(t, "res://scenes/engines/fit.tscn", _seg("trunk"), "becca")
	t.check(scene.is_locked("mommy-yellow") and scene.is_locked("daddy-gray"), "becca: the big bags are in")
	kit.done(t, scene)


func test_trunk_wrong_drop_slides_back(t) -> void:
	var scene: Node2D = await kit.make(t, "res://scenes/engines/fit.tscn", _seg("trunk"), "jack")
	var home: Vector2 = scene.waiting_point("daddy-gray")
	await kit.drag(t, scene.piece_point("daddy-gray"), scene.cell_center(Vector2i(5, 5), Vector2i(2, 3)))
	await kit.wait(t, 0.4)
	t.eq(scene.model.cell_of("daddy-gray"), TrunkModel.NOWHERE, "not placed on a wheel well")
	t.check(scene.piece_point("daddy-gray").distance_to(home) < 2.0, "slid back")
	t.check(not kit.finished(t), "not done")
	kit.done(t, scene)


func test_trunk_done_for_both_kids(t) -> void:
	for kid_id in ["becca", "jack"]:
		var scene: Node2D = await kit.make(t, "res://scenes/engines/fit.tscn", _seg("trunk"), kid_id)
		await _solve_trunk(t, scene)
		t.check(scene.model.is_full(), kid_id + ": full")
		t.check(kit.finished(t), kid_id + ": done")
		kit.done(t, scene)


# --- on the tablet ---

func test_waiting_bags_clear_of_the_grid_and_the_helper(t) -> void:
	for kid_id in ["becca", "jack"]:
		var scene: Node2D = await kit.make(t, "res://scenes/engines/fit.tscn", _seg("trunk"), kid_id, Vector2i(1920, 1200))
		var helper_rect: Rect2 = scene.helper.hit_rect()
		for id: String in scene.model.bag_ids:
			if scene.is_locked(id):
				continue
			var r: Rect2 = scene.piece_rect(id)
			t.check(not r.intersects(scene.grid_rect()), "%s %s waits off the grid" % [kid_id, id])
			t.check(not r.intersects(helper_rect), "%s %s waits clear of the helper" % [kid_id, id])
		kit.done(t, scene)

func test_layout_fits_the_tablet(t) -> void:
	for kid_id in ["becca", "jack"]:
		var scene: Node2D = await kit.make(t, "res://scenes/engines/fit.tscn", _seg("trunk"), kid_id, Vector2i(1920, 1200))
		t.check(kit.on_screen(scene, scene.grid_rect()), kid_id + ": trunk grid on screen")
		for id: String in scene.model.bag_ids:
			t.check(kit.on_screen(scene, scene.piece_rect(id)), "%s %s on screen" % [kid_id, id])
		kit.done(t, scene)
		scene = await kit.make(t, "res://scenes/engines/place.tscn", _seg("boosters"), kid_id, Vector2i(1920, 1200))
		for id: String in scene.item_ids():
			t.check(kit.on_screen(scene, scene.item_rect(id)), "%s %s on screen" % [kid_id, id])
		for sid: String in scene.slot_ids():
			t.check(kit.on_screen(scene, scene.slot_rect(sid)), "%s %s on screen" % [kid_id, sid])
		kit.done(t, scene)
		var laps := _seg("bags")
		laps[kid_id]["speed"] = 800  # a full lap in about four seconds
		scene = await kit.make(t, "res://scenes/engines/moving.tscn", laps, kid_id, Vector2i(1920, 1200))
		for i in 100:
			await t.tree.process_frame
			for id: String in scene.item_ids():
				t.check(kit.on_screen(scene, scene.item_rect(id)), "%s %s on screen" % [kid_id, id])
		kit.done(t, scene)


# --- the whole chapter, through the real player ---

func test_whole_chapter_for_both_kids(t) -> void:
	var game: Node = t.tree.root.get_node("Game")
	var progress: Node = t.tree.root.get_node("Progress")
	var old_path: String = progress.path
	progress.path = "user://test_progress_florida.json"
	progress.reset()
	for kid_id in ["becca", "jack"]:
		t.tree.root.size = Vector2i(1920, 1200)
		game.navigate = false
		game.stop_chapter()
		game.kid = load("res://data/%s.tres" % kid_id)
		game.last_scene_request = ""
		var seen: Array[String] = []
		game.play_chapter("florida")
		var guard := 0
		while game.last_scene_request != game.MAP and guard < 12:
			guard += 1
			var seg: Dictionary = game.segment
			seen.append(seg["id"])
			if seg["kind"] != "scene":
				t.check(game.last_scene_request == game.INTRO, "%s %s plays as media" % [kid_id, seg["id"]])
				game.segment_done()
				continue
			var scene: Node2D = load(seg["scene"]).instantiate()
			t.tree.root.add_child(scene)
			await t.tree.process_frame
			await t.tree.process_frame
			kit.to_screen = t.tree.root.get_final_transform() * scene.get_canvas_transform()
			var voice: Node = t.tree.root.get_node("Voice")
			voice.enabled = false
			match seg["id"]:
				"bags":
					for id: String in scene.targets():
						await _spot(t, scene, id)
				"boosters":
					await _place_boosters(t, scene)
				"trunk":
					await _solve_trunk(t, scene)
			await kit.wait(t, 2.0 if not game.last_segment_done else 0.0)
			t.check(game.last_segment_done or game.last_scene_request != "", "%s %s finished" % [kid_id, seg["id"]])
			scene.free()
		t.eq(seen, ["arrival", "bags", "boosters", "trunk", "drive", "hotel"], kid_id + ": every segment, in order")
		t.eq(game.last_scene_request, game.MAP, kid_id + ": the map follows")
		t.check(progress.chapter_done(kid_id, "florida"), kid_id + ": chapter marked done")
	progress.path = old_path
	t.tree.root.size = Vector2i(1920, 1080)
	game.segment = {}
	game.stop_chapter()
