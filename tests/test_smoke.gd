extends RefCounted


func test_version_setting(t) -> void:
	t.eq(ProjectSettings.get_setting("application/config/version"), "0.1.0", "version")
