extends Node2D
## The Moonstone, deep under Highstones, where StarClan comes close.
## Medicine cats get their full name here, and new leaders receive nine lives from StarClan.

const STONE := Vector2(640, 250)
const PLAYER_SPOT := Vector2(560, 480)  # above the talking box
## The StarClan cats who give a new leader their nine lives, and what each life is for
const LIVES := [
	["Redtail", "courage", "to protect your Clan, even when you feel scared"],
	["Swiftbreeze", "speed", "to always be there when your Clan needs you"],
	["Robinwing", "energy", "to keep going even on the hardest days"],
	["Featherwhisker", "kindness", "to care for every cat, young and old"],
	["Thrushpelt", "patience", "to listen to your Clanmates before you decide"],
	["Snowfur", "love", "to protect the kits like they were your very own"],
	["Moonflower", "wisdom", "to make good choices for your Clan"],
	["Pinestar", "fairness", "to treat every cat the same, even cats from other Clans"],
	["Sunstar", "hope", "to light the way for your Clan, even on the darkest night"],
]

var _world: Node2D
var _player: Cat
var _player_label: Label
var _spottedleaf: Npc
var _starclan: Array[Npc] = []
var _dialog: DialogBox
var _card: InfoCard
var _picker: EndingPicker
var _camera: Camera2D
var _reveal: CanvasLayer
var _lives := 0
var _show_lives := false
var _dream := 0.0  # 0 = the cave, 1 = StarClan's starry dream
var _glow := 0.3  # how bright the Moonstone shines
var _stars: Array = []
var _time := 0.0


func _ready() -> void:
	seed(7)
	for i in 200:
		_stars.append(Vector3(randf() * 1280, randf() * 720, randf() * TAU))
	randomize()
	_camera = Camera2D.new()
	_camera.position = Vector2(640, 360)
	add_child(_camera)
	_world = Node2D.new()
	_world.y_sort_enabled = true
	add_child(_world)

	_player = GameState.make_player_cat()
	_player.position = PLAYER_SPOT
	_world.add_child(_player)
	_player_label = Fx.make_label(GameState.cat_name(), 26, Color("ffd966"), 6)
	_player_label.size = Vector2(400, 36)
	_player_label.position = Vector2(-200, -112 * _player.size - 36)
	_player_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_player.add_child(_player_label)
	_spottedleaf = Npc.make("Spottedleaf", 1.0)
	_spottedleaf.position = Vector2(330, 495)
	_world.add_child(_spottedleaf)

	_dialog = DialogBox.new()
	add_child(_dialog)
	_card = InfoCard.new()
	add_child(_card)
	_picker = EndingPicker.new()
	add_child(_picker)
	_reveal = CanvasLayer.new()
	add_child(_reveal)
	if GameState.activity == "nine_lives":
		_nine_lives.call_deferred()
	else:
		_medicine_ceremony.call_deferred()


# --- medicine cat ceremony -----------------------------------------------------------------

func _medicine_ceremony() -> void:
	_card.show_card(GameState.current().get("title", "The Moonstone"),
			"You and Spottedleaf traveled all the way to Highstones, and climbed down into the dark cave called Mothermouth...\n\nThere, the Moonstone waits for the moon.",
			"Press SPACE")
	await _card.closed
	_dialog.say(Story.lines([
		["Spottedleaf", "This is the Moonstone. When the moon shines on it, StarClan comes close."],
		["", "Moonlight pours through a hole in the roof. The Moonstone starts to sparkle!"],
	]))
	await _dialog.finished
	await _shine(1.0)
	_dialog.say(Story.lines([
		["Spottedleaf", "I, Spottedleaf, medicine cat of ThunderClan, call upon my warrior ancestors to look down on this apprentice."],
		["Spottedleaf", "{paw} has learned the ways of a medicine cat. With your help, {paw} will heal the Clan for many moons."],
		["Spottedleaf", "{paw}, do you promise to help every cat who needs you, in every Clan?"],
		["{paw}", "I promise!"],
	]))
	await _dialog.finished
	await _picker.choose_name(_dialog, "Spottedleaf")
	_dialog.say([["Spottedleaf", "Then by the power of StarClan, I give you your medicine cat name..."]])
	await _dialog.finished
	await _big_reveal(GameState.warrior_name(), "From this moment, you will be known as")

	_dialog.say(Story.lines([["Spottedleaf", "Now touch your nose to the Moonstone, {warrior}, and share dreams with StarClan."]]))
	await _dialog.finished
	await _go_to_dream()
	var guide := _add_starclan("Featherwhisker", Vector2(820, 560))
	await get_tree().create_timer(0.8).timeout
	_dialog.say(Story.lines([
		["Featherwhisker", "Welcome, {warrior}. I was ThunderClan's medicine cat long ago."],
		["Featherwhisker", "Heal your Clan with kindness, and StarClan will always walk beside you."],
	]))
	await _dialog.finished
	guide.cat.bounce(0.4)
	Fx.hearts(self, _player.position + Vector2(0, -80), 14)
	_card.show_card("You're a Medicine Cat!",
			"Congratulations, %s!\nYou went from kittypet to ThunderClan's medicine cat." % GameState.warrior_name(),
			"Press SPACE to go back to camp")
	await _card.closed
	GameState.complete_step()


