class_name Territory
extends Node2D
## ThunderClan's whole territory in ONE world, for two players at once (split screen).
## The camp is in the middle; walk out through the gorse tunnel to the forest, Fourtrees,
## the Owl Tree, Tallpines, Sunningrocks and Snakerocks.
## Player 1: arrows + SPACE.  Player 2: W A S D + E.  The same key pounces, talks and uses things.
##   Border patrol: mark the 5 glowing scent-marker trees.
##   Hunting patrol: catch mice and carry them home to the fresh-kill pile.
## Every den has a room you can walk into (the rooms are tucked away below the map).
## Each player keeps their own rank from their save: only a leader speaks from the Highrock,
## only medicine cats can pick herbs, and the camp changes when cats have retired.
## The jobs live in their own scripts:
##   leader_duties.gd  - the leader's ceremonies on the Highrock, patrols, mentors and apprentices
##   medicine_work.gd  - sick cats in the medicine den, and asking cats to fetch herbs
##   friend_play.gd    - things the two players do with each other (tag, races, sharing tongues)
## The Clan remembers its ceremonies between visits (together_clan.gd).

const MAP := Rect2(0, 0, 3200, 2400)
const WALK := Rect2(210, 150, 2900, 2160)  # where cats can go (the river is on the left)
const CAMP := Vector2(1600, 1150)  # middle of the camp
const CAMP_RADII := Vector2(640, 335)  # the gorse wall around the camp
const OFFSET := CAMP - Vector2(640, 440)  # moves things from camp.gd's camp into this world
const TUNNEL := CAMP + Vector2(0, 290)  # just inside the gorse tunnel
const OUTSIDE := CAMP + Vector2(0, 540)  # just outside it, on the path
const USE_DISTANCE := 90.0
const CATCH_DISTANCE := 70.0
const SCARE_DISTANCE := 115.0
const PLAYER_COLORS := [Color("ffd966"), Color("ff9ec0")]
const ROOMS := ["warriors", "apprentices", "nursery", "elders", "medicine", "leader"]
const ROOM_Y := 2700.0  # the den rooms are in a row down here, out of sight of the territory
const ROOM_SIZE := Vector2(1280, 720)
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
## Where cats who grew up in a ceremony hang out (in camp.gd's camp)
const RANK_AREAS := {
	"kit": Rect2(400, 560, 150, 70), "apprentice": Rect2(860, 420, 200, 110),
	"medicine_apprentice": Rect2(330, 300, 150, 60), "medicine": Rect2(330, 300, 150, 60),
	"warrior": Rect2(260, 400, 230, 80),
}
## What Clan cats say once a ceremony has changed their rank
const RANK_CHATS := {
	"apprentice": ["I'm an apprentice now! {mentor} is teaching me SO much!", "Want to see my hunter's crouch? Wiggle wiggle... POUNCE!"],
	"medicine_apprentice": ["{mentor} is teaching me all about herbs!", "Marigold for scratches, catmint for coughs!"],
	"warrior": ["I'm a warrior now! I'll always look after the Clan.", "Thank you for my warrior name, {leader}!"],
	"medicine": ["I'm a real medicine cat now! Do you feel okay, {me}?"],
}
const DEPUTY_CHATS := ["I'm the deputy! I make sure the patrols go out, {me}.",
		"The Clan is safe while I'm watching, {me}!"]

var world: Node2D
var players: Array[TopDownPlayer] = []
var infos: Array = []  # each player's cat (from GameState.describe_slot)
var npcs: Array[Npc] = []
var menus: Array[PlayerMenu] = []
var busy := [false, false]  # a player is in a menu, a ceremony, a nap...
var inside := ["", ""]  # which den each player is inside ("" = outside)
var doors := {}  # den -> where its door is in camp
var rooms := {}  # den -> its room
var carrying := [0, 0]  # mice each player is carrying home
var carrying_herbs := [{}, {}]  # herbs each player is carrying: herb -> how many
var playing := false
var clan: TogetherClan
var duties: LeaderDuties
var medicine: MedicineWork
var play: FriendPlay

var _cameras: Array[Camera2D] = []
var _prompts: Array[Label] = []
var _spots: Array = []  # things to use: {pos, what, ...}
var _markers: Array[ScentMarker] = []
var _mice: Array[Mouse] = []
var _pile: CampProp
var _pile_count := 0
var _patrols := 0
var _herbs: Array[HerbPatch] = []  # herbs growing in the forest (for medicine cats)
var _hud: CanvasLayer
var _hud_names: Array[Label] = []
var _hud_titles: Array[Label] = []
var _quest_back: Panel
var _quest_label: Label
var _banners := 0  # how many banners are showing right now
var _map: MiniMap
var _card: InfoCard


