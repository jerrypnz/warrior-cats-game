extends Node2D
## Helping sick cats: a Clanmate tells you what's wrong, and you give them the right herb
## from the shelf. LEFT/RIGHT = choose a herb, SPACE = give it. Clicking a herb works too.
## Used for Spottedleaf's healing lesson, for helping hurt Yellowfang, and later on whenever
## you like (from the medicine den, or with Cinderpaw).

const NEST := Vector2(700, 430)
const SHELF_Y := 640.0
const SHELF := ["Marigold", "Catmint", "Poppy Seeds", "Cobwebs", "Watermint", "Honey"]
const CLANMATES := ["Smallear", "Longtail", "Mousefur", "Halftail", "Darkstripe", "Dustpaw", "Sandpaw",
		"Ravenpaw", "Frostfur", "Whitestorm", "One-eye", "Patchpelt"]

const SETUPS := {
	"healing_lesson": {
		"place": "den", "watcher": "Spottedleaf",
		"patients": [["Smallear", ["Watermint"]], ["Longtail", ["Marigold"]], ["Mousefur", ["Catmint"]],
				["Halftail", ["Poppy Seeds"]]],
		"intro": "Some Clanmates are feeling poorly. Listen to what's wrong, then give them the right herb!\n\nLEFT/RIGHT = choose a herb    SPACE = give it",
	},
	"yellowfang": {
		"place": "snakerocks", "watcher": "", "stays": true,
		"patients": [["Yellowfang", ["Cobwebs", "Marigold", "Poppy Seeds"]]],
		"problems": {"Cobwebs": "Ouch! My leg has a nasty cut from a thorn.", "Marigold": "And I'm covered in scratches. Grrr.",
				"Poppy Seeds": "Now I'm SO tired... but my leg hurts too much to sleep."},
		"intro": "You're near Snakerocks, looking for the hurt cat from Spottedleaf's dream.\n\nLEFT/RIGHT = choose a herb    SPACE = give it",
		"before": [["Yellowfang", "Grrr! Who's there?! Stay back, ThunderClan cat!"],
				["{paw}", "You're hurt! I'm a medicine cat apprentice. Let me help you!"],
				["Yellowfang", "Hmph. I'm Yellowfang. I used to live in ShadowClan. Fine, help me... but be quick about it!"]],
		"outro": [["Yellowfang", "Hmph... my leg feels better already. You're a good healer, young one."],
				["Bluestar", "{paw}! Who is this? A ShadowClan cat in our territory?"],
				["{paw}", "She's hurt, Bluestar. Please, can she come back to camp? Spottedleaf can look after her."],
				["Bluestar", "Helping a cat in need... that's what ThunderClan cats do. Very well, Yellowfang may come."]],
	},
	"heal_clan": {
		"place": "den", "watcher": "", "random": 4,
		"intro": "Your Clanmates need you! Listen to what's wrong, then give them the right herb.\n\nLEFT/RIGHT = choose a herb    SPACE = give it",
	},
}

var _setup: Dictionary
var _world: Node2D
var _player: Cat
var _watcher: Npc  # Spottedleaf, or Cinderpaw when she's your apprentice
var _patient: Npc
var _queue: Array = []  # [cat name, [herbs it needs]]
var _needs: Array = []  # herbs the patient here still needs
var _healed := 0
var _total := 0
var _choice := 0
var _playing := false
var _waiting := false  # a herb is flying over
var _card: InfoCard
var _dialog: DialogBox
var _problem_label: Label
var _problem_panel: Panel
var _score_label: Label
var _herb_buttons: Array[Button] = []
var _camera: Camera2D
var _time := 0.0


