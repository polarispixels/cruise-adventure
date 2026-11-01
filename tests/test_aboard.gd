# Chapter 11, Welcome aboard: one test per segment (both kids), the fixed drill layouts, and a
# playthrough of the whole chapter through the real player. Data and engines only.
extends RefCounted

const KIT := preload("res://tests/engine_kit.gd")
const DIR := "res://data/chapters/aboard/"
const MATCH := "res://scenes/engines/match.tscn"
const MOMENTS := "res://scenes/engines/moments.tscn"
const MAZE := "res://scenes/engines/maze.tscn"

var kit := KIT.new()


func _seg(file: String) -> Dictionary:
	return {"data": DIR + file + ".json", "done_delay": 0.0, "hint_delay": 60.0}


func _route(scene: Node2D) -> Array[Vector2]:
	var m: MazeModel = scene.maze
	var points: Array[Vector2] = [scene.token_position()]
	for c in m.path(scene.token_cell(), m.gates[scene.right_goal()]):
		points.append(scene.cell_center(c))
	return points


func _wrong_id(scene: Node2D) -> String:
	for id: String in scene.choice_ids():
		if not scene.is_right(id):
			return id
	return ""


func test_registry_entry(t) -> void:
	var game: Node = t.tree.root.get_node("Game")
	var ch: Dictionary = game.chapter("aboard")
	var segs: Array = ch["segments"]
	t.eq(segs.size(), 6, "clip, key card, hallway, room, drill, clip")
	t.eq(str(segs[0]["name"]), "aboard-walk-on", "intro clip")
	t.eq(str(segs[5]["name"]), "aboard-sail-away", "payoff clip")
	t.check(ResourceLoader.exists("res://assets/stills/aboard-walk-on.png"), "intro still")
	t.check(ResourceLoader.exists("res://assets/stills/aboard-sail-away.png"), "payoff still")


func test_keycard_jack_four_faces(t) -> void:
	var scene: Node2D = await kit.make(t, MATCH, _seg("keycard"), "jack")
	t.eq(scene.choice_ids().size(), 4, "four family cards")
	t.eq(scene.target(), "jack", "his own face")
	t.check(scene.get_node("Stage/Choices/jack").get_node_or_null("Label") != null, "the card shows the room number")
	t.check(scene.get_node("Stage/Target").get_node_or_null("TargetLabel") != null, "and so does the target card")
	t.check(kit.said.has("get-keycard"), "start line")
	await kit.tap(t, scene.choice_point(_wrong_id(scene)))
	t.check(not scene.is_found("jack") and not kit.finished(t), "a wrong card slides back")
	t.check(kit.said.has("try-again"), "hmm line")
	await kit.tap(t, scene.choice_point("jack"))
	t.check(kit.finished(t), "his card done")
	t.check(kit.said.has("see-number"), "the number line")
	kit.done(t, scene)


func test_keycard_becca_two_faces(t) -> void:
	var scene: Node2D = await kit.make(t, MATCH, _seg("keycard"), "becca")
	t.eq(scene.choice_ids().size(), 2, "two cards")
	t.eq(scene.target(), "becca", "her face")
	t.check(scene.get_node("Stage/Choices/becca").get_node_or_null("Label") == null, "Becca's card has no number")
	await kit.tap(t, scene.choice_point(_wrong_id(scene)))
	t.check(not kit.finished(t), "wrong slides back")
	await kit.tap(t, scene.choice_point("becca"))
	t.check(kit.finished(t), "her card done")
	t.check(kit.said.has("see-sticker"), "the sticker line")
	kit.done(t, scene)


