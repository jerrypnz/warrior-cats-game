class_name Cat
extends Node2D
## A cute chibi cat drawn with shapes: big round head, sparkly eyes, rosy cheeks.
## The origin is at the cat's feet and it faces right.
##
## The cat is drawn in layers so brush paint stays inside the cat:
##   outline layer -> fill layer (paint is clipped to it) -> face layer (eyes stay on top)

const OUTLINE := Color("4a2f3c")
const PINK := Color("ff8fab")
const BLUSH := Color(1.0, 0.55, 0.65, 0.55)

# Where the head and body are when standing. Everything else is measured from these.
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
var sleeping := false  # curled up napping
var paint: Array = []  # brush dabs: [position, color, radius], measured from the cat's feet
var size := 1.0
var facing := 1.0  # 1 = right, -1 = left
var walk_amount := 0.0  # 0 = standing still, 1 = walking
var lift := 0.0  # how high the cat is off the ground (for pounces)
var squish := Vector2.ONE

var _phase := 0.0
var _time := 0.0
var _blink := 0.0
var _next_blink := 2.0
var _layers: Array[Node2D] = []
var _paint_layer: Node2D
var _c: CanvasItem  # the layer being drawn right now

# This frame's pose
var _bob := 0.0
var _head_pos := Vector2.ZERO  # head drawing is moved by this...
var _head_scale := 1.0  # ...and scaled by this
var _body_pos := Vector2.ZERO  # same for the body
var _body_scale := Vector2.ONE


func _ready() -> void:
	_time = randf() * 10.0
	var outline := CatLayer.new(self, "outline")
	var fills := CatLayer.new(self, "fills")
	fills.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	_paint_layer = CatLayer.new(self, "paint")
	fills.add_child(_paint_layer)
	var face := CatLayer.new(self, "face")
	_layers = [outline, fills, face]
	for layer in _layers:
		add_child(layer)
	_update_pose()


func set_look(look: Dictionary) -> void:
	fur = look.fur
	markings = look.markings
	pattern = look.pattern
	eyes = look.eyes
	fluffy = look.get("fluffy", false)
	mood = look.get("mood", "happy")


func bounce(amount := 0.25) -> void:
	squish = Vector2(1.0 + amount, 1.0 - amount)


## Turns a point on the screen into a spot on the cat (for painting)
func to_cat_space(global_point: Vector2) -> Vector2:
	return _paint_layer.to_local(global_point) if _paint_layer else Vector2.ZERO


func _process(delta: float) -> void:
	_time += delta
	_phase += delta * 13.0 * walk_amount
	squish = squish.lerp(Vector2.ONE, minf(1.0, delta * 9.0))
	_next_blink -= delta
	if _next_blink <= 0.0:
		_blink = 0.16
		_next_blink = randf_range(2.0, 5.0)
	_blink = maxf(0.0, _blink - delta)
	_update_pose()


func _update_pose() -> void:
	if sleeping:
		_bob = sin(_time * 1.6)
		_head_scale = 0.85
		_head_pos = Vector2(24, -24) - HEAD * _head_scale + Vector2(0, _bob * 0.4)
		_body_scale = Vector2(34.0 / BODY_R.x, (15.0 + _bob * 0.6) / BODY_R.y)
		_body_pos = Vector2(-8, -15) - BODY * _body_scale
	else:
		_bob = -absf(sin(_phase)) * 3.0 * walk_amount
		_head_scale = 1.0
		_head_pos = Vector2(0, _bob + sin(_time * 2.0) * 0.8)
		_body_scale = Vector2.ONE
		_body_pos = Vector2(0, _bob)
	for layer in _layers:
		layer.position = Vector2(0, -lift)
		layer.scale = Vector2(facing * size * squish.x, size * squish.y)
		layer.queue_redraw()
	if _paint_layer:
		_paint_layer.queue_redraw()
	queue_redraw()


func _draw() -> void:
	# The shadow stays on the ground even while pouncing
	var shadow_scale := 1.0 / (1.0 + lift / 120.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(size, size))
	var width := 44.0 if sleeping else 36.0
	draw_colored_polygon(Fx.ellipse_points(Vector2(2, 0), Vector2(width, 7) * shadow_scale, 24), Color(0, 0, 0, 0.18))
	if sleeping:
		for k in 3:
			var t := fmod(_time * 0.5 + k / 3.0, 1.0)
			var p := Vector2(30 + t * 30, -70 - t * 40)
			_draw_z(p, 6.0 + t * 5.0, Color(1, 1, 1, 1.0 - t))


