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
		for pose in ["idle", "wave-1", "wave-2", "cheer", "clap", "point", "hmm", "hug"]:
			var tex: Texture2D = load("res://assets/characters/%s/%s.png" % [kid, pose])
			t.eq(tex.get_size() if tex else Vector2.ZERO, Vector2(1024, 1536), "%s %s canvas" % [kid, pose])


func test_variants_match_card_size(t) -> void:
	for kid in ["jack", "becca"]:
		for item in ["shirt", "shorts", "underwear", "socks", "pajamas", "swimsuit", "hoodie", "nice-outfit", "sandals", "hat", "hairbrush", "toothbrush", "buddy", "book", "tablet", "special"]:
			var card: Texture2D = load("res://assets/props/%s/%s-card.png" % [kid, item])
			for alt in ["alt-1", "alt-2", "alt-3", "alt-4", "alt-5", "alt-6", "alt-7"]:
				var tex: Texture2D = load("res://assets/props/%s/%s-%s.png" % [kid, item, alt])
				t.check(card != null and tex != null and tex.get_size() == card.get_size(), "%s %s %s size" % [kid, item, alt])


func test_car_art_matches_trunk_data(t) -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/trunk.json"))
	t.check(data != null, "trunk.json parses")
	if data == null:
		return
	var cell: int = data["cell_px"]
	for bag in data["bags"]:
		var path := "res://assets/car/bag-%s.png" % bag["id"]
		var tex: Texture2D = load(path) if ResourceLoader.exists(path) else null
		var want := Vector2(bag["size"][0] * cell, bag["size"][1] * cell)
		t.eq(tex.get_size() if tex else Vector2.ZERO, want, path)
	var open: Texture2D = load("res://assets/car/suv-open.png") if ResourceLoader.exists("res://assets/car/suv-open.png") else null
	var closed: Texture2D = load("res://assets/car/suv-closed.png") if ResourceLoader.exists("res://assets/car/suv-closed.png") else null
	t.check(open != null and closed != null, "suv art exists")
	if open and closed:
		t.eq(open.get_size(), closed.get_size(), "open and closed suv line up")
	var cargo: Array = data["cargo_rect"]
	t.eq(Vector2(cargo[2], cargo[3]), Vector2(data["cols"] * cell, data["rows"] * cell), "cargo rect is the grid")
