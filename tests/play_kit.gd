# Shared by the playthrough tests (not a test file itself): plays chapters through
# the registry player (Game), instantiating each scene the player asks for and
# finishing it with real touches, the way a child does. Game.navigate stays off, so
# this loop is what changes scenes.
extends RefCounted

const Step := preload("res://scripts/room.gd").Step
const TMP := "user://test_playthrough_progress.json"
## What a kid does in security, per kid: item -> tray.
const TRAYS := {
	"jack": {"tablet": 0, "jack-backpack": 1, "mommy-purse": 1, "buddy": 2},
	"becca": {"becca-backpack": 0, "tablet": 1, "buddy": 2},
}

var t
var game: Node
var progress: Node
var voice: Node
var to_screen := Transform2D.IDENTITY
## One entry per scene the player asked for: {chapter, id, kind, scene, mode}.
var trace: Array[Dictionary] = []
var said: Array[String] = []
var requests: Array[String] = []
var _voice_was := true


## Fresh progress file, voice off, no navigation.
func begin(runner) -> void:
	t = runner
	game = t.tree.root.get_node("Game")
	progress = t.tree.root.get_node("Progress")
	voice = t.tree.root.get_node("Voice")
	progress.path = TMP
	progress.reset()
	_voice_was = voice.enabled
	voice.enabled = false
	voice.last_line = ""
	if not voice.said.is_connected(_on_said):
		voice.said.connect(_on_said)
	if not game.scene_requested.is_connected(_on_request):
		game.scene_requested.connect(_on_request)
	t.tree.root.size = Vector2i(1920, 1080)
	game.navigate = false
	game.last_scene_request = ""
	game.stop_chapter()
	game.use_chapters([])
	game.level = 0
	trace.clear()
	said.clear()
	requests.clear()


func end() -> void:
	game.stop_chapter()
	game.use_chapters([])
	game.stills_dir = "res://assets/stills/"
	progress.reset()
	progress.path = "user://progress.json"
	voice.enabled = _voice_was
	t.tree.root.size = Vector2i(1920, 1080)


func _on_said(line: String) -> void:
	said.append(line)


func _on_request(path: String) -> void:
	requests.append(path)


## The kid picks their name on the title screen. Their done clip is off (it is a long video).
func pick(kid_id: String) -> void:
	game.pick(kid_id)
	var kid: KidProfile = game.kid.duplicate()
	kid.done_video = ""
	game.kid = kid


## Plays the chapters the player is running until none is, or until it asks for the
## segment with id `stop_at` (which is left unplayed).
func run(stop_at := "") -> void:
	var guard := 0
	while game.playing() and guard < 40:
		guard += 1
		var seg: Dictionary = game.segment
		if stop_at != "" and seg.get("id", "") == stop_at:
			return
		var path: String = game.last_scene_request
		var scene: Node = load(path).instantiate()
		t.tree.root.add_child(scene)
		await t.tree.process_frame
		await t.tree.process_frame
		if scene is Node2D:
			to_screen = t.tree.root.get_final_transform() * (scene as Node2D).get_canvas_transform()
		var entry := {"chapter": seg.get("chapter", ""), "id": seg.get("id", ""), "kind": seg.get("kind", ""),
				"scene": path, "mode": ""}
		if path == game.INTRO:
			entry["mode"] = scene.mode
		trace.append(entry)
		match path:
			game.INTRO:
				await click(Vector2(960, 540))
			game.ROOM:
				await _room(scene)
			game.TRUNK:
				await _trunk(scene)
			game.CHECKIN:
				await _checkin(scene)
			game.SECURITY:
				await _security(scene)
			game.MAZE:
				await _maze(scene)
			_:
				t.check(false, "unexpected scene asked for: " + path)
				game.stop_chapter()
		var moved := await until(func(): return not game.playing() or game.segment != seg, 15.0)
		scene.free()
		if not moved:
			game.stop_chapter()
			return


## The map for the current kid and progress.
func make_map() -> Node2D:
	game.stop_chapter()
	var map: Node2D = load("res://scenes/map.tscn").instantiate()
	t.tree.root.add_child(map)
	await t.tree.process_frame
	await t.tree.process_frame
	to_screen = t.tree.root.get_final_transform() * map.get_canvas_transform()
	return map


## "chapter/segment" strings of the trace, for comparing orders.
func order() -> Array[String]:
	var out: Array[String] = []
	for e in trace:
		out.append("%s/%s" % [e["chapter"], e["id"]])
	return out


# --- input ---------------------------------------------------------------

func send(event: InputEvent) -> void:
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await t.tree.process_frame


func click(screen: Vector2) -> void:
	for pressed in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = pressed
		e.position = screen
		e.global_position = screen
		await send(e)


func touch(pressed: bool, world: Vector2) -> void:
	var e := InputEventScreenTouch.new()
	e.pressed = pressed
	e.position = to_screen * world
	await send(e)