func test_hallway_jack_six_doors(t) -> void:
	var scene: Node2D = await kit.make(t, MATCH, _seg("hallway"), "jack")
	var ids: Array[String] = scene.choice_ids()
	t.eq(ids.size(), 6, "six doors")
	t.eq(scene.target(), "d8315", "the number on his card")
	t.check(scene.get_node("Stage/Target").get_node_or_null("Label") != null, "the card shows the number")
	t.check(kit.said.has("slide-hall"), "start line")
	await kit.drag(t, Vector2(1500, 300), Vector2(700, 300))
	t.check(not kit.finished(t), "a drag picks nothing")
	await kit.tap(t, scene.choice_point("d8312"))
	t.check(not kit.finished(t), "a wrong door stays shut")
	t.check(kit.said.has("not-this-door"), "wrong line")
	t.check(scene.view_rect().has_point(scene.choice_point("d8315")), "his door is on screen after scrolling")
	await kit.tap(t, scene.choice_point("d8315"))
	t.check(kit.finished(t), "the right door")
	kit.done(t, scene)


func test_hallway_becca_three_doors(t) -> void:
	var scene: Node2D = await kit.make(t, MATCH, _seg("hallway"), "becca")
	t.eq(scene.choice_ids().size(), 3, "three doors")
	t.eq(scene.target(), "crab", "the sticker on her card")
	t.check(kit.said.has("slide-hall"), "start line")
	await kit.tap(t, scene.choice_point("fish"))
	t.check(not kit.finished(t), "wrong door stays shut")
	await kit.tap(t, scene.choice_point("crab"))
	t.check(kit.finished(t), "the right door")
	kit.done(t, scene)


func test_room_reveal_both_kids(t) -> void:
	for kid_id in ["jack", "becca"]:
		var scene: Node2D = await kit.make(t, MOMENTS, _seg("room"), kid_id)
		t.eq(scene.moments(), 1, kid_id + ": one reveal")
		t.check(kit.said.has("our-room"), kid_id + ": the line is the start line, never skipped")
		await kit.tap(t, scene.thing_point())
		for i in 90:
			if kit.finished(t):
				break
			await t.tree.process_frame
		t.check(kit.finished(t), kid_id + ": room done")
		kit.done(t, scene)


func test_drill_layouts_are_solvable_and_easy(t) -> void:
	var game: Node = t.tree.root.get_node("Game")
	var want := {"jack": [Vector2i(6, 3), 3], "becca": [Vector2i(4, 2), 1]}
	for kid_id: String in want:
		var seg: Dictionary = game.merge_segment({"data": DIR + "drill.json"}, kid_id)
		var m := MazeModel.from_rows(seg["fixed"], "G", true)
		t.eq(m.size, want[kid_id][0], kid_id + ": layout size")
		var p := m.path(m.start, m.gates[m.correct])
		t.check(not p.is_empty(), kid_id + ": solvable")
		t.check(MazeModel.turns(p) <= int(want[kid_id][1]), kid_id + ": turns %d" % MazeModel.turns(p))
		t.eq(m.gates.size(), 1, kid_id + ": one meeting spot")
		t.check(m.arrows.size() >= 3, kid_id + ": arrow signs")
		t.check(bool(seg.get("fixed_thin_walls", false)), kid_id + ": thin walls, big cells")


func test_drill_jack_and_becca(t) -> void:
	for kid_id in ["jack", "becca"]:
		var scene: Node2D = await kit.make(t, MAZE, _seg("drill"), kid_id)
		t.check(kit.said.has("horn-warning"), kid_id + ": the warning line")
		t.check(bool(Game.segment.get("hold_input_until_intro", false)), kid_id + ": hands off until the intro is over")
		for i in 600:
			if scene.intro_done:
				break
			await t.tree.process_frame
		t.check(scene.intro_done, kid_id + ": the intro finishes")
		t.eq(Sfx.last, "ship-horn", kid_id + ": the horn")
		t.check(kit.said.has("follow-arrows"), kid_id + ": follow-arrows after the horn")
		t.eq(kit.said.find("horn-warning"), 0, kid_id + ": the warning comes first")
		t.check(kit.said.find("follow-arrows") > kit.said.find("horn-warning"), kid_id + ": and follow-arrows after it")
		t.check(scene.cell_px() >= 150.0, "%s: cells %.0f px" % [kid_id, scene.cell_px()])
		await kit.drag_through(t, [scene.token_position(), scene.cell_center(Vector2i(0, 0))] as Array[Vector2])
		t.eq(scene.token_cell(), scene.maze.start, kid_id + ": a wall stops the token")
		t.check(not kit.finished(t), kid_id + ": not yet")
		await kit.drag_through(t, _route(scene))
		t.check(kit.finished(t), kid_id + ": meeting spot reached")
		t.check(kit.said.has("all-together"), kid_id + ": together")
		kit.done(t, scene)
	var game: Node = t.tree.root.get_node("Game")
	t.check(bool(game.merge_segment({"data": DIR + "drill.json"}, "becca").get("footprints", false)), "Becca gets footprints")
	t.check(not bool(game.merge_segment({"data": DIR + "drill.json"}, "jack").get("footprints", false)), "Jack-Jack does not")


