extends Node2D
## Rescue the kits: sneak through ShadowClan's camp at night without the guards seeing you.
## Hide in the ferns! If a guard spots you, you go back to the last fern you hid in.

const AREA := Rect2(50, 180, 1180, 520)
const KITS_DEN := Vector2(1140, 250)
const SIGHT := 190.0  # how far guards can see
const SIGHT_ANGLE := 0.45  # half the width of their view (radians)
const FERNS := [
	Rect2(50, 590, 270, 110),  # the start
	Rect2(520, 470, 170, 60),
	Rect2(1000, 470, 170, 60),
	Rect2(200, 335, 170, 55),
	Rect2(760, 335, 170, 55),
	Rect2(380, 205, 170, 55),
]
# Guard lanes: [y, left x, right x, speed]
const LANES := [[560, 330, 950, 80.0], [420, 280, 1120, 95.0], [290, 560, 1060, 70.0]]

var _world: Node2D
var _player: TopDownPlayer
var _graypaw: Follower
var _guards: Array = []  # each: {npc, lane, dir, pause}
var _checkpoint := Vector2(160, 650)
var _playing := false
var _caught_cooldown := 0.0
var _dialog: DialogBox
var _card: InfoCard
var _hint: Label
var _stars: Array = []


func _ready() -> void:
	seed(13)
	for i in 70:
		_stars.append(Vector2(randf() * 1280, randf() * 160))
	randomize()

	_world = Node2D.new()
	_world.y_sort_enabled = true
	add_child(_world)
	_player = TopDownPlayer.new()
	_player.position = _checkpoint
	_player.bounds = AREA
	_player.speed = 220.0
	_player.frozen = true
	_graypaw = Follower.make("Graypaw", _player, 90.0)
	_world.add_child(_graypaw)
	_world.add_child(_player)

	for lane in LANES:
		var npc := Npc.make("ShadowClan warrior")
		npc.position = Vector2(randf_range(lane[1], lane[2]), lane[0])
		_world.add_child(npc)
		_guards.append({"npc": npc, "lane": lane, "dir": [-1.0, 1.0].pick_random(), "pause": 0.0})

	var yellowfang := Npc.make("Yellowfang")
	yellowfang.position = Vector2(330, 660)
	_world.add_child(yellowfang)

	Scenery.fireflies(self, Rect2(0, 200, 1280, 500), Color("d6ff8a"))
	var hud := CanvasLayer.new()
	add_child(hud)
	_hint = Fx.centered_label("Sneak to the bramble den in the top corner!", 30, Color.WHITE, 26)
	hud.add_child(_hint)

	_dialog = DialogBox.new()
	add_child(_dialog)
	_card = InfoCard.new()
	add_child(_card)
	_card.show_card(GameState.current().get("title", "Rescue the Kits!"),
			"Sneak through ShadowClan's camp and find the kits!\n\nHide in the ferns. Stay out of the guards' yellow glow, or they'll see you!",
			"Press SPACE to start!")
	await _card.closed
	_dialog.say(Story.lines([
		["Yellowfang", "Psst! {paw}! Over here!"],
		["Yellowfang", "I didn't take the kits. Brokenstar did! He's ShadowClan's mean leader."],
		["Yellowfang", "The kits are in the bramble den in the top corner. Stay in the ferns and sneak past the guards!"],
		["Graypaw", "I'll be right behind you!"],
	]))
	await _dialog.finished
	_playing = true
	_player.frozen = false


func _process(delta: float) -> void:
	queue_redraw()
	_caught_cooldown -= delta
	for g in _guards:
		_move_guard(g, delta)
	if not _playing:
		return
	var hidden := _fern_at(_player.position) >= 0
	_player.modulate.a = 0.5 if hidden else 1.0
	if hidden:
		_checkpoint = FERNS[_fern_at(_player.position)].get_center()
	elif _caught_cooldown <= 0.0:
		for g in _guards:
			if _can_see(g, _player.position):
				_spotted(g)
				break
	if _player.position.distance_to(KITS_DEN) < 100:
		_found_kits()


func _move_guard(g: Dictionary, delta: float) -> void:
	var npc: Npc = g.npc
	if g.pause > 0.0:
		g.pause -= delta
		npc.cat.walk_amount = move_toward(npc.cat.walk_amount, 0.0, delta * 6.0)
		return
	var lane: Array = g.lane
	npc.position.x += g.dir * lane[3] * delta
	npc.cat.facing = g.dir
	npc.cat.walk_amount = 1.0
	if npc.position.x < lane[1] or npc.position.x > lane[2]:
		npc.position.x = clampf(npc.position.x, lane[1], lane[2])
		g.dir = -g.dir
		g.pause = 1.2  # stop and look around before turning


func _can_see(g: Dictionary, p: Vector2) -> bool:
	var npc: Npc = g.npc
	var to := p - npc.position
	if to.length() > SIGHT or to.length() < 1.0:
		return to.length() < 45.0  # bumping right into a guard counts too
	var look := Vector2(npc.cat.facing, 0)
	return absf(look.angle_to(to)) < SIGHT_ANGLE


func _fern_at(p: Vector2) -> int:
	for i in FERNS.size():
		if FERNS[i].has_point(p):
			return i
	return -1