func _ready() -> void:
	for slot in GameState.together:
		infos.append(GameState.describe_slot(slot))
	if infos.size() < 2 or infos.has({}):
		Transition.go.call_deferred("res://scenes/title.tscn")  # nobody to play with
		return
	GameState.make_friends(GameState.together[0], GameState.together[1])  # playing together = friends!
	GameState.fresh_kill = 0  # the pile in this world starts empty
	clan = TogetherClan.open(infos.any(func(c): return c.grown))
	duties = LeaderDuties.new(self)
	medicine = MedicineWork.new(self)
	play = FriendPlay.new(self)
	for helper in [duties, medicine, play]:
		add_child(helper)

	world = WorldFloor.new()
	world.y_sort_enabled = true
	_cameras = SplitScreen.make(self, world, MAP)
	_build_camp()
	_build_rooms()
	_build_territory()
	var blockers: Array[Rect2] = _gorse_wall()
	for prop in world.get_children():
		if prop is CampProp:
			blockers.append(prop.footprint())
	for i in 2:
		var player := SplitScreen.make_player(infos[i], i, WALK)
		player.position = CAMP + Vector2(-90 + i * 180, 200)
		player.blockers = blockers
		world.add_child(player)
		player.name_label.add_theme_color_override("font_color", PLAYER_COLORS[i])
		players.append(player)
		_cameras[i].position = player.position
		var prompt := Fx.make_label("", 22, PLAYER_COLORS[i], 6)
		prompt.size = Vector2(300, 30)
		prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		prompt.z_index = 20
		world.add_child(prompt)
		_prompts.append(prompt)
	for npc in npcs:
		if npc.get_parent() == world and not npc.has_meta("retired"):
			settle(npc)  # apprentices find their mentors
	update_deputy()

	_make_hud()
	_card = InfoCard.new()
	add_child(_card)
	var intro := "Patrols: mark glowing trees and bring mice home."
	if leader_name() != "":
		intro += "\nLeader: hold ceremonies at the Highrock!"
	if medicine.active():
		intro += "\nMedicine cat: help sick cats in your den!"
	intro += "\nWalk up to each other to play together!"
	_card.show_card("ThunderClan Together!", intro, "Press SPACE to start!")
	await _card.closed
	playing = true
	for player in players:
		player.frozen = false


# --- building the world --------------------------------------------------------------------

func _build_camp() -> void:
	var rock := _add_prop("high_rock", Vector2(640, 300) + OFFSET, "Highrock")
	# Cats who retired because one of the players took their place
	var retired := []
	if leader_name() != "":
		retired.append("Bluestar")
	if infos.any(func(c): return c.rank in ["deputy", "leader"]):
		retired.append("Lionheart")
	if infos.any(func(c): return c.rank == "head"):
		retired.append("Spottedleaf")
	if not "Bluestar" in retired:
		var bluestar := _make_clan_cat("Bluestar")
		bluestar.position = Vector2(-10, -136)
		bluestar.talk_spot = Vector2(0, 175)
		rock.add_child(bluestar)
		npcs.append(bluestar)
	var elder_spots := [Vector2(870, 650), Vector2(1170, 545), Vector2(800, 670)]
	for who in retired:
		var elder := _make_clan_cat(who, -1.0)
		elder.position = elder_spots.pop_front() + OFFSET
		elder.set_meta("retired", true)
		world.add_child(elder)
		npcs.append(elder)
	_spots.append({"pos": Vector2(530, 352) + OFFSET, "what": "rock"})
	_spots.append({"pos": Vector2(748, 322) + OFFSET, "what": "den", "den": "leader"})
	doors["leader"] = Vector2(748, 322) + OFFSET
	for key in DENS:
		var den: Array = DENS[key]
		_add_prop("medicine" if key == "medicine" else "den", den[0] + OFFSET, den[1])
		_spots.append({"pos": den[0] + OFFSET + Vector2(0, 22), "what": "den", "den": key})
		doors[key] = den[0] + OFFSET + Vector2(0, 22)
	_pile = _add_prop("fresh_kill", Vector2(840, 470) + OFFSET, "Fresh-kill Pile")
	_spots.append({"pos": Vector2(840, 492) + OFFSET, "what": "pile"})
	for c in CLAN:
		if c[0] in retired:
			continue
		var npc := _make_clan_cat(c[0], [-1.0, 1.0].pick_random())
		npc.position = c[1] + OFFSET
		var area: Rect2 = c[2]
		if area.has_area():
			npc.wander_area = Rect2(area.position + OFFSET, area.size)
		world.add_child(npc)
		npcs.append(npc)
	# Den cats who grew up (or became deputy) live out in camp now
	for key in Den.DENS:
		for c in Den.DENS[key].cats:
			if _lives_in_camp(c[0]):
				var npc := _make_clan_cat(c[0], [-1.0, 1.0].pick_random())
				var area: Rect2 = RANK_AREAS.get(clan.rank(c[0]), RANK_AREAS.warrior)
				npc.position = area.get_center() + OFFSET
				world.add_child(npc)
				npcs.append(npc)