func _draw_z(p: Vector2, s: float, color: Color) -> void:
	draw_polyline(PackedVector2Array([p + Vector2(-s, -s), p + Vector2(s, -s), p + Vector2(-s, s),
			p + Vector2(s, s)]), color, 2.5)


## Called by each layer to draw its part of the cat
func draw_layer(layer: CanvasItem, what: String) -> void:
	_c = layer
	match what:
		"outline": _silhouette()
		"fills": _fills()
		"paint": _paint()
		"face": _face_layer()
	_c.draw_set_transform(Vector2.ZERO)
	_c = null


# --- where things go -----------------------------------------------------------------------

func _on_body() -> void:
	_c.draw_set_transform(_body_pos, 0.0, _body_scale)


func _on_head() -> void:
	_c.draw_set_transform(_head_pos, 0.0, Vector2(_head_scale, _head_scale))


func _on_ground() -> void:
	_c.draw_set_transform(Vector2.ZERO)


func _leg_points(x: float, phase_offset: float) -> Array:
	var s := sin(_phase + phase_offset) * walk_amount
	return [Vector2(x, -18 + _bob), Vector2(x - s * 6.0, -5 - maxf(0.0, s) * 4.0)]


func _far_legs() -> Array:
	return [] if sleeping else [_leg_points(-20, PI), _leg_points(10, 0.0)]


func _near_legs() -> Array:
	return [] if sleeping else [_leg_points(-12, 0.0), _leg_points(18, PI)]


func _tail_points() -> Array:
	var points := []
	for i in 12:
		var t := i / 11.0
		if sleeping:
			# Curled around the front of the body
			var a := lerpf(PI * 0.95, PI * 0.12, t)
			points.append(Vector2(-4, -9) + Vector2(cos(a) * 40, sin(a) * 9))
		else:
			var sway := sin(_time * 2.6 + t * 2.0) * 7.0 * t
			points.append(Vector2(-28, -30 + _bob) + Vector2(-20.0 * sin(t * PI * 0.8) - 6.0 * t + sway, -40.0 * t))
	return points


func _tail_radius() -> float:
	return 8.5 if fluffy else 6.0


func _ear(front: bool) -> PackedVector2Array:
	if front:
		return PackedVector2Array([Vector2(24, -86), Vector2(44, -106), Vector2(49, -76)])
	return PackedVector2Array([Vector2(-8, -74), Vector2(-7, -103), Vector2(14, -87)])


func _cheek_tufts() -> Array:
	return [
		PackedVector2Array([Vector2(-10, -58), Vector2(-22, -44), Vector2(-4, -42)]),
		PackedVector2Array([Vector2(46, -58), Vector2(58, -42), Vector2(40, -40)]),
	]


func _body_top(x: float) -> float:
	var k := (x - BODY.x) / BODY_R.x
	return BODY.y - BODY_R.y * sqrt(maxf(0.0, 1.0 - k * k))


# --- drawing -------------------------------------------------------------------------------

func _silhouette() -> void:
	var e := 3.0
	_on_ground()
	for leg in _far_legs() + _near_legs():
		_leg(leg, OUTLINE, e)
	for p in _tail_points():
		_c.draw_circle(p, _tail_radius() + e, OUTLINE)
	if sleeping:
		for paw in _sleepy_paws():
			_ellipse(paw, Vector2(8, 5.5) + Vector2(e, e), OUTLINE)
	_on_body()
	_ellipse(BODY, BODY_R + Vector2(e, e), OUTLINE)
	_on_head()
	_c.draw_colored_polygon(_grow(_ear(false), e), OUTLINE)
	_c.draw_colored_polygon(_grow(_ear(true), e), OUTLINE)
	if fluffy:
		for tuft in _cheek_tufts():
			_c.draw_colored_polygon(_grow(tuft, e), OUTLINE)
	_ellipse(HEAD, HEAD_R + Vector2(e, e), OUTLINE)


