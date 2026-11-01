# Chapter 14, Beach hotel: every segment played with real touches for both kids, then the
# whole chapter through the real player (finale included: the route lights up, the
# celebration plays, the map offers every chapter again). Data on the engines, no new scenes.
extends RefCounted

const KIT := preload("res://tests/engine_kit.gd")
const PLAY := preload("res://tests/play_kit.gd")
const SEGMENTS := ["beach-intro", "trunk", "elevator", "hallway", "room", "waves", "castle", "decorate", "finale-map", "celebration"]
const BIG := Vector2i(1920, 1200)

var kit := KIT.new()


func _game(t) -> Node:
	return t.tree.root.get_node("Game")


func _entry(t, segment_id: String) -> Dictionary:
	for s: Variant in _game(t).chapter("beach")["segments"]:
		if str((s as Dictionary).get("id", "")) == segment_id:
			return (s as Dictionary).duplicate(true)
	return {}


func _open(t, segment_id: String, kid_id: String, size := Vector2i(1920, 1080)) -> Node2D:
	var seg := _entry(t, segment_id)
	seg["done_delay"] = 0.0
	seg["hint_delay"] = 60.0
	seg["round_delay"] = 0.0
	# Merge the data file first, then the test settings win.
	var merged: Dictionary = _game(t).merge_segment(seg, kid_id)
	for k in ["done_delay", "hint_delay", "round_delay"]:
		merged[k] = seg[k]
	var scene: Node2D = await kit.make(t, str(merged["scene"]), merged, kid_id, size)
	_game(t).segment["done_delay"] = 0.0
	return scene


func _wrong(scene: Node2D) -> String:
	for id in scene.choice_ids():
		if not scene.is_right(id):
			return id
	return ""


# --- Registry ---------------------------------------------------------------

func test_chapter_is_wired(t) -> void:
	var game := _game(t)
	var ch: Dictionary = game.chapter("beach")
	t.eq(int(ch["number"]), 14, "chapter 14")
	var ids: Array = []
	for s: Variant in ch["segments"]:
		ids.append(str((s as Dictionary).get("id", "")))
	t.eq(ids, SEGMENTS, "segments in order")
	t.eq(str(_entry(t, "trunk")["scene"]), "res://scenes/engines/fit.tscn", "the trunk is Fit")
	t.eq(str(_entry(t, "elevator")["scene"]), "res://scenes/engines/match.tscn", "the elevator is Match")
	t.eq(str(_entry(t, "waves")["scene"]), "res://scenes/engines/moments.tscn", "the waves are Tap moments")
	t.eq(str(_entry(t, "castle")["scene"]), "res://scenes/engines/place.tscn", "the castle is Place")
	t.check(bool(_entry(t, "finale-map")["finale"]), "the map segment is the finale")
	t.eq(str(_entry(t, "beach-intro")["name"]), "beach-walk-sand", "intro clip")
	t.eq(str(_entry(t, "celebration")["name"]), "beach-celebration", "celebration clip")
	t.check(str(_entry(t, "beach-intro")["line"]) != "" and str(_entry(t, "celebration")["line"]) != "", "clips never open or end in silence")
	for n in ["beach-walk-sand", "beach-celebration"]:
		t.check(ResourceLoader.exists("res://assets/stills/%s.png" % n), n + ": fallback still")


# --- Load the minivan again (Fit) ------------------------------------------------

func test_trunk(t) -> void:
	for kid in [["jack", 4], ["becca", 7]]:
		var kid_id: String = kid[0]
		var scene: Node2D = await _open(t, "trunk", kid_id)
		if kid_id == "becca":
			t.check(scene.is_locked("becca-backpack") and not scene.is_locked("mommy-purse"), "becca: only the purse is left, it cannot dead-end")
		var locked := 0
		for id: String in scene.model.bag_ids:
			if scene.is_locked(id):
				locked += 1
		t.eq(locked, kid[1], kid_id + ": bags already in")
		t.check(kit.said.has("beach-pack-again"), kid_id + ": start line")
		var left: Array = []
		for id: String in scene.model.bag_ids:
			if not scene.is_locked(id):
				left.append(id)
		t.eq(left.size(), 8 - int(kid[1]), kid_id + ": bags left to place")
		# Wrong move: dropped half off the grid, it slides back.
		var home: Vector2 = scene.waiting_point(left[0])
		await kit.drag(t, scene.piece_point(left[0]), Vector2(1500, 80))
		await kit.wait(t, 0.4)
		t.eq(scene.model.cell_of(left[0]), TrunkModel.NOWHERE, kid_id + ": not placed")
		t.check(scene.piece_point(left[0]).distance_to(home) < 2.0, kid_id + ": slid back")
		var ref: Dictionary = scene.model.reference_solution()
		for id: String in left:
			scene.model.set_turned(id, ref[id]["turned"])
			scene.pieces[id].set_turned(ref[id]["turned"])
			var size: Vector2i = scene.model.size_of(id, scene.model.is_turned(id))
			await kit.drag(t, scene.piece_point(id), scene.cell_center(ref[id]["cell"], size))
			await kit.wait(t, 0.4)
		t.check(kit.finished(t), kid_id + ": the grid is full")
		t.check(kit.said.has("beach-packed"), kid_id + ": done line")
		kit.done(t, scene)


