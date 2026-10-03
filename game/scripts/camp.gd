extends Node2D
## ThunderClan's camp: the story's home base. Talk to the cat with the "!" to start the
## next chapter, and chat with your Clanmates in between. After the story, the "!" brings
## big news: your own apprentice, becoming deputy, leader or the Clan's medicine cat.

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
var _doors: Array = []  # places to use: dens, the gorse tunnel, the fresh-kill pile, the Highrock
var _door_prompt: Label
var _pile: CampProp
var _cinderpaw: Follower
var _camera: Camera2D

const DENS := {
	"warriors": [Vector2(225, 345), "Warriors' Den"], "apprentices": [Vector2(1055, 345), "Apprentices' Den"],
	"nursery": [Vector2(250, 630), "Nursery"], "elders": [Vector2(1030, 630), "Elders' Den"],
	"medicine": [Vector2(395, 262), "Medicine Den"],
}
const TUNNEL := Vector2(640, 668)
const HIGHROCK := Vector2(640, 300)
const HIGHROCK_TOP := Vector2(630, 184)  # where the leader stands to talk to the Clan
const MEETING_SPOT := Vector2(630, 352)  # stand here to climb the Highrock
const FROM_TUNNEL := ["free_hunt", "teach_battle", "gather_herbs", "lead_patrol", "nine_lives"]


func _ready() -> void:
	seed(42)
	for i in 70:
		_decor.append(Vector3(randf_range(160, 1120), randf_range(220, 670), randi() % 4))
	randomize()

	_camera = Camera2D.new()
	_camera.position = Vector2(640, 360)
	add_child(_camera)
	_night = CanvasModulate.new()
	_night.color = NIGHT if GameState.current_id() == "rescue" else Color.WHITE
	add_child(_night)
	_world = Node2D.new()
	_world.y_sort_enabled = true
	add_child(_world)

	var rock: CampProp = _add_prop("high_rock", HIGHROCK, "Highrock")
	for key in DENS:
		var den: Array = DENS[key]
		_add_prop("medicine" if key == "medicine" else "den", den[0], den[1])
		_doors.append({"pos": den[0] + Vector2(0, 22), "prompt": "SPACE = go inside", "what": "den", "den": key})
	_pile = _add_prop("fresh_kill", Vector2(840, 470), "Fresh-kill Pile")
	_doors.append({"pos": Vector2(840, 492), "prompt": "SPACE = look", "what": "pile"})
	_doors.append({"pos": TUNNEL, "prompt": "SPACE = leave camp", "what": "tunnel"})
	if GameState.is_leader():
		_doors.append({"pos": MEETING_SPOT, "prompt": "SPACE = call a Clan meeting", "what": "highrock"})

	_player = TopDownPlayer.new()
	_player.position = Vector2(560, 560) if GameState.met_clan else Vector2(560, 450)
	if GameState.just_finished in ["den", "heal_clan"] and DENS.has(GameState.den):
		_player.position = DENS[GameState.den][0] + Vector2(0, 45)
	elif GameState.just_finished in FROM_TUNNEL:
		_player.position = TUNNEL + Vector2(0, -40)
	_player.bounds = CLEARING
	_player.round_bounds = true
	_world.add_child(_player)
	for prop in _world.get_children():
		if prop is CampProp:
			_player.blockers.append(prop.footprint())

	# Bluestar stands on top of the Highrock (until she retires to the elders' den)
	if not GameState.is_leader():
		var bluestar := Npc.make("Bluestar")
		bluestar.position = Vector2(-10, -136)
		bluestar.talk_spot = Vector2(0, 175)
		bluestar.bubble_offset = Vector2(-105, 100)
		rock.add_child(bluestar)
		_npcs.append(bluestar)

	_add_npc("Tigerclaw", Vector2(620, 380), Rect2(560, 360, 160, 50))
	if not GameState.rank in ["deputy", "leader"]:  # then Lionheart is resting in the elders' den
		_add_npc("Lionheart", Vector2(340, 470))
	_add_npc("Longtail", Vector2(190, 500), Rect2(170, 480, 70, 60))
	if GameState.rank != "head":
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
		if not GameState.has_apprentice:
			_add_kit("Cinderkit")
		if GameState.brightpaw_mentor == "":
			_add_kit("Brightkit")
		else:
			_add_npc("Brightpaw", Vector2(560, 520), Rect2(480, 480, 200, 80))
	if GameState.apprentice_graduated:
		_add_npc("Cinderpelt", Vector2(520, 430), Rect2(460, 410, 140, 60))
	if GameState.deputy_name == "Whitestorm":
		_add_npc("Whitestorm", Vector2(760, 400), Rect2(720, 380, 120, 50))

	if GameState.apprentice_following():
		_add_cinderpaw()

	_door_prompt = Fx.make_label("", 22, Color("c9f7a8"), 6)
	_door_prompt.size = Vector2(320, 30)
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


