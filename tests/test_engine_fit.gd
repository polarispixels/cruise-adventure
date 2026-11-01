# The Fit engine, played with real drags and taps.
extends RefCounted

const SCENE := "res://scenes/engines/fit.tscn"
const KIT := preload("res://tests/engine_kit.gd")

var kit := KIT.new()


## The overhead bin: Daddy's suitcase plus, for Jack-Jack, a backpack that needs a turn.
## Becca's backpack starts turned, her pieces show ghosts and turn themselves.
func _bin() -> Dictionary:
	return {"done_delay": 0.0, "hint_delay": 60.0, "start_line": "stow-bags",
		"grid": [3, 2], "area": [600, 200, 480, 320], "container_texture": "res://assets/airport/tray-empty.png",
		"pieces": [
			{"id": "daddy-gray", "size": [2, 2], "texture": "res://assets/car/bag-daddy-gray.png", "pos": [400, 780]},
			{"id": "jack-backpack", "size": [2, 1], "texture": "res://assets/car/bag-jack-backpack.png", "pos": [1200, 780]}],
		"becca": {"outlines": true, "auto_turn": true}}


## The minivan: 6 x 6, three blocked cells, the family's eight bags; Becca starts with the big ones in.
func _minivan() -> Dictionary:
	var bags: Array = (JSON.parse_string(FileAccess.get_file_as_string("res://data/trunk.json")) as Dictionary)["bags"]
	return {"done_delay": 0.0, "hint_delay": 60.0, "grid": [6, 6], "blocked": [[0, 5], [2, 5], [5, 5]],
		"pieces": bags, "container_texture": "res://assets/car/suv-open.png",
		"container_rect": [536, 20, 600, 480], "cargo_rect": [300, 380, 1400, 1000],
		"becca": {"preplaced": ["mommy-yellow", "daddy-gray"], "outlines": true, "auto_turn": true}}


## Drags every free piece to its reference spot (turning by tap first when needed).
func _solve(t, scene: Node2D) -> void:
	var m: TrunkModel = scene.model
	var ref := m.reference_solution()
	for id: String in m.bag_ids:
		if m.cell_of(id) != TrunkModel.NOWHERE:
			continue
		var turned: bool = ref[id]["turned"]
		if m.is_turned(id) != turned and not scene.data["auto_turn"]:
			await kit.tap(t, scene.piece_point(id))
			await kit.wait(t, 0.35)
		var to: Vector2 = scene.cell_center(ref[id]["cell"], m.size_of(id, turned))
		await kit.drag(t, scene.piece_point(id), to)
		await kit.wait(t, 0.05)


func test_setup_from_segment(t) -> void:
	var scene: Node2D = await kit.make(t, SCENE, _bin(), "jack")
	t.eq(scene.model.bag_ids.size(), 2, "two pieces")
	t.eq(Vector2i(scene.model.cols, scene.model.rows), Vector2i(3, 2), "the bin grid")
	t.eq(scene.ghost_ids().size(), 0, "no ghosts for jack-jack")
	t.check(kit.said.has("stow-bags"), "start line")
	t.check(scene.get_node("Stage/Container") != null, "the container is drawn")
	kit.done(t, scene)
	scene = await kit.make(t, SCENE, _minivan(), "becca")
	t.check(scene.is_locked("mommy-yellow") and scene.model.cell_of("mommy-yellow") != TrunkModel.NOWHERE, "preloaded")
	t.eq(scene.ghost_ids().size(), 6, "ghosts for the six bags left")
	kit.done(t, scene)


func test_tap_turns_a_waiting_piece(t) -> void:
	var scene: Node2D = await kit.make(t, SCENE, _bin(), "jack")
	t.check(not scene.model.is_turned("jack-backpack"), "standing")
	await kit.tap(t, scene.piece_point("jack-backpack"))
	t.check(scene.model.is_turned("jack-backpack"), "turned by a tap")
	kit.done(t, scene)


