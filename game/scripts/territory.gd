extends Node2D
## ThunderClan's whole territory in ONE world, for two players at once (split screen).
## The camp is in the middle; walk out through the gorse tunnel to the forest, Fourtrees,
## the Owl Tree, Tallpines, Sunningrocks and Snakerocks.
## Player 1: arrows + SPACE.  Player 2: W A S D + E.  The same key pounces, talks and uses things.
##   Border patrol: mark the 5 glowing scent-marker trees.
##   Hunting patrol: catch mice and carry them home to the fresh-kill pile.
## Each player keeps their own rank from their save: only a leader speaks from the Highrock,
## only medicine cats can pick herbs, and the camp changes when cats have retired.

const MAP := Rect2(0, 0, 3200, 2400)
const WALK := Rect2(210, 150, 2900, 2160)  # where cats can go (the river is on the left)
const CAMP := Vector2(1600, 1150)  # middle of the camp
const CAMP_RADII := Vector2(640, 335)  # the gorse wall around the camp
const OFFSET := CAMP - Vector2(640, 440)  # moves things from camp.gd's camp into this world
const USE_DISTANCE := 90.0
const CATCH_DISTANCE := 70.0
const SCARE_DISTANCE := 115.0
const PLAYER_COLORS := [Color("ffd966"), Color("ff9ec0")]
const KEY_NAMES := ["SPACE", "E"]

## Special places in the territory: [name, where, where its scent-marker tree is]
const PLACES := [
	["Fourtrees", Vector2(1600, 330), Vector2(1780, 470)],
	["Owl Tree", Vector2(2650, 560), Vector2(2650, 700)],
	["Tallpines", Vector2(560, 520), Vector2(700, 660)],
	["Sunningrocks", Vector2(470, 1500), Vector2(560, 1680)],
	["Snakerocks", Vector2(2700, 1750), Vector2(2560, 1900)],
	["Training Hollow", Vector2(1600, 2020), Vector2.INF],
]
## Where mice live (out in the forest, not in camp)
const MOUSE_ZONES := [Rect2(320, 260, 2560, 420), Rect2(320, 1620, 2560, 600), Rect2(260, 760, 560, 800),
		Rect2(2380, 760, 620, 800)]
## The dens, in the same places as in the camp scene (camp.gd)
const DENS := {
	"warriors": [Vector2(225, 345), "Warriors' Den"], "apprentices": [Vector2(1055, 345), "Apprentices' Den"],
	"nursery": [Vector2(250, 630), "Nursery"], "elders": [Vector2(1030, 630), "Elders' Den"],
	"medicine": [Vector2(395, 262), "Medicine Den"],
}
const DEN_WORDS := {
	"warriors": "The Warriors' Den. Whitestorm is snoring! Zzz...",
	"apprentices": "The Apprentices' Den. It smells like moss and mice.",
	"nursery": "The Nursery. Shh! The kits are napping.",
	"elders": "The Elders' Den. One-eye is telling a story about the old days.",
	"medicine": "The Medicine Den. It smells like herbs and honey!",
	"leader": "The Leader's Den. Bluestar's mossy nest is behind the lichen.",
}
## Clan cats in camp: [name, place in camp.gd's camp, wander area]
const CLAN := [
	["Tigerclaw", Vector2(620, 380), Rect2(560, 360, 160, 50)], ["Lionheart", Vector2(340, 470), Rect2()],
	["Longtail", Vector2(190, 500), Rect2(170, 480, 70, 60)], ["Spottedleaf", Vector2(300, 300), Rect2()],
	["Graypaw", Vector2(900, 420), Rect2(860, 400, 110, 60)], ["Ravenpaw", Vector2(1110, 470), Rect2()],
	["Sandpaw", Vector2(730, 615), Rect2()], ["Dustpaw", Vector2(815, 618), Rect2()],
	["Smallear", Vector2(920, 560), Rect2()], ["Yellowfang", Vector2(470, 330), Rect2()],
	["Frostfur", Vector2(380, 640), Rect2()], ["Cinderkit", Vector2(450, 600), Rect2(400, 560, 150, 70)],
	["Brightkit", Vector2(500, 590), Rect2(400, 560, 150, 70)],
]