func _add_kit(kit_name: String) -> void:
	var npc := _add_npc(kit_name, Vector2(450, 600), Rect2(400, 560, 150, 70))
	npc.speed = 120.0
	npc.hops = true


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


## A cat walks off to the elders' den for a long rest
func _retire(cat_name: String) -> void:
	var npc := _find(cat_name)
	if npc == null:
		return
	npc.wander_area = Rect2()
	await npc.walk_to(DENS.elders[0] + Vector2(0, 30), 220.0)
	_remove(cat_name)


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
	_door_prompt.position = door.pos + Vector2(-160, 8)
	if Input.is_action_just_pressed("jump"):
		_use_door(door)


## Asks a question and waits for the answer (and stops you walking away meanwhile)
func _ask(speaker: String, question: String, answers: Array) -> int:
	_busy = true
	_dialog.ask(speaker, question, answers)
	var pick: int = await _dialog.chosen
	_busy = false
	return pick


func _use_door(door: Dictionary) -> void:
	var gs := GameState
	match door.what:
		"den":
			Sfx.play("click")
			gs.den = door.den
			Transition.go("res://scenes/den.tscn")
		"pile":
			var amount := "No prey yet. Let's go hunting!" if gs.fresh_kill == 0 else \
					"%d pieces of prey! The Clan won't go hungry." % gs.fresh_kill
			_dialog.say([["Fresh-kill Pile", amount]])
		"tunnel":
			if not gs.is_grown():
				_dialog.say([["", "Apprentices can't leave camp without their mentor. Talk to %s!" % gs.mentor()]])
			elif gs.is_medicine():
				var pick: int = await _ask(gs.cat_name(), "Go and gather herbs in the forest?", ["Let's go!", "Not now"])
				if pick == 0:
					gs.start_activity("gather_herbs")
			elif gs.rank in ["deputy", "leader"]:
				var pick: int = await _ask(gs.cat_name(), "Which patrol will you lead?",
						["Hunting patrol!", "Border patrol!", "Not now"])
				if pick < 2:
					gs.start_activity(["free_hunt", "lead_patrol"][pick])
			else:
				var pick: int = await _ask(gs.cat_name(), "Go hunting in the forest?", ["Let's go!", "Not now"])
				if pick == 0:
					gs.start_activity("free_hunt")
		"cinderpaw":
			_cinderpaw.cat.bounce(0.3)
			if gs.is_medicine():
				var pick := await _ask("Cinderpaw", Story.CINDERPAW_MEDICINE_CHATS.pick_random() + " What should we do?",
						["Gather herbs!", "Help sick cats!", "Just saying hi!"])
				if pick < 2:
					gs.start_activity(["gather_herbs", "heal_clan"][pick])
				else:
					Fx.hearts(self, _cinderpaw.position + Vector2(0, -60), 8)
			else:
				var pick := await _ask("Cinderpaw", Story.CINDERPAW_CHATS.pick_random() + " What should we do?",
						["Go hunting!", "Battle practice!", "Just saying hi!"])
				if pick < 2:
					gs.start_activity(["free_hunt", "teach_battle"][pick])
				else:
					Fx.hearts(self, _cinderpaw.position + Vector2(0, -60), 8)
		"highrock":
			_clan_meeting()


