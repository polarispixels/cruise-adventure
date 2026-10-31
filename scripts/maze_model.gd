# The airport gate maze: a grid of terminal cells with walls between them.
# generate() makes a fresh one every play from the kid's settings: a random
# depth-first maze, some dead ends opened up (braid), a few extra loops, the
# start in the left column and the gates as openings in the right edge.
# Becca's maze also keeps its main path to a few turns. Every maze is solvable.
class_name MazeModel
extends RefCounted

const DIRS: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]
const TRIES := 200

var size: Vector2i
var start: Vector2i
## The right-column cell each gate opens from, top to bottom.
var gates: Array[Vector2i] = []
## Index into gates of the kid's gate.
var correct := 0

## Open passages, stored once per pair: {Vector2i cell: bits}, bit 1 = right, bit 2 = down.
var _open := {}


static func generate(maze_size: Vector2i, braid: float, loops: int, max_turns: int, gate_count: int, rng: RandomNumberGenerator) -> MazeModel:
	var m: MazeModel
	for i in TRIES:
		m = _attempt(maze_size, braid, loops, gate_count, rng)
		if max_turns <= 0 or turns(m.path(m.start, m.gates[m.correct])) <= max_turns:
			return m
	# Still too twisty after every try: carve a straight run along the start's row
	# and one turn to the gate. It only opens walls, so the maze stays a maze.
	var g := m.gates[m.correct]
	for x in range(0, maze_size.x - 1):
		m._set_open(Vector2i(x, m.start.y), Vector2i(x + 1, m.start.y))
	var step := 1 if g.y > m.start.y else -1
	for y in range(m.start.y, g.y, step):
		m._set_open(Vector2i(g.x, y), Vector2i(g.x, y + step))
	return m


static func _attempt(maze_size: Vector2i, braid: float, loops: int, gate_count: int, rng: RandomNumberGenerator) -> MazeModel:
	var m := MazeModel.new()
	m.size = maze_size
	m._carve(rng)
	m._braid(braid, rng)
	m._add_loops(loops, rng)
	m.start = Vector2i(0, rng.randi_range(0, maze_size.y - 1))
	var rows: Array[int] = []
	if gate_count <= 1:
		rows.append(rng.randi_range(0, maze_size.y - 1))
	else:
		for i in gate_count:
			rows.append(roundi(float(i) * (maze_size.y - 1) / (gate_count - 1)))
	for r in rows:
		m.gates.append(Vector2i(maze_size.x - 1, r))
	m.correct = rng.randi_range(0, m.gates.size() - 1)
	return m


## Whether a and b are neighbors with no wall between them.
func open(a: Vector2i, b: Vector2i) -> bool:
	if not _inside(a) or not _inside(b):
		return false
	var d := b - a
	if d == Vector2i.RIGHT:
		return _open.get(a, 0) & 1 != 0
	if d == Vector2i.DOWN:
		return _open.get(a, 0) & 2 != 0
	if d == Vector2i.LEFT or d == Vector2i.UP:
		return open(b, a)
	return false


## Shortest path from one cell to another, both included; [] if unreachable.
func path(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var came := {from: from}
	var queue: Array[Vector2i] = [from]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		if c == to:
			var out: Array[Vector2i] = [c]
			while c != from:
				c = came[c]
				out.push_front(c)
			return out
		for d in DIRS:
			var n := c + d
			if not came.has(n) and open(c, n):
				came[n] = c
				queue.append(n)
	return []


## How many times a path changes direction.
static func turns(cells: Array[Vector2i]) -> int:
	var n := 0
	for i in range(2, cells.size()):
		if cells[i] - cells[i - 1] != cells[i - 1] - cells[i - 2]:
			n += 1
	return n


## Cells with exactly one way out.
func dead_ends() -> int:
	var n := 0
	for y in size.y:
		for x in size.x:
			if exits(Vector2i(x, y)).size() == 1:
				n += 1
	return n


## The open neighbors of a cell.
func exits(c: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for d in DIRS:
		if open(c, c + d):
			out.append(c + d)
	return out


func _inside(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < size.x and c.y < size.y


func _set_open(a: Vector2i, b: Vector2i) -> void:
	var d := b - a
	if d == Vector2i.LEFT or d == Vector2i.UP:
		_set_open(b, a)
	elif d == Vector2i.RIGHT:
		_open[a] = _open.get(a, 0) | 1
	elif d == Vector2i.DOWN:
		_open[a] = _open.get(a, 0) | 2


func _closed_neighbors(c: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for d in DIRS:
		var n := c + d
		if _inside(n) and not open(c, n):
			out.append(n)
	return out


## Randomized depth-first carving: one long winding passage with branches.
func _carve(rng: RandomNumberGenerator) -> void:
	var first := Vector2i(rng.randi_range(0, size.x - 1), rng.randi_range(0, size.y - 1))
	var seen := {first: true}
	var stack: Array[Vector2i] = [first]
	while not stack.is_empty():
		var c: Vector2i = stack.back()
		var fresh: Array[Vector2i] = []
		for d in DIRS:
			var n := c + d
			if _inside(n) and not seen.has(n):
				fresh.append(n)
		if fresh.is_empty():
			stack.pop_back()
			continue
		var n: Vector2i = fresh[rng.randi_range(0, fresh.size() - 1)]
		_set_open(c, n)
		seen[n] = true
		stack.append(n)


## Opens up a share of the dead ends (fewer dead ends = an easier maze).
func _braid(share: float, rng: RandomNumberGenerator) -> void:
	var ends: Array[Vector2i] = []
	for y in size.y:
		for x in size.x:
			if exits(Vector2i(x, y)).size() == 1:
				ends.append(Vector2i(x, y))
	_shuffle(ends, rng)
	for c in ends.slice(0, roundi(share * ends.size())):
		if exits(c).size() != 1:
			continue
		var options := _closed_neighbors(c)
		if not options.is_empty():
			_set_open(c, options[rng.randi_range(0, options.size() - 1)])


## Knocks down extra walls so there's more than one way around.
func _add_loops(count: int, rng: RandomNumberGenerator) -> void:
	var added := 0
	var guard := 0
	while added < count and guard < 1000:
		guard += 1
		var c := Vector2i(rng.randi_range(0, size.x - 1), rng.randi_range(0, size.y - 1))
		var options := _closed_neighbors(c)
		if options.is_empty():
			continue
		_set_open(c, options[rng.randi_range(0, options.size() - 1)])
		added += 1


func _shuffle(cells: Array[Vector2i], rng: RandomNumberGenerator) -> void:
	for i in range(cells.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := cells[i]
		cells[i] = cells[j]
		cells[j] = tmp
