# Headless test runner. Runs every test_* method in res://tests/test_*.gd.
# Usage: godot --headless --script res://tests/run_tests.gd
extends SceneTree

const WATCHDOG_SECONDS := 600

var tree: SceneTree
var _failures: Array[String] = []
var _errors := ErrorCatcher.new()


# Records engine and script errors so a test that crashes cannot pass.
class ErrorCatcher extends Logger:
	var messages: Array[String] = []

	func _log_error(_function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, _error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		messages.append("%s (%s:%d)" % [rationale if rationale else code, file, line])


func _initialize() -> void:
	tree = self
	OS.add_logger(_errors)
	# Watchdog: a test that never resumes must not hang CI.
	create_timer(WATCHDOG_SECONDS).timeout.connect(func():
		print("FAIL watchdog: tests still running after %d s" % WATCHDOG_SECONDS)
		quit(2))
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
		var script: GDScript = load("res://tests/" + file)
		if script == null or not script.can_instantiate():
			failed += 1
			print("FAIL ", file, ": could not load (parse error?)")
			continue
		var suite: RefCounted = script.new()
		var names: Array[String] = []
		for method in suite.get_method_list():
			if method.name.begins_with("test_"):
				names.append(method.name)
		names.sort()
		for test_name in names:
			_failures.clear()
			_errors.messages.clear()
			await suite.call(test_name, self)
			for message in _errors.messages:
				_failures.append("error: " + message)
			if _failures.is_empty():
				passed += 1
				print("PASS ", test_name)
			else:
				failed += 1
				print("FAIL ", test_name, ": ", "; ".join(_failures))
	# Let queued frees run so nothing leaks at exit.
	await process_frame
	await process_frame
	print("%d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 or passed == 0 else 0)