## A cat from the story, with the name and size the Clan remembers for them
func _make_clan_cat(cat_name: String, face := 1.0) -> Npc:
	var npc := Npc.make(cat_name, face)
	npc.set_meta("base", cat_name)
	if clan.cats.has(cat_name):
		npc.rename(clan.shown_name(cat_name))
		npc.resize(TogetherClan.size_for(cat_name, clan.rank(cat_name)))
	if clan.rank(cat_name) == "kit":
		npc.hops = true
		npc.speed = 120.0
	return npc


## Den cats normally sleep in their den, unless a ceremony changed them
func _lives_in_camp(cat_name: String) -> bool:
	return clan.cats.has(cat_name) or clan.deputy == cat_name


## Where a Clan cat hangs out: apprentices follow a mentor who is playing, kits play by the
## nursery, and cats who grew up in a ceremony wander near their new den.
func settle(npc: Npc) -> void:
	var cat_name: String = npc.get_meta("base", npc.npc_name)
	var rank := clan.rank(cat_name)
	npc.hops = rank == "kit"
	npc.speed = 120.0 if npc.hops else 70.0
	npc.follow_target = null
	if rank in TogetherClan.APPRENTICE_RANKS:
		for i in players.size():
			if infos[i].name == clan.mentor(cat_name):
				npc.follow_target = players[i]
				npc.wander_area = Rect2()
				return
	if clan.cats.has(cat_name) or cat_name == clan.deputy:
		var area: Rect2 = RANK_AREAS.get(rank, RANK_AREAS.warrior)
		npc.wander_area = Rect2(area.position + OFFSET, area.size)


## Who the deputy is: a player who is deputy in their own game, or whoever the Clan chose
func deputy_name() -> String:
	for info in infos:
		if info.rank == "deputy":
			return info.name
	if clan.deputy != "":
		return clan.deputy
	if leader_name() == "":
		return "Lionheart"  # Bluestar's deputy, like in the book
	return ""


func is_deputy(i: int) -> bool:
	return deputy_name() == infos[i].name


## Puts the "Deputy" tag on the right cat
func update_deputy() -> void:
	var deputy := deputy_name()
	for npc in npcs:
		npc.set_title("Deputy" if npc.npc_name == deputy and not npc.has_meta("retired") else "")
	update_quests()


## The name of a player who is leader ("" if neither of you is)
func leader_name() -> String:
	for info in infos:
		if info.leader:
			return info.name
	return ""


func _add_prop(kind: String, pos: Vector2, label: String) -> CampProp:
	var prop := CampProp.new().setup(kind, label)
	prop.position = pos
	world.add_child(prop)
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


## The inside of every den, each one a room in the same world
func _build_rooms() -> void:
	var leader := leader_name()
	for k in ROOMS.size():
		var key: String = ROOMS[k]
		var den: Dictionary = Den.DENS[key]
		var origin := room_origin(key)
		var room := DenRoom.new()
		room.den = den
		room.position = origin
		world.add_child(room)
		rooms[key] = room
		var nests: Array = den.nests.duplicate()
		if key == "leader":
			nests.append([Vector2(640, 380), "%s's nest" % (leader if leader != "" else "Bluestar")])
		if key == "medicine" and medicine.active():
			for spot in MedicineWork.SICK_NESTS:
				nests.append([spot, "Sick cats' nest"])
		for i in 2:
			if _home_den(i) == key and key != "leader":
				nests.append([Vector2(540 + i * 200, 480), "%s's nest" % infos[i].name])
		for n in nests:
			var nest := Den.Nest.new()
			nest.position = n[0]
			nest.label = n[1]
			if nest.label == "Spottedleaf's nest" and infos.any(func(c): return c.rank == "head"):
				nest.label = "Yellowfang's nest"
			room.add_child(nest)
			var owner := -1
			for i in 2:
				if nest.label == "%s's nest" % infos[i].name:
					owner = i
			if owner >= 0:
				_spots.append({"pos": origin + n[0], "what": "nest", "owner": owner})
		for c in den.cats:
			if _lives_in_camp(c[0]):
				continue
			var npc := _make_clan_cat(c[0], [-1.0, 1.0].pick_random())
			npc.position = c[1]
			npc.cat.sleeping = c[2]
			npc.set_meta("den_cat", true)
			room.add_child(npc)
			npcs.append(npc)
		for thing in den.get("herbs", []) + den.get("treasures", []):
			var text: String = thing[2].format({"nine": "Nine little stars, one for each of %s's nine lives." % (
					leader if leader != "" else "Bluestar")})
			_spots.append({"pos": origin + thing[0], "what": "thing", "name": thing[1], "text": text})


func room_origin(key: String) -> Vector2:
	return Vector2(ROOMS.find(key) * (ROOM_SIZE.x + 200), ROOM_Y)