func _ready() -> void:
	_setup = SETUPS.get(GameState.current_id(), SETUPS.healing_lesson)
	_camera = Camera2D.new()
	_camera.position = Vector2(640, 360)
	add_child(_camera)
	_world = Node2D.new()
	_world.y_sort_enabled = true
	add_child(_world)

	_player = GameState.make_player_cat()
	_player.position = Vector2(480, 470)
	_world.add_child(_player)
	var my_label := Fx.make_label(GameState.cat_name(), 22, Color("ffd966"), 6)
	my_label.size = Vector2(300, 32)
	my_label.position = Vector2(-150, -112 * _player.size - 30)
	my_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_player.add_child(my_label)
	if _setup.watcher != "":
		_watcher = Npc.make(_setup.watcher)
		_watcher.position = Vector2(300, 400)
		_world.add_child(_watcher)
	elif GameState.apprentice_following():
		_watcher = Npc.make("Cinderkit")
		_watcher.rename("Cinderpaw")
		_watcher.cat.size = 0.72
		_watcher.position = Vector2(330, 470)
		_world.add_child(_watcher)

	if _setup.has("random"):
		var cats := CLANMATES.duplicate()
		cats.shuffle()
		for i in _setup.random:
			_queue.append([cats[i], [SHELF.pick_random()]])
	else:
		_queue = _setup.patients.duplicate(true)
	for p in _queue:
		_total += p[1].size()

	_make_hud()
	_dialog = DialogBox.new()
	add_child(_dialog)
	_card = InfoCard.new()
	add_child(_card)
	var title: String = "Helping Sick Cats!" if _setup.has("random") else GameState.current().get("title", "Healing!")
	_card.show_card(title, _setup.intro, "Press SPACE to start!")
	await _card.closed
	_next_patient()


func _make_hud() -> void:
	var hud := CanvasLayer.new()
	add_child(hud)
	_score_label = Fx.centered_label("", 34, Color.WHITE, 16)
	hud.add_child(_score_label)
	_update_score()
	_problem_panel = Panel.new()
	_problem_panel.position = Vector2(340, 70)
	_problem_panel.size = Vector2(600, 96)
	_problem_panel.add_theme_stylebox_override("panel", Fx.cute_panel(20))
	_problem_panel.visible = false
	hud.add_child(_problem_panel)
	_problem_label = Fx.ink_label("", 26)
	_problem_label.position = Vector2(20, 10)
	_problem_label.size = Vector2(560, 76)
	_problem_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_problem_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_problem_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_problem_panel.add_child(_problem_label)
	# The herb shelf: a row of buttons along the bottom
	for i in SHELF.size():
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.position = Vector2(100 + i * 185, SHELF_Y - 70)
		b.size = Vector2(170, 130)
		b.mouse_entered.connect(func():
			_choice = i
			_refresh_shelf())
		b.pressed.connect(func():
			_choice = i
			_give())
		hud.add_child(b)
		var art := HerbIcon.new()
		art.kind = SHELF[i]
		art.position = Vector2(85, 72)
		b.add_child(art)
		var label := Fx.ink_label(SHELF[i], 22)
		label.size = Vector2(170, 30)
		label.position = Vector2(0, 92)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.add_child(label)
		_herb_buttons.append(b)
	_refresh_shelf()


func _next_patient() -> void:
	if _queue.is_empty():
		_win()
		return
	var next: Array = _queue.pop_front()
	_needs = next[1].duplicate()
	if _patient == null or not _setup.has("stays"):
		_patient = Npc.make(next[0], -1.0)
		_patient.position = Vector2(1360, NEST.y)
		_world.add_child(_patient)
		await _patient.walk_to(NEST, 260.0)
	_patient.face_toward(_player.position)
	if _setup.has("before") and _healed == 0:
		_dialog.say(Story.lines(_setup.before))
		await _dialog.finished
	_show_problem()
	_playing = true


