extends Node2D
## Herb hunting for medicine cats: walk around the forest, find the sparkly herbs on
## Spottedleaf's list and press SPACE to pick them. Watch out for deathberries!
## Used for the herb lesson, and for gathering herbs as much as you like later.

const MEADOW := Rect2(80, 250, 1120, 440)
const PICK_DISTANCE := 70.0
const HOME_TUNNEL := Vector2(70, 465)  # free gathering: walk in here to go home
const BERRY_BUSHES := [Vector2(980, 330), Vector2(330, 620)]

const SETUPS := {
	"herb_lesson": {
		"list": {"Marigold": 2, "Catmint": 2, "Cobwebs": 1, "Watermint": 1}, "watcher": "Spottedleaf",
		"intro": "Find the herbs on Spottedleaf's list! Walk up to a sparkly plant and press SPACE to pick it.\n\nBut never touch the red deathberries!",
	},
	"gather_herbs": {
		"list": {}, "watcher": "", "free": true,
		"intro": "Gather as many herbs as you like for the medicine den!\n\nWhen you're done, walk into the tunnel on the left to go home.",
	},
}

var _setup: Dictionary
var _world: Node2D
var _player: TopDownPlayer
var _cinderpaw: Follower
var _watcher: Npc
var _plants: Array = []  # {pos, kind}
var _picked := {}  # kind -> how many
var _playing := false
var _card: InfoCard
var _dialog: DialogBox
var _list_label: Label
var _prompt: Label
var _camera: Camera2D
var _decor: Array = []
var _time := 0.0
var _berry_warned := 0.0


func _ready() -> void:
	_setup = SETUPS.get(GameState.current_id(), SETUPS.herb_lesson)
	seed(21)
	for i in 90:
		_decor.append(Vector3(randf_range(20, 1260), randf_range(170, 710), randi() % 5))
	randomize()

	_camera = Camera2D.new()
	_camera.position = Vector2(640, 360)
	add_child(_camera)
	_world = Node2D.new()
	_world.y_sort_enabled = true
	add_child(_world)

	_player = TopDownPlayer.new()
	_player.position = Vector2(640, 600)
	_player.bounds = MEADOW
	_player.speed = 250.0
	_player.frozen = true
	_world.add_child(_player)
	if GameState.apprentice_following():
		_cinderpaw = Follower.make("Cinderkit", _player, 90.0)
		_cinderpaw.cat.size = 0.72
		_world.add_child(_cinderpaw)
	if _setup.watcher != "":
		_watcher = Npc.make(_setup.watcher)
		_watcher.position = Vector2(170, 300)
		_world.add_child(_watcher)

	for kind in HerbArt.GROWING:
		for k in 3:
			_grow_plant(kind)

	var hud := CanvasLayer.new()
	add_child(hud)
	var panel := Panel.new()
	panel.position = Vector2(930, 12)
	panel.size = Vector2(336, 58 + _setup.list.size() * 37)
	panel.add_theme_stylebox_override("panel", Fx.cute_panel(18))
	hud.add_child(panel)
	_list_label = Fx.ink_label("", 24)
	_list_label.position = Vector2(18, 10)
	panel.add_child(_list_label)
	_update_list()
	_prompt = Fx.make_label("SPACE = pick", 22, Color("c9f7a8"), 6)
	_prompt.size = Vector2(200, 30)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.z_index = 10
	add_child(_prompt)

	_dialog = DialogBox.new()
	add_child(_dialog)
	_card = InfoCard.new()
	add_child(_card)
	var title: String = "Gathering Herbs!" if _setup.has("free") else GameState.current().get("title", "Herb Hunting!")
	_card.show_card(title, _setup.intro, "Press SPACE to start!")
	await _card.closed
	if _watcher:
		_dialog.say([["Spottedleaf", "Marigold has orange flowers. Catmint has purple ones. Cobwebs hang on twigs, and watermint has round leaves!"]])
		await _dialog.finished
	_playing = true
	_player.frozen = false


