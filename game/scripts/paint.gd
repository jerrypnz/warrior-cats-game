extends Node2D
## Paint on your cat with a brush! The paint stays inside your cat's outline.
## Mouse: click and drag. Keyboard: arrow keys move the brush, hold SPACE to paint.

const COLORS := [
	"ffffff", "fff1c9", "ffb3c8", "ff5d73", "ff9f43", "e8862a", "ffd23f", "b8f07a",
	"4fbf5a", "8fd8ff", "3f8cff", "a77ae8", "d9c2ff", "8a5a35", "8a8f98", "35303a",
]
const SIZES := {"Small": 4.0, "Medium": 8.0, "Big": 14.0}
const CANVAS_RIGHT := 740.0  # the brush only paints to the left of the buttons

var _cat: Cat
var _color := Color("ff5d73")
var _radius := 8.0
var _erasing := false
var _cursor := Vector2(430, 480)
var _last_mouse := Vector2.ZERO
var _last_dab := Vector2.INF
var _painting := false
var _undo: Array = []  # copies of the paint from before each stroke
var _swatches: Array[Button] = []
var _size_buttons: Array[Button] = []
var _eraser: Button
var _time := 0.0


func _ready() -> void:
	_cat = GameState.make_player_cat()
	_cat.position = Vector2(430, 650)
	_cat.size = 3.6
	_cat.collar = false  # so you can paint the neck too
	add_child(_cat)

	var ui := CanvasLayer.new()
	add_child(ui)
	ui.add_child(Fx.centered_label("Paint Your Cat!", 44, Color("ffd966"), 14, CANVAS_RIGHT))
	ui.add_child(Fx.centered_label("Click and drag with the mouse to paint!", 22, Color("fff6ec"), 74, CANVAS_RIGHT))
	ui.add_child(Fx.centered_label("(or move with arrow keys and hold SPACE)", 20, Color("fff6ec"), 102, CANVAS_RIGHT))

	var panel := Panel.new()
	panel.position = Vector2(760, 20)
	panel.size = Vector2(500, 680)
	panel.add_theme_stylebox_override("panel", Fx.cute_panel())
	ui.add_child(panel)
	var colors_title := Fx.ink_label("Colors", 28, Fx.PINK_DARK)
	colors_title.position = Vector2(30, 16)
	panel.add_child(colors_title)
	for i in COLORS.size():
		var swatch := _make_button("", Color(COLORS[i]), Vector2(30 + (i % 4) * 112, 64 + (i / 4) * 78), Vector2(100, 66))
		swatch.pressed.connect(_pick_color.bind(i))
		panel.add_child(swatch)
		_swatches.append(swatch)

	var size_title := Fx.ink_label("Brush Size", 28, Fx.PINK_DARK)
	size_title.position = Vector2(30, 384)
	panel.add_child(size_title)
	var x := 30.0
	for size_name in SIZES:
		var b := _make_button(size_name, Fx.PINK, Vector2(x, 430), Vector2(140, 56))
		b.pressed.connect(_pick_size.bind(size_name))
		panel.add_child(b)
		_size_buttons.append(b)
		x += 150.0

	_eraser = _make_button("Eraser", Color("c9b6ff"), Vector2(30, 506), Vector2(140, 56))
	_eraser.pressed.connect(func():
		_erasing = not _erasing
		Sfx.play("click")
		_refresh_buttons())
	panel.add_child(_eraser)
	var undo := _make_button("Undo", Color("8fd8ff"), Vector2(180, 506), Vector2(140, 56))
	undo.pressed.connect(_undo_stroke)
	panel.add_child(undo)
	var clear := _make_button("Clear All", Color("ffb3a7"), Vector2(330, 506), Vector2(140, 56))
	clear.pressed.connect(_clear)
	panel.add_child(clear)
	var done := _make_button("Done!", Color("7ad67a"), Vector2(30, 586), Vector2(440, 70))
	done.add_theme_font_size_override("font_size", 34)
	done.pressed.connect(_done)
	panel.add_child(done)
	_refresh_buttons()


func _make_button(text: String, color: Color, pos: Vector2, button_size: Vector2) -> Button:
	var b := Button.new()
	b.text = text
	b.position = pos
	b.size = button_size
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 24)
	b.add_theme_color_override("font_color", Fx.INK)
	b.add_theme_color_override("font_hover_color", Fx.INK)
	b.add_theme_color_override("font_pressed_color", Fx.INK)
	for state in ["normal", "hover", "pressed"]:
		var c: Color = color.lightened(0.15) if state == "hover" else color
		b.add_theme_stylebox_override(state, Fx.panel_style(c, Color.WHITE, 18, 4))
	return b


