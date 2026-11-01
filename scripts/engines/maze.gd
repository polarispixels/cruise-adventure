# Maze: a top-down layout the kid drags their face token through, with the
# sibling's token trailing a cell behind. The token only moves along open
# corridors. The layout is either fixed (rows of text, see MazeModel.from_rows,
# with arrow signs and goal cells) or generated fresh (MazeModel.generate, the
# goals in the right column). Reaching a wrong goal: the sibling bounces and
# says the wrong line. The right goal: done. Hints: the sibling token steps
# toward the way to go, and footprints show the next steps when turned on.
extends EngineBase

const TOKEN_CELLS := 0.65
const SIBLING_CELLS := 0.5
const GOAL_CELLS := 0.9
const GRAB_CELLS := 0.7
const MOVE_BUDGET := 4.0
const WALL_OUTLINE := Color("#263444")
const FOOTPRINTS := 3
const BOUNCE := 0.25

var maze: MazeModel

var _cell := 100.0
var _origin := Vector2.ZERO
var _a := Vector2i.ZERO
var _b := Vector2i.ZERO
var _t := 0.0
var _trail: Array[Vector2] = []
var _at_goal := -1
var _best := 1 << 30
var _board: Node2D
var _token: Sprite2D
var _sibling: Sprite2D
var _prints: Array[Sprite2D] = []


func _defaults() -> Dictionary:
	return {
		"area": [130, 160, 1412, 740],
		"wall_color": "#7E9CAF",
		"floor_color": "",
		"footprints": false,
		"hint_line": "this-way",
		"wrong_line": "not-this-one",
		"token_texture": "res://assets/airport/token-%s.png" % Game.kid.id,
		"sibling_token_texture": "res://assets/airport/token-%s.png" % Game.sibling().id,
		"footprint_texture": "res://assets/airport/footprints-hint.png",
		"goal_textures": ["res://assets/art/star.png"],
		"helper_feet": null,
	}


func _build() -> void:
	if data.has("fixed"):
		maze = MazeModel.from_rows(data["fixed"] as Array, str(data.get("goal", "G")))
	else:
		var g: Dictionary = data.get("generate", {})
		var rng := RandomNumberGenerator.new()
		if g.has("seed"):
			rng.seed = int(g["seed"])
		else:
			rng.randomize()
		maze = MazeModel.generate(Vector2i(vec(g.get("size"), Vector2(6, 4))), float(g.get("braid", 0.5)),
				int(g.get("loops", 1)), int(g.get("max_turns", 0)), int(g.get("gates", 1)), rng)
	var area := rect_of(data["area"])
	_cell = minf(area.size.x / maze.size.x, area.size.y / maze.size.y)
	_origin = area.get_center() - Vector2(maze.size) * _cell / 2
	_board = Node2D.new()
	_board.name = "Board"
	stage.add_child(_board)
	_draw_board()
	_token = _sprite(str(data["token_texture"]), TOKEN_CELLS, Color(0.3, 0.5, 1.0))
	_token.name = "Token"
	_sibling = _sprite(str(data["sibling_token_texture"]), SIBLING_CELLS, Color(1.0, 0.5, 0.7))
	_sibling.name = "Sibling"
	_sibling.modulate.a = 0.9
	for i in FOOTPRINTS:
		var p := _sprite(str(data["footprint_texture"]), 0.7, Color(1, 1, 1, 0.6))
		p.visible = false
		p.modulate.a = 0.85
		stage.add_child(p)
		_prints.append(p)
	stage.add_child(_sibling)
	stage.add_child(_token)
	_a = maze.start
	_b = maze.start
	_token.position = token_local()
	_place_sibling()
	_best = _distance_left()


func cell_px() -> float:
	return _cell * stage.scale.x


## Global center of a cell.
func cell_center(c: Vector2i) -> Vector2:
	return stage.to_global(_cell_local(c))


func token_position() -> Vector2:
	return stage.to_global(token_local())


func token_local() -> Vector2:
	return _cell_local(_a).lerp(_cell_local(_b), _t)


func token_cell() -> Vector2i:
	return _a if _t < 0.5 else _b


func goal_cell(i: int) -> Vector2i:
	return maze.gates[i]


func right_goal() -> int:
	return maze.correct


func board_rect() -> Rect2:
	return to_global_rect(Rect2(_origin, Vector2(maze.size) * _cell))


func footprints_shown() -> int:
	var n := 0
	for p in _prints:
		if p.visible:
			n += 1
	return n


func sibling_position() -> Vector2:
	return stage.to_global(_sibling.position)


func _press(local: Vector2) -> bool:
	return local.distance_to(token_local()) <= GRAB_CELLS * _cell


