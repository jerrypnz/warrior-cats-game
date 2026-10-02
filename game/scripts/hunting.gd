extends Node2D
## Hunting training: sneak up on mice in the meadow and pounce on them!

const GOAL := 5
const MEADOW := Rect2(80, 250, 1120, 440)
const CATCH_DISTANCE := 70.0
const SCARE_DISTANCE := 115.0

var _world: Node2D
var _player: TopDownPlayer
var _mentor: Npc
var _mice: Array[Mouse] = []
var _caught := 0
var _playing := false
var _card: InfoCard
var _score_label: Label
var _camera: Camera2D
var _decor: Array = []


func _ready() -> void:
	seed(5)
	for i in 90:
		_decor.append(Vector3(randf_range(20, 1260), randf_range(170, 710), randi() % 5))
	randomize()

	_camera = Camera2D.new()
	_camera.position = Vector2(640, 360)
	add_child(_camera)
	_world = Node2D.new()
	_world.y_sort_enabled = true
	add_child(_world)

	_player = TopDownPlayer.new()
	_player.position = Vector2(640, 600)
	_player.bounds = MEADOW
	_player.speed = 250.0
	_player.can_pounce = true
	_player.frozen = true
	_world.add_child(_player)

	_mentor = Npc.new().setup(GameState.MENTOR, {"fur": Color("c9ced6"), "markings": Color("5d626b"),
			"pattern": "Tabby Stripes", "eyes": Color("5fd14a")}, 1.05, 1.0)
	_mentor.position = Vector2(110, 270)
	_world.add_child(_mentor)

	for i in 6:
		_spawn_mouse(Vector2(randf_range(250, 1100), randf_range(290, 560)))

	var hud := CanvasLayer.new()
	add_child(hud)
	hud.add_child(Fx.centered_label("HUNTING PRACTICE", 34, Color("ffd966"), 10))
	_score_label = Fx.centered_label("", 40, Color.WHITE, 56)
	hud.add_child(_score_label)
	_update_score()

	_card = InfoCard.new()
	add_child(_card)
	_card.show_card("Hunting Practice!",
			"Sneak up close to a mouse, then press SPACE to POUNCE!\n\nIf you get too close, the mouse will run away. Catch %d mice!" % GOAL,
			"Press SPACE to start!")
	await _card.closed
	_playing = true
	_player.frozen = false


func _spawn_mouse(pos: Vector2) -> void:
	var mouse := Mouse.new()
	mouse.position = pos
	mouse.bounds = MEADOW
	mouse.scale = Vector2(1.4, 1.4)
	_world.add_child(mouse)
	_mice.append(mouse)


func _process(_delta: float) -> void:
	if not _playing:
		return
	var paws := _player.global_position
	for mouse: Mouse in _mice.duplicate():
		var d := mouse.global_position.distance_to(paws)
		if _player.is_pouncing() and d < CATCH_DISTANCE:
			_catch(mouse)
		elif not _player.is_pouncing() and d < SCARE_DISTANCE and _player.cat.walk_amount > 0.3:
			mouse.scare(paws)


func _catch(mouse: Mouse) -> void:
	_mice.erase(mouse)
	var pos := mouse.global_position
	mouse.queue_free()
	_caught += 1
	Sfx.play("collect")
	Fx.burst(self, pos + Vector2(0, -20), Color("fff27a"), 18)
	Fx.popup_text(self, pos + Vector2(0, -70), ["Got it!", "Nice catch!", "Great pounce!", "Yum!"].pick_random(),
			Color("ffd966"))
	Fx.shake(_camera, 6.0)
	_player.cat.bounce(0.3)
	_mentor.cat.bounce(0.25)
	_update_score()
	if _caught >= GOAL:
		_win()
		return
	# A new mouse pops out of the long grass at the edge of the meadow
	await get_tree().create_timer(1.2).timeout
	var edge: Vector2 = [Vector2(MEADOW.position.x, randf_range(250, 650)), Vector2(MEADOW.end.x, randf_range(250, 650)),
			Vector2(randf_range(200, 1100), MEADOW.end.y)].pick_random()
	if _playing:
		_spawn_mouse(edge)


func _update_score() -> void:
	_score_label.text = "Mice caught: %d / %d" % [_caught, GOAL]


func _win() -> void:
	_playing = false
	_player.frozen = true
	Sfx.play("win")
	Fx.confetti(self, Vector2(640, 300), 80)
	await get_tree().create_timer(1.0).timeout
	_card.show_card("Great Hunting!", "You caught %d mice for the Clan!\n%s is really proud of you!" % [GOAL, GameState.MENTOR],
			"Press SPACE to go back to camp")
	await _card.closed
	GameState.finish_training("hunting")
	Transition.go("res://scenes/camp.tscn")


func _draw() -> void:
	Scenery.sky(self, Color("9fd6ef"), Color("d8f0f5"), Rect2(0, 0, 1280, 200))
	for i in 9:
		Scenery.tree(self, Vector2(i * 160 - 20, 200), 0.75 + (i % 2) * 0.15, Color("4f8a43"))
	draw_rect(Rect2(0, 170, 1280, 550), Color("7dbb4f"))
	for d in _decor:
		var pos := Vector2(d.x, d.y)
		match int(d.z):
			0, 1, 2: Scenery.grass_tuft(self, pos, Color("5e9a3a"))
			3: Scenery.flower(self, pos, Color("f7a8c8"))
			4: Scenery.flower(self, pos, Color("fff3a0"))
	for p in [Vector2(40, 720), Vector2(1240, 720), Vector2(30, 420), Vector2(1250, 400)]:
		Scenery.bush(self, p, 1.3, Color("4f8a43"), true)
