class_name Fx
extends RefCounted
## Little helpers for juicy effects: particle bursts, floating text, screen shake, labels.


static func burst(parent: Node, pos: Vector2, color: Color, amount := 16, speed := 240.0,
		gravity := 400.0) -> void:
	var p := CPUParticles2D.new()
	p.position = pos
	p.one_shot = true
	p.amount = amount
	p.lifetime = 0.8
	p.explosiveness = 1.0
	p.direction = Vector2.UP
	p.spread = 180.0
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.gravity = Vector2(0, gravity)
	p.scale_amount_min = 4.0
	p.scale_amount_max = 9.0
	var ramp := Gradient.new()
	ramp.set_color(0, color)
	ramp.set_color(1, Color(color, 0.0))
	p.color_ramp = ramp
	parent.add_child(p)
	p.emitting = true
	parent.get_tree().create_timer(p.lifetime + 0.3).timeout.connect(p.queue_free)


static func confetti(parent: Node, pos: Vector2, amount := 60) -> void:
	for c in [Color("ff5d73"), Color("ffd23f"), Color("3bceac"), Color("5aa9e6"), Color("c77dff")]:
		burst(parent, pos, c, amount / 5, 650.0, 500.0)


static func popup_text(parent: Node, pos: Vector2, text: String, color := Color.WHITE,
		font_size := 32) -> void:
	var label := make_label(text, font_size, color)
	parent.add_child(label)
	label.position = pos - Vector2(150, 20)
	label.size = Vector2(300, 50)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.pivot_offset = Vector2(150, 25)
	label.scale = Vector2(0.4, 0.4)
	var t := label.create_tween()
	t.tween_property(label, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(label, "position:y", label.position.y - 70, 1.0)
	t.parallel().tween_property(label, "modulate:a", 0.0, 0.4).set_delay(0.6)
	t.tween_callback(label.queue_free)


static func shake(camera: Camera2D, strength := 8.0, duration := 0.25) -> void:
	if camera == null:
		return
	var t := camera.create_tween()
	var steps := int(duration / 0.03)
	for i in steps:
		var fade := 1.0 - float(i) / steps
		t.tween_property(camera, "offset", Vector2(randf_range(-1, 1), randf_range(-1, 1)) * strength * fade, 0.03)
	t.tween_property(camera, "offset", Vector2.ZERO, 0.03)


static func make_label(text: String, font_size: int, color := Color.WHITE, outline := 8) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color("1c1420"))
	label.add_theme_constant_override("outline_size", outline)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


static func centered_label(text: String, font_size: int, color: Color, y: float,
		width := 1280.0) -> Label:
	var label := make_label(text, font_size, color)
	label.position = Vector2(0, y)
	label.size = Vector2(width, font_size * 1.5)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


static func panel_style(bg: Color, border: Color, radius := 18, border_width := 4) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	return style


static func ellipse_points(center: Vector2, radii: Vector2, count := 32) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in count:
		var a := TAU * i / count
		pts.append(center + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	return pts
