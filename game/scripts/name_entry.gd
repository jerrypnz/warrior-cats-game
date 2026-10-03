class_name NameEntry
extends CanvasLayer
## A box for typing a name. Call ask(title, example), then: var text: String = await entry.entered
## ENTER or the OK button = done. ESC or Cancel = never mind (gives back "").

signal entered(text: String)

var _panel: Panel
var _title: Label
var _box: LineEdit
var _preview: Label
var _closed_frame := -10
var _ending := false  # typing a warrior name ending (like "heart") instead of a first name


func _ready() -> void:
	layer = 30
	add_to_group("typing")  # the ESC menu stays shut while typing
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.5)
	dim.size = Vector2(1280, 720)
	add_child(dim)
	_panel = Panel.new()
	_panel.position = Vector2(290, 170)
	_panel.size = Vector2(700, 380)
	_panel.add_theme_stylebox_override("panel", Fx.cute_panel(30))
	dim.add_child(_panel)
	_title = Fx.centered_label("", 40, Fx.PINK_DARK, 24, 700)
	_title.add_theme_constant_override("outline_size", 0)
	_panel.add_child(_title)

	_box = LineEdit.new()
	_box.position = Vector2(100, 100)
	_box.size = Vector2(500, 80)
	_box.max_length = 14
	_box.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_theme_font_size_override("font_size", 44)
	_box.add_theme_color_override("font_color", Fx.INK)
	_box.add_theme_color_override("caret_color", Fx.PINK_DARK)
	_box.add_theme_stylebox_override("normal", Fx.panel_style(Color.WHITE, Fx.PINK, 18, 4))
	_box.add_theme_stylebox_override("focus", Fx.panel_style(Color.WHITE, Fx.PINK_DARK, 18, 5))
	_box.text_changed.connect(func(_t): _update_preview())
	_box.text_submitted.connect(func(_t): _done(true))
	_panel.add_child(_box)

	_preview = Fx.centered_label("", 30, Fx.INK, 200, 700)
	_preview.add_theme_constant_override("outline_size", 0)
	_panel.add_child(_preview)

	for i in 2:
		var b := Button.new()
		b.text = ["OK!", "Cancel"][i]
		b.focus_mode = Control.FOCUS_NONE
		b.position = Vector2(120 + i * 250, 270)
		b.size = Vector2(210, 66)
		b.add_theme_font_size_override("font_size", 30)
		b.add_theme_color_override("font_color", Fx.INK)
		b.add_theme_color_override("font_hover_color", Fx.INK)
		var color := Color("7ad67a") if i == 0 else Color("f3e6ea")
		for state in ["normal", "hover", "pressed"]:
			b.add_theme_stylebox_override(state, Fx.panel_style(color.lightened(0.15) if state == "hover" else color,
					Color.WHITE, 18, 4))
		b.pressed.connect(_done.bind(i == 0))
		_panel.add_child(b)
	visible = false


## Opens the box. ending = true when typing a name ending ("heart") instead of a first name.
func ask(title: String, ending := false, start_text := "") -> void:
	_title.text = title
	_ending = ending
	_box.text = start_text
	_box.caret_column = start_text.length()
	visible = true
	_update_preview()
	_box.grab_focus.call_deferred()
	Sfx.play("select")


## True while typing, and for a moment after, so the ENTER that closed it isn't reused
func is_open() -> bool:
	return visible or Engine.get_process_frames() - _closed_frame < 3


func _process(_delta: float) -> void:
	if visible and Input.is_action_just_pressed("menu"):
		_done(false)


func _update_preview() -> void:
	var typed := GameState.clean_name(_box.text, _ending)
	if typed == "":
		_preview.text = "Type with the keyboard!"
	elif _ending:
		_preview.text = "Your name will be: %s" % (GameState.prefix() + typed)
	else:
		_preview.text = "You'll be: %spaw" % typed


func _done(ok: bool) -> void:
	if not visible:
		return
	var typed := GameState.clean_name(_box.text, _ending) if ok else ""
	if ok and typed == "":
		Sfx.play("click", 0.7)  # nothing typed yet
		return
	Sfx.play("win" if ok else "click")
	_box.release_focus()
	visible = false
	_closed_frame = Engine.get_process_frames()
	entered.emit(typed)