var _world: Node2D
var _players: Array[TopDownPlayer] = []
var _cameras: Array[Camera2D] = []
var _infos: Array = []
var _prompts: Array[Label] = []
var _carrying := [0, 0]  # mice each player is carrying home
var _on_rock := [false, false]
var _npcs: Array[Npc] = []
var _spots: Array = []  # things to use: {pos, what, ...}
var _markers: Array[ScentMarker] = []
var _mice: Array[Mouse] = []
var _pile: CampProp
var _pile_count := 0
var _patrols := 0
var _herbs: Array[HerbPatch] = []  # herbs growing in the forest (for medicine cats)
var _carrying_herbs := [0, 0]
var _herb_count := 0  # herbs brought home to the medicine den
var _quest_back: Panel
var _quest_label: Label
var _banner: Label
var _map: MiniMap
var _playing := false
var _card: InfoCard


func _ready() -> void:
	for slot in GameState.together:
		_infos.append(GameState.describe_slot(slot))
	if _infos.size() < 2 or _infos.has({}):
		Transition.go.call_deferred("res://scenes/title.tscn")  # nobody to play with
		return
	GameState.make_friends(GameState.together[0], GameState.together[1])  # playing together = friends!
	GameState.fresh_kill = 0  # the pile in this world starts empty

	_world = WorldFloor.new()
	_world.y_sort_enabled = true
	_cameras = SplitScreen.make(self, _world, MAP)
	_build_camp()
	_build_territory()
	var blockers: Array[Rect2] = _gorse_wall()
	for prop in _world.get_children():
		if prop is CampProp:
			blockers.append(prop.footprint())
	for i in 2:
		var player := SplitScreen.make_player(_infos[i], i, WALK)
		player.position = CAMP + Vector2(-90 + i * 180, 200)
		player.blockers = blockers
		_world.add_child(player)
		player.name_label.add_theme_color_override("font_color", PLAYER_COLORS[i])
		_players.append(player)
		_cameras[i].position = player.position
		var prompt := Fx.make_label("", 22, PLAYER_COLORS[i], 6)
		prompt.size = Vector2(300, 30)
		prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		prompt.z_index = 20
		_world.add_child(prompt)
		_prompts.append(prompt)

	_make_hud()
	_card = InfoCard.new()
	add_child(_card)
	_card.show_card("ThunderClan Together!",
			"The camp and the territory, all in one world!\n\nBorder patrol: mark the 5 glowing trees.\nHunting patrol: bring mice to the fresh-kill pile.",
			"Press SPACE to start!")
	await _card.closed
	_playing = true
	for player in _players:
		player.frozen = false


# --- building the world --------------------------------------------------------------------

func _build_camp() -> void:
	var rock := _add_prop("high_rock", Vector2(640, 300) + OFFSET, "Highrock")
	# Cats who retired because one of the players took their place
	var retired := []
	if _leader_name() != "":
		retired.append("Bluestar")
	if _infos.any(func(c): return c.rank in ["deputy", "leader"]):
		retired.append("Lionheart")
	if _infos.any(func(c): return c.rank == "head"):
		retired.append("Spottedleaf")
	if not "Bluestar" in retired:
		var bluestar := Npc.make("Bluestar")
		bluestar.position = Vector2(-10, -136)
		bluestar.talk_spot = Vector2(0, 175)
		rock.add_child(bluestar)
		_npcs.append(bluestar)
	var elder_spots := [Vector2(870, 650), Vector2(1170, 545), Vector2(800, 670)]
	for who in retired:
		var elder := Npc.make(who, -1.0)
		elder.position = elder_spots.pop_front() + OFFSET
		elder.set_meta("retired", true)
		_world.add_child(elder)
		_npcs.append(elder)
	_spots.append({"pos": Vector2(530, 352) + OFFSET, "what": "rock"})
	_spots.append({"pos": Vector2(748, 322) + OFFSET, "what": "den", "den": "leader"})
	for key in DENS:
		var den: Array = DENS[key]
		_add_prop("medicine" if key == "medicine" else "den", den[0] + OFFSET, den[1])
		_spots.append({"pos": den[0] + OFFSET + Vector2(0, 22), "what": "den", "den": key})
	_pile = _add_prop("fresh_kill", Vector2(840, 470) + OFFSET, "Fresh-kill Pile")
	_spots.append({"pos": Vector2(840, 492) + OFFSET, "what": "pile"})
	var someone_grown: bool = _infos.any(func(c): return c.grown)
	for c in CLAN:
		if c[0] in retired:
			continue
		var npc := Npc.make(c[0], [-1.0, 1.0].pick_random())
		if c[0] == "Graypaw" and someone_grown:
			npc.rename("Graystripe")
		npc.position = c[1] + OFFSET
		var area: Rect2 = c[2]
		if area.has_area():
			npc.wander_area = Rect2(area.position + OFFSET, area.size)
		if c[0].ends_with("kit"):
			npc.hops = true
			npc.speed = 120.0
		_world.add_child(npc)
		_npcs.append(npc)


