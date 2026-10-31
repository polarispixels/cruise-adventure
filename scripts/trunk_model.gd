# The trunk puzzle's rules: a grid of cells (some blocked by the wheel wells),
# bags that cover a block of cells standing up or turned on their side, and
# which bag sits where. A small backtracking solver answers "can the trunk
# still be filled from here?", which the helper's hints use.
class_name TrunkModel
extends RefCounted

const NOWHERE := Vector2i(-1, -1)

var cols: int
var rows: int
## Bag ids in file order.
var bag_ids: Array[String] = []

var _blocked := {}
var _sizes := {}
var _turned := {}
var _cells := {}
var _reference := {}


static func from_file(path := "res://data/trunk.json") -> TrunkModel:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var m := TrunkModel.new()
	m.cols = int(data["cols"])
	m.rows = int(data["rows"])
	for c in data["blocked"]:
		m._blocked[Vector2i(int(c[0]), int(c[1]))] = true
	for bag in data["bags"]:
		var id: String = bag["id"]
		m.bag_ids.append(id)
		m._sizes[id] = Vector2i(int(bag["size"][0]), int(bag["size"][1]))
		m._turned[id] = false
	for id in data["solution"]:
		var s: Dictionary = data["solution"][id]
		m._reference[id] = {"cell": Vector2i(int(s["cell"][0]), int(s["cell"][1])), "turned": bool(s["turned"])}
	return m


func size_of(id: String, turned: bool) -> Vector2i:
	var s: Vector2i = _sizes[id]
	return Vector2i(s.y, s.x) if turned else s


func is_turned(id: String) -> bool:
	return _turned[id]


func set_turned(id: String, turned: bool) -> void:
	_turned[id] = turned


## Whether the bag, turned as it is now, fits with its top-left at `cell`.
func can_place(id: String, cell: Vector2i) -> bool:
	return _fits(id, cell, _turned[id], _occupied(id))


func place(id: String, cell: Vector2i) -> bool:
	if not can_place(id, cell):
		return false
	_cells[id] = cell
	return true


func remove(id: String) -> void:
	_cells.erase(id)


func cell_of(id: String) -> Vector2i:
	return _cells.get(id, NOWHERE)


func placed_ids() -> Array[String]:
	var out: Array[String] = []
	for id in bag_ids:
		if _cells.has(id):
			out.append(id)
	return out


func is_full() -> bool:
	return _cells.size() == bag_ids.size()


## A full arrangement that keeps the placed bags where they are, as
## {id: {"cell": Vector2i, "turned": bool}}, or {} when there is none.
func solve(allow_turns := true) -> Dictionary:
	var taken := _occupied("")
	var out := {}
	for id in _cells:
		out[id] = {"cell": _cells[id], "turned": _turned[id]}
	var left: Array[String] = []
	for id in bag_ids:
		if not _cells.has(id):
			left.append(id)
	return out if _search(taken, left, out, allow_turns) else {}


## The solution from data, in solve()'s shape.
func reference_solution() -> Dictionary:
	return _reference.duplicate(true)


## What the helper should point at: {} when full; {"kind": "wrong", "id"}
## when the bags in the trunk can't lead to a full trunk; otherwise
## {"kind": "next", "id", "cell", "turned"} for a bag that needs turning, or
## else the biggest bag left.
func hint() -> Dictionary:
	if is_full():
		return {}
	var sol := solve()
	if sol.is_empty():
		for id in placed_ids():
			var cell: Vector2i = _cells[id]
			_cells.erase(id)
			var ok := not solve().is_empty()
			_cells[id] = cell
			if ok:
				return {"kind": "wrong", "id": id}
		return {"kind": "wrong", "id": placed_ids()[0]}
	var pick := ""
	for id in bag_ids:
		if not _cells.has(id) and sol[id]["turned"] != _turned[id]:
			pick = id
			break
	if pick == "":
		var best := -1
		for id in bag_ids:
			var s: Vector2i = _sizes[id]
			if not _cells.has(id) and s.x * s.y > best:
				best = s.x * s.y
				pick = id
	return {"kind": "next", "id": pick, "cell": sol[pick]["cell"], "turned": sol[pick]["turned"]}


func _fits(id: String, cell: Vector2i, turned: bool, taken: Dictionary) -> bool:
	var s := size_of(id, turned)
	for y in s.y:
		for x in s.x:
			var c := cell + Vector2i(x, y)
			if c.x < 0 or c.y < 0 or c.x >= cols or c.y >= rows or _blocked.has(c) or taken.has(c):
				return false
	return true


## Cells covered by placed bags, except `skip`'s own.
func _occupied(skip: String) -> Dictionary:
	var taken := {}
	for id in _cells:
		if id == skip:
			continue
		_mark(taken, id, _cells[id], _turned[id], true)
	return taken


func _mark(taken: Dictionary, id: String, cell: Vector2i, turned: bool, on: bool) -> void:
	var s := size_of(id, turned)
	for y in s.y:
		for x in s.x:
			if on:
				taken[cell + Vector2i(x, y)] = true
			else:
				taken.erase(cell + Vector2i(x, y))


## Fills the first empty open cell with some remaining bag, depth first.
func _search(taken: Dictionary, left: Array[String], out: Dictionary, allow_turns: bool) -> bool:
	var first := NOWHERE
	for y in rows:
		for x in cols:
			var c := Vector2i(x, y)
			if not taken.has(c) and not _blocked.has(c):
				first = c
				break
		if first != NOWHERE:
			break
	if first == NOWHERE:
		return left.is_empty()
	for i in left.size():
		var id := left[i]
		for turned in ([false, true] if allow_turns else [false]):
			if turned and size_of(id, true) == size_of(id, false):
				continue
			if not _fits(id, first, turned, taken):
				continue
			_mark(taken, id, first, turned, true)
			out[id] = {"cell": first, "turned": turned}
			var rest := left.duplicate()
			rest.remove_at(i)
			if _search(taken, rest, out, allow_turns):
				return true
			_mark(taken, id, first, turned, false)
			out.erase(id)
	return false
