extends CanvasLayer
## Fades the screen out and in when changing scenes: Transition.go("res://scenes/camp.tscn")

var _rect: ColorRect
var _busy := false


func _ready() -> void:
	layer = 100
	_rect = ColorRect.new()
	_rect.color = Color(0.06, 0.04, 0.1, 0.0)
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rect)


func is_busy() -> bool:
	return _busy


func go(path: String) -> void:
	if _busy:
		return
	_busy = true
	var fade_out := create_tween()
	fade_out.tween_property(_rect, "color:a", 1.0, 0.35)
	await fade_out.finished
	get_tree().change_scene_to_file(path)
	var fade_in := create_tween()
	fade_in.tween_property(_rect, "color:a", 0.0, 0.35)
	await fade_in.finished
	_busy = false
