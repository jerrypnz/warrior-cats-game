class_name MedicineWork
extends Node
## The medicine cat's work in ThunderClan Together.
##   Now and then a Clan cat feels sick and goes to lie down in the Medicine Den. A little cloud
##   above them shows the herb they need. Talk to them to give it from the herb store
##   (the shelf on your side of the screen shows how many of each herb you have).
##   Running low? Ask a Clan cat to fetch a herb while you keep working, or ask the other player:
##   they get an errand ("Find 3 Catmint for Cinderpelt"), can pick that herb, and bring it to the
##   Medicine Den (or straight to you).

const SICK_NESTS := [Vector2(930, 520), Vector2(1050, 410)]  # in the Medicine Den room
const ERRAND_SIZE := 3  # herbs the other player is asked to find
const HELPER_FINDS := 2  # herbs a Clan cat brings back
const FIRST_SICK := 30.0  # seconds before the first cat gets sick

var t: Territory
var healed := 0
var errands := [{}, {}]  # each player's errand: {"herb", "need", "found", "for"} or empty
var _patients := []  # {"npc": the cat in the den, "cat": the camp cat who got sick, "herb", "nest"}
var _sick_timer := FIRST_SICK
var _shelves: Array[HerbShelf] = []
var _errand_labels: Array[Label] = []


func _init(territory: Territory) -> void:
	t = territory


## True if one of the players is a medicine cat (then cats get sick and herbs grow)
func active() -> bool:
	return t.infos.any(func(c): return c.medicine)


func make_hud(hud: CanvasLayer) -> void:
	for i in 2:
		var label := Fx.make_label("", 22, Color("c9f7a8"), 6)
		label.position = Vector2(16 + i * 660, 76)
		label.size = Vector2(600, 30)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if i == 0 else HORIZONTAL_ALIGNMENT_RIGHT
		hud.add_child(label)
		_errand_labels.append(label)
		if t.infos[i].medicine:
			var shelf := HerbShelf.new()
			shelf.clan = t.clan
			shelf.size = Vector2(320, 88)
			shelf.position = Vector2(16 if i == 0 else 1280 - 16 - 320, 592)
			hud.add_child(shelf)
			_shelves.append(shelf)


func _process(delta: float) -> void:
	if not t.playing or not active():
		return
	_sick_timer -= delta
	if _sick_timer <= 0.0:
		_sick_timer = randf_range(35.0, 50.0)
		if _patients.size() < SICK_NESTS.size():
			_get_sick()


## A Clan cat in camp feels sick and goes to lie down in the Medicine Den
func _get_sick() -> void:
	var cats := t.camp_cats(["warrior", "apprentice", "elder"])
	if cats.is_empty():
		return
	var cat: Npc = cats.pick_random()
	var herb: String = HerbArt.GROWING.pick_random()
	var nest := 0 if not _patients.any(func(p): return p.nest == 0) else 1
	t.hold_npc(cat)
	var patient := {"npc": null, "cat": cat, "herb": herb, "nest": nest}
	_patients.append(patient)
	Fx.speech(cat, "Achoo! I don't feel very well...", 112 * cat.cat.size + 30, 3.0)
	t.show_banner("%s is sick! Medicine cat, please help!" % cat.npc_name)
	await get_tree().create_timer(2.0).timeout
	await cat.walk_to(t.doors["medicine"])
	cat.visible = false
	# Now they're lying in a sick cats' nest in the Medicine Den
	var sick := Npc.make(cat.get_meta("base"), -1.0)
	sick.rename(cat.npc_name)
	sick.resize(cat.cat.size)
	sick.position = SICK_NESTS[nest]
	sick.set_meta("base", cat.get_meta("base"))
	sick.set_meta("patient", true)
	var bubble := HerbBubble.new()
	bubble.kind = herb
	bubble.position = Vector2(0, -112 * cat.cat.size - 90)
	sick.add_child(bubble)
	t.rooms["medicine"].add_child(sick)
	t.npcs.append(sick)
	patient.npc = sick


