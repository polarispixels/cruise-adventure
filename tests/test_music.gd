extends RefCounted


func _music(t) -> Node:
	var m: Node = t.tree.root.get_node("Music")
	m.hold(false)
	return m


func test_theme_plays_and_loops(t) -> void:
	var m := _music(t)
	var player: AudioStreamPlayer = m.player
	t.check(player.stream != null, "a theme is loaded")
	t.check(player.stream.loop, "the theme loops")
	t.check(player.playing, "playing")
	t.check(player.volume_db <= m.NORMAL_DB, "quiet, under the voices")


func test_hold_pauses_and_resumes(t) -> void:
	var m := _music(t)
	m.hold(true)
	t.check(m.player.stream_paused, "paused for a video")
	m.hold(false)
	t.check(not m.player.stream_paused, "back on")


func test_ducks_while_someone_speaks(t) -> void:
	var m := _music(t)
	var voice: Node = t.tree.root.get_node("Voice")
	voice.enabled = true
	voice.say("pick-a-row", load("res://data/becca.tres"))
	var end := Time.get_ticks_msec() + 2000
	while m.player.volume_db > m.DUCKED_DB + 0.5 and Time.get_ticks_msec() < end:
		await t.tree.process_frame
	t.check(m.player.volume_db <= m.DUCKED_DB + 0.5, "quieter under a voice line: %s" % m.player.volume_db)
	voice.stop()
	end = Time.get_ticks_msec() + 2000
	while m.player.volume_db < m.NORMAL_DB - 0.5 and Time.get_ticks_msec() < end:
		await t.tree.process_frame
	t.check(m.player.volume_db >= m.NORMAL_DB - 0.5, "back up after")


func test_videos_hold_the_music(t) -> void:
	var m := _music(t)
	var game: Node = t.tree.root.get_node("Game")
	game.navigate = false
	game.kid = load("res://data/becca.tres")
	var intro: Control = load("res://scenes/intro.tscn").instantiate()
	t.tree.root.add_child(intro)
	await t.tree.process_frame
	t.check(m.player.stream_paused, "paused during the intro")
	intro.free()
	await t.tree.process_frame
	t.check(not m.player.stream_paused, "back on when the intro goes")
