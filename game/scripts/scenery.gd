class_name Scenery
extends RefCounted
## Drawing helpers for forest things. Each takes the CanvasItem to draw on (call from _draw).

const OUTLINE := Color("2a1d17")


static func sky(c: CanvasItem, top: Color, bottom: Color, rect := Rect2(0, 0, 1280, 720)) -> void:
	c.draw_polygon(PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end,
			Vector2(rect.position.x, rect.end.y)]), PackedColorArray([top, top, bottom, bottom]))


static func tree(c: CanvasItem, base: Vector2, s: float, leaves: Color, trunk := Color("6b4428")) -> void:
	c.draw_rect(Rect2(base + Vector2(-12, -90) * s, Vector2(24, 90) * s), trunk)
	for blob in [Vector3(0, -150, 62), Vector3(-42, -110, 48), Vector3(42, -112, 50), Vector3(0, -195, 46)]:
		c.draw_circle(base + Vector2(blob.x, blob.y) * s, blob.z * s, leaves.darkened(0.15))
	for blob in [Vector3(-6, -158, 54), Vector3(-36, -118, 40), Vector3(36, -120, 42), Vector3(-4, -198, 38)]:
		c.draw_circle(base + Vector2(blob.x, blob.y) * s, blob.z * s, leaves)


static func pine(c: CanvasItem, base: Vector2, s: float, color: Color) -> void:
	c.draw_rect(Rect2(base + Vector2(-8, -30) * s, Vector2(16, 30) * s), color.darkened(0.3))
	for i in 3:
		var y := -30.0 - i * 45.0
		var w := 70.0 - i * 16.0
		c.draw_colored_polygon(PackedVector2Array([base + Vector2(-w, y) * s, base + Vector2(w, y) * s,
				base + Vector2(0, y - 80) * s]), color)


static func bush(c: CanvasItem, base: Vector2, s: float, color: Color, berries := false) -> void:
	c.draw_circle(base + Vector2(-28, -22) * s, 28 * s, color.darkened(0.12))
	c.draw_circle(base + Vector2(28, -22) * s, 28 * s, color.darkened(0.12))
	c.draw_circle(base + Vector2(0, -38) * s, 34 * s, color)
	if berries:
		for p in [Vector2(-20, -30), Vector2(10, -50), Vector2(24, -24), Vector2(-4, -20)]:
			c.draw_circle(base + p * s, 5 * s, Color("e2445c"))


static func rock(c: CanvasItem, base: Vector2, s: float, color := Color("8d8f96")) -> void:
	var pts := PackedVector2Array([Vector2(-50, 0), Vector2(-44, -30), Vector2(-14, -48), Vector2(26, -44),
			Vector2(50, -18), Vector2(52, 0)])
	var outline := PackedVector2Array()
	var fill := PackedVector2Array()
	for p in pts:
		outline.append(base + p * s * 1.06 + Vector2(0, 2))
		fill.append(base + p * s)
	c.draw_colored_polygon(outline, OUTLINE)
	c.draw_colored_polygon(fill, color)
	c.draw_colored_polygon(PackedVector2Array([base + Vector2(-30, -34) * s, base + Vector2(-12, -42) * s,
			base + Vector2(10, -38) * s, base + Vector2(-20, -28) * s]), color.lightened(0.25))


static func flower(c: CanvasItem, pos: Vector2, color: Color) -> void:
	c.draw_line(pos, pos + Vector2(0, 12), Color("3e7d2a"), 2.0)
	for i in 5:
		var a := TAU * i / 5.0
		c.draw_circle(pos + Vector2(cos(a), sin(a)) * 5.0, 4.0, color)
	c.draw_circle(pos, 3.0, Color("ffd23f"))


static func grass_tuft(c: CanvasItem, pos: Vector2, color: Color) -> void:
	for dx in [-6, 0, 6]:
		c.draw_line(pos + Vector2(dx, 0), pos + Vector2(dx * 1.8, -16 + absf(dx)), color, 3.0)


static func star(c: CanvasItem, pos: Vector2, r: float, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI / 2 + TAU * i / 10.0
		var rr := r if i % 2 == 0 else r * 0.45
		pts.append(pos + Vector2(cos(a), sin(a)) * rr)
	c.draw_colored_polygon(pts, color)


static func fireflies(parent: Node, area: Rect2, color := Color("fff27a")) -> void:
	var p := CPUParticles2D.new()
	p.position = area.get_center()
	p.amount = 30
	p.lifetime = 4.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = area.size / 2.0
	p.gravity = Vector2.ZERO
	p.direction = Vector2.UP
	p.spread = 180.0
	p.initial_velocity_min = 5.0
	p.initial_velocity_max = 25.0
	p.scale_amount_min = 3.0
	p.scale_amount_max = 5.0
	var ramp := Gradient.new()
	ramp.set_color(0, Color(color, 0.0))
	ramp.add_point(0.5, color)
	ramp.set_color(ramp.get_point_count() - 1, Color(color, 0.0))
	p.color_ramp = ramp
	parent.add_child(p)