# --- Elevator (Match) -----------------------------------------------------------

func test_elevator(t) -> void:
	for kid in [["jack", 4, "f7", "number"], ["becca", 3, "green", "color"]]:
		var kid_id: String = kid[0]
		var scene: Node2D = await _open(t, "elevator", kid_id)
		t.eq(scene.choice_ids().size(), kid[1], kid_id + ": buttons")
		t.eq(scene.target(), kid[2], kid_id + ": the button on the key")
		t.eq(str(_game(t).segment["key"]), kid[3], kid_id + ": match key")
		t.check(kit.said.has("beach-elevator"), kid_id + ": start line")
		await kit.tap(t, scene.choice_point(_wrong(scene)))
		t.check(not kit.finished(t), kid_id + ": a wrong button waits")
		t.check(kit.said.has("try-again"), kid_id + ": hmm line")
		await kit.tap(t, scene.choice_point(kid[2]))
		t.check(kit.finished(t), kid_id + ": the floor")
		t.check(kit.said.has("beach-ding"), kid_id + ": ding line")
		kit.done(t, scene)
	var jack: Dictionary = _game(t).merge_segment(_entry(t, "elevator"), "jack")
	t.check(str(jack["round_line"]) == "beach-floor-number", "jack: number line")
	t.check(str(_game(t).merge_segment(_entry(t, "elevator"), "becca")["round_line"]) == "beach-floor-color", "becca: color line")


# --- Hallway (Match, doors) and the room ---------------------------------------------

func test_hallway(t) -> void:
	for kid in [["jack", 4, "d7206"], ["becca", 2, "crab"]]:
		var kid_id: String = kid[0]
		var scene: Node2D = await _open(t, "hallway", kid_id)
		t.eq(scene.choice_ids().size(), kid[1], kid_id + ": doors")
		t.eq(scene.target(), kid[2], kid_id + ": the door on the key")
		t.eq(str(_game(t).segment["background"]), "res://assets/beach/beach-hallway.png", kid_id + ": hotel skin")
		t.check(kit.said.has("beach-find-room"), kid_id + ": start line")
		await kit.tap(t, scene.choice_point(_wrong(scene)))
		t.check(not kit.finished(t), kid_id + ": a wrong door stays shut")
		t.check(kit.said.has("not-this-door"), kid_id + ": wrong line")
		for scroll in 6:
			if scene.view_rect().has_point(scene.choice_point(kid[2])):
				break
			await kit.drag(t, Vector2(1500, 300), Vector2(700, 300))
		await kit.tap(t, scene.choice_point(kid[2]))
		t.check(kit.finished(t), kid_id + ": the right door")
		kit.done(t, scene)


func test_room(t) -> void:
	for kid_id in ["becca", "jack"]:
		var scene: Node2D = await _open(t, "room", kid_id)
		var seg: Dictionary = _game(t).segment
		t.eq(str(seg["prompt_line"]), "beach-tap-window", kid_id + ": prompt line")
		t.eq(seg["arrive_from"], seg["arrive_to"], kid_id + ": the door does not glide")
		t.check(kit.said.has("beach-our-room"), kid_id + ": the room line")
		await kit.tap(t, Vector2(100, 100))  # not the window: nothing happens
		t.check(not kit.finished(t) or scene.state != "gap", kid_id + ": waiting")
		for guard in 20:
			if kit.finished(t):
				break
			await kit.tap(t, scene.thing_point())
			await kit.wait(t, 0.4)
		t.check(kit.finished(t), kid_id + ": into the room")
		kit.done(t, scene)


# --- Jump the waves (Tap moments) ---------------------------------------------------