## The name of a player who is leader ("" if neither of you is)
func _leader_name() -> String:
	for info in _infos:
		if info.leader:
			return info.name
	return ""


func _add_prop(kind: String, pos: Vector2, label: String) -> CampProp:
	var prop := CampProp.new().setup(kind, label)
	prop.position = pos
	_world.add_child(prop)
	return prop


## The prickly gorse wall around camp: blocks you everywhere except the tunnel at the bottom
func _gorse_wall() -> Array[Rect2]:
	var rects: Array[Rect2] = []
	for k in 72:
		var a := TAU * k / 72.0
		if absf(a - PI / 2) < 0.14:
			continue
		var p := CAMP + Vector2(cos(a) * CAMP_RADII.x, sin(a) * CAMP_RADII.y)
		rects.append(Rect2(p - Vector2(40, 40), Vector2(80, 80)))
	return rects


func _build_territory() -> void:
	for place in PLACES:
		if place[2] == Vector2.INF:
			continue
		var marker := ScentMarker.new()
		marker.position = place[2] - Vector2(0, ScentMarker.SINK)
		marker.place = place[0]
		_world.add_child(marker)
		_markers.append(marker)
	for i in 18:
		_spawn_mouse()
	if _infos.any(func(c): return c.medicine):
		for i in 10:
			_spawn_herb()


func _spawn_herb() -> void:
	var zone: Rect2 = MOUSE_ZONES.pick_random()
	var herb := HerbPatch.new()
	herb.kind = HerbArt.GROWING.pick_random()
	herb.position = Vector2(randf_range(zone.position.x, zone.end.x), randf_range(zone.position.y, zone.end.y))
	_world.add_child(herb)
	_herbs.append(herb)


func _spawn_mouse() -> void:
	var zone: Rect2 = MOUSE_ZONES.pick_random()
	var mouse := Mouse.new()
	mouse.position = Vector2(randf_range(zone.position.x, zone.end.x), randf_range(zone.position.y, zone.end.y))
	mouse.bounds = zone
	mouse.scale = Vector2(1.4, 1.4)
	_world.add_child(mouse)
	_mice.append(mouse)


