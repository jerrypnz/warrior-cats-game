extends Node2D
## Inside a den! Cats nap in mossy nests. Visit your own nest to take a nap,
## or look at the herbs in the medicine den. Walk out the bottom to go back to camp.

const INSIDE := Rect2(150, 250, 980, 420)  # oval you can walk in
const EXIT := Vector2(640, 668)
const NAP_DREAMS := [
	"You dreamed you were chasing a giant, fluffy mouse!",
	"You dreamed you could swim like a RiverClan cat!",
	"You dreamed about StarClan, twinkling in the sky and watching over you.",
	"You dreamed about a mountain made of fresh-kill. Yum!",
	"You dreamed you were leader of ThunderClan!",
]
# For each den: cats [name, place, sleeping?], nests [place, label], herbs [place, name, what it does]
const DENS := {
	"warriors": {
		"title": "Warriors' Den", "wall": Color("4f8a45"),
		"cats": [["Whitestorm", Vector2(300, 400), true], ["Mousefur", Vector2(980, 400), true],
				["Darkstripe", Vector2(840, 580), false]],
		"nests": [[Vector2(300, 400), ""], [Vector2(980, 400), ""], [Vector2(520, 330), "Lionheart's nest"],
				[Vector2(760, 330), "Tigerclaw's nest"], [Vector2(330, 570), "Longtail's nest"]],
	},
	"apprentices": {
		"title": "Apprentices' Den", "wall": Color("5f9e4f"),
		"cats": [],
		"nests": [[Vector2(320, 400), "Graypaw's nest"], [Vector2(560, 330), "Ravenpaw's nest"],
				[Vector2(800, 330), "Sandpaw's nest"], [Vector2(980, 430), "Dustpaw's nest"]],
	},
	"nursery": {
		"title": "Nursery", "wall": Color("6fa85f"),
		"cats": [["Goldenflower", Vector2(520, 420), true], ["Thornkit", Vector2(600, 440), true],
				["Brackenkit", Vector2(780, 540), false]],
		"nests": [[Vector2(540, 425), "Goldenflower's nest"], [Vector2(880, 380), "Frostfur's nest"]],
	},
	"elders": {
		"title": "Elders' Den", "wall": Color("7a8f4a"),
		"cats": [["One-eye", Vector2(320, 410), true], ["Patchpelt", Vector2(960, 410), true],
				["Halftail", Vector2(640, 540), false]],
		"nests": [[Vector2(320, 410), ""], [Vector2(960, 410), ""], [Vector2(640, 340), "Smallear's nest"]],
	},
	"medicine": {
		"title": "Medicine Den", "wall": Color("5f8a7a"),
		"cats": [],
		"nests": [[Vector2(900, 420), "Spottedleaf's nest"]],
		"herbs": [[Vector2(260, 360), "Marigold", "Marigold leaves help scratches heal."],
				[Vector2(420, 300), "Poppy Seeds", "Poppy seeds help a sore cat fall asleep."],
				[Vector2(600, 290), "Catmint", "Catmint helps a cat with a cough feel better."],
				[Vector2(780, 300), "Honey", "Honey soothes a sore throat. Sweet!"],
				[Vector2(300, 520), "Cobwebs", "Cobwebs go on cuts to help them stop hurting."]],
	},
}

var _den: Dictionary
var _world: Node2D
var _player: TopDownPlayer
var _cinderpaw: Follower
var _cats: Array[Npc] = []
var _spots: Array = []  # things you can use: {pos, prompt, what}
var _prompt: Label
var _dialog: DialogBox
var _dark: CanvasModulate
var _busy := false
var _my_nest := Vector2.INF


