extends Node2D
## Play-fighting with one other cat (claws in!). They crouch, then leap at you.
## Dodge the leap, then POUNCE on them while they catch their breath.
## Used for Graypaw's surprise attack and battle practice with your mentor Bluestar.

const ARENA := Rect2(170, 300, 940, 360)  # oval the cats can move in
const TAG_DISTANCE := 85.0
const BUMP_DISTANCE := 55.0

const SETUPS := {
	"teach_battle": {
		"opponent": "Cinderkit", "rename": "Cinderpaw", "goal": 3, "place": "hollow", "speed": 0.8, "dodge": 0.15,
		"intro": "Now YOU are the mentor! Show Cinderpaw your battle moves.\n\nDodge when she crouches, then POUNCE when she's tired!",
		"before": [["Cinderpaw", "I'm ready, {me}! Teach me everything!"]],
		"tips": ["Whoa, you're fast!", "I'll get you this time!", "Hee hee!", "Teach me that move!"],
	},
	"graypaw": {
		"opponent": "Graypaw", "goal": 3, "place": "forest", "speed": 0.8, "dodge": 0.1,
		"intro": "A young gray cat jumps out of the bushes! Don't worry, it's only a play-fight.\n\nWhen he crouches, get out of the way! When he's tired, POUNCE on him!",
		"before": [["Graypaw", "I'm Graypaw of ThunderClan! This is OUR territory!"],
				["Graypaw", "Let's see if a kittypet can fight!"]],
		"tips": ["Here I come!", "You're fast for a kittypet!", "Hey, no fair!"],
	},
	"battle_lesson": {
		"opponent": "Bluestar", "goal": 5, "place": "hollow", "speed": 1.0, "dodge": 0.3,
		"intro": "Battle practice with Bluestar in the training hollow!\n\nWhen she crouches, dodge out of the way. When she's tired, POUNCE on her!",
		"before": [["Bluestar", "A warrior only fights to protect the Clan. Today, we practice!"],
				["Bluestar", "Watch me closely. When I crouch, I'm about to leap!"]],
		"tips": ["Watch my crouch!", "Good! Again!", "Quick paws!", "Keep your balance!"],
	},
}

var _setup: Dictionary
var _world: Node2D
var _player: TopDownPlayer
var _foe: Npc
var _tags := 0
var _playing := false
var _card: InfoCard
var _dialog: DialogBox
var _score_label: Label
var _camera: Camera2D

# The other cat's moves: "circle" -> "crouch" -> "leap" -> "tired" -> "circle"...
var _state := "circle"
var _state_time := 1.5
var _leap_dir := Vector2.ZERO
var _safe_time := 0.0  # can't be tagged again right after a tag
var _bump_safe := 0.0
var _decor: Array = []


func _ready() -> void:
	_setup = SETUPS.get(GameState.current_id(), SETUPS.battle_lesson)
	seed(9)
	for i in 50:
		_decor.append(Vector3(randf_range(40, 1240), randf_range(220, 700), randi() % 4))
	randomize()

	_camera = Camera2D.new()
	_camera.position = Vector2(640, 360)
	add_child(_camera)
	_world = Node2D.new()
	_world.y_sort_enabled = true
	add_child(_world)

	_player = TopDownPlayer.new()
	_player.position = Vector2(420, 500)
	_player.bounds = ARENA
	_player.round_bounds = true
	_player.can_pounce = true
	_player.frozen = true
	_world.add_child(_player)
	_foe = Npc.make(_setup.opponent, -1.0)
	if _setup.has("rename"):
		_foe.rename(_setup.rename)
		_foe.cat.size = 0.72
	_foe.position = Vector2(860, 480)
	_world.add_child(_foe)

	var hud := CanvasLayer.new()
	add_child(hud)
	_score_label = Fx.centered_label("", 38, Color.WHITE, 30)
	hud.add_child(_score_label)
	_update_score()

	_dialog = DialogBox.new()
	add_child(_dialog)
	_card = InfoCard.new()
	add_child(_card)
	var title: String = "Teach Cinderpaw!" if _setup.has("rename") else GameState.current().get("title", "Battle Practice!")
	_card.show_card(title, _setup.intro, "Press SPACE to start!")
	await _card.closed
	_dialog.say(Story.lines(_setup.before))
	await _dialog.finished
	_playing = true
	_player.frozen = false


