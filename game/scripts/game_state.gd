extends Node
## Remembers everything about the player's cat and how far they are in the story.

const CLAN := "ThunderClan"
const KITTYPET_NAME := "Biscuit"

const FUR_COLORS := [
	{"name": "Ginger", "color": Color("f29a45")},
	{"name": "Gray", "color": Color("9aa0aa")},
	{"name": "Black", "color": Color("45404d")},
	{"name": "White", "color": Color("fbf8f2")},
	{"name": "Brown", "color": Color("a06a42")},
	{"name": "Cream", "color": Color("f6e2b8")},
	{"name": "Silver", "color": Color("d3d8e0")},
	{"name": "Golden", "color": Color("f0c35a")},
	{"name": "Blue-Gray", "color": Color("8396b3")},
	{"name": "Dark Brown", "color": Color("6e4a32")},
]

const MARKING_COLORS := [
	{"name": "Dark Brown", "color": Color("5a3622")},
	{"name": "Black", "color": Color("35303a")},
	{"name": "White", "color": Color("fffdf8")},
	{"name": "Dark Ginger", "color": Color("c8642a")},
	{"name": "Gray", "color": Color("6c717b")},
	{"name": "Cream", "color": Color("f7e8c8")},
	{"name": "Golden", "color": Color("e0a530")},
]

const PATTERNS := ["Solid", "Tabby Stripes", "Spots", "Patches", "Socks", "Chest", "Back Stripe"]

const EYE_COLORS := [
	{"name": "Green", "color": Color("5fd14a")},
	{"name": "Amber", "color": Color("f2a531")},
	{"name": "Blue", "color": Color("4fb3f0")},
	{"name": "Yellow", "color": Color("f5d63a")},
	{"name": "Copper", "color": Color("d9732f")},
	{"name": "Purple", "color": Color("a77ae8")},
]

const NAME_PREFIXES := [
	"Fire", "Bramble", "Sand", "Leaf", "Moss", "Storm", "Frost", "Sun", "Ash", "Cloud",
	"Willow", "Fern", "Rain", "Holly", "Lion", "Ivy", "Hazel", "Pebble", "Tiger", "Feather",
	"Bright", "Rose", "Snow", "Thistle", "Blue", "Squirrel", "Sky", "Raven", "Berry", "Flame",
	"Silver", "Shadow", "Dawn", "Spark", "Acorn", "Poppy", "Wind", "Honey", "Echo", "Swift",
]

const PERSONALITIES := [
	{"name": "Brave", "about": "Never scared of anything!", "suffix": "heart", "virtue": "bravery"},
	{"name": "Kind", "about": "Always helps their Clanmates.", "suffix": "petal", "virtue": "kindness"},
	{"name": "Clever", "about": "Thinks before they pounce.", "suffix": "whisker", "virtue": "cleverness"},
	{"name": "Speedy", "about": "Fast as the wind!", "suffix": "leap", "virtue": "speed"},
	{"name": "Strong", "about": "Tough as an old oak tree.", "suffix": "claw", "virtue": "strength"},
	{"name": "Playful", "about": "Loves games and fun!", "suffix": "tail", "virtue": "joyful spirit"},
	{"name": "Calm", "about": "Quiet and wise.", "suffix": "mist", "virtue": "calm wisdom"},
	{"name": "Loyal", "about": "Would do anything for the Clan.", "suffix": "song", "virtue": "loyalty"},
]

## The cats from the story, and what they look like
const CATS := {
	"Bluestar": {"fur": Color("8396b3"), "markings": Color("dfe6f0"), "pattern": "Chest", "eyes": Color("4fb3f0"), "size": 1.1},
	"Tigerclaw": {"fur": Color("6e4a32"), "markings": Color("2e2224"), "pattern": "Tabby Stripes", "eyes": Color("f2a531"), "size": 1.3, "mood": "grumpy"},
	"Lionheart": {"fur": Color("f0c35a"), "markings": Color("c88a2a"), "pattern": "Tabby Stripes", "eyes": Color("5fd14a"), "size": 1.2, "fluffy": true},
	"Graypaw": {"fur": Color("7c808b"), "markings": Color("4a4d57"), "pattern": "Back Stripe", "eyes": Color("f5d63a"), "size": 0.85, "fluffy": true},
	"Ravenpaw": {"fur": Color("3f3a46"), "markings": Color("fffdf8"), "pattern": "Chest", "eyes": Color("f2a531"), "size": 0.8},
	"Spottedleaf": {"fur": Color("d98a45"), "markings": Color("5a3622"), "pattern": "Patches", "eyes": Color("f2a531"), "size": 0.95},
	"Longtail": {"fur": Color("f6e2b8"), "markings": Color("35303a"), "pattern": "Tabby Stripes", "eyes": Color("f5d63a"), "size": 1.05, "mood": "grumpy"},
	"Frostfur": {"fur": Color("fbf8f2"), "markings": Color("dfe6f0"), "pattern": "Solid", "eyes": Color("4fb3f0"), "size": 1.0},
	"Cinderkit": {"fur": Color("6c717b"), "markings": Color("45404d"), "pattern": "Solid", "eyes": Color("4fb3f0"), "size": 0.55, "fluffy": true},
	"Brightkit": {"fur": Color("fbf8f2"), "markings": Color("f29a45"), "pattern": "Patches", "eyes": Color("4fb3f0"), "size": 0.55},
	"Smallear": {"fur": Color("9aa0aa"), "markings": Color("6c717b"), "pattern": "Solid", "eyes": Color("f2a531"), "size": 0.95},
	"Sandpaw": {"fur": Color("f3c98e"), "markings": Color("e0a530"), "pattern": "Solid", "eyes": Color("5fd14a"), "size": 0.85},
	"Dustpaw": {"fur": Color("a06a42"), "markings": Color("5a3622"), "pattern": "Tabby Stripes", "eyes": Color("f2a531"), "size": 0.85, "mood": "grumpy"},
	"Yellowfang": {"fur": Color("5e5862"), "markings": Color("45404d"), "pattern": "Solid", "eyes": Color("f08a24"), "size": 1.05, "fluffy": true, "mood": "grumpy"},
	"Smudge": {"fur": Color("35303a"), "markings": Color("fffdf8"), "pattern": "Socks", "eyes": Color("5fd14a"), "size": 1.1},
	"RiverClan warrior": {"fur": Color("b8c4d6"), "markings": Color("6c7a90"), "pattern": "Tabby Stripes", "eyes": Color("4fb3f0"), "size": 1.1, "mood": "grumpy"},
	"ShadowClan warrior": {"fur": Color("4a4552"), "markings": Color("2e2a33"), "pattern": "Tabby Stripes", "eyes": Color("f5d63a"), "size": 1.1, "mood": "grumpy"},
}

