# Chapter 9, the flight: each segment's data played with real touches, then the whole chapter
# through the real player for both kids.
extends RefCounted

const KIT := preload("res://tests/engine_kit.gd")

var kit := KIT.new()


func _entry(id: String) -> Dictionary:
	for s: Dictionary in Game.chapter("flight")["segments"]:
		if s.get("id", "") == id:
			return s
	return {}


## The segment as chapters.json lists it; kit.make lays the data file and the kid's block over it.
func _make(t, id: String, kid_id: String, size := Vector2i(1920, 1080)) -> Node2D:
	var e := _entry(id)
	var scene: Node2D = await kit.make(t, e["scene"], e, kid_id, size)
	_quick(scene)
	return scene


func _quick(scene: Node2D) -> void:
	scene.data["done_delay"] = 0.0
	scene.data["hint_delay"] = 60.0
	scene.data["round_delay"] = 0.0


func _scroll_to(t, scene: Node2D, id: String) -> void:
	for i in 12:
		if scene.view_rect().has_point(scene.choice_point(id)):
			return
		await kit.drag(t, Vector2(1500, 300), Vector2(500, 300))


## Plays the segment's done path with real touches.
func _solve(t, scene: Node2D, id: String) -> void:
	match id:
		"seat":
			var want: String = scene.target()
			await _scroll_to(t, scene, want)
			await kit.tap(t, scene.choice_point(want))
		"bin":
			var m: TrunkModel = scene.model
			var ref := m.reference_solution()
			for bag: String in m.bag_ids:
				var turned: bool = ref[bag]["turned"]
				if m.is_turned(bag) != turned and not scene.data.get("auto_turn", false):
					await kit.tap(t, scene.piece_point(bag))
					await kit.wait(t, 0.35)
				await kit.drag(t, scene.piece_point(bag), scene.cell_center(ref[bag]["cell"], m.size_of(bag, turned)))
				await kit.wait(t, 0.05)
		"under", "buckle":
			for item: Dictionary in scene.data["items"]:
				await kit.drag(t, scene.item_point(item["id"]), scene.slot_point(item["slot"]))
				await kit.wait(t, 0.1)
		"cart":
			await _until(t, scene, "ready")
			await kit.tap(t, Vector2(800, 400))
			await kit.wait(t, 0.2)
		"snack":
			await kit.tap(t, scene.choice_point("crackers"))
		"clouds":
			for r in scene.rounds():
				await kit.tap(t, scene.choice_point(scene.target()))
				await kit.wait(t, 0.1)


func _until(t, scene: Node2D, state: String) -> void:
	for i in 200:
		if scene.state == state:
			return
		await t.tree.process_frame


func test_chapter_is_registered(t) -> void:
	var c: Dictionary = Game.chapter("flight")
	var ids: Array = []
	for s: Dictionary in c["segments"]:
		ids.append(s["id"])
	t.eq(ids, ["seat", "bin", "under", "buckle", "takeoff", "cart", "snack", "clouds", "landing"], "segment order")
	for s: Dictionary in c["segments"]:
		if s["kind"] == "scene":
			t.check(FileAccess.file_exists(s["data"]), "data file " + str(s["data"]))


func test_seat_setup_and_done(t) -> void:
	var scene := await _make(t, "seat", "jack")
	t.eq(scene.choice_ids().size(), 4, "jack-jack: 4 rows")
	t.eq(scene.target(), "row-14", "his row number")
	t.check(kit.said.has("match-number"), "the sibling says what to match")
	t.check(scene.choice_rect("row-12").position.y > scene.target_rect().end.y, "the rows sit below the boarding pass")
	await _solve(t, scene, "seat")
	t.check(kit.finished(t), "jack-jack finds his seat")
	kit.done(t, scene)
	scene = await _make(t, "seat", "becca")
	t.eq(scene.choice_ids().size(), 3, "becca: 3 stickers")
	t.check(kit.said.has("match-sticker"), "the sibling says what to match")
	await _solve(t, scene, "seat")
	t.check(kit.finished(t), "becca finds her seat")
	t.check(kit.said.has("our-seats"), "done line")
	kit.done(t, scene)


func test_seat_wrong_row_wiggles(t) -> void:
	var scene := await _make(t, "seat", "becca")
	await kit.tap(t, scene.choice_point("red"))
	await t.tree.process_frame
	t.check(absf((scene.choice_nodes["red"] as Node2D).rotation) > 0.0, "wiggling")
	t.check(kit.said.has("try-again"), "Hmm... try another one")
	t.check(not kit.finished(t), "no failure, not done")
	kit.done(t, scene)


