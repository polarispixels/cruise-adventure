extends RefCounted

const FEET := Vector2(512, 1480)


func _make(t, kid_id := "becca", at := Vector2(300, 900)) -> Character:
	var c: Character = load("res://scenes/character.tscn").instantiate()
	c.kid = load("res://data/%s.tres" % kid_id)
	c.position = at
	t.tree.root.add_child(c)
	return c


func test_feet_are_origin(t) -> void:
	var c := _make(t)
	var sprite: Sprite2D = c.get_node("Sprite")
	var feet: Vector2 = sprite.global_transform * (FEET + sprite.offset)
	t.check(feet.distance_to(Vector2(300, 900)) < 0.5, "feet at origin, got %s" % feet)
	t.eq(sprite.texture, c.kid.character("idle"), "starts idle")
	c.free()


func test_mirrored_flips(t) -> void:
	var c := _make(t)
	c.mirrored = true
	t.check(c.scale.x < 0, "flipped")
	var sprite: Sprite2D = c.get_node("Sprite")
	var feet: Vector2 = sprite.global_transform * (FEET + sprite.offset)
	t.check(feet.distance_to(Vector2(300, 900)) < 0.5, "feet unchanged")
	c.free()


func test_cheer_returns_to_idle(t) -> void:
	var c := _make(t)
	c.cheer()
	t.eq(c.pose, "cheer", "cheering")
	await t.tree.create_timer(1.2).timeout
	t.eq(c.pose, "idle", "back to idle")
	t.check(absf(c.position.y - 900) < 0.5, "landed, y=%s" % c.position.y)
	c.free()


func test_point_faces_target(t) -> void:
	var c := _make(t, "jack", Vector2(500, 900))
	c.point_at(Vector2(100, 600))
	t.eq(c.pose, "point", "pointing")
	t.check(c.scale.x < 0, "faces left")
	c.point_at(Vector2(900, 600))
	t.check(c.scale.x > 0, "faces right")
	c.free()


func test_actions_interrupt_cleanly(t) -> void:
	var c := _make(t)
	c.cheer()
	await t.tree.process_frame
	c.wave()
	await t.tree.create_timer(1.5).timeout
	t.eq(c.pose, "idle", "idle after wave")
	t.check(absf(c.position.y - 900) < 0.5, "not left mid-hop, y=%s" % c.position.y)
	c.free()
