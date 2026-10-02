class_name Npc
extends Node2D
## A Clan cat you can talk to. Can stand still or wander around an area.

var npc_name := ""
var cat: Cat
var wander_area := Rect2()  # leave empty to stand still
var speed := 70.0
var hops := false  # kits bounce around while they play
var talk_spot := Vector2.ZERO  # offset of where the player should stand to talk
var bubble_offset := Vector2.ZERO  # moves the "!" if it would be off screen
var has_news := false:  # shows a bouncing "!" above their head
	set(value):
		has_news = value
		queue_redraw()

var _target := Vector2.ZERO
var _wait := 0.0
var _prompt: Label
var _time := 0.0


func setup(cat_name: String, look: Dictionary, cat_size := 1.0, face := 1.0) -> Npc:
	npc_name = cat_name
	cat = Cat.new()
	cat.set_look(look)
	cat.size = cat_size
	cat.facing = face
	cat.show_behind_parent = true  # so the "!" bubble is drawn on top of the cat
	add_child(cat)
	var label := Fx.make_label(cat_name, 22, Color.WHITE, 6)
	label.size = Vector2(300, 32)
	label.position = Vector2(-150, -112 * cat_size - 30)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(label)
	_prompt = Fx.make_label("SPACE = talk", 22, Color("9be37a"), 6)
	_prompt.size = Vector2(300, 32)
	_prompt.position = Vector2(-150, 6)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.visible = false
	add_child(_prompt)
	return self


func talk_position() -> Vector2:
	return global_position + talk_spot


func show_prompt(on: bool) -> void:
	_prompt.visible = on


func face_toward(p: Vector2) -> void:
	if absf(p.x - global_position.x) > 5:
		cat.facing = signf(p.x - global_position.x)


func _process(delta: float) -> void:
	_time += delta
	if has_news:
		queue_redraw()
	if wander_area.size == Vector2.ZERO or _prompt.visible:
		cat.walk_amount = move_toward(cat.walk_amount, 0.0, delta * 5.0)
		return
	if _target == Vector2.ZERO:
		_target = position
		_wait = randf_range(0.5, 2.5)
	if _wait > 0.0:
		_wait -= delta
		cat.lift = move_toward(cat.lift, 0.0, delta * 120.0)
		cat.walk_amount = move_toward(cat.walk_amount, 0.0, delta * 5.0)
		if _wait <= 0.0:
			_target = Vector2(randf_range(wander_area.position.x, wander_area.end.x),
					randf_range(wander_area.position.y, wander_area.end.y))
		return
	var to_target := _target - position
	if to_target.length() < 6.0:
		_wait = randf_range(1.0, 3.5) if not hops else randf_range(0.2, 0.8)
		return
	position += to_target.normalized() * minf(speed * delta, to_target.length())
	cat.walk_amount = move_toward(cat.walk_amount, 1.0, delta * 5.0)
	face_toward(global_position + to_target)
	if hops:
		cat.lift = absf(sin(_time * 9.0)) * 14.0


func _draw() -> void:
	if not has_news:
		return
	var p := Vector2(0, -112 * cat.size - 70 + sin(_time * 5.0) * 6.0) + bubble_offset
	draw_circle(p, 22, Color("2a1d17"))
	draw_circle(p, 19, Color("ffd23f"))
	draw_rect(Rect2(p + Vector2(-3.5, -12), Vector2(7, 15)), Color("2a1d17"))
	draw_circle(p + Vector2(0, 9), 3.5, Color("2a1d17"))
