class_name Cat
extends Node2D
## A cartoon cat drawn with shapes. The origin is at the cat's feet and it faces right.

const OUTLINE := Color("2a1d17")
const PINK := Color("f29bb0")

var fur := Color("e8862a")
var markings := Color("4a2c18")
var pattern := "Solid"
var eyes := Color("5fd14a")
var size := 1.0
var facing := 1.0  # 1 = right, -1 = left
var walk_amount := 0.0  # 0 = standing still, 1 = walking
var lift := 0.0  # how high the cat is off the ground (for pounces)
var squish := Vector2.ONE

var _phase := 0.0
var _time := 0.0
var _blink := 0.0
var _next_blink := 2.0


func _ready() -> void:
	_time = randf() * 10.0


func set_look(look: Dictionary) -> void:
	fur = look.fur
	markings = look.markings
	pattern = look.pattern
	eyes = look.eyes
	queue_redraw()


func bounce(amount := 0.25) -> void:
	squish = Vector2(1.0 + amount, 1.0 - amount)


func _process(delta: float) -> void:
	_time += delta
	_phase += delta * 13.0 * walk_amount
	squish = squish.lerp(Vector2.ONE, minf(1.0, delta * 9.0))
	_next_blink -= delta
	if _next_blink <= 0.0:
		_blink = 0.14
		_next_blink = randf_range(2.0, 5.0)
	_blink = maxf(0.0, _blink - delta)
	queue_redraw()


func _draw() -> void:
	# Shadow stays on the ground even while pouncing
	var shadow_scale := 1.0 / (1.0 + lift / 120.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(size, size))
	_ellipse(Vector2(6, 0), Vector2(50, 8) * shadow_scale, Color(0, 0, 0, 0.2))

	draw_set_transform(Vector2(0, -lift), 0.0, Vector2(facing * size * squish.x, size * squish.y))
	var bob := -absf(sin(_phase)) * 3.0 * walk_amount
	_silhouette(bob)
	_fills(bob)


# --- body geometry -------------------------------------------------------------------------

func _leg_points(x: float, phase_offset: float, bob: float) -> Array:
	var s := sin(_phase + phase_offset) * walk_amount
	var top := Vector2(x, -32 + bob)
	var foot := Vector2(x - s * 9.0, -6 - maxf(0.0, s) * 5.0)
	return [top, foot]


func _tail_points(bob: float) -> Array:
	var points := []
	var base := Vector2(-34, -44 + bob)
	for i in 14:
		var t := i / 13.0
		var sway := sin(_time * 2.6 + t * 2.2) * 9.0 * t
		points.append(base + Vector2(-34.0 * sin(t * 1.4) + sway, -48.0 * t))
	return points


func _ear(front: bool, bob: float) -> PackedVector2Array:
	if front:
		return PackedVector2Array([Vector2(42, -80 + bob), Vector2(57, -100 + bob), Vector2(60, -70 + bob)])
	return PackedVector2Array([Vector2(22, -72 + bob), Vector2(26, -98 + bob), Vector2(42, -82 + bob)])


func _far_legs(bob: float) -> Array:
	return [_leg_points(-26, PI, bob), _leg_points(22, 0.0, bob)]


func _near_legs(bob: float) -> Array:
	return [_leg_points(-15, 0.0, bob), _leg_points(31, PI, bob)]


# --- drawing -------------------------------------------------------------------------------

func _silhouette(bob: float) -> void:
	var e := 3.0
	for leg in _far_legs(bob) + _near_legs(bob):
		_leg(leg, OUTLINE, e)
	for p in _tail_points(bob):
		draw_circle(p, _tail_radius(p, bob) + e, OUTLINE)
	_ellipse(Vector2(0, -38 + bob), Vector2(40, 21) + Vector2(e, e), OUTLINE)
	_ellipse(Vector2(27, -50 + bob), Vector2(15, 17) + Vector2(e, e), OUTLINE)
	draw_colored_polygon(_grow(_ear(false, bob), e), OUTLINE)
	draw_colored_polygon(_grow(_ear(true, bob), e), OUTLINE)
	draw_circle(Vector2(40, -62 + bob), 21 + e, OUTLINE)


