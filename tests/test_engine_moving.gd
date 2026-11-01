# The Moving targets engine, played with real taps.
extends RefCounted

const SCENE := "res://scenes/engines/moving.tscn"
const KIT := preload("res://tests/engine_kit.gd")

var kit := KIT.new()


## The baggage carousel: Becca taps her pink suitcase (slow, different decoys);
## Jack-Jack taps all three family bags among similar ones.
func _carousel() -> Dictionary:
	return {"done_delay": 0.0, "hint_delay": 60.0, "start_line": "spot-our-bags", "path": "loop",
		"items": [
			{"id": "jack-suitcase", "texture": "res://assets/car/bag-jack-suitcase.png"},
			{"id": "becca-suitcase", "texture": "res://assets/car/bag-becca-suitcase.png"},
			{"id": "mommy-yellow", "texture": "res://assets/car/bag-mommy-yellow.png"},
			{"id": "decoy-1", "texture": "res://assets/car/bag-daddy-gray.png"},
			{"id": "decoy-2", "texture": "res://assets/car/bag-daddy-backpack.png"}],
		"jack": {"targets": ["jack-suitcase", "becca-suitcase", "mommy-yellow"], "speed": 160},
		"becca": {"targets": ["becca-suitcase"], "speed": 70}}


## Floating toys drifting left to right.
func _toys() -> Dictionary:
	return {"done_delay": 0.0, "hint_delay": 60.0, "path": "drift", "lanes": [560, 720], "speed": 2000,
		"items": [{"id": "duck", "texture": "res://assets/art/star.png", "target": true},
			{"id": "ball", "texture": "res://assets/art/star.png", "target": true},
			{"id": "rock", "texture": "res://assets/car/bag-mommy-purse.png"}]}


func test_setup_from_segment(t) -> void:
	var scene: Node2D = await kit.make(t, SCENE, _carousel(), "jack")
	t.eq(scene.targets().size(), 3, "jack-jack: three bags")
	t.check(kit.said.has("spot-our-bags"), "start line")
	kit.done(t, scene)
	scene = await kit.make(t, SCENE, _carousel(), "becca")
	t.eq(scene.targets(), ["becca-suitcase"] as Array[String], "becca: her pink suitcase")
	kit.done(t, scene)


func test_things_move(t) -> void:
	var scene: Node2D = await kit.make(t, SCENE, _carousel(), "jack")
	var before: Vector2 = scene.item_point("decoy-1")
	await kit.wait(t, 0.3)
	t.check(scene.item_point("decoy-1").distance_to(before) > 5.0, "the carousel turns")
	kit.done(t, scene)


func test_right_tap_takes_the_bag(t) -> void:
	var scene: Node2D = await kit.make(t, SCENE, _carousel(), "jack")
	await kit.tap(t, scene.item_point("jack-suitcase"))
	t.check(scene.is_tapped("jack-suitcase"), "got it")
	t.check(not kit.finished(t), "two to go")
	kit.done(t, scene)


func test_decoy_wiggles(t) -> void:
	var scene: Node2D = await kit.make(t, SCENE, _carousel(), "becca")
	await kit.tap(t, scene.item_point("decoy-1"))
	await t.tree.process_frame
	t.check(not scene.is_tapped("decoy-1"), "not taken")
	t.check(absf((scene.item_nodes["decoy-1"] as Node2D).rotation) > 0.0, "wiggles")
	t.check(not kit.finished(t), "not done")
	kit.done(t, scene)


func test_done_for_both_kids(t) -> void:
	for kid_id in ["becca", "jack"]:
		var scene: Node2D = await kit.make(t, SCENE, _carousel(), kid_id)
		for id: String in scene.targets():
			await kit.tap(t, scene.item_point(id))
		t.check(kit.finished(t), kid_id + ": every bag spotted")
		kit.done(t, scene)


func test_drifting_toys_come_back_around(t) -> void:
	var scene: Node2D = await kit.make(t, SCENE, _toys(), "jack")
	var seen_left := false
	var last: float = scene.item_point("duck").x
	for i in 30:
		await kit.wait(t, 0.05)
		var x: float = scene.item_point("duck").x
		if x < last:
			seen_left = true
		last = x
	t.check(seen_left, "a toy that drifts off re-enters from the left")
	await kit.tap(t, scene.item_point("duck"))
	await kit.tap(t, scene.item_point("ball"))
	t.check(kit.finished(t), "both toys")
	kit.done(t, scene)


