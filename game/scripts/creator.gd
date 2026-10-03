extends Node2D
## Design your cat: fur, markings, eyes, the first part of your name, and personality.
## On the Name row, SPACE (or the "Type!" button) lets you type your very own name.

const ROWS := [
	{"title": "Fur", "key": "fur"},
	{"title": "Markings", "key": "markings"},
	{"title": "Pattern", "key": "pattern"},
	{"title": "Eyes", "key": "eyes"},
	{"title": "Fur Length", "key": "fluffy"},
	{"title": "Name", "key": "prefix"},
	{"title": "Personality", "key": "personality"},
	{"title": "Paint with a Brush!", "key": "paint"},
	{"title": "Surprise Me!", "key": "random"},
	{"title": "I'm Ready!", "key": "done"},
]

const BUTTONS := ["paint", "random", "done"]

var _selected := 0
var _cat: Cat
var _row_panels: Array[Panel] = []
var _row_values: Array[Label] = []
var _name_label: Label
var _about_label: Label
var _normal_style := Fx.panel_style(Color(1, 0.97, 0.93, 0.88), Color("f3c6d4"), 18, 3)
var _selected_style := Fx.panel_style(Color("fff0f5"), Fx.PINK_DARK, 18, 5)
var _time := 0.0
var _typing: NameEntry


func _ready() -> void:
	_cat = Cat.new()
	_cat.position = Vector2(300, 545)
	_cat.size = 3.2
	add_child(_cat)

	var ui := CanvasLayer.new()
	add_child(ui)
	ui.add_child(Fx.centered_label("Design Your Cat!", 44, Color("ffd966"), 18, 600))
	_name_label = Fx.centered_label("", 64, Color.WHITE, 90, 600)
	ui.add_child(_name_label)
	ui.add_child(Fx.centered_label("(your Clan name)", 26, Color("fff6ec"), 175, 600))
	_about_label = Fx.centered_label("", 26, Color("fff6ec"), 612, 600)
	_about_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_about_label.size.y = 80
	ui.add_child(_about_label)

	for i in ROWS.size():
		_add_row(ui, i)
	ui.add_child(Fx.centered_label("UP/DOWN = pick    LEFT/RIGHT = change    SPACE = next", 20,
			Color("fff6ec"), 676, 600))
	_typing = NameEntry.new()
	add_child(_typing)
	_refresh()


func _add_row(ui: CanvasLayer, i: int) -> void:
	var row: Dictionary = ROWS[i]
	var panel := Panel.new()
	panel.position = Vector2(620, 8 + i * 70.5)
	panel.size = Vector2(620, 62)
	ui.add_child(panel)
	_row_panels.append(panel)
	var is_button: bool = row.key in BUTTONS
	var title := Fx.ink_label(row.title, 30 if is_button else 26, Fx.PINK_DARK)
	title.position = Vector2(20, 12)
	if is_button:
		title.size = Vector2(620, 40)
		title.position = Vector2(0, 10)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(title)
	var value := Fx.ink_label("", 28)
	value.position = Vector2(230, 10)
	value.size = Vector2(320, 40)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(value)
	_row_values.append(value)

	# Mouse support: click a row to pick it, or click the arrows
	var click := Button.new()
	click.flat = true
	click.focus_mode = Control.FOCUS_NONE
	click.size = panel.size
	click.pressed.connect(func():
		_select(i)
		if is_button:
			_activate())
	panel.add_child(click)
	if not is_button:
		for dir in [-1, 1]:
			var arrow := Button.new()
			arrow.text = "<" if dir < 0 else ">"
			arrow.focus_mode = Control.FOCUS_NONE
			arrow.add_theme_font_size_override("font_size", 30)
			for state in ["normal", "hover", "pressed"]:
				var c: Color = {"normal": Fx.PINK, "hover": Fx.PINK_DARK, "pressed": Color("c2406a")}[state]
				arrow.add_theme_stylebox_override(state, Fx.panel_style(c, Color.WHITE, 14, 3))
			arrow.add_theme_color_override("font_color", Color.WHITE)
			arrow.add_theme_color_override("font_hover_color", Color.WHITE)
			arrow.position = Vector2(220 if dir < 0 else 560, 10)
			arrow.size = Vector2(48, 48)
			arrow.pressed.connect(func(): _select(i); _change(dir))
			panel.add_child(arrow)
	if row.key == "prefix":
		var type_button := Button.new()
		type_button.text = "Type!"
		type_button.focus_mode = Control.FOCUS_NONE
		type_button.position = Vector2(100, 10)
		type_button.size = Vector2(108, 48)
		type_button.add_theme_font_size_override("font_size", 24)
		type_button.add_theme_color_override("font_color", Fx.INK)
		type_button.add_theme_color_override("font_hover_color", Fx.INK)
		for state in ["normal", "hover", "pressed"]:
			var c := Color("ffe9a8") if state == "normal" else Color("ffd966")
			type_button.add_theme_stylebox_override(state, Fx.panel_style(c, Color.WHITE, 14, 3))
		type_button.pressed.connect(func(): _select(i); _type_name())
		panel.add_child(type_button)


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()
	_cat.walk_amount = 0.0
	_name_label.scale = Vector2.ONE * (1.0 + 0.03 * sin(_time * 3.0))
	_name_label.pivot_offset = _name_label.size / 2.0
	if Transition.is_busy() or _typing.is_open() or PauseMenu.visible:
		return
	if Input.is_action_just_pressed("move_down"):
		_select(_selected + 1)
	elif Input.is_action_just_pressed("move_up"):
		_select(_selected - 1)
	elif Input.is_action_just_pressed("move_right"):
		_change(1)
	elif Input.is_action_just_pressed("move_left"):
		_change(-1)
	elif Input.is_action_just_pressed("jump") or Input.is_action_just_pressed("action"):
		if ROWS[_selected].key in BUTTONS:
			_activate()
		elif ROWS[_selected].key == "prefix":
			_type_name()
		else:
			_select(_selected + 1)