# --- nine lives ----------------------------------------------------------------------------

func _nine_lives() -> void:
	_card.show_card("Nine Lives",
			"You and Spottedleaf traveled to the Moonstone.\n\nTonight, StarClan will give you nine lives and your leader name!",
			"Press SPACE")
	await _card.closed
	await _shine(1.0)
	_dialog.say(Story.lines([
		["Spottedleaf", "Lie down and touch your nose to the Moonstone, {me}. StarClan is waiting for you."],
	]))
	await _dialog.finished
	await _go_to_dream()
	# StarClan cats appear all around, in a big circle of starlight
	for i in LIVES.size():
		var a := PI + PI * (i + 0.5) / LIVES.size()
		var cat := _add_starclan(LIVES[i][0], PLAYER_SPOT + Vector2(80, -40) + Vector2(cos(a) * 520, sin(a) * 300 + 70))
		cat.cat.facing = 1.0 if cat.position.x < PLAYER_SPOT.x else -1.0
		Sfx.play("collect", 0.8 + i * 0.06, -6.0)
		await get_tree().create_timer(0.25).timeout
	_show_lives = true
	_dialog.say([["Sunstar", "Welcome, %s. We are StarClan. We have watched you grow from a kittypet into a great warrior." % GameState.cat_name()]])
	await _dialog.finished
	for i in LIVES.size():
		var life: Array = LIVES[i]
		var giver := _starclan[i]
		giver.cat.bounce(0.4)
		var home := giver.position
		await giver.walk_to(PLAYER_SPOT + Vector2(110, -10), 320.0)
		giver.face_toward(_player.position)
		_dialog.say([[life[0], "With this life I give you %s, %s." % [life[1], life[2]]]])
		await _dialog.finished
		_lives += 1
		Sfx.play("powerup", 0.9 + i * 0.04)
		Fx.burst(self, _player.position + Vector2(0, -50), Color("fff27a"), 26)
		Fx.burst(self, _player.position + Vector2(0, -50), Color("bfe6ff"), 16)
		Fx.popup_text(self, _player.position + Vector2(0, -160), "Life %d: %s!" % [_lives, life[1].capitalize()], Color("ffd966"))
		Fx.shake(_camera, 5.0)
		_player.bounce(0.35)
		await giver.walk_to(home, 320.0)
	GameState.rank = "leader"
	GameState.save_game()
	_dialog.say([["Sunstar", "I hail you by your new name..."]])
	await _dialog.finished
	create_tween().tween_property(_player, "size", GameState.cat_size(), 0.8).set_trans(Tween.TRANS_BACK)
	await _big_reveal(GameState.leader_name(), "From this moment, you are")
	for k in 3:
		for star_cat in _starclan:
			Fx.popup_text(self, star_cat.position + Vector2(0, -150), GameState.leader_name() + "!", Color("e7f3ff"), 24)
			star_cat.cat.bounce(0.3)
		await get_tree().create_timer(0.8).timeout
	_dialog.say([["Sunstar", "Lead ThunderClan with all nine of your gifts, %s. StarClan is proud of you." % GameState.leader_name()]])
	await _dialog.finished
	_card.show_card("You're the Leader!",
			"Congratulations, %s!\nYou went from kittypet all the way to leader of ThunderClan!" % GameState.leader_name(),
			"Press SPACE to go home to camp")
	await _card.closed
	GameState.finish_activity()


# --- shared bits ---------------------------------------------------------------------------

func _shine(to: float) -> void:
	Sfx.play("powerup", 0.7)
	var t := create_tween()
	t.tween_property(self, "_glow", to, 1.2)
	await t.finished


## Fall asleep by the Moonstone and wake up in StarClan's starry dream
func _go_to_dream() -> void:
	_player.sleeping = true
	_spottedleaf.cat.sleeping = true
	await get_tree().create_timer(0.8).timeout
	var t := create_tween()
	t.tween_property(self, "_dream", 1.0, 1.6)
	await t.finished
	_player.sleeping = false
	_player.bounce(0.3)


func _add_starclan(cat_name: String, pos: Vector2) -> Npc:
	var cat := Npc.make(cat_name)
	cat.position = pos
	cat.modulate = Color(0.8, 0.9, 1.25, 0.0)
	_world.add_child(cat)
	_starclan.append(cat)
	create_tween().tween_property(cat, "modulate:a", 0.85, 0.8)
	Fx.burst(self, pos + Vector2(0, -50), Color("e7f3ff"), 14, 160.0, -40.0)
	return cat


