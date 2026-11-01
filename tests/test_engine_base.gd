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


## Runs an engine with the voice on (the kit turns it off), so line timing is real.
func _make_voiced(t, segment: Dictionary) -> Node2D:
	var voice: Node = t.tree.root.get_node("Voice")
	voice.stop()
	var scene: Node2D = await kit.make(t, "res://scenes/engines/moments.tscn", {"done_delay": 0.0, "hint_delay": 60.0}, "jack")
	kit.done(t, scene)
	voice.enabled = true
	var game: Node = t.tree.root.get_node("Game")
	var entry := segment.duplicate(true)
	entry["kind"] = "scene"
	entry["scene"] = "res://scenes/engines/moments.tscn"
	game.segment = game.merge_segment(entry, "jack")
	scene = load("res://scenes/engines/moments.tscn").instantiate()
	t.tree.root.add_child(scene)
	await t.tree.process_frame
	return scene


func _until(t, cond: Callable, seconds: float) -> void:
	var end := Time.get_ticks_msec() + int(seconds * 1000)
	while not cond.call() and Time.get_ticks_msec() < end:
		await t.tree.process_frame


func test_start_sound_after_line_waits_for_the_line(t) -> void:
	var sfx: Node = t.tree.root.get_node("Sfx")
	var voice: Node = t.tree.root.get_node("Voice")
	sfx.last = ""
	var scene := await _make_voiced(t, {"done_delay": 0.0, "hint_delay": 60.0, "start_line": "all-packed",
		"start_sound": "whoosh", "start_sound_after_line": true, "after_sound_line": "lets-go"})
	t.check(voice.is_speaking() and voice.current_line == "all-packed", "the start line plays")
	t.eq(sfx.last, "", "the sound waits for it")
	t.check(not scene.intro_done, "the intro isn't over")
	await _until(t, func() -> bool: return sfx.last == "whoosh", 8.0)
	t.eq(sfx.last, "whoosh", "the sound once the line is done")
	t.check(sfx.ducking(), "the music dips under it")
	t.check(voice.last_line == "all-packed", "the after-sound line waits for the sound")
	await _until(t, func() -> bool: return voice.last_line == "lets-go", 8.0)
	t.eq(voice.last_line, "lets-go", "said when the sound ends")
	await _until(t, func() -> bool: return scene.intro_done, 8.0)
	t.check(scene.intro_done, "the intro is over")
	voice.stop()
	voice.enabled = false
	kit.done(t, scene)


func test_without_the_keys_the_sound_plays_with_the_line(t) -> void:
	var sfx: Node = t.tree.root.get_node("Sfx")
	sfx.last = ""
	var scene: Node2D = await kit.make(t, "res://scenes/engines/moments.tscn",
		{"done_delay": 0.0, "hint_delay": 60.0, "start_line": "all-packed", "start_sound": "whoosh"}, "jack")
	t.eq(sfx.last, "whoosh", "same frame as before")
	t.check(kit.said.has("all-packed"), "and the line")
	kit.done(t, scene)


func test_sfx_uses_an_idle_player_before_cutting_one_off(t) -> void:
	var sfx: Node = t.tree.root.get_node("Sfx")
	for p: AudioStreamPlayer in sfx.players():
		p.stop()
	var long: AudioStreamPlayer = sfx.play("belt")
	t.check(long != null and long.playing, "a long sound plays")
	var seen := {long: true}
	for i in sfx.players().size() - 1:
		var p: AudioStreamPlayer = sfx.play("step")
		t.check(not seen.has(p), "a free player each time")
		seen[p] = true
	t.check(long.playing, "the long sound is never cut while a player is free")
	t.eq(sfx.play("no-such-sound"), null, "a missing sound gives no player")
	for p: AudioStreamPlayer in sfx.players():
		p.stop()