func _make_hud() -> void:
	var hud := CanvasLayer.new()
	add_child(hud)
	SplitScreen.divider(hud)
	for i in 2:
		var name_label := Fx.make_label(_infos[i].name, 28, PLAYER_COLORS[i], 8)
		name_label.position = Vector2(16 + i * 660, 10)
		name_label.size = Vector2(600, 40)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if i == 0 else HORIZONTAL_ALIGNMENT_RIGHT
		hud.add_child(name_label)
		var title := Fx.make_label(_infos[i].title, 20, Color("fff6ec"), 6)
		title.position = Vector2(16 + i * 660, 46)
		title.size = Vector2(600, 30)
		title.horizontal_alignment = name_label.horizontal_alignment
		hud.add_child(title)
		var keys := Fx.make_label("Arrows + SPACE" if i == 0 else "W A S D + E", 22, Color("fff6ec"), 6)
		keys.position = Vector2(16 + i * 660, 684)
		keys.size = Vector2(600, 30)
		keys.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if i == 0 else HORIZONTAL_ALIGNMENT_RIGHT
		hud.add_child(keys)
	_quest_back = Panel.new()
	_quest_back.position = Vector2(440, 8)
	_quest_back.size = Vector2(400, 110 if not _herbs.is_empty() else 82)
	_quest_back.add_theme_stylebox_override("panel", Fx.cute_panel(18))
	hud.add_child(_quest_back)
	_quest_label = Fx.ink_label("", 22)
	_quest_label.position = Vector2(0, 8)
	_quest_label.size = Vector2(400, _quest_back.size.y - 12)
	_quest_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_quest_back.add_child(_quest_label)
	_banner = Fx.centered_label("", 44, Color("ffd966"), 110)
	_banner.add_theme_constant_override("outline_size", 12)
	_banner.visible = false
	hud.add_child(_banner)
	_map = MiniMap.new()
	_map.position = Vector2(565, 596)
	_map.size = Vector2(150, 112)
	_map.places = PLACES
	_map.markers = _markers
	_map.players = _players
	_map.colors = PLAYER_COLORS
	hud.add_child(_map)
	_update_quests()


# --- playing -------------------------------------------------------------------------------

func _process(_delta: float) -> void:
	for i in _cameras.size():
		_cameras[i].position = _players[i].position + Vector2(0, -60)
	if not _playing:
		return
	for i in 2:
		_player_turn(i)
	_hunt()


## Shows what a player can use nearby, and uses it when they press their key
func _player_turn(i: int) -> void:
	var player := _players[i]
	var prompt := _prompts[i]
	if _on_rock[i]:
		prompt.visible = false
		return
	var spot := _nearest_spot(player.position)
	player.can_pounce = spot.is_empty()  # the key talks or uses things instead of pouncing
	prompt.visible = not spot.is_empty()
	if spot.is_empty():
		return
	var info: Dictionary = _infos[i]
	var verb: String = {"cat": "talk", "den": "look", "pile": "look", "rock": "look", "marker": "mark it!",
			"herb": "look"}[spot.what]
	if spot.what == "pile" and _carrying[i] > 0:
		verb = "drop your prey"
	elif spot.what == "rock" and info.leader:
		verb = "hold a Clan meeting!"
	elif spot.what == "herb" and info.medicine:
		verb = "pick %s" % spot.herb.kind
	elif spot.what == "den" and spot.den == "medicine" and _carrying_herbs[i] > 0:
		verb = "put away your herbs"
	prompt.text = "%s = %s" % [KEY_NAMES[i], verb]
	prompt.position = spot.pos + Vector2(-150, 10)
	if Input.is_action_just_pressed("p%d_pounce" % (i + 1)):
		_use(i, spot)


func _nearest_spot(pos: Vector2) -> Dictionary:
	var best := {}
	var best_d := USE_DISTANCE
	for npc in _npcs:
		var d := npc.talk_position().distance_to(pos)
		if d < best_d:
			best_d = d
			best = {"pos": npc.talk_position(), "what": "cat", "npc": npc}
	for spot in _spots:
		if spot.pos.distance_to(pos) < best_d:
			best_d = spot.pos.distance_to(pos)
			best = spot
	for marker in _markers:
		if not marker.done and marker.position.distance_to(pos) < best_d + 20:
			best_d = marker.position.distance_to(pos)
			best = {"pos": marker.position, "what": "marker", "marker": marker}
	for herb in _herbs:
		if herb.position.distance_to(pos) < best_d:
			best_d = herb.position.distance_to(pos)
			best = {"pos": herb.position, "what": "herb", "herb": herb}
	return best