func _big_reveal(new_name: String, before: String) -> void:
	await get_tree().create_timer(0.4).timeout
	for child in _reveal.get_children():
		child.queue_free()
	_reveal.offset = Vector2.ZERO
	_reveal.add_child(Fx.centered_label(before, 30, Color("fff6ec"), 8))
	var big := Fx.centered_label(new_name.to_upper(), 96, Color("ffd966"), 44)
	big.add_theme_constant_override("outline_size", 14)
	big.pivot_offset = Vector2(640, 70)
	big.scale = Vector2(0.1, 0.1)
	_reveal.add_child(big)
	create_tween().tween_property(big, "scale", Vector2.ONE, 0.6).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	Sfx.play("powerup")
	Fx.shake(_camera, 10.0, 0.4)
	Fx.confetti(self, Vector2(640, 130), 120)
	Fx.hearts(self, _player.position + Vector2(0, -80), 14)
	_player_label.text = new_name
	_player_label.position.y = -112 * GameState.cat_size() - 36
	_player.bounce(0.4)
	await get_tree().create_timer(0.7).timeout
	Sfx.play("win")
	await get_tree().create_timer(1.6).timeout
	create_tween().tween_property(_reveal, "offset:y", -400.0, 0.5)


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	# The dark cave
	draw_rect(Rect2(0, 0, 1280, 720), Color("1e1830"))
	for i in 30:
		var a := PI + PI * i / 29.0
		var p := Vector2(640, 620) + Vector2(cos(a) * 700, sin(a) * 560)
		draw_circle(p, 90, Color("2c2442"))
		draw_circle(p + Vector2(-10, -10), 64, Color("362d52"))
	draw_colored_polygon(Fx.ellipse_points(Vector2(640, 520), Vector2(620, 170), 48), Color("3a3150"))
	# Moonlight from the hole in the roof
	draw_colored_polygon(PackedVector2Array([Vector2(600, 0), Vector2(680, 0), Vector2(760, 320), Vector2(520, 320)]),
			Color(0.85, 0.9, 1.0, 0.08 + 0.12 * _glow))
	# The Moonstone
	var shimmer := 0.5 + 0.5 * sin(_time * 2.0)
	draw_circle(STONE, 130 + shimmer * 12, Color(0.8, 0.9, 1.0, 0.12 * _glow))
	draw_circle(STONE, 95 + shimmer * 8, Color(0.85, 0.92, 1.0, 0.2 * _glow))
	var stone := PackedVector2Array([Vector2(-70, 60), Vector2(-85, 0), Vector2(-50, -70), Vector2(0, -95),
			Vector2(55, -65), Vector2(85, 5), Vector2(70, 60)])
	var outline := PackedVector2Array()
	for p in stone:
		outline.append(STONE + p * 1.06)
	draw_colored_polygon(outline, Color("4a2f3c"))
	var lit := Color("8a8fb0").lerp(Color("eef4ff"), _glow)
	var moved := PackedVector2Array()
	for p in stone:
		moved.append(STONE + p)
	draw_colored_polygon(moved, lit)
	draw_colored_polygon(PackedVector2Array([STONE + Vector2(-30, -60), STONE + Vector2(0, -85), STONE + Vector2(20, -30),
			STONE + Vector2(-20, 10)]), Color(1, 1, 1, 0.35 + 0.4 * _glow))
	for k in 5:
		var a := _time * 0.8 + k * TAU / 5.0
		Scenery.star(self, STONE + Vector2(cos(a) * 110, sin(a) * 50 - 10), 6, Color(1, 1, 0.9, 0.7 * _glow))
	# StarClan's dream: a starry sky fades in over the cave
	if _dream > 0.0:
		draw_rect(Rect2(0, 0, 1280, 720), Color(0.1, 0.12, 0.3, 0.85 * _dream))
		for s in _stars:
			var twinkle := 0.5 + 0.5 * sin(_time * 2.5 + s.z)
			draw_circle(Vector2(s.x, s.y), 1.2 + twinkle * 1.5, Color(1, 1, 0.9, (0.3 + 0.7 * twinkle) * _dream))
		draw_colored_polygon(Fx.ellipse_points(Vector2(640, 520), Vector2(600, 150), 48), Color(0.6, 0.7, 1.0, 0.2 * _dream))
	for star_cat in _starclan:
		draw_circle(star_cat.position + Vector2(0, -45), 70, Color(0.8, 0.9, 1.0, 0.1 * star_cat.modulate.a))
	if _show_lives:
		draw_string(ThemeDB.fallback_font, Vector2(20, 50), "Lives:", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color("fff6ec"))
		for i in 9:
			var on := i < _lives
			Scenery.star(self, Vector2(130 + i * 40, 40), 15 if on else 11, Color("ffd966") if on else Color(1, 1, 1, 0.25))