func test_hint_pulses_a_target(t) -> void:
	var data := _carousel()
	data["hint_delay"] = 0.2
	var scene: Node2D = await kit.make(t, SCENE, data, "becca")
	await kit.wait(t, 0.35)
	t.check(scene.is_pulsing(scene.item_nodes["becca-suitcase"]), "her suitcase pulses")
	kit.done(t, scene)


func test_layout_fits_the_tablet(t) -> void:
	var scene: Node2D = await kit.make(t, SCENE, _carousel(), "jack", Vector2i(1920, 1200))
	for i in 30:
		await t.tree.process_frame
		for id: String in scene.item_ids():
			t.check(kit.on_screen(scene, scene.item_rect(id)), "%s stays on screen" % id)
	kit.done(t, scene)


func test_tap_effect_shows_briefly_where_the_target_was(t) -> void:
	var data := _toys()
	data["path"] = "still"
	data["speed"] = 0
	data["items"] = [{"id": "jet", "texture": "res://assets/art/star.png", "target": true, "pos": [600, 500]},
		{"id": "jet2", "texture": "res://assets/art/star.png", "target": true, "pos": [1000, 500]}]
	data["tap_effect"] = "res://assets/art/star.png"
	data["tap_effect_sound"] = "whoosh"
	var sfx: Node = t.tree.root.get_node("Sfx")
	var scene: Node2D = await kit.make(t, SCENE, data, "becca")
	var at: Vector2 = scene.item_point("jet")
	await kit.tap(t, at)
	var fx: Sprite2D = scene.get_node_or_null("Stage/TapEffect")
	t.check(fx != null, "the spray shows")
	if fx:
		t.check(scene.stage.to_global(fx.position).distance_to(at) < 2.0, "where the jet was tapped")
	t.eq(sfx.last, "whoosh", "with its sound")
	await kit.wait(t, 0.6)
	t.check(scene.get_node_or_null("Stage/TapEffect") == null, "and goes after a moment")
	kit.done(t, scene)


func test_no_tap_effect_without_the_key(t) -> void:
	var scene: Node2D = await kit.make(t, SCENE, _carousel(), "jack")
	await kit.tap(t, scene.item_point("jack-suitcase"))
	t.check(scene.get_node_or_null("Stage/TapEffect") == null, "nothing extra")
	kit.done(t, scene)


## The splash zone: two still jets plus drifting toys. The toys are spaced among
## themselves, so each comes on screen; the hint never points at a jet or off screen.
func test_drift_span_counts_only_drifting_things(t) -> void:
	var data := {"done_delay": 0.0, "hint_delay": 60.0, "path": "drift", "lanes": [600], "spacing": 380, "speed": 0,
		"items": [{"id": "jet-1", "texture": "res://assets/art/star.png", "pos": [300, 300], "target": true},
			{"id": "jet-2", "texture": "res://assets/art/star.png", "pos": [1300, 300], "target": true},
			{"id": "jet-3", "texture": "res://assets/art/star.png", "pos": [800, 300]},
			{"id": "duck", "texture": "res://assets/art/star.png", "target": true},
			{"id": "ball", "texture": "res://assets/art/star.png", "target": true},
			{"id": "boat", "texture": "res://assets/art/star.png", "target": true}]}
	var scene: Node2D = await kit.make(t, SCENE, data, "jack")
	var xs: Array = []
	for id in ["duck", "ball", "boat"]:
		xs.append(scene.stage.to_local(scene.item_point(id)).x)
	t.eq(xs, [0.0 + 100 - 380, 100.0, 100.0 + 380], "spaced among the drifting ones only")
	scene._show_hint()
	t.check(not ["jet-1", "jet-2"].has(scene._hint), "no jet while a toy is left: %s" % scene._hint)
	t.check(scene._hint != "duck", "never a toy off screen")
	kit.done(t, scene)
