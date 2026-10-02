class_name Cat
extends Node2D
## A cute chibi cat drawn with shapes: big round head, sparkly eyes, rosy cheeks.
## The origin is at the cat's feet and it faces right.

const OUTLINE := Color("4a2f3c")
const PINK := Color("ff8fab")
const BLUSH := Color(1.0, 0.55, 0.65, 0.55)

const HEAD := Vector2(18, -60)
const HEAD_R := Vector2(33, 29)
const BODY := Vector2(-4, -24)
const BODY_R := Vector2(27, 18)

var fur := Color("e8862a")
var markings := Color("4a2c18")
var pattern := "Solid"
var eyes := Color("5fd14a")
var fluffy := false
var mood := "happy"  # "happy" or "grumpy"
var collar := false  # kittypets wear a collar with a bell
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
	fluffy = look.get("fluffy", false)
	mood = look.get("mood", "happy")
	queue_redraw()


func bounce(amount := 0.25) -> void:
	squish = Vector2(1.0 + amount, 1.0 - amount)


func _process(delta: float) -> void:
	_time += delta
	_phase += delta * 13.0 * walk_amount
	squish = squish.lerp(Vector2.ONE, minf(1.0, delta * 9.0))
	_next_blink -= delta
	if _next_blink <= 0.0:
		_blink = 0.16
		_next_blink = randf_range(2.0, 5.0)
	_blink = maxf(0.0, _blink - delta)
	queue_redraw()


func _draw() -> void:
	var shadow_scale := 1.0 / (1.0 + lift / 120.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(size, size))
	_ellipse(Vector2(2, 0), Vector2(36, 7) * shadow_scale, Color(0, 0, 0, 0.18))

	draw_set_transform(Vector2(0, -lift), 0.0, Vector2(facing * size * squish.x, size * squish.y))
	var bob := -absf(sin(_phase)) * 3.0 * walk_amount
	var head_bob := Vector2(0, bob + sin(_time * 2.0) * 0.8)
	_silhouette(bob, head_bob)
	_fills(bob, head_bob)


# --- body geometry -------------------------------------------------------------------------

func _leg_points(x: float, phase_offset: float, bob: float) -> Array:
	var s := sin(_phase + phase_offset) * walk_amount
	return [Vector2(x, -18 + bob), Vector2(x - s * 6.0, -5 - maxf(0.0, s) * 4.0)]


func _far_legs(bob: float) -> Array:
	return [_leg_points(-20, PI, bob), _leg_points(10, 0.0, bob)]


func _near_legs(bob: float) -> Array:
	return [_leg_points(-12, 0.0, bob), _leg_points(18, PI, bob)]


func _tail_points(bob: float) -> Array:
	var points := []
	var base := Vector2(-28, -30 + bob)
	for i in 12:
		var t := i / 11.0
		var sway := sin(_time * 2.6 + t * 2.0) * 7.0 * t
		points.append(base + Vector2(-20.0 * sin(t * PI * 0.8) - 6.0 * t + sway, -40.0 * t))
	return points


func _tail_radius() -> float:
	return 8.5 if fluffy else 6.0


func _ear(front: bool, h: Vector2) -> PackedVector2Array:
	if front:
		return PackedVector2Array([Vector2(24, -86) + h, Vector2(44, -106) + h, Vector2(49, -76) + h])
	return PackedVector2Array([Vector2(-8, -74) + h, Vector2(-7, -103) + h, Vector2(14, -87) + h])


func _cheek_tufts(h: Vector2) -> Array:
	return [
		PackedVector2Array([Vector2(-10, -58) + h, Vector2(-22, -44) + h, Vector2(-4, -42) + h]),
		PackedVector2Array([Vector2(46, -58) + h, Vector2(58, -42) + h, Vector2(40, -40) + h]),
		PackedVector2Array([Vector2(8, -86) + h, Vector2(16, -98) + h, Vector2(24, -86) + h]),
	]