func _select(i: int) -> void:
	_selected = wrapi(i, 0, ROWS.size())
	Sfx.play("click", 1.0, -4.0)
	_refresh()


func _change(dir: int) -> void:
	var gs := GameState
	match ROWS[_selected].key:
		"fur": gs.fur_index = wrapi(gs.fur_index + dir, 0, gs.FUR_COLORS.size())
		"markings": gs.marking_index = wrapi(gs.marking_index + dir, 0, gs.MARKING_COLORS.size())
		"pattern": gs.pattern_index = wrapi(gs.pattern_index + dir, 0, gs.PATTERNS.size())
		"eyes": gs.eye_index = wrapi(gs.eye_index + dir, 0, gs.EYE_COLORS.size())
		"fluffy": gs.fluffy = not gs.fluffy
		"prefix":
			if gs.custom_prefix == "":
				gs.prefix_index = wrapi(gs.prefix_index + dir, 0, gs.NAME_PREFIXES.size())
			gs.custom_prefix = ""  # back to the list
		"personality": gs.personality_index = wrapi(gs.personality_index + dir, 0, gs.PERSONALITIES.size())
		_: return
	Sfx.play("select", 1.0 + randf() * 0.2)
	_cat.bounce(0.18)
	Fx.hearts(self, Vector2(300, 400), 8)
	_refresh()


func _type_name() -> void:
	_typing.ask("Type your cat's name!", false, GameState.custom_prefix)
	var typed: String = await _typing.entered
	if typed == "":
		return
	GameState.custom_prefix = typed
	_cat.bounce(0.3)
	Fx.confetti(self, Vector2(300, 420), 40)
	_refresh()


func _activate() -> void:
	if ROWS[_selected].key == "paint":
		Sfx.play("select")
		Transition.go("res://scenes/paint.tscn")
	elif ROWS[_selected].key == "random":
		GameState.randomize_cat()
		Sfx.play("powerup")
		_cat.bounce(0.3)
		Fx.confetti(self, Vector2(300, 420), 40)
		_refresh()
	else:
		Sfx.play("win")
		_cat.bounce(0.35)
		Fx.confetti(self, Vector2(300, 420))
		GameState.step = 0
		GameState.save_game()
		GameState.start_step()


func _refresh() -> void:
	var gs := GameState
	_cat.set_look(gs.look())
	_cat.paint = gs.paint
	_name_label.text = gs.apprentice_name()
	var p: Dictionary = gs.personality()
	_about_label.text = "%s: %s" % [p.name, p.about]
	var values := [gs.FUR_COLORS[gs.fur_index].name, gs.MARKING_COLORS[gs.marking_index].name,
			gs.PATTERNS[gs.pattern_index], gs.EYE_COLORS[gs.eye_index].name,
			"Fluffy" if gs.fluffy else "Short", gs.prefix() + "-",
			p.name, "", "", ""]
	for i in ROWS.size():
		_row_values[i].text = values[i]
		_row_panels[i].add_theme_stylebox_override("panel", _selected_style if i == _selected else _normal_style)


func _draw() -> void:
	Scenery.sky(self, Color("f7a1bd"), Color("ffd6a5"))
	for i in 8:
		Scenery.tree(self, Vector2(i * 180 - 40, 470), 1.1 + (i % 2) * 0.25, Color("8cc97a"), Color("b07a58"))
	draw_rect(Rect2(0, 470, 1280, 250), Color("9ed27c"))
	draw_circle(Vector2(300, 330), 250, Color(1, 1, 1, 0.18))
	for k in 6:
		var a := _time * 0.6 + k * TAU / 6.0
		Scenery.star(self, Vector2(300, 330) + Vector2(cos(a) * 230, sin(a) * 120), 9, Color(1, 1, 1, 0.8))
	# Tree stump the cat stands on
	draw_colored_polygon(Fx.ellipse_points(Vector2(300, 560), Vector2(170, 40)), Color("2a1d17"))
	draw_rect(Rect2(134, 560, 332, 50), Color("2a1d17"))
	draw_rect(Rect2(138, 560, 324, 46), Color("7a5230"))
	draw_colored_polygon(Fx.ellipse_points(Vector2(300, 606), Vector2(166, 36)), Color("7a5230"))
	draw_colored_polygon(Fx.ellipse_points(Vector2(300, 558), Vector2(164, 36)), Color("c79a5f"))
	draw_set_transform(Vector2(300, 558), 0.0, Vector2(1.0, 0.22))
	for r in [120, 80, 40]:
		draw_arc(Vector2.ZERO, r, 0, TAU, 40, Color("9b7444"), 4.0)
	draw_set_transform(Vector2.ZERO)