func _ready() -> void:
	_den = DENS.get(GameState.den, DENS.warriors)
	_dark = CanvasModulate.new()
	add_child(_dark)
	var floor_things := Node2D.new()  # nests go under the cats
	add_child(floor_things)
	_world = Node2D.new()
	_world.y_sort_enabled = true
	add_child(_world)

	var nests: Array = _den.nests.duplicate()
	var home := "warriors" if GameState.is_warrior() else "apprentices"
	if GameState.den == home:
		_my_nest = Vector2(640, 470)
		nests.append([_my_nest, "Your nest"])
		_spots.append({"pos": _my_nest, "prompt": "SPACE = nap", "what": "nap"})
	if GameState.den == "apprentices" and GameState.has_apprentice:
		nests.append([Vector2(420, 560), "Cinderpaw's nest"])
	for n in nests:
		var nest := Nest.new()
		nest.position = n[0]
		nest.label = n[1]
		floor_things.add_child(nest)
	for herb in _den.get("herbs", []):
		_spots.append({"pos": herb[0], "prompt": "SPACE = look", "what": "herb", "herb": herb})

	for c in _den.cats:
		var npc := Npc.make(c[0], [-1.0, 1.0].pick_random())
		npc.position = c[1]
		npc.cat.sleeping = c[2]
		_world.add_child(npc)
		_cats.append(npc)
		_spots.append({"pos": npc.position, "prompt": "SPACE = talk", "what": "cat", "npc": npc})

	_player = TopDownPlayer.new()
	_player.position = EXIT + Vector2(0, -50)
	_player.bounds = INSIDE
	_player.round_bounds = true
	_world.add_child(_player)
	if GameState.has_apprentice:
		_cinderpaw = Follower.make("Cinderkit", _player, 90.0)
		_cinderpaw.cat.size = 0.72
		_world.add_child(_cinderpaw)

	_prompt = Fx.make_label("", 22, Color("c9f7a8"), 6)
	_prompt.size = Vector2(240, 30)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.z_index = 10
	add_child(_prompt)
	var hud := CanvasLayer.new()
	add_child(hud)
	hud.add_child(Fx.centered_label(_den.title, 40, Color("ffd966"), 14))
	hud.add_child(Fx.centered_label("Walk out the bottom to go back to camp", 22, Color("fff6ec"), 686))
	_dialog = DialogBox.new()
	add_child(_dialog)


func _process(_delta: float) -> void:
	queue_redraw()
	if _busy or _dialog.is_open() or Transition.is_busy():
		_player.frozen = true
		_prompt.visible = false
		return
	_player.frozen = false
	var spot := _nearest_spot()
	_prompt.visible = not spot.is_empty()
	if not spot.is_empty():
		_prompt.text = spot.prompt
		_prompt.position = spot.pos + Vector2(-120, 12)
		if Input.is_action_just_pressed("jump"):
			_use(spot)
	if _player.position.y > EXIT.y - 12 and absf(_player.position.x - EXIT.x) < 90:
		GameState.just_finished = "den"
		Sfx.play("click")
		Transition.go("res://scenes/camp.tscn")


func _nearest_spot() -> Dictionary:
	var best := {}
	var best_d := 90.0
	for spot in _spots:
		var d: float = spot.pos.distance_to(_player.position)
		if d < best_d:
			best_d = d
			best = spot
	if _cinderpaw and _cinderpaw.position.distance_to(_player.position) < best_d:
		best = {"pos": _cinderpaw.position, "prompt": "SPACE = talk", "what": "cinderpaw"}
	return best


func _use(spot: Dictionary) -> void:
	match spot.what:
		"nap":
			_nap()
		"herb":
			Sfx.play("select")
			_dialog.say([[spot.herb[1], spot.herb[2]]])
		"cinderpaw":
			_dialog.say(Story.lines([["Cinderpaw", Story.DEN_CHATS.Cinderpaw.pick_random()]]))
		"cat":
			var npc: Npc = spot.npc
			if npc.cat.sleeping:
				Fx.popup_text(self, npc.position + Vector2(0, -90), "Shh! %s is sleeping." % npc.npc_name,
						Color("c9f7a8"), 24)
			else:
				npc.face_toward(_player.position)
				var lines: Array = Story.DEN_CHATS.get(npc.npc_name, ["Hello!"])
				_dialog.say(Story.lines([[npc.npc_name, lines.pick_random()]]))


