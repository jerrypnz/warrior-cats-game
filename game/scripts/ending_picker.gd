class_name EndingPicker
extends CanvasLayer
## Pick the end of your warrior (or medicine cat) name, like Fire + "heart".
## Call open(), then: var ending: String = await picker.picked
## Arrows move, SPACE picks. The last button lets you type your own ending.

signal picked(ending: String)

const COLUMNS := 5

var _panel: Panel
var _preview: Label
var _buttons: Array[Button] = []
var _choice := 0
var _typing: NameEntry
var _opened_frame := -10


func _ready() -> void:
	layer = 25
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.size = Vector2(1280, 720)
	add_child(dim)
	_panel = Panel.new()
	_panel.position = Vector2(140, 20)
	_panel.size = Vector2(1000, 680)
	_panel.add_theme_stylebox_override("panel", Fx.cute_panel(30))
	dim.add_child(_panel)
	var title := Fx.centered_label("Pick the end of your name!", 34, Fx.PINK_DARK, 14, 1000)
	title.add_theme_constant_override("outline_size", 0)
	_panel.add_child(title)
	_preview = Fx.centered_label("", 56, Color("ffd966"), 56, 1000)
	_panel.add_child(_preview)

	var endings: Array = GameState.NAME_ENDINGS.duplicate()
	endings.append("Type my own!")
	for i in endings.size():
		var b := Button.new()
		b.text = endings[i] if _is_typing_button(i) else "-" + endings[i]
		b.focus_mode = Control.FOCUS_NONE
		b.position = Vector2(40 + (i % COLUMNS) * 186, 150 + (i / COLUMNS) * 82)
		b.size = Vector2(172, 66)
		b.add_theme_font_size_override("font_size", 24 if _is_typing_button(i) else 28)
		b.add_theme_color_override("font_color", Fx.INK)
		b.add_theme_color_override("font_hover_color", Fx.INK)
		b.mouse_entered.connect(func():
			_choice = i
			_refresh())
		b.pressed.connect(func():
			_choice = i
			_pick())
		_panel.add_child(b)
		_buttons.append(b)
	var help := Fx.centered_label("ARROWS = choose    SPACE = pick", 22, Fx.INK, 640, 1000)
	help.add_theme_constant_override("outline_size", 0)
	_panel.add_child(help)
	_typing = NameEntry.new()
	add_child(_typing)
	visible = false


## At a naming ceremony: let the speaker choose your name, or pick it yourself.
## Sets GameState.name_ending ("" means the speaker's surprise name).
func choose_name(dialog: DialogBox, speaker: String) -> void:
	dialog.ask(speaker, Story.fill("{paw}, StarClan has whispered a name to me. Will you take it, or choose your own?"),
			["Surprise me!", "I'll pick my name!"])
	var pick: int = await dialog.chosen
	GameState.name_ending = ""
	if pick == 1:
		open()
		GameState.name_ending = await picked
	GameState.save_game()


func open() -> void:
	# Start on the ending that matches your personality
	_choice = maxi(0, GameState.NAME_ENDINGS.find(GameState.personality().suffix))
	visible = true
	_opened_frame = Engine.get_process_frames()
	_refresh()


func _process(_delta: float) -> void:
	if not visible or _typing.is_open() or Engine.get_process_frames() - _opened_frame < 10:
		return
	var count := _buttons.size()
	if Input.is_action_just_pressed("move_right"):
		_move(1)
	elif Input.is_action_just_pressed("move_left"):
		_move(-1)
	elif Input.is_action_just_pressed("move_down"):
		_move(COLUMNS if _choice + COLUMNS < count else 0)
	elif Input.is_action_just_pressed("move_up"):
		_move(-COLUMNS if _choice - COLUMNS >= 0 else 0)
	elif Input.is_action_just_pressed("jump") or Input.is_action_just_pressed("action"):
		_pick()


func _move(by: int) -> void:
	_choice = wrapi(_choice + by, 0, _buttons.size())
	Sfx.play("click", 1.1, -4.0)
	_refresh()


func _is_typing_button(i: int) -> bool:
	return i >= GameState.NAME_ENDINGS.size()


func _pick() -> void:
	var ending := ""
	if _is_typing_button(_choice):
		_typing.ask("Type the end of your name!", true)
		ending = await _typing.entered
		if ending == "":
			return  # changed their mind: back to the list
	else:
		ending = GameState.NAME_ENDINGS[_choice]
	Sfx.play("powerup")
	visible = false
	picked.emit(ending)


func _refresh() -> void:
	var ending: String = "..." if _is_typing_button(_choice) else GameState.NAME_ENDINGS[_choice]
	_preview.text = GameState.prefix() + ending
	for i in _buttons.size():
		var on := i == _choice
		var color := Color("ffe9a8") if _is_typing_button(i) else Color("f3e6ea")
		for state in ["normal", "hover", "pressed"]:
			_buttons[i].add_theme_stylebox_override(state, Fx.panel_style(Fx.PINK if on else color,
					Fx.PINK_DARK if on else Color.WHITE, 16, 5 if on else 3))
