extends RefCounted

const EXPECTED_IDS := [
	"who-do-you-want", "pick-a-row", "open-suitcase", "open-drawer", "open-basket", "open-toybox",
	"find-shirt", "find-shorts", "find-underwear", "find-socks", "find-pajamas", "find-swimsuit",
	"find-hoodie", "find-nice-outfit", "find-sandals", "find-hat", "find-hairbrush", "find-toothbrush",
	"find-buddy", "find-book", "find-tablet", "find-special",
	"found-1", "found-2", "found-3", "try-again", "roll-it", "pack-it", "hug-buddy",
	"close-suitcase", "zip-it", "all-packed",
	"load-car", "turn-it", "try-another-spot", "it-fits", "close-trunk", "lets-go",
	"tag-bags", "needs-tag", "on-the-belt", "bye-suitcases", "in-a-tray", "tablet-tray", "push-it",
	"comes-back", "walk-through", "get-your-things", "find-gate", "match-airplane", "this-way",
	"not-this-one", "found-gate",
]


func _lines() -> Array:
	return JSON.parse_string(FileAccess.get_file_as_string("res://data/voice_lines.json"))


func _voice(t) -> Node:
	var v: Node = t.tree.root.get_node("Voice")
	v.enabled = true
	v.stop()
	v.last_line = ""
	return v


func _kid(id: String) -> KidProfile:
	return load("res://data/%s.tres" % id)


func test_json_has_the_53_ids(t) -> void:
	var ids: Array = []
	for line in _lines():
		ids.append(line["id"])
		t.check(String(line["text"]) != "", "text for " + line["id"])
	t.eq(ids, EXPECTED_IDS, "voice line ids")


func test_find_special_and_buddy_text_by_speaker(t) -> void:
	for line in _lines():
		if line["id"] == "find-buddy":
			t.eq(line["text_by_kid"]["becca"], "Find your teddy!", "becca says jack's buddy")
			t.eq(line["text_by_kid"]["jack"], "Find your unicorn!", "jack says becca's buddy")
		if line["id"] == "find-special":
			t.eq(line["text_by_kid"]["becca"], "Find your monster truck!", "becca says jack's special")
			t.eq(line["text_by_kid"]["jack"], "Find your Minnie ears!", "jack says becca's special")


func test_every_line_has_a_file_for_both_kids(t) -> void:
	for kid_id in ["jack", "becca"]:
		for line in _lines():
			var path := "res://assets/voice/%s/%s.ogg" % [kid_id, line["id"]]
			var s = load(path)
			t.check(s is AudioStream, "loadable " + path)


func test_say_records_emits_and_plays(t) -> void:
	var v := _voice(t)
	var heard: Array[String] = []
	var cb := func(id: String): heard.append(id)
	v.said.connect(cb)
	v.say("pick-a-row", _kid("jack"))
	v.said.disconnect(cb)
	t.eq(v.last_line, "pick-a-row", "last_line")
	t.eq(heard, ["pick-a-row"] as Array[String], "said emitted")
	t.check(v.is_speaking(), "speaking right after say")
	v.stop()
	t.check(not v.is_speaking(), "stop silences")


func test_second_say_interrupts(t) -> void:
	var v := _voice(t)
	v.say("pick-a-row", _kid("jack"))
	v.say("zip-it", _kid("becca"))
	t.eq(v.last_line, "zip-it", "switched line")
	t.check(v.is_speaking(), "still speaking")
	v.stop()


func test_disabled_records_without_playing(t) -> void:
	var v := _voice(t)
	v.enabled = false
	var heard: Array[String] = []
	var cb := func(id: String): heard.append(id)
	v.said.connect(cb)
	v.say("zip-it", _kid("jack"))
	v.said.disconnect(cb)
	t.eq(v.last_line, "zip-it", "last_line when disabled")
	t.eq(heard, ["zip-it"] as Array[String], "said when disabled")
	t.check(not v.is_speaking(), "not playing when disabled")
	v.enabled = true


func test_missing_line_is_harmless(t) -> void:
	var v := _voice(t)
	v.say("no-such-line", _kid("jack"))
	t.check(not v.is_speaking(), "nothing plays for a missing file")


func test_found_line_cycles(t) -> void:
	var v := _voice(t)
	var got: Array[String] = []
	for i in 6:
		got.append(v.found_line())
	var first := got.slice(0, 3)
	t.check("found-1" in first and "found-2" in first and "found-3" in first, "first three are all distinct found lines")
	t.eq(got.slice(3, 6), first, "cycle repeats")
	t.eq(got[0], got[3], "period 3")


func test_wait_lets_the_current_line_finish(t) -> void:
	var voice: Node = t.tree.root.get_node("Voice")
	voice.enabled = true
	var becca: KidProfile = load("res://data/becca.tres")
	voice.say("found-2", becca)
	voice.say("find-shirt", becca, true)
	t.eq(voice.current_line, "found-2", "the cheer keeps playing")
	voice.get_child(0).finished.emit()
	t.eq(voice.current_line, "find-shirt", "then the instruction")
	voice.say("open-drawer", becca)
	t.eq(voice.current_line, "open-drawer", "a plain say still interrupts")
	voice.stop()
