extends Node2D
## Battle practice: your mentor rolls moss balls at you. Swat them away with SPACE!

const GOAL := 12
const ARENA := Rect2(170, 270, 940, 380)  # oval the player can move in
const SWAT_DISTANCE := 125.0
const BONK_DISTANCE := 42.0

var _world: Node2D
var _player: TopDownPlayer
var _mentor: Npc
var _balls: Array[MossBall] = []
var _swats := 0
var _playing := false
var _spawn_timer := 1.0
var _card: InfoCard
var _score_label: Label
var _camera: Camera2D


func _ready() -> void:
	_camera = Camera2D.new()
	_camera.position = Vector2(640, 360)
	add_child(_camera)
	_world = Node2D.new()
	_world.y_sort_enabled = true
	add_child(_world)

	_mentor = Npc.new().setup(GameState.MENTOR, {"fur": Color("c9ced6"), "markings": Color("5d626b"),
			"pattern": "Tabby Stripes", "eyes": Color("5fd14a")}, 1.05, 1.0)
	_mentor.position = Vector2(640, 290)
	_world.add_child(_mentor)

	_player = TopDownPlayer.new()
	_player.position = Vector2(640, 520)
	_player.bounds = ARENA
	_player.round_bounds = true
	_player.can_swipe = true
	_player.frozen = true
	_player.swiped.connect(_on_swipe)
	_world.add_child(_player)

	var hud := CanvasLayer.new()
	add_child(hud)
	hud.add_child(Fx.centered_label("BATTLE PRACTICE", 34, Color("ffd966"), 10))
	_score_label = Fx.centered_label("", 36, Color.WHITE, 54)
	hud.add_child(_score_label)
	_update_score()

	_card = InfoCard.new()
	add_child(_card)
	_card.show_card("Battle Practice!",
			"%s will roll moss balls at you.\nWhen one gets close, press SPACE to SWAT it away!\n\nSwat %d moss balls to finish." % [GameState.MENTOR, GOAL],
			"Press SPACE to start!")
	await _card.closed
	_playing = true
	_player.frozen = false


func _process(delta: float) -> void:
	if not _playing:
		return
	_spawn_timer -= delta
	if _spawn_timer <= 0.0 and _balls.size() < 4:
		_spawn_ball()
		_spawn_timer = lerpf(1.5, 0.9, float(_swats) / GOAL)
	for ball: MossBall in _balls.duplicate():
		if ball.global_position.distance_to(_player.global_position + Vector2(0, -6)) < BONK_DISTANCE:
			_bonk(ball)
		elif not Rect2(-80, -80, 1440, 880).has_point(ball.global_position):
			_remove(ball)


func _spawn_ball() -> void:
	var ball := MossBall.new()
	var from_mentor := randf() < 0.5
	if from_mentor:
		ball.position = _mentor.position + Vector2(40 * _mentor.cat.facing, 10)
		_mentor.cat.bounce(0.25)
		Sfx.play("click", 0.6, -3.0)
	else:
		ball.position = [Vector2(-40, randf_range(320, 620)), Vector2(1320, randf_range(320, 620))].pick_random()
	var aim := _player.position + Vector2(randf_range(-40, 40), randf_range(-30, 30))
	ball.velocity = (aim - ball.position).normalized() * randf_range(170, 230)
	_mentor.face_toward(aim)
	_world.add_child(ball)
	_balls.append(ball)


func _on_swipe() -> void:
	var hit_any := false
	for ball: MossBall in _balls.duplicate():
		if ball.global_position.distance_to(_player.global_position + Vector2(0, -20)) < SWAT_DISTANCE:
			_swat(ball)
			hit_any = true
	if hit_any:
		Fx.shake(_camera, 7.0)