func _use(i: int, spot: Dictionary) -> void:
	var player := _players[i]
	var info: Dictionary = _infos[i]
	var me: String = info.name
	var above := 112 * player.cat.size + 30
	match spot.what:
		"cat":
			var npc: Npc = spot.npc
			npc.face_toward(player.position)
			npc.cat.bounce(0.25)
			Sfx.play("select")
			var lines: Array = Story.DEN_CHATS[npc.npc_name] if npc.has_meta("retired") else \
					Story.chat_options(npc.npc_name, info.grown, info.medicine, info.leader)
			Fx.speech(npc, lines.pick_random().replace("{me}", me), 112 * npc.cat.size + 30, 3.0)
		"den":
			Sfx.play("click")
			if spot.den == "medicine" and _carrying_herbs[i] > 0:
				_put_away_herbs(i)
			else:
				Fx.speech(player, _den_words(i, spot.den), above, 3.0)
		"herb":
			if info.medicine:
				_pick_herb(i, spot.herb)
			else:
				Fx.speech(player, "Only medicine cats know which plants are herbs!", above, 2.5)
		"pile":
			if _carrying[i] == 0:
				Fx.speech(player, "%d pieces of prey. Let's catch more!" % _pile_count if _pile_count > 0 else
						"It's empty! Let's go hunting!", 112 * player.cat.size + 30, 2.5)
				return
			var amount: int = _carrying[i]
			_carrying[i] = 0
			_pile_count += amount
			GameState.fresh_kill = _pile_count
			GameState.add_prey_to_slot(GameState.together[i], amount)
			_pile.queue_redraw()
			_update_carrying(i)
			_update_quests()
			Sfx.play("win")
			Fx.confetti(_world, _pile.position + Vector2(0, -60), 40)
			_cheer("Fresh-kill!")
		"rock":
			if info.leader:
				_climb(i)
			elif _leader_name() != "":
				Fx.speech(player, "Only %s can speak from the Highrock. That's the leader's job!" % _leader_name(), above, 3.0)
			else:
				Fx.speech(player, "Only the leader speaks from the Highrock. That's Bluestar!", above, 3.0)
		"marker":
			_mark(i, spot.marker)


## What a player sees when they look at a den. It depends on their rank!
func _den_words(i: int, den: String) -> String:
	var info: Dictionary = _infos[i]
	match den:
		"leader":
			if info.leader:
				return "Your very own den! Your mossy nest is inside."
			if _leader_name() != "":
				return "%s's den. Only the leader sleeps in here." % _leader_name()
		"medicine":
			if info.medicine:
				return "Your medicine den! Let's find more herbs in the forest." if info.grown else \
						"The medicine den, where you're learning to be a healer!"
		"warriors":
			if not info.grown and not info.medicine:
				return "The Warriors' Den. Apprentices aren't allowed in there... yet!"
			if info.grown and not info.medicine and not info.leader:
				return "Your den! Your nest is next to Whitestorm's."
		"apprentices":
			if not info.grown and not info.medicine:
				return "Your den! Your mossy nest is in here."
	return DEN_WORDS[den]


func _pick_herb(i: int, herb: HerbPatch) -> void:
	_herbs.erase(herb)
	_carrying_herbs[i] += 1
	Sfx.play("collect", 1.2)
	Fx.burst(_world, herb.position + Vector2(0, -20), Color("c9f7a8"), 16)
	Fx.popup_text(_world, herb.position + Vector2(0, -70), "+ %s" % herb.kind, Color("c9f7a8"), 26)
	herb.queue_free()
	_players[i].cat.bounce(0.3)
	_update_carrying(i)
	await get_tree().create_timer(3.0).timeout
	_spawn_herb()


func _put_away_herbs(i: int) -> void:
	_herb_count += _carrying_herbs[i]
	_carrying_herbs[i] = 0
	_update_carrying(i)
	_update_quests()
	Sfx.play("win")
	Fx.hearts(_world, _players[i].position + Vector2(0, -80), 12)
	Fx.speech(_players[i], "The medicine den is full of good herbs now!", 112 * _players[i].cat.size + 30, 2.5)


