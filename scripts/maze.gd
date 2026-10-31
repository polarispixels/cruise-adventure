# Airport, Find our gate: a terminal maze seen from above, fresh every play.
# The child puts a finger on their face token and drags it through the
# hallways. The token only moves along open corridors, so walls simply stop
# it, and lifting the finger leaves it where it is. The sibling's token trails
# behind. Jack-Jack matches the airplane on his boarding pass to one of three
# gates; Becca has one gate and footprint hints. Reaching the right gate plays
# the jet-bridge clip and the finish buttons.
extends Node2D

## Tests set this to get the same maze every time; -1 means a random one.
static var next_seed := -1

const BG_SIZE := Vector2(1672, 941)
## The spec's 150 px cell on the 1672-wide canvas, in screen pixels.
const MAX_CELL := 150.0 * 1920.0 / 1672.0
const MARGIN := 24.0
## Room above the maze for the home button and the boarding pass.
const TOP_BAND := 190.0
## A gate is this many cells wide.
const GATE_CELLS := 1.6
const TOKEN_CELLS := 0.65
const SIBLING_CELLS := 0.5
## A press counts on the token within this many cells of its center.
const GRAB_CELLS := 0.6
## How far (cells) one finger movement can carry the token.
const MOVE_BUDGET := 4.0
const WALL_FILL := Color("#7E9CAF")
const WALL_OUTLINE := Color("#263444")
## Wall thickness in cells (the spec's 30 px at a 150 px cell).
const WALL_CELLS := 0.2
const WALL_OUTLINE_PX := 4.0
const GATE_COLORS := ["red", "green", "blue"]
const DECOR := ["cart", "info", "kiosk", "planter", "seats", "walkway"]
const MAX_DECOR := 4
const FOOTPRINTS := 3
const PAYOFF_VIDEO := "res://assets/video/airport-jet-bridge.ogv"
const SKIP_GRACE := 0.75
const BOUNCE := 0.25

var maze: MazeModel
var payoff_video := PAYOFF_VIDEO
var finished := false

var _cell := 100.0
var _origin := Vector2.ZERO
var _gate_colors: Array[String] = []
## The token sits on the segment from _a to _b, _t of the way along.
## Nodes are cells; a gate's node is the cell just past the right edge.
var _a := Vector2i.ZERO
var _b := Vector2i.ZERO
var _t := 0.0
var _dragging := false
var _trail: Array[Vector2] = []
var _at_gate := -1
var _idle := 0.0
var _hinting := false
var _best := 1 << 30
var _video_started := 0.0

@onready var _background: Sprite2D = $Background
@onready var _walls: Node2D = $Walls
@onready var _decor: Node2D = $Decor
@onready var _gates: Node2D = $Gates
@onready var _footprints: Node2D = $Footprints
@onready var _sibling: Sprite2D = $Sibling
@onready var _token: Sprite2D = $Token
@onready var _pass: Sprite2D = $BoardingPass
@onready var _play_home: TextureButton = $PlayHome
@onready var _payoff: CanvasLayer = $PayoffVideo
@onready var _player: VideoStreamPlayer = $PayoffVideo/Player
@onready var _finish: Node2D = $Finish


