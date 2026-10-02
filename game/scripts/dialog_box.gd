class_name DialogBox
extends CanvasLayer
## A talking box at the bottom of the screen. Call say([[speaker, text], ...]), then
## await finished. SPACE shows the whole line, then goes to the next one.

signal finished

var _lines: Array = []
var _index := 0
var _shown := 0.0
var _opened_frame := -10
var _closed_frame := -10
var _panel: Panel
var _name_label: Label
var _text_label: Label
var _hint: Label


func _ready() -> void:
	layer = 10
	_panel = Panel.new()
	_panel.position = Vector2(120, 500)
	_panel.size = Vector2(1040, 196)
	_panel.add_theme_stylebox_override("panel", Fx.panel_style(Color(0.16, 0.11, 0.07, 0.94), Color("e8c26a")))
	add_child(_panel)
	_name_label = Fx.make_label("", 30, Color("ffd966"))
	_name_label.position = Vector2(28, 12)
	_panel.add_child(_name_label)
	_text_label = Fx.make_label("", 28, Color.WHITE, 6)
	_text_label.position = Vector2(28, 56)
	_text_label.size = Vector2(984, 110)
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_panel.add_child(_text_label)
	_hint = Fx.make_label("SPACE >", 22, Color("ffd966"), 5)
	_hint.position = Vector2(910, 154)
	_panel.add_child(_hint)
	_panel.visible = false


func say(lines: Array) -> void:
	_lines = lines
	_index = 0
	_panel.visible = true
	_opened_frame = Engine.get_process_frames()
	_show_line()


## True while talking, and for a moment after, so the SPACE that closed it isn't reused.
func is_open() -> bool:
	return _panel.visible or Engine.get_process_frames() - _closed_frame < 2


func _show_line() -> void:
	_name_label.text = _lines[_index][0]
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
