# The Place engine, played with real drags.
extends RefCounted

const SCENE := "res://scenes/engines/place.tscn"
const KIT := preload("res://tests/engine_kit.gd")

var kit := KIT.new()


## Dress up: the hat to the head, the sandals to the feet.
func _dress() -> Dictionary:
	return {"done_delay": 0.0, "hint_delay": 60.0, "start_line": "put-it-on", "player_feet": [800, 900],
		"items": [
			{"id": "hat", "texture": "res://assets/car/bag-mommy-purse.png", "slot": "head", "pos": [300, 800]},
			{"id": "sandals", "texture": "res://assets/car/bag-jack-backpack.png", "slot": "feet", "pos": [500, 800]}],
		"slots": [{"id": "head", "rect": [740, 300, 120, 100]}, {"id": "feet", "point": [800, 880], "size": 120}]}


## Sun safe: one sunscreen bottle, dabbed on every glowing spot (3 for Becca, 5 for Jack-Jack).
func _sun() -> Dictionary:
	var spots: Array = []
	for i in 5:
		spots.append({"id": "spot-%d" % i, "point": [500 + i * 150, 400], "size": 100})
	return {"done_delay": 0.0, "hint_delay": 60.0, "always_glow": true,
		"items": [{"id": "sunscreen", "texture": "res://assets/car/bag-mommy-purse.png", "reusable": true,
			"pos": [300, 800]}],
		"slots": spots, "becca": {"slots": spots.slice(0, 3)}}


## Sandcastle: bucket shapes into the outline, in order.
func _castle() -> Dictionary:
	return {"done_delay": 0.0, "hint_delay": 60.0, "ordered": true,
		"items": [{"id": "a", "texture": "res://assets/car/bag-jack-suitcase.png", "pos": [300, 800]},
			{"id": "b", "texture": "res://assets/car/bag-becca-suitcase.png", "pos": [600, 800]}],
		"slots": [{"id": "base", "rect": [700, 400, 200, 200], "accepts": "any"},
			{"id": "top", "rect": [1000, 400, 200, 200], "accepts": "any"}]}


func test_setup_from_segment(t) -> void:
	var scene: Node2D = await kit.make(t, SCENE, _sun(), "jack")
	t.eq(scene.slot_ids().size(), 5, "jack-jack: 5 spots")
	t.eq(scene.glows.shown().size(), 5, "every spot glows")
	kit.done(t, scene)
	scene = await kit.make(t, SCENE, _sun(), "becca")
	t.eq(scene.slot_ids().size(), 3, "becca: 3 spots")
	kit.done(t, scene)
	scene = await kit.make(t, SCENE, _dress(), "jack")
	t.check(kit.said.has("put-it-on"), "start line")
	t.check(scene.player != null, "the kid is there")
	kit.done(t, scene)


func test_right_slot_snaps_and_glows_while_held(t) -> void:
	var scene: Node2D = await kit.make(t, SCENE, _dress(), "jack")
	var from: Vector2 = scene.item_point("hat")
	var to: Vector2 = scene.slot_point("head")
	await kit.touch(t, true, from)
	for i in range(1, 5):
		await kit.move(t, from.lerp(to, i / 4.0))
	t.eq(scene.glows.shown().size(), 1, "only the head glows for the hat")
	await kit.touch(t, false, to)
	await kit.wait(t, 0.4)
	t.check(scene.is_placed("hat"), "placed")
	t.check(scene.item_point("hat").distance_to(to) < 2.0, "snapped to the head")
	t.check(scene.item_rect("hat").size.x <= scene.slot_rect("head").size.x + 1.0, "shrunk to the slot")
	t.check(not kit.finished(t), "sandals still to go")
	kit.done(t, scene)


func test_wrong_slot_wiggles_back(t) -> void:
	var scene: Node2D = await kit.make(t, SCENE, _dress(), "jack")
	var home: Vector2 = scene.item_point("hat")
	await kit.drag(t, home, scene.slot_point("feet"))
	await t.tree.process_frame
	t.check(absf((scene.item_nodes["hat"] as Node2D).rotation) > 0.0, "wiggling")
	await kit.wait(t, 0.45)
	t.check(not scene.is_placed("hat"), "not placed")
	t.check(scene.item_point("hat").distance_to(home) < 2.0, "slid back home")
	t.check(not kit.finished(t), "not done")
	kit.done(t, scene)


func test_dress_done(t) -> void:
	var scene: Node2D = await kit.make(t, SCENE, _dress(), "becca")
	await kit.drag(t, scene.item_point("hat"), scene.slot_point("head"))
	await kit.drag(t, scene.item_point("sandals"), scene.slot_point("feet"))
	t.check(kit.finished(t), "dressed")
	kit.done(t, scene)