## The leader climbs the Highrock and holds a Clan meeting: everyone cheers!
func _climb(i: int) -> void:
	var player := _players[i]
	_on_rock[i] = true
	player.frozen = true
	var back := player.position
	player.z_index = 5
	var up := create_tween()
	up.tween_property(player, "position", Vector2(630 - 60 + i * 120, 184) + OFFSET, 0.5).set_trans(Tween.TRANS_BACK)
	await up.finished
	Sfx.play("win")
	Fx.speech(player, "Let all cats gather beneath the Highrock!", 112 * player.cat.size + 30, 2.0)
	for k in 2:
		_cheer(_infos[i].name + "!")
		await get_tree().create_timer(0.7).timeout
	var down := create_tween()
	down.tween_property(player, "position", back, 0.5)
	await down.finished
	player.z_index = 0
	player.frozen = false
	_on_rock[i] = false


func _cheer(text: String) -> void:
	for npc in _npcs:
		if npc.position.distance_to(CAMP) < 900 or npc.get_parent() is CampProp:
			Fx.popup_text(_world, npc.global_position + Vector2(0, -130), text, Color("ffd966"), 24)
			npc.cat.bounce(0.25)


func _mark(i: int, marker: ScentMarker) -> void:
	marker.done = true
	Sfx.play("collect")
	Fx.burst(_world, marker.position + Vector2(0, -90), Color("c77dff"), 20)
	Fx.burst(_world, marker.position + Vector2(0, -90), Color("ffd23f"), 12)
	Fx.popup_text(_world, marker.position + Vector2(0, -170), "%s marked!" % marker.place, Color("e7c6ff"), 26)
	_players[i].cat.bounce(0.3)
	_update_quests()
	for m in _markers:
		if not m.done:
			return
	# Every marker is done: the border patrol is complete!
	_patrols += 1
	Sfx.play("win")
	for player in _players:
		Fx.confetti(_world, player.position + Vector2(0, -120), 60)
	await _show_banner("Border patrol complete!")
	await get_tree().create_timer(6.0).timeout
	for m in _markers:
		m.done = false
	_update_quests()
	_show_banner("The scent markers need refreshing. New patrol!")


func _show_banner(text: String) -> void:
	_banner.text = text
	_banner.visible = true
	_banner.modulate.a = 1.0
	_banner.pivot_offset = Vector2(640, 30)
	_banner.scale = Vector2(0.4, 0.4)
	var t := create_tween()
	t.tween_property(_banner, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK)
	t.tween_interval(2.2)
	t.tween_property(_banner, "modulate:a", 0.0, 0.5)
	await t.finished
	_banner.visible = false


func _hunt() -> void:
	for mouse: Mouse in _mice.duplicate():
		for i in 2:
			var player := _players[i]
			var d := mouse.global_position.distance_to(player.global_position)
			if player.is_pouncing() and d < CATCH_DISTANCE:
				_catch(mouse, i)
				break
			elif not player.is_pouncing() and d < SCARE_DISTANCE and player.cat.walk_amount > 0.3:
				mouse.scare(player.global_position)


func _catch(mouse: Mouse, i: int) -> void:
	_mice.erase(mouse)
	var pos := mouse.global_position
	mouse.queue_free()
	_carrying[i] += 1
	_update_carrying(i)
	Sfx.play("collect")
	Fx.burst(_world, pos + Vector2(0, -20), Color("fff27a"), 18)
	Fx.popup_text(_world, pos + Vector2(0, -70), "Take it to camp!", Color("ffd966"), 26)
	_players[i].cat.bounce(0.3)
	await get_tree().create_timer(2.0).timeout
	_spawn_mouse()


func _update_carrying(i: int) -> void:
	var holding := []
	if _carrying[i] > 0:
		holding.append("%d %s" % [_carrying[i], "mouse" if _carrying[i] == 1 else "mice"])
	if _carrying_herbs[i] > 0:
		holding.append("%d %s" % [_carrying_herbs[i], "herb" if _carrying_herbs[i] == 1 else "herbs"])
	var text: String = _infos[i].name
	if not holding.is_empty():
		text += "  (%s)" % ", ".join(holding)
	_players[i].name_label.text = text


