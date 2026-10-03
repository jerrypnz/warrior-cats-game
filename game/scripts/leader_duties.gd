class_name LeaderDuties
extends Node
## Leader and deputy jobs in ThunderClan Together, just like in the books.
##   The leader holds Clan meetings on the Highrock: make a kit into an apprentice and choose
##   their mentor, give an apprentice their warrior name, choose a deputy, or send out patrols.
##   The deputy can send out patrols too.
## (Mentors taking their apprentices out training is in mentor_training.gd.)
## The other player can be part of it: a mentor, a new warrior, or the deputy (they say yes first).

const ROCK_TOP := Vector2(630, 184)  # where the leader stands on the Highrock (in camp.gd's camp)
const STEP_FORWARD := Vector2(700, 430)  # where a cat stands below the Highrock in a ceremony
const BORDER_NEWS := ["All is quiet at the border.", "We saw a RiverClan cat catching a fish!",
		"We found a lost kittypet and showed it the way home!", "We saw WindClan cats racing across the moor!",
		"The scent markers are fresh and strong!"]

var t: Territory
var _patrol_out := false


func _init(territory: Territory) -> void:
	t = territory


func _me(i: int) -> String:
	return t.infos[i].name


# --- Clan meetings -----------------------------------------------------------------------------

## The leader stands at the Highrock and picks what to do
func clan_meeting(i: int) -> void:
	var jobs := []  # [what the menu says, what to do]
	if not _kits().is_empty():
		jobs.append(["Make a kit an apprentice", "apprentice"])
	if not _apprentices(i).is_empty():
		jobs.append(["Give a warrior name", "warrior"])
	jobs.append(["Choose a deputy", "deputy"])
	jobs.append(["Send out a patrol", "patrol"])
	jobs.append(["Cheer for ThunderClan!", "cheer"])
	jobs.append(["Never mind", ""])
	var pick: int = await t.ask(i, "Clan meeting! What will you do, %s?" % _me(i), jobs.map(func(j): return j[0]))
	if pick < 0:
		return
	match jobs[pick][1]:
		"apprentice":
			await _make_apprentice(i)
		"warrior":
			await _make_warrior(i)
		"deputy":
			await _choose_deputy(i)
		"patrol":
			await send_patrol(i)
		"cheer":
			await _ceremony(i, null, [["leader", "ThunderClan, you are the bravest, kindest Clan in the whole forest!"]],
					func(): pass, "Hooray for ThunderClan!", "ThunderClan")


## Kits who can become apprentices
func _kits() -> Array:
	return t.npcs.filter(func(npc: Npc): return _free(npc) and t.clan.rank(npc.get_meta("base", "")) == "kit")


## Apprentices who can get their warrior (or medicine cat) name: Clan cats, and the other player
## if they're a warrior apprentice. Each is {"name", "npc", "player", "medicine", "ready"}.
func _apprentices(i: int) -> Array:
	var found := []
	var j := 1 - i
	var other: Dictionary = t.infos[j]
	if not other.grown and not other.medicine and not other.kittypet:
		found.append({"name": other.name, "npc": null, "player": j, "medicine": false, "ready": true})
	for npc in t.npcs:
		var cat_name: String = npc.get_meta("base", "")
		var rank := t.clan.rank(cat_name)
		if _free(npc, true) and rank in TogetherClan.APPRENTICE_RANKS:
			found.append({"name": npc.npc_name, "npc": npc, "player": -1, "medicine": rank == "medicine_apprentice",
					"ready": t.clan.lessons(cat_name) >= TogetherClan.LESSONS_TO_BE_READY})
	return found


## A Clan cat who can step forward in a ceremony (awake or asleep, but not off doing a job)
func _free(npc: Npc, followers_ok := false) -> bool:
	return npc.visible and not npc.has_meta("busy") and not npc.has_meta("patient") \
			and not npc.has_meta("retired") and not (npc.get_parent() is CampProp) \
			and (followers_ok or npc.follow_target == null)