## Which den a player sleeps in, from their rank
func _home_den(i: int) -> String:
	var info: Dictionary = infos[i]
	if info.leader:
		return "leader"
	if info.medicine:
		return "medicine"
	return "warriors" if info.grown else "apprentices"


## Walk through a den's door into its room
func _enter_den(i: int, key: String) -> void:
	var info: Dictionary = infos[i]
	var player := players[i]
	if key == "warriors" and not info.grown and not info.medicine:
		say(i, "Apprentices aren't allowed in the Warriors' Den... yet!", 2.5)
		return
	Sfx.play("click")
	inside[i] = key
	var origin := room_origin(key)
	player.position = origin + Den.EXIT + Vector2(0, -60)
	player.bounds = Rect2(origin + Den.INSIDE.position, Den.INSIDE.size)
	player.round_bounds = true
	_set_camera_room(i, Rect2(origin, ROOM_SIZE))
	say(i, _den_words(i, key), 3.0)
	if key == "medicine":
		medicine.put_away(i)


## Walk out of the bottom of a den, back into camp
func _leave_den(i: int) -> void:
	var player := players[i]
	player.position = doors[inside[i]] + Vector2(0, 40)
	player.bounds = WALK
	player.round_bounds = false
	inside[i] = ""
	Sfx.play("click")
	_set_camera_room(i, MAP)


func _set_camera_room(i: int, area: Rect2) -> void:
	var camera := _cameras[i]
	camera.limit_left = int(area.position.x)
	camera.limit_top = int(area.position.y)
	camera.limit_right = int(area.end.x)
	camera.limit_bottom = int(area.end.y)
	camera.position = players[i].position + Vector2(0, -60)
	camera.reset_smoothing()


## Curl up in your own nest for a nap
func _nap(i: int) -> void:
	var player := players[i]
	var info: Dictionary = infos[i]
	busy[i] = true
	player.frozen = true
	player.cat.sleeping = true
	await get_tree().create_timer(2.5).timeout
	var dreams: Array = Den.STARCLAN_DREAMS if (info.medicine or info.leader) and randf() < 0.6 else Den.NAP_DREAMS
	player.cat.sleeping = false
	player.cat.bounce(0.35)
	Sfx.play("powerup")
	Fx.hearts(world, player.position + Vector2(0, -60), 10)
	say(i, dreams.pick_random(), 4.0)
	player.frozen = false
	busy[i] = false


func _build_territory() -> void:
	for place in PLACES:
		if place[2] == Vector2.INF:
			continue
		var marker := ScentMarker.new()
		marker.position = place[2] - Vector2(0, ScentMarker.SINK)
		marker.place = place[0]
		world.add_child(marker)
		_markers.append(marker)
	for i in 18:
		_spawn_mouse()
	if medicine.active():
		for i in 10:
			spawn_herb()


## A herb starts growing somewhere in the forest (a random kind unless you say which)
func spawn_herb(kind := "") -> void:
	var zone: Rect2 = MOUSE_ZONES.pick_random()
	var herb := HerbPatch.new()
	herb.kind = kind if kind != "" else HerbArt.GROWING.pick_random()
	herb.tagged = medicine.is_wanted(herb.kind)
	herb.position = Vector2(randf_range(zone.position.x, zone.end.x), randf_range(zone.position.y, zone.end.y))
	world.add_child(herb)
	_herbs.append(herb)


## How many herbs of this kind are growing in the forest
func herbs_growing(kind: String) -> int:
	return _herbs.filter(func(h): return h.kind == kind).size()


## Shows the herb's name over every patch somebody has been asked to find
func update_herb_tags() -> void:
	for herb in _herbs:
		herb.tagged = medicine.is_wanted(herb.kind)


func _spawn_mouse() -> void:
	var zone: Rect2 = MOUSE_ZONES.pick_random()
	var mouse := Mouse.new()
	mouse.position = Vector2(randf_range(zone.position.x, zone.end.x), randf_range(zone.position.y, zone.end.y))
	mouse.bounds = zone
	mouse.scale = Vector2(1.4, 1.4)
	world.add_child(mouse)
	_mice.append(mouse)


