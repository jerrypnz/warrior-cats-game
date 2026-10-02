class_name PlatformPlayer
extends CharacterBody2D
## The player's cat running and jumping in side-view levels (border patrol).

signal landed

const SPEED := 330.0
const JUMP_VELOCITY := -800.0
const GRAVITY := 1900.0
const COYOTE_TIME := 0.12  # you can still jump just after running off an edge
const JUMP_BUFFER := 0.15  # pressing jump just before landing still counts

var cat: Cat
var name_label: Label
var frozen := false
var _coyote := 0.0
var _buffer := 0.0
var _was_on_floor := true


func _ready() -> void:
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(64, 44)
	shape.shape = rect
	shape.position = Vector2(0, -22)
	add_child(shape)
	cat = Cat.new()
	cat.set_look(GameState.look())
	cat.size = GameState.cat_size()
	cat.collar = GameState.is_kittypet()
	add_child(cat)
	name_label = Fx.make_label(GameState.cat_name(), 24, Color("ffd966"), 6)
	name_label.size = Vector2(300, 36)
	name_label.position = Vector2(-150, -112 * cat.size - 34)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(name_label)


func _physics_process(delta: float) -> void:
	velocity.y = minf(velocity.y + GRAVITY * delta, 1400.0)
	var dir := 0.0 if frozen else Input.get_axis("move_left", "move_right")
	velocity.x = move_toward(velocity.x, dir * SPEED, 3000.0 * delta)

	_coyote = COYOTE_TIME if is_on_floor() else _coyote - delta
	_buffer -= delta
	if not frozen and Input.is_action_just_pressed("jump"):
		_buffer = JUMP_BUFFER
	if _buffer > 0.0 and _coyote > 0.0:
		velocity.y = JUMP_VELOCITY
		_buffer = 0.0
		_coyote = 0.0
		cat.bounce(-0.25)
		Sfx.play("jump")

	move_and_slide()

	if is_on_floor() and not _was_on_floor:
		cat.bounce(0.3)
		Sfx.play("land", 1.0, -4.0)
		landed.emit()
	_was_on_floor = is_on_floor()
	cat.walk_amount = move_toward(cat.walk_amount, 1.0 if absf(velocity.x) > 20 and is_on_floor() else 0.0, delta * 8.0)
	if absf(dir) > 0.1:
		cat.facing = signf(dir)