func move(world: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.position = to_screen * world
	e.relative = Vector2(1, 1)
	await send(e)


func tap(world: Vector2) -> void:
	await touch(true, world)
	await touch(false, world)


func drag(from: Vector2, to: Vector2) -> void:
	await touch(true, from)
	for i in range(1, 6):
		await move(from.lerp(to, i / 5.0))
	await touch(false, to)


func drag_through(points: Array[Vector2]) -> void:
	await touch(true, points[0])
	for i in range(1, points.size()):
		for k in range(1, 5):
			await move(points[i - 1].lerp(points[i], k / 4.0))
	await touch(false, points.back())


func wait(seconds: float) -> void:
	await t.tree.create_timer(seconds).timeout


## Waits (frame by frame) until cond() is true; false after `timeout` seconds.
func until(cond: Callable, timeout := 5.0) -> bool:
	var end := Time.get_ticks_msec() + timeout * 1000
	while not cond.call():
		if Time.get_ticks_msec() > end:
			t.check(false, "timed out waiting")
			return false
		await t.tree.process_frame
	return true


func button_center(b: TextureButton) -> Vector2:
	return b.global_position + b.size / 2


## Taps a finish-screen button once it is enabled.
func press(b: TextureButton) -> void:
	await until(func(): return b.is_visible_in_tree() and not b.disabled, 10.0)
	await tap(button_center(b))


# --- the room ------------------------------------------------------------

func _room(room: Node2D) -> void:
	var view: DrawerView = room.get_node("DrawerView")
	var guard := 0
	while room.step != Step.DONE and guard < 400:
		guard += 1
		var at: int = room.step
		match at:
			Step.START:
				await tap(room.suitcase_point())
				await until(func(): return room.step != at)
			Step.OPENED:
				await tap(room.dresser_point())
				await until(func(): return room.step != at)
			Step.FINDING:
				if not await until(func(): return view.visible and view.correct_choice() != null):
					return
				var item := view.correct_choice()
				item.begin_drag(item.global_position)
				item.drag_to(view.TARGET_CENTER)
				item.end_drag(view.TARGET_CENTER)
				var done_id := item.get_instance_id()
				await until(func(): return room.step != at or (view.visible and view.correct_choice() != null \
						and view.correct_choice().get_instance_id() != done_id))
			Step.ROLL:
				await tap(room.layup_point())
				await until(func(): return room.step != at)
			Step.PACK_BUNDLE:
				var bundle: Draggable = room.get_node("Stage/Bundle")
				await drag(bundle.global_position + Vector2(0, 5), bundle.snap_point)
				await until(func(): return room.step != at)
			Step.CLOSE:
				await tap(room.suitcase_point())
				await until(func(): return room.step != at)
			Step.PACK_ITEMS:
				var loose: Array = room.loose_items()
				if loose.is_empty():
					await until(func(): return room.step != at)
				else:
					var piece: Draggable = loose[0]
					await drag(piece.global_position, piece.snap_point)
					var left: int = loose.size() - 1
					await until(func(): return room.step != at or room.loose_items().size() == left)
			Step.ZIP:
				var zipper: Zipper = room.get_node("Stage/Suitcase/Zipper")
				await drag(zipper.to_global(zipper.start), zipper.to_global(zipper.end))
				await until(func(): return room.step != at)
	await until(func(): return room.get_node("Finish").visible, 10.0)
	await press(room.get_node("Finish/ContinueButton"))


# --- the trunk -----------------------------------------------------------

func _trunk(trunk: Node2D) -> void:
	trunk.payoff_video = ""
	var ref: Dictionary = trunk.model.reference_solution()
	for id: String in ref:
		if trunk.model.cell_of(id) != TrunkModel.NOWHERE:
			continue  # already in (Becca's two big bags)
		trunk.model.set_turned(id, ref[id]["turned"])
		trunk.bag(id).set_turned(ref[id]["turned"])
		var size: Vector2i = trunk.model.size_of(id, trunk.model.is_turned(id))
		await drag(trunk.bag(id).global_position, trunk.cell_center(ref[id]["cell"], size))
		await wait(0.6)
	t.check(trunk.model.is_full(), "trunk full")
	await tap(trunk.hatch_point())
	await press(trunk.get_node("Finish/ContinueButton"))


# --- the airport ---------------------------------------------------------

func _checkin(scene: Node2D) -> void:
	for id: String in game.kid.airport_bags:
		await drag(scene.tag_point(scene.TAG_COLOR[id]), scene.bag_point(id))
		await drag(scene.bag_point(id), scene.scale_point())
	# The scene says goodbye, then calls Game.segment_done() by itself: run() waits for it.


func _scan(scene: Node2D, plan: Dictionary) -> void:
	for id: String in plan:
		await drag(scene.item_point(id), scene.tray_point(plan[id]))
		await wait(0.4)
	var trays := {}
	for id: String in plan:
		trays[plan[id]] = true
	for tray: int in trays:
		await tap(scene.tray_point(tray))
		await wait(scene.SCAN_TIME + 0.6)


func _security(scene: Node2D) -> void:
	var plan: Dictionary = TRAYS[game.kid.id]
	await _scan(scene, plan)
	await tap(scene.arch_point())
	await wait(scene.WALK_TIME + 0.3)
	for id: String in plan:
		if id.ends_with("-backpack") or id == "buddy":
			continue
		await drag(scene.item_point(id), scene.backpack_point())
		await wait(0.4)
	await drag(scene.item_point("buddy"), scene.kid_point())
	# After the hug the scene calls Game.segment_done() by itself: run() waits for it.


func _maze(maze: Node2D) -> void:
	maze.payoff_video = ""
	var m: MazeModel = maze.maze
	var cells := m.path(m.start, m.gates[m.correct])
	var points: Array[Vector2] = [maze.token_position()]
	for c in cells:
		points.append(maze.cell_center(c))
	points.append(maze.gate_point(m.correct))
	await drag_through(points)
	await press(maze.get_node("Finish/ContinueButton"))
