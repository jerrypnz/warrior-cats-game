class_name InfoCard
extends CanvasLayer
## A big card in the middle of the screen (training instructions, "You did it!").
## Call show_card(title, body), then await closed. SPACE closes it.

signal closed

var _panel: Panel
var _title: Label
var _body: Label
var _hint: Label
var _opened_frame := -10


func _ready() -> void:
	layer = 20
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.size = Vector2(1280, 720)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel = Panel.new()
	_panel.position = Vector2(240, 150)
	_panel.size = Vector2(800, 420)
	_panel.add_theme_stylebox_override("panel", Fx.cute_panel(30))
	add_child(dim)
	add_child(_panel)
	_title = Fx.centered_label("", 50, Fx.PINK_DARK, 30, 800)
	_title.add_theme_constant_override("outline_size", 0)
	_panel.add_child(_title)
	_body = Fx.ink_label("", 28)
	_body.position = Vector2(50, 120)
	_body.size = Vector2(700, 220)
	_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_panel.add_child(_body)
	_hint = Fx.centered_label("Press SPACE!", 30, Color("3f9e4a"), 350, 800)
	_hint.add_theme_constant_override("outline_size", 0)
	_panel.add_child(_hint)
	visible = false


func show_card(title: String, body: String, hint := "Press SPACE!") -> void:
	_title.text = title
	_body.text = body
	_hint.text = hint
	visible = true
	_opened_frame = Engine.get_process_frames()
	_panel.pivot_offset = _panel.size / 2.0
	_panel.scale = Vector2(0.6, 0.6)
	create_tween().tween_property(_panel, "scale", Vector2.ONE, 0.3) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func is_open() -> bool:
	return visible


func _process(_delta: float) -> void:
	if not visible:
		return
	_hint.modulate.a = 0.6 + 0.4 * sin(Time.get_ticks_msec() / 200.0)
	if Engine.get_process_frames() - _opened_frame < 15:
		return  # a short pause so a held SPACE doesn't skip the card
	if Input.is_action_just_pressed("jump") or Input.is_action_just_pressed("action"):
		Sfx.play("select")
		visible = false
		closed.emit()
