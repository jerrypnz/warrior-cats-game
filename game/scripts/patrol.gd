extends Node2D
## Border patrol training: run along the edge of the territory, jump over streams and logs,
## and leave scent markers at the glowing trees.

const GROUND_Y := 600.0
const LEVEL_END := 4400.0
const FINISH_X := 4220.0
# Solid ground pieces [start x, end x]. The gaps between them are streams.
const GROUND := [[0, 900], [1050, 1850], [2000, 2900], [3050, 4400]]
# Logs and rocks to jump over: [x, y, width, height, "log" or "rock"]
const OBSTACLES := [
	[450, 555, 150, 45, "log"],
	[1300, 540, 110, 60, "rock"],
	[1480, 480, 140, 120, "rock"],
	[2250, 555, 170, 45, "log"],
	[2550, 500, 120, 100, "rock"],
	[3400, 555, 150, 45, "log"],
	[3700, 520, 120, 80, "rock"],
]
const MARKERS := [700, 1700, 2450, 3300, 3950]

var _player: PlatformPlayer
var _marked: Array[bool] = []
var _checkpoint_x := 140.0
var _playing := false
var _card: InfoCard
var _score_label: Label
var _time := 0.0
var _decor: Array = []


func _ready() -> void:
	seed(11)
	for i in 120:
		_decor.append(Vector3(randf_range(0, LEVEL_END), randf_range(612, 700), randi() % 4))
	randomize()
	for m in MARKERS:
		_marked.append(false)

	var background := CanvasLayer.new()
	background.layer = -1
	add_child(background)
	background.add_child(ForestBackground.new())

	for g in GROUND:
		_add_solid(Rect2(g[0], GROUND_Y, g[1] - g[0], 200))
	for o in OBSTACLES:
		_add_solid(Rect2(o[0], o[1], o[2], o[3]))
	_add_solid(Rect2(-50, -400, 50, 1200))
	_add_solid(Rect2(LEVEL_END, -400, 50, 1200))

	var mentor := Npc.new().setup(GameState.MENTOR, {"fur": Color("c9ced6"), "markings": Color("5d626b"),
			"pattern": "Tabby Stripes", "eyes": Color("5fd14a")}, 1.05, -1.0)
	mentor.position = Vector2(4330, GROUND_Y)
	add_child(mentor)

	_player = PlatformPlayer.new()
	_player.position = Vector2(_checkpoint_x, GROUND_Y - 2)
	_player.frozen = true
	add_child(_player)
	var camera := Camera2D.new()
	camera.limit_left = 0
	camera.limit_right = int(LEVEL_END)
	camera.limit_top = 0
	camera.limit_bottom = 720
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 6.0
	camera.position = Vector2(160, -40)  # see more of what is ahead
	_player.add_child(camera)

	var hud := CanvasLayer.new()
	add_child(hud)
	hud.add_child(Fx.centered_label("BORDER PATROL", 34, Color("ffd966"), 10))
	_score_label = Fx.centered_label("", 36, Color.WHITE, 54)
	hud.add_child(_score_label)
	_update_score()

	_card = InfoCard.new()
	add_child(_card)
	_card.show_card("Border Patrol!",
			"Run to the border and leave a scent marker on every glowing tree.\n\nPress SPACE to jump over logs, rocks and streams!",
			"Press SPACE to start!")
	await _card.closed
	_playing = true
	_player.frozen = false


func _add_solid(rect: Rect2) -> void:
	var body := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = rect.size
	shape.shape = box
	shape.position = rect.get_center()
	body.add_child(shape)
	add_child(body)


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()
	if not _playing:
		return
	var x := _player.position.x
	for i in MARKERS.size():
		if not _marked[i] and absf(x - MARKERS[i]) < 50:
			_mark(i)
	if _player.position.y > 700:
		_splash()
	elif x > FINISH_X:
		_win()


func _mark(i: int) -> void:
	_marked[i] = true
	_checkpoint_x = MARKERS[i]
	Sfx.play("collect")
	var pos := Vector2(MARKERS[i], GROUND_Y - 90)
	Fx.burst(self, pos, Color("c77dff"), 20)
	Fx.burst(self, pos, Color("ffd23f"), 12)
	Fx.popup_text(self, pos + Vector2(0, -80), "Scent marked!", Color("e7c6ff"))
	_player.cat.bounce(0.25)
	_update_score()


func _splash() -> void:
	var pos := _player.position
	Sfx.play("hurt")
	Fx.burst(self, Vector2(pos.x, 650), Color("8fd3ff"), 24, 380.0, 900.0)
	Fx.popup_text(self, Vector2(pos.x, 560), "Splash! Try again!", Color("8fd3ff"))
	_player.position = Vector2(_checkpoint_x, GROUND_Y - 2)
	_player.velocity = Vector2.ZERO
	_player.cat.bounce(0.3)


func _update_score() -> void:
	_score_label.text = "Scent markers: %d / %d" % [_marked.count(true), MARKERS.size()]


func _win() -> void:
	_playing = false
	_player.frozen = true
	Sfx.play("win")
	Fx.confetti(self, _player.position + Vector2(0, -200), 80)
	await get_tree().create_timer(1.0).timeout
	_card.show_card("Border Patrolled!", "You marked the whole border!\nNow every Clan knows this is %s territory." % GameState.CLAN,
			"Press SPACE to go back to camp")
	await _card.closed
	GameState.finish_training("patrol")
	Transition.go("res://scenes/camp.tscn")


# --- drawing -------------------------------------------------------------------------------