func test_helper_scale_sizes_the_sibling_alone(t) -> void:
	var feet := {"done_delay": 0.0, "hint_delay": 60.0, "player_feet": [500, 900], "helper_feet": [1200, 900]}
	var scene: Node2D = await kit.make(t, "res://scenes/engines/moments.tscn", feet, "jack")
	t.eq(scene.helper.height_scale, scene.player.height_scale, "same size by default")
	kit.done(t, scene)
	feet["kid_scale"] = 0.2
	feet["helper_scale"] = 0.15
	scene = await kit.make(t, "res://scenes/engines/moments.tscn", feet, "jack")
	t.eq(scene.player.height_scale, 0.2, "the kid at kid_scale")
	t.eq(scene.helper.height_scale, 0.15, "the sibling at helper_scale")
	kit.done(t, scene)


func test_foreground_lines_and_done_overlay(t) -> void:
	var data := {"done_delay": 0.0, "hint_delay": 60.0, "moments": 1, "arrive_time": 0.1, "player_feet": [700, 900],
		"foreground": "res://assets/art/star.png", "foreground_rect": [0, 0, 400, 300],
		"lines": [{"y": 512, "from_x": 300, "to_x": 900, "color": "#e03030", "width": 8}],
		"done_overlay": {"texture": "res://assets/art/star.png", "pos": [836, 120], "size": [200, 100]},
		"done_overlay_sound": "scanner-chime"}
	var scene: Node2D = await kit.make(t, "res://scenes/engines/moments.tscn", data, "jack")
	var stage: Node2D = scene.get_node("Stage")
	var fg: Sprite2D = stage.get_node("Foreground")
	t.eq(fg.get_index(), stage.get_child_count() - 1, "the foreground is over everything on the stage")
	t.eq(fg.texture.get_size() * fg.scale, Vector2(400, 300), "in foreground_rect")
	var line_node: Line2D = stage.get_node("Lines").get_child(0)
	t.eq(line_node.points, PackedVector2Array([Vector2(300, 512), Vector2(900, 512)]), "the height line")
	t.eq(line_node.width, 8.0, "its width")
	t.check(stage.get_node("Lines").get_index() < scene.player.get_index(), "under the characters")
	t.check(stage.get_node_or_null("DoneOverlay") == null, "no overlay before the end")
	var sfx: Node = t.tree.root.get_node("Sfx")
	await kit.wait(t, 0.2)
	await kit.tap(t, Vector2(400, 300))
	var end := Time.get_ticks_msec() + 3000
	while not scene.finished and Time.get_ticks_msec() < end:
		await t.tree.process_frame
	var o: Sprite2D = stage.get_node_or_null("DoneOverlay")
	t.check(o != null, "the overlay shows when done")
	if o:
		t.eq(o.position, Vector2(836, 120), "at pos")
		t.eq(o.texture.get_size() * o.scale, Vector2(200, 100), "at size")
		await kit.wait(t, 0.5)
		t.check(o.modulate.a > 0.99, "faded in")
	t.eq(sfx.last, "scanner-chime", "with its sound")
	kit.done(t, scene)


func test_no_foreground_lines_or_overlay_without_the_keys(t) -> void:
	var scene: Node2D = await kit.make(t, "res://scenes/engines/moments.tscn", {"done_delay": 0.0, "hint_delay": 60.0}, "jack")
	var stage: Node2D = scene.get_node("Stage")
	t.check(stage.get_node_or_null("Foreground") == null and stage.get_node_or_null("Lines") == null, "nothing extra")
	kit.done(t, scene)


func test_no_idle_hint_during_the_intro(t) -> void:
	var scene: Node2D = await kit.make(t, "res://scenes/engines/moments.tscn",
		{"done_delay": 0.0, "hint_delay": 0.2, "hint_line": "this-way", "moments": 1, "arrive_time": 0.05}, "jack")
	scene.intro_done = false  # as if the start line were still playing
	kit.said.clear()
	await kit.wait(t, 0.6)
	t.check(not kit.said.has("this-way"), "the hint waits for the intro")
	scene.intro_done = true
	await kit.wait(t, 0.6)
	t.check(kit.said.has("this-way"), "then the idle hint comes")
	kit.done(t, scene)