## Someone talks to a sick cat. Medicine cats give them the herb they need (if there's any).
func use_patient(i: int, npc: Npc) -> void:
	var patient: Dictionary = {}
	for p in _patients:
		if p.npc == npc:
			patient = p
	if patient.is_empty():
		return
	var herb: String = patient.herb
	var problem: String = HerbArt.HERBS[herb].problem
	if not t.infos[i].medicine:
		Fx.speech(npc, "%s I need some %s." % [problem, herb], 112 * npc.cat.size + 30, 3.5)
		return
	if t.clan.herb_count(herb) <= 0:
		Fx.speech(npc, problem, 112 * npc.cat.size + 30, 3.0)
		await get_tree().create_timer(1.5).timeout
		t.say(i, "Oh no, we're out of %s! I'll ask someone to fetch some." % herb, 3.5)
		return
	t.clan.add_herbs(herb, -1)
	healed += 1
	_patients.erase(patient)
	t.npcs.erase(npc)
	refresh()
	t.update_quests()
	Sfx.play("powerup")
	Fx.burst(t.world, npc.position + Vector2(0, -50), Color("c9f7a8"), 20)
	Fx.hearts(t.world, npc.position + Vector2(0, -70), 12)
	t.players[i].cat.bounce(0.3)
	Fx.speech(npc, "%s! Thank you, %s! I feel all better!" % [herb, t.infos[i].name], 112 * npc.cat.size + 30, 2.5)
	await get_tree().create_timer(2.5).timeout
	npc.queue_free()
	var cat: Npc = patient.cat
	cat.position = t.doors["medicine"] + Vector2(0, 40)
	cat.visible = true
	Fx.speech(cat, "I feel great now!", 112 * cat.cat.size + 30, 2.0)
	t.release_npc(cat)


## Clan cats a medicine cat can ask for help (not kits, elders, or cats doing something else)
func can_ask(npc: Npc) -> bool:
	return npc.get_parent() == t.world and not npc.has_meta("busy") and not npc.has_meta("retired") \
			and t.clan.rank(npc.get_meta("base", "")) in ["warrior", "apprentice", "medicine_apprentice", "medicine"]


## A medicine cat talks to a Clan cat
func talk_menu(i: int, npc: Npc) -> void:
	var pick: int = await t.ask(i, "%s: Hi, %s! Do you need anything?" % [npc.npc_name, t.infos[i].name],
			["Please fetch herbs!", "Just say hi", "Never mind"])
	if pick == 0:
		await fetch_menu(i, npc)
	elif pick == 1:
		t.chat(i, npc)


## Pick a herb, and a Clan cat goes out to find it while you keep working
func fetch_menu(i: int, npc: Npc) -> void:
	var pick: int = await t.ask(i, "Which herb should %s find?" % npc.npc_name, _herb_answers())
	if pick < 0 or pick >= HerbArt.GROWING.size():
		return
	var herb: String = HerbArt.GROWING[pick]
	Fx.speech(npc, "I'll find some %s for you, %s!" % [herb, t.infos[i].name], 112 * npc.cat.size + 30, 2.5)
	t.say(i, "Thank you! I'll look after the sick cats.", 2.5)
	await get_tree().create_timer(1.0).timeout
	await t.send_away(npc, randf_range(15.0, 20.0))
	await npc.walk_to(t.doors["medicine"] + Vector2(0, 40))
	t.clan.add_herbs(herb, HELPER_FINDS)
	refresh()
	Sfx.play("collect")
	Fx.hearts(t.world, npc.position + Vector2(0, -70), 8)
	Fx.speech(npc, "I found %d %s!" % [HELPER_FINDS, herb], 112 * npc.cat.size + 30, 2.5)
	t.show_banner("%s brought %d %s to the Medicine Den!" % [npc.npc_name, HELPER_FINDS, herb])
	await get_tree().create_timer(1.0).timeout
	t.release_npc(npc)


func _herb_answers() -> Array:
	var answers: Array = HerbArt.GROWING.map(func(h): return "%s (you have %d)" % [h, t.clan.herb_count(h)])
	answers.append("Never mind")
	return answers


# --- errands for the other player --------------------------------------------------------------

## The medicine cat (i) asks the other player to find some herbs
func ask_friend(i: int) -> void:
	var j := 1 - i
	var pick: int = await t.ask(i, "Which herb should %s find?" % t.infos[j].name, _herb_answers())
	if pick < 0 or pick >= HerbArt.GROWING.size():
		return
	var herb: String = HerbArt.GROWING[pick]
	if not t.available(j):
		t.say(i, "%s is busy right now. Try again soon!" % t.infos[j].name)
		return
	t.say(i, "Could you find %d %s for me, please?" % [ERRAND_SIZE, herb], 3.0)
	var yes: int = await t.ask(j, "%s asks: Can you find %d %s for the Medicine Den?" % [t.infos[i].name, ERRAND_SIZE, herb],
			["Yes, I'll help!", "Not right now"])
	if yes != 0:
		t.say(j, "Sorry, not right now!", 2.5)
		return
	errands[j] = {"herb": herb, "need": ERRAND_SIZE, "found": 0, "for": i}
	t.say(j, "I'll find %d %s! I'll look for its name in the forest." % [ERRAND_SIZE, herb], 3.0)
	await get_tree().create_timer(1.0).timeout
	t.say(i, "Thank you! I'll look after the sick cats while you're gone.", 3.0)
	for k in maxi(0, ERRAND_SIZE + 1 - t.herbs_growing(herb)):
		t.spawn_herb(herb)
	t.update_herb_tags()
	_update_errand(j)


