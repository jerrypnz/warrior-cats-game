class_name TogetherClan
extends RefCounted
## The Clan in ThunderClan Together (the two-player world). It remembers the ceremonies held
## there: kits who became apprentices, new warriors and their mentors, the deputy, and the herbs
## in the medicine den. (Each player's own rank still comes from their save slot.)

const PATH := "user://together_clan.json"

## Every Clan cat's rank when the two-player world starts. Everyone not listed is a warrior.
const RANKS := {
	"Cinderkit": "kit", "Brightkit": "kit", "Brackenkit": "kit", "Thornkit": "kit",
	"Graypaw": "apprentice", "Ravenpaw": "apprentice", "Sandpaw": "apprentice", "Dustpaw": "apprentice",
	"Spottedleaf": "medicine", "Yellowfang": "medicine", "Bluestar": "leader",
	"Smallear": "elder", "One-eye": "elder", "Patchpelt": "elder", "Halftail": "elder",
}
## The apprentices' mentors in the book
const MENTORS := {"Graypaw": "Lionheart", "Ravenpaw": "Tigerclaw", "Sandpaw": "Whitestorm", "Dustpaw": "Darkstripe"}
## The name ending each kit or apprentice gets in the books
const BOOK_ENDINGS := {"Cinderkit": "pelt", "Brightkit": "heart", "Brackenkit": "fur", "Thornkit": "claw",
		"Graypaw": "stripe", "Ravenpaw": "wing", "Sandpaw": "storm", "Dustpaw": "pelt"}
const APPRENTICE_RANKS := ["apprentice", "medicine_apprentice"]
const LESSONS_TO_BE_READY := 3

var cats := {}  # cats who changed since the start: cat -> {"name", "rank", "mentor", "lessons"}
var deputy := ""
var herbs := {}  # herb -> how many are in the medicine den


static func open(someone_grown: bool) -> TogetherClan:
	var clan := TogetherClan.new()
	if FileAccess.file_exists(PATH):
		var data = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if data is Dictionary:
			clan.cats = data.get("cats", {})
			clan.deputy = str(data.get("deputy", ""))
			clan.herbs = data.get("herbs", {})
	if someone_grown and not clan.cats.has("Graypaw"):
		clan.cats["Graypaw"] = {"name": "Graystripe", "rank": "warrior"}  # he got his name with you
	return clan


func save() -> void:
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"cats": cats, "deputy": deputy, "herbs": herbs}))


func rank(cat: String) -> String:
	return cats.get(cat, {}).get("rank", RANKS.get(cat, "warrior"))


func shown_name(cat: String) -> String:
	return cats.get(cat, {}).get("name", cat)


func mentor(cat: String) -> String:
	if cats.has(cat):
		return cats[cat].get("mentor", "")
	return MENTORS.get(cat, "")


func lessons(cat: String) -> int:
	return int(cats.get(cat, {}).get("lessons", 0))


func is_mentoring(who: String) -> bool:
	for cat in RANKS.keys() + cats.keys():
		if rank(cat) in APPRENTICE_RANKS and mentor(cat) == who:
			return true
	return false


## A ceremony gave this cat a new name and rank
func set_cat(cat: String, new_name: String, new_rank: String, new_mentor := "") -> void:
	cats[cat] = {"name": new_name, "rank": new_rank, "mentor": new_mentor, "lessons": 0}
	save()


func add_lesson(cat: String) -> int:
	if not cats.has(cat):
		cats[cat] = {"name": cat, "rank": rank(cat), "mentor": mentor(cat), "lessons": 0}
	cats[cat]["lessons"] = lessons(cat) + 1
	save()
	return lessons(cat)


func herb_count(kind: String) -> int:
	return int(herbs.get(kind, 0))


func add_herbs(kind: String, amount: int) -> void:
	herbs[kind] = maxi(0, herb_count(kind) + amount)
	save()


## "Brightkit" -> "Bright", "Sandpaw" -> "Sand"
static func name_start(cat_name: String) -> String:
	for ending in ["kit", "paw"]:
		if cat_name.ends_with(ending):
			return cat_name.left(-ending.length())
	return cat_name


## How big a cat of this rank is
static func size_for(cat: String, cat_rank: String) -> float:
	if cat_rank == "kit":
		return 0.55
	if cat_rank in APPRENTICE_RANKS:
		return 0.78
	return maxf(1.0, GameState.CATS.get(cat, {}).get("size", 1.0))