func _make_hud() -> void:
	_hud = CanvasLayer.new()
	add_child(_hud)
	SplitScreen.divider(_hud)
	for i in 2:
		var name_label := Fx.make_label(infos[i].name, 28, PLAYER_COLORS[i], 8)
		name_label.position = Vector2(16 + i * 660, 10)
		name_label.size = Vector2(600, 40)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if i == 0 else HORIZONTAL_ALIGNMENT_RIGHT
		_hud.add_child(name_label)
		_hud_names.append(name_label)
		var title := Fx.make_label(infos[i].title, 20, Color("fff6ec"), 6)
		title.position = Vector2(16 + i * 660, 46)
		title.size = Vector2(600, 30)
		title.horizontal_alignment = name_label.horizontal_alignment
		_hud.add_child(title)
		_hud_titles.append(title)
		var keys := Fx.make_label("Arrows + SPACE" if i == 0 else "W A S D + E", 22, Color("fff6ec"), 6)
		keys.position = Vector2(16 + i * 660, 684)
		keys.size = Vector2(600, 30)
		keys.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if i == 0 else HORIZONTAL_ALIGNMENT_RIGHT
		_hud.add_child(keys)
	_quest_back = Panel.new()
	_quest_back.position = Vector2(440, 8)
	_quest_back.size = Vector2(400, 82)
	_quest_back.add_theme_stylebox_override("panel", Fx.cute_panel(18))
	_hud.add_child(_quest_back)
	_quest_label = Fx.ink_label("", 20)
	_quest_label.position = Vector2(0, 8)
	_quest_label.size = Vector2(400, 70)
	_quest_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_quest_back.add_child(_quest_label)
	_map = MiniMap.new()
	_map.position = Vector2(565, 596)
	_map.size = Vector2(150, 112)
	_map.places = PLACES
	_map.markers = _markers
	_map.players = players
	_map.where = map_position
	_map.colors = PLAYER_COLORS
	_hud.add_child(_map)
	medicine.make_hud(_hud)
	play.make_hud(_hud, _map)
	# The menus go on their own layer, on top of everything else
	var menu_layer := CanvasLayer.new()
	menu_layer.layer = 5
	add_child(menu_layer)
	for i in 2:
		var menu := PlayerMenu.make(i)
		menu_layer.add_child(menu)
		menus.append(menu)
	update_quests()


# --- playing -------------------------------------------------------------------------------

func _process(_delta: float) -> void:
	for i in _cameras.size():
		_cameras[i].position = players[i].position + Vector2(0, -60)
	if not playing:
		return
	for i in 2:
		_player_turn(i)
	_hunt()


## Shows what a player can use nearby, and uses it when they press their key
func _player_turn(i: int) -> void:
	var player := players[i]
	var prompt := _prompts[i]
	if busy[i] or menus[i].is_open():
		prompt.visible = false
		return
	if inside[i] != "":
		var exit := room_origin(inside[i]) + Den.EXIT
		if player.position.y > exit.y - 12 and absf(player.position.x - exit.x) < 90:
			_leave_den(i)
			return
	if play.running():
		player.can_pounce = true  # in tag and races your key is just for pouncing
		prompt.visible = false
		return
	var spot := _nearest_spot(i)
	player.can_pounce = spot.is_empty()  # the key talks or uses things instead of pouncing
	prompt.visible = not spot.is_empty()
	if spot.is_empty():
		return
	prompt.text = "%s = %s" % [KEY_NAMES[i], _verb(i, spot)]
	prompt.position = spot.pos + Vector2(-150, 10)
	if Input.is_action_just_pressed("p%d_pounce" % (i + 1)):
		_use(i, spot)


## What pressing your key will do here
func _verb(i: int, spot: Dictionary) -> String:
	var info: Dictionary = infos[i]
	match spot.what:
		"cat":
			if spot.npc.has_meta("patient") and info.medicine:
				return "help %s" % spot.npc.npc_name
			return "talk"
		"friend":
			return "play with %s" % infos[1 - i].name
		"den":
			return "go inside"
		"pile":
			return "drop your prey" if carrying[i] > 0 else "look"
		"rock":
			if info.leader:
				return "hold a Clan meeting!"
			if is_deputy(i):
				return "send out patrols"
			return "look"
		"marker":
			return "mark it!"
		"herb":
			return "pick %s" % spot.herb.kind if medicine.can_pick(i, spot.herb.kind) else "look"
		"nest":
			return "nap" if spot.owner == i else "look"
	return "look"


func _nearest_spot(i: int) -> Dictionary:
	var pos := players[i].position
	var best := {}
	var best_d := USE_DISTANCE
	for npc in npcs:
		if not npc.visible or npc.has_meta("busy"):
			continue
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
	# The other player: walk up to them to play together
	var other := players[1 - i]
	if available(1 - i) and inside[0] == inside[1] and other.position.distance_to(pos) < best_d + 30:
		best = {"pos": other.position, "what": "friend"}
	return best


