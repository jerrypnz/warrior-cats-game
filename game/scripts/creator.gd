extends Node2D
## Design your cat: fur, markings, eyes, the first part of your name, and personality.

const ROWS := [
	{"title": "Fur", "key": "fur"},
	{"title": "Markings", "key": "markings"},
	{"title": "Pattern", "key": "pattern"},
	{"title": "Eyes", "key": "eyes"},
	{"title": "Name", "key": "prefix"},
	{"title": "Personality", "key": "personality"},
	{"title": "Surprise Me!", "key": "random"},
	{"title": "I'm Ready!", "key": "done"},
]

var _selected := 0
var _cat: Cat
var _row_panels: Array[Panel] = []
var _row_values: Array[Label] = []
var _name_label: Label
var _about_label: Label
var _normal_style := Fx.panel_style(Color(0.16, 0.11, 0.07, 0.75), Color(0.5, 0.38, 0.22), 14, 3)
var _selected_style := Fx.panel_style(Color(0.32, 0.22, 0.1, 0.95), Color("ffd966"), 14, 4)
var _time := 0.0


func _ready() -> void:
	_cat = Cat.new()
	_cat.position = Vector2(300, 545)
	_cat.size = 2.6
	add_child(_cat)

	var ui := CanvasLayer.new()
	add_child(ui)
	ui.add_child(Fx.centered_label("Design Your Cat!", 44, Color("ffd966"), 18, 600))
	_name_label = Fx.centered_label("", 64, Color.WHITE, 90, 600)
	ui.add_child(_name_label)
	ui.add_child(Fx.centered_label("%s Apprentice" % GameState.CLAN, 26, Color("f6e8c8"), 175, 600))
	_about_label = Fx.centered_label("", 26, Color("9be37a"), 600, 600)
	_about_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_about_label.size.y = 80
	ui.add_child(_about_label)

	for i in ROWS.size():
		_add_row(ui, i)
	ui.add_child(Fx.centered_label("UP / DOWN = pick     LEFT / RIGHT = change     SPACE = next", 22,
			Color("f6e8c8"), 684))
	_refresh()


func _add_row(ui: CanvasLayer, i: int) -> void:
	var row: Dictionary = ROWS[i]
	var panel := Panel.new()
	panel.position = Vector2(620, 24 + i * 80)
	panel.size = Vector2(620, 68)
	ui.add_child(panel)
	_row_panels.append(panel)
	var is_button: bool = row.key in ["random", "done"]
	var title := Fx.make_label(row.title, 30 if is_button else 26, Color("ffd966"))
	title.position = Vector2(20, 14)
	if is_button:
		title.size = Vector2(620, 40)
		title.position = Vector2(0, 12)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(title)
	var value := Fx.make_label("", 28, Color.WHITE)
	value.position = Vector2(230, 12)
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
			arrow.position = Vector2(220 if dir < 0 else 560, 10)
			arrow.size = Vector2(48, 48)
			arrow.pressed.connect(func(): _select(i); _change(dir))
			panel.add_child(arrow)


func _process(delta: float) -> void:
	_time += delta
	_cat.walk_amount = 0.0
	_name_label.scale = Vector2.ONE * (1.0 + 0.03 * sin(_time * 3.0))
	_name_label.pivot_offset = _name_label.size / 2.0
	if Transition.is_busy():
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
		if ROWS[_selected].key in ["random", "done"]:
			_activate()
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
		"prefix": gs.prefix_index = wrapi(gs.prefix_index + dir, 0, gs.NAME_PREFIXES.size())
		"personality": gs.personality_index = wrapi(gs.personality_index + dir, 0, gs.PERSONALITIES.size())
		_: return
	Sfx.play("select", 1.0 + randf() * 0.2)
	_cat.bounce(0.18)
	Fx.burst(self, Vector2(300, 440), Color("fff27a"), 10, 200.0, 100.0)
	_refresh()


func _activate() -> void:
	if ROWS[_selected].key == "random":
		GameState.randomize_cat()
		Sfx.play("powerup")
		_cat.bounce(0.3)
		Fx.confetti(self, Vector2(300, 420), 40)
		_refresh()
	else:
		Sfx.play("win")
		_cat.bounce(0.35)
		Fx.confetti(self, Vector2(300, 420))
		Transition.go("res://scenes/camp.tscn")


func _refresh() -> void:
	var gs := GameState
	_cat.set_look(gs.look())
	_name_label.text = gs.apprentice_name()
	var p: Dictionary = gs.personality()
	_about_label.text = "%s: %s" % [p.name, p.about]
	var values := [gs.FUR_COLORS[gs.fur_index].name, gs.MARKING_COLORS[gs.marking_index].name,
			gs.PATTERNS[gs.pattern_index], gs.EYE_COLORS[gs.eye_index].name, gs.prefix() + "-",
			p.name, "", ""]
	for i in ROWS.size():
		_row_values[i].text = values[i]
		_row_panels[i].add_theme_stylebox_override("panel", _selected_style if i == _selected else _normal_style)


func _draw() -> void:
	Scenery.sky(self, Color("2b4a3a"), Color("7aa65a"))
	for i in 8:
		Scenery.tree(self, Vector2(i * 180 - 40, 470), 1.1 + (i % 2) * 0.25, Color("3d6b3f"))
	draw_rect(Rect2(0, 470, 1280, 250), Color("5e8f43"))
	draw_circle(Vector2(300, 300), 250, Color(1, 0.95, 0.7, 0.12))
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
