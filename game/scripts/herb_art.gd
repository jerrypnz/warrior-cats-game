class_name HerbArt
extends RefCounted
## The medicine cat's herbs: what each one is for, and how to draw it.

const HERBS := {
	"Marigold": {"use": "Marigold helps scratches heal.", "problem": "I got a scratch on my ear!"},
	"Catmint": {"use": "Catmint helps a cat with a cough.", "problem": "*cough cough* I can't stop coughing!"},
	"Poppy Seeds": {"use": "Poppy seeds help a cat who can't sleep.", "problem": "I'm so tired, but I just can't sleep..."},
	"Cobwebs": {"use": "Cobwebs go on a cut to help it stop hurting.", "problem": "Ouch! I cut my paw on a thorn!"},
	"Watermint": {"use": "Watermint helps a tummy ache.", "problem": "Ooh, my tummy hurts!"},
	"Honey": {"use": "Honey soothes a sore throat. Sweet!", "problem": "My throat is all scratchy and sore."},
}
## Herbs that grow in the forest (honey comes from bees, so you can't pick it)
const GROWING := ["Marigold", "Catmint", "Poppy Seeds", "Cobwebs", "Watermint"]

const OUTLINE := Color("4a2f3c")
const LEAF := Color("6fb85a")


static func draw(c: CanvasItem, pos: Vector2, kind: String, s := 1.0) -> void:
	c.draw_set_transform(pos, 0.0, Vector2(s, s))
	match kind:
		"Marigold":
			_leaves(c, LEAF)
			for k in 8:
				var a := TAU * k / 8.0
				c.draw_circle(Vector2(0, -26) + Vector2(cos(a), sin(a)) * 10, 7, Color("ff9f43"))
			c.draw_circle(Vector2(0, -26), 7, Color("e0661a"))
		"Catmint":
			_leaves(c, Color("8fc97a"))
			for x in [-10, 0, 10]:
				c.draw_line(Vector2(x * 0.5, -4), Vector2(x, -34), Color("5a9a4a"), 3.0)
				for k in 4:
					c.draw_circle(Vector2(x, -18 - k * 6), 4.5 - k * 0.5, Color("c9b6ff"))
		"Poppy Seeds":
			_leaves(c, LEAF)
			c.draw_line(Vector2(0, -4), Vector2(0, -22), Color("5a9a4a"), 3.0)
			for k in 5:
				var a := TAU * k / 5.0
				c.draw_circle(Vector2(0, -28) + Vector2(cos(a), sin(a)) * 9, 9, Color("ff5d73"))
			c.draw_circle(Vector2(0, -28), 6, Color("35303a"))
			for k in 4:
				c.draw_circle(Vector2(14 + k * 3, -6 + (k % 2) * 3), 2, Color("35303a"))
		"Cobwebs":
			c.draw_line(Vector2(-22, 0), Vector2(18, -40), Color("8a5a35"), 4.0)
			for r in [8.0, 15.0, 22.0]:
				var ring := PackedVector2Array()
				for k in 9:
					var a := TAU * k / 8.0
					ring.append(Vector2(0, -20) + Vector2(cos(a), sin(a)) * r)
				c.draw_polyline(ring, Color(1, 1, 1, 0.95), 2.0)
			for k in 8:
				var a := TAU * k / 8.0
				c.draw_line(Vector2(0, -20), Vector2(0, -20) + Vector2(cos(a), sin(a)) * 22, Color(1, 1, 1, 0.95), 1.5)
		"Watermint":
			for p in [Vector2(-12, -10), Vector2(12, -10), Vector2(-6, -24), Vector2(8, -26), Vector2(0, -38)]:
				c.draw_circle(p, 10, OUTLINE)
				c.draw_circle(p, 8.5, Color("7fe0c0"))
				c.draw_line(p + Vector2(-4, 3), p + Vector2(4, -3), Color("3fa08a"), 1.5)
		"Honey":
			c.draw_colored_polygon(Fx.ellipse_points(Vector2(0, -6), Vector2(26, 9)), Color("5a9a4a"))
			c.draw_colored_polygon(Fx.ellipse_points(Vector2(0, -18), Vector2(17, 15)), OUTLINE)
			c.draw_colored_polygon(Fx.ellipse_points(Vector2(0, -18), Vector2(15, 13)), Color("ffc93f"))
			c.draw_circle(Vector2(-5, -23), 4, Color("fff0a8"))
			c.draw_circle(Vector2(12, -4), 4, Color("ffc93f"))
	c.draw_set_transform(Vector2.ZERO)


static func _leaves(c: CanvasItem, color: Color) -> void:
	for a in [-0.9, -0.3, 0.3, 0.9]:
		var tip := Vector2(sin(a) * 22, -6 - cos(a) * 8)
		c.draw_colored_polygon(Fx.ellipse_points(tip * 0.6, Vector2(12, 5)), color.darkened(0.15))
	c.draw_colored_polygon(Fx.ellipse_points(Vector2(0, -2), Vector2(20, 6)), color)
