extends Node2D
## Two players hunting together in a big forest, split screen!
## Player 1 (left side): arrows + SPACE to pounce.  Player 2 (right side): W A S D + E to pounce.
## Everything you both catch goes on your fresh-kill piles, and playing together makes you friends.

const MAP := Rect2(0, 0, 2400, 1500)
const FIELD := Rect2(90, 170, 2220, 1250)  # where cats and mice can go
const CATCH_DISTANCE := 70.0
const SCARE_DISTANCE := 115.0
const PLAY_TIME := 75.0
const MICE := 18

var _world: Node2D
var _players: Array[TopDownPlayer] = []
var _cameras: Array[Camera2D] = []
var _infos: Array = []
var _scores := [0, 0]
var _score_labels: Array[Label] = []
var _timer_label: Label
var _mice: Array[Mouse] = []
var _time_left := PLAY_TIME
var _playing := false
var _card: InfoCard


func _ready() -> void:
	for slot in GameState.together:
		_infos.append(GameState.describe_slot(slot))
	if _infos.size() < 2 or _infos.has({}):
		Transition.go.call_deferred("res://scenes/title.tscn")  # nobody to play with
		return

	# Two views of the same forest: the left one follows Player 1, the right one follows Player 2
	_world = ForestFloor.new()
	_world.y_sort_enabled = true
	_cameras = SplitScreen.make(self, _world, MAP)
	for i in 2:
		var player := SplitScreen.make_player(_infos[i], i, FIELD)
		player.position = FIELD.get_center() + Vector2(-140 + i * 280, 200)
		_world.add_child(player)
		_players.append(player)
		_cameras[i].position = player.position
	for i in MICE:
		_spawn_mouse(Vector2(randf_range(FIELD.position.x + 60, FIELD.end.x - 60), randf_range(FIELD.position.y + 60, FIELD.end.y - 60)))

	_make_hud()
	_card = InfoCard.new()
	add_child(_card)
	_card.show_card("Hunting Together!",
			"%s: arrows to walk, SPACE to pounce\n%s: W A S D to walk, E to pounce\n\nCatch as many mice as you can in %d seconds!" % [
				_infos[0].name, _infos[1].name, int(PLAY_TIME)],
			"Press SPACE to start!")
	await _card.closed
	_playing = true
	for player in _players:
		player.frozen = false


func _make_hud() -> void:
	var hud := CanvasLayer.new()
	add_child(hud)
	SplitScreen.divider(hud)
	for i in 2:
		var label := Fx.make_label("", 30, Color("ffd966"), 8)
		label.position = Vector2(16 + i * 660, 12)
		label.size = Vector2(600, 40)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if i == 0 else HORIZONTAL_ALIGNMENT_RIGHT
		hud.add_child(label)
		_score_labels.append(label)
		var keys := Fx.make_label("Arrows + SPACE" if i == 0 else "W A S D + E", 22, Color("fff6ec"), 6)
		keys.position = Vector2(16 + i * 660, 680)
		keys.size = Vector2(600, 30)
		keys.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if i == 0 else HORIZONTAL_ALIGNMENT_RIGHT
		hud.add_child(keys)
	var timer_back := Panel.new()
	timer_back.position = Vector2(570, 8)
	timer_back.size = Vector2(140, 56)
	timer_back.add_theme_stylebox_override("panel", Fx.cute_panel(18))
	hud.add_child(timer_back)
	_timer_label = Fx.centered_label("", 34, Fx.PINK_DARK, 6, 140)
	_timer_label.add_theme_constant_override("outline_size", 0)
	timer_back.add_child(_timer_label)
	_update_hud()


func _spawn_mouse(pos: Vector2) -> void:
	var mouse := Mouse.new()
	mouse.position = pos
	mouse.bounds = FIELD
	mouse.scale = Vector2(1.4, 1.4)
	_world.add_child(mouse)
	_mice.append(mouse)


func _process(delta: float) -> void:
	for i in _cameras.size():
		_cameras[i].position = _players[i].position + Vector2(0, -60)
	if not _playing:
		return
	_time_left -= delta
	if _time_left <= 0.0:
		_time_left = 0.0
		_finish()
	for mouse: Mouse in _mice.duplicate():
		for i in 2:
			var player := _players[i]
			var d := mouse.global_position.distance_to(player.global_position)
			if player.is_pouncing() and d < CATCH_DISTANCE:
				_catch(mouse, i)
				break
			elif not player.is_pouncing() and d < SCARE_DISTANCE and player.cat.walk_amount > 0.3:
				mouse.scare(player.global_position)
	_update_hud()