func _talk(npc: Npc) -> void:
	npc.face_toward(_player.global_position)
	_player.cat.facing = signf(npc.global_position.x - _player.global_position.x)
	Sfx.play("select")
	var news := GameState.waiting_news()
	if not news.is_empty() and npc.npc_name == news[1]:
		_big_news(news[0])
		return
	if npc.npc_name == GameState.current().get("from_camp", ""):
		_busy = true
		_dialog.say(Story.start_lines(GameState.current_id()))
		await _dialog.finished
		GameState.start_step()
		return
	_dialog.say([[npc.npc_name, Story.chat(npc.npc_name)]])


# --- cutscenes -----------------------------------------------------------------------------

func _enter_camp() -> void:
	_busy = true
	_update_hud()
	var back := GameState.just_finished
	if not GameState.met_clan:
		await _join_clan()
	elif back == "nine_lives":
		await _welcome_leader()
	elif not Story.return_lines(back).is_empty():
		if back in ["ceremony", "medicine_ceremony"]:
			_cheer(GameState.cat_name())
		await _play_return(Story.return_lines(back))
	else:
		var line: Array = {
			"free_hunt": ["Smallear", "Fresh-kill! Thank you, {me}! The whole Clan will eat well tonight."],
			"teach_battle": ["Cinderpaw", "That was SO fun! I'm getting better every day, right?"],
			"gather_herbs": ["Yellowfang", "Hmph. Fresh herbs! Good work, {me}. The medicine den smells lovely."],
			"heal_clan": ["Smallear", "Everyone feels so much better! Thank you, {me}!"],
			"lead_patrol": ["Graystripe", "What a great patrol! You're a natural leader, {me}!"],
		}.get(back, [])
		if not line.is_empty():
			_dialog.say(Story.lines([line]))
			await _dialog.finished
		if GameState.rank == "deputy" and back in ["free_hunt", "lead_patrol"]:
			Fx.popup_text(self, _player.position + Vector2(0, -150),
					"Patrols led: %d / %d" % [mini(GameState.deputy_tasks, GameState.DEPUTY_TASKS), GameState.DEPUTY_TASKS],
					Color("ffd966"), 30)
	GameState.just_finished = ""
	GameState.save_game()
	_busy = false
	_update_hud()


## Your first time in camp: choose to be a warrior or a medicine cat, and get your apprentice name
func _join_clan() -> void:
	await get_tree().create_timer(0.6).timeout
	_dialog.say(Story.lines(Story.JOIN_LINES))
	await _dialog.finished
	_dialog.ask("Bluestar", Story.fill(Story.JOIN_QUESTION), Story.JOIN_ANSWERS)
	var pick: int = await _dialog.chosen
	GameState.path = "medicine" if pick == 1 else "warrior"
	_dialog.say(Story.lines(Story.JOIN_NAMED_LINES[GameState.path]))
	await _dialog.finished
	GameState.met_clan = true
	GameState.save_game()
	_player.name_label.text = GameState.cat_name()
	_name_label.text = GameState.cat_name()
	_update_hud()
	await _cheer(GameState.apprentice_name())
	_dialog.say(Story.lines(Story.JOIN_AFTER_LINES[GameState.path]))
	await _dialog.finished


