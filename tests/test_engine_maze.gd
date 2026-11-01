# The Maze engine, driven with a finger on the face token.
extends RefCounted

const SCENE := "res://scenes/engines/maze.tscn"
const KIT := preload("res://tests/engine_kit.gd")

var kit := KIT.new()


## Safety drill: a fixed, easy layout with arrow signs; a wrong spot A; Becca gets footprints.
func _drill() -> Dictionary:
	return {"done_delay": 0.0, "hint_delay": 60.0, "start_line": "follow-the-arrows", "wrong_line": "not-this-one",
		"fixed": [
			"S.>..#A",
			"#.##.#.",
			"#.>....",
			"####.#G"],
		"decor": [{"texture": "res://assets/airport/maze-decor-planter.png", "cell": [0, 2]}],
		"becca": {"footprints": true}}


## A generated maze, like the airport gate maze.
func _generated() -> Dictionary:
	return {"done_delay": 0.0, "hint_delay": 60.0,
		"generate": {"size": [6, 4], "braid": 0.6, "loops": 2, "max_turns": 0, "gates": 3, "seed": 7},
		"decor": ["res://assets/airport/maze-decor-cart.png"],
		"goal_textures": ["res://assets/airport/gate-blue.png", "res://assets/airport/gate-red.png"],
		"becca": {"generate": {"size": [4, 3], "braid": 1.0, "loops": 0, "max_turns": 2, "gates": 1, "seed": 7},
			"footprints": true}}


func _route(scene: Node2D, goal: int) -> Array[Vector2]:
	var m: MazeModel = scene.maze
	var points: Array[Vector2] = [scene.token_position()]
	for c in m.path(scene.token_cell(), m.gates[goal]):
		points.append(scene.cell_center(c))
	return points


func test_setup_from_segment(t) -> void:
	var scene: Node2D = await kit.make(t, SCENE, _drill(), "jack")
	t.eq(scene.maze.size, Vector2i(7, 4), "the fixed layout")
	t.eq(scene.token_cell(), Vector2i(0, 0), "token on the start")
	t.eq(scene.maze.gates.size(), 2, "two spots")
	t.check(kit.said.has("follow-the-arrows"), "start line")
	t.eq(scene.maze.arrows.size(), 2, "arrow signs")
	kit.done(t, scene)
	scene = await kit.make(t, SCENE, _generated(), "jack")
	t.eq(scene.maze.gates.size(), 3, "jack-jack: three gates")
	kit.done(t, scene)
	scene = await kit.make(t, SCENE, _generated(), "becca")
	t.eq(scene.maze.size, Vector2i(4, 3), "becca: a smaller maze")
	t.eq(scene.maze.gates.size(), 1, "becca: one gate")
	kit.done(t, scene)


func test_right_move_along_a_corridor(t) -> void:
	var scene: Node2D = await kit.make(t, SCENE, _drill(), "jack")
	await kit.drag_through(t, [scene.token_position(), scene.cell_center(Vector2i(1, 0))] as Array[Vector2])
	t.eq(scene.token_cell(), Vector2i(1, 0), "followed the finger")
	t.check(not kit.finished(t), "not there yet")
	kit.done(t, scene)


func test_walls_stop_the_token(t) -> void:
	var scene: Node2D = await kit.make(t, SCENE, _drill(), "jack")
	await kit.drag_through(t, [scene.token_position(), scene.cell_center(Vector2i(0, 1))] as Array[Vector2])
	t.eq(scene.token_cell(), Vector2i(0, 0), "a wall below: the token stays")
	kit.done(t, scene)


func test_wrong_goal_says_the_line_and_goes_on(t) -> void:
	var scene: Node2D = await kit.make(t, SCENE, _drill(), "jack")
	await kit.drag_through(t, _route(scene, 0))
	t.eq(scene.token_cell(), scene.maze.gates[0], "at spot A")
	t.check(kit.said.has("not-this-one"), "the wrong line")
	t.check(not kit.finished(t), "not done")
	await kit.drag_through(t, _route(scene, scene.right_goal()))
	t.check(kit.finished(t), "then the meeting spot")
	kit.done(t, scene)


func test_done_for_both_kids(t) -> void:
	for data: Dictionary in [_drill(), _generated()]:
		for kid_id in ["becca", "jack"]:
			var scene: Node2D = await kit.make(t, SCENE, data, kid_id)
			await kit.drag_through(t, _route(scene, scene.right_goal()))
			t.check(kit.finished(t), "%s reached the right goal" % kid_id)
			kit.done(t, scene)


func test_hint_footprints_for_becca(t) -> void:
	var data := _drill()
	data["hint_delay"] = 0.2
	var scene: Node2D = await kit.make(t, SCENE, data, "becca")
	await kit.wait(t, 0.35)
	t.eq(scene.footprints_shown(), 3, "three footprints")
	t.check(kit.said.has("this-way"), "this way")
	kit.done(t, scene)
	scene = await kit.make(t, SCENE, data, "jack")
	await kit.wait(t, 0.35)
	t.eq(scene.footprints_shown(), 0, "no footprints for jack-jack")
	kit.done(t, scene)


func test_layout_fits_the_tablet(t) -> void:
	for data: Dictionary in [_drill(), _generated()]:
		var scene: Node2D = await kit.make(t, SCENE, data, "jack", Vector2i(1920, 1200))
		t.check(kit.on_screen(scene, scene.board_rect()), "the board is on screen: %s" % scene.board_rect())
		kit.done(t, scene)
