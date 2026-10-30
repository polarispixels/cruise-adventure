extends RefCounted


func test_version_setting(t) -> void:
	t.eq(ProjectSettings.get_setting("application/config/version"), "0.3.0", "version")


func test_landscape_follows_tablet_flip(t) -> void:
	# 4 = sensor landscape: locked to landscape, but turns over with the tablet.
	t.eq(ProjectSettings.get_setting("display/window/handheld/orientation"), 4, "orientation")


func test_android_version_code(t) -> void:
	var presets := ConfigFile.new()
	t.eq(presets.load("res://export_presets.cfg"), OK, "presets load")
	t.eq(presets.get_value("preset.1.options", "version/code"), 3, "version code")