## Big news after the story: Cinderpaw, Cinderpelt, deputy, leader or head medicine cat
func _big_news(news: String) -> void:
	_busy = true
	_update_hud()
	match news:
		"apprentice":
			await _apprentice_ceremony()
		"graduate":
			_dialog.say(Story.lines(Story.NEWS_LINES.graduate))
			await _dialog.finished
			GameState.apprentice_graduated = true
			GameState.save_game()
			var spot := _cinderpaw.position
			_cinderpaw.queue_free()
			_cinderpaw = null
			var pelt := _add_npc("Cinderpelt", spot, Rect2(460, 410, 140, 60))
			pelt.cat.bounce(0.5)
			Sfx.play("powerup")
			Fx.confetti(self, spot + Vector2(0, -80), 60)
			await _cheer("Cinderpelt")
			_dialog.say(Story.lines(Story.NEWS_LINES.graduate_after))
			await _dialog.finished
		"deputy":
			_dialog.say(Story.lines(Story.NEWS_LINES.deputy))
			await _dialog.finished
			GameState.rank = "deputy"
			GameState.save_game()
			_retire("Lionheart")
			await _cheer(GameState.cat_name())
			_dialog.say(Story.lines(Story.NEWS_LINES.deputy_after))
			await _dialog.finished
		"head":
			_dialog.say(Story.lines(Story.NEWS_LINES.head))
			await _dialog.finished
			GameState.rank = "head"
			GameState.save_game()
			_retire("Spottedleaf")
			await _cheer(GameState.cat_name())
			_dialog.say(Story.lines(Story.NEWS_LINES.head_after))
			await _dialog.finished
		"leader":
			_dialog.say(Story.lines(Story.NEWS_LINES.leader))
			await _dialog.finished
			GameState.start_activity("nine_lives")
			return
	_busy = false
	_update_hud()


