# Tap moments: something arrives (a wave rolls in, the slide is ready) and any
# tap, during or after the arrival, succeeds: the kid hops or rides the slide,
# says the success line, and the next moment comes. There's no timing to miss:
# if the kid doesn't tap, the moment waits, and every hint_delay the helper says
# the prompt again and points while the thing pulses. Done after `moments`.
extends EngineBase

## Which moment is playing (0-based); equals `moments` when all are done.
var moment := 0
## "gap" (between moments, taps ignored), "arriving", "ready" (arrived, waiting), "acting".
var state := "gap"

var _thing: Sprite2D
var _actor: Character
var _actor_home := Vector2.ZERO
var _textures: Array[String] = []


func _defaults() -> Dictionary:
	return {
		"moments": 3,
		"action": "hop",
		"actor": "player",
		"arrive_from": [1800, 700],
		"arrive_to": [1100, 700],
		"leave_to": [-200, 700],
		"arrive_time": 1.5,
		"arrive_height": 300.0,
		"hop_height": 140.0,
		"action_pose": "arms-up",
		"ride_time": 1.6,
		"gap": 0.8,
		"player_feet": [700, 900],
		"helper_feet": [1480, 930],
		"success_line": "found",
		"success_sound": "whoosh",
	}


func _build() -> void:
	var tex: Variant = data.get("textures", [])
	if tex is Array:
		for p: Variant in tex:
			_textures.append(str(p))
	elif tex is String:
		_textures.append(tex as String)
	_thing = Sprite2D.new()
	_thing.name = "Thing"
	_thing.visible = false
	stage.add_child(_thing)


func _started() -> void:
	_actor = helper if str(data["actor"]) == "helper" else player
	if _actor:
		_actor_home = _actor.position
	_begin_moment()


func moments() -> int:
	return int(data["moments"])


## Global point of the arriving thing.
func thing_point() -> Vector2:
	return stage.to_global(_thing.position)


func thing_rect() -> Rect2:
	return to_global_rect(sprite_rect(_thing))


func _busy() -> bool:
	return state != "ready"


func _press(_local: Vector2) -> bool:
	if state == "arriving" or state == "ready":
		_success()
	return false


func _begin_moment() -> void:
	if finished:
		return
	if _actor:
		_actor.set_pose("idle")
		_actor.position = _actor_home
	state = "arriving"
	var path := _textures[moment % _textures.size()] if not _textures.is_empty() else ""
	var h := float(data["arrive_height"])
	_thing.texture = texture_or(path, Vector2(h * 1.5, h), Color(0.4, 0.7, 1.0))
	set_height(_thing, h)
	_thing.modulate = Color.WHITE
	_thing.position = vec(data["arrive_from"])
	_thing.visible = true
	sound(str(data.get("arrive_sound", "")))
	var t := create_tween()
	t.tween_property(_thing, "position", vec(data["arrive_to"]), float(data["arrive_time"])) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_callback(_arrived)


func _arrived() -> void:
	if state == "arriving":
		state = "ready"
		say(str(data.get("prompt_line", "")))


func _success() -> void:
	state = "acting"
	_clear_hint()
	stop_pulse(_thing)
	sound(str(data["success_sound"]))
	moment += 1
	var last := moment >= moments()
	var t := create_tween()
	t.tween_property(_thing, "position", vec(data["leave_to"]), float(data["arrive_time"]) * 0.7) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(_thing, "modulate:a", 0.0, float(data["arrive_time"]) * 0.7)
	var act := _act()
	say(line("success_line"))
	if last:
		act.tween_callback(finish)
		return
	act.tween_interval(float(data["gap"]))
	act.tween_callback(_begin_moment)


## The kid's action; returns the tween so the next step can follow it.
func _act() -> Tween:
	var t := create_tween()
	if _actor == null:
		t.tween_interval(0.5)
		return t
	_actor.set_pose(str(data["action_pose"]))
	if str(data["action"]) == "ride":
		var pts: Array = data.get("ride_path", []) as Array
		var each := float(data["ride_time"]) / maxf(pts.size(), 1)
		for p: Variant in pts:
			t.tween_property(_actor, "position", vec(p), each).set_trans(Tween.TRANS_SINE)
	else:
		var up := _actor_home - Vector2(0, float(data["hop_height"]))
		t.tween_property(_actor, "position", up, 0.22).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		t.tween_property(_actor, "position", _actor_home, 0.22).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	t.tween_callback(func() -> void: _actor.set_pose("idle"))
	return t


func _show_hint() -> void:
	say(str(data.get("prompt_line", "")))
	pulse(_thing)
	point_helper(_thing.position)


func _hide_hint() -> void:
	stop_pulse(_thing)
