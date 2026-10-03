extends Node2D
## Hunting: sneak up on mice and pounce on them! Used for three parts of the story:
## your very first mouse, Bluestar's hunting lesson, and feeding hungry Yellowfang.

const MEADOW := Rect2(80, 250, 1120, 440)
const CATCH_DISTANCE := 70.0
const SCARE_DISTANCE := 115.0

const HOME_TUNNEL := Vector2(70, 465)  # free hunting: walk in here to go home
const SETUPS := {
	"free_hunt": {
		"goal": 9999, "place": "forest", "watcher": "", "mice": 6, "free": true,
		"intro": "Hunt as much as you like! Every mouse goes to the fresh-kill pile.\n\nWhen you're done, walk into the tunnel on the left to go home.",
		"score": "Prey caught: %d",
	},
	"first_mouse": {
		"goal": 1, "place": "forest", "watcher": "", "mice": 2,
		"intro": "The forest is full of amazing smells... and a MOUSE!\n\nYou've never hunted before. Creep up close, then press SPACE to POUNCE!",
		"score": "Catch your first mouse!",
		"outro": [["{kp}", "I did it! My very first mouse!"],
				["???", "Hey, kittypet! What are you doing in OUR forest?!"]],
	},
	"hunt_lesson": {
		"goal": 5, "place": "meadow", "watcher": "Bluestar", "mice": 6,
		"intro": "Sneak up close to a mouse, then press SPACE to POUNCE!\n\nIf you run too close, the mouse will scurry away. Catch 5 mice for the elders!",
		"score": "Mice caught: %d / %d",
		"card": ["Great Hunting!", "You caught 5 mice for the Clan!\nBluestar is really proud of you!"],
	},
	"yellowfang": {
		"goal": 3, "place": "snakerocks", "watcher": "Yellowfang", "mice": 5,
		"intro": "You're hunting alone near Snakerocks today.\n\nSneak up on the mice and press SPACE to pounce!",
		"score": "Mice for Yellowfang: %d / %d",
		"before": [["Yellowfang", "Grrr! Who's there?! Stay back, ThunderClan cat!"],
				["{paw}", "You're hurt! And you look really hungry..."],
				["Yellowfang", "Hmph. I'm Yellowfang. I used to live in ShadowClan. My leg hurts too much to hunt."],
				["{paw}", "Don't worry, I'll catch some mice for you!"]],
		"outro": [["Yellowfang", "Mmm... thank you, young one. Maybe not ALL ThunderClan cats are bad."],
				["Bluestar", "{paw}! Who is this? A ShadowClan cat in our territory?"],
				["{paw}", "She's hurt, Bluestar. Please, can she come back to camp with us?"],
				["Bluestar", "Helping a cat in need... that's what a true warrior does. Very well, Yellowfang may come."]],
	},
}

var _setup: Dictionary
var _world: Node2D
var _player: TopDownPlayer
var _helpers: Array[Follower] = []  # Cinderpaw and friends who hunt with you
var _watcher: Npc
var _mice: Array[Mouse] = []
var _caught := 0
var _playing := false
var _card: InfoCard
var _dialog: DialogBox
var _score_label: Label
var _camera: Camera2D
var _decor: Array = []


func _ready() -> void:
	_setup = SETUPS.get(GameState.current_id(), SETUPS.hunt_lesson)
	seed(5)
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
	_player.can_pounce = true
	_player.frozen = true
	_world.add_child(_player)

	if GameState.activity == "free_hunt" and GameState.apprentice_following():
		var cinderpaw := Follower.make("Cinderkit", _player, 90.0)
		cinderpaw.cat.size = 0.72
		_helpers.append(cinderpaw)
	if GameState.activity == "free_hunt" and GameState.hunt_buddy >= 0:
		# A friend from another save slot came along!
		var friend := GameState.describe_slot(GameState.hunt_buddy)
		if not friend.is_empty():
			_helpers.append(Follower.make_custom(friend.name, friend.look, friend.size, _player, 180.0, friend.paint))
	for helper in _helpers:
		_world.add_child(helper)
	if _setup.watcher != "":
		_watcher = Npc.make(_setup.watcher)
		_watcher.position = Vector2(640, 300) if _setup.place == "snakerocks" else Vector2(110, 280)
		_world.add_child(_watcher)

	for i in _setup.mice:
		_spawn_mouse(Vector2(randf_range(250, 1100), randf_range(330, 560)))

	var hud := CanvasLayer.new()
	add_child(hud)
	_score_label = Fx.centered_label("", 38, Color.WHITE, 30)
	hud.add_child(_score_label)
	_update_score()

	_dialog = DialogBox.new()
	add_child(_dialog)
	_card = InfoCard.new()
	add_child(_card)
	var title: String = "Hunting!" if _setup.has("free") else GameState.current().get("title", "Hunting!")
	_card.show_card(title, _setup.intro, "Press SPACE to start!")
	await _card.closed
	if _setup.has("before"):
		_dialog.say(Story.lines(_setup.before))
		await _dialog.finished
	_playing = true
	_player.frozen = false


func _spawn_mouse(pos: Vector2) -> void:
	var mouse := Mouse.new()
	mouse.position = pos
	mouse.bounds = MEADOW
	mouse.scale = Vector2(1.4, 1.4)
	_world.add_child(mouse)
	_mice.append(mouse)


