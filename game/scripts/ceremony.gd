extends Node2D
## The warrior ceremony! Under the stars, the leader gives the apprentice their warrior name.

var _world: Node2D
var _player_cat: Cat
var _player_label: Label
var _leader: Npc
var _clan: Array[Npc] = []
var _dialog: DialogBox
var _card: InfoCard
var _camera: Camera2D
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
	_leader = Npc.new().setup(GameState.LEADER, {"fur": Color("8a5a35"), "markings": Color("4a2c18"),
			"pattern": "Tabby Stripes", "eyes": Color("f2a531")}, 1.0, -1.0)
	_leader.position = Vector2(-10, -136)
	rock.add_child(_leader)

	var clanmates := [
		[GameState.MENTOR, Color("c9ced6"), Color("5d626b"), "Tabby Stripes", Vector2(330, 560), 1.05],
		["Sorrelstripe", Color("e8862a"), Color("fbf9f4"), "Patches", Vector2(170, 620), 1.0],
		["Pebblefoot", Color("8a8f98"), Color("34313a"), "Spots", Vector2(960, 560), 1.0],
		["Mumblefoot", Color("6f7f99"), Color("fbf9f4"), "Socks", Vector2(1110, 620), 0.95],
		["Acornkit", Color("8a5a35"), Color("e8862a"), "Spots", Vector2(330, 690), 0.55],
		["Minnowkit", Color("c9ced6"), Color("5d626b"), "Spots", Vector2(960, 690), 0.55],
	]
	for c in clanmates:
		var npc := Npc.new().setup(c[0], {"fur": c[1], "markings": c[2], "pattern": c[3],
				"eyes": Color("5fd14a")}, c[5], 1.0 if c[4].x < 640 else -1.0)
		npc.position = c[4]
		_world.add_child(npc)
		_clan.append(npc)

	_player_cat = Cat.new()
	_player_cat.set_look(GameState.look())
	_player_cat.size = 0.85
	_player_cat.position = Vector2(640, 640)
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
	_run_ceremony.call_deferred()


func _run_ceremony() -> void:
	var lead := GameState.LEADER
	var paw := GameState.apprentice_name()
	await get_tree().create_timer(0.8).timeout
	_dialog.say([
		[lead, "Let all cats old enough to catch their own prey gather beneath the High Rock!"],
		[lead, "I, %s, leader of %s, call upon StarClan to look down on this apprentice." % [lead, GameState.CLAN]],
		[lead, "%s has trained hard to learn the ways of the warrior code." % paw],
		[lead, "%s, do you promise to protect your Clan with all your heart?" % paw],
		[paw, "I do!"],
		[lead, "Then by the power of StarClan, I give you your warrior name..."],
	])
	await _dialog.finished

	# The big reveal!
	GameState.is_warrior = true
	var warrior := GameState.warrior_name()
	await get_tree().create_timer(0.4).timeout
	var reveal := CanvasLayer.new()
	add_child(reveal)
	var small := Fx.centered_label("From this moment, you will be known as", 30, Color("f6e8c8"), 8)
	reveal.add_child(small)
	var big := Fx.centered_label(warrior.to_upper(), 96, Color("ffd966"), 44)
	big.add_theme_constant_override("outline_size", 14)
	big.pivot_offset = Vector2(640, 80)
	big.scale = Vector2(0.1, 0.1)
	reveal.add_child(big)
	create_tween().tween_property(big, "scale", Vector2.ONE, 0.6).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	Sfx.play("powerup")
	Fx.shake(_camera, 10.0, 0.4)
	Fx.confetti(self, Vector2(640, 130), 120)
	for k in 4:
		_shooting.append([Vector2(randf_range(200, 1200), randf_range(20, 160)), Vector2(-700, 260), 0.0])
	var grow := create_tween()
	grow.tween_property(_player_cat, "size", GameState.cat_size(), 0.8).set_trans(Tween.TRANS_BACK)
	_player_label.text = warrior
	_player_cat.bounce(0.4)
	await get_tree().create_timer(0.7).timeout
	Sfx.play("win")

	# The Clan cheers the new name
	var everyone: Array[Npc] = _clan.duplicate()
	everyone.append(_leader)
	for cheer in 3:
		for npc in everyone:
			Fx.popup_text(self, npc.global_position + Vector2(0, -150), warrior + "!", Color("ffd966"), 28)
			npc.cat.bounce(0.3)
		Fx.confetti(self, Vector2(randf_range(300, 980), 300), 40)
		await get_tree().create_timer(0.8).timeout

	_dialog.say([[lead, "StarClan honors your %s, and we welcome you as a full warrior of %s!" % [
			GameState.personality().virtue, GameState.CLAN]]])
	await _dialog.finished
	create_tween().tween_property(reveal, "offset:y", -400.0, 0.5)
	_card.show_card("You're a Warrior!",
			"Congratulations, %s!\nYou trained hard and became a true warrior of %s." % [warrior, GameState.CLAN],
			"Press SPACE to go back to camp")
	await _card.closed
	GameState.just_finished = "ceremony"
	Transition.go("res://scenes/camp.tscn")


func _process(delta: float) -> void:
	_time += delta
	for s in _shooting:
		s[2] += delta
	_shooting = _shooting.filter(func(s): return s[2] < 1.2)
	queue_redraw()


func _draw() -> void:
	Scenery.sky(self, Color("0d0b2a"), Color("3a2a6a"))
	for s in _stars:
		if s.z < 0.0:
			draw_circle(Vector2(s.x, s.y), 1.2, Color(0.85, 0.88, 1.0, 0.45))
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
		Scenery.pine(self, Vector2(i * 120 - 20, 470), 1.3 + (i % 3) * 0.2, Color("141c2e"))
	draw_rect(Rect2(0, 460, 1280, 260), Color("2a3f2e"))
	draw_colored_polygon(Fx.ellipse_points(Vector2(640, 600), Vector2(600, 140)), Color("3a5238"))