func _fills() -> void:
	_on_ground()
	for leg in _far_legs():
		_leg(leg, fur.darkened(0.15), 0.0)
		if pattern == "Socks":
			_c.draw_circle(leg[1], 6.0, markings.darkened(0.1))
	if not sleeping:
		_draw_tail()

	_on_body()
	_ellipse(BODY, BODY_R, fur)
	_body_pattern()

	_on_ground()
	if sleeping:
		_draw_tail(true)
	for leg in _near_legs():
		_leg(leg, OUTLINE, 2.5)
		_leg(leg, fur, 0.0)
		if pattern == "Socks":
			_c.draw_circle(leg[1], 6.0, markings)

	_on_head()
	_ellipse(HEAD, HEAD_R + Vector2(2.5, 2.5), OUTLINE)
	_c.draw_colored_polygon(_ear(false), fur.darkened(0.08))
	_c.draw_colored_polygon(_ear(true), fur)
	_c.draw_colored_polygon(_grow(_ear(false), -4.5), PINK.darkened(0.1))
	_c.draw_colored_polygon(_grow(_ear(true), -4.5), PINK)
	if fluffy:
		for tuft in _cheek_tufts():
			_c.draw_colored_polygon(tuft, fur)
	_ellipse(HEAD, HEAD_R, fur)
	_head_pattern()

	if sleeping:
		_on_ground()
		for paw in _sleepy_paws():
			_ellipse(paw, Vector2(9.5, 7), OUTLINE)
			_ellipse(paw, Vector2(8, 5.5), markings if pattern == "Socks" else fur)


func _sleepy_paws() -> Array:
	return [Vector2(30, -5), Vector2(46, -4)]


func _draw_tail(with_outline := false) -> void:
	var tail := _tail_points()
	if with_outline:
		for p in tail:
			_c.draw_circle(p, _tail_radius() + 2.5, OUTLINE)
	for i in tail.size():
		var c := fur
		if pattern == "Tabby Stripes" and (i / 2) % 2 == 1:
			c = markings
		elif pattern in ["Socks", "Patches", "Back Stripe"] and i >= 9:
			c = markings
		_c.draw_circle(tail[i], _tail_radius(), c)


func _body_pattern() -> void:
	match pattern:
		"Tabby Stripes":
			for x in [-22.0, -11.0, 0.0]:
				var top := _body_top(x)
				_c.draw_line(Vector2(x, top + 2), Vector2(x - 2, top + 12), markings, 5.0)
		"Spots":
			for p in [Vector2(-18, -30), Vector2(-8, -36), Vector2(-14, -20), Vector2(2, -28), Vector2(-24, -22)]:
				_c.draw_circle(p, 3.8, markings)
		"Patches":
			_ellipse(Vector2(-14, -30), Vector2(12, 9), markings)
			_ellipse(Vector2(6, -18), Vector2(8, 5), markings)
		"Back Stripe":
			var spine := PackedVector2Array()
			for k in 9:
				var x := -26.0 + k * 4.5
				spine.append(Vector2(x, _body_top(x) + 3))
			_c.draw_polyline(spine, markings, 7.0)


func _head_pattern() -> void:
	match pattern:
		"Tabby Stripes":
			for x in [12.0, 18.0, 24.0]:
				_c.draw_line(Vector2(x, -86), Vector2(x, -79), markings, 3.5)
			_c.draw_line(Vector2(-12, -62), Vector2(-5, -60), markings, 3.0)
		"Spots":
			_c.draw_circle(Vector2(-4, -70), 3.0, markings)
			_c.draw_circle(Vector2(2, -80), 2.5, markings)
		"Patches":
			_ellipse(Vector2(0, -76), Vector2(11, 8), markings)
		"Back Stripe":
			_c.draw_line(Vector2(18, -88), Vector2(18, -78), markings, 6.0)
		"Socks", "Chest":
			_ellipse(Vector2(20, -33), Vector2(12, 6), markings)
	if pattern == "Socks":
		_ellipse(Vector2(22, -47), Vector2(11, 7), markings)


