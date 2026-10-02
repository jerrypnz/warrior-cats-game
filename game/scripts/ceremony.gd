extends Node2D
## The warrior ceremony! Under the stars, Bluestar gives you and Graypaw your warrior names.

const CLAN_CATS := [
	["Lionheart", Vector2(320, 560)], ["Tigerclaw", Vector2(150, 620)], ["Spottedleaf", Vector2(330, 680)],
	["Ravenpaw", Vector2(960, 560)], ["Yellowfang", Vector2(1120, 620)], ["Frostfur", Vector2(950, 680)],
	["Cinderkit", Vector2(1060, 700)], ["Brightkit", Vector2(1150, 700)], ["Longtail", Vector2(180, 500)],
	["Sandpaw", Vector2(1100, 500)],
]

var _world: Node2D
var _player_cat: Cat
var _player_label: Label
var _graypaw: Npc
var _bluestar: Npc
var _clan: Array[Npc] = []
var _dialog: DialogBox
var _card: InfoCard
var _camera: Camera2D
var _reveal: CanvasLayer
var _stars: Array = []
var _shooting: Array = []  # [start, velocity, age]
var _time := 0.0


func _ready() -> void:
	seed(3)
	for i in 160:
		_stars.append(Vector3(randf() * 1280, randf() * 420, randf() * TAU))
	# Silverpelt: a band of tiny stars across the sky, where StarClan watches over the Clans
	for i in 260:
		var t := randf()
		_stars.append(Vector3(t * 1280, 330 - t * 300 + randf_range(-45, 45), -1.0))
	randomize()

	_camera = Camera2D.new()
	_camera.position = Vector2(640, 360)
	add_child(_camera)
	_world = Node2D.new()
	_world.y_sort_enabled = true
	add_child(_world)

	var rock := CampProp.new().setup("high_rock")
	rock.position = Vector2(640, 480)
	_world.add_child(rock)
	_bluestar = Npc.make("Bluestar")
	_bluestar.position = Vector2(-10, -136)
	rock.add_child(_bluestar)

	for c in CLAN_CATS:
		var npc := Npc.make(c[0], 1.0 if c[1].x < 640 else -1.0)
		npc.position = c[1]
		_world.add_child(npc)
		_clan.append(npc)
	_graypaw = Npc.make("Graypaw", 1.0)
	_graypaw.position = Vector2(540, 640)
	_world.add_child(_graypaw)

	_player_cat = Cat.new()
	_player_cat.set_look(GameState.look())
	_player_cat.size = 0.9
	_player_cat.facing = -1.0
	_player_cat.position = Vector2(730, 640)
	_world.add_child(_player_cat)
	_player_label = Fx.make_label(GameState.apprentice_name(), 26, Color("ffd966"), 6)
	_player_label.size = Vector2(400, 36)
	_player_label.position = Vector2(-200, -140)
	_player_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_player_cat.add_child(_player_label)

	Scenery.fireflies(self, Rect2(0, 380, 1280, 300))
	_dialog = DialogBox.new()
	add_child(_dialog)
	_card = InfoCard.new()
	add_child(_card)
	_reveal = CanvasLayer.new()
	add_child(_reveal)
	_run_ceremony.call_deferred()


