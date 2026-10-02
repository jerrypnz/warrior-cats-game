class_name Mouse
extends Node2D
## A little mouse that nibbles around the meadow and scurries away if a cat gets too close.

const OUTLINE := Color("2a1d17")
const WANDER_SPEED := 45.0
const FLEE_SPEED := 205.0

var bounds := Rect2(0, 0, 1280, 720)
var _dir := Vector2.RIGHT
var _turn_time := 0.0
var _flee_time := 0.0
var _time := 0.0
var _moving := true


func _ready() -> void:
	_time = randf() * 5.0
	_dir = Vector2.RIGHT.rotated(randf() * TAU)


func is_scared() -> bool:
	return _flee_time > 0.0


func scare(from: Vector2) -> void:
	if _flee_time > -0.4:  # a little rest between scurries
		return
	_flee_time = 0.9
	_dir = (global_position - from).normalized().rotated(randf_range(-0.6, 0.6))


func _process(delta: float) -> void:
	_time += delta
	_flee_time -= delta
	_turn_time -= delta
	var speed := FLEE_SPEED if _flee_time > 0.0 else (WANDER_SPEED if _moving else 0.0)
	if _flee_time <= 0.0 and _turn_time <= 0.0:
		_turn_time = randf_range(0.8, 2.2)
		_moving = randf() < 0.65
		_dir = _dir.rotated(randf_range(-1.5, 1.5))
	position += _dir * speed * delta
	# Bounce off the edges of the meadow
	if position.x < bounds.position.x or position.x > bounds.end.x:
		_dir.x = -_dir.x
	if position.y < bounds.position.y or position.y > bounds.end.y:
		_dir.y = -_dir.y
	position = position.clamp(bounds.position, bounds.end)
	queue_redraw()


func _draw() -> void:
	var facing := 1.0 if _dir.x >= 0.0 else -1.0
	var running := _flee_time > 0.0 or _moving
	var bob := -absf(sin(_time * (30.0 if _flee_time > 0.0 else 14.0))) * (3.0 if running else 0.0)
	draw_colored_polygon(Fx.ellipse_points(Vector2(0, 0), Vector2(20, 5)), Color(0, 0, 0, 0.2))
	draw_set_transform(Vector2(0, bob), 0.0, Vector2(facing, 1.0))
	var fur := Color("9a8574")
	var tail := PackedVector2Array()
	for i in 8:
		var t := i / 7.0
		tail.append(Vector2(-16 - t * 26, -8 - sin(t * 3.0 + _time * 6.0) * 5.0))
	draw_polyline(tail, Color("e8a0a8"), 3.0)
	draw_colored_polygon(Fx.ellipse_points(Vector2(0, -11), Vector2(19, 12)), OUTLINE)
	draw_colored_polygon(Fx.ellipse_points(Vector2(0, -11), Vector2(17, 10)), fur)
	draw_colored_polygon(Fx.ellipse_points(Vector2(14, -14), Vector2(10, 8)), fur)
	draw_circle(Vector2(8, -24), 7, OUTLINE)
	draw_circle(Vector2(8, -24), 5.5, Color("e8a0a8"))
	draw_circle(Vector2(22, -13), 2.5, Color("e2445c"))
	draw_circle(Vector2(15, -17), 2.2, OUTLINE)
	if _flee_time > 0.0:
		draw_set_transform(Vector2(0, bob), 0.0, Vector2.ONE)
		draw_string(ThemeDB.fallback_font, Vector2(-6, -36), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 28,
				Color("ffd23f"))