func test_waves(t) -> void:
	for kid in [["jack", 5], ["becca", 3]]:
		var kid_id: String = kid[0]
		var scene: Node2D = await _open(t, "waves", kid_id)
		t.eq(scene.moments(), kid[1], kid_id + ": waves")
		t.check(kit.said.has("beach-waves"), kid_id + ": start line")
		var home: Vector2 = scene.player.position
		# Any tap hops, wherever it lands, even before the wave arrives.
		await kit.tap(t, Vector2(300, 300))
		await kit.wait(t, 0.2)
		var hopped := false
		var end := Time.get_ticks_msec() + 20000
		while not kit.finished(t) and Time.get_ticks_msec() < end:
			if scene.state == "acting":
				hopped = true
			if scene.state == "ready":
				await kit.tap(t, Vector2(1000, 120))
			await t.tree.process_frame
		t.check(hopped, kid_id + ": a tap makes the kid hop")
		t.check(kit.finished(t), kid_id + ": every wave jumped")
		t.check(kit.said.has("beach-jumped"), kid_id + ": done line")
		t.check(scene.player.position.distance_to(home) < 5.0, kid_id + ": back on the sand")
		kit.done(t, scene)


# --- Sandcastle (Place) ---------------------------------------------------------------

func test_castle_and_decorate(t) -> void:
	for kid_id in ["jack", "becca"]:
		var n := 5 if kid_id == "jack" else 3
		var scene: Node2D = await _open(t, "castle", kid_id)
		t.eq(scene.item_ids().size(), n, kid_id + ": castle pieces")
		t.check(kit.said.has("beach-build"), kid_id + ": start line")
		var first: String = scene.item_ids()[0]
		var home: Vector2 = scene.item_point(first)
		await kit.drag(t, home, Vector2(1450, 120))
		await kit.wait(t, 0.5)
		t.check(not scene.is_placed(first) and scene.item_point(first).distance_to(home) < 2.0, kid_id + ": a piece dropped in the air slides back")
		for id in scene.item_ids():
			if not scene.is_placed(id):
				await kit.drag(t, scene.item_point(id), scene.slot_point(id))
				await kit.wait(t, 0.15)
		t.check(kit.finished(t), kid_id + ": castle built")
		kit.done(t, scene)
		scene = await _open(t, "decorate", kid_id)
		t.eq(scene.item_ids().size(), n, kid_id + ": shells")
		var shell_home: Vector2 = scene.item_point("sh1")
		await kit.drag(t, shell_home, Vector2(1450, 120))
		await kit.wait(t, 0.5)
		t.check(not scene.is_placed("sh1") and scene.item_point("sh1").distance_to(shell_home) < 2.0, kid_id + ": a shell dropped in the air slides back")
		var dots: Array[String] = []
		for sid in scene.slot_ids():
			if sid.begins_with("dot-"):
				dots.append(sid)
		for i in n:
			await kit.drag(t, scene.item_point("sh%d" % (i + 1)), scene.slot_point(dots[i]))
			await kit.wait(t, 0.15)
		t.check(kit.finished(t), kid_id + ": decorated")
		t.check(kit.said.has("beach-castle-done"), kid_id + ": done line")
		kit.done(t, scene)


# --- 1920x1200: everything the kid touches is on screen and inside the 16:10 area -----------

func _inside(t, scene: Node2D, r: Rect2, what: String) -> void:
	t.check(scene.view_rect().grow(1.0).encloses(r), "on screen: " + what)
	var local := Rect2(scene.stage.to_local(r.position), r.size / scene.stage.scale)
	t.check(Rect2(100, 0, 1472, 941).grow(1.0).encloses(local), "inside the safe area: %s %s" % [what, str(local)])


func test_layout_1920x1200(t) -> void:
	for kid_id in ["jack", "becca"]:
		var scene: Node2D = await _open(t, "trunk", kid_id, BIG)
		_inside(t, scene, scene.grid_rect(), kid_id + " grid")
		for id: String in scene.model.bag_ids:
			_inside(t, scene, scene.piece_rect(id), kid_id + " piece " + id)
		kit.done(t, scene)
		for seg in ["elevator", "hallway"]:
			scene = await _open(t, seg, kid_id, BIG)
			_inside(t, scene, scene.target_rect(), kid_id + " key card")
			var ids: Array[String] = scene.choice_ids()
			if seg == "elevator":
				for id in ids:
					_inside(t, scene, scene.choice_rect(id), kid_id + " button " + id)
			else:
				_inside(t, scene, scene.choice_rect(ids[0]), kid_id + " first door")
				for id in ids:
					t.check(scene.choice_rect(id).size.y >= 120.0, kid_id + " door is a big target")
			kit.done(t, scene)
		scene = await _open(t, "waves", kid_id, BIG)
		for _i in 400:
			if scene.state == "ready":
				break
			await t.tree.process_frame
		_inside(t, scene, scene.thing_rect(), kid_id + " wave")
		kit.done(t, scene)
		for seg in ["castle", "decorate"]:
			scene = await _open(t, seg, kid_id, BIG)
			for id: String in scene.item_ids():
				if scene.item_nodes[id].visible:
					_inside(t, scene, scene.item_rect(id), kid_id + " item " + id)
			for sid: String in scene.slot_ids():
				_inside(t, scene, scene.slot_rect(sid), kid_id + " slot " + sid)
			kit.done(t, scene)


