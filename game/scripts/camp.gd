extends Node2D
## ThunderClan camp: walk around, talk to your mentor and Clanmates, and go off to train.

const CLEARING := Rect2(120, 190, 1040, 490)  # the oval cats can walk in
const TALK_DISTANCE := 115.0

var _world: Node2D
var _player: TopDownPlayer
var _dialog: DialogBox
var _mentor: Npc
var _leader: Npc
var _npcs: Array[Npc] = []
var _checklist: Checklist
var _goal_label: Label
var _rank_label: Label
var _busy := false  # true during cutscenes
var _decor: Array = []


func _ready() -> void:
	seed(42)
	for i in 70:
		_decor.append(Vector3(randf_range(160, 1120), randf_range(220, 670), randi() % 4))
	randomize()

	_world = Node2D.new()
	_world.y_sort_enabled = true
	add_child(_world)

	var rock: CampProp = _add_prop("high_rock", Vector2(640, 300), "")
	_add_prop("den", Vector2(225, 345), "Warriors' Den")
	_add_prop("den", Vector2(1055, 345), "Apprentices' Den")
	_add_prop("den", Vector2(250, 630), "Nursery")
	_add_prop("den", Vector2(1030, 630), "Elders' Den")
	_add_prop("fresh_kill", Vector2(820, 450), "Fresh-kill Pile")

	_player = TopDownPlayer.new()
	_player.position = Vector2(640, 560) if GameState.met_clan else Vector2(640, 420)
	_player.bounds = CLEARING
	_player.round_bounds = true
	_world.add_child(_player)
	for prop in _world.get_children():
		if prop is CampProp:
			_player.blockers.append(prop.footprint())

	# The leader stands on top of the High Rock
	_leader = Npc.new().setup(GameState.LEADER, {"fur": Color("8a5a35"), "markings": Color("4a2c18"),
			"pattern": "Tabby Stripes", "eyes": Color("f2a531")}, 1.05, 1.0)
	_leader.position = Vector2(-10, -136)
	_leader.talk_spot = Vector2(0, 175)
	_leader.bubble_offset = Vector2(-105, 100)
	rock.add_child(_leader)
	_npcs.append(_leader)

	_mentor = _add_npc(GameState.MENTOR, {"fur": Color("c9ced6"), "markings": Color("5d626b"),
			"pattern": "Tabby Stripes", "eyes": Color("5fd14a")}, Vector2(470, 430), 1.05)
	_add_npc("Sorrelstripe", {"fur": Color("e8862a"), "markings": Color("fbf9f4"), "pattern": "Patches",
			"eyes": Color("f5e04a")}, Vector2(760, 360), 1.0, Rect2(600, 330, 300, 150))
	_add_npc("Pebblefoot", {"fur": Color("8a8f98"), "markings": Color("34313a"), "pattern": "Spots",
			"eyes": Color("4fb3f0")}, Vector2(320, 440), 1.0, Rect2(280, 410, 110, 90))
	_add_npc("Mumblefoot", {"fur": Color("6f7f99"), "markings": Color("fbf9f4"), "pattern": "Socks",
			"eyes": Color("f2a531")}, Vector2(880, 645), 0.95, Rect2(), -1.0)
	for kit in [["Acornkit", Color("8a5a35"), Color("e8862a")], ["Minnowkit", Color("c9ced6"), Color("5d626b")]]:
		var npc := _add_npc(kit[0], {"fur": kit[1], "markings": kit[2], "pattern": "Spots",
				"eyes": Color("4fb3f0")}, Vector2(420, 610), 0.55, Rect2(380, 560, 190, 80))
		npc.speed = 120.0
		npc.hops = true

	_dialog = DialogBox.new()
	add_child(_dialog)
	_busy = true
	_make_hud()
	_add_falling_leaves()
	_enter_camp.call_deferred()


func _add_prop(kind: String, pos: Vector2, label: String) -> CampProp:
	var prop := CampProp.new().setup(kind, label)
	prop.position = pos
	_world.add_child(prop)
	return prop


func _add_npc(cat_name: String, look: Dictionary, pos: Vector2, cat_size: float,
		wander := Rect2(), face := 1.0) -> Npc:
	var npc := Npc.new().setup(cat_name, look, cat_size, face)
	npc.position = pos
	npc.wander_area = wander
	_world.add_child(npc)
	_npcs.append(npc)
	return npc


# --- talking -------------------------------------------------------------------------------

func _process(_delta: float) -> void:
	if _busy or _dialog.is_open() or Transition.is_busy():
		_player.frozen = true
		for npc in _npcs:
			npc.show_prompt(false)
		return
	_player.frozen = false
	var nearest: Npc = null
	var best := TALK_DISTANCE
	for npc in _npcs:
		var d := npc.talk_position().distance_to(_player.global_position)
		if d < best:
			best = d
			nearest = npc
	for npc in _npcs:
		npc.show_prompt(npc == nearest)
	if nearest and Input.is_action_just_pressed("jump"):
		_talk(nearest)