func _catch(mouse: Mouse, who: int) -> void:
	_mice.erase(mouse)
	var pos := mouse.global_position
	mouse.queue_free()
	_scores[who] += 1
	Sfx.play("collect")
	Fx.burst(_world, pos + Vector2(0, -20), Color("fff27a"), 18)
	Fx.hearts(_world, pos + Vector2(0, -30), 6)
	Fx.popup_text(_world, pos + Vector2(0, -70), ["Got it!", "Nice catch!", "Great pounce!", "Yum!"].pick_random(),
			Color("ffd966"))
	_players[who].cat.bounce(0.3)
	await get_tree().create_timer(1.0).timeout
	if _playing:
		_spawn_mouse(Vector2(randf_range(FIELD.position.x + 60, FIELD.end.x - 60), randf_range(FIELD.position.y + 60, FIELD.end.y - 60)))


func _update_hud() -> void:
	for i in 2:
		_score_labels[i].text = "%s: %d" % [_infos[i].name, _scores[i]]
	_timer_label.text = str(ceili(_time_left))


func _finish() -> void:
	_playing = false
	for player in _players:
		player.frozen = true
	Sfx.play("win")
	for i in 2:
		Fx.confetti(_world, _players[i].position + Vector2(0, -120), 60)
	var total: int = _scores[0] + _scores[1]
	var best := "It's a tie!" if _scores[0] == _scores[1] else \
			"%s caught the most!" % _infos[0 if _scores[0] > _scores[1] else 1].name
	var slots: Array = GameState.together
	var new_friends := not GameState.are_friends(slots[0], slots[1])
	GameState.make_friends(slots[0], slots[1])
	for i in 2:
		GameState.add_prey_to_slot(slots[i], _scores[i])
	var body := "%s caught %d\n%s caught %d\n%s\nTogether: %d mice for the Clan!" % [
			_infos[0].name, _scores[0], _infos[1].name, _scores[1], best, total]
	if new_friends:
		body += "\nAnd now you're friends!"
	await get_tree().create_timer(1.2).timeout
	_card.show_card("Time's Up!", body, "Press SPACE to go back to the title screen")
	await _card.closed
	GameState.together = []
	Transition.go("res://scenes/title.tscn")


class ForestFloor extends Node2D:
	## The big forest where the players hunt (drawn once)
	func _draw() -> void:
		var grass := Color("8fca72")
		draw_rect(MAP, Color("5f9e4f"))
		draw_rect(FIELD.grow(40), grass)
		seed(31)
		for i in 260:
			var p := Vector2(randf_range(FIELD.position.x, FIELD.end.x), randf_range(FIELD.position.y, FIELD.end.y))
			match i % 6:
				0, 1, 2: Scenery.grass_tuft(self, p, grass.darkened(0.2))
				3: Scenery.flower(self, p, Color("f7a8c8"))
				4: Scenery.flower(self, p, Color("fff3a0"))
				5: draw_circle(p, 4, Color("7ab35f"))
		# Trees all around the edge, and a few in the middle to hide behind
		var x := 0.0
		while x < MAP.end.x + 100:
			Scenery.tree(self, Vector2(x, FIELD.position.y + 10), 1.1, Color("6fb85a"), Color("a0704e"))
			Scenery.bush(self, Vector2(x + 60, MAP.end.y), 1.4, Color("5fa84f"))
			x += 150.0
		for y in range(int(FIELD.position.y) + 120, int(MAP.end.y), 170):
			Scenery.bush(self, Vector2(40, y), 1.3, Color("5fa84f"))
			Scenery.bush(self, Vector2(MAP.end.x - 40, y), 1.3, Color("5fa84f"))
		for p in [Vector2(600, 600), Vector2(1200, 900), Vector2(1800, 520), Vector2(900, 1200), Vector2(2000, 1150)]:
			Scenery.bush(self, p, 1.2, Color("6fb85a"))
		for p in [Vector2(1500, 400), Vector2(400, 1050)]:
			Scenery.rock(self, p, 1.3, Color("b8b4bd"))
		draw_colored_polygon(Fx.ellipse_points(Vector2(1300, 1250), Vector2(170, 60)), Color("6fc1e8"))
		draw_colored_polygon(Fx.ellipse_points(Vector2(1300, 1245), Vector2(150, 48)), Color("8fd3ff"))
		randomize()