func _ready() -> void:
	var kid := Game.kid
	var rng := RandomNumberGenerator.new()
	if next_seed >= 0:
		rng.seed = next_seed
		next_seed = -1
	else:
		rng.randomize()
	maze = MazeModel.generate(kid.maze_size, kid.maze_braid, kid.maze_loops, kid.maze_max_turns, kid.maze_gates, rng)
	var colors: Array = GATE_COLORS.duplicate()
	for i in range(colors.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = colors[i]
		colors[i] = colors[j]
		colors[j] = tmp
	for i in maze.gates.size():
		_gate_colors.append(colors[i])
	_token.texture = load("res://assets/airport/token-%s.png" % kid.id)
	_sibling.texture = load("res://assets/airport/token-%s.png" % Game.sibling().id)
	_pass.texture = load("res://assets/airport/boarding-pass-%s.png" % _gate_colors[maze.correct])
	_pass.visible = maze.gates.size() > 1
	_a = maze.start
	_b = maze.start
	_play_home.pressed.connect(func(): Game.goto(Game.TITLE))
	$Finish/HomeButton.pressed.connect(func(): Game.goto(Game.TITLE))
	$Finish/ReplayButton.pressed.connect(func(): Game.goto(Game.MAZE))
	$Finish/ContinueButton.pressed.connect(func(): Game.goto(Game.MAP))
	get_viewport().size_changed.connect(_fit)
	_fit()
	_best = _distance_left()
	_say("find-gate")
	if _pass.visible:
		_say("match-airplane", true)


func _exit_tree() -> void:
	Music.hold(false)


## The visible part of the world (the camera is centered on 960, 540).
func view_rect() -> Rect2:
	var size := get_viewport().get_visible_rect().size
	return Rect2(Vector2(960, 540) - size / 2, size)


func cell_px() -> float:
	return _cell


func maze_rect() -> Rect2:
	return Rect2(_origin, Vector2(maze.size) * _cell)


func pass_rect() -> Rect2:
	var size := _pass.texture.get_size() * _pass.scale
	return Rect2(_pass.global_position - size / 2, size)


func cell_center(c: Vector2i) -> Vector2:
	return _origin + (Vector2(c) + Vector2(0.5, 0.5)) * _cell


## Where the token stands when it reaches gate i.
func gate_point(i: int) -> Vector2:
	return _node_point(_gate_node(i))


func token_position() -> Vector2:
	return _point_at(_a, _b, _t)


## [from node, to node, how far along]: where the token is.
func token_segment() -> Array:
	return [_a, _b, _t]


## Whether two nodes have an open corridor between them.
func connected(a: Vector2i, b: Vector2i) -> bool:
	if a == b:
		return true
	if maze.open(a, b):
		return true
	for i in maze.gates.size():
		var g := _gate_node(i)
		if (a == g and b == maze.gates[i]) or (b == g and a == maze.gates[i]):
			return true
	return false


func _unhandled_input(event: InputEvent) -> void:
	if finished:
		if event is InputEventMouseButton and event.pressed and _payoff.visible \
				and Time.get_ticks_msec() / 1000.0 - _video_started >= SKIP_GRACE:
			_show_finish()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var point := get_global_mouse_position()
		if event.pressed:
			_dragging = point.distance_to(token_position()) <= GRAB_CELLS * _cell
		else:
			_dragging = false
		if _dragging:
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _dragging:
		_follow(get_global_mouse_position())
		get_viewport().set_input_as_handled()


func _input(event: InputEvent) -> void:
	if event is InputEventMouse and event is InputEventMouseButton and event.pressed:
		_idle = 0.0


func _process(delta: float) -> void:
	if finished:
		return
	_idle += delta
	if not _hinting and _idle >= Game.kid.maze_hint_delay:
		_show_hint()


## Moves the token toward the finger, along open corridors only.
func _follow(finger: Vector2) -> void:
	var budget := MOVE_BUDGET * _cell
	for i in 32:
		if _a == _b:
			if not _turn_toward(_a, finger):
				break
			continue
		var a := _node_point(_a)
		var ab := _node_point(_b) - a
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
	_moved()


## The token is exactly at a node: pick the open corridor pointing at the finger.
func _turn_toward(node: Vector2i, finger: Vector2) -> bool:
	var here := _node_point(node)
	var to_finger := finger - here
	if to_finger.length() < _cell * 0.05:
		return false
	var best := node
	var best_dot := 0.3
	for n in _neighbors(node):
		var d := (_node_point(n) - here).normalized().dot(to_finger.normalized())
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
	_a = node
	_b = node
	_t = 0.0


func _neighbors(node: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for i in maze.gates.size():
		if node == _gate_node(i):
			out.append(maze.gates[i])
			return out
	if node.x >= 0 and node.x < maze.size.x:
		out.append_array(maze.exits(node))
		for i in maze.gates.size():
			if node == maze.gates[i]:
				out.append(_gate_node(i))
	return out


func _moved() -> void:
	_token.position = token_position()
	var p := token_position()
	if _trail.is_empty() or _trail.back().distance_to(p) > _cell * 0.1:
		_trail.append(p)
	_place_sibling()
	var left := _distance_left()
	if left < _best:
		_best = left
		_clear_hint()
	var gate := _gate_at(_a) if _a == _b else -1
	if gate != _at_gate:
		_at_gate = gate
		if gate >= 0:
			_reach_gate(gate)


func _reach_gate(i: int) -> void:
	if i == maze.correct:
		_found()
		return
	_bounce(_sibling)
	_say("not-this-one")


func _found() -> void:
	finished = true
	_dragging = false
	_clear_hint()
	_bounce(_token)
	_bounce(_sibling)
	Progress.mark_airport_done(Game.kid.id)
	_say("found-gate")
	if ResourceLoader.exists(payoff_video):
		_player.stream = load(payoff_video)
		_player.finished.connect(_show_finish)
		_payoff.visible = true
		_video_started = Time.get_ticks_msec() / 1000.0
		Music.hold(true)
		_player.play()
	else:
		_show_finish()


func _show_finish() -> void:
	if _finish.visible:
		return
	_player.stop()
	_payoff.visible = false
	Music.hold(false)
	_play_home.visible = false
	_finish.visible = true


## Cells left on the shortest way from the token to the right gate.
func _distance_left() -> int:
	var here := _a if _t < 0.5 else _b
	if _gate_at(here) == maze.correct:
		return 0
	if _gate_at(here) >= 0:
		here = maze.gates[_gate_at(here)]
	return maze.path(here, maze.gates[maze.correct]).size()


func _show_hint() -> void:
	_hinting = true
	_bounce(_sibling)
	_say("this-way")
	if not Game.kid.maze_footprints:
		return
	var here := _a if _t < 0.5 else _b
	if _gate_at(here) >= 0:
		here = maze.gates[_gate_at(here)]
	var route := maze.path(here, maze.gates[maze.correct])
	route.append(_gate_node(maze.correct))
	var steps := _footprints.get_children()
	for k in steps.size():
		var print_node: Sprite2D = steps[k]
		print_node.visible = k + 1 < route.size()
		if print_node.visible:
			var from := route[k]
			var to := route[k + 1]
			print_node.position = _node_point(to)
			print_node.rotation = (Vector2(to - from)).angle() + PI / 2


func _clear_hint() -> void:
	_idle = 0.0
	if not _hinting:
		return
	_hinting = false
	for n in _footprints.get_children():
		n.visible = false


func _place_sibling() -> void:
	# One cell behind along the way the token came.
	var left := _cell
	var p: Vector2 = _trail[0] if _trail.size() > 0 else token_position()
	for i in range(_trail.size() - 1, 0, -1):
		var seg := _trail[i].distance_to(_trail[i - 1])
		if seg >= left:
			p = _trail[i].move_toward(_trail[i - 1], left)
			break
		left -= seg
	if _trail.size() <= 1:
		p = token_position() + Vector2(-_cell * 0.35, _cell * 0.25)
	_sibling.position = p


func _bounce(sprite: Sprite2D) -> void:
	var t := create_tween()
	var rest := sprite.position
	t.tween_property(sprite, "position", rest + Vector2(0, -_cell * BOUNCE), 0.15).set_ease(Tween.EASE_OUT)
	t.tween_property(sprite, "position", rest, 0.2).set_ease(Tween.EASE_IN)
	t.set_loops(2)


func _say(line: String, wait := false) -> void:
	Voice.say(line, Game.sibling(), wait)


func _gate_node(i: int) -> Vector2i:
	return Vector2i(maze.size.x, maze.gates[i].y)


func _gate_at(node: Vector2i) -> int:
	for i in maze.gates.size():
		if node == _gate_node(i):
			return i
	return -1


## World point of a node: a cell center, or a gate's standing spot past the right edge.
func _node_point(node: Vector2i) -> Vector2:
	if node.x >= maze.size.x:
		return _origin + Vector2(maze.size.x * _cell + _cell * 0.45, (node.y + 0.5) * _cell)
	return cell_center(node)


func _point_at(a: Vector2i, b: Vector2i, t: float) -> Vector2:
	return _node_point(a).lerp(_node_point(b), t)


func _fit() -> void:
	var view := view_rect()
	_background.position = Vector2(960, 540)
	_background.scale = Vector2.ONE * maxf(view.size.x / BG_SIZE.x, view.size.y / BG_SIZE.y)
	var cols := float(maze.size.x) + GATE_CELLS
	var avail := Vector2(view.size.x - 2 * MARGIN, view.size.y - TOP_BAND - MARGIN)
	_cell = minf(MAX_CELL, minf(avail.x / cols, avail.y / maze.size.y))
	var total := Vector2(cols * _cell, maze.size.y * _cell)
	_origin = Vector2(960 - total.x / 2, view.position.y + TOP_BAND + (avail.y - total.y) / 2)
	_play_home.position = view.position + Vector2(MARGIN, MARGIN)
	_play_home.size = Vector2.ONE * 130.0
	var pass_h := TOP_BAND - 2 * MARGIN
	_pass.scale = Vector2.ONE * pass_h / _pass.texture.get_size().y
	_pass.position = view.position + Vector2(MARGIN + 130.0 + MARGIN, MARGIN) + _pass.texture.get_size() * _pass.scale / 2
	_draw_walls()
	_place_gates()
	_place_decor()
	_size_sprite(_token, TOKEN_CELLS)
	_size_sprite(_sibling, SIBLING_CELLS)
	for n: Sprite2D in _footprints.get_children():
		_size_sprite(n, 0.7)
	_token.position = token_position()
	_place_sibling()


func _size_sprite(sprite: Sprite2D, cells: float) -> void:
	sprite.scale = Vector2.ONE * cells * _cell / sprite.texture.get_size().x


## Walls as rounded strokes: every closed edge between cells, and the outside
## edge except where the gates open.
func _draw_walls() -> void:
	for n in _walls.get_children():
		n.free()
	var w := maze.size.x
	var h := maze.size.y
	var runs: Array = []
	# Horizontal walls: along the top edge of row y (y = 0..h).
	for y in h + 1:
		var start := -1
		for x in w + 1:
			var closed := x < w and (y == 0 or y == h or not maze.open(Vector2i(x, y - 1), Vector2i(x, y)))
			if closed and start < 0:
				start = x
			elif not closed and start >= 0:
				runs.append([Vector2(start, y), Vector2(x, y)])
				start = -1
	# Vertical walls: along the left edge of column x (x = 0..w).
	var gate_rows := {}
	for g in maze.gates:
		gate_rows[g.y] = true
	for x in w + 1:
		var start := -1
		for y in h + 1:
			var closed := false
			if y < h:
				if x == 0:
					closed = true
				elif x == w:
					closed = not gate_rows.has(y)
				else:
					closed = not maze.open(Vector2i(x - 1, y), Vector2i(x, y))
			if closed and start < 0:
				start = y
			elif not closed and start >= 0:
				runs.append([Vector2(x, start), Vector2(x, y)])
				start = -1
	for layer in [[WALL_OUTLINE, WALL_CELLS * _cell + 2 * WALL_OUTLINE_PX], [WALL_FILL, WALL_CELLS * _cell]]:
		for run in runs:
			var line := Line2D.new()
			line.default_color = layer[0]
			line.width = layer[1]
			line.begin_cap_mode = Line2D.LINE_CAP_ROUND
			line.end_cap_mode = Line2D.LINE_CAP_ROUND
			line.points = PackedVector2Array([_origin + run[0] * _cell, _origin + run[1] * _cell])
			_walls.add_child(line)


func _place_gates() -> void:
	for n in _gates.get_children():
		n.free()
	for i in maze.gates.size():
		var gate := Sprite2D.new()
		gate.texture = load("res://assets/airport/gate-%s.png" % _gate_colors[i])
		gate.scale = Vector2.ONE * GATE_CELLS * _cell / gate.texture.get_size().x
		# Drawn with the airplane at the top: turn it so the desk faces the maze.
		gate.rotation = PI / 2
		gate.position = _origin + Vector2(maze.size.x * _cell + GATE_CELLS * _cell / 2, (maze.gates[i].y + 0.5) * _cell)
		_gates.add_child(gate)


## Airport furniture in dead-end cells off the way to the gate.
func _place_decor() -> void:
	for n in _decor.get_children():
		n.free()
	var route := {}
	for c in maze.path(maze.start, maze.gates[maze.correct]):
		route[c] = true
	var placed := 0
	for y in maze.size.y:
		for x in maze.size.x:
			var c := Vector2i(x, y)
			if placed >= MAX_DECOR or route.has(c) or c == maze.start or maze.exits(c).size() != 1:
				continue
			var sprite := Sprite2D.new()
			sprite.texture = load("res://assets/airport/maze-decor-%s.png" % DECOR[(x * 7 + y * 3) % DECOR.size()])
			sprite.scale = Vector2.ONE * 0.55 * _cell / sprite.texture.get_size().x
			sprite.position = cell_center(c)
			_decor.add_child(sprite)
			placed += 1