func _talk(npc: Npc) -> void:
	npc.face_toward(_player.global_position)
	_player.cat.facing = signf(npc.global_position.x - _player.global_position.x)
	Sfx.play("select")
	_dialog.say(_lines_for(npc))
	await _dialog.finished
	var next := GameState.next_training()
	if npc == _mentor and not GameState.is_warrior and next != "":
		Transition.go(GameState.TRAINING_SCENES[next])
	elif npc == _leader and not GameState.is_warrior and next == "":
		Transition.go("res://scenes/ceremony.tscn")


func _lines_for(npc: Npc) -> Array:
	var me := GameState.cat_name()
	var m := GameState.MENTOR
	var lead := GameState.LEADER
	if npc == _mentor:
		if GameState.is_warrior:
			return [[m, "%s! My apprentice is a real warrior now. I'm SO proud of you!" % me]]
		match GameState.next_training():
			"hunting":
				return [[m, "Ready for your first lesson, %s? A warrior always feeds the Clan. Let's go HUNTING!" % me],
						[m, "Creep up close to the mice, then press SPACE to POUNCE! Catch 5 mice."]]
			"patrol":
				return [[m, "Now we'll patrol the border and leave scent markers, so the other Clans know where our territory is."],
						[m, "Watch out for streams! Press SPACE to jump over them."]]
			"battle":
				return [[m, "Last lesson: battle practice! A warrior protects their Clan."],
						[m, "I'll roll moss balls at you. Press SPACE to swat them away! No claws - it's only practice!"]]
		return [[m, "You've learned everything I can teach you, %s! Go and see %s at the High Rock. Hurry!" % [me, lead]]]
	if npc == _leader:
		if GameState.is_warrior:
			return [[lead, "%s is stronger with a warrior like you, %s." % [GameState.CLAN, me]]]
		if GameState.next_training() == "":
			return [[lead, "%s, %s tells me your training is complete." % [me, m]],
					[lead, "Then it is time... for your WARRIOR CEREMONY!"]]
		return [[lead, "Train hard, young %s. %s will teach you well." % [me, m]]]
	var chats := {
		"Sorrelstripe": ["Hi %s! Did you know I caught TWO squirrels yesterday?" % me,
				"Being %s is great for a warrior! Keep it up!" % GameState.personality().name.to_lower()],
		"Pebblefoot": ["Watch out for the brambles, they're super prickly!",
				"The fresh-kill pile is looking good today. Mmm, mice!"],
		"Mumblefoot": ["When I was an apprentice, I caught a mouse THIS big! ...Well, almost.",
				"Ahh, the sun feels nice on my old fur."],
		"Acornkit": ["Wow, a real %s! When I grow up I'll be just like you!" % ("warrior" if GameState.is_warrior else "apprentice"),
				"Do you want to play moss-ball with us?"],
		"Minnowkit": ["I'm going to be the fastest warrior EVER!", "Shhh! We're hiding from Acornkit!"],
	}
	var options: Array = chats.get(npc.npc_name, ["Hello!"])
	return [[npc.npc_name, options.pick_random()]]


# --- cutscenes -----------------------------------------------------------------------------

func _enter_camp() -> void:
	var me := GameState.cat_name()
	var m := GameState.MENTOR
	var lead := GameState.LEADER
	_busy = true
	if not GameState.met_clan:
		await get_tree().create_timer(0.6).timeout
		_dialog.say([
			[lead, "Let all cats old enough to catch their own prey gather beneath the High Rock!"],
			[lead, "Today %s welcomes a new apprentice. From this day on, you will be known as %s!" % [GameState.CLAN, me]],
			[lead, "%s, you will be %s's mentor. Teach this young cat everything you know." % [m, me]],
		])
		await _dialog.finished
		_cheer(me)
		await get_tree().create_timer(1.4).timeout
		_dialog.say([[m, "Welcome, %s! I can tell you're very %s. That will make you a great warrior!" % [me, GameState.personality().name.to_lower()]],
				[m, "Come and talk to me when you're ready to start training. Look for the yellow \"!\""]])
		await _dialog.finished
		GameState.met_clan = true
	elif GameState.just_finished in GameState.TRAININGS:
		var praise := {
			"hunting": "Great hunting, %s! The elders will love those mice." % me,
			"patrol": "Every scent marker is in place. No cat will sneak into our territory now!",
			"battle": "WOW, what fast paws! Your %s really showed today." % GameState.personality().virtue,
		}
		var follow := "Come and talk to me when you're ready for your next lesson."
		if GameState.next_training() == "":
			follow = "That was your last lesson! Go and see %s at the High Rock!" % lead
		_dialog.say([[m, praise[GameState.just_finished]], [m, follow]])
		await _dialog.finished
	elif GameState.just_finished == "ceremony":
		_cheer(me)
		_dialog.say([[m, "Welcome to the warriors, %s! You can sleep in the Warriors' Den now!" % me]])
		await _dialog.finished
	GameState.just_finished = ""
	_busy = false
	_update_hud()


