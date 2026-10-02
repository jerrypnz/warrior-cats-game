extends Node2D
## Chapter 1: you're a kittypet in a Twoleg garden, dreaming of the forest beyond the fence.

const GARDEN := Rect2(90, 330, 1150, 350)
const FENCE_X := 1180.0
const GAP := Vector2(410, 530)  # the hole in the fence (top and bottom y)
const BOWL := Vector2(330, 420)

var _world: Node2D
var _player: TopDownPlayer
var _smudge: Npc
var _dialog: DialogBox
var _card: InfoCard
var _bowl_prompt: Label
var _busy := true
var _decor: Array = []


func _ready() -> void:
	seed(21)
	for i in 50:
		_decor.append(Vector3(randf_range(100, 1150), randf_range(360, 700), randi() % 6))
	randomize()

	_world = Node2D.new()
	_world.y_sort_enabled = true
	add_child(_world)
	_player = TopDownPlayer.new()
	_player.position = Vector2(420, 470)
	_player.bounds = Rect2(GARDEN.position, GARDEN.size + Vector2(60, 0))
	_player.blockers = [Rect2(FENCE_X - 25, 300, 50, GAP.x - 300), Rect2(FENCE_X - 25, GAP.y, 50, 300),
			Rect2(BOWL.x - 30, BOWL.y - 16, 60, 20)]
	_player.frozen = true
	_world.add_child(_player)
	_smudge = Npc.make("Smudge", -1.0)
	_smudge.position = Vector2(840, 420)
	_world.add_child(_smudge)

	_bowl_prompt = Fx.make_label("SPACE = look", 22, Color("c9f7a8"), 6)
	_bowl_prompt.position = BOWL + Vector2(-80, 14)
	_bowl_prompt.size = Vector2(160, 30)
	_bowl_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_bowl_prompt)

	var hud := CanvasLayer.new()
	add_child(hud)
	var goal := Fx.centered_label("Talk to Smudge, then sneak through the hole in the fence!", 26,
			Color("c9f7a8"), 680)
	hud.add_child(goal)

	_dialog = DialogBox.new()
	add_child(_dialog)
	_card = InfoCard.new()
	add_child(_card)
	_card.show_card(GameState.current().title,
			"You are %s, a kittypet who lives with your Twolegs.\n\nBut every night you dream about the wild forest on the other side of the fence..." % GameState.KITTYPET_NAME)
	await _card.closed
	_busy = false


func _process(_delta: float) -> void:
	queue_redraw()
	var can_act := not (_busy or _dialog.is_open() or Transition.is_busy())
	_player.frozen = not can_act
	var near_smudge := can_act and _player.position.distance_to(_smudge.position) < 120
	var near_bowl := can_act and not near_smudge and _player.position.distance_to(BOWL) < 100
	_smudge.show_prompt(near_smudge)
	_bowl_prompt.visible = near_bowl
	if not can_act:
		return
	if Input.is_action_just_pressed("jump"):
		if near_smudge:
			_smudge.face_toward(_player.position)
			_dialog.say(Story.lines([
				["Smudge", "Hi {kp}! Are you staring at the forest AGAIN?"],
				["Smudge", "Don't go in there! Wild cats live in the forest. I heard they eat rabbits AND bones!"],
				["{kp}", "But it smells so exciting... I just want to see it once!"],
			]))
		elif near_bowl:
			_dialog.say(Story.lines([["{kp}", "Crunchy kittypet food. Yum... but it's not as exciting as REAL prey!"]]))
	if _player.position.x > FENCE_X + 30:
		_leave_garden()


func _leave_garden() -> void:
	_busy = true
	_player.cat.bounce(0.3)
	Sfx.play("powerup")
	_dialog.say(Story.lines([["{kp}", "The forest! It smells like leaves and mice and adventure!"],
			["{kp}", "Wait... what's that rustling? A MOUSE!"]]))
	await _dialog.finished
	GameState.complete_step()


func _draw() -> void:
	# Forest behind the fence
	draw_rect(Rect2(0, 0, 1280, 720), Color("4f8a43"))
	for i in 12:
		Scenery.tree(self, Vector2(i * 120 - 10, 250), 0.9 + (i % 3) * 0.1, Color("5f9e4f"))
	for y in range(260, 720, 90):
		Scenery.tree(self, Vector2(1250 + (y % 180) * 0.1, y + 60), 0.7, Color("5f9e4f"))
	# Lawn
	draw_rect(Rect2(0, 300, FENCE_X, 420), Color("a8dc7a"))
	for x in range(0, int(FENCE_X), 80):
		draw_rect(Rect2(x, 300, 40, 420), Color("b4e388"))
	# Twoleg house
	var house := Rect2(60, 40, 520, 290)
	draw_rect(house.grow(4), Scenery.OUTLINE)
	draw_rect(house, Color("fde7d0"))
	draw_colored_polygon(PackedVector2Array([Vector2(30, 60), Vector2(320, -60), Vector2(610, 60)]), Color("e0628a"))
	for wx in [110, 410]:
		draw_rect(Rect2(wx, 110, 110, 90).grow(4), Scenery.OUTLINE)
		draw_rect(Rect2(wx, 110, 110, 90), Color("bfe6ff"))
		draw_line(Vector2(wx + 55, 110), Vector2(wx + 55, 200), Color.WHITE, 4.0)
		draw_rect(Rect2(wx - 8, 196, 126, 14), Color("f7a1bd"))
	draw_rect(Rect2(270, 190, 90, 140).grow(4), Scenery.OUTLINE)
	draw_rect(Rect2(270, 190, 90, 140), Color("a06a42"))
	draw_circle(Vector2(345, 265), 6, Color("ffd23f"))
	# Paths, flowers and bushes
	draw_colored_polygon(Fx.ellipse_points(Vector2(315, 345), Vector2(90, 22)), Color("e9d3b0"))
	for d in _decor:
		var colors := [Color("ff8fab"), Color("ffd23f"), Color("c77dff"), Color("fbf8f2")]
		if int(d.z) < 4:
			Scenery.flower(self, Vector2(d.x, d.y), colors[int(d.z)])
		else:
			Scenery.grass_tuft(self, Vector2(d.x, d.y), Color("8cc95e"))
	Scenery.bush(self, Vector2(640, 330), 1.1, Color("6fb85a"), true)
	Scenery.bush(self, Vector2(120, 700), 1.2, Color("6fb85a"), true)
	# Food bowl
	draw_colored_polygon(Fx.ellipse_points(BOWL, Vector2(30, 12)), Scenery.OUTLINE)
	draw_colored_polygon(Fx.ellipse_points(BOWL, Vector2(27, 10)), Color("6fb3f0"))
	draw_colored_polygon(Fx.ellipse_points(BOWL + Vector2(0, -4), Vector2(20, 6)), Color("c88a5a"))
	# Wooden fence with a hole in it
	for y in range(300, 720, 34):
		if y > GAP.x - 20 and y < GAP.y:
			continue
		draw_rect(Rect2(FENCE_X - 18, y, 36, 30).grow(2), Scenery.OUTLINE)
		draw_rect(Rect2(FENCE_X - 18, y, 36, 30), Color("d9a066"))
	var glow := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 300.0)
	draw_circle(Vector2(FENCE_X + 30, (GAP.x + GAP.y) / 2.0), 40 + glow * 8, Color(1, 1, 0.6, 0.2))