func _body_top(x: float) -> float:
	var k := (x - BODY.x) / BODY_R.x
	return BODY.y - BODY_R.y * sqrt(maxf(0.0, 1.0 - k * k))


# --- drawing -------------------------------------------------------------------------------

func _silhouette(bob: float, h: Vector2) -> void:
	var e := 3.0
	for leg in _far_legs(bob) + _near_legs(bob):
		_leg(leg, OUTLINE, e)
	for p in _tail_points(bob):
		draw_circle(p, _tail_radius() + e, OUTLINE)
	_ellipse(BODY + Vector2(0, bob), BODY_R + Vector2(e, e), OUTLINE)
	draw_colored_polygon(_grow(_ear(false, h), e), OUTLINE)
	draw_colored_polygon(_grow(_ear(true, h), e), OUTLINE)
	if fluffy:
		for tuft in _cheek_tufts(h):
			draw_colored_polygon(_grow(tuft, e), OUTLINE)
	_ellipse(HEAD + h, HEAD_R + Vector2(e, e), OUTLINE)


func _fills(bob: float, h: Vector2) -> void:
	var dark := fur.darkened(0.15)
	for leg in _far_legs(bob):
		_leg(leg, dark, 0.0)
		if pattern == "Socks":
			draw_circle(leg[1], 6.0, markings.darkened(0.1))

	var tail := _tail_points(bob)
	for i in tail.size():
		var c := fur
		if pattern == "Tabby Stripes" and (i / 2) % 2 == 1:
			c = markings
		elif pattern in ["Socks", "Patches", "Back Stripe"] and i >= 9:
			c = markings
		draw_circle(tail[i], _tail_radius(), c)

	_ellipse(BODY + Vector2(0, bob), BODY_R, fur)
	_body_pattern(bob)

	for leg in _near_legs(bob):
		_leg(leg, OUTLINE, 2.5)
		_leg(leg, fur, 0.0)
		if pattern == "Socks":
			draw_circle(leg[1], 6.0, markings)

	_ellipse(HEAD + h, HEAD_R + Vector2(2.5, 2.5), OUTLINE)
	draw_colored_polygon(_ear(false, h), fur.darkened(0.08))
	draw_colored_polygon(_ear(true, h), fur)
	draw_colored_polygon(_grow(_ear(false, h), -4.5), PINK.darkened(0.1))
	draw_colored_polygon(_grow(_ear(true, h), -4.5), PINK)
	if fluffy:
		for tuft in _cheek_tufts(h):
			draw_colored_polygon(tuft, fur)
	_ellipse(HEAD + h, HEAD_R, fur)
	_head_pattern(h)
	_face(h)
	if collar:
		var band := PackedVector2Array()
		for i in 9:
			var a := PI * 0.28 + PI * 0.44 * i / 8.0
			band.append(HEAD + h + Vector2(cos(a) * (HEAD_R.x - 4), sin(a) * (HEAD_R.y - 1)))
		draw_polyline(band, Color("e2445c"), 5.0)
		draw_circle(HEAD + h + Vector2(0, HEAD_R.y + 2), 5.5, OUTLINE)
		draw_circle(HEAD + h + Vector2(0, HEAD_R.y + 2), 4.0, Color("ffd23f"))


func _body_pattern(bob: float) -> void:
	var o := Vector2(0, bob)
	match pattern:
		"Tabby Stripes":
			for x in [-22.0, -11.0, 0.0]:
				var top := _body_top(x) + bob
				draw_line(Vector2(x, top + 2), Vector2(x - 2, top + 12), markings, 5.0)
		"Spots":
			for p in [Vector2(-18, -30), Vector2(-8, -36), Vector2(-14, -20), Vector2(2, -28), Vector2(-24, -22)]:
				draw_circle(p + o, 3.8, markings)
		"Patches":
			_ellipse(Vector2(-14, -30) + o, Vector2(12, 9), markings)
			_ellipse(Vector2(6, -18) + o, Vector2(8, 5), markings)
		"Back Stripe":
			var spine := PackedVector2Array()
			for k in 9:
				var x := -26.0 + k * 4.5
				spine.append(Vector2(x, _body_top(x) + 3 + bob))
			draw_polyline(spine, markings, 7.0)