func test_bin_both_kids(t) -> void:
	var scene := await _make(t, "bin", "jack")
	t.eq(scene.model.bag_ids.size(), 2, "jack-jack: suitcase and backpack")
	t.check(scene.model.is_turned("daddy-backpack"), "the backpack starts lying down")
	t.eq(scene.ghost_ids().size(), 0, "no ghosts for jack-jack")
	await _solve(t, scene, "bin")
	await kit.wait(t, 0.2)
	t.check(kit.finished(t), "jack-jack's bin is full")
	kit.done(t, scene)
	scene = await _make(t, "bin", "becca")
	t.eq(scene.model.bag_ids.size(), 1, "becca: the suitcase")
	t.eq(scene.ghost_ids().size(), 1, "a ghost outline")
	await _solve(t, scene, "bin")
	await kit.wait(t, 0.2)
	t.check(kit.finished(t), "becca's bin is full")
	t.check(kit.said.has("it-fits"), "it fits")
	kit.done(t, scene)


func test_bin_wrong_spot_slides_back(t) -> void:
	var scene := await _make(t, "bin", "jack")
	var home: Vector2 = scene.piece_point("daddy-gray")
	await kit.drag(t, home, Vector2(1500, 300))
	await kit.wait(t, 0.5)
	t.eq(scene.model.cell_of("daddy-gray"), TrunkModel.NOWHERE, "not in the bin")
	t.check(not kit.finished(t), "not done")
	kit.done(t, scene)


func test_under_the_seat(t) -> void:
	var scene := await _make(t, "under", "jack")
	t.eq(scene.slot_ids().size(), 2, "jack-jack: two bags")
	var home: Vector2 = scene.item_point("jack-backpack")
	await kit.drag(t, home, Vector2(200, 300))
	await kit.wait(t, 0.5)
	t.check(not scene.is_placed("jack-backpack"), "dropped off the slots")
	t.check(scene.item_point("jack-backpack").distance_to(home) < 2.0, "slid back")
	await kit.drag(t, scene.item_point("mommy-purse"), scene.slot_point("a"))
	await kit.wait(t, 0.3)
	t.check(scene.is_placed("mommy-purse"), "either bag fits either spot")
	kit.done(t, scene)
	scene = await _make(t, "under", "jack")
	await _solve(t, scene, "under")
	await kit.wait(t, 0.2)
	t.check(kit.finished(t), "jack-jack done")
	kit.done(t, scene)
	scene = await _make(t, "under", "becca")
	t.eq(scene.slot_ids().size(), 1, "becca: one bag")
	await _solve(t, scene, "under")
	await kit.wait(t, 0.2)
	t.check(kit.finished(t), "becca done")
	kit.done(t, scene)


func test_buckle_up(t) -> void:
	var scene := await _make(t, "buckle", "jack")
	t.eq(scene.slot_ids().size(), 2, "jack-jack: his belt and Becca's")
	await kit.drag(t, scene.item_point("tab-1"), Vector2(200, 300))
	await kit.wait(t, 0.5)
	t.check(not scene.is_placed("tab-1"), "a tab dropped short slides back")
	await kit.drag(t, scene.item_point("tab-2"), scene.slot_point("buckle-1"))
	await kit.wait(t, 0.3)
	t.check(scene.is_placed("tab-2"), "either tab clicks into either buckle")
	kit.done(t, scene)
	scene = await _make(t, "buckle", "jack")
	await _solve(t, scene, "buckle")
	await kit.wait(t, 0.2)
	t.check(kit.finished(t), "jack-jack buckled both")
	t.check(kit.said.has("buckle-becca"), "then he helps Becca")
	kit.done(t, scene)
	scene = await _make(t, "buckle", "becca")
	t.eq(scene.slot_ids().size(), 1, "becca: just hers")
	await _solve(t, scene, "buckle")
	await kit.wait(t, 0.2)
	t.check(kit.finished(t), "becca buckled")
	t.check(kit.said.has("light-on"), "the light line")
	kit.done(t, scene)


func test_cart_any_tap(t) -> void:
	for kid_id in ["jack", "becca"]:
		var scene := await _make(t, "cart", kid_id)
		await _solve(t, scene, "cart")
		await kit.wait(t, 0.8)
		t.check(kit.finished(t), kid_id + ": the cart came and left")
		t.check(not kit.said.has("yum") and not kit.said.has("pick-snack"), "the snack lines wait for the snack")
		kit.done(t, scene)


func test_snack_any_choice_is_right(t) -> void:
	for pick in ["apple", "crackers", "juice"]:
		var scene := await _make(t, "snack", "becca")
		t.eq(scene.choice_ids().size(), 3, "3 snacks")
		await kit.tap(t, scene.choice_point(pick))
		t.check(kit.finished(t), pick + " is a fine snack")
		kit.done(t, scene)