func _swat(ball: MossBall) -> void:
	_balls.erase(ball)
	_swats += 1
	Sfx.play("enemy_bonk", randf_range(0.9, 1.15))
	var away := (ball.global_position - _player.global_position).normalized()
	if away == Vector2.ZERO:
		away = Vector2(_player.cat.facing, 0)
	ball.knock(away * 900.0)
	Fx.burst(self, ball.global_position + Vector2(0, -20), Color("7bc24f"), 16, 300.0)
	Fx.popup_text(self, ball.global_position + Vector2(0, -60), ["SWAT!", "WHACK!", "Nice!", "POW!"].pick_random(),
			Color("ffd966"))
	_update_score()
	if _swats >= GOAL:
		_win()


func _bonk(ball: MossBall) -> void:
	_remove(ball)
	Sfx.play("hurt")
	Fx.burst(self, _player.global_position + Vector2(0, -60), Color("fff27a"), 10, 160.0, 0.0)
	Fx.popup_text(self, _player.global_position + Vector2(0, -120), "Oof! Mossy!", Color("b8f0a0"), 26)
	_player.cat.bounce(0.35)
	Fx.shake(_camera, 4.0)


func _remove(ball: MossBall) -> void:
	_balls.erase(ball)
	ball.queue_free()


func _update_score() -> void:
	_score_label.text = "Moss balls swatted: %d / %d" % [_swats, GOAL]


func _win() -> void:
	_playing = false
	_player.frozen = true
	for ball: MossBall in _balls.duplicate():
		_remove(ball)
	Sfx.play("win")
	Fx.confetti(self, Vector2(640, 300), 80)
	await get_tree().create_timer(1.0).timeout
	_card.show_card("Amazing Moves!", "You swatted %d moss balls!\nYou're ready to protect your Clan." % GOAL,
			"Press SPACE to go back to camp")
	await _card.closed
	GameState.finish_training("battle")
	Transition.go("res://scenes/camp.tscn")


func _draw() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color("4f8a43"))
	for i in 10:
		Scenery.tree(self, Vector2(i * 145 - 20, 200), 0.85 + (i % 3) * 0.1, Color("3d6b3f"))
	draw_colored_polygon(Fx.ellipse_points(Vector2(640, 460), Vector2(600, 270), 48), Color("8a7a4a"))
	draw_colored_polygon(Fx.ellipse_points(Vector2(640, 465), Vector2(570, 245), 48), Color("d6bf85"))
	for i in 18:
		var a := TAU * i / 18.0
		if sin(a) < -0.5:
			continue  # leave the top open so we can see the mentor
		Scenery.rock(self, Vector2(640, 470) + Vector2(cos(a) * 600, sin(a) * 265), 0.6, Color("8d8f96"))


class MossBall extends Node2D:
	## A soft ball of moss that rolls along the ground.
	var velocity := Vector2.ZERO
	var _spin := 0.0
	var _knocked := false
	var _height := 0.0

	func knock(v: Vector2) -> void:
		_knocked = true
		velocity = v
		var t := create_tween()
		t.tween_property(self, "_height", 160.0, 0.35).set_ease(Tween.EASE_OUT)
		t.parallel().tween_property(self, "modulate:a", 0.0, 0.45)
		t.tween_callback(queue_free)

	func _process(delta: float) -> void:
		position += velocity * delta
		_spin += velocity.x * delta / 22.0
		queue_redraw()

	func _draw() -> void:
		draw_colored_polygon(Fx.ellipse_points(Vector2.ZERO, Vector2(22, 6)), Color(0, 0, 0, 0.2))
		var c := Vector2(0, -22 - _height)
		draw_circle(c, 24, Color("2a1d17"))
		draw_circle(c, 21, Color("5fa83a"))
		for k in 5:
			var a := _spin + k * TAU / 5.0
			draw_circle(c + Vector2(cos(a), sin(a)) * 11.0, 5.5, Color("4a8a2f"))
		draw_circle(c + Vector2(-7, -8), 5, Color("9be37a"))