func _spotted(g: Dictionary) -> void:
	_caught_cooldown = 1.2
	var npc: Npc = g.npc
	g.pause = 1.0
	Sfx.play("hurt")
	npc.cat.bounce(0.3)
	Fx.speech(npc, "Hey! Who's there?!", 140.0, 1.4)
	Fx.popup_text(self, _player.position + Vector2(0, -120), "Spotted! Back to the ferns!", Color("ffd966"), 26)
	_player.position = _checkpoint
	_player.cat.bounce(0.3)
	_graypaw.reset()


func _found_kits() -> void:
	_playing = false
	_player.frozen = true
	_player.modulate.a = 1.0
	Sfx.play("powerup")
	var kits: Array[Npc] = []
	for i in 2:
		var kit := Npc.make(["Cinderkit", "Brightkit"][i])
		kit.position = KITS_DEN + Vector2(-20 + i * 50, 30)
		_world.add_child(kit)
		kits.append(kit)
		Fx.hearts(self, kit.position + Vector2(0, -40), 8)
	_dialog.say(Story.lines([
		["Cinderkit", "{paw}! You came for us!"],
		["Brightkit", "We were so scared! We want to go home!"],
		["Bluestar", "ThunderClan! Chase them out of here!"],
	]))
	await _dialog.finished
	# ThunderClan's warriors arrive, and the ShadowClan guards run off!
	var warriors: Array[Npc] = []
	for i in 3:
		var w := Npc.make(["Bluestar", "Tigerclaw", "Lionheart"][i])
		w.position = Vector2(-80, 380 + i * 110)
		_world.add_child(w)
		w.walk_to(Vector2(280 + i * 60, 380 + i * 110), 260.0)
		warriors.append(w)
	for g in _guards:
		var npc: Npc = g.npc
		g.pause = 99.0
		Fx.popup_text(self, npc.position + Vector2(0, -130), "Eek! Run!", Color("bfe6ff"), 26)
		npc.walk_to(Vector2(1400, npc.position.y), 320.0)
	Fx.shake(get_viewport().get_camera_2d(), 6.0)
	await get_tree().create_timer(1.6).timeout
	Sfx.play("win")
	Fx.confetti(self, Vector2(640, 300), 80)
	_dialog.say(Story.lines([
		["Yellowfang", "Brokenstar has run away! ShadowClan is free of him at last."],
		["Graypaw", "We did it, {paw}! The kits are safe!"],
		["Bluestar", "Well done, {paw}. Let's take the kits home to their mother."],
	]))
	await _dialog.finished
	_card.show_card("Kits Rescued!", "You sneaked into ShadowClan's camp and saved Cinderkit and Brightkit!",
			"Press SPACE to go back to camp")
	await _card.closed
	GameState.complete_step()


func _draw() -> void:
	Scenery.sky(self, Color("141836"), Color("2c2a55"), Rect2(0, 0, 1280, 200))
	for s in _stars:
		draw_circle(s, 1.6, Color(1, 1, 0.9, 0.7))
	draw_circle(Vector2(1120, 70), 36, Color("fff6d5"))
	for i in 12:
		Scenery.pine(self, Vector2(i * 115 - 10, 200), 1.0 + (i % 3) * 0.2, Color("1d2d2a"))
	draw_rect(Rect2(0, 180, 1280, 540), Color("34503f"))
	for p in [Vector2(250, 250), Vector2(900, 230), Vector2(640, 660), Vector2(1000, 640)]:
		draw_colored_polygon(Fx.ellipse_points(p, Vector2(70, 18)), Color("2a4a4a"))  # marshy puddles
	# Ferns to hide in
	for r in FERNS:
		draw_rect(r, Color(0.2, 0.45, 0.25, 0.45))
		for k in int(r.size.x / 22):
			var base := Vector2(r.position.x + 11 + k * 22, r.end.y)
			for a in [-0.5, 0.0, 0.5]:
				draw_line(base, base + Vector2(sin(a) * 28, -r.size.y * 0.9), Color("5fae5a"), 4.0)
	# The bramble den where the kits are
	draw_colored_polygon(Fx.ellipse_points(KITS_DEN + Vector2(0, -30), Vector2(95, 70)), Color("4a3a30"))
	for k in 10:
		var a := TAU * k / 10.0
		draw_circle(KITS_DEN + Vector2(cos(a) * 80, -30 + sin(a) * 55), 20, Color("5a4a3a"))
	draw_colored_polygon(Fx.ellipse_points(KITS_DEN + Vector2(0, -18), Vector2(36, 28)), Color("1a1410"))
	if _playing:
		var glow := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 250.0)
		draw_circle(KITS_DEN + Vector2(0, -30), 110 + glow * 10, Color(1, 0.85, 0.4, 0.12))
	# What the guards can see
	for g in _guards:
		var npc: Npc = g.npc
		if g.pause > 50.0:
			continue
		var eye := npc.position + Vector2(0, -20)
		var cone := PackedVector2Array([eye])
		for k in 9:
			var a := -SIGHT_ANGLE + SIGHT_ANGLE * 2.0 * k / 8.0
			cone.append(eye + Vector2(npc.cat.facing, 0).rotated(a) * SIGHT)
		draw_colored_polygon(cone, Color(1, 0.9, 0.3, 0.22))