func _process(_delta: float) -> void:
	if not _playing:
		return
	var paws := _player.global_position
	for mouse: Mouse in _mice.duplicate():
		var d := mouse.global_position.distance_to(paws)
		if _player.is_pouncing() and d < CATCH_DISTANCE:
			_catch(mouse)
		elif not _player.is_pouncing() and d < SCARE_DISTANCE and _player.cat.walk_amount > 0.3:
			mouse.scare(paws)
		else:
			for helper in _helpers:
				if mouse.global_position.distance_to(helper.position) < 60 and randf() < 0.02:
					helper.cat.bounce(0.4)
					Fx.speech(helper, "I got one!", 112 * helper.cat.size, 1.2)
					_catch(mouse)
					break
	if _setup.has("free") and _player.position.distance_to(HOME_TUNNEL) < 90:
		_go_home()


func _catch(mouse: Mouse) -> void:
	_mice.erase(mouse)
	var pos := mouse.global_position
	mouse.queue_free()
	_caught += 1
	Sfx.play("collect")
	Fx.burst(self, pos + Vector2(0, -20), Color("fff27a"), 18)
	Fx.hearts(self, pos + Vector2(0, -30), 6)
	var cheer: String = "For Yellowfang!" if _setup.watcher == "Yellowfang" else \
			["Got it!", "Nice catch!", "Great pounce!", "Yum!"].pick_random()
	Fx.popup_text(self, pos + Vector2(0, -70), cheer, Color("ffd966"))
	Fx.shake(_camera, 6.0)
	_player.cat.bounce(0.3)
	if _watcher:
		_watcher.cat.bounce(0.25)
	_update_score()
	if _caught >= _setup.goal:
		_win()
		return
	# A new mouse pops out of the long grass at the edge
	await get_tree().create_timer(1.2).timeout
	var edge: Vector2 = [Vector2(MEADOW.position.x, randf_range(300, 650)), Vector2(MEADOW.end.x, randf_range(300, 650)),
			Vector2(randf_range(200, 1100), MEADOW.end.y)].pick_random()
	if _playing:
		_spawn_mouse(edge)


func _update_score() -> void:
	var text: String = _setup.score
	if _setup.has("free"):
		_score_label.text = text % _caught
	else:
		_score_label.text = text % [_caught, _setup.goal] if "%d" in text else text


func _go_home() -> void:
	_playing = false
	_player.frozen = true
	Sfx.play("win")
	GameState.fresh_kill += _caught
	var body := "You didn't catch anything this time. Better luck next time!" if _caught == 0 else \
			"You caught %d prey for the Clan!\nIt goes on the fresh-kill pile." % _caught
	_card.show_card("Back to Camp!", body, "Press SPACE")
	await _card.closed
	GameState.finish_activity()


func _win() -> void:
	_playing = false
	_player.frozen = true
	Sfx.play("win")
	Fx.confetti(self, Vector2(640, 300), 80)
	await get_tree().create_timer(1.0).timeout
	if _setup.has("outro"):
		if GameState.current_id() == "yellowfang":
			var bluestar := Npc.make("Bluestar")
			bluestar.position = Vector2(-60, 520)
			_world.add_child(bluestar)
			bluestar.walk_to(Vector2(380, 520))
		_dialog.say(Story.lines(_setup.outro))
		await _dialog.finished
	else:
		_card.show_card(_setup.card[0], _setup.card[1], "Press SPACE to go back to camp")
		await _card.closed
	GameState.complete_step()


func _draw() -> void:
	var place: String = _setup.place
	var grass: Color = {"forest": Color("86c46a"), "meadow": Color("9ed27c"), "snakerocks": Color("a9cf80")}[place]
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
	if place == "forest":
		for p in [Vector2(30, 450), Vector2(1250, 470), Vector2(200, 760), Vector2(1100, 760)]:
			Scenery.tree(self, p, 1.0, Color("5fa84f"), Color("a0704e"))
	elif place == "snakerocks":
		for p in [Vector2(560, 290), Vector2(720, 285), Vector2(640, 255)]:
			Scenery.rock(self, p, 1.6, Color("b8b4bd"))
		draw_string(ThemeDB.fallback_font, Vector2(540, 160), "Snakerocks", HORIZONTAL_ALIGNMENT_CENTER, 200, 26, Fx.INK)
	for p in [Vector2(40, 720), Vector2(1240, 720), Vector2(30, 420), Vector2(1250, 400)]:
		if _setup.has("free") and p.x < 100 and p.y < 500:
			continue
		Scenery.bush(self, p, 1.3, Color("6fb85a"), true)
	if _setup.has("free"):
		# The gorse tunnel back to camp
		for k in 7:
			var a := PI + PI * k / 6.0
			draw_circle(HOME_TUNNEL + Vector2(cos(a) * 60, sin(a) * 70), 26, Color("4f8f45"))
			draw_circle(HOME_TUNNEL + Vector2(cos(a) * 60, sin(a) * 70) + Vector2(8, -10), 5, Color("ffd23f"))
		draw_colored_polygon(Fx.ellipse_points(HOME_TUNNEL + Vector2(0, -10), Vector2(38, 45)), Color("3a2a2a"))
		draw_string(ThemeDB.fallback_font, HOME_TUNNEL + Vector2(-40, 70), "Camp", HORIZONTAL_ALIGNMENT_CENTER, 120, 26, Fx.INK)