func _cheer(cat_name: String) -> void:
	Sfx.play("win")
	for i in 2:
		for npc in _npcs:
			Fx.popup_text(self, npc.global_position + Vector2(0, -130), cat_name + "!", Color("ffd966"), 26)
			npc.cat.bounce(0.25)
		await get_tree().create_timer(0.6).timeout


# --- HUD -----------------------------------------------------------------------------------

func _make_hud() -> void:
	var hud := CanvasLayer.new()
	hud.layer = 5
	add_child(hud)
	var panel := Panel.new()
	panel.position = Vector2(12, 10)
	panel.size = Vector2(300, 200)
	panel.add_theme_stylebox_override("panel", Fx.panel_style(Color(0.16, 0.11, 0.07, 0.8), Color("e8c26a"), 14, 3))
	hud.add_child(panel)
	var name_label := Fx.make_label(GameState.cat_name(), 32, Color("ffd966"))
	name_label.position = Vector2(16, 6)
	panel.add_child(name_label)
	_rank_label = Fx.make_label("", 20, Color("f6e8c8"), 5)
	_rank_label.position = Vector2(16, 48)
	panel.add_child(_rank_label)
	_checklist = Checklist.new()
	_checklist.position = Vector2(16, 84)
	panel.add_child(_checklist)
	for i in GameState.TRAININGS.size():
		var label := Fx.make_label(GameState.TRAINING_NAMES[GameState.TRAININGS[i]], 22, Color.WHITE, 5)
		label.position = Vector2(56, 82 + i * 36)
		panel.add_child(label)
	_goal_label = Fx.centered_label("", 26, Color("9be37a"), 680, 1280)
	hud.add_child(_goal_label)
	_update_hud()


func _update_hud() -> void:
	var next := GameState.next_training()
	_rank_label.text = "%s %s" % [GameState.CLAN, "Warrior" if GameState.is_warrior else "Apprentice"]
	_checklist.queue_redraw()
	_mentor.has_news = not GameState.is_warrior and next != "" and not _busy
	_leader.has_news = not GameState.is_warrior and next == "" and not _busy
	if GameState.is_warrior:
		_goal_label.text = "You're a warrior! Explore the camp and visit your Clanmates."
	elif next == "":
		_goal_label.text = "Goal: Talk to %s at the High Rock!" % GameState.LEADER
	else:
		_goal_label.text = "Goal: Talk to %s for %s training!" % [GameState.MENTOR, GameState.TRAINING_NAMES[next]]


class Checklist extends Control:
	func _draw() -> void:
		for i in GameState.TRAININGS.size():
			var c := Vector2(14, 18 + i * 36)
			var done: bool = GameState.trainings_done[GameState.TRAININGS[i]]
			draw_circle(c, 14, Color("2a1d17"))
			draw_circle(c, 11, Color("5fd14a") if done else Color("5a4a3a"))
			if done:
				draw_polyline(PackedVector2Array([c + Vector2(-6, 0), c + Vector2(-1, 5), c + Vector2(7, -6)]),
						Color.WHITE, 3.5)


# --- scenery -------------------------------------------------------------------------------

func _add_falling_leaves() -> void:
	var p := CPUParticles2D.new()
	p.position = Vector2(640, -20)
	p.amount = 14
	p.lifetime = 9.0
	p.preprocess = 9.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(700, 10)
	p.gravity = Vector2(15, 30)
	p.initial_velocity_min = 10.0
	p.initial_velocity_max = 40.0
	p.angular_velocity_min = -90.0
	p.angular_velocity_max = 90.0
	p.scale_amount_min = 6.0
	p.scale_amount_max = 9.0
	var colors := Gradient.new()
	colors.set_color(0, Color("e8862a"))
	colors.set_color(1, Color("f5c542"))
	p.color_initial_ramp = colors
	add_child(p)


func _draw() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color("2f5a33"))
	# Trees peeking over the camp wall
	for i in 11:
		Scenery.tree(self, Vector2(i * 130 - 10, 150), 0.9 + (i % 3) * 0.12, Color("3d6b3f"))
	# Sandy clearing in the middle
	draw_colored_polygon(Fx.ellipse_points(Vector2(640, 440), Vector2(610, 320), 48), Color("8fae5a"))
	draw_colored_polygon(Fx.ellipse_points(Vector2(640, 450), Vector2(560, 280), 48), Color("c9b27a"))
	for d in _decor:
		var pos := Vector2(d.x, d.y)
		match int(d.z):
			0, 1: Scenery.grass_tuft(self, pos, Color("8fae5a"))
			2: draw_circle(pos, 4, Color("a8936a"))
			3: Scenery.flower(self, pos, Color("f7f2e8"))
	# Bramble wall around the camp, with a gap for the entrance at the bottom
	for i in 64:
		var a := TAU * i / 64.0
		if absf(a - PI / 2) < 0.12:
			continue
		var p := Vector2(640, 440) + Vector2(cos(a) * 640, sin(a) * 335)
		draw_circle(p, 46, Color("2a4a2b"))
		draw_circle(p + Vector2(-6, -8), 36, Color("355e35"))
		if i % 3 == 0:
			draw_circle(p + Vector2(12, -14), 5, Color("e2445c"))