func test_sunscreen_done_for_both_kids(t) -> void:
	for kid_id in ["becca", "jack"]:
		var scene: Node2D = await kit.make(t, SCENE, _sun(), kid_id)
		for sid: String in scene.slot_ids():
			t.check(not kit.finished(t), kid_id + ": not done before " + sid)
			await kit.drag(t, scene.item_point("sunscreen"), scene.slot_point(sid))
			await kit.wait(t, 0.35)
			t.check(scene.is_filled(sid), kid_id + ": dabbed " + sid)
		t.check(kit.finished(t), kid_id + ": every spot done")
		kit.done(t, scene)


func test_ordered_slots_fill_in_order(t) -> void:
	var scene: Node2D = await kit.make(t, SCENE, _castle(), "jack")
	await kit.drag(t, scene.item_point("a"), scene.slot_point("top"))
	await kit.wait(t, 0.4)
	t.check(not scene.is_placed("a"), "the top can't go first")
	await kit.drag(t, scene.item_point("a"), scene.slot_point("base"))
	await kit.drag(t, scene.item_point("b"), scene.slot_point("top"))
	t.check(kit.finished(t), "castle built")
	kit.done(t, scene)


func test_tap_sends_a_thing_to_its_slot(t) -> void:
	var scene: Node2D = await kit.make(t, SCENE, _dress(), "becca")
	await kit.tap(t, scene.item_point("sandals"))
	t.check(scene.is_placed("sandals"), "a tap puts it on")
	kit.done(t, scene)


func test_layout_fits_the_tablet(t) -> void:
	for data: Dictionary in [_dress(), _sun(), _castle()]:
		var scene: Node2D = await kit.make(t, SCENE, data, "jack", Vector2i(1920, 1200))
		for id: String in scene.item_ids():
			t.check(kit.on_screen(scene, scene.item_rect(id)), "%s on screen" % id)
		for id: String in scene.slot_ids():
			t.check(kit.on_screen(scene, scene.slot_rect(id)), "%s on screen" % id)
		kit.done(t, scene)


## Swimsuit on: the slot's picture is the kid; filled, it becomes the kid in the swimsuit.
func test_hide_marker_on_fill_swaps_the_slot_picture(t) -> void:
	var data := {"done_delay": 0.0, "hint_delay": 60.0,
		"items": [{"id": "swimsuit", "texture": "res://assets/car/bag-mommy-purse.png", "slot": "kid", "pos": [300, 800],
			"hide_on_place": true}],
		"slots": [{"id": "kid", "rect": [700, 200, 300, 500], "texture": "res://assets/characters/jack/idle.png",
			"fill_texture": "res://assets/characters/jack/cheer.png", "hide_marker_on_fill": true}]}
	var scene: Node2D = await kit.make(t, SCENE, data, "jack")
	var idle: Sprite2D = scene.get_node("Stage/Slots/kid")
	t.check(idle.visible, "the kid shows as the slot")
	await kit.drag(t, scene.item_point("swimsuit"), scene.slot_point("kid"))
	await kit.wait(t, 0.4)
	t.check(not idle.visible, "the idle picture goes")
	var filled: Sprite2D = scene.get_node_or_null("Stage/Slots/Filled-kid")
	t.check(filled != null and filled.visible, "the swimsuit picture takes its place")
	t.check(not (scene.item_nodes["swimsuit"] as Sprite2D).visible, "the swimsuit itself is put away")
	t.check(kit.finished(t), "done")
	kit.done(t, scene)
	(data["slots"][0] as Dictionary).erase("hide_marker_on_fill")
	scene = await kit.make(t, SCENE, data, "jack")
	await kit.drag(t, scene.item_point("swimsuit"), scene.slot_point("kid"))
	await kit.wait(t, 0.4)
	t.check((scene.get_node("Stage/Slots/kid") as Sprite2D).visible, "without the key the slot picture stays")
	kit.done(t, scene)


## Dress for dinner, then sit: the chair only shows once the outfit is on.
func test_appears_after_waits_for_its_slot(t) -> void:
	var data := {"done_delay": 0.0, "hint_delay": 60.0,
		"items": [{"id": "outfit", "texture": "res://assets/car/bag-mommy-purse.png", "slot": "kid", "pos": [300, 800]},
			{"id": "kid-token", "texture": "res://assets/car/bag-jack-backpack.png", "slot": "chair", "pos": [800, 800],
				"appears_after": "kid"}],
		"slots": [{"id": "kid", "point": [800, 400], "size": 160}, {"id": "chair", "point": [1200, 500], "size": 160}]}
	var scene: Node2D = await kit.make(t, SCENE, data, "becca")
	var waiting: Sprite2D = scene.item_nodes["kid-token"]
	t.check(not waiting.visible, "hidden at first")
	await kit.drag(t, scene.item_point("kid-token"), scene.slot_point("chair"))
	t.check(not scene.is_placed("kid-token"), "a hidden thing can't be moved")
	await kit.drag(t, scene.item_point("outfit"), scene.slot_point("kid"))
	await kit.wait(t, 0.4)
	t.check(waiting.visible, "shows once its slot is filled")
	t.check(not kit.finished(t), "still to place")
	await kit.drag(t, scene.item_point("kid-token"), scene.slot_point("chair"))
	t.check(kit.finished(t), "done")
	kit.done(t, scene)