func test_right_drop_snaps_in(t) -> void:
	var scene: Node2D = await kit.make(t, SCENE, _bin(), "jack")
	var to: Vector2 = scene.cell_center(Vector2i(0, 0), Vector2i(2, 2))
	await kit.touch(t, true, scene.piece_point("daddy-gray"))
	for i in range(1, 5):
		await kit.move(t, scene.piece_point("daddy-gray").lerp(to, 0.5))
	t.eq(scene.glows.shown().size(), 1, "its spot glows while held")
	await kit.drag(t, scene.piece_point("daddy-gray"), to)
	await kit.wait(t, 0.35)
	t.eq(scene.model.cell_of("daddy-gray"), Vector2i(0, 0), "in the bin")
	t.check(scene.piece_point("daddy-gray").distance_to(to) < 2.0, "snapped")
	t.check(not kit.finished(t), "one to go")
	kit.done(t, scene)


func test_wrong_drop_slides_back(t) -> void:
	var scene: Node2D = await kit.make(t, SCENE, _bin(), "jack")
	var home: Vector2 = scene.waiting_point("daddy-gray")
	# Half off the right edge of the grid.
	await kit.drag(t, scene.piece_point("daddy-gray"), scene.cell_center(Vector2i(2, 0), Vector2i(2, 2)))
	await kit.wait(t, 0.4)
	t.eq(scene.model.cell_of("daddy-gray"), TrunkModel.NOWHERE, "not placed")
	t.check(scene.piece_point("daddy-gray").distance_to(home) < 2.0, "back where it waited")
	t.check(not kit.finished(t), "not done")
	kit.done(t, scene)


func test_backpack_needs_a_turn_for_jack(t) -> void:
	var scene: Node2D = await kit.make(t, SCENE, _bin(), "jack")
	await kit.drag(t, scene.piece_point("daddy-gray"), scene.cell_center(Vector2i(0, 0), Vector2i(2, 2)))
	# Standing (2 x 1) it can't go in the last column.
	await kit.drag(t, scene.piece_point("jack-backpack"), scene.cell_center(Vector2i(2, 0), Vector2i(1, 2)))
	await kit.wait(t, 0.4)
	t.check(not kit.finished(t), "not without turning")
	t.check(kit.said.has("turn-it"), "the helper says turn it")
	await _solve(t, scene)
	t.check(kit.finished(t), "full after a turn")
	kit.done(t, scene)


func test_done_for_both_kids(t) -> void:
	for data: Dictionary in [_bin(), _minivan()]:
		for kid_id in ["becca", "jack"]:
			var scene: Node2D = await kit.make(t, SCENE, data, kid_id)
			await _solve(t, scene)
			t.check(scene.model.is_full(), "%s full" % kid_id)
			t.check(kit.finished(t), "%s done" % kid_id)
			kit.done(t, scene)


func test_becca_auto_turn(t) -> void:
	var scene: Node2D = await kit.make(t, SCENE, _bin(), "becca")
	await kit.drag(t, scene.piece_point("daddy-gray"), scene.cell_center(Vector2i(0, 0), Vector2i(2, 2)))
	await kit.drag(t, scene.piece_point("jack-backpack"), scene.cell_center(Vector2i(2, 0), Vector2i(1, 2)))
	t.eq(scene.model.cell_of("jack-backpack"), Vector2i(2, 0), "turned itself and went in")
	t.check(kit.finished(t), "done")
	kit.done(t, scene)


func test_layout_fits_the_tablet(t) -> void:
	for data: Dictionary in [_bin(), _minivan()]:
		for kid_id in ["becca", "jack"]:
			var scene: Node2D = await kit.make(t, SCENE, data, kid_id, Vector2i(1920, 1200))
			t.check(kit.on_screen(scene, scene.grid_rect()), "grid on screen")
			for id: String in scene.model.bag_ids:
				t.check(kit.on_screen(scene, scene.piece_rect(id)), "%s %s on screen: %s" % [kid_id, id, scene.piece_rect(id)])
			kit.done(t, scene)