func _show_problem() -> void:
	var herb: String = _needs[0]
	var text: String = _setup.get("problems", {}).get(herb, HerbArt.HERBS[herb].problem)
	_problem_label.text = "%s: %s" % [_patient.npc_name, text]
	_problem_panel.visible = true
	_problem_panel.pivot_offset = _problem_panel.size / 2.0
	_problem_panel.scale = Vector2(0.7, 0.7)
	create_tween().tween_property(_problem_panel, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK)
	_patient.cat.bounce(0.2)


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()
	if not _playing or _waiting or _dialog.is_open() or _card.is_open():
		return
	if Input.is_action_just_pressed("move_right"):
		_choice = wrapi(_choice + 1, 0, SHELF.size())
		Sfx.play("click", 1.1, -4.0)
		_refresh_shelf()
	elif Input.is_action_just_pressed("move_left"):
		_choice = wrapi(_choice - 1, 0, SHELF.size())
		Sfx.play("click", 1.1, -4.0)
		_refresh_shelf()
	elif Input.is_action_just_pressed("jump") or Input.is_action_just_pressed("action"):
		_give()


func _refresh_shelf() -> void:
	for i in _herb_buttons.size():
		var on := i == _choice
		for state in ["normal", "hover", "pressed"]:
			_herb_buttons[i].add_theme_stylebox_override(state, Fx.panel_style(Color("fff0f5") if on else Fx.CREAM,
					Fx.PINK_DARK if on else Fx.PINK, 18, 6 if on else 3))


## Give the chosen herb to the patient
func _give() -> void:
	if not _playing or _waiting or _dialog.is_open():
		return
	_waiting = true
	var herb: String = SHELF[_choice]
	Sfx.play("select")
	_player.facing = 1.0
	_player.bounce(0.25)
	# The herb flies over to the patient
	var flying := HerbIcon.new()
	flying.kind = herb
	flying.position = _herb_buttons[_choice].position + Vector2(85, 60)
	flying.z_index = 20
	add_child(flying)
	var fly := create_tween()
	fly.tween_property(flying, "position", _patient.position + Vector2(0, -50), 0.45).set_trans(Tween.TRANS_SINE)
	await fly.finished
	flying.queue_free()
	if herb == _needs[0]:
		await _correct(herb)
	else:
		await _wrong()
	_waiting = false


func _correct(herb: String) -> void:
	_needs.pop_front()
	_healed += 1
	_update_score()
	Sfx.play("powerup")
	Fx.burst(self, _patient.position + Vector2(0, -50), Color("c9f7a8"), 24)
	Fx.hearts(self, _patient.position + Vector2(0, -60), 10)
	Fx.popup_text(self, _patient.position + Vector2(0, -150), ["All better!", "Thank you!", "Ahhh, much better!"].pick_random(),
			Color("ffd966"))
	_patient.cat.bounce(0.4)
	if _watcher:
		_watcher.cat.bounce(0.3)
		Fx.speech(_watcher, "Yes! %s!" % herb, 112 * _watcher.cat.size + 30, 1.6)
	_problem_panel.visible = false
	await get_tree().create_timer(1.1).timeout
	if not _needs.is_empty():
		_show_problem()
		return
	_playing = false
	if not _setup.has("stays"):
		var leaving := _patient
		_patient = null
		leaving.walk_to(Vector2(-120, NEST.y + 40), 260.0)
		get_tree().create_timer(2.0).timeout.connect(leaving.queue_free)
	_next_patient()


func _wrong() -> void:
	Sfx.play("click", 0.7)
	Fx.popup_text(self, _patient.position + Vector2(0, -150), "Hmm, not that one...", Color("fff6ec"), 26)
	_patient.cat.bounce(0.15)
	var hint: String = HerbArt.HERBS[_needs[0]].use
	if _watcher:
		_dialog.say([[_watcher.npc_name, "Hmm, let me think... " + hint]])
	else:
		_dialog.say([["", "You try to remember what Spottedleaf taught you... " + hint]])
	await _dialog.finished