func _use(i: int, spot: Dictionary) -> void:
	var info: Dictionary = infos[i]
	match spot.what:
		"cat":
			_talk(i, spot.npc)
		"friend":
			play.friend_menu(i)
		"den":
			_enter_den(i, spot.den)
		"thing":
			Sfx.play("select")
			say(i, "%s: %s" % [spot.name, spot.text], 3.5)
		"nest":
			if spot.owner == i:
				_nap(i)
			else:
				say(i, "That's %s's nest. So cozy!" % infos[spot.owner].name, 2.5)
		"herb":
			if medicine.can_pick(i, spot.herb.kind):
				_pick_herb(i, spot.herb)
			else:
				say(i, "Only medicine cats know which plants are herbs!", 2.5)
		"pile":
			if carrying[i] == 0:
				say(i, "%d pieces of prey. Let's catch more!" % _pile_count if _pile_count > 0 else
						"It's empty! Let's go hunting!", 2.5)
				return
			GameState.add_prey_to_slot(GameState.together[i], carrying[i])
			add_to_pile(carrying[i])
			carrying[i] = 0
			update_carrying(i)
		"rock":
			if info.leader:
				duties.clan_meeting(i)
			elif is_deputy(i):
				duties.send_patrol(i)
			elif leader_name() != "":
				say(i, "Only %s can speak from the Highrock. That's the leader's job!" % leader_name(), 3.0)
			else:
				say(i, "Only the leader speaks from the Highrock. That's Bluestar!", 3.0)
		"marker":
			_mark(i, spot.marker)


## Talking to a Clan cat. Medicine cats can ask them to fetch herbs, and mentors can train
## their apprentices.
func _talk(i: int, npc: Npc) -> void:
	npc.face_toward(players[i].position)
	npc.cat.bounce(0.25)
	Sfx.play("select")
	if npc.cat.sleeping:
		Fx.speech(npc, "Zzz... (Shh! %s is sleeping.)" % npc.npc_name, 112 * npc.cat.size + 30, 2.0)
		return
	if npc.has_meta("patient"):
		medicine.use_patient(i, npc)
		return
	var cat_name: String = npc.get_meta("base", npc.npc_name)
	if clan.rank(cat_name) in TogetherClan.APPRENTICE_RANKS and clan.mentor(cat_name) == infos[i].name:
		duties.talk_to_apprentice(i, npc)
		return
	if infos[i].medicine and medicine.can_ask(npc):
		medicine.talk_menu(i, npc)
		return
	chat(i, npc)


## A Clan cat says something friendly, depending on who they are and who you are
func chat(i: int, npc: Npc) -> void:
	var info: Dictionary = infos[i]
	var cat_name: String = npc.get_meta("base", npc.npc_name)
	var lines: Array = Story.chat_options(npc.npc_name, info.grown, info.medicine, info.leader)
	if npc.has_meta("retired") or npc.has_meta("den_cat"):
		lines = Story.DEN_CHATS.get(npc.npc_name, ["Hello, {me}!"])
	elif npc.npc_name == deputy_name():
		lines = DEPUTY_CHATS
	elif clan.cats.has(cat_name) and RANK_CHATS.has(clan.rank(cat_name)) and cat_name != "Graypaw":
		lines = RANK_CHATS[clan.rank(cat_name)]
	var leader := leader_name() if leader_name() != "" else "Bluestar"
	var text: String = lines.pick_random().format({"me": info.name, "mentor": clan.mentor(cat_name), "leader": leader})
	Fx.speech(npc, text, 112 * npc.cat.size + 30, 3.0)


## A speech bubble over a player's cat
func say(i: int, text: String, seconds := 3.0) -> void:
	for child in players[i].get_children():
		if child is PanelContainer:
			child.queue_free()  # the old bubble goes away
	Fx.speech(players[i], text, 112 * players[i].cat.size + 30, seconds)


## Asks player i something with their own menu. Returns which answer they picked,
## or -1 if their menu was already open. Use it with await.
func ask(i: int, question: String, answers: Array) -> int:
	if menus[i].visible:
		return -1
	var player := players[i]
	var was_frozen := player.frozen
	var was_busy: bool = busy[i]
	busy[i] = true
	player.frozen = true
	_prompts[i].visible = false
	menus[i].ask(question, answers)
	var pick: int = await menus[i].chosen
	player.frozen = was_frozen
	busy[i] = was_busy
	return pick


## True if player i is free to be asked something (not in a menu, a ceremony or a nap)
func available(i: int) -> bool:
	return playing and not busy[i] and not menus[i].is_open()


## A player's rank changed in a ceremony: read their save again and update how they look
func refresh_player(i: int) -> void:
	infos[i] = GameState.describe_slot(GameState.together[i])
	var player := players[i]
	player.cat.size = infos[i].size
	player.name_label.position = Vector2(-150, -112 * player.cat.size - 34)
	_hud_names[i].text = infos[i].name
	_hud_titles[i].text = infos[i].title
	update_carrying(i)
	update_deputy()


# --- Clan cats on the move -------------------------------------------------------------------

## Clan cats out in camp who are free to help (for patrols, errands, and getting sick)
func camp_cats(ranks: Array) -> Array[Npc]:
	var found: Array[Npc] = []
	for npc in npcs:
		if npc.get_parent() == world and npc.visible and not npc.has_meta("busy") and npc.follow_target == null \
				and not npc.has_meta("patient") and not npc.has_meta("retired") \
				and clan.rank(npc.get_meta("base", "")) in ranks and npc.position.distance_to(CAMP) < 700:
			found.append(npc)
	return found