func _run_ceremony() -> void:
	var paw := GameState.apprentice_name()
	await get_tree().create_timer(0.8).timeout
	_dialog.say(Story.lines([
		["Bluestar", "Let all cats old enough to catch their own prey gather beneath the Highrock!"],
		["Bluestar", "I, Bluestar, leader of ThunderClan, call upon StarClan to look down on these two apprentices."],
		["Bluestar", "They have trained hard to learn the ways of the warrior code. Graypaw, step forward."],
		["Bluestar", "Graypaw, from this moment you will be known as Graystripe!"],
	]))
	await _dialog.finished
	_graypaw.rename("Graystripe")
	_graypaw.cat.bounce(0.4)
	Sfx.play("powerup")
	Fx.confetti(self, _graypaw.position + Vector2(0, -80), 40)
	await _chant("Graystripe", 2)

	_dialog.say(Story.lines([
		["Bluestar", "{paw}, you came to us as a kittypet. But you have the heart of a true warrior."],
		["Bluestar", "{paw}, do you promise to protect your Clan with all your heart?"],
		[paw, "I do!"],
		["Bluestar", "Then by the power of StarClan, I give you your warrior name..."],
	]))
	await _dialog.finished

	# The big reveal!
	var warrior := GameState.warrior_name()
	await get_tree().create_timer(0.4).timeout
	_reveal.add_child(Fx.centered_label("From this moment, you will be known as", 30, Color("fff6ec"), 8))
	var big := Fx.centered_label(warrior.to_upper(), 96, Color("ffd966"), 44)
	big.add_theme_constant_override("outline_size", 14)
	big.pivot_offset = Vector2(640, 70)
	big.scale = Vector2(0.1, 0.1)
	_reveal.add_child(big)
	create_tween().tween_property(big, "scale", Vector2.ONE, 0.6).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	Sfx.play("powerup")
	Fx.shake(_camera, 10.0, 0.4)
	Fx.confetti(self, Vector2(640, 130), 120)
	Fx.hearts(self, _player_cat.position + Vector2(0, -80), 14)
	for k in 4:
		_shooting.append([Vector2(randf_range(200, 1200), randf_range(20, 160)), Vector2(-700, 260), 0.0])
	create_tween().tween_property(_player_cat, "size", 1.15, 0.8).set_trans(Tween.TRANS_BACK)
	_player_label.text = warrior
	_player_label.position.y = -165
	_player_cat.bounce(0.4)
	await get_tree().create_timer(0.7).timeout
	Sfx.play("win")
	await _chant(warrior, 3)

	_dialog.say(Story.lines([["Bluestar", "StarClan honors your {virtue}. We welcome you both as full warriors of ThunderClan!"]]))
	await _dialog.finished
	create_tween().tween_property(_reveal, "offset:y", -400.0, 0.5)
	_card.show_card("You're a Warrior!",
			"Congratulations, %s!\nYou went from kittypet to a true warrior of ThunderClan." % warrior,
			"Press SPACE to go back to camp")
	await _card.closed
	GameState.complete_step()


## The Clan cheers a new warrior's name
func _chant(cat_name: String, times: int) -> void:
	var cheering: Array[Npc] = _clan.duplicate()
	cheering.append(_bluestar)
	cheering.append(_graypaw)
	for k in times:
		for npc in cheering:
			Fx.popup_text(self, npc.global_position + Vector2(0, -150), cat_name + "!", Color("ffd966"), 26)
			npc.cat.bounce(0.3)
		Fx.confetti(self, Vector2(randf_range(300, 980), 300), 30)
		await get_tree().create_timer(0.8).timeout


func _process(delta: float) -> void:
	_time += delta
	for s in _shooting:
		s[2] += delta
	_shooting = _shooting.filter(func(s): return s[2] < 1.2)
	queue_redraw()


func _draw() -> void:
	Scenery.sky(self, Color("1b1640"), Color("6a4a8a"))
	for s in _stars:
		if s.z < 0.0:
			draw_circle(Vector2(s.x, s.y), 1.2, Color(0.95, 0.9, 1.0, 0.5))
		else:
			var twinkle := 0.5 + 0.5 * sin(_time * 2.5 + s.z)
			draw_circle(Vector2(s.x, s.y), 1.3 + twinkle * 1.2, Color(1, 1, 0.9, 0.4 + 0.6 * twinkle))
	for s in _shooting:
		var head: Vector2 = s[0] + s[1] * s[2]
		draw_line(head, head - s[1].normalized() * 90.0, Color(1, 1, 0.8, 1.0 - s[2] / 1.2), 3.0)
		Scenery.star(self, head, 8, Color("fff6d5"))
	draw_circle(Vector2(1100, 90), 56, Color(1, 0.97, 0.8, 0.15))
	draw_circle(Vector2(1100, 90), 44, Color("fff6d5"))
	for i in 12:
		Scenery.pine(self, Vector2(i * 120 - 20, 470), 1.3 + (i % 3) * 0.2, Color("2a2550"))
	draw_rect(Rect2(0, 460, 1280, 260), Color("3d5a48"))
	draw_colored_polygon(Fx.ellipse_points(Vector2(640, 600), Vector2(600, 140)), Color("4f7058"))