## Bluestar makes Cinderkit an apprentice, and you are her mentor!
func _apprentice_ceremony() -> void:
	var job := "medicine cat apprentice" if GameState.is_medicine() else "apprentice"
	_dialog.say(Story.lines([
		["Bluestar", "{me}, you have grown so much. Now it's time for you to teach others."],
		["Bluestar", "Cinderkit, come forward. You are old enough to become an %s!" % job],
		["Cinderkit", "Really?! YAY!"],
		["Bluestar", "From this day on, she will be known as Cinderpaw. {me}, you will be her mentor!"],
		["Bluestar", "Teach her everything you know about herbs and healing." if GameState.is_medicine()
				else "Teach her everything you know: hunting, battle moves, and the warrior code."],
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


## Home from the Moonstone with nine lives! Now pick a deputy.
func _welcome_leader() -> void:
	await get_tree().create_timer(0.4).timeout
	_cheer(GameState.leader_name())
	_dialog.say(Story.lines(Story.NEWS_LINES.nine_lives))
	await _dialog.finished
	if GameState.deputy_name == "":
		_dialog.ask(GameState.cat_name(), "Who will be my deputy?", Story.DEPUTY_CHOICES)
		GameState.deputy_name = Story.DEPUTY_CHOICES[await _dialog.chosen]
		GameState.save_game()
		_dialog.say(Story.lines([[GameState.cat_name(), "I say these words before StarClan: {deputy} will be the new deputy of ThunderClan!"]]))
		await _dialog.finished
		if _find(GameState.deputy_name) == null:
			_add_npc(GameState.deputy_name, Vector2(760, 400), Rect2(720, 380, 120, 50))
		var deputy := _find(GameState.deputy_name)
		deputy.cat.bounce(0.5)
		Fx.confetti(self, deputy.position + Vector2(0, -80), 50)
		await _cheer(GameState.deputy_name)
		_dialog.say(Story.lines([[GameState.deputy_name, "Me?! Thank you, {me}! I won't let you down!"],
				["", "Climb up to the Highrock any time to call a Clan meeting!"]]))
		await _dialog.finished


## The leader climbs the Highrock and talks to the whole Clan
func _clan_meeting() -> void:
	_busy = true
	var answers := ["Cheer for the Clan!", "Not now"]
	if GameState.brightpaw_mentor == "":
		answers.push_front("Make Brightkit an apprentice!")
	var pick := await _ask(GameState.cat_name(), "Call a Clan meeting?", answers)
	if answers[pick] == "Not now":
		return
	_busy = true
	_player.z_index = 5  # stand in front of the rock
	var climb := create_tween()
	climb.tween_property(_player, "position", HIGHROCK_TOP, 0.5).set_trans(Tween.TRANS_BACK)
	await climb.finished
	_player.cat.facing = 1.0
	Sfx.play("jump")
	_dialog.say(Story.lines([["{me}", "Let all cats old enough to catch their own prey gather beneath the Highrock!"]]))
	await _dialog.finished
	if answers[pick] == "Cheer for the Clan!":
		_dialog.say(Story.lines([["{me}", "ThunderClan, you are the bravest, kindest Clan in the whole forest!"]]))
		await _dialog.finished
		Fx.shake(_camera, 8.0, 0.4)
		await _cheer("ThunderClan")
		await _cheer(GameState.cat_name())
	else:
		_dialog.say(Story.lines([["{me}", "Brightkit, come forward. From this day on, you will be known as Brightpaw!"]]))
		await _dialog.finished
		_dialog.ask(GameState.cat_name(), "Who should be Brightpaw's mentor?", Story.DEPUTY_CHOICES)
		GameState.brightpaw_mentor = Story.DEPUTY_CHOICES[await _dialog.chosen]
		GameState.save_game()
		var spot := Vector2(560, 520)
		var kit := _find("Brightkit")
		if kit:
			spot = kit.position
			_remove("Brightkit")
		var paw := _add_npc("Brightpaw", spot, Rect2(480, 480, 200, 80))
		paw.cat.bounce(0.5)
		Fx.confetti(self, spot + Vector2(0, -60), 50)
		_dialog.say([[GameState.brightpaw_mentor, "I'll teach Brightpaw everything I know!"],
				["Brightpaw", "Yippee! I'm an apprentice!"]])
		await _dialog.finished
		await _cheer("Brightpaw")
	var down := create_tween()
	down.tween_property(_player, "position", MEETING_SPOT + Vector2(0, 30), 0.5)
	await down.finished
	_player.z_index = 0
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
	panel.size = Vector2(380, 118)
	panel.add_theme_stylebox_override("panel", Fx.cute_panel(18))
	hud.add_child(panel)
	_name_label = Fx.ink_label(GameState.cat_name(), 32, Fx.PINK_DARK)
	_name_label.position = Vector2(18, 6)
	panel.add_child(_name_label)
	_chapter_label = Fx.ink_label("", 20)
	_chapter_label.position = Vector2(18, 50)
	_chapter_label.size = Vector2(350, 60)
	_chapter_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(_chapter_label)
	_goal_label = Fx.centered_label("", 26, Color("fff6ec"), 680, 1280)
	hud.add_child(_goal_label)


func _update_hud() -> void:
	var gs := GameState
	var news := gs.waiting_news()
	var news_cat: String = news[1] if not news.is_empty() else gs.current().get("from_camp", "")
	for npc in _npcs:
		npc.has_news = not _busy and npc.npc_name == news_cat
	_name_label.text = gs.cat_name()
	var detail := ""
	var goal := ""
	if not gs.is_grown():
		var title: String = gs.current().get("title", "")
		detail = "Next: " + title.get_slice(": ", 1)
		var where := " by the Highrock" if news_cat == "Bluestar" else ""
		goal = "Talk to %s%s (look for the yellow !)" % [news_cat, where]
	elif not news.is_empty():
		detail = "%s has news!" % news_cat
		goal = "%s wants to talk to you! (look for the yellow !)" % news_cat
	elif gs.apprentice_following():
		detail = "Cinderpaw's lessons: %d / %d" % [gs.apprentice_lessons, gs.LESSONS_NEEDED]
		goal = "Talk to Cinderpaw to gather herbs or help sick cats together!" if gs.is_medicine() else \
				"Talk to Cinderpaw to train her, go hunting through the tunnel, or visit the dens!"
	elif gs.rank == "deputy":
		detail = "Patrols led: %d / %d" % [gs.deputy_tasks, gs.DEPUTY_TASKS]
		goal = "Lead patrols out of the gorse tunnel at the bottom of camp!"
	elif gs.is_leader():
		detail = "Deputy: %s" % gs.deputy_name
		goal = "Walk up to the Highrock to call a Clan meeting, or lead patrols through the tunnel!"
	else:
		detail = "Herbs, healing and StarClan dreams"
		goal = "Help sick cats in the Medicine Den, or gather herbs through the tunnel!"
	_chapter_label.text = "%s\n%s" % [gs.rank_title(), detail]
	_goal_label.text = goal


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
