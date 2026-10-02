extends Node
## Remembers everything about the player's cat and their training progress.

const CLAN := "ThunderClan"
const MENTOR := "Mossfeather"
const LEADER := "Oakstar"

const FUR_COLORS := [
	{"name": "Ginger", "color": Color("e8862a")},
	{"name": "Gray", "color": Color("8a8f98")},
	{"name": "Black", "color": Color("34313a")},
	{"name": "White", "color": Color("f4f1ea")},
	{"name": "Brown", "color": Color("8a5a35")},
	{"name": "Cream", "color": Color("f0d9a8")},
	{"name": "Silver", "color": Color("c9ced6")},
	{"name": "Golden", "color": Color("e6b740")},
	{"name": "Blue-Gray", "color": Color("6f7f99")},
	{"name": "Dark Brown", "color": Color("5a3a24")},
]

const MARKING_COLORS := [
	{"name": "Dark Brown", "color": Color("4a2c18")},
	{"name": "Black", "color": Color("26232b")},
	{"name": "White", "color": Color("fbf9f4")},
	{"name": "Dark Ginger", "color": Color("b8561a")},
	{"name": "Gray", "color": Color("5d626b")},
	{"name": "Cream", "color": Color("f3e2bd")},
	{"name": "Golden", "color": Color("d99a1e")},
]

const PATTERNS := ["Solid", "Tabby Stripes", "Spots", "Patches", "Socks"]

const EYE_COLORS := [
	{"name": "Green", "color": Color("5fd14a")},
	{"name": "Amber", "color": Color("f2a531")},
	{"name": "Blue", "color": Color("4fb3f0")},
	{"name": "Yellow", "color": Color("f5e04a")},
	{"name": "Copper", "color": Color("c8692b")},
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

const TRAININGS := ["hunting", "patrol", "battle"]
const TRAINING_NAMES := {"hunting": "Hunting", "patrol": "Border Patrol", "battle": "Battle Practice"}
const TRAINING_SCENES := {
	"hunting": "res://scenes/hunting.tscn",
	"patrol": "res://scenes/patrol.tscn",
	"battle": "res://scenes/battle.tscn",
}

var fur_index := 0
var marking_index := 0
var pattern_index := 1
var eye_index := 0
var prefix_index := 0
var personality_index := 0

var is_warrior := false
var met_clan := false  # the apprentice ceremony in camp has happened
var trainings_done := {"hunting": false, "patrol": false, "battle": false}
var just_finished := ""  # training finished right before coming back to camp


func look() -> Dictionary:
	return {
		"fur": FUR_COLORS[fur_index].color,
		"markings": MARKING_COLORS[marking_index].color,
		"pattern": PATTERNS[pattern_index],
		"eyes": EYE_COLORS[eye_index].color,
	}


func personality() -> Dictionary:
	return PERSONALITIES[personality_index]


func prefix() -> String:
	return NAME_PREFIXES[prefix_index]


func apprentice_name() -> String:
	return prefix() + "paw"


func warrior_name() -> String:
	return prefix() + personality().suffix


func cat_name() -> String:
	return warrior_name() if is_warrior else apprentice_name()


func cat_size() -> float:
	return 1.05 if is_warrior else 0.85


func next_training() -> String:
	for t in TRAININGS:
		if not trainings_done[t]:
			return t
	return ""


func finish_training(t: String) -> void:
	trainings_done[t] = true
	just_finished = t


func randomize_cat() -> void:
	fur_index = randi() % FUR_COLORS.size()
	marking_index = randi() % MARKING_COLORS.size()
	pattern_index = randi() % PATTERNS.size()
	eye_index = randi() % EYE_COLORS.size()
	prefix_index = randi() % NAME_PREFIXES.size()
	personality_index = randi() % PERSONALITIES.size()