## Brush paint, kept inside the cat by the fill layer
func _paint() -> void:
	var head_area := HEAD_R + Vector2(6, 6)
	for on_head in [true, false]:
		if on_head:
			_on_head()
		else:
			_on_body()
		for dab in paint:
			var p: Vector2 = dab[0]
			var inside_head := ((p - HEAD) / head_area).length() < 1.0
			if inside_head == on_head:
				_c.draw_circle(p, dab[2], dab[1])


func _face_layer() -> void:
	_on_head()
	for side in [-1.0, 1.0]:
		_ellipse(Vector2(21 + side * 22.5, -46), Vector2(6, 3.5), BLUSH)
	for eye_x in [8.0, 34.0]:
		var c := Vector2(eye_x, -59)
		if sleeping:
			_c.draw_arc(c + Vector2(0, -3), 6.0, PI * 0.15, PI * 0.85, 8, OUTLINE, 3.0)
			continue
		if _blink > 0.0:
			# Happy closed eyes, like ^ ^
			_c.draw_arc(c + Vector2(0, 3), 6.0, PI * 1.1, PI * 1.9, 8, OUTLINE, 3.0)
			continue
		_ellipse(c, Vector2(8.5, 10.5), OUTLINE)
		_ellipse(c, Vector2(7, 9), eyes)
		_ellipse(c + Vector2(0, -1), Vector2(5, 6.5), Color("2a1d2a"))
		_ellipse(c + Vector2(0, 5), Vector2(4, 2.5), eyes.lightened(0.45))
		_c.draw_circle(c + Vector2(2.5, -4), 3.0, Color.WHITE)
		_c.draw_circle(c + Vector2(-2.5, 2.5), 1.5, Color.WHITE)
	if mood == "grumpy" and not sleeping:
		_c.draw_line(Vector2(0, -74), Vector2(14, -69), OUTLINE, 3.5)
		_c.draw_line(Vector2(28, -69), Vector2(42, -74), OUTLINE, 3.5)
	_c.draw_colored_polygon(PackedVector2Array([Vector2(18.5, -51), Vector2(25.5, -51), Vector2(22, -47.5)]), PINK)
	if mood == "grumpy":
		_c.draw_line(Vector2(18, -43), Vector2(26, -43), OUTLINE, 1.8)
	else:
		_c.draw_arc(Vector2(19.5, -46), 2.5, 0.0, PI, 6, OUTLINE, 1.6)
		_c.draw_arc(Vector2(24.5, -46), 2.5, 0.0, PI, 6, OUTLINE, 1.6)
	var whisker := Color(OUTLINE, 0.5)
	_c.draw_line(Vector2(50, -50), Vector2(62, -53), whisker, 1.5)
	_c.draw_line(Vector2(50, -46), Vector2(62, -45), whisker, 1.5)
	_c.draw_line(Vector2(-14, -50), Vector2(-24, -53), whisker, 1.5)
	if collar:
		var band := PackedVector2Array()
		for i in 9:
			var a := PI * 0.28 + PI * 0.44 * i / 8.0
			band.append(HEAD + Vector2(cos(a) * (HEAD_R.x - 4), sin(a) * (HEAD_R.y - 1)))
		_c.draw_polyline(band, Color("e2445c"), 5.0)
		_c.draw_circle(HEAD + Vector2(0, HEAD_R.y + 2), 5.5, OUTLINE)
		_c.draw_circle(HEAD + Vector2(0, HEAD_R.y + 2), 4.0, Color("ffd23f"))


func _leg(leg: Array, color: Color, e: float) -> void:
	_c.draw_line(leg[0], leg[1], color, 11.0 + e * 2.0)
	_ellipse(leg[1], Vector2(7.0, 5.5) + Vector2(e, e), color)
	_c.draw_circle(leg[0], 5.5 + e, color)


func _ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	_c.draw_colored_polygon(Fx.ellipse_points(center, radii, 28), color)


func _grow(tri: PackedVector2Array, amount: float) -> PackedVector2Array:
	var center := (tri[0] + tri[1] + tri[2]) / 3.0
	var out := PackedVector2Array()
	for p in tri:
		out.append(center + (p - center) * (1.0 + amount / 9.0))
	return out


class CatLayer extends Node2D:
	var cat: Cat
	var what: String

	func _init(owner_cat: Cat, layer_name: String) -> void:
		cat = owner_cat
		what = layer_name

	func _draw() -> void:
		cat.draw_layer(self, what)
