# Shared helpers for the engine tests (not a test file itself): set up
# Game.segment for a kid, run an engine scene, and drive it with real touches
# (emulated as mouse events, as on the tablet).
extends RefCounted

var to_screen := Transform2D.IDENTITY
var said: Array[String] = []


## Runs `scene_path` with `segment` merged for `kid_id` (kid blocks honored, as the player does).
func make(t, scene_path: String, segment: Dictionary, kid_id := "jack", size := Vector2i(1920, 1080)) -> Node2D:
	var voice: Node = t.tree.root.get_node("Voice")
	voice.enabled = false
	voice.last_line = ""
	said.clear()
	if not voice.said.is_connected(_on_said):
		voice.said.connect(_on_said)
	t.tree.root.size = size
	var game: Node = t.tree.root.get_node("Game")
	game.navigate = false
	game.last_scene_request = ""
	game.stop_chapter()
	game.kid = load("res://data/%s.tres" % kid_id)
	var entry := segment.duplicate(true)
	entry["kind"] = "scene"
	entry["scene"] = scene_path
	game.segment = game.merge_segment(entry, kid_id)
	game.last_segment_done = false
	var scene: Node2D = load(scene_path).instantiate()
	t.tree.root.add_child(scene)
	await t.tree.process_frame
	await t.tree.process_frame
	to_screen = t.tree.root.get_final_transform() * scene.get_canvas_transform()
	return scene


func done(t, scene: Node) -> void:
	scene.free()
	t.tree.root.size = Vector2i(1920, 1080)
	var game: Node = t.tree.root.get_node("Game")
	game.segment = {}
	game.last_segment_done = false


func finished(t) -> bool:
	return t.tree.root.get_node("Game").last_segment_done


func _on_said(line: String) -> void:
	said.append(line)


func send(t, event: InputEvent) -> void:
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await t.tree.process_frame


func touch(t, pressed: bool, world: Vector2) -> void:
	var e := InputEventScreenTouch.new()
	e.pressed = pressed
	e.position = to_screen * world
	await send(t, e)


func move(t, world: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.position = to_screen * world
	e.relative = Vector2(1, 1)
	await send(t, e)


func tap(t, world: Vector2) -> void:
	await touch(t, true, world)
	await touch(t, false, world)


func drag(t, from: Vector2, to: Vector2, steps := 6) -> void:
	await touch(t, true, from)
	for i in range(1, steps + 1):
		await move(t, from.lerp(to, float(i) / steps))
	await touch(t, false, to)


## Drags through several world points.
func drag_through(t, points: Array[Vector2]) -> void:
	await touch(t, true, points[0])
	for i in range(1, points.size()):
		for k in range(1, 5):
			await move(t, points[i - 1].lerp(points[i], k / 4.0))
	await touch(t, false, points.back())


func wait(t, seconds: float) -> void:
	await t.tree.create_timer(seconds).timeout


## Whether a world rect is fully on screen.
func on_screen(scene: Node2D, r: Rect2) -> bool:
	return scene.view_rect().grow(1.0).encloses(r)
