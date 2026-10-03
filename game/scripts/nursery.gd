class_name Nursery
extends Node
## New kits are born in the nursery in ThunderClan Together, so there are always kits for the
## leader to make into apprentices. Every minute or so (while there are fewer than 5 kits) one of
## the queens has a new kit, with its own name and fur. The Clan remembers them.

const QUEENS := ["Frostfur", "Goldenflower"]
const MOST_KITS := 5
const BORN_EVERY := [60.0, 90.0]
const FIRST_KIT := 12.0  # how soon a kit is born when there are none at all
const NAMES := ["Fern", "Pebble", "Sparrow", "Robin", "Daisy", "Mint", "Hazel", "Acorn", "Clover", "Willow",
		"Poppy", "Birch", "Ember", "Misty", "Nettle", "Lark", "Wren", "Briar", "Dapple", "Honey", "Bramble",
		"Sorrel", "Spark", "Cloud", "Rain", "Frost", "Holly", "Berry", "Dew", "Sunny", "Moth", "Rowan"]

var t: Territory
var _timer := -1.0  # (worked out once the camp is built)


func _init(territory: Territory) -> void:
	t = territory


func _process(delta: float) -> void:
	if not t.playing:
		return
	if _timer < 0.0:
		_timer = FIRST_KIT if _kits() == 0 else randf_range(BORN_EVERY[0], BORN_EVERY[1])
	_timer -= delta
	if _timer <= 0.0:
		_timer = randf_range(BORN_EVERY[0], BORN_EVERY[1])
		if _kits() < MOST_KITS:
			_new_kit()


func _kits() -> int:
	return t.npcs.filter(func(npc): return t.clan.rank(npc.get_meta("base", "")) == "kit" \
			and not npc.has_meta("retired")).size()


## A name nobody in the Clan has yet, like "Fernkit"
func _new_name() -> String:
	var taken := {}
	for npc in t.npcs:
		taken[TogetherClan.name_start(npc.npc_name)] = true
	for cat in t.clan.cats:
		taken[TogetherClan.name_start(cat)] = true
		taken[TogetherClan.name_start(t.clan.shown_name(cat))] = true
	for info in t.infos:
		taken[info.prefix] = true
	var free: Array = NAMES.filter(func(n): return not taken.has(n))
	if free.is_empty():
		free = GameState.NAME_PREFIXES.filter(func(n): return not taken.has(n))
	return (free.pick_random() if not free.is_empty() else "Tiny%d" % t.clan.cats.size()) + "kit"


func _new_kit() -> void:
	var queen: String = QUEENS.pick_random()
	var kit_name := _new_name()
	var look := {
		"fur": GameState.FUR_COLORS.pick_random().color.to_html(false),
		"markings": GameState.MARKING_COLORS.pick_random().color.to_html(false),
		"pattern": GameState.PATTERNS.pick_random(),
		"eyes": GameState.EYE_COLORS.pick_random().color.to_html(false),
		"fluffy": randf() < 0.5,
	}
	t.clan.add_kit(kit_name, look, queen)
	var kit := t.make_clan_cat(kit_name)
	kit.position = t.doors["nursery"] + Vector2(0, 40)
	t.world.add_child(kit)
	t.npcs.append(kit)
	t.settle(kit)
	kit.cat.bounce(0.5)
	Sfx.play("powerup")
	Fx.hearts(t.world, kit.position + Vector2(0, -50), 14)
	Fx.confetti(t.world, kit.position + Vector2(0, -70), 30)
	Fx.speech(kit, "Mew! Hello, ThunderClan!", 112 * kit.cat.size + 30, 3.0)
	t.show_banner("%s has a new kit: %s!" % [queen, kit_name])
	t.cheer("Welcome, %s!" % kit_name)
