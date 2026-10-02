extends Node2D
## Title screen: a starry forest night, the game's name, and the controls.

var _start_label: Label
var _stars: Array = []
var _time := 0.0


func _ready() -> void:
	seed(7)
	for i in 70:
		_stars.append(Vector3(randf() * 1280, randf() * 380, randf() * TAU))
	randomize()

	var cats := [
		[{"fur": Color("e8862a"), "markings": Color("b8561a"), "pattern": "Tabby Stripes", "eyes": Color("5fd14a")}, Vector2(400, 655), 1.0, 1.3],
		[{"fur": Color("8a8f98"), "markings": Color("fbf9f4"), "pattern": "Socks", "eyes": Color("4fb3f0")}, Vector2(880, 655), -1.0, 1.3],
		[{"fur": Color("f0d9a8"), "markings": Color("8a5a35"), "pattern": "Patches", "eyes": Color("f2a531")}, Vector2(630, 450), 1.0, 0.9],
	]
	for data in cats:
		var cat := Cat.new()
		cat.set_look(data[0])
		cat.position = data[1]
		cat.facing = data[2]
		cat.size = data[3]
		add_child(cat)

	Scenery.fireflies(self, Rect2(0, 250, 1280, 400))

	var ui := CanvasLayer.new()
	add_child(ui)
	ui.add_child(Fx.centered_label("WARRIOR CATS", 96, Color("ffd966"), 70))
	ui.add_child(Fx.centered_label("Path of the Apprentice", 40, Color("f6e8c8"), 190))
	_start_label = Fx.centered_label("Press SPACE to start!", 40, Color("9be37a"), 270)
	ui.add_child(_start_label)
	var controls := Fx.centered_label("Arrow keys = walk and choose     SPACE = jump, pounce, talk and OK", 26,
			Color("f6e8c8"), 660)
	ui.add_child(controls)


func _process(delta: float) -> void:
	_time += delta
	_start_label.modulate.a = 0.55 + 0.45 * sin(_time * 4.0)
	queue_redraw()
	if Transition.is_busy():
		return
	if Input.is_action_just_pressed("jump") or Input.is_action_just_pressed("action"):
		Sfx.play("select")
		Transition.go("res://scenes/creator.tscn")


func _draw() -> void:
	Scenery.sky(self, Color("1b1640"), Color("6b3f7a"))
	for s in _stars:
		var twinkle := 0.5 + 0.5 * sin(_time * 2.0 + s.z)
		draw_circle(Vector2(s.x, s.y), 1.5 + twinkle, Color(1, 1, 0.9, 0.4 + 0.6 * twinkle))
	draw_circle(Vector2(1090, 110), 58, Color(1, 0.97, 0.8, 0.15))
	draw_circle(Vector2(1090, 110), 46, Color("fff6d5"))
	for i in 12:
		Scenery.pine(self, Vector2(i * 120 - 20, 520), 1.4 + (i % 3) * 0.2, Color("1d2b3a"))
	draw_colored_polygon(Fx.ellipse_points(Vector2(640, 760), Vector2(900, 230)), Color("24402c"))
	Scenery.rock(self, Vector2(640, 610), 3.6, Color("5d6170"))
	for x in [120, 240, 1040, 1180]:
		Scenery.bush(self, Vector2(x, 720), 1.4, Color("2f5a33"))
