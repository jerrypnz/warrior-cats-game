class_name ClanOutings
extends Node
## Clan cats in ThunderClan Together don't all stay in camp: every so often a warrior or an
## apprentice walks out of the gorse tunnel to somewhere in the territory (sunning on Sunningrocks,
## hunting in the forest, looking up at the Owl Tree...), stays a while, and comes home.
## A few are already out when you start, so the forest feels busy. You can talk to them out there.

## Places cats go: [where, what they say there]
const SPOTS := [
	[Vector2(470, 1460), ["The sun is so warm on Sunningrocks!", "Mmm, I could nap here all day."]],
	[Vector2(460, 650), ["The pine needles are so soft under my paws!", "I can hear a squirrel up in the pines!"]],
	[Vector2(2510, 610), ["Shh! The owl is asleep up there.", "The Owl Tree is the tallest tree in the forest!"]],
	[Vector2(2830, 1820), ["Careful! Adders live in Snakerocks.", "I'm keeping watch so nobody gets near the snakes!"]],
	[Vector2(1430, 430), ["Fourtrees is where the Clans meet at the full moon!", "I love the Great Rock!"]],
	[Vector2(1000, 420), ["Shh! I'm stalking a mouse!", "I'm hunting for the fresh-kill pile!"]],
	[Vector2(2250, 1980), ["I smell a vole! Shh!", "Hunting is the best!"]],
	[Vector2(2880, 1150), ["I'm checking the border scent markers.", "All quiet over here!"]],
	[Vector2(360, 1100), ["I can see RiverClan cats across the river!", "Splash! The river is so fast today."]],
]
const AT_START := 5  # cats already out when you start
const MOST_OUT := 7
const STAY_IN_CAMP := 6  # always leave at least this many cats in camp
const GO_EVERY := [12.0, 25.0]
const STAY := [40.0, 80.0]  # how long they stay out

var t: Territory
var _timer := 15.0
var _out: Array[Npc] = []


func _init(territory: Territory) -> void:
	t = territory


## Some cats are already out in the forest when the world starts
func start() -> void:
	for k in AT_START:
		_go_out(true)


func _process(delta: float) -> void:
	if not t.playing:
		return
	_timer -= delta
	if _timer <= 0.0:
		_timer = randf_range(GO_EVERY[0], GO_EVERY[1])
		if _out.size() < MOST_OUT:
			_go_out(false)


## The place with the fewest cats there right now
func _quiet_spot() -> Array:
	var spots := SPOTS.duplicate()
	spots.shuffle()
	var best: Array = spots[0]
	var best_count := 99
	for spot in spots:
		var count := _out.filter(func(npc): return npc.get_meta("outing") == spot[1]).size()
		if count < best_count:
			best = spot
			best_count = count
	return best


func _go_out(already_there: bool) -> void:
	var cats := t.camp_cats(["warrior", "apprentice"])
	if cats.size() <= STAY_IN_CAMP:
		return
	var npc: Npc = cats.pick_random()
	var spot := _quiet_spot()
	var there: Vector2 = spot[0] + Vector2(randf_range(-60, 60), randf_range(-30, 30))
	t.hold_npc(npc)
	npc.set_meta("outing", spot[1])
	_out.append(npc)
	if already_there:
		npc.position = there
	else:
		await npc.walk_to(Territory.TUNNEL)
		await npc.walk_to(Territory.OUTSIDE)
		await t.walk_route(npc, there)
	npc.set_wander(Rect2(there - Vector2(80, 40), Vector2(160, 80)))
	await get_tree().create_timer(randf_range(STAY[0], STAY[1])).timeout
	# Time to go home
	npc.set_wander(Rect2())
	await t.walk_route(npc, Territory.OUTSIDE)
	await npc.walk_to(Territory.TUNNEL)
	npc.remove_meta("outing")
	_out.erase(npc)
	t.release_npc(npc)