## A new herb plant somewhere in the forest (not on top of another one)
func _grow_plant(kind: String) -> void:
	for tries in 30:
		var pos := Vector2(randf_range(240, 1150), randf_range(300, 660))
		var crowded := pos.distance_to(_player.position) < 120
		for p in _plants:
			crowded = crowded or p.pos.distance_to(pos) < 90
		for b in BERRY_BUSHES:
			crowded = crowded or b.distance_to(pos) < 110
		if not crowded:
			_plants.append({"pos": pos, "kind": kind})
			return


func _process(delta: float) -> void:
	_time += delta
	_berry_warned -= delta
	queue_redraw()
	_prompt.visible = false
	if not _playing or _dialog.is_open():
		_player.frozen = _playing and _dialog.is_open()
		return
	_player.frozen = false
	var paws := _player.position
	var nearest := {}
	var best := PICK_DISTANCE
	for p in _plants:
		if p.pos.distance_to(paws) < best:
			best = p.pos.distance_to(paws)
			nearest = p
	if not nearest.is_empty():
		_prompt.visible = true
		_prompt.text = "SPACE = pick %s" % nearest.kind
		_prompt.position = nearest.pos + Vector2(-100, 6)
		if Input.is_action_just_pressed("jump"):
			_pick(nearest)
	for b in BERRY_BUSHES:
		if b.distance_to(paws) < 85 and _berry_warned <= 0.0:
			_berries()
	if _cinderpaw and randf() < 0.004:
		for p in _plants:
			if p.pos.distance_to(_cinderpaw.position) < 160:
				_cinderpaw.cat.bounce(0.4)
				Fx.speech(_cinderpaw, "I found %s!" % p.kind, 100.0, 1.4)
				_pick(p)
				break
	if _setup.has("free") and paws.distance_to(HOME_TUNNEL) < 90:
		_go_home()


func _pick(plant: Dictionary) -> void:
	var kind: String = plant.kind
	var wanted: int = _setup.list.get(kind, 0)
	if not _setup.has("free") and _picked.get(kind, 0) >= wanted:
		Sfx.play("click", 0.8)
		var why := "We don't need %s today." % kind if wanted == 0 else "We have enough %s now!" % kind
		Fx.popup_text(self, plant.pos + Vector2(0, -60), why, Color("fff6ec"), 24)
		return
	_plants.erase(plant)
	_picked[kind] = _picked.get(kind, 0) + 1
	Sfx.play("collect")
	Fx.burst(self, plant.pos + Vector2(0, -20), Color("c9f7a8"), 18)
	Fx.hearts(self, plant.pos + Vector2(0, -30), 5)
	Fx.popup_text(self, plant.pos + Vector2(0, -70), "+ " + kind, Color("ffd966"))
	_player.cat.bounce(0.3)
	if _watcher:
		_watcher.cat.bounce(0.25)
	_update_list()
	if not _setup.has("free") and _list_done():
		_win()
		return
	await get_tree().create_timer(1.5).timeout
	if _playing:
		_grow_plant(kind)


func _berries() -> void:
	_berry_warned = 6.0
	Sfx.play("hurt", 1.3, -6.0)
	var who := "Spottedleaf" if _watcher else "Cinderpaw" if _cinderpaw else GameState.cat_name()
	var text := "Careful! Those red berries are deathberries. Never eat them! Let's leave them alone." if who != GameState.cat_name() \
			else "Those red berries are deathberries. I'd better not touch them!"
	_dialog.say([[who, text]])


func _list_done() -> bool:
	for kind in _setup.list:
		if _picked.get(kind, 0) < _setup.list[kind]:
			return false
	return true


func _update_list() -> void:
	if _setup.has("free"):
		var total := 0
		for kind in _picked:
			total += _picked[kind]
		_list_label.text = "Herbs gathered: %d" % total
		return
	var text := "Spottedleaf's list:"
	for kind in _setup.list:
		var have := mini(_picked.get(kind, 0), _setup.list[kind])
		text += "\n%s %s  %d / %d" % ["[x]" if have >= _setup.list[kind] else "[  ]", kind, have, _setup.list[kind]]
	_list_label.text = text