## The leader climbs the Highrock, calls the Clan together, says the ceremony's words, and
## everyone cheers. lines are [who, words]: who is "leader" or "cat" (the cat stepping forward).
## named() is called when the cat gets their new name or job.
func _ceremony(i: int, cat: Npc, lines: Array, named: Callable, banner: String, cheer_for: String,
		player_cat := -1) -> void:
	var leader := t.players[i]
	t.busy[i] = true
	leader.frozen = true
	var back := leader.position
	leader.z_index = 5
	var up := create_tween()
	up.tween_property(leader, "position", ROCK_TOP + Territory.OFFSET + Vector2(-60 + i * 120, 0), 0.5) \
			.set_trans(Tween.TRANS_BACK)
	await up.finished
	Sfx.play("jump")
	await _speak(leader, "Let all cats old enough to catch their own prey gather beneath the Highrock!")
	if cat:
		t.bring_to_camp(cat)
		t.hold_npc(cat)
		await cat.walk_to(STEP_FORWARD + Territory.OFFSET)
		cat.face_toward(leader.position)
	var speaker: Node2D = cat if cat else (t.players[player_cat] if player_cat >= 0 else leader)
	for line in lines:
		await _speak(leader if line[0] == "leader" else speaker, line[1])
	named.call()
	Sfx.play("win")
	Fx.confetti(t.world, speaker.position + Vector2(0, -100), 60)
	t.show_banner(banner)
	for k in 2:
		t.cheer(cheer_for + "!")
		await get_tree().create_timer(0.8).timeout
	if cat:
		t.release_npc(cat, false)
		t.settle(cat)
	var down := create_tween()
	down.tween_property(leader, "position", back, 0.5)
	await down.finished
	leader.z_index = 0
	leader.frozen = false
	t.busy[i] = false


## A speech bubble that stays long enough to read, then the next one
func _speak(who, text: String) -> void:
	var seconds := 1.2 + text.length() * 0.042
	var height: float = 112 * who.cat.size + 30
	Fx.speech(who, text, height, seconds)
	await get_tree().create_timer(seconds + 0.2).timeout


# --- making apprentices ------------------------------------------------------------------------

func _make_apprentice(i: int) -> void:
	var kits := _kits()
	var pick: int = await t.ask(i, "Which kit is ready to be an apprentice?", kits.map(func(k): return k.npc_name) + ["Never mind"])
	if pick < 0 or pick >= kits.size():
		return
	var kit: Npc = kits[pick]
	var paw_name := TogetherClan.name_start(kit.npc_name) + "paw"
	var mentors := _mentor_choices(i)  # [what the menu says, mentor's name, medicine cat?]
	pick = await t.ask(i, "Who will be %s's mentor?" % paw_name, mentors.map(func(m): return m[0]) + ["Never mind"])
	if pick < 0 or pick >= mentors.size():
		return
	var mentor: String = mentors[pick][1]
	var medicine: bool = mentors[pick][2]
	var lines := [
		["leader", "%s, you are six moons old. Time to become an apprentice!" % kit.npc_name],
		["leader", "From now on, you will be known as %s!" % paw_name],
	]
	if mentor == _me(i):
		lines.append(["leader", "And I will be your mentor myself!"])
	elif medicine:
		lines.append(["leader", "%s will teach you to be a medicine cat!" % mentor])
	else:
		lines.append(["leader", "%s will be your mentor. Teach them well, %s!" % [mentor, mentor]])
	lines.append(["cat", "Yippee! I'm an apprentice!"])
	var cat_name: String = kit.get_meta("base")
	var named := func():
		t.clan.set_cat(cat_name, paw_name, "medicine_apprentice" if medicine else "apprentice", mentor)
		kit.rename(paw_name)
		kit.resize(TogetherClan.size_for(cat_name, "apprentice"))
	await _ceremony(i, kit, lines, named, "%s is an apprentice! Mentor: %s" % [paw_name, mentor], paw_name)
	if mentor == _me(1 - i) or mentor == _me(i):
		var j := 0 if mentor == _me(0) else 1
		t.say(j, "%s is my apprentice! Talk to them to train together." % paw_name, 3.5)