func _update_quests() -> void:
	var marked := _markers.filter(func(m): return m.done).size()
	_quest_label.text = "Border markers: %d / %d\nFresh-kill brought home: %d" % [marked, _markers.size(), _pile_count]
	if not _herbs.is_empty() or _herb_count > 0:
		_quest_label.text += "\nHerbs in the medicine den: %d" % _herb_count


# --- drawing -------------------------------------------------------------------------------

class WorldFloor extends Node2D:
	## The ground of the whole territory, drawn once: forest, river, camp, special places
	func _draw() -> void:
		var grass := Color("86c46a")
		draw_rect(MAP, grass)
		# RiverClan's river along the left side
		draw_rect(Rect2(0, 0, 190, MAP.end.y), Color("4aa3e0"))
		for y in range(40, int(MAP.end.y), 90):
			draw_line(Vector2(40 + (y % 3) * 30, y), Vector2(80 + (y % 3) * 30, y), Color("d6f0ff"), 3.0)
		draw_string(ThemeDB.fallback_font, Vector2(20, 1210), "RiverClan", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color.WHITE)
		# Sandy path from the camp tunnel down to the training hollow
		for k in 12:
			draw_circle(CAMP + Vector2(0, 360 + k * 45), 34, Color("dcc69a"))
		draw_colored_polygon(Fx.ellipse_points(PLACES[5][1], Vector2(260, 140)), Color("e9d6a8"))
		seed(77)
		for i in 500:
			var p := Vector2(randf_range(200, MAP.end.x), randf_range(0, MAP.end.y))
			if _in_camp(p, 60.0):
				continue
			match i % 5:
				0, 1, 2: Scenery.grass_tuft(self, p, grass.darkened(0.2))
				3: Scenery.flower(self, p, Color("f7a8c8"))
				4: Scenery.flower(self, p, Color("fff3a0"))
		# The camp: a sandy clearing in a ravine, with a gorse wall and the tunnel at the bottom
		draw_colored_polygon(Fx.ellipse_points(CAMP, Vector2(610, 320), 48), Color("a8d88a"))
		draw_colored_polygon(Fx.ellipse_points(CAMP + Vector2(0, 10), Vector2(560, 280), 48), Color("f3dfb5"))
		for k in 64:
			var a := TAU * k / 64.0
			if absf(a - PI / 2) < 0.12:
				continue
			var p := CAMP + Vector2(cos(a) * CAMP_RADII.x, sin(a) * CAMP_RADII.y)
			draw_circle(p, 46, Color("4f8f45"))
			draw_circle(p + Vector2(-6, -8), 36, Color("62a554"))
			if k % 2 == 0:
				draw_circle(p + Vector2(12, -14), 6, Color("ffd23f"))
		# Special places
		_fourtrees(PLACES[0][1])
		Scenery.tree(self, PLACES[1][1], 1.8, Color("5f9e4f"), Color("8a5a35"))  # the Owl Tree
		draw_circle(PLACES[1][1] + Vector2(10, -150), 14, Color("3a2a2a"))  # the owl's hole
		for k in 7:
			Scenery.pine(self, PLACES[2][1] + Vector2(-240 + k * 80, (k % 2) * 40), 1.6, Color("3f7a45"))
		for k in 4:
			Scenery.rock(self, PLACES[3][1] + Vector2(-120 + k * 80, (k % 2) * 30), 1.6, Color("c9c4b0"))
		for k in 4:
			Scenery.rock(self, PLACES[4][1] + Vector2(-110 + k * 75, (k % 2) * 30), 1.4, Color("9e98a6"))
		for place in PLACES:
			draw_string(ThemeDB.fallback_font, place[1] + Vector2(-120, 60), place[0], HORIZONTAL_ALIGNMENT_CENTER,
					240, 30, Fx.INK)
		# Trees all over the forest (not in camp, and not on top of the special places)
		for i in 170:
			var p := Vector2(randf_range(260, MAP.end.x - 40), randf_range(120, MAP.end.y + 60))
			var crowded := _in_camp(p, 220.0)
			for place in PLACES:
				crowded = crowded or p.distance_to(place[1]) < 300 or (place[2] != Vector2.INF and p.distance_to(place[2]) < 160)
			crowded = crowded or (absf(p.x - CAMP.x) < 120 and p.y > CAMP.y)  # keep the path clear
			if not crowded:
				Scenery.tree(self, p, 0.9 + randf() * 0.4, Color("6fb85a").darkened(randf() * 0.15), Color("a0704e"))
		randomize()

	func _fourtrees(center: Vector2) -> void:
		draw_colored_polygon(Fx.ellipse_points(center + Vector2(0, 20), Vector2(260, 120)), Color("9ed27c"))
		for p in [Vector2(-200, -40), Vector2(200, -40), Vector2(-170, 90), Vector2(170, 90)]:
			Scenery.tree(self, center + p, 1.6, Color("4f8f45"), Color("8a5a35"))
		Scenery.rock(self, center + Vector2(0, 30), 1.8, Color("a7a3b5"))  # the Great Rock

	func _in_camp(p: Vector2, extra: float) -> bool:
		var d := (p - CAMP) / (CAMP_RADII + Vector2(extra, extra))
		return d.length() < 1.0