## Medicine cats can pick any herb. Other cats can only pick the herb they were asked to find.
func can_pick(i: int, kind: String) -> bool:
	return t.infos[i].medicine or errands[i].get("herb", "") == kind


## Is anyone looking for this herb? (Then its name shows above it in the forest.)
func is_wanted(kind: String) -> bool:
	return errands.any(func(e): return e.get("herb", "") == kind)


func picked(i: int, kind: String) -> void:
	if errands[i].get("herb", "") == kind:
		errands[i].found += 1
		_update_errand(i)
		if errands[i].found == errands[i].need:
			t.say(i, "That's enough %s! Now to the Medicine Den!" % kind, 3.0)


## Herbs you're carrying go into the medicine den's store (when you walk into the Medicine Den,
## or hand them to the medicine cat)
func put_away(i: int) -> void:
	var held: Dictionary = t.carrying_herbs[i]
	if held.is_empty():
		return
	var count := 0
	for kind in held:
		t.clan.add_herbs(kind, held[kind])
		count += held[kind]
	t.carrying_herbs[i] = {}
	t.update_carrying(i)
	refresh()
	Sfx.play("win")
	Fx.hearts(t.world, t.players[i].position + Vector2(0, -80), 12)
	var errand: Dictionary = errands[i]
	if not errand.is_empty() and errand.found >= errand.need:
		var medic: int = errand["for"]
		errands[i] = {}
		_update_errand(i)
		t.update_herb_tags()
		t.show_banner("%s brought %d %s for %s!" % [t.infos[i].name, errand.found, errand.herb, t.infos[medic].name])
		Fx.confetti(t.world, t.players[i].position + Vector2(0, -100), 40)
		Fx.hearts(t.world, t.players[medic].position + Vector2(0, -80), 12)
		t.say(medic, "Thank you SO much, %s! You're a great helper!" % t.infos[i].name, 3.0)
	else:
		t.say(i, "%d %s in the medicine den. It smells lovely!" % [count, "herb" if count == 1 else "herbs"], 2.5)


## True if player i has herbs to give the medicine cat (j)
func can_give(i: int, j: int) -> bool:
	return t.infos[j].medicine and not t.infos[i].medicine and not t.carrying_herbs[i].is_empty()


func _update_errand(i: int) -> void:
	var errand: Dictionary = errands[i]
	var label := _errand_labels[i]
	if errand.is_empty():
		label.text = ""
	elif errand.found < errand.need:
		label.text = "Find %s for %s: %d / %d" % [errand.herb, t.infos[errand["for"]].name, errand.found, errand.need]
	else:
		label.text = "Take the %s to %s or the Medicine Den!" % [errand.herb, t.infos[errand["for"]].name]


func refresh() -> void:
	for shelf in _shelves:
		shelf.queue_redraw()


class HerbShelf extends Control:
	## The medicine den's herb store: how many of each herb you have
	var clan: TogetherClan

	func _draw() -> void:
		draw_style_box(Fx.cute_panel(16), Rect2(Vector2.ZERO, size))
		var font := ThemeDB.fallback_font
		for k in HerbArt.GROWING.size():
			var kind: String = HerbArt.GROWING[k]
			var x := 36.0 + k * 62.0
			HerbArt.draw(self, Vector2(x, 44), kind, 0.8)
			var count := clan.herb_count(kind)
			draw_string(font, Vector2(x - 30, 76), str(count), HORIZONTAL_ALIGNMENT_CENTER, 60, 24,
					Fx.INK if count > 0 else Color("d06a6a"))


class HerbBubble extends Node2D:
	## A little thought cloud over a sick cat, showing the herb they need
	var kind := ""
	var _time := randf() * 3.0

	func _process(delta: float) -> void:
		_time += delta
		queue_redraw()

	func _draw() -> void:
		var bob := sin(_time * 2.5) * 4.0
		draw_circle(Vector2(-14, 38 + bob * 0.5), 6, Fx.OUTLINE)
		draw_circle(Vector2(-14, 38 + bob * 0.5), 4.5, Color.WHITE)
		draw_colored_polygon(Fx.ellipse_points(Vector2(0, bob), Vector2(38, 30)), Fx.OUTLINE)
		draw_colored_polygon(Fx.ellipse_points(Vector2(0, bob), Vector2(35, 27)), Color.WHITE)
		HerbArt.draw(self, Vector2(0, 20 + bob), kind, 0.8)
