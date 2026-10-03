class_name TopDownPlayer
extends Node2D
## The player's cat walking around (camp, hunting, battle practice).
## Turn on can_pounce (leap forward) or can_swipe (bat with a paw) for training games.

signal pounce_landed
signal swiped

const POUNCE_TIME := 0.34
const POUNCE_SPEED := 560.0

var cat: Cat
var name_label: Label
var speed := 260.0
var bounds := Rect2(0, 0, 1280, 720)
var round_bounds := false  # true = bounds is an oval instead of a rectangle
var blockers: Array[Rect2] = []
var frozen := false
var can_pounce := false
var can_swipe := false

var _pounce_left := 0.0
var _pounce_dir := Vector2.RIGHT
var _cooldown := 0.0
var _swipe_left := 0.0


func _ready() -> void:
	cat = GameState.make_player_cat()
	add_child(cat)
	name_label = Fx.make_label(GameState.cat_name(), 24, Color("ffd966"), 6)
	name_label.size = Vector2(300, 36)
	name_label.position = Vector2(-150, -112 * cat.size - 34)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(name_label)


func is_pouncing() -> bool:
	return _pounce_left > 0.0


## Where the middle of the cat's body is (for catching and bonking things)
func body_center() -> Vector2:
	return global_position + Vector2(10 * cat.facing, -45) * cat.size


func _process(delta: float) -> void:
	_cooldown -= delta
	_swipe_left -= delta
	queue_redraw()
	if _pounce_left > 0.0:
		_pounce_left -= delta
		position += _pounce_dir * POUNCE_SPEED * delta
		cat.lift = sin((1.0 - _pounce_left / POUNCE_TIME) * PI) * 55.0
		cat.walk_amount = 0.0
		if _pounce_left <= 0.0:
			cat.lift = 0.0
			cat.bounce(0.3)
			_cooldown = 0.25
			Sfx.play("land")
			pounce_landed.emit()
		position = _keep_inside(position)
		return
	if frozen:
		cat.walk_amount = move_toward(cat.walk_amount, 0.0, delta * 6.0)
		return

	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	position += dir * speed * delta
	position = _keep_inside(position)
	cat.walk_amount = move_toward(cat.walk_amount, 1.0 if dir != Vector2.ZERO else 0.0, delta * 6.0)
	if absf(dir.x) > 0.1:
		cat.facing = signf(dir.x)

	if Input.is_action_just_pressed("jump") and _cooldown <= 0.0:
		if can_pounce:
			_pounce_dir = dir.normalized() if dir != Vector2.ZERO else Vector2(cat.facing, 0)
			_pounce_left = POUNCE_TIME
			cat.bounce(-0.25)
			Sfx.play("jump")
		elif can_swipe:
			_swipe_left = 0.18
			_cooldown = 0.28
			cat.bounce(0.2)
			Sfx.play("click", 0.7)
			swiped.emit()


func _keep_inside(p: Vector2) -> Vector2:
	if round_bounds:
		var center := bounds.get_center()
		var radii := bounds.size / 2.0
		var d := (p - center) / radii
		if d.length() > 1.0:
			p = center + d.normalized() * radii
	else:
		p = p.clamp(bounds.position, bounds.end)
	for r in blockers:
		if r.has_point(p):
			var pushes := [
				Vector2(r.position.x - p.x, 0), Vector2(r.end.x - p.x, 0),
				Vector2(0, r.position.y - p.y), Vector2(0, r.end.y - p.y),
			]
			var best: Vector2 = pushes[0]
			for push in pushes:
				if push.length() < best.length():
					best = push
			p += best
	return p


func _draw() -> void:
	if _swipe_left <= 0.0:
		return
	# A cartoon "swoosh" in front of the cat
	var t := _swipe_left / 0.18
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(cat.facing, 1.0))
	var center := Vector2(20, -45) * cat.size
	var sweep := PI * 1.2 * (1.0 - t) + 0.05
	for i in 3:
		draw_arc(center, 70.0 + i * 14.0, -PI * 0.6, -PI * 0.6 + sweep, 16,
				Color(1, 1, 1, 0.8 * t), 6.0 - i * 1.5)