func _draw() -> void:
	# Streams in the gaps
	for i in GROUND.size() - 1:
		var left: float = GROUND[i][1]
		var right: float = GROUND[i + 1][0]
		draw_rect(Rect2(left, 630, right - left, 120), Color("3a8fd1"))
		for k in 6:
			var wx := left + fmod(k * 40.0 + _time * 40.0, right - left)
			draw_line(Vector2(wx, 645 + (k % 2) * 25), Vector2(wx + 20, 645 + (k % 2) * 25), Color("bfe6ff"), 3.0)
	# Ground
	for g in GROUND:
		var rect := Rect2(g[0], GROUND_Y, g[1] - g[0], 200)
		draw_rect(rect, Color("7a5230"))
		draw_rect(Rect2(rect.position, Vector2(rect.size.x, 18)), Color("5fae3c"))
		draw_rect(Rect2(rect.position + Vector2(0, 18), Vector2(rect.size.x, 5)), Color("4a8a2f"))
	for d in _decor:
		var pos := Vector2(d.x, d.y)
		if _over_water(pos.x):
			continue
		match int(d.z):
			0: Scenery.flower(self, Vector2(pos.x, GROUND_Y - 10), Color("f7a8c8"))
			1: Scenery.grass_tuft(self, Vector2(pos.x, GROUND_Y + 2), Color("4a8a2f"))
			2: draw_circle(pos, 5, Color("6b4428"))
	# Logs and rocks
	for o in OBSTACLES:
		var r := Rect2(o[0], o[1], o[2], o[3])
		if o[4] == "log":
			draw_rect(r.grow(3), Scenery.OUTLINE)
			draw_rect(r, Color("8a5a35"))
			draw_line(r.position + Vector2(10, 15), r.position + Vector2(r.size.x - 30, 15), Color("6b4428"), 3.0)
			draw_circle(Vector2(r.end.x, r.get_center().y), r.size.y / 2.0 + 3, Scenery.OUTLINE)
			draw_circle(Vector2(r.end.x, r.get_center().y), r.size.y / 2.0, Color("c79a5f"))
			draw_arc(Vector2(r.end.x, r.get_center().y), r.size.y / 4.0, 0, TAU, 16, Color("8a5a35"), 2.0)
		else:
			var rock_style := Fx.panel_style(Color("8d8f96"), Scenery.OUTLINE, 22, 3)
			rock_style.draw(get_canvas_item(), r)
			var shine := Fx.panel_style(Color("b4b6bd"), Color(0, 0, 0, 0), 6, 0)
			shine.draw(get_canvas_item(), Rect2(r.position + Vector2(14, 10), Vector2(r.size.x * 0.45, 10)))
	# Scent marker trees
	for i in MARKERS.size():
		_draw_marker(Vector2(MARKERS[i], GROUND_Y), _marked[i])
	# Border stones and sign at the finish
	for k in 4:
		Scenery.rock(self, Vector2(FINISH_X + 30 + k * 26, GROUND_Y + 4), 0.35, Color("a3a5ad"))
	draw_rect(Rect2(FINISH_X - 6, GROUND_Y - 150, 12, 150), Color("6b4428"))
	draw_rect(Rect2(FINISH_X - 70, GROUND_Y - 170, 140, 50).grow(3), Scenery.OUTLINE)
	draw_rect(Rect2(FINISH_X - 70, GROUND_Y - 170, 140, 50), Color("c79a5f"))
	draw_string(ThemeDB.fallback_font, Vector2(FINISH_X - 60, GROUND_Y - 136), "BORDER", HORIZONTAL_ALIGNMENT_CENTER,
			120, 26, Scenery.OUTLINE)


func _draw_marker(base: Vector2, done: bool) -> void:
	var glow := Color("ffd23f") if done else Color("c77dff")
	var pulse := 0.5 + 0.5 * sin(_time * 4.0)
	draw_circle(base + Vector2(0, -90), 70 + pulse * 10, Color(glow, 0.18))
	draw_circle(base + Vector2(0, -90), 48 + pulse * 6, Color(glow, 0.25))
	Scenery.tree(self, base, 0.8, Color("3d7a3a"))
	for k in 4:
		var a := _time * 1.5 + k * TAU / 4.0
		Scenery.star(self, base + Vector2(cos(a) * 55, -90 + sin(a) * 30), 7, glow)


func _over_water(x: float) -> bool:
	for g in GROUND:
		if x >= g[0] and x <= g[1]:
			return false
	return true


class ForestBackground extends Node2D:
	## Sky and far-away trees that scroll slower than the ground (parallax).
	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var cam := get_viewport().get_camera_2d()
		var cam_x := cam.get_screen_center_position().x if cam else 640.0
		Scenery.sky(self, Color("8fd0f0"), Color("e3f4f7"))
		draw_circle(Vector2(1100, 110), 50, Color("fff3b0"))
		var far_shift := fmod(cam_x * 0.12, 110.0)
		for i in 14:
			Scenery.pine(self, Vector2(i * 110 - far_shift, 470), 1.0 + (i % 3) * 0.25, Color("9cc3b0"))
		draw_rect(Rect2(0, 465, 1280, 260), Color("9cc3b0"))
		var near_shift := fmod(cam_x * 0.35, 660.0)
		for i in 9:
			Scenery.tree(self, Vector2(i * 220 - near_shift, 540), 1.0 + (i % 3) * 0.2, Color("6fa86f"),
					Color("5a4632"))
		draw_rect(Rect2(0, 535, 1280, 200), Color("6fa86f"))