func _process(delta: float) -> void:
	queue_redraw()
	if not _playing:
		return
	_safe_time -= delta
	_bump_safe -= delta
	_state_time -= delta
	var speed: float = _setup.speed
	var to_player := _player.position - _foe.position
	match _state:
		"circle":
			# Keep a little distance and walk around the player
			var want := _player.position - to_player.normalized() * 240.0
			want += to_player.normalized().orthogonal() * 120.0
			_move_foe(want, 150.0 * speed, delta)
			if _state_time <= 0.0:
				_set_state("crouch", 0.9 / speed)
				_foe.face_toward(_player.global_position)
		"crouch":
			_foe.cat.walk_amount = 0.0
			_foe.cat.squish = Vector2(1.18, 0.82)
			if _state_time <= 0.0:
				_leap_dir = to_player.normalized()
				_set_state("leap", 0.5)
				Sfx.play("jump", 0.8)
				_foe.cat.bounce(-0.3)
		"leap":
			_foe.position += _leap_dir * 620.0 * speed * delta
			_foe.cat.lift = sin((1.0 - _state_time / 0.5) * PI) * 45.0
			_foe.position = _keep_in_arena(_foe.position)
			if _bump_safe <= 0.0 and _foe.position.distance_to(_player.position) < BUMP_DISTANCE \
					and not _player.is_pouncing():
				_bump()
			if _state_time <= 0.0:
				_foe.cat.lift = 0.0
				_foe.cat.bounce(0.3)
				_set_state("tired", 1.8 / speed)
		"tired":
			_foe.cat.walk_amount = 0.0
			if _state_time <= 0.0:
				_set_state("circle", randf_range(1.2, 2.2))

	if _player.is_pouncing() and _safe_time <= 0.0 and _player.position.distance_to(_foe.position) < TAG_DISTANCE:
		if _state == "circle" and randf() < _setup.dodge:
			_dodge()
		else:
			_tag()


func _set_state(state: String, time: float) -> void:
	_state = state
	_state_time = time


func _move_foe(target: Vector2, speed: float, delta: float) -> void:
	var step := (target - _foe.position).limit_length(speed * delta)
	_foe.position = _keep_in_arena(_foe.position + step)
	_foe.cat.walk_amount = move_toward(_foe.cat.walk_amount, 1.0 if step.length() > 0.5 else 0.0, delta * 6.0)
	_foe.face_toward(_player.global_position)


func _keep_in_arena(p: Vector2) -> Vector2:
	var center := ARENA.get_center()
	var d := (p - center) / (ARENA.size / 2.0)
	return center + d.normalized() * (ARENA.size / 2.0) if d.length() > 1.0 else p


func _tag() -> void:
	_tags += 1
	_safe_time = 0.8
	Sfx.play("enemy_bonk")
	var pos := _foe.position + Vector2(0, -60)
	Fx.burst(self, pos, Color("fff27a"), 14, 260.0)
	Fx.popup_text(self, pos + Vector2(0, -40), ["Gotcha!", "Tagged!", "Pounce!", "Nice move!"].pick_random(), Color("ffd966"))
	Fx.shake(_camera, 7.0)
	_foe.cat.bounce(0.4)
	var tween := create_tween()
	tween.tween_property(_foe, "position", _keep_in_arena(_foe.position + (_foe.position - _player.position).normalized() * 110.0), 0.25)
	_set_state("circle", randf_range(1.0, 1.8))
	_foe.cat.lift = 0.0
	_update_score()
	if _tags >= _setup.goal:
		_win()
	elif randf() < 0.6:
		Fx.speech(_foe, _setup.tips.pick_random(), 130.0 * _foe.cat.size, 1.6)


func _dodge() -> void:
	_safe_time = 0.5
	Fx.popup_text(self, _foe.position + Vector2(0, -130), "Dodged!", Color("bfe6ff"), 26)
	var side := (_foe.position - _player.position).orthogonal().normalized() * 120.0
	create_tween().tween_property(_foe, "position", _keep_in_arena(_foe.position + side), 0.18)


func _bump() -> void:
	_bump_safe = 0.8
	Sfx.play("hurt")
	Fx.popup_text(self, _player.position + Vector2(0, -130), "Oof! Dodge next time!", Color("bfe6ff"), 24)
	Fx.burst(self, _player.position + Vector2(0, -50), Color("fff27a"), 8, 140.0, 0.0)
	_player.cat.bounce(0.35)
	Fx.shake(_camera, 4.0)
	var push := _keep_in_arena(_player.position + _leap_dir * 90.0)
	create_tween().tween_property(_player, "position", push, 0.2)


func _update_score() -> void:
	_score_label.text = "Pounces on %s: %d / %d" % [_foe.npc_name, _tags, _setup.goal]


