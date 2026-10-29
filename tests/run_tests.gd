# Headless test runner. Runs every test_* method in res://tests/test_*.gd.
# Usage: godot --headless --script res://tests/run_tests.gd
extends SceneTree

var tree: SceneTree
var _failures: Array[String] = []


func _initialize() -> void:
	tree = self
	_run.call_deferred()


func check(cond: bool, msg: String) -> void:
	if not cond:
		_failures.append(msg)


func eq(a: Variant, b: Variant, msg: String) -> void:
	if a != b:
		_failures.append("%s: expected %s, got %s" % [msg, str(b), str(a)])


func _run() -> void:
	var passed := 0
	var failed := 0
	var files := Array(DirAccess.get_files_at("res://tests"))
	files.sort()
	for file: String in files:
		if not (file.begins_with("test_") and file.ends_with(".gd")):
			continue
		var suite: RefCounted = load("res://tests/" + file).new()
		var names: Array[String] = []
		for method in suite.get_method_list():
			if method.name.begins_with("test_"):
				names.append(method.name)
		names.sort()
		for test_name in names:
			_failures.clear()
			await suite.call(test_name, self)
			if _failures.is_empty():
				passed += 1
				print("PASS ", test_name)
			else:
				failed += 1
				print("FAIL ", test_name, ": ", "; ".join(_failures))
	print("%d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 or passed == 0 else 0)