func _drag(local: Vector2) -> void:
	_follow(local)


## Moves the token toward the finger, along open corridors only.
func _follow(finger: Vector2) -> void:
	var budget := MOVE_BUDGET * _cell
	for i in 32:
		if _a == _b:
			if not _turn_toward(_a, finger):
				break
			continue
		var a := _cell_local(_a)
		var ab := _cell_local(_b) - a
		var want := clampf((finger - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
		var step := clampf((want - _t) * ab.length(), -budget, budget)
		_t += step / ab.length()
		budget -= absf(step)
		if _t >= 1.0 - 0.001:
			_land(_b)
		elif _t <= 0.001:
			_land(_a)
		else:
			break
		if budget <= 0.0:
			break
	_moved_token()


func _turn_toward(node: Vector2i, finger: Vector2) -> bool:
	var here := _cell_local(node)
	var to_finger := finger - here
	if to_finger.length() < _cell * 0.05:
		return false
	var best := node
	var best_dot := 0.3
	for n in maze.exits(node):
		var d := (_cell_local(n) - here).normalized().dot(to_finger.normalized())
		if d > best_dot:
			best_dot = d
			best = n
	if best == node:
		return false
	_a = node
	_b = best
	_t = 0.0
	return true


func _land(node: Vector2i) -> void:
	if node != _a or _a != _b:
		sound(str(data.get("step_sound", "step")))
	_a = node
	_b = node
	_t = 0.0


func _moved_token() -> void:
	var p := token_local()
	if p.distance_to(_token.position) > 0.5:
		_idle = 0.0
	_token.position = p
	if _trail.is_empty() or _trail.back().distance_to(p) > _cell * 0.1:
		_trail.append(p)
	_place_sibling()
	var left := _distance_left()
	if left < _best:
		_best = left
		_clear_hint()
	var goal := maze.gates.find(_a) if _a == _b else -1
	if goal != _at_goal:
		_at_goal = goal
		if goal == maze.correct:
			_pressing = false
			_bounce(_token)
			_bounce(_sibling)
			finish()
		elif goal >= 0:
			_bounce(_sibling)
			say(line("wrong_line"))


func _distance_left() -> int:
	return maze.path(token_cell(), maze.gates[maze.correct]).size()


func _show_hint() -> void:
	var route := maze.path(token_cell(), maze.gates[maze.correct])
	if route.size() > 1:
		_sibling.position = token_local() + (_cell_local(route[1]) - _cell_local(route[0])).normalized() * _cell * 0.5
	_bounce(_sibling)
	if not bool(data["footprints"]):
		return
	for k in _prints.size():
		var p := _prints[k]
		p.visible = k + 1 < route.size()
		if p.visible:
			p.position = _cell_local(route[k + 1])
			p.rotation = Vector2(route[k + 1] - route[k]).angle() + PI / 2


func _hide_hint() -> void:
	for p in _prints:
		p.visible = false


func _place_sibling() -> void:
	var left := _cell
	var p: Vector2 = _trail[0] if _trail.size() > 0 else token_local()
	for i in range(_trail.size() - 1, 0, -1):
		var seg := _trail[i].distance_to(_trail[i - 1])
		if seg >= left:
			p = _trail[i].move_toward(_trail[i - 1], left)
			break
		left -= seg
	if _trail.size() <= 1:
		p = token_local() + Vector2(-_cell * 0.35, _cell * 0.25)
	_sibling.position = p


func _bounce(sprite: Sprite2D) -> void:
	var height := _cell * BOUNCE / sprite.scale.y
	var t := create_tween()
	t.tween_property(sprite, "offset", Vector2(0, -height), 0.15).set_ease(Tween.EASE_OUT)
	t.tween_property(sprite, "offset", Vector2.ZERO, 0.2).set_ease(Tween.EASE_IN)
	t.set_loops(2)


func _cell_local(c: Vector2i) -> Vector2:
	return _origin + (Vector2(c) + Vector2(0.5, 0.5)) * _cell


func _sprite(path: String, cells: float, fallback: Color) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = texture_or(path, Vector2(128, 128), fallback)
	s.scale = Vector2.ONE * cells * _cell / s.texture.get_size().x
	return s


## Walls (wall cells in a fixed layout, edge walls in a generated one), arrow
## signs, goals and decor.
func _draw_board() -> void:
	var wall := color_of(data["wall_color"], Color("#7E9CAF"))
	var fill := color_of(data.get("floor_color", ""), Color(0, 0, 0, 0))
	var whole := Rect2(_origin, Vector2(maze.size) * _cell)
	if fill.a > 0.0:
		_board.add_child(_rect_poly(whole, fill))
	if data.has("fixed"):
		for c: Vector2i in maze.walls:
			_board.add_child(_rect_poly(Rect2(_origin + Vector2(c) * _cell, Vector2.ONE * _cell).grow(-2), wall))
		var frame := Line2D.new()
		frame.points = PackedVector2Array([whole.position, Vector2(whole.end.x, whole.position.y), whole.end,
				Vector2(whole.position.x, whole.end.y), whole.position])
		frame.width = _cell * 0.12
		frame.default_color = WALL_OUTLINE
		_board.add_child(frame)
	else:
		_draw_edge_walls(wall)
	for c: Vector2i in maze.arrows:
		_board.add_child(_arrow(c, maze.arrows[c] as Vector2i))
	var textures: Array = data["goal_textures"] as Array
	var wrong := 0
	for i in maze.gates.size():
		var path := str(textures[0])
		if i != maze.correct and textures.size() > 1:
			path = str(textures[1 + wrong % (textures.size() - 1)])
			wrong += 1
		var goal := _sprite(path, GOAL_CELLS, Color(0.4, 0.8, 0.4) if i == maze.correct else Color(0.8, 0.8, 0.8))
		goal.name = "Goal%d" % i
		goal.position = _cell_local(maze.gates[i])
		_board.add_child(goal)
	_place_decor()


func _place_decor() -> void:
	var route := {}
	for c in maze.path(maze.start, maze.gates[maze.correct]):
		route[c] = true
	var auto: Array[String] = []
	for d: Variant in data.get("decor", []):
		if d is Dictionary:
			var s := _sprite(str(d.get("texture", "")), float(d.get("cells", 0.6)), Color(0.7, 0.6, 0.5))
			s.position = _cell_local(Vector2i(vec(d.get("cell"))))
			_board.add_child(s)
		else:
			auto.append(str(d))
	if auto.is_empty():
		return
	var n := 0
	for y in maze.size.y:
		for x in maze.size.x:
			var c := Vector2i(x, y)
			if n >= auto.size() or route.has(c) or c == maze.start or maze.is_wall(c) \
					or maze.gates.has(c) or maze.exits(c).size() != 1:
				continue
			var s := _sprite(auto[n], 0.55, Color(0.7, 0.6, 0.5))
			s.position = _cell_local(c)
			_board.add_child(s)
			n += 1


func _draw_edge_walls(color: Color) -> void:
	var runs: Array = []
	var w := maze.size.x
	var h := maze.size.y
	for y in h + 1:
		var start := -1
		for x in w + 1:
			var closed := x < w and (y == 0 or y == h or not maze.open(Vector2i(x, y - 1), Vector2i(x, y)))
			if closed and start < 0:
				start = x
			elif not closed and start >= 0:
				runs.append([Vector2(start, y), Vector2(x, y)])
				start = -1
	for x in w + 1:
		var start := -1
		for y in h + 1:
			var closed := y < h and (x == 0 or x == w or not maze.open(Vector2i(x - 1, y), Vector2i(x, y)))
			if closed and start < 0:
				start = y
			elif not closed and start >= 0:
				runs.append([Vector2(x, start), Vector2(x, y)])
				start = -1
	for layer: Array in [[WALL_OUTLINE, 0.2 * _cell + 8.0], [color, 0.2 * _cell]]:
		for run: Array in runs:
			var l := Line2D.new()
			l.default_color = layer[0]
			l.width = layer[1]
			l.begin_cap_mode = Line2D.LINE_CAP_ROUND
			l.end_cap_mode = Line2D.LINE_CAP_ROUND
			l.points = PackedVector2Array([_origin + (run[0] as Vector2) * _cell, _origin + (run[1] as Vector2) * _cell])
			_board.add_child(l)


func _rect_poly(r: Rect2, color: Color) -> Polygon2D:
	var p := Polygon2D.new()
	p.polygon = PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
	p.color = color
	return p


## A yellow arrow sign on the floor (or arrow_texture, drawn pointing right).
func _arrow(c: Vector2i, dir: Vector2i) -> Node2D:
	var node: Node2D
	if data.has("arrow_texture"):
		node = _sprite(str(data["arrow_texture"]), 0.6, Color.YELLOW)
	else:
		var p := Polygon2D.new()
		var s := _cell * 0.3
		p.polygon = PackedVector2Array([Vector2(-s, -s * 0.35), Vector2(0, -s * 0.35), Vector2(0, -s * 0.8),
				Vector2(s, 0), Vector2(0, s * 0.8), Vector2(0, s * 0.35), Vector2(-s, s * 0.35)])
		p.color = Color("#FFD23F")
		node = p
	node.position = _cell_local(c)
	node.rotation = Vector2(dir).angle()
	return node