## Stops a Clan cat wandering, so they can walk somewhere for a job
func hold_npc(npc: Npc) -> void:
	if npc.has_meta("busy"):
		return
	npc.set_meta("busy", true)
	npc.set_meta("home", npc.position)
	npc.set_meta("area", npc.wander_area)
	npc.set_meta("following", npc.follow_target)
	npc.wander_area = Rect2()
	npc.follow_target = null


## The job is done: walk back home (if you like) and go back to wandering or following
func release_npc(npc: Npc, go_home := true) -> void:
	if go_home and npc.has_meta("home"):
		await npc.walk_to(npc.get_meta("home"))
	npc.wander_area = npc.get_meta("area", Rect2())
	npc.follow_target = npc.get_meta("following") if npc.has_meta("following") else null
	for key in ["busy", "home", "area", "following"]:
		npc.remove_meta(key)


## A Clan cat goes out through the gorse tunnel for a while (on patrol, or to find herbs).
## Await it: it's done when they're back inside the tunnel.
func send_away(npc: Npc, seconds: float) -> void:
	hold_npc(npc)
	await npc.walk_to(TUNNEL)
	await npc.walk_to(OUTSIDE)
	npc.visible = false
	await get_tree().create_timer(seconds).timeout
	npc.visible = true
	await npc.walk_to(TUNNEL)


## A cat sleeping in a den gets up and comes out into camp (for a ceremony)
func bring_to_camp(npc: Npc) -> void:
	for key in rooms:
		if npc.get_parent() == rooms[key]:
			npc.reparent(world)
			npc.position = doors[key] + Vector2(0, 40)
			npc.remove_meta("den_cat")
			npc.cat.sleeping = false


# --- prey, herbs, patrols ----------------------------------------------------------------------

## Prey goes on the fresh-kill pile in camp
func add_to_pile(amount: int) -> void:
	_pile_count += amount
	GameState.fresh_kill = _pile_count
	_pile.queue_redraw()
	update_quests()
	Sfx.play("win")
	Fx.confetti(world, _pile.position + Vector2(0, -60), 40)
	cheer("Fresh-kill!")


## What a player sees when they look at a den. It depends on their rank!
func _den_words(i: int, den: String) -> String:
	var info: Dictionary = infos[i]
	match den:
		"leader":
			if info.leader:
				return "Your very own den! Curl up in your nest for a nap."
			if leader_name() != "":
				return "%s's den. Only the leader sleeps in here." % leader_name()
		"medicine":
			if info.medicine:
				return "Your medicine den! Your nest is here, next to all the herbs." if info.grown else \
						"The medicine den, where you're learning to be a healer!"
		"warriors":
			if not info.grown and not info.medicine:
				return "The Warriors' Den. Apprentices aren't allowed in there... yet!"
			if info.grown and not info.medicine and not info.leader:
				return "Your den! Your nest is next to Whitestorm's."
			if info.leader:
				return "The Warriors' Den. Your warriors are napping after their patrols."
		"apprentices":
			if not info.grown and not info.medicine:
				return "Your den! Your mossy nest is in here."
	return DEN_WORDS[den]


func _pick_herb(i: int, herb: HerbPatch) -> void:
	_herbs.erase(herb)
	var held: Dictionary = carrying_herbs[i]
	held[herb.kind] = held.get(herb.kind, 0) + 1
	Sfx.play("collect", 1.2)
	Fx.burst(world, herb.position + Vector2(0, -20), Color("c9f7a8"), 16)
	Fx.popup_text(world, herb.position + Vector2(0, -70), "+ %s" % herb.kind, Color("c9f7a8"), 26)
	herb.queue_free()
	players[i].cat.bounce(0.3)
	medicine.picked(i, herb.kind)
	update_carrying(i)
	await get_tree().create_timer(3.0).timeout
	spawn_herb()


func cheer(text: String) -> void:
	for npc in npcs:
		if npc.visible and (npc.position.distance_to(CAMP) < 900 or npc.get_parent() is CampProp):
			Fx.popup_text(world, npc.global_position + Vector2(0, -130), text, Color("ffd966"), 24)
			npc.cat.bounce(0.25)


func _mark(i: int, marker: ScentMarker) -> void:
	marker.done = true
	Sfx.play("collect")
	Fx.burst(world, marker.position + Vector2(0, -90), Color("c77dff"), 20)
	Fx.burst(world, marker.position + Vector2(0, -90), Color("ffd23f"), 12)
	Fx.popup_text(world, marker.position + Vector2(0, -170), "%s marked!" % marker.place, Color("e7c6ff"), 26)
	players[i].cat.bounce(0.3)
	update_quests()
	for m in _markers:
		if not m.done:
			return
	# Every marker is done: the border patrol is complete!
	_patrols += 1
	Sfx.play("win")
	for player in players:
		Fx.confetti(world, player.position + Vector2(0, -120), 60)
	await show_banner("Border patrol complete!")
	await get_tree().create_timer(6.0).timeout
	for m in _markers:
		m.done = false
	update_quests()
	show_banner("The scent markers need refreshing. New patrol!")