func _win() -> void:
	_playing = false
	_player.frozen = true
	Sfx.play("win")
	Fx.confetti(self, Vector2(640, 300), 80)
	_foe.cat.walk_amount = 0.0
	await get_tree().create_timer(1.0).timeout
	if GameState.activity == "teach_battle":
		_dialog.say(Story.lines([["Cinderpaw", "Wow! You're the best mentor in the whole forest, {me}!"]]))
		await _dialog.finished
		GameState.finish_activity()
		return
	if GameState.current_id() == "graypaw":
		await _meet_the_clan()
	else:
		_dialog.say(Story.lines([["Bluestar", "Well done, {paw}! You learn fast. That was a great move!"]]))
		await _dialog.finished
		_card.show_card("Amazing Moves!", "You beat Bluestar at battle practice!\nYou're learning to protect your Clan.",
				"Press SPACE to go back to camp")
		await _card.closed
	GameState.complete_step()


## Bluestar and Lionheart come out of the trees and invite you to join ThunderClan
func _meet_the_clan() -> void:
	_dialog.say(Story.lines([["Graypaw", "Whoa! You're really strong for a kittypet!"]]))
	await _dialog.finished
	var bluestar := Npc.make("Bluestar")
	var lionheart := Npc.make("Lionheart")
	bluestar.position = Vector2(-80, 340)
	lionheart.position = Vector2(-80, 450)
	_world.add_child(bluestar)
	_world.add_child(lionheart)
	bluestar.walk_to(Vector2(300, 340), 140.0)
	await lionheart.walk_to(Vector2(220, 450), 140.0)
	_player.cat.facing = -1.0
	_dialog.say(Story.lines([
		["Lionheart", "Well, well, Graypaw. It looks like this kittypet won!"],
		["Bluestar", "I am Bluestar, leader of ThunderClan. I've been watching you, young one."],
		["Bluestar", "You are brave, and you caught a mouse all by yourself. Would you like to join ThunderClan and train as a warrior?"],
		["{kp}", "Yes! I want to be a warrior more than anything!"],
		["Bluestar", "Then come with us. You won't need that collar anymore!"],
	]))
	await _dialog.finished
	# Off comes the collar!
	_player.cat.collar = false
	_player.cat.bounce(0.4)
	Sfx.play("powerup")
	Fx.burst(self, _player.position + Vector2(0, -40), Color("e2445c"), 10)
	Fx.burst(self, _player.position + Vector2(0, -40), Color("ffd23f"), 10)
	await get_tree().create_timer(1.0).timeout


func _draw() -> void:
	var forest: bool = _setup.place == "forest"
	draw_rect(Rect2(0, 0, 1280, 720), Color("7fbf62") if forest else Color("6fb85a"))
	for i in 10:
		Scenery.tree(self, Vector2(i * 145 - 20, 240), 0.9 + (i % 3) * 0.1, Color("5fa84f"), Color("a0704e"))
	if forest:
		for p in [Vector2(80, 720), Vector2(1200, 720), Vector2(60, 420), Vector2(1230, 430)]:
			Scenery.bush(self, p, 1.4, Color("5fa84f"), true)
	else:
		draw_colored_polygon(Fx.ellipse_points(Vector2(640, 480), Vector2(600, 250), 48), Color("c9a86a"))
		draw_colored_polygon(Fx.ellipse_points(Vector2(640, 485), Vector2(570, 225), 48), Color("f0d9a8"))
	for d in _decor:
		if not forest and int(d.z) < 3:
			continue
		Scenery.flower(self, Vector2(d.x, d.y), [Color("f7a8c8"), Color("fff3a0"), Color("c9b6ff"), Color("ffffff")][int(d.z)])
	if _playing and _state == "crouch":
		# A warning "!" so you know a leap is coming
		var p := _foe.position + Vector2(0, -120 * _foe.cat.size - 40)
		draw_circle(p, 20, Fx.OUTLINE)
		draw_circle(p, 17, Color("ff6b6b"))
		draw_rect(Rect2(p + Vector2(-3, -11), Vector2(6, 13)), Color.WHITE)
		draw_circle(p + Vector2(0, 8), 3, Color.WHITE)
	if _playing and _state == "tired":
		var p := _foe.position + Vector2(0, -120 * _foe.cat.size - 20)
		for k in 3:
			var a := Time.get_ticks_msec() / 250.0 + k * TAU / 3.0
			Scenery.star(self, p + Vector2(cos(a) * 30, sin(a) * 10), 8, Color("ffd23f"))