## Who can be a mentor: the leader, the other player (if they're grown up), and Clan warriors
## who don't have an apprentice yet. Each is [what the menu says, name, medicine cat?].
func _mentor_choices(i: int) -> Array:
	var choices := [["Me! (%s)" % _me(i), _me(i), false]]
	var other: Dictionary = t.infos[1 - i]
	if other.grown and other.medicine:
		choices.append(["%s (medicine cat)" % other.name, other.name, true])
	elif other.grown:
		choices.append([other.name, other.name, false])
	var warriors := t.camp_cats(["warrior"]).filter(
			func(npc): return npc.npc_name != t.deputy_name() and not t.clan.is_mentoring(npc.npc_name))
	for npc in warriors.slice(0, 3):
		choices.append([npc.npc_name, npc.npc_name, false])
	return choices


# --- warrior names -----------------------------------------------------------------------------

func _make_warrior(i: int) -> void:
	var paws := _apprentices(i)
	var labels := paws.map(func(p): return p.name + (" (ready!)" if p.ready and p.npc else ""))
	var pick: int = await t.ask(i, "Who is ready for their warrior name?", labels + ["Never mind"])
	if pick < 0 or pick >= paws.size():
		return
	var paw: Dictionary = paws[pick]
	var j: int = paw.player
	if j >= 0:
		if not t.available(j):
			t.say(i, "%s is busy right now. Try again soon!" % paw.name)
			return
		var yes: int = await t.ask(j, "%s wants to give you your warrior name! (You'll skip the rest of your apprentice adventures.) Are you ready?" % _me(i),
				["I'm ready!", "Not yet"])
		if yes != 0:
			t.say(j, "Not yet! I want to keep training.")
			return
	var start := TogetherClan.name_start(paw.name)
	var endings := _name_endings(paw)
	var kind := "medicine cat" if paw.medicine else "warrior"
	pick = await t.ask(i, "What will %s's %s name be?" % [paw.name, kind], endings.map(func(e): return start + e))
	var ending: String = endings[maxi(pick, 0)]
	var new_name := start + ending
	var lines := []
	if paw.medicine:
		lines = [["leader", "%s has learned all about herbs, and StarClan shares dreams with them." % paw.name],
				["leader", "From this moment, you will be known as %s, a medicine cat of ThunderClan!" % new_name]]
	else:
		lines = [["leader", "%s, do you promise to protect and help your Clan, always?" % paw.name],
				["cat", "I do!"],
				["leader", "Then from this moment you will be known as %s. StarClan is proud of you!" % new_name]]
	var npc: Npc = paw.npc
	var named := func():
		if j >= 0:
			GameState.edit_slot(GameState.together[j], {"step": GameState.STORY.size(), "met_clan": true,
					"name_ending": ending})
			t.refresh_player(j)
		else:
			var cat_name: String = npc.get_meta("base")
			var rank := "medicine" if paw.medicine else "warrior"
			t.clan.set_cat(cat_name, new_name, rank)
			npc.rename(new_name)
			npc.resize(TogetherClan.size_for(cat_name, rank))
	await _ceremony(i, npc, lines, named, "%s is now %s!" % [paw.name, new_name], new_name, j)


## Name endings to pick from: the one from the books (or the player's own), and 3 others
func _name_endings(paw: Dictionary) -> Array:
	var endings := []
	if paw.player >= 0:
		endings.append(t.infos[paw.player].suffix)
	elif paw.npc:
		endings.append(TogetherClan.BOOK_ENDINGS.get(paw.npc.get_meta("base"), "heart"))
	var others: Array = GameState.NAME_ENDINGS.duplicate()
	others.shuffle()
	for e in others:
		if endings.size() >= 4:
			break
		if not e in endings:
			endings.append(e)
	return endings


# --- the deputy --------------------------------------------------------------------------------