# --- The whole chapter, then the finale ---------------------------------------------

## The finale: the map lights the route, the player moves on by itself to the celebration.
func _finale(t, pk) -> void:
	var game: Node = pk.game
	t.eq(game.last_scene_request, "res://scenes/map.tscn", "the map is the finale's segment")
	var map: Node2D = load("res://scenes/map.tscn").instantiate()
	t.tree.root.add_child(map)
	await t.tree.process_frame
	await t.tree.process_frame
	t.check(map.route_lit(), "the finale lights the route")
	t.check(map.stop_ids.has("beach") and map.stop_ids.has("car") and map.stop_ids.has("seaday"), "every built stop is on the route")
	var taps_before: String = game.last_scene_request
	await pk.tap(map.stop_point("car"))
	t.eq(game.last_scene_request, taps_before, "taps start nothing during the finale")
	var sfx: Node = t.tree.root.get_node("Sfx")
	var fanfare := {"heard": false}
	var moved: bool = await pk.until(func():
		fanfare["heard"] = fanfare["heard"] or sfx.last == "celebration-fanfare"
		return game.last_scene_request == game.INTRO, 20.0)
	t.check(fanfare["heard"], "the fanfare plays as the route finishes lighting")
	t.check(moved, "then the celebration clip")
	map.free()


func _chapter_for(t, kid_id: String) -> void:
	var pk := PLAY.new()
	pk.begin(t)
	pk.progress.mark_chapter_done(kid_id, "mission")
	for level in 4:
		pk.progress.mark_done(kid_id, level)
	for c: Dictionary in pk.game.chapters():
		if int(c["number"]) >= 7 and int(c["number"]) < 14 and not c.get("dropped", false) and not (c["segments"] as Array).is_empty():
			pk.progress.mark_chapter_done(kid_id, c["id"])
	pk.pick(kid_id)
	var map: Node2D = await pk.make_map()
	t.eq(map.next_stop(), "beach", kid_id + ": the beach is the last stop")
	await pk.tap(map.stop_point("beach"))
	t.check(pk.game.playing(), kid_id + ": tapping the stop starts the chapter")
	map.free()
	await pk.run("finale-map")
	var before: Array[String] = pk.order()
	t.eq(before, ["beach/beach-intro", "beach/trunk", "beach/elevator", "beach/hallway", "beach/room", "beach/waves", "beach/castle", "beach/decorate"] as Array[String], kid_id + ": segments before the finale")
	await _finale(t, pk)
	await pk.run()
	t.eq(pk.order().slice(before.size()), ["beach/celebration"] as Array[String], kid_id + ": then the celebration")
	t.check(pk.said.has("beach-replay"), kid_id + ": the map line after the clip")
	t.check(pk.progress.chapter_done(kid_id, "beach"), kid_id + ": chapter 14 done")
	t.eq(pk.requests.back(), pk.game.MAP, kid_id + ": back to the map")
	# On the map, everything can be replayed.
	map = await pk.make_map()
	t.check(map.stop_button("beach").get_node_or_null("Check") != null, kid_id + ": the stop is checked")
	for c: Dictionary in pk.game.chapters():
		if int(c["number"]) >= 7 and not c.get("dropped", false) and not (c["segments"] as Array).is_empty():
			t.check(map.stop_button(c["id"]).visible and map.stop_button(c["id"]).get_node_or_null("Check") != null, "%s: %s is checked and replayable" % [kid_id, c["id"]])
	await pk.tap(map.stop_point("beach"))
	map.free()
	t.check(pk.game.playing(), kid_id + ": a finished stop replays")
	pk.trace.clear()
	await pk.run("finale-map")
	t.eq(pk.order(), ["beach/trunk", "beach/elevator", "beach/hallway", "beach/room", "beach/waves", "beach/castle", "beach/decorate"] as Array[String], kid_id + ": the replay skips the once-clip")
	await _finale(t, pk)
	await pk.run()
	t.check(pk.progress.chapter_done(kid_id, "beach"), kid_id + ": still done after the replay")
	pk.end()


func test_playthrough_jack(t) -> void:
	await _chapter_for(t, "jack")


func test_playthrough_becca(t) -> void:
	await _chapter_for(t, "becca")


func test_hallway_and_room_end_with_a_line(t) -> void:
	for file in ["hallway", "room"]:
		var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/chapters/beach/%s.json" % file))
		t.check(str(d.get("done_line", "")) != "" and t.tree.root.get_node("Voice").has_line(str(d["done_line"])), "%s has a spoken done line" % file)