func test_clouds_rounds_per_kid(t) -> void:
	var scene := await _make(t, "clouds", "jack")
	t.eq(scene.rounds(), 3, "jack-jack: 3 clouds")
	var back: Sprite2D = scene.get_node("Stage/Target/Back")
	t.eq(back.texture.resource_path, "res://assets/flight/cloud-heart.png", "the target is the cloud to find")
	await kit.tap(t, scene.choice_point("bunny"))
	await t.tree.process_frame
	t.check(absf((scene.choice_nodes["bunny"] as Node2D).rotation) > 0.0, "a wrong cloud wiggles")
	await _solve(t, scene, "clouds")
	t.check(kit.finished(t), "jack-jack matched all three")
	kit.done(t, scene)
	scene = await _make(t, "clouds", "becca")
	t.eq(scene.rounds(), 2, "becca: 2 clouds")
	t.eq(scene.choice_ids().size(), 2, "becca sees just 2 clouds")
	t.check(scene.get_node("Stage/Target/Back") != null, "her target shows the cloud too")
	await _solve(t, scene, "clouds")
	t.check(kit.finished(t), "becca matched both")
	kit.done(t, scene)


func test_hints_use_the_kid_delays(t) -> void:
	var e := _entry("seat")
	var scene: Node2D = await kit.make(t, e["scene"], e, "becca")
	t.eq(scene.hint_delay(), 6.0, "becca: 6 s")
	kit.done(t, scene)
	scene = await kit.make(t, e["scene"], e, "jack")
	t.eq(scene.hint_delay(), 8.0, "jack-jack: 8 s")
	kit.done(t, scene)


func test_everything_fits_the_tablet(t) -> void:
	for kid_id in ["jack", "becca"]:
		for id in ["bin", "under", "buckle", "snack", "clouds"]:
			var scene := await _make(t, id, kid_id, Vector2i(1920, 1200))
			if id == "bin":
				for bag: String in scene.model.bag_ids:
					t.check(kit.on_screen(scene, scene.piece_rect(bag)), "%s %s %s on screen" % [kid_id, id, bag])
			elif id in ["under", "buckle"]:
				for s: String in scene.slot_ids():
					t.check(kit.on_screen(scene, scene.slot_rect(s)), "%s %s %s slot on screen" % [kid_id, id, s])
				for i: String in scene.item_ids():
					t.check(kit.on_screen(scene, scene.item_rect(i)), "%s %s %s item on screen" % [kid_id, id, i])
			else:
				for c: String in scene.choice_ids():
					t.check(kit.on_screen(scene, scene.choice_rect(c)), "%s %s %s on screen" % [kid_id, id, c])
			kit.done(t, scene)
		var seat := await _make(t, "seat", kid_id, Vector2i(1920, 1200))
		t.check(kit.on_screen(seat, seat.target_rect()), kid_id + ": boarding pass on screen")
		kit.done(t, seat)


## The whole chapter through the real player, both kids.
func test_playthrough_both_kids(t) -> void:
	var progress: Node = t.tree.root.get_node("Progress")
	progress.path = "user://test_progress_flight.json"
	progress.reset()
	var game: Node = t.tree.root.get_node("Game")
	for kid_id in ["jack", "becca"]:
		t.tree.root.size = Vector2i(1920, 1080)
		game.navigate = false
		game.use_chapters([])
		game.stop_chapter()
		game.kid = load("res://data/%s.tres" % kid_id)
		game.last_scene_request = ""
		game.play_chapter("flight")
		var order: Array = []
		for guard in 20:
			var seg: Dictionary = game.segment
			var id: String = seg.get("id", "")
			if id == "" or game.last_scene_request == "":
				break
			order.append(id)
			if seg["kind"] == "scene":
				var scene: Node2D = load(seg["scene"]).instantiate()
				t.tree.root.add_child(scene)
				await t.tree.process_frame
				await t.tree.process_frame
				kit.to_screen = t.tree.root.get_final_transform() * scene.get_canvas_transform()
				_quick(scene)
				var voice: Node = t.tree.root.get_node("Voice")
				voice.enabled = false
				await _solve(t, scene, id)
				await kit.wait(t, 0.3)
				scene.free()
			else:
				game.segment_done()
			if progress.chapter_done(kid_id, "flight"):
				break
		t.eq(order, ["seat", "bin", "under", "buckle", "takeoff", "cart", "snack", "clouds", "landing"], kid_id + " played every segment")
		t.check(progress.chapter_done(kid_id, "flight"), kid_id + ": chapter marked done")
		game.stop_chapter()
	progress.reset()
	progress.path = "user://progress.json"
	game.segment = {}
	game.last_segment_done = false
