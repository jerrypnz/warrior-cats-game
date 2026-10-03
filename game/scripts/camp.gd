extends Node2D
## ThunderClan's camp: the story's home base. Talk to the cat with the "!" to start the
## next chapter, and chat with your Clanmates in between.

const CLEARING := Rect2(120, 190, 1040, 490)  # the oval cats can walk in
const TALK_DISTANCE := 115.0
const NIGHT := Color("6d74b8")

var _world: Node2D
var _player: TopDownPlayer
var _dialog: DialogBox
var _npcs: Array[Npc] = []
var _name_label: Label
var _goal_label: Label
var _chapter_label: Label
var _night: CanvasModulate
var _busy := true  # true during cutscenes
var _decor: Array = []
var _doors: Array = []  # places to use: dens, the gorse tunnel, the fresh-kill pile
var _door_prompt: Label
var _pile: CampProp
var _cinderpaw: Follower

const DENS := {
	"warriors": [Vector2(225, 345), "Warriors' Den"], "apprentices": [Vector2(1055, 345), "Apprentices' Den"],
	"nursery": [Vector2(250, 630), "Nursery"], "elders": [Vector2(1030, 630), "Elders' Den"],
	"medicine": [Vector2(395, 262), "Medicine Den"],
}
const TUNNEL := Vector2(640, 668)


func _ready() -> void:
	seed(42)
	for i in 70:
		_decor.append(Vector3(randf_range(160, 1120), randf_range(220, 670), randi() % 4))
	randomize()

	_night = CanvasModulate.new()
	_night.color = NIGHT if GameState.current_id() == "rescue" else Color.WHITE
	add_child(_night)
	_world = Node2D.new()
	_world.y_sort_enabled = true
	add_child(_world)

	var rock: CampProp = _add_prop("high_rock", Vector2(640, 300), "Highrock")
	for key in DENS:
		var den: Array = DENS[key]
		_add_prop("medicine" if key == "medicine" else "den", den[0], den[1])
		_doors.append({"pos": den[0] + Vector2(0, 22), "prompt": "SPACE = go inside", "what": "den", "den": key})
	_pile = _add_prop("fresh_kill", Vector2(840, 470), "Fresh-kill Pile")
	_doors.append({"pos": Vector2(840, 492), "prompt": "SPACE = look", "what": "pile"})
	_doors.append({"pos": TUNNEL, "prompt": "SPACE = leave camp", "what": "tunnel"})

	_player = TopDownPlayer.new()
	_player.position = Vector2(560, 560) if GameState.met_clan else Vector2(560, 450)
	if GameState.just_finished == "den" and DENS.has(GameState.den):
		_player.position = DENS[GameState.den][0] + Vector2(0, 45)
	elif GameState.just_finished in ["free_hunt", "teach_battle"]:
		_player.position = TUNNEL + Vector2(0, -40)
	_player.bounds = CLEARING
	_player.round_bounds = true
	_world.add_child(_player)
	for prop in _world.get_children():
		if prop is CampProp:
			_player.blockers.append(prop.footprint())

	# Bluestar stands on top of the Highrock
	var bluestar := Npc.make("Bluestar")
	bluestar.position = Vector2(-10, -136)
	bluestar.talk_spot = Vector2(0, 175)
	bluestar.bubble_offset = Vector2(-105, 100)
	rock.add_child(bluestar)
	_npcs.append(bluestar)

	_add_npc("Tigerclaw", Vector2(620, 380), Rect2(560, 360, 160, 50))
	_add_npc("Lionheart", Vector2(340, 470))
	_add_npc("Longtail", Vector2(190, 500), Rect2(170, 480, 70, 60))
	_add_npc("Spottedleaf", Vector2(300, 300))
	_add_npc("Graypaw", Vector2(900, 420), Rect2(860, 400, 110, 60))
	_add_npc("Ravenpaw", Vector2(1110, 470), Rect2(), -1.0)
	_add_npc("Sandpaw", Vector2(730, 615))
	_add_npc("Dustpaw", Vector2(815, 618), Rect2(), -1.0)
	_add_npc("Smallear", Vector2(920, 560), Rect2(), -1.0)
	if GameState.step > 7 or GameState.just_finished == "yellowfang":
		_add_npc("Yellowfang", Vector2(470, 330))
	_add_npc("Frostfur", Vector2(380, 640))
	if GameState.current_id() != "rescue" or GameState.just_finished == "yellowfang":
		for kit in ["Brightkit"] if GameState.has_apprentice else ["Cinderkit", "Brightkit"]:
			var npc := _add_npc(kit, Vector2(450, 600), Rect2(400, 560, 150, 70))
			npc.speed = 120.0
			npc.hops = true

	if GameState.has_apprentice:
		_add_cinderpaw()

	_door_prompt = Fx.make_label("", 22, Color("c9f7a8"), 6)
	_door_prompt.size = Vector2(260, 30)
	_door_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_door_prompt.z_index = 10
	add_child(_door_prompt)
	_dialog = DialogBox.new()
	add_child(_dialog)
	_make_hud()
	_add_falling_leaves()
	_enter_camp.call_deferred()