func _update_score() -> void:
	_score_label.text = "Cats helped: %d / %d" % [_healed, _total] if not _setup.has("stays") else \
			"Herbs for %s: %d / %d" % [_setup.patients[0][0], _healed, _total]


func _win() -> void:
	_playing = false
	_problem_panel.visible = false
	Sfx.play("win")
	Fx.confetti(self, Vector2(640, 300), 80)
	await get_tree().create_timer(1.0).timeout
	if GameState.activity == "heal_clan":
		_card.show_card("Everyone's Better!", "You helped %d Clanmates feel better!\nWhat a wonderful medicine cat." % _total,
				"Press SPACE to go back to camp")
		await _card.closed
		GameState.finish_activity()
		return
	if _setup.has("outro"):
		var bluestar := Npc.make("Bluestar")
		bluestar.position = Vector2(-60, 470)
		_world.add_child(bluestar)
		await bluestar.walk_to(Vector2(200, 470))
		_dialog.say(Story.lines(_setup.outro))
		await _dialog.finished
	else:
		_dialog.say(Story.lines([["Spottedleaf", "You helped every cat, {paw}! I'm so proud of you."]]))
		await _dialog.finished
		_card.show_card("Wonderful Healing!", "You picked the right herb for every cat!\nSpottedleaf says you're a natural healer.",
				"Press SPACE to go back to camp")
		await _card.closed
	GameState.complete_step()


func _draw() -> void:
	if _setup.place == "snakerocks":
		Scenery.sky(self, Color("bfe6ff"), Color("fde7f0"), Rect2(0, 0, 1280, 260))
		for i in 9:
			Scenery.tree(self, Vector2(i * 160 - 20, 260), 0.75 + (i % 2) * 0.15, Color("6fb85a"), Color("a0704e"))
		draw_rect(Rect2(0, 250, 1280, 470), Color("a9cf80"))
		for p in [Vector2(820, 330), Vector2(980, 340), Vector2(900, 300)]:
			Scenery.rock(self, p, 1.6, Color("b8b4bd"))
		draw_string(ThemeDB.fallback_font, Vector2(800, 220), "Snakerocks", HORIZONTAL_ALIGNMENT_CENTER, 200, 26, Fx.INK)
	else:
		# Inside the medicine den: a cool, ferny cave
		var wall := Color("5f8a7a")
		draw_rect(Rect2(0, 0, 1280, 720), wall.darkened(0.45))
		for i in 40:
			var a := PI + PI * i / 39.0
			var p := Vector2(640, 560) + Vector2(cos(a) * 660, sin(a) * 470)
			draw_circle(p, 70, wall.darkened(0.15))
			draw_circle(p + Vector2(-8, -8), 50, wall)
		draw_colored_polygon(Fx.ellipse_points(Vector2(640, 470), Vector2(560, 200), 48), Color("c9a86a"))
		draw_colored_polygon(Fx.ellipse_points(Vector2(640, 475), Vector2(540, 185), 48), Color("e3c896"))
		for x in [380.0, 900.0]:
			draw_colored_polygon(PackedVector2Array([Vector2(x - 20, 60), Vector2(x + 20, 60), Vector2(x + 90, 560),
					Vector2(x - 10, 560)]), Color(1, 0.95, 0.7, 0.08))
	# The soft nest where the patient lies
	draw_colored_polygon(Fx.ellipse_points(NEST + Vector2(0, 4), Vector2(80, 28)), Color("4f8a45"))
	draw_colored_polygon(Fx.ellipse_points(NEST + Vector2(0, 2), Vector2(66, 21)), Color("7cc26a"))
	draw_colored_polygon(Fx.ellipse_points(NEST + Vector2(0, 4), Vector2(50, 14)), Color("9ed27c"))


class HerbIcon extends Node2D:
	## A herb picture (for the shelf and for flying over to the patient)
	var kind := ""

	func _draw() -> void:
		HerbArt.draw(self, Vector2.ZERO, kind, 1.3)