func _nap() -> void:
	_busy = true
	_dialog.ask(GameState.cat_name(), "Take a nap in your cozy nest?", ["Yes, nap time!", "Not now"])
	var pick: int = await _dialog.chosen
	if pick != 0:
		_busy = false
		return
	_player.position = _my_nest + Vector2(0, 8)
	_player.cat.sleeping = true
	var dim := create_tween()
	dim.tween_property(_dark, "color", Color("4a4a7a"), 1.0)
	await get_tree().create_timer(2.5).timeout
	_dialog.say([["", NAP_DREAMS.pick_random()]])
	await _dialog.finished
	var wake := create_tween()
	wake.tween_property(_dark, "color", Color.WHITE, 0.8)
	await wake.finished
	_player.cat.sleeping = false
	_player.cat.bounce(0.35)
	Sfx.play("powerup")
	Fx.hearts(self, _player.position + Vector2(0, -60), 10)
	Fx.popup_text(self, _player.position + Vector2(0, -130), "What a lovely nap!", Color("ffd966"), 26)
	_busy = false


func _draw() -> void:
	var wall: Color = _den.wall
	draw_rect(Rect2(0, 0, 1280, 720), wall.darkened(0.45))
	# Leafy walls curving overhead
	for i in 40:
		var a := PI + PI * i / 39.0
		var p := Vector2(640, 520) + Vector2(cos(a) * 640, sin(a) * 420)
		draw_circle(p, 70, wall.darkened(0.15))
		draw_circle(p + Vector2(-8, -8), 50, wall)
	# Sunlight coming through the leaves
	for x in [380.0, 700.0, 960.0]:
		draw_colored_polygon(PackedVector2Array([Vector2(x - 20, 120), Vector2(x + 20, 120), Vector2(x + 90, 640),
				Vector2(x - 10, 640)]), Color(1, 0.95, 0.7, 0.08))
	# The floor
	draw_colored_polygon(Fx.ellipse_points(Vector2(640, 460), Vector2(520, 240), 48), Color("c9a86a"))
	draw_colored_polygon(Fx.ellipse_points(Vector2(640, 465), Vector2(500, 225), 48), Color("e3c896"))
	# Way out
	draw_colored_polygon(Fx.ellipse_points(EXIT + Vector2(0, 30), Vector2(90, 50)), Color("f3dfb5"))
	draw_string(ThemeDB.fallback_font, EXIT + Vector2(-60, 10), "To camp", HORIZONTAL_ALIGNMENT_CENTER, 120, 22, Fx.INK)
	for herb in _den.get("herbs", []):
		var p: Vector2 = herb[0]
		draw_colored_polygon(Fx.ellipse_points(p + Vector2(0, 4), Vector2(46, 14)), Color("8e8aa0"))
		for k in 5:
			var leaf := p + Vector2(-24 + k * 12, -6 - (k % 2) * 6)
			draw_colored_polygon(Fx.ellipse_points(leaf, Vector2(9, 5)), Color("6fb85a").darkened(k * 0.05))
		var flower: Color = {"Marigold": Color("ff9f43"), "Poppy Seeds": Color("ff5d73"), "Catmint": Color("c9b6ff"),
				"Honey": Color("ffd23f"), "Cobwebs": Color("f3f3f3")}.get(herb[1], Color.WHITE)
		Scenery.flower(self, p + Vector2(0, -18), flower)
		draw_string(ThemeDB.fallback_font, p + Vector2(-70, 40), herb[1], HORIZONTAL_ALIGNMENT_CENTER, 140, 20, Fx.INK)


class Nest extends Node2D:
	## A soft mossy nest to sleep in
	var label := ""

	func _draw() -> void:
		draw_colored_polygon(Fx.ellipse_points(Vector2.ZERO, Vector2(62, 24)), Color("4f8a45"))
		draw_colored_polygon(Fx.ellipse_points(Vector2(0, -2), Vector2(52, 18)), Color("7cc26a"))
		draw_colored_polygon(Fx.ellipse_points(Vector2(0, 0), Vector2(40, 12)), Color("9ed27c"))
		draw_line(Vector2(30, -8), Vector2(48, -18), Color.WHITE, 3.0)  # a feather
		if label != "":
			draw_string(ThemeDB.fallback_font, Vector2(-90, 46), label, HORIZONTAL_ALIGNMENT_CENTER, 180, 18, Fx.INK)
