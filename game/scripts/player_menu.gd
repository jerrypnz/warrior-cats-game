class_name PlayerMenu
extends Control
## A little menu on one player's half of the split screen, worked with that player's own keys
## (Player 1: UP / DOWN + SPACE.  Player 2: W / S + E), so the other player can keep playing.
## Call ask(question, answers), then: var pick: int = await chosen

signal chosen(index: int)

const WIDTH := 500.0
const ROW := 50.0
const HINTS := ["UP / DOWN to choose, SPACE to pick", "W / S to choose, E to pick"]

var keys := "p1"
var _hint_text := ""
var _panel: Panel
var _rows: Array[Panel] = []
var _choice := 0
var _opened_frame := -10
var _closed_frame := -10


static func make(index: int) -> PlayerMenu:
	var menu := PlayerMenu.new()
	menu.keys = "p%d" % (index + 1)
	menu._hint_text = HINTS[index]
	menu.position = Vector2(index * (1280 - SplitScreen.HALF.x), 0)
	menu.size = SplitScreen.HALF
	menu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu.visible = false
	return menu


func ask(question: String, answers: Array) -> void:
	if _panel:
		_panel.queue_free()
	_rows.clear()
	_panel = Panel.new()
	_panel.add_theme_stylebox_override("panel", Fx.cute_panel(22))
	add_child(_panel)
	var font := ThemeDB.fallback_font
	var title_height := font.get_multiline_string_size(question, HORIZONTAL_ALIGNMENT_CENTER, WIDTH - 40, 24).y
	var title := Fx.ink_label(question, 24, Fx.PINK_DARK)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(20, 14)
	title.size = Vector2(WIDTH - 40, title_height)
	_panel.add_child(title)
	var y := 26.0 + title_height
	for answer in answers:
		var row := Panel.new()
		row.position = Vector2(24, y)
		row.size = Vector2(WIDTH - 48, ROW - 6)
		_panel.add_child(row)
		var label := Fx.ink_label(answer, 24)
		label.position = Vector2(0, 6)
		label.size = Vector2(row.size.x, 32)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.clip_text = true
		row.add_child(label)
		_rows.append(row)
		y += ROW
	var hint := Fx.ink_label(_hint_text, 22, Color("3f9e4a"))
	hint.position = Vector2(0, y + 4)
	hint.size = Vector2(WIDTH, 30)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_panel.add_child(hint)
	_panel.size = Vector2(WIDTH, y + 44)
	_panel.position = Vector2((size.x - WIDTH) / 2.0, clampf((720 - _panel.size.y) / 2.0, 90, 700 - _panel.size.y))
	_panel.pivot_offset = _panel.size / 2.0
	_panel.scale = Vector2(0.7, 0.7)
	create_tween().tween_property(_panel, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_choice = 0
	_refresh()
	visible = true
	_opened_frame = Engine.get_process_frames()
	Sfx.play("select")


## True while it's open, and for a moment after, so the key that picked isn't used again.
func is_open() -> bool:
	return visible or Engine.get_process_frames() - _closed_frame < 2


func _process(_delta: float) -> void:
	if not visible or Engine.get_process_frames() == _opened_frame:
		return
	if Input.is_action_just_pressed(keys + "_down"):
		_choice = wrapi(_choice + 1, 0, _rows.size())
		Sfx.play("click", 1.2, -6.0)
		_refresh()
	elif Input.is_action_just_pressed(keys + "_up"):
		_choice = wrapi(_choice - 1, 0, _rows.size())
		Sfx.play("click", 1.2, -6.0)
		_refresh()
	elif Input.is_action_just_pressed(keys + "_pounce"):
		visible = false
		_closed_frame = Engine.get_process_frames()
		Sfx.play("select")
		chosen.emit(_choice)


func _refresh() -> void:
	for i in _rows.size():
		var picked := i == _choice
		_rows[i].add_theme_stylebox_override("panel", Fx.panel_style(Fx.PINK if picked else Color("f3e6ea"),
				Fx.PINK_DARK if picked else Color.WHITE, 16, 4))