func _pick_color(i: int) -> void:
	_color = Color(COLORS[i])
	_erasing = false
	Sfx.play("select", 1.0 + i * 0.03)
	_refresh_buttons()


func _pick_size(size_name: String) -> void:
	_radius = SIZES[size_name]
	Sfx.play("click")
	_refresh_buttons()


func _refresh_buttons() -> void:
	for i in _swatches.size():
		var picked: bool = not _erasing and _color == Color(COLORS[i])
		for state in ["normal", "hover", "pressed"]:
			_swatches[i].add_theme_stylebox_override(state, Fx.panel_style(Color(COLORS[i]),
					Fx.PINK_DARK if picked else Color.WHITE, 18, 7 if picked else 4))
	var names := SIZES.keys()
	for i in _size_buttons.size():
		var picked: bool = SIZES[names[i]] == _radius
		_size_buttons[i].add_theme_stylebox_override("normal", Fx.panel_style(Fx.PINK_DARK if picked else Fx.PINK,
				Color.WHITE, 18, 4))
	_eraser.add_theme_stylebox_override("normal", Fx.panel_style(Color("8a6ad8") if _erasing else Color("c9b6ff"),
			Color.WHITE, 18, 4))


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()
	if Transition.is_busy():
		return
	# The brush follows the mouse when it moves, or the arrow keys
	var mouse := get_global_mouse_position()
	if mouse.distance_to(_last_mouse) > 0.5:
		_cursor = mouse
		_last_mouse = mouse
	var keys := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	_cursor += keys * 320.0 * delta
	_cursor = _cursor.clamp(Vector2(0, 0), Vector2(1280, 720))

	var mouse_down := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	var brushing := (mouse_down or Input.is_action_pressed("jump")) and _cursor.x < CANVAS_RIGHT
	if brushing:
		_brush(_cursor)
	else:
		_painting = false
		_last_dab = Vector2.INF
	if Input.is_action_just_pressed("action"):
		_done()


func _brush(screen_pos: Vector2) -> void:
	var p := _cat.to_cat_space(screen_pos)
	if not _painting:
		_painting = true
		_undo.append(GameState.paint.duplicate())
		if _undo.size() > 30:
			_undo.pop_front()
	if _erasing:
		var kept := GameState.paint.filter(func(dab): return dab[0].distance_to(p) > _radius + dab[2] * 0.5)
		_set_paint(kept)
	elif Rect2(-80, -120, 160, 125).has_point(p):
		# Fill in the gap since last frame so fast strokes stay smooth
		var from := p if _last_dab == Vector2.INF else _last_dab
		var steps := maxi(1, int(from.distance_to(p) / (_radius * 0.4)))
		for k in steps:
			if GameState.paint.size() < GameState.MAX_PAINT:
				GameState.paint.append([from.lerp(p, (k + 1.0) / steps), _color, _radius])
		if Engine.get_process_frames() % 6 == 0:
			Sfx.play("click", randf_range(1.4, 1.8), -18.0)
	_last_dab = p


func _set_paint(dabs: Array) -> void:
	GameState.paint = dabs
	_cat.paint = dabs


func _undo_stroke() -> void:
	if _undo.is_empty():
		return
	Sfx.play("click", 0.8)
	_set_paint(_undo.pop_back())


func _clear() -> void:
	Sfx.play("hurt")
	_undo.append(GameState.paint.duplicate())
	_set_paint([])
	_cat.bounce(0.3)


func _done() -> void:
	if Transition.is_busy():
		return
	Sfx.play("win")
	_cat.bounce(0.35)
	Fx.hearts(self, Vector2(430, 380), 14)
	Transition.go("res://scenes/creator.tscn")


func _draw() -> void:
	Scenery.sky(self, Color("c9b6ff"), Color("ffd6e8"))
	draw_circle(Vector2(430, 440), 280, Color(1, 1, 1, 0.25))
	for k in 8:
		var a := _time * 0.4 + k * TAU / 8.0
		Scenery.star(self, Vector2(430, 440) + Vector2(cos(a) * 300, sin(a) * 230), 8, Color(1, 1, 1, 0.7))
	draw_colored_polygon(Fx.ellipse_points(Vector2(430, 660), Vector2(230, 40)), Color(1, 1, 1, 0.35))
	# Brush cursor
	if _cursor.x < CANVAS_RIGHT:
		var r := _radius * _cat.size
		draw_circle(_cursor, r, Color(1, 1, 1, 0.5) if _erasing else Color(_color, 0.6))
		draw_arc(_cursor, r, 0, TAU, 32, Fx.OUTLINE, 2.0)