class HerbPatch extends Node2D:
	## A sparkly herb growing in the forest. Only medicine cats can pick it!
	var kind := ""
	var _time := randf() * 5.0

	func _process(delta: float) -> void:
		_time += delta
		queue_redraw()

	func _draw() -> void:
		var pulse := 0.5 + 0.5 * sin(_time * 3.0)
		draw_circle(Vector2(0, -16), 32 + pulse * 6, Color(0.8, 1, 0.8, 0.22))
		HerbArt.draw(self, Vector2.ZERO, kind, 1.2)
		Scenery.star(self, Vector2(20, -44 - pulse * 6), 5, Color(1, 1, 0.8, 0.6 + 0.4 * pulse))


class ScentMarker extends Node2D:
	## A glowing tree at the edge of the territory. Mark it on a border patrol!
	const SINK := 40.0
	var place := ""
	var done := false
	var _time := 0.0

	func _process(delta: float) -> void:
		_time += delta
		queue_redraw()

	func _draw() -> void:
		# Drawn a little lower than the node, so a cat standing in front of the tree isn't hidden by it
		draw_set_transform(Vector2(0, SINK))
		var glow := Color("ffd23f") if done else Color("c77dff")
		var pulse := 0.5 + 0.5 * sin(_time * 4.0)
		draw_circle(Vector2(0, -90), 70 + pulse * 10, Color(glow, 0.18))
		draw_circle(Vector2(0, -90), 48 + pulse * 6, Color(glow, 0.25))
		Scenery.tree(self, Vector2.ZERO, 0.8, Color("3d7a3a"))
		for k in 4:
			var a := _time * 1.5 + k * TAU / 4.0
			Scenery.star(self, Vector2(cos(a) * 55, -90 + sin(a) * 30), 7, glow)


class MiniMap extends Control:
	## A little map of the territory so nobody gets lost
	var places: Array = []
	var markers: Array = []
	var players: Array = []
	var colors: Array = []

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var s := size.x / MAP.size.x
		draw_style_box(Fx.panel_style(Color("cfe8b8"), Fx.PINK_DARK, 12, 3), Rect2(Vector2.ZERO, size))
		draw_rect(Rect2(Vector2(3, 3), Vector2(190 * s, size.y - 6)), Color("4aa3e0"))
		draw_colored_polygon(Fx.ellipse_points(CAMP * s, CAMP_RADII * s), Color("f3dfb5"))
		for place in places:
			draw_circle(place[1] * s, 4, Color("6b4428"))
		for m in markers:
			draw_circle(m.position * s, 4, Color("ffd23f") if m.done else Color("c77dff"))
		for i in players.size():
			draw_circle(players[i].position * s, 6, Fx.OUTLINE)
			draw_circle(players[i].position * s, 4.5, colors[i])