func _add_prop(kind: String, pos: Vector2, label: String) -> CampProp:
	var prop := CampProp.new().setup(kind, label)
	prop.position = pos
	_world.add_child(prop)
	return prop


func _add_npc(cat_name: String, pos: Vector2, wander := Rect2(), face := 1.0) -> Npc:
	var npc := Npc.make(cat_name, face)
	npc.position = pos
	npc.wander_area = wander
	npc.rename(Story.display_name(cat_name))
	_world.add_child(npc)
	_npcs.append(npc)
	return npc


func _add_cinderpaw() -> void:
	_cinderpaw = Follower.make("Cinderkit", _player, 90.0)
	_cinderpaw.cat.size = 0.72
	_world.add_child(_cinderpaw)


func _find(cat_name: String) -> Npc:
	for npc in _npcs:
		if npc.npc_name == cat_name:
			return npc
	return null


func _remove(cat_name: String) -> void:
	var npc := _find(cat_name)
	if npc:
		_npcs.erase(npc)
		npc.queue_free()


# --- talking -------------------------------------------------------------------------------

func _process(_delta: float) -> void:
	if _busy or _dialog.is_open() or Transition.is_busy():
		_player.frozen = true
		for npc in _npcs:
			npc.show_prompt(false)
		_door_prompt.visible = false
		return
	_player.frozen = false
	var nearest: Npc = null
	var best := TALK_DISTANCE
	for npc in _npcs:
		var d := npc.talk_position().distance_to(_player.global_position)
		if d < best:
			best = d
			nearest = npc
	# Is Cinderpaw, a den, the tunnel or the fresh-kill pile closer than any cat?
	var door := {}
	var door_best := 70.0
	for d in _doors:
		if d.pos.distance_to(_player.position) < door_best:
			door_best = d.pos.distance_to(_player.position)
			door = d
	if _cinderpaw and _cinderpaw.position.distance_to(_player.position) < 80.0:
		door = {"pos": _cinderpaw.position, "prompt": "SPACE = talk", "what": "cinderpaw"}
		door_best = 0.0
	if nearest and best <= door_best:
		door = {}
	else:
		nearest = null
	for npc in _npcs:
		npc.show_prompt(npc == nearest)
	if nearest:
		_door_prompt.visible = false
		if Input.is_action_just_pressed("jump"):
			_talk(nearest)
		return
	_door_prompt.visible = not door.is_empty()
	if door.is_empty():
		return
	_door_prompt.text = door.prompt
	_door_prompt.position = door.pos + Vector2(-130, 8)
	if Input.is_action_just_pressed("jump"):
		_use_door(door)


func _use_door(door: Dictionary) -> void:
	match door.what:
		"den":
			Sfx.play("click")
			GameState.den = door.den
			Transition.go("res://scenes/den.tscn")
		"pile":
			var amount := "No prey yet. Let's go hunting!" if GameState.fresh_kill == 0 else \
					"%d pieces of prey! The Clan won't go hungry." % GameState.fresh_kill
			_dialog.say([["Fresh-kill Pile", amount]])
		"tunnel":
			if not GameState.is_warrior():
				_dialog.say([["", "Apprentices can't leave camp without their mentor. Talk to Bluestar!"]])
				return
			_busy = true
			_dialog.ask(GameState.cat_name(), "Go hunting in the forest?", ["Let's go!", "Not now"])
			var pick: int = await _dialog.chosen
			_busy = false
			if pick == 0:
				GameState.start_activity("free_hunt")
		"cinderpaw":
			_busy = true
			_cinderpaw.cat.bounce(0.3)
			_dialog.ask("Cinderpaw", Story.CINDERPAW_CHATS.pick_random() + " What should we do?",
					["Go hunting!", "Battle practice!", "Just saying hi!"])
			var pick: int = await _dialog.chosen
			_busy = false
			if pick == 0:
				GameState.start_activity("free_hunt")
			elif pick == 1:
				GameState.start_activity("teach_battle")
			else:
				Fx.hearts(self, _cinderpaw.position + Vector2(0, -60), 8)


