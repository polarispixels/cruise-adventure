# What every engine shares: Home, missing art and lines, the done delay.
extends RefCounted

const KIT := preload("res://tests/engine_kit.gd")

var kit := KIT.new()


func test_home_button_goes_to_the_title(t) -> void:
	var scene: Node2D = await kit.make(t, "res://scenes/engines/moments.tscn", {"hint_delay": 60.0}, "jack")
	var home: TextureButton = scene.get_node("Home")
	await kit.tap(t, home.position + home.size / 2)
	t.eq(t.tree.root.get_node("Game").last_scene_request, "res://scenes/title.tscn", "home")
	t.eq(scene.moment, 0, "the Home tap isn't a moment tap")
	kit.done(t, scene)


func test_missing_art_and_lines_never_crash(t) -> void:
	var voice: Node = t.tree.root.get_node("Voice")
	var data := {"hint_delay": 60.0, "done_delay": 0.0, "background": "res://assets/nope/missing.png",
		"start_line": "no-such-line", "done_line": "no-such-line-either",
		"choices": [{"id": "a", "texture": "res://assets/nope/a.png"}, {"id": "b", "texture": "res://assets/nope/b.png"}],
		"target": "a"}
	for scene_path in ["res://scenes/engines/match.tscn", "res://scenes/engines/place.tscn",
			"res://scenes/engines/moving.tscn", "res://scenes/engines/moments.tscn"]:
		var scene: Node2D = await kit.make(t, scene_path, data, "becca")
		t.check(scene.is_inside_tree(), scene_path + " runs")
		kit.done(t, scene)
	# A missing line with the voice on is harmless too.
	voice.enabled = true
	var picker: Node2D = await kit.make(t, "res://scenes/engines/match.tscn", data, "becca")
	voice.enabled = true
	picker.say("no-such-line")
	await kit.tap(t, picker.choice_point("a"))
	t.check(kit.finished(t), "still finishes")
	voice.enabled = false
	kit.done(t, picker)


func test_done_waits_for_done_delay(t) -> void:
	var data := {"hint_delay": 60.0, "done_delay": 0.3, "target": "a",
		"choices": [{"id": "a", "texture": "res://assets/art/star.png"}]}
	var scene: Node2D = await kit.make(t, "res://scenes/engines/match.tscn", data, "jack")
	await kit.tap(t, scene.choice_point("a"))
	t.check(scene.finished, "finished")
	t.check(not kit.finished(t), "segment_done waits for the cheer")
	await kit.wait(t, 0.4)
	t.check(kit.finished(t), "then segment_done")
	kit.done(t, scene)


func test_characters_from_data(t) -> void:
	var scene: Node2D = await kit.make(t, "res://scenes/engines/match.tscn",
		{"hint_delay": 60.0, "player_feet": [400, 900], "helper_feet": [1300, 900], "target": "a",
		"choices": [{"id": "a", "texture": "res://assets/art/star.png"}]}, "becca")
	t.eq(scene.player.kid.id, "becca", "the kid")
	t.eq(scene.helper.kid.id, "jack", "the sibling helps")
	t.eq(scene.player.position, Vector2(400, 900), "player feet")
	kit.done(t, scene)
	scene = await kit.make(t, "res://scenes/engines/match.tscn", {"hint_delay": 60.0, "helper_feet": null,
		"target": "a", "choices": [{"id": "a", "texture": "res://assets/art/star.png"}]}, "becca")
	t.check(scene.helper == null and scene.player == null, "no characters when the data says so")
	kit.done(t, scene)