## Big words across the middle of the screen for a few seconds. You can await it.
func show_banner(text: String) -> void:
	var banner := Fx.centered_label(text, 38, Color("ffd966"), 170 + 58 * _banners)
	banner.add_theme_constant_override("outline_size", 12)
	banner.pivot_offset = Vector2(640, 28)
	banner.scale = Vector2(0.4, 0.4)
	_hud.add_child(banner)
	_banners += 1
	var t := create_tween()
	t.tween_property(banner, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK)
	t.tween_interval(2.6)
	t.tween_property(banner, "modulate:a", 0.0, 0.5)
	await t.finished
	banner.queue_free()
	_banners -= 1


func _hunt() -> void:
	for mouse: Mouse in _mice.duplicate():
		for i in 2:
			var player := players[i]
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
	carrying[i] += 1
	update_carrying(i)
	Sfx.play("collect")
	Fx.burst(world, pos + Vector2(0, -20), Color("fff27a"), 18)
	Fx.popup_text(world, pos + Vector2(0, -70), "Take it to camp!", Color("ffd966"), 26)
	players[i].cat.bounce(0.3)
	await get_tree().create_timer(2.0).timeout
	_spawn_mouse()


## Where to show a player on the little map (at the door if they're inside a den)
func map_position(i: int) -> Vector2:
	return doors[inside[i]] if inside[i] != "" else players[i].position


func update_carrying(i: int) -> void:
	var holding := []
	if carrying[i] > 0:
		holding.append("%d %s" % [carrying[i], "mouse" if carrying[i] == 1 else "mice"])
	var herbs := 0
	for kind in carrying_herbs[i]:
		herbs += carrying_herbs[i][kind]
	if herbs > 0:
		holding.append("%d %s" % [herbs, "herb" if herbs == 1 else "herbs"])
	var text: String = infos[i].name
	if not holding.is_empty():
		text += "  (%s)" % ", ".join(holding)
	players[i].name_label.text = text


func update_quests() -> void:
	if _quest_label == null:
		return
	var marked := _markers.filter(func(m): return m.done).size()
	var lines := ["Border markers: %d / %d" % [marked, _markers.size()], "Fresh-kill brought home: %d" % _pile_count]
	var deputy := deputy_name()
	lines.append("Deputy: %s" % (deputy if deputy != "" else "nobody yet!"))
	if medicine.active():
		lines.append("Sick cats helped: %d" % medicine.healed)
	_quest_label.text = "\n".join(lines)
	_quest_back.size.y = lines.size() * 28 + 16
	_quest_label.size.y = _quest_back.size.y - 12


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


class DenRoom extends Node2D:
	## The inside of one den (drawn the same way as the one-player den scene)
	var den: Dictionary

	func _process(_delta: float) -> void:
		if den.get("cave", false):
			queue_redraw()  # the lichen curtain sways

	func _draw() -> void:
		Den.draw_room(self, den)


class HerbPatch extends Node2D:
	## A sparkly herb growing in the forest. Only medicine cats can pick it,
	## unless a medicine cat asked you to find this kind (then its name shows above it).
	var kind := ""
	var tagged := false
	var _time := randf() * 5.0

	func _process(delta: float) -> void:
		_time += delta
		queue_redraw()

	func _draw() -> void:
		var pulse := 0.5 + 0.5 * sin(_time * 3.0)
		draw_circle(Vector2(0, -16), 32 + pulse * 6, Color(0.8, 1, 0.8, 0.22))
		HerbArt.draw(self, Vector2.ZERO, kind, 1.2)
		Scenery.star(self, Vector2(20, -44 - pulse * 6), 5, Color(1, 1, 0.8, 0.6 + 0.4 * pulse))
		if tagged:
			var font := ThemeDB.fallback_font
			var pos := Vector2(-100, -66 - pulse * 4)
			draw_string_outline(font, pos, kind, HORIZONTAL_ALIGNMENT_CENTER, 200, 22, 6, Fx.OUTLINE)
			draw_string(font, pos, kind, HORIZONTAL_ALIGNMENT_CENTER, 200, 22, Color("c9f7a8"))


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
	var where: Callable  # where to draw player i
	var target := Vector2.INF  # where a race is going (a gold star)

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
		if target != Vector2.INF:
			Scenery.star(self, target * s, 9, Color("ffd23f"))
		for i in players.size():
			draw_circle(where.call(i) * s, 6, Fx.OUTLINE)
			draw_circle(where.call(i) * s, 4.5, colors[i])
