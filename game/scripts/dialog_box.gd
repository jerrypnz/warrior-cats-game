class_name DialogBox
extends CanvasLayer
## A talking box at the bottom of the screen. Call say([[speaker, text], ...]), then
## await finished. SPACE shows the whole line, then goes to the next one.

signal finished
signal chosen(index: int)  # after ask(): which answer was picked

var _lines: Array = []
var _index := 0
var _shown := 0.0
var _opened_frame := -10
var _closed_frame := -10
var _panel: Panel
var _name_tag: Panel
var _name_label: Label
var _text_label: Label
var _hint: Label
var _choices: Array[Button] = []
var _choice := 0


func _ready() -> void:
	layer = 10
	_panel = Panel.new()
	_panel.position = Vector2(120, 512)
	_panel.size = Vector2(1040, 186)
	_panel.add_theme_stylebox_override("panel", Fx.cute_panel())
	add_child(_panel)
	_name_tag = Panel.new()
	_name_tag.position = Vector2(30, -26)
	_name_tag.add_theme_stylebox_override("panel", Fx.panel_style(Fx.PINK_DARK, Color.WHITE, 20, 4))
	_panel.add_child(_name_tag)
	_name_label = Fx.make_label("", 28, Color.WHITE, 0)
	_name_label.position = Vector2(22, 4)
	_name_tag.add_child(_name_label)
	_text_label = Fx.ink_label("", 28)
	_text_label.position = Vector2(34, 36)
	_text_label.size = Vector2(972, 110)
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_panel.add_child(_text_label)
	_hint = Fx.ink_label("SPACE >", 22, Fx.PINK_DARK)
	_hint.position = Vector2(920, 146)
	_panel.add_child(_hint)
	_panel.visible = false


func say(lines: Array) -> void:
	_lines = lines
	_index = 0
	_panel.visible = true
	_opened_frame = Engine.get_process_frames()
	_show_line()


## Asks a question with answers to pick from. Then: var pick: int = await dialog.chosen
func ask(speaker: String, text: String, answers: Array) -> void:
	say([[speaker, text]])
	var x := 34.0
	for i in answers.size():
		var b := Button.new()
		b.text = answers[i]
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 24)
		b.add_theme_color_override("font_color", Fx.INK)
		b.add_theme_color_override("font_hover_color", Fx.INK)
		b.position = Vector2(x, 112)
		b.pressed.connect(func():
			_choice = i
			_pick())
		_panel.add_child(b)
		b.reset_size()
		b.size = Vector2(b.get_minimum_size().x + 40, 52)
		x += b.size.x + 16.0
		_choices.append(b)
	_choice = 0
	_refresh_choices()


func _refresh_choices() -> void:
	for i in _choices.size():
		var picked := i == _choice
		for state in ["normal", "hover", "pressed"]:
			_choices[i].add_theme_stylebox_override(state, Fx.panel_style(Fx.PINK if picked else Color("f3e6ea"),
					Fx.PINK_DARK if picked else Color.WHITE, 16, 4))
		_choices[i].visible = _line_done()


func _pick() -> void:
	Sfx.play("select")
	for b in _choices:
		b.queue_free()
	_choices.clear()
	_panel.visible = false
	_closed_frame = Engine.get_process_frames()
	chosen.emit(_choice)


## True while talking, and for a moment after, so the SPACE that closed it isn't reused.
func is_open() -> bool:
	return _panel.visible or Engine.get_process_frames() - _closed_frame < 2


func _show_line() -> void:
	_name_label.text = _lines[_index][0]
	_name_tag.visible = _name_label.text != ""
	_name_tag.size = Vector2(_name_label.get_minimum_size().x + 44, 46)
	_text_label.add_theme_color_override("font_color", Fx.INK if _name_tag.visible else Color("8a6a7a"))
	_text_label.text = _lines[_index][1]
	_text_label.visible_characters = 0
	_shown = 0.0


func _line_done() -> bool:
	return _text_label.visible_characters < 0 or \
			_text_label.visible_characters >= _text_label.get_total_character_count()


func _process(delta: float) -> void:
	if not _panel.visible:
		return
	if not _line_done():
		_shown += delta * 55.0
		_text_label.visible_characters = int(_shown)
	_hint.visible = _line_done() and fmod(Time.get_ticks_msec() / 400.0, 2.0) < 1.4
	if Engine.get_process_frames() == _opened_frame:
		return
	if not _choices.is_empty():
		_hint.visible = false
		_refresh_choices()
		if Input.is_action_just_pressed("jump") or Input.is_action_just_pressed("action"):
			if _line_done():
				_pick()
			else:
				_text_label.visible_characters = -1
		elif Input.is_action_just_pressed("move_right") or Input.is_action_just_pressed("move_down"):
			_choice = wrapi(_choice + 1, 0, _choices.size())
			Sfx.play("click", 1.2, -6.0)
		elif Input.is_action_just_pressed("move_left") or Input.is_action_just_pressed("move_up"):
			_choice = wrapi(_choice - 1, 0, _choices.size())
			Sfx.play("click", 1.2, -6.0)
		return
	if Input.is_action_just_pressed("jump") or Input.is_action_just_pressed("action"):
		if not _line_done():
			_text_label.visible_characters = -1
			return
		Sfx.play("click", 1.1, -6.0)
		_index += 1
		if _index < _lines.size():
			_show_line()
		else:
			_panel.visible = false
			_closed_frame = Engine.get_process_frames()
			finished.emit()