func _fills(bob: float) -> void:
	var dark := fur.darkened(0.18)
	var paws := markings if pattern == "Socks" else fur
	for leg in _far_legs(bob):
		_leg(leg, dark, 0.0)
		if pattern == "Socks":
			draw_circle(leg[1], 6.0, markings.darkened(0.12))

	var tail := _tail_points(bob)
	for i in tail.size():
		var c := fur
		if pattern == "Tabby Stripes" and (i / 2) % 2 == 1:
			c = markings
		elif (pattern == "Socks" or pattern == "Patches") and i >= 11:
			c = markings
		draw_circle(tail[i], _tail_radius(tail[i], bob), c)

	_ellipse(Vector2(0, -38 + bob), Vector2(40, 21), fur)
	_ellipse(Vector2(27, -50 + bob), Vector2(15, 17), fur)
	_body_pattern(bob)

	for leg in _near_legs(bob):
		_leg(leg, OUTLINE, 2.5)
		_leg(leg, fur, 0.0)
		if pattern == "Socks":
			draw_line(leg[0].lerp(leg[1], 0.55), leg[1], paws, 12.0)
			draw_circle(leg[1], 6.0, paws)

	draw_colored_polygon(_ear(false, bob), fur.darkened(0.1))
	draw_colored_polygon(_ear(true, bob), fur)
	draw_colored_polygon(_grow(_ear(true, bob), -5.0), PINK)
	draw_circle(Vector2(40, -62 + bob), 21, fur)
	_head_pattern(bob)
	_face(bob)


func _body_pattern(bob: float) -> void:
	match pattern:
		"Tabby Stripes":
			for x in [-27, -15, -3, 9]:
				var top := -38.0 + bob - 21.0 * sqrt(1.0 - pow(x / 40.0, 2))
				draw_line(Vector2(x, top + 3), Vector2(x - 3, top + 17), markings, 5.0)
		"Spots":
			for p in [Vector2(-24, -44), Vector2(-12, -51), Vector2(-6, -36), Vector2(6, -46),
					Vector2(14, -33), Vector2(-30, -34), Vector2(18, -50)]:
				draw_circle(p + Vector2(0, bob), 4.5, markings)
		"Patches":
			_ellipse(Vector2(-18, -45 + bob), Vector2(17, 12), markings)
			_ellipse(Vector2(14, -31 + bob), Vector2(12, 8), markings)
		"Socks":
			_ellipse(Vector2(31, -44 + bob), Vector2(10, 14), markings)


func _head_pattern(bob: float) -> void:
	match pattern:
		"Tabby Stripes":
			for x in [35, 41, 47]:
				draw_line(Vector2(x, -81 + bob), Vector2(x, -72 + bob), markings, 3.5)
		"Spots":
			draw_circle(Vector2(30, -70 + bob), 3.5, markings)
		"Patches":
			_ellipse(Vector2(32, -68 + bob), Vector2(9, 8), markings)


func _face(bob: float) -> void:
	var o := Vector2(0, bob)
	var muzzle := markings if pattern == "Socks" else fur.lightened(0.35)
	_ellipse(Vector2(50, -54) + o, Vector2(12, 8), muzzle)
	for eye_x in [33.0, 49.0]:
		var c := Vector2(eye_x, -66) + o
		if _blink > 0.0:
			draw_line(c + Vector2(-5, 0), c + Vector2(5, 0), OUTLINE, 2.5)
			continue
		_ellipse(c, Vector2(6.5, 8), OUTLINE)
		_ellipse(c, Vector2(5, 6.5), eyes)
		_ellipse(c + Vector2(0.8, 0.5), Vector2(2, 5), Color("1a1418"))
		draw_circle(c + Vector2(2.2, -2.8), 1.8, Color.WHITE)
	draw_colored_polygon(PackedVector2Array([Vector2(52, -60) + o, Vector2(59, -60) + o,
			Vector2(55.5, -56) + o]), PINK)
	draw_line(Vector2(55.5, -56) + o, Vector2(55.5, -53) + o, OUTLINE, 1.5)
	draw_arc(Vector2(53, -53) + o, 2.5, 0.0, PI, 6, OUTLINE, 1.5)
	draw_arc(Vector2(58, -53) + o, 2.5, 0.0, PI, 6, OUTLINE, 1.5)
	var whisker := Color(OUTLINE, 0.55)
	draw_line(Vector2(59, -55) + o, Vector2(78, -59) + o, whisker, 1.5)
	draw_line(Vector2(59, -53) + o, Vector2(79, -52) + o, whisker, 1.5)


func _tail_radius(_p: Vector2, _bob: float) -> float:
	return 6.5


func _leg(leg: Array, color: Color, e: float) -> void:
	draw_line(leg[0], leg[1], color, 12.0 + e * 2.0)
	draw_circle(leg[1], 6.0 + e, color)
	draw_circle(leg[0], 6.0 + e, color)


func _ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in 28:
		var a := TAU * i / 28.0
		pts.append(center + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	draw_colored_polygon(pts, color)


func _grow(tri: PackedVector2Array, amount: float) -> PackedVector2Array:
	var center := (tri[0] + tri[1] + tri[2]) / 3.0
	var out := PackedVector2Array()
	for p in tri:
		out.append(center + (p - center) * (1.0 + amount / 9.0))
	return out