## The story, in order. Steps with "from_camp" start by talking to that cat in camp.
const STORY := [
	{"id": "kittypet", "scene": "res://scenes/garden.tscn", "title": "Chapter 1: Kittypet"},
	{"id": "first_mouse", "scene": "res://scenes/hunting.tscn", "title": "Chapter 2: Into the Forest"},
	{"id": "graypaw", "scene": "res://scenes/duel.tscn", "title": "Chapter 3: A Surprise Attack!"},
	{"id": "hunt_lesson", "scene": "res://scenes/hunting.tscn", "title": "Chapter 4: Hunting Lesson", "from_camp": "Bluestar"},
	{"id": "battle_lesson", "scene": "res://scenes/duel.tscn", "title": "Chapter 5: Battle Practice", "from_camp": "Bluestar"},
	{"id": "patrol", "scene": "res://scenes/patrol.tscn", "title": "Chapter 6: Border Patrol", "from_camp": "Lionheart"},
	{"id": "yellowfang", "scene": "res://scenes/hunting.tscn", "title": "Chapter 7: The Grumpy Stranger", "from_camp": "Bluestar"},
	{"id": "rescue", "scene": "res://scenes/rescue.tscn", "title": "Chapter 8: Rescue the Kits!", "from_camp": "Bluestar"},
	{"id": "ceremony", "scene": "res://scenes/ceremony.tscn", "title": "Chapter 9: Warrior Ceremony", "from_camp": "Bluestar"},
]

var fur_index := 0
var marking_index := 0
var pattern_index := 1
var eye_index := 0
var fluffy := false
var prefix_index := 0
var personality_index := 0

var step := 0  # which part of the story we're on
var met_clan := false  # the apprentice ceremony in camp has happened
var just_finished := ""  # story step finished right before coming back to camp


func look() -> Dictionary:
	return {
		"fur": FUR_COLORS[fur_index].color,
		"markings": MARKING_COLORS[marking_index].color,
		"pattern": PATTERNS[pattern_index],
		"eyes": EYE_COLORS[eye_index].color,
		"fluffy": fluffy,
	}


func personality() -> Dictionary:
	return PERSONALITIES[personality_index]


func prefix() -> String:
	return NAME_PREFIXES[prefix_index]


func apprentice_name() -> String:
	return prefix() + "paw"


func warrior_name() -> String:
	return prefix() + personality().suffix


func is_warrior() -> bool:
	return step >= STORY.size()


func is_kittypet() -> bool:
	return not met_clan and step <= 2


func cat_name() -> String:
	if is_warrior():
		return warrior_name()
	return KITTYPET_NAME if is_kittypet() else apprentice_name()


func cat_size() -> float:
	return 1.15 if is_warrior() else 0.9


func current() -> Dictionary:
	return STORY[step] if step < STORY.size() else {}


func current_id() -> String:
	return current().get("id", "")


## Finish this part of the story and go to wherever the story goes next.
func complete_step() -> void:
	just_finished = current_id()
	step += 1
	var next := current()
	if next.is_empty() or next.has("from_camp"):
		Transition.go("res://scenes/camp.tscn")
	else:
		Transition.go(next.scene)


func start_step() -> void:
	Transition.go(current().scene)


func randomize_cat() -> void:
	fur_index = randi() % FUR_COLORS.size()
	marking_index = randi() % MARKING_COLORS.size()
	pattern_index = randi() % PATTERNS.size()
	eye_index = randi() % EYE_COLORS.size()
	fluffy = randf() < 0.5
	prefix_index = randi() % NAME_PREFIXES.size()
	personality_index = randi() % PERSONALITIES.size()