func _head_pattern(h: Vector2) -> void:
	match pattern:
		"Tabby Stripes":
			for x in [12.0, 18.0, 24.0]:
				draw_line(Vector2(x, -86) + h, Vector2(x, -79) + h, markings, 3.5)
			draw_line(Vector2(-12, -62) + h, Vector2(-5, -60) + h, markings, 3.0)
		"Spots":
			draw_circle(Vector2(-4, -70) + h, 3.0, markings)
			draw_circle(Vector2(2, -80) + h, 2.5, markings)
		"Patches":
			_ellipse(Vector2(0, -76) + h, Vector2(11, 8), markings)
		"Back Stripe":
			draw_line(Vector2(18, -88) + h, Vector2(18, -78) + h, markings, 6.0)
		"Socks", "Chest":
			_ellipse(Vector2(20, -33) + h, Vector2(12, 6), markings)


func _face(h: Vector2) -> void:
	if pattern == "Socks":
		_ellipse(Vector2(22, -47) + h, Vector2(11, 7), markings)
	for side in [-1.0, 1.0]:
		var cheek := Vector2(21 + side * 22.5, -46) + h
		_ellipse(cheek, Vector2(6, 3.5), BLUSH)
	for eye_x in [8.0, 34.0]:
		var c := Vector2(eye_x, -59) + h
		if _blink > 0.0:
			# Happy closed eyes, like ^ ^
			draw_arc(c + Vector2(0, 3), 6.0, PI * 1.1, PI * 1.9, 8, OUTLINE, 3.0)
			continue
		_ellipse(c, Vector2(8.5, 10.5), OUTLINE)
		_ellipse(c, Vector2(7, 9), eyes)
		_ellipse(c + Vector2(0, -1), Vector2(5, 6.5), Color("2a1d2a"))
		_ellipse(c + Vector2(0, 5), Vector2(4, 2.5), eyes.lightened(0.45))
		draw_circle(c + Vector2(2.5, -4), 3.0, Color.WHITE)
		draw_circle(c + Vector2(-2.5, 2.5), 1.5, Color.WHITE)
	if mood == "grumpy":
		draw_line(Vector2(0, -74) + h, Vector2(14, -69) + h, OUTLINE, 3.5)
		draw_line(Vector2(28, -69) + h, Vector2(42, -74) + h, OUTLINE, 3.5)
	draw_colored_polygon(PackedVector2Array([Vector2(18.5, -51) + h, Vector2(25.5, -51) + h,
			Vector2(22, -47.5) + h]), PINK)
	if mood == "grumpy":
		draw_line(Vector2(18, -43) + h, Vector2(26, -43) + h, OUTLINE, 1.8)
	else:
		draw_arc(Vector2(19.5, -46) + h, 2.5, 0.0, PI, 6, OUTLINE, 1.6)
		draw_arc(Vector2(24.5, -46) + h, 2.5, 0.0, PI, 6, OUTLINE, 1.6)
	var whisker := Color(OUTLINE, 0.5)
	draw_line(Vector2(50, -50) + h, Vector2(62, -53) + h, whisker, 1.5)
	draw_line(Vector2(50, -46) + h, Vector2(62, -45) + h, whisker, 1.5)
	draw_line(Vector2(-14, -50) + h, Vector2(-24, -53) + h, whisker, 1.5)


func _leg(leg: Array, color: Color, e: float) -> void:
	draw_line(leg[0], leg[1], color, 11.0 + e * 2.0)
	_ellipse(leg[1], Vector2(7.0, 5.5) + Vector2(e, e), color)
	draw_circle(leg[0], 5.5 + e, color)


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