func _choose_deputy(i: int) -> void:
	for j in 2:
		if t.infos[j].rank == "deputy":
			t.say(i, "%s is already my deputy! A deputy is a deputy for life." % t.infos[j].name, 3.5)
			return
	var deputy := t.deputy_name()
	var choices := []  # [name, Npc or null, player or -1]
	var other: Dictionary = t.infos[1 - i]
	if other.grown and not other.medicine and not other.leader:
		choices.append([other.name, null, 1 - i])
	for npc in t.npcs:
		if _free(npc) and t.clan.rank(npc.get_meta("base", "")) == "warrior" and npc.npc_name != deputy \
				and choices.size() < 5:
			choices.append([npc.npc_name, npc, -1])
	var question := "Who will be the new deputy?" if deputy == "" else "Who will be deputy instead of %s?" % deputy
	var pick: int = await t.ask(i, question, choices.map(func(c): return c[0]) + ["Never mind"])
	if pick < 0 or pick >= choices.size():
		return
	var chosen_name: String = choices[pick][0]
	var npc: Npc = choices[pick][1]
	var j: int = choices[pick][2]
	if j >= 0:
		if not t.available(j):
			t.say(i, "%s is busy right now. Try again soon!" % chosen_name)
			return
		var yes: int = await t.ask(j, "%s wants YOU to be ThunderClan's deputy! Will you help lead the Clan?" % _me(i),
				["Yes, I will!", "No thanks"])
		if yes != 0:
			t.say(j, "No thanks! Maybe one day.")
			return
	var lines := [["leader", "I say these words before StarClan, so that our ancestors may hear and approve my choice."],
			["leader", "%s will be the new deputy of ThunderClan!" % chosen_name],
			["cat", "Thank you, %s! I won't let you down!" % _me(i)]]
	var named := func():
		t.clan.deputy = chosen_name
		t.clan.save()
		GameState.edit_slot(GameState.together[i], {"deputy_name": chosen_name})
		if j >= 0:
			GameState.edit_slot(GameState.together[j], {"rank": "deputy"})
			t.refresh_player(j)
		t.update_deputy()
	await _ceremony(i, npc, lines, named, "%s is the new deputy!" % chosen_name, chosen_name, j)


# --- patrols -----------------------------------------------------------------------------------

## The leader or deputy sends Clan cats out on a patrol. They come back with prey or news.
func send_patrol(i: int) -> void:
	if _patrol_out:
		t.say(i, "A patrol is already out. Let's wait for them to come back!", 3.0)
		return
	var pick: int = await t.ask(i, "Which patrol should go out?", ["Hunting patrol", "Border patrol", "Never mind"])
	if pick < 0 or pick > 1:
		return
	var hunting := pick == 0
	var cats: Array = t.camp_cats(["warrior", "apprentice"])
	cats.shuffle()
	cats = cats.slice(0, 3)
	if cats.size() < 2:
		t.say(i, "Everyone is busy! Try again in a little while.", 3.0)
		return
	_patrol_out = true
	var names: Array = cats.map(func(c): return c.npc_name)
	var who := "%s and %s" % [", ".join(names.slice(0, -1)), names[-1]]
	t.say(i, "%s: please go on a %s patrol!" % [who, "hunting" if hunting else "border"], 3.5)
	for npc in cats:
		Fx.speech(npc, ["On my way!", "Yes, %s!" % _me(i), "Let's go!"].pick_random(), 112 * npc.cat.size + 30, 2.0)
	t.show_banner("The %s patrol is heading out!" % ("hunting" if hunting else "border"))
	await get_tree().create_timer(1.5).timeout
	var back := [0]  # how many are home again
	for npc in cats:
		_patrol_trip(npc, back)
	while back[0] < cats.size():
		await get_tree().process_frame
	if hunting:
		var prey := cats.size() + randi_range(1, 3)
		t.add_to_pile(prey)
		t.show_banner("The hunting patrol brought back %d pieces of prey!" % prey)
	else:
		Sfx.play("win")
		t.show_banner("The border patrol is back! %s" % BORDER_NEWS.pick_random())
	for npc in cats:
		t.release_npc(npc)
	_patrol_out = false


func _patrol_trip(npc: Npc, back: Array) -> void:
	await t.send_away(npc, randf_range(18.0, 24.0))
	back[0] += 1
