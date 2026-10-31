# The gate maze, driven the way a child does: a finger on the face token.
extends RefCounted

var _to_screen := Transform2D.IDENTITY
var _requests: Array[String] = []


func _make(t, kid_id := "jack", seed_value := 7, size := Vector2i(1920, 1080), hint_delay := 30.0) -> Node2D:
	var progress: Node = t.tree.root.get_node("Progress")
	progress.path = "user://test_maze_progress.json"
	progress.reset()
	t.tree.root.get_node("Voice").enabled = false
	t.tree.root.get_node("Voice").last_line = ""
	t.tree.root.size = size
	var game: Node = t.tree.root.get_node("Game")
	game.navigate = false
	game.last_scene_request = ""
	_requests.clear()
	if not game.scene_requested.is_connected(_on_request):
		game.scene_requested.connect(_on_request)
	var kid: KidProfile = load("res://data/%s.tres" % kid_id).duplicate()
	kid.maze_hint_delay = hint_delay
	game.kid = kid
	var script: GDScript = load("res://scripts/maze.gd")
	script.next_seed = seed_value
	var maze: Node2D = load("res://scenes/maze.tscn").instantiate()
	t.tree.root.add_child(maze)
	await t.tree.process_frame
	await t.tree.process_frame
	_to_screen = t.tree.root.get_final_transform() * maze.get_canvas_transform()
	return maze


func _done(t, maze: Node) -> void:
	maze.free()
	var progress: Node = t.tree.root.get_node("Progress")
	progress.reset()
	progress.path = "user://progress.json"
	t.tree.root.size = Vector2i(1920, 1080)


func _on_request(path: String) -> void:
	_requests.append(path)


func _send(t, event: InputEvent) -> void:
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await t.tree.process_frame


func _touch(t, pressed: bool, world: Vector2) -> void:
	var e := InputEventScreenTouch.new()
	e.pressed = pressed
	e.position = _to_screen * world
	await _send(t, e)


