# The Tap moments engine, played with real taps.
extends RefCounted

const SCENE := "res://scenes/engines/moments.tscn"
const KIT := preload("res://tests/engine_kit.gd")

var kit := KIT.new()


## Jump the waves: Becca 2 waves, Jack-Jack 3.
func _waves() -> Dictionary:
	return {"done_delay": 0.0, "hint_delay": 60.0, "start_line": "jump-the-waves", "prompt_line": "jump",
		"success_line": "whee", "done_line": "we-did-it", "arrive_time": 0.3, "gap": 0.1,
		"textures": ["res://assets/art/star.png"], "action": "hop",
		"jack": {"moments": 3}, "becca": {"moments": 2}}


## The slide: the kid rides it along a path.
func _slide() -> Dictionary:
	return {"done_delay": 0.0, "hint_delay": 60.0, "moments": 1, "action": "ride", "arrive_time": 0.2,
		"ride_path": [[900, 500], [1200, 800]], "ride_time": 0.3, "player_feet": [700, 400],
		"textures": ["res://assets/art/star.png"]}


func _until(t, scene: Node2D, state: String) -> void:
	for i in 120:
		if scene.state == state:
			return
		await t.tree.process_frame


func test_setup_from_segment(t) -> void:
	var scene: Node2D = await kit.make(t, SCENE, _waves(), "jack")
	t.eq(scene.moments(), 3, "jack-jack: three waves")
	t.check(kit.said.has("jump-the-waves"), "start line")
	t.eq(scene.state, "arriving", "the first wave is coming")
	kit.done(t, scene)
	scene = await kit.make(t, SCENE, _waves(), "becca")
	t.eq(scene.moments(), 2, "becca: two waves")
	kit.done(t, scene)


func test_a_tap_while_arriving_counts(t) -> void:
	var scene: Node2D = await kit.make(t, SCENE, _waves(), "jack")
	await kit.tap(t, Vector2(400, 300))
	t.eq(scene.moment, 1, "jumped the first wave")
	t.eq(scene.state, "acting", "the hop")
	t.check(kit.said.has("whee"), "success line")
	kit.done(t, scene)


func test_no_tap_just_waits_with_a_prompt(t) -> void:
	var data := _waves()
	data["hint_delay"] = 0.2
	var scene: Node2D = await kit.make(t, SCENE, data, "becca")
	await _until(t, scene, "ready")
	await kit.wait(t, 0.5)
	t.eq(scene.state, "ready", "still waiting: nothing is missed")
	t.eq(scene.moment, 0, "no moment lost")
	t.check(kit.said.count("jump") >= 2, "the prompt, and again as a hint")
	t.check(scene.is_pulsing(scene.get_node("Stage/Thing")), "the wave pulses")
	t.check(not kit.finished(t), "not done")
	await kit.tap(t, Vector2(960, 540))
	t.eq(scene.moment, 1, "a late tap still counts")
	kit.done(t, scene)


func test_taps_between_moments_do_nothing(t) -> void:
	var scene: Node2D = await kit.make(t, SCENE, _waves(), "jack")
	await kit.tap(t, Vector2(400, 300))
	await kit.tap(t, Vector2(400, 300))
	t.eq(scene.moment, 1, "the second tap came while hopping")
	kit.done(t, scene)


func test_done_for_both_kids(t) -> void:
	for kid_id in ["becca", "jack"]:
		var scene: Node2D = await kit.make(t, SCENE, _waves(), kid_id)
		for i in scene.moments():
			await _until(t, scene, "arriving")
			await kit.tap(t, Vector2(400, 300))
		await kit.wait(t, 0.6)
		t.check(kit.finished(t), kid_id + ": every wave jumped")
		t.check(kit.said.has("we-did-it"), kid_id + ": done line")
		kit.done(t, scene)


func test_slide_ride_moves_the_kid(t) -> void:
	var scene: Node2D = await kit.make(t, SCENE, _slide(), "jack")
	await kit.tap(t, Vector2(400, 300))
	await kit.wait(t, 0.9)
	t.check(absf(scene.player.position.x - 1200.0) < 2.0, "rode to the bottom: %s" % scene.player.position)
	t.check(kit.finished(t), "done")
	kit.done(t, scene)


func test_layout_fits_the_tablet(t) -> void:
	var scene: Node2D = await kit.make(t, SCENE, _waves(), "jack", Vector2i(1920, 1200))
	await _until(t, scene, "ready")
	t.check(kit.on_screen(scene, scene.thing_rect()), "the wave arrives on screen")
	t.check(kit.on_screen(scene, scene.player.hit_rect()), "the kid is on screen")
	kit.done(t, scene)


func test_keep_thing_and_ride_end(t) -> void:
	var data := {"done_delay": 0.0, "hint_delay": 60.0, "moments": 1, "arrive_time": 0.1, "action": "ride",
		"ride_path": [[700, 600], [900, 800]], "ride_time": 0.2, "keep_thing": true,
		"ride_end_texture": "res://assets/art/star.png", "ride_end_size": [300, 200], "ride_end_sound": "whoosh",
		"textures": ["res://assets/art/star.png"]}
	var sfx: Node = t.tree.root.get_node("Sfx")
	var scene: Node2D = await kit.make(t, SCENE, data, "jack")
	await kit.wait(t, 0.2)
	await kit.tap(t, Vector2(400, 300))
	var thing: Sprite2D = scene.get_node("Stage/Thing")
	await kit.wait(t, 0.35)
	t.check(thing.visible and thing.modulate.a > 0.99, "the thing stays")
	var burst: Sprite2D = scene.get_node_or_null("Stage/RideEnd")
	t.check(burst != null, "the splash shows at the end of the ride")
	if burst:
		t.check(burst.position.distance_to(Vector2(900, 800)) < 1.0, "at the last ride point")
	t.eq(sfx.last, "whoosh", "with its sound")
	await kit.wait(t, 1.0)
	t.check(scene.get_node_or_null("Stage/RideEnd") == null, "and goes")
	kit.done(t, scene)


func test_thing_leaves_without_keep_thing(t) -> void:
	var scene: Node2D = await kit.make(t, SCENE, {"done_delay": 0.0, "hint_delay": 60.0, "moments": 2,
		"arrive_time": 0.1, "gap": 5.0}, "jack")
	await kit.wait(t, 0.2)
	await kit.tap(t, Vector2(400, 300))
	await kit.wait(t, 0.3)
	t.check((scene.get_node("Stage/Thing") as Sprite2D).modulate.a < 0.05, "faded as before")
	t.check(scene.get_node_or_null("Stage/RideEnd") == null, "no burst")
	kit.done(t, scene)
