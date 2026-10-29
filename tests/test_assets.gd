extends RefCounted

const MANIFEST := "res://data/art_manifest.json"


func _entries() -> Array:
	var text := FileAccess.get_file_as_string(MANIFEST)
	var parsed = JSON.parse_string(text)
	return parsed if parsed is Array else []


func test_manifest_files_load(t) -> void:
	var entries := _entries()
	t.check(entries.size() > 0, "manifest has entries")
	for entry in entries:
		var path: String = "res://" + entry["game"]
		t.check(ResourceLoader.exists(path), "exists: " + path)
		var res = load(path)
		match path.get_extension():
			"png": t.check(res is Texture2D, "texture: " + path)
			"ogg": t.check(res is AudioStream, "audio: " + path)
			"ogv": t.check(res is VideoStream, "video: " + path)


func test_character_canvas(t) -> void:
	for kid in ["jack", "becca"]:
		for pose in ["idle", "wave-1", "wave-2", "cheer", "clap", "point"]:
			var tex: Texture2D = load("res://assets/characters/%s/%s.png" % [kid, pose])
			t.eq(tex.get_size() if tex else Vector2.ZERO, Vector2(1024, 1536), "%s %s canvas" % [kid, pose])


func test_variants_match_card_size(t) -> void:
	for kid in ["jack", "becca"]:
		for item in ["shirt", "shorts", "underwear", "socks"]:
			var card: Texture2D = load("res://assets/props/%s/%s-card.png" % [kid, item])
			for alt in ["alt-1", "alt-2", "alt-3"]:
				var tex: Texture2D = load("res://assets/props/%s/%s-%s.png" % [kid, item, alt])
				t.check(card != null and tex != null and tex.get_size() == card.get_size(), "%s %s %s size" % [kid, item, alt])