func _move(t, world: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.position = _to_screen * world
	e.relative = Vector2(1, 1)
	await _send(t, e)


func _tap(t, world: Vector2) -> void:
	await _touch(t, true, world)
	await _touch(t, false, world)


## Drags the token through these world points, a few steps between each.
func _drag_through(t, points: Array[Vector2], release := true) -> void:
	await _touch(t, true, points[0])
	for i in range(1, points.size()):
		for k in range(1, 5):
			await _move(t, points[i - 1].lerp(points[i], k / 4.0))
	if release:
		await _touch(t, false, points.back())


func _route_to_gate(maze: Node2D, gate: int) -> Array[Vector2]:
	var m: MazeModel = maze.maze
	var cells := m.path(m.start, m.gates[gate])
	var points: Array[Vector2] = [maze.token_position()]
	for c in cells:
		points.append(maze.cell_center(c))
	points.append(maze.gate_point(gate))
	return points


func _voice(t) -> String:
	return t.tree.root.get_node("Voice").last_line


func test_says_find_gate_and_jack_matches_the_airplane(t) -> void:
	var maze := await _make(t, "jack")
	t.eq(_voice(t), "match-airplane", "jack-jack: find the airplane on your ticket")
	t.check(maze.get_node("BoardingPass").visible, "his boarding pass")
	_done(t, maze)
	maze = await _make(t, "becca")
	t.eq(_voice(t), "find-gate", "becca: let's find our gate")
	t.check(not maze.get_node("BoardingPass").visible, "no boarding pass for becca")
	_done(t, maze)


func test_token_starts_at_the_start(t) -> void:
	var maze := await _make(t, "jack")
	t.check(maze.token_position().distance_to(maze.cell_center(maze.maze.start)) < 1.0, "on the start cell")
	_done(t, maze)


func test_drag_moves_along_a_corridor(t) -> void:
	var maze := await _make(t, "jack")
	var m: MazeModel = maze.maze
	var next: Vector2i = m.exits(m.start)[0]
	await _drag_through(t, [maze.token_position(), maze.cell_center(next)] as Array[Vector2])
	t.check(maze.token_position().distance_to(maze.cell_center(next)) < 2.0, "followed the finger to the next cell")
	_done(t, maze)


func test_token_never_crosses_a_wall(t) -> void:
	var maze := await _make(t, "jack", 11)
	var m: MazeModel = maze.maze
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	await _touch(t, true, maze.token_position())
	var bad := 0
	for i in 120:
		var view: Rect2 = maze.view_rect()
		var p := Vector2(rng.randf_range(view.position.x, view.end.x), rng.randf_range(view.position.y, view.end.y))
		if i % 3 == 0:
			p = maze.token_position() + Vector2(rng.randf_range(-250, 250), rng.randf_range(-250, 250))
		await _move(t, p)
		var seg: Array = maze.token_segment()
		if not maze.connected(seg[0], seg[1]):
			bad += 1
	await _touch(t, false, maze.token_position())
	t.eq(bad, 0, "always on an open corridor")
	_done(t, maze)


func test_press_off_the_token_does_nothing(t) -> void:
	var maze := await _make(t, "jack")
	var at: Vector2 = maze.token_position()
	await _drag_through(t, [at + Vector2(0, 400), at + Vector2(400, 400)] as Array[Vector2])
	t.check(maze.token_position().distance_to(at) < 1.0, "only a finger on the token moves it")
	_done(t, maze)


func test_lifting_leaves_the_token(t) -> void:
	var maze := await _make(t, "jack")
	var m: MazeModel = maze.maze
	var next: Vector2i = m.exits(m.start)[0]
	await _drag_through(t, [maze.token_position(), maze.cell_center(next)] as Array[Vector2])
	await t.tree.create_timer(0.3).timeout
	t.check(maze.token_position().distance_to(maze.cell_center(next)) < 2.0, "it stays where the finger left it")
	_done(t, maze)


func test_reaching_the_right_gate_finishes(t) -> void:
	var maze := await _make(t, "jack")
	maze.payoff_video = ""
	await _drag_through(t, _route_to_gate(maze, maze.maze.correct))
	await t.tree.create_timer(0.3).timeout
	t.check(maze.finished, "found the gate")
	t.eq(_voice(t), "found-gate", "we found our gate")
	t.check(t.tree.root.get_node("Progress").airport_done("jack"), "remembered")
	t.check(maze.get_node("Finish").visible, "finish buttons")
	_done(t, maze)


func test_wrong_gate_says_not_this_one(t) -> void:
	var maze := await _make(t, "jack")
	var wrong: int = (maze.maze.correct + 1) % maze.maze.gates.size()
	await _drag_through(t, _route_to_gate(maze, wrong))
	t.eq(_voice(t), "not-this-one", "not this one")
	t.check(not maze.finished, "keep looking")
	_done(t, maze)


func test_becca_footprints_hint(t) -> void:
	var maze := await _make(t, "becca", 3, Vector2i(1920, 1080), 0.3)
	await t.tree.create_timer(0.7).timeout
	t.eq(_voice(t), "this-way", "this way")
	var prints: Node2D = maze.get_node("Footprints")
	t.eq(prints.get_children().filter(func(n): return n.visible).size(), 3, "footprints on the next three cells")
	_done(t, maze)
	maze = await _make(t, "jack", 3, Vector2i(1920, 1080), 0.3)
	await t.tree.create_timer(0.7).timeout
	t.eq(_voice(t), "this-way", "jack-jack gets the line too")
	t.eq(maze.get_node("Footprints").get_children().filter(func(n): return n.visible).size(), 0, "but no footprints")
	_done(t, maze)


func test_layout_fits_16_9_and_16_10(t) -> void:
	for size in [Vector2i(1920, 1080), Vector2i(1920, 1200)]:
		for kid_id in ["jack", "becca"]:
			var maze := await _make(t, kid_id, 9, size)
			var view: Rect2 = maze.view_rect()
			var m: MazeModel = maze.maze
			t.check(view.encloses(maze.maze_rect()), "%s maze on screen at %s" % [kid_id, size])
			for i in m.gates.size():
				t.check(view.has_point(maze.gate_point(i)), "%s gate %d on screen" % [kid_id, i])
			var pass_node: Sprite2D = maze.get_node("BoardingPass")
			if pass_node.visible:
				t.check(view.encloses(maze.pass_rect()), "boarding pass on screen")
				t.check(not maze.maze_rect().intersects(maze.pass_rect()), "boarding pass clear of the maze")
			t.check(maze.cell_px() >= 140.0, "%s cells big enough for a finger: %s" % [kid_id, maze.cell_px()])
			_done(t, maze)


func test_finish_buttons(t) -> void:
	var game: Node = t.tree.root.get_node("Game")
	for pair in [["HomeButton", game.TITLE], ["ReplayButton", game.MAZE], ["ContinueButton", game.MAP]]:
		var maze := await _make(t, "becca")
		maze.payoff_video = ""
		await _drag_through(t, _route_to_gate(maze, maze.maze.correct))
		await t.tree.create_timer(0.3).timeout
		var button: TextureButton = maze.get_node("Finish/" + pair[0])
		await _tap(t, button.global_position + button.size / 2)
		t.eq(game.last_scene_request, pair[1], pair[0])
		_done(t, maze)


func test_double_tap_keeps_the_payoff_clip(t) -> void:
	var maze := await _make(t, "becca")
	maze.payoff_video = "res://assets/video/becca-done.ogv"
	await _drag_through(t, _route_to_gate(maze, maze.maze.correct))
	await _tap(t, Vector2(960, 540))
	await t.tree.create_timer(0.2).timeout
	t.check(maze.get_node("PayoffVideo").visible, "the clip keeps playing")
	await t.tree.create_timer(0.8).timeout
	await _tap(t, Vector2(960, 540))
	t.check(maze.get_node("Finish").visible, "a later tap skips it")
	_done(t, maze)


func test_home_button_while_playing(t) -> void:
	var maze := await _make(t, "jack")
	var button: TextureButton = maze.get_node("PlayHome")
	await _tap(t, button.global_position + button.size / 2)
	t.eq(t.tree.root.get_node("Game").last_scene_request, "res://scenes/title.tscn", "home")
	_done(t, maze)
