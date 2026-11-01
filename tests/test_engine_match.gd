# The Match engine, played with real taps.
extends RefCounted

const SCENE := "res://scenes/engines/match.tscn"
const KIT := preload("res://tests/engine_kit.gd")

var kit := KIT.new()


## Find our seat: Jack-Jack matches a row number among 4 in a scrolling aisle; Becca a color among 3.
func _seat() -> Dictionary:
	return {
		"start_line": "find-our-seat", "done_line": "we-did-it", "done_delay": 0.0, "hint_delay": 60.0,
		"layout": "doors", "door_spacing": 520, "player_feet": [260, 920],
		"jack": {"key": "number", "target": "row-12", "choices": [
			{"id": "row-10", "texture": "res://assets/airport/tray-empty.png", "label": "10"},
			{"id": "row-11", "texture": "res://assets/airport/tray-empty.png", "label": "11"},
			{"id": "row-12", "texture": "res://assets/airport/tray-empty.png", "label": "12"},
			{"id": "row-13", "texture": "res://assets/airport/tray-empty.png", "label": "13"}]},
		"becca": {"key": "color", "layout": "row", "target": "pink", "choices": [
			{"id": "blue", "texture": "res://assets/airport/tray-empty.png", "color": "#3a7bd5"},
			{"id": "pink", "texture": "res://assets/airport/tray-empty.png", "color": "#ff7eb9"},
			{"id": "yellow", "texture": "res://assets/airport/tray-empty.png", "color": "#ffd23f"}]},
	}


## Shell hunt: rounds of the same shell picture, found among decoys.
func _shells() -> Dictionary:
	var choices: Array = []
	for i in 5:
		choices.append({"id": "shell-%d" % i, "match": "shell", "texture": "res://assets/art/star.png"})
	choices.append({"id": "rock-1", "texture": "res://assets/car/bag-mommy-purse.png"})
	choices.append({"id": "rock-2", "texture": "res://assets/car/bag-mommy-purse.png"})
	return {"layout": "grid", "columns": 4, "done_delay": 0.0, "hint_delay": 60.0, "round_delay": 0.0,
		"choices": choices, "key": "picture",
		"jack": {"rounds": ["shell", "shell", "shell", "shell", "shell"]},
		"becca": {"rounds": ["shell", "shell", "shell"], "count": 4}}


func test_setup_from_segment(t) -> void:
	var scene: Node2D = await kit.make(t, SCENE, _seat(), "jack")
	t.eq(scene.choice_ids().size(), 4, "jack-jack: 4 rows")
	t.eq(scene.target(), "row-12", "his row")
	t.check(kit.said.has("find-our-seat"), "start line")
	t.check(scene.get_node("Stage/Target").get_node_or_null("Label") != null, "the target shows the row number")
	kit.done(t, scene)
	scene = await kit.make(t, SCENE, _seat(), "becca")
	t.eq(scene.choice_ids().size(), 3, "becca: 3 seats")
	t.check(scene.get_node("Stage/Target").get_node_or_null("Sticker") != null, "the target shows a color sticker")
	t.check(scene.get_node("Home") != null, "home button")
	kit.done(t, scene)


func test_right_pick_finishes(t) -> void:
	var scene: Node2D = await kit.make(t, SCENE, _seat(), "becca")
	await kit.tap(t, scene.choice_point("pink"))
	t.check(scene.is_found("pink"), "found")
	t.check(kit.finished(t), "segment done")
	t.check(kit.said.has("we-did-it"), "done line")
	kit.done(t, scene)


func test_wrong_pick_wiggles_and_waits(t) -> void:
	var scene: Node2D = await kit.make(t, SCENE, _seat(), "becca")
	await kit.tap(t, scene.choice_point("blue"))
	await t.tree.process_frame
	t.check(not scene.is_found("blue"), "not taken")
	t.check(absf((scene.choice_nodes["blue"] as Node2D).rotation) > 0.0, "wiggling")
	t.check(not kit.finished(t), "not done")
	t.eq(scene.misses, 1, "a miss")
	await kit.tap(t, scene.choice_point("pink"))
	t.check(kit.finished(t), "then the right one finishes")
	kit.done(t, scene)


func test_hallway_scrolls_by_drag(t) -> void:
	var scene: Node2D = await kit.make(t, SCENE, _seat(), "jack")
	var start: float = scene.scroll()
	await kit.drag(t, Vector2(1500, 400), Vector2(700, 400))
	t.check(scene.scroll() < start - 100.0, "dragged the hallway left: %s -> %s" % [start, scene.scroll()])
	t.check(not kit.finished(t), "a drag picks nothing")
	t.check(scene.view_rect().has_point(scene.choice_point("row-12")), "row 12 on screen after scrolling")
	await kit.tap(t, scene.choice_point("row-12"))
	t.check(kit.finished(t), "tapped the right row")
	kit.done(t, scene)


func test_rounds_jack_and_becca(t) -> void:
	for kid_id in ["jack", "becca"]:
		var scene: Node2D = await kit.make(t, SCENE, _shells(), kid_id)
		var want := 5 if kid_id == "jack" else 3
		t.eq(scene.rounds(), want, kid_id + " rounds")
		if kid_id == "becca":
			t.eq(scene.choice_ids().size(), 4, "becca sees 4 things")
		var rock := "rock-1" if scene.choice_ids().has("rock-1") else "rock-2"
		if scene.choice_ids().has(rock):
			await kit.tap(t, scene.choice_point(rock))
		t.check(not kit.finished(t), kid_id + ": a rock is not a shell")
		var found := 0
		for id: String in scene.choice_ids():
			if id.begins_with("shell") and found < want:
				await kit.tap(t, scene.choice_point(id))
				await kit.wait(t, 0.05)
				found += 1
		t.check(kit.finished(t), kid_id + ": found every shell")
		kit.done(t, scene)


func test_hint_points_at_the_right_one(t) -> void:
	var seg := _seat()
	seg["hint_delay"] = 0.2
	var scene: Node2D = await kit.make(t, SCENE, seg, "becca")
	await kit.wait(t, 0.35)
	t.check(scene.is_pulsing(scene.choice_nodes["pink"]), "the right seat pulses")
	t.eq(scene.helper.pose, "point", "the helper points")
	kit.done(t, scene)


func test_layout_fits_the_tablet(t) -> void:
	for kid_id in ["jack", "becca"]:
		var scene: Node2D = await kit.make(t, SCENE, _seat(), kid_id, Vector2i(1920, 1200))
		for id: String in scene.choice_ids():
			if kid_id == "becca":
				t.check(kit.on_screen(scene, scene.choice_rect(id)), "%s on screen" % id)
		t.check(kit.on_screen(scene, scene.target_rect()), kid_id + ": target on screen")
		var home: TextureButton = scene.get_node("Home")
		t.check(kit.on_screen(scene, Rect2(home.position, home.size)), "home on screen")
		kit.done(t, scene)
	var grid: Node2D = await kit.make(t, SCENE, _shells(), "jack", Vector2i(1920, 1200))
	for id: String in grid.choice_ids():
		t.check(kit.on_screen(grid, grid.choice_rect(id)), "%s on screen" % id)
	kit.done(t, grid)