func _talk(npc: Npc) -> void:
	npc.face_toward(_player.global_position)
	_player.cat.facing = signf(npc.global_position.x - _player.global_position.x)
	Sfx.play("select")
	if npc.npc_name == "Bluestar" and GameState.is_warrior() and not GameState.has_apprentice:
		_apprentice_ceremony()
		return
	if npc.npc_name == GameState.current().get("from_camp", ""):
		_busy = true
		_dialog.say(Story.lines(Story.START_LINES[GameState.current_id()]))
		await _dialog.finished
		GameState.start_step()
		return
	var chats: Dictionary = Story.CHATS
	if GameState.is_warrior() and Story.WARRIOR_CHATS.has(npc.npc_name):
		chats = Story.WARRIOR_CHATS
	var options: Array = chats.get(npc.npc_name, Story.CHATS.Graypaw)
	_dialog.say(Story.lines([[npc.npc_name, options.pick_random()]]))


# --- cutscenes -----------------------------------------------------------------------------

func _enter_camp() -> void:
	_busy = true
	_update_hud()
	if not GameState.met_clan:
		await get_tree().create_timer(0.6).timeout
		_dialog.say(Story.lines(Story.JOIN_LINES))
		await _dialog.finished
		GameState.met_clan = true
		_player.name_label.text = GameState.cat_name()
		_name_label.text = GameState.cat_name()
		await _cheer(GameState.apprentice_name())
		_dialog.say(Story.lines(Story.JOIN_AFTER_LINES))
		await _dialog.finished
	elif Story.RETURN_LINES.has(GameState.just_finished):
		if GameState.just_finished == "ceremony":
			_cheer(GameState.cat_name())
		await _play_return(Story.lines(Story.RETURN_LINES[GameState.just_finished]))
	elif GameState.just_finished == "free_hunt":
		_pile.queue_redraw()
		_dialog.say(Story.lines([["Smallear", "Fresh-kill! Thank you, {me}! The whole Clan will eat well tonight."]]))
		await _dialog.finished
	elif GameState.just_finished == "teach_battle":
		_dialog.say(Story.lines([["Cinderpaw", "That was SO fun! I'm getting better every day, right?"]]))
		await _dialog.finished
	GameState.just_finished = ""
	GameState.save_game()
	_busy = false
	_update_hud()


## Bluestar makes Cinderkit an apprentice, and you are her mentor!
func _apprentice_ceremony() -> void:
	_busy = true
	_update_hud()
	_dialog.say(Story.lines([
		["Bluestar", "{me}, you have become a fine warrior. Now it's time for you to teach others."],
		["Bluestar", "Cinderkit, come forward. You are old enough to become an apprentice!"],
		["Cinderkit", "Really?! YAY!"],
		["Bluestar", "From this day on, she will be known as Cinderpaw. {me}, you will be her mentor!"],
		["Bluestar", "Teach her everything you know: hunting, battle moves, and the warrior code."],
	]))
	await _dialog.finished
	var kit := _find("Cinderkit")
	if kit:
		kit.wander_area = Rect2()
		kit.hops = false
		await kit.walk_to(_player.position + Vector2(-90, 10), 200.0)
		_remove("Cinderkit")
	GameState.has_apprentice = true
	GameState.save_game()
	_add_cinderpaw()
	_cinderpaw.cat.bounce(0.4)
	Sfx.play("powerup")
	Fx.confetti(self, _cinderpaw.position + Vector2(0, -80), 60)
	await _cheer("Cinderpaw")
	_dialog.say(Story.lines([["Cinderpaw", "You're my mentor? This is the BEST day ever! Talk to me whenever you want to train!"]]))
	await _dialog.finished
	_busy = false
	_update_hud()


## Plays the "welcome back" talk. A line with no speaker that starts "That night" makes the
## camp go dark before the rest of the talk.
func _play_return(lines: Array) -> void:
	var split := lines.size()
	for i in lines.size():
		if lines[i][0] == "" and lines[i][1].begins_with("That night"):
			split = i
	_dialog.say(lines.slice(0, split))
	await _dialog.finished
	if split >= lines.size():
		return
	var dark := create_tween()
	dark.tween_property(_night, "color", NIGHT, 1.2)
	await dark.finished
	for missing in ["Yellowfang", "Cinderkit", "Brightkit"]:
		_remove(missing)
	_dialog.say(lines.slice(split))
	await _dialog.finished