func test_fits_1920_by_1200(t) -> void:
	for file: String in ["keycard", "hallway"]:
		for kid_id in ["jack", "becca"]:
			var scene: Node2D = await kit.make(t, MATCH, _seg(file), kid_id, Vector2i(1920, 1200))
			t.check(kit.on_screen(scene, scene.target_rect()), "%s %s: target on screen" % [file, kid_id])
			var first: String = scene.choice_ids()[0]
			t.check(scene.view_rect().has_point(scene.choice_point(first)), "%s %s: first choice on screen" % [file, kid_id])
			kit.done(t, scene)
	for kid_id in ["jack", "becca"]:
		var maze: Node2D = await kit.make(t, MAZE, _seg("drill"), kid_id, Vector2i(1920, 1200))
		t.check(kit.on_screen(maze, maze.board_rect()), kid_id + ": drill board on screen")
		kit.done(t, maze)


## The whole chapter through the real player, with real touches.
func test_playthrough_both_kids(t) -> void:
	var game: Node = t.tree.root.get_node("Game")
	var progress: Node = t.tree.root.get_node("Progress")
	for kid_id in ["jack", "becca"]:
		progress.path = "user://test_progress_aboard.json"
		progress.reset()
		t.tree.root.size = Vector2i(1920, 1200)
		game.navigate = false
		game.stop_chapter()
		game.kid = load("res://data/%s.tres" % kid_id)
		game.play_chapter("aboard")
		var kinds: Array[String] = []
		for i in 6:
			var seg: Dictionary = game.segment
			if str(seg.get("kind", "")) == "clip":
				kinds.append("clip")
				game.segment_done()
				continue
			seg["done_delay"] = 0.0
			seg["hint_delay"] = 60.0
			var scene: Node2D = load(str(seg["scene"])).instantiate()
			t.tree.root.add_child(scene)
			await t.tree.process_frame
			await t.tree.process_frame
			kit.to_screen = t.tree.root.get_final_transform() * scene.get_canvas_transform()
			var id := str(seg["id"])
			kinds.append(id)
			var before: int = game.segment.get("index", -1)
			match id:
				"keycard":
					await kit.tap(t, scene.choice_point(kid_id))
				"hallway":
					await kit.drag(t, Vector2(1500, 300), Vector2(700, 300))
					await kit.tap(t, scene.choice_point(scene.target()))
				"room":
					await kit.tap(t, scene.thing_point())
					for k in 90:
						if game.last_segment_done or game.segment.get("index", -1) != before:
							break
						await t.tree.process_frame
				"drill":
					for k in 600:
						if scene.intro_done:
							break
						await t.tree.process_frame
					await kit.drag_through(t, _route(scene))
			scene.free()
			await t.tree.process_frame
		t.eq(kinds, ["clip", "keycard", "hallway", "room", "drill", "clip"] as Array[String], kid_id + ": every segment ran in order")
		t.check(progress.chapter_done(kid_id, "aboard"), kid_id + ": chapter marked done")
		game.stop_chapter()
	progress.reset()
	progress.path = "user://progress.json"
	t.tree.root.size = Vector2i(1920, 1080)