func _go_home() -> void:
	_playing = false
	_player.frozen = true
	Sfx.play("win")
	var total := 0
	for kind in _picked:
		total += _picked[kind]
	var body := "You didn't find any herbs this time. Better luck next time!" if total == 0 else \
			"You gathered %d herbs!\nThe medicine den smells wonderful." % total
	_card.show_card("Back to Camp!", body, "Press SPACE")
	await _card.closed
	GameState.finish_activity()


func _win() -> void:
	_playing = false
	_player.frozen = true
	Sfx.play("win")
	Fx.confetti(self, Vector2(640, 300), 80)
	await get_tree().create_timer(1.0).timeout
	_dialog.say(Story.lines([["Spottedleaf", "You found everything on the list, {paw}! You have a great nose for herbs."]]))
	await _dialog.finished
	_card.show_card("Great Herb Hunting!", "You found all the herbs on Spottedleaf's list!\nNow the medicine den is ready to help sick cats.",
			"Press SPACE to go back to camp")
	await _card.closed
	GameState.complete_step()


func _draw() -> void:
	var grass := Color("8fca72")
	Scenery.sky(self, Color("bfe6ff"), Color("fde7f0"), Rect2(0, 0, 1280, 200))
	for i in 9:
		Scenery.tree(self, Vector2(i * 160 - 20, 200), 0.75 + (i % 2) * 0.15, Color("6fb85a"), Color("a0704e"))
	draw_rect(Rect2(0, 170, 1280, 550), grass)
	for d in _decor:
		var pos := Vector2(d.x, d.y)
		match int(d.z):
			0, 1, 2: Scenery.grass_tuft(self, pos, grass.darkened(0.2))
			3: Scenery.flower(self, pos, Color("f7a8c8"))
			4: Scenery.flower(self, pos, Color("fff3a0"))
	for b in BERRY_BUSHES:
		Scenery.bush(self, b, 1.0, Color("2f5a3a"))
		for k in 7:
			draw_circle(b + Vector2(-26 + k * 9, -24 - (k % 3) * 9), 5, Color("d62839"))
		draw_string(ThemeDB.fallback_font, b + Vector2(-80, 30), "Deathberries!", HORIZONTAL_ALIGNMENT_CENTER, 160, 20, Color("8a1a2a"))
	for p in _plants:
		var pulse := 0.5 + 0.5 * sin(_time * 3.0 + p.pos.x)
		draw_circle(p.pos + Vector2(0, -16), 34 + pulse * 6, Color(1, 1, 0.8, 0.22))
		HerbArt.draw(self, p.pos, p.kind, 1.2)
		Scenery.star(self, p.pos + Vector2(20, -44 - pulse * 6), 5, Color(1, 1, 0.8, 0.6 + 0.4 * pulse))
	for p in [Vector2(40, 720), Vector2(1240, 720), Vector2(1250, 400)]:
		Scenery.bush(self, p, 1.3, Color("6fb85a"))  # no berries, so they don't look like deathberries
	if _setup.has("free"):
		# The gorse tunnel back to camp
		for k in 7:
			var a := PI + PI * k / 6.0
			draw_circle(HOME_TUNNEL + Vector2(cos(a) * 60, sin(a) * 70), 26, Color("4f8f45"))
			draw_circle(HOME_TUNNEL + Vector2(cos(a) * 60, sin(a) * 70) + Vector2(8, -10), 5, Color("ffd23f"))
		draw_colored_polygon(Fx.ellipse_points(HOME_TUNNEL + Vector2(0, -10), Vector2(38, 45)), Color("3a2a2a"))
		draw_string(ThemeDB.fallback_font, HOME_TUNNEL + Vector2(-40, 70), "Camp", HORIZONTAL_ALIGNMENT_CENTER, 120, 26, Fx.INK)
	else:
		Scenery.bush(self, Vector2(30, 420), 1.3, Color("6fb85a"))