func _cheer(cat_name: String) -> void:
	Sfx.play("win")
	for i in 2:
		for npc in _npcs:
			Fx.popup_text(self, npc.global_position + Vector2(0, -130), cat_name + "!", Color("ffd966"), 26)
			npc.cat.bounce(0.25)
		Fx.hearts(self, _player.global_position + Vector2(0, -60), 8)
		await get_tree().create_timer(0.6).timeout


# --- HUD -----------------------------------------------------------------------------------

func _make_hud() -> void:
	var hud := CanvasLayer.new()
	hud.layer = 5
	add_child(hud)
	var panel := Panel.new()
	panel.position = Vector2(12, 10)
	panel.size = Vector2(360, 118)
	panel.add_theme_stylebox_override("panel", Fx.cute_panel(18))
	hud.add_child(panel)
	_name_label = Fx.ink_label(GameState.cat_name(), 32, Fx.PINK_DARK)
	_name_label.position = Vector2(18, 6)
	panel.add_child(_name_label)
	_chapter_label = Fx.ink_label("", 20)
	_chapter_label.position = Vector2(18, 50)
	_chapter_label.size = Vector2(330, 60)
	_chapter_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(_chapter_label)
	_goal_label = Fx.centered_label("", 26, Color("fff6ec"), 680, 1280)
	hud.add_child(_goal_label)


func _update_hud() -> void:
	var story_cat: String = GameState.current().get("from_camp", "")
	for npc in _npcs:
		npc.has_news = not _busy and npc.npc_name == story_cat
	if GameState.is_warrior() and not GameState.has_apprentice:
		for npc in _npcs:
			npc.has_news = not _busy and npc.npc_name == "Bluestar"
		_chapter_label.text = "%s Warrior\nBluestar has news!" % GameState.CLAN
		_goal_label.text = "Bluestar wants to talk to you! (look for the yellow !)"
	elif GameState.is_warrior():
		_chapter_label.text = "%s Warrior\nCinderpaw's lessons: %d" % [GameState.CLAN, GameState.apprentice_lessons]
		_goal_label.text = "Talk to Cinderpaw to train her, go hunting through the tunnel, or visit the dens!"
	else:
		var title: String = GameState.current().get("title", "")
		_chapter_label.text = "%s Apprentice\nNext: %s" % [GameState.CLAN, title.get_slice(": ", 1)]
		var where := " by the Highrock" if story_cat == "Bluestar" else ""
		_goal_label.text = "Talk to %s%s (look for the yellow !)" % [story_cat, where]


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
	colors.set_color(0, Color("ffb3c8"))
	colors.set_color(1, Color("ffd6a5"))
	p.color_initial_ramp = colors
	add_child(p)


func _draw() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color("5f9e4f"))
	# Trees on top of the ravine
	for i in 11:
		Scenery.tree(self, Vector2(i * 130 - 10, 150), 0.9 + (i % 3) * 0.12, Color("7cc26a"), Color("a0704e"))
	# The sandy clearing at the bottom of the ravine
	draw_colored_polygon(Fx.ellipse_points(Vector2(640, 440), Vector2(610, 320), 48), Color("a8d88a"))
	draw_colored_polygon(Fx.ellipse_points(Vector2(640, 450), Vector2(560, 280), 48), Color("f3dfb5"))
	for d in _decor:
		var pos := Vector2(d.x, d.y)
		match int(d.z):
			0, 1: Scenery.grass_tuft(self, pos, Color("a8d88a"))
			2: draw_circle(pos, 4, Color("dcc69a"))
			3: Scenery.flower(self, pos, Color("ffb3c8"))
	# Gorse wall around the camp (prickly bushes with yellow flowers), with the gorse tunnel at the bottom
	for i in 64:
		var a := TAU * i / 64.0
		if absf(a - PI / 2) < 0.12:
			continue
		var p := Vector2(640, 440) + Vector2(cos(a) * 640, sin(a) * 335)
		draw_circle(p, 46, Color("4f8f45"))
		draw_circle(p + Vector2(-6, -8), 36, Color("62a554"))
		if i % 2 == 0:
			draw_circle(p + Vector2(12, -14), 6, Color("ffd23f"))
			draw_circle(p + Vector2(-14, 4), 5, Color("ffd23f"))
