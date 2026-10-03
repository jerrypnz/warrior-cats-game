class_name CampProp
extends Node2D
## Big things in camp that cats can walk behind: dens, the High Rock, the fresh-kill pile.
## The origin is where the thing touches the ground.

const OUTLINE := Color("2a1d17")

var kind := "den"


func setup(prop_kind: String, label_text := "") -> CampProp:
	kind = prop_kind
	if label_text != "":
		var label := Fx.make_label(label_text, 20, Color("f6e8c8"), 6)
		label.size = Vector2(240, 30)
		label.position = Vector2(-120, 4)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(label)
	return self


## The ground area cats can't walk into
func footprint() -> Rect2:
	match kind:
		"high_rock": return Rect2(global_position + Vector2(-165, -110), Vector2(330, 115))
		"den": return Rect2(global_position + Vector2(-95, -45), Vector2(190, 48))
		"fresh_kill": return Rect2(global_position + Vector2(-40, -18), Vector2(80, 22))
		"medicine": return Rect2(global_position + Vector2(-60, -30), Vector2(120, 32))
	return Rect2()


func _draw() -> void:
	match kind:
		"den": _draw_den()
		"high_rock": _draw_high_rock()
		"fresh_kill": _draw_fresh_kill()
		"medicine": _draw_medicine()


func _draw_den() -> void:
	var dome := PackedVector2Array()
	for i in 21:
		var a := PI + PI * i / 20.0
		dome.append(Vector2(cos(a) * 100, sin(a) * 105))
	var outline := PackedVector2Array()
	for p in dome:
		outline.append(p * 1.04)
	draw_colored_polygon(outline, OUTLINE)
	draw_colored_polygon(dome, Color("5fa84f"))
	for leaf in [Vector2(-60, -40), Vector2(-20, -80), Vector2(30, -60), Vector2(60, -30), Vector2(0, -40),
			Vector2(-45, -75), Vector2(50, -78), Vector2(-75, -15), Vector2(75, -12)]:
		draw_circle(leaf, 14, Color("6fb85a"))
		draw_circle(leaf + Vector2(-3, -3), 7, Color("8cc97a"))
	var door := PackedVector2Array()
	for i in 13:
		var a := PI + PI * i / 12.0
		door.append(Vector2(cos(a) * 34, sin(a) * 46))
	draw_colored_polygon(door, Color("3a2a2a"))


func _draw_medicine() -> void:
	# A tunnel of ferns leading to the medicine cat's den
	for k in 9:
		var x := -60.0 + k * 15.0
		for a in [-0.6, -0.2, 0.2, 0.6]:
			var tip := Vector2(x + sin(a) * 40, -85 + absf(a) * 30)
			draw_line(Vector2(x, 0), tip, OUTLINE, 7.0)
			draw_line(Vector2(x, 0), tip, Color("6fc46a"), 4.0)
	draw_colored_polygon(Fx.ellipse_points(Vector2(0, -16), Vector2(26, 18)), Color("3a2a2a"))
	for p in [Vector2(-40, -10), Vector2(42, -14)]:
		Scenery.flower(self, p, Color("c9b6ff"))


func _draw_high_rock() -> void:
	var pts := PackedVector2Array([Vector2(-165, 0), Vector2(-150, -60), Vector2(-110, -118), Vector2(-40, -138),
			Vector2(60, -134), Vector2(125, -100), Vector2(160, -45), Vector2(168, 0)])
	var outline := PackedVector2Array()
	for p in pts:
		outline.append(p * 1.03 + Vector2(0, 2))
	draw_colored_polygon(outline, OUTLINE)
	draw_colored_polygon(pts, Color("a7a3b5"))
	draw_colored_polygon(PackedVector2Array([Vector2(-100, -112), Vector2(-40, -130), Vector2(50, -126),
			Vector2(-30, -110)]), Color("cfcbdc"))
	draw_colored_polygon(PackedVector2Array([Vector2(60, -40), Vector2(140, -50), Vector2(160, -10),
			Vector2(80, -8)]), Color("8e8aa0"))
	draw_line(Vector2(-60, -70), Vector2(-20, -40), Color("8e8aa0"), 4.0)


func _draw_fresh_kill() -> void:
	draw_colored_polygon(Fx.ellipse_points(Vector2(0, -6), Vector2(46, 14)), Color("5c4630"))
	var prey := [Vector3(-18, -14, 0), Vector3(14, -12, 1), Vector3(-2, -26, 2)]
	# The pile grows when you bring prey home
	var extra := [Vector3(-30, -24, 0), Vector3(26, -24, 2), Vector3(-14, -36, 1), Vector3(12, -38, 0),
			Vector3(0, -48, 2), Vector3(-26, -36, 1), Vector3(24, -36, 0), Vector3(-6, -58, 1)]
	prey.append_array(extra.slice(0, mini(GameState.fresh_kill, extra.size())))
	for m in prey:
		var c := Color("8a7a6a") if m.z != 1 else Color("a0623a")
		draw_colored_polygon(Fx.ellipse_points(Vector2(m.x, m.y), Vector2(16, 9)), OUTLINE)
		draw_colored_polygon(Fx.ellipse_points(Vector2(m.x, m.y), Vector2(14, 7.5)), c)
		draw_line(Vector2(m.x - 14, m.y), Vector2(m.x - 26, m.y - 6), Color("e8a0a8"), 2.0)
