class_name MentorTraining
extends Node
## Mentors taking their apprentices out training in ThunderClan Together.
##   Clan mentors (like Tigerclaw and Ravenpaw) walk out of camp to the Training Hollow every so
##   often, practice battle moves together, and come home again.
##   If YOU are a mentor, talk to your apprentice to take them out:
##     Battle training: walk to the Training Hollow together (follow the arrow), then practice.
##     Hunting lesson: catch 2 mice with your apprentice close by. They catch one too!
##     Herb lesson (medicine cats): pick 2 herbs with your apprentice close by.
## Every training is a lesson. After 3 lessons an apprentice is ready for their warrior name.

const HOLLOW := Vector2(1600, 2020)  # the Training Hollow (Territory.PLACES)
const ARRIVE := 260.0  # how close to the hollow counts as being there
const NEAR := 420.0  # how close your apprentice must be to watch you hunt
const LESSON_GOAL := 2  # mice or herbs in a hunting or herb lesson
const NPC_TRAINING_EVERY := [40.0, 70.0]
const MENTOR_TIPS := ["Keep your tail low!", "Now pounce, like this!", "Good! Again!", "Watch my paws!",
		"Faster this time!", "Great job!"]
const APPRENTICE_LINES := ["Like this?", "Hi-yah!", "I did it!", "Watch me!", "This is SO fun!"]
const TRAINING_CHATS := ["We're going training! Shh, we're concentrating!", "Can't stop now, it's training time!",
		"My mentor is teaching me a new move!"]

var t: Territory
var lessons := [{}, {}]  # each player's lesson: {"kind": "battle"/"hunt"/"herbs", "npc", "count", "started"}
var _labels: Array[Label] = []
var _arrows: Array[FriendPlay.RaceArrow] = []
var _npc_timer := 15.0  # the first Clan training starts soon, so you can see it
var _npc_out := false


func _init(territory: Territory) -> void:
	t = territory


func make_hud(hud: CanvasLayer) -> void:
	for i in 2:
		var label := Fx.make_label("", 22, Color("ffd966"), 6)
		label.position = Vector2(16 + i * 660, 104)
		label.size = Vector2(600, 30)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if i == 0 else HORIZONTAL_ALIGNMENT_RIGHT
		hud.add_child(label)
		_labels.append(label)
		var arrow := FriendPlay.RaceArrow.new()
		arrow.position = Vector2(30 + i * 1100, 140)
		arrow.size = Vector2(120, 120)
		arrow.place = "Training Hollow"
		arrow.visible = false
		hud.add_child(arrow)
		_arrows.append(arrow)


func _process(delta: float) -> void:
	if not t.playing:
		return
	_npc_timer -= delta
	if _npc_timer <= 0.0:
		_npc_timer = randf_range(NPC_TRAINING_EVERY[0], NPC_TRAINING_EVERY[1])
		if not _npc_out:
			_clan_training()
	for i in 2:
		var lesson: Dictionary = lessons[i]
		_arrows[i].visible = lesson.get("kind", "") == "battle" and not lesson.started
		if not _arrows[i].visible:
			continue
		_arrows[i].angle = (HOLLOW - t.map_position(i)).angle()
		_arrows[i].queue_redraw()
		var player := t.players[i]
		var npc: Npc = lesson.npc
		if t.inside[i] == "" and player.position.distance_to(HOLLOW) < ARRIVE \
				and npc.position.distance_to(player.position) < NEAR and t.available(i):
			_battle_practice(i)


# --- talking to your own apprentice ------------------------------------------------------------

func talk_to_apprentice(i: int, npc: Npc) -> void:
	var me: String = t.infos[i].name
	var medicine := t.clan.rank(npc.get_meta("base")) == "medicine_apprentice"
	var following := npc.follow_target == t.players[i]
	var options := []
	if not lessons[i].is_empty():
		options.append("Stop the lesson")
	elif medicine:
		options.append_array(["Herb lesson in the forest", "Please fetch herbs"])
	else:
		options.append_array(["Battle training at the Training Hollow", "Hunting lesson in the forest"])
	options.append("Wait here" if following else "Follow me!")
	options.append("Just say hi")
	var pick: int = await t.ask(i, "%s: What are we doing today, %s?" % [npc.npc_name, me], options)
	if pick < 0:
		return
	match options[pick]:
		"Battle training at the Training Hollow":
			_start(i, npc, "battle", "Let's go to the Training Hollow! Follow me!")
		"Hunting lesson in the forest":
			_start(i, npc, "hunt", "Let's go hunting! Stay close and watch me.")
		"Herb lesson in the forest":
			_start(i, npc, "herbs", "Let's find some herbs! Stay close and watch me.")
		"Stop the lesson":
			_stop(i)
			_say(npc, "Aww! Okay, maybe next time.")
		"Wait here":
			npc.follow_target = null
			npc.wander_area = Rect2(npc.position - Vector2(60, 30), Vector2(120, 60))
			_say(npc, "Okay! I'll wait right here.")
		"Follow me!":
			npc.wander_area = Rect2()
			npc.follow_target = t.players[i]
			_say(npc, "Coming, %s!" % me)
		"Please fetch herbs":
			t.medicine.fetch_menu(i, npc)
		_:
			_say(npc, ["You're the best mentor in the whole forest!", "I love being your apprentice!"].pick_random())


func _start(i: int, npc: Npc, kind: String, words: String) -> void:
	lessons[i] = {"kind": kind, "npc": npc, "count": 0, "started": false}
	npc.wander_area = Rect2()
	npc.follow_target = t.players[i]
	t.say(i, words, 3.0)
	_say(npc, "Yay! Training time!")
	_update_label(i)


func _stop(i: int) -> void:
	lessons[i] = {}
	_update_label(i)


func _update_label(i: int) -> void:
	var lesson: Dictionary = lessons[i]
	var label := _labels[i]
	if lesson.is_empty():
		label.text = ""
		return
	var paw: String = lesson.npc.npc_name
	match lesson.kind:
		"battle":
			label.text = "Take %s to the Training Hollow!" % paw
		"hunt":
			label.text = "Hunting lesson: catch mice with %s close by: %d / %d" % [paw, lesson.count, LESSON_GOAL]
		"herbs":
			label.text = "Herb lesson: pick herbs with %s close by: %d / %d" % [paw, lesson.count, LESSON_GOAL]


func _say(npc: Npc, text: String, seconds := 2.5) -> void:
	Fx.speech(npc, text, 112 * npc.cat.size + 30, seconds)


## Is player i's apprentice close enough to watch?
func _watching(i: int) -> bool:
	var npc: Npc = lessons[i].npc
	return t.inside[i] == "" and npc.position.distance_to(t.players[i].position) < NEAR


# --- lessons out in the forest -----------------------------------------------------------------

## Player i caught a mouse
func caught(i: int) -> void:
	if lessons[i].get("kind", "") == "hunt" and _watching(i):
		_lesson_step(i, ["Wow, what a pounce!", "I'm watching! I'm learning!", "You're SO fast!"])


## Player i picked a herb
func picked_herb(i: int, kind: String) -> void:
	if lessons[i].get("kind", "") == "herbs" and _watching(i):
		_lesson_step(i, [HerbArt.HERBS[kind].use.replace(".", "! I'll remember!")])


func _lesson_step(i: int, cheers: Array) -> void:
	var lesson: Dictionary = lessons[i]
	var npc: Npc = lesson.npc
	lesson.count += 1
	_update_label(i)
	_say(npc, cheers.pick_random())
	npc.cat.bounce(0.3)
	if lesson.count < LESSON_GOAL:
		return
	_stop(i)
	await get_tree().create_timer(1.5).timeout
	# The apprentice has a go too
	var hop := create_tween()
	hop.tween_property(npc.cat, "lift", 50.0, 0.2).set_trans(Tween.TRANS_SINE)
	hop.tween_property(npc.cat, "lift", 0.0, 0.2).set_trans(Tween.TRANS_SINE)
	await hop.finished
	Sfx.play("collect")
	Fx.burst(t.world, npc.position + Vector2(0, -20), Color("fff27a"), 16)
	if lesson.kind == "hunt":
		_say(npc, "Look! I caught one too! You can carry it home.", 3.0)
		t.carrying[i] += 1
		t.update_carrying(i)
	else:
		var herb: String = HerbArt.GROWING.pick_random()
		_say(npc, "Look! I found some %s by myself!" % herb, 3.0)
		t.clan.add_herbs(herb, 1)
		t.medicine.refresh()
	await _finished(i, npc, "hunting lesson" if lesson.kind == "hunt" else "herb lesson")


## Battle practice at the Training Hollow, once you both get there
func _battle_practice(i: int) -> void:
	var lesson: Dictionary = lessons[i]
	lesson.started = true
	var npc: Npc = lesson.npc
	var player := t.players[i]
	t.busy[i] = true
	player.frozen = true
	t.hold_npc(npc)
	await npc.walk_to(player.position + Vector2(130 if player.position.x < HOLLOW.x + 100 else -130, 0))
	npc.face_toward(player.position)
	player.cat.facing = signf(npc.position.x - player.position.x)
	var moves := [["Show me your pounce!", "Like this?"], ["Now dodge my swipe!", "Missed me! Hee hee!"],
			["Now a back-kick!", "Hi-yah!"]]
	for move in moves:
		t.say(i, move[0], 1.8)
		await get_tree().create_timer(1.6).timeout
		var start := npc.position
		var lunge := create_tween()  # the apprentice leaps at you, then back
		lunge.tween_property(npc, "position", start.lerp(player.position, 0.6), 0.2)
		lunge.parallel().tween_property(npc.cat, "lift", 45.0, 0.2)
		lunge.tween_property(npc, "position", start, 0.25)
		lunge.parallel().tween_property(npc.cat, "lift", 0.0, 0.25)
		await lunge.finished
		Sfx.play("land")
		Fx.burst(t.world, (npc.position + player.position) / 2.0 + Vector2(0, -50), Color.WHITE, 12)
		player.cat.bounce(0.3)
		_say(npc, move[1], 1.6)
		await get_tree().create_timer(1.4).timeout
	t.release_npc(npc, false)
	_stop(i)
	player.frozen = false
	t.busy[i] = false
	await _finished(i, npc, "battle training")


## A lesson is done: it counts towards the apprentice's warrior name
func _finished(i: int, npc: Npc, what: String) -> void:
	Sfx.play("powerup")
	Fx.hearts(t.world, npc.position + Vector2(0, -70), 10)
	var done := t.clan.add_lesson(npc.get_meta("base"))
	t.show_banner("%s finished their %s!" % [npc.npc_name, what])
	await get_tree().create_timer(3.0).timeout
	if done == TogetherClan.LESSONS_TO_BE_READY:
		var medicine := t.clan.rank(npc.get_meta("base")) == "medicine_apprentice"
		var who := "you" if t.infos[i].leader else "the leader"
		_say(npc, "I think I'm ready for my %s name! Will %s hold a ceremony?" % [
				"medicine cat" if medicine else "warrior", who], 4.0)
		t.show_banner("%s is ready for their %s name!" % [npc.npc_name, "medicine cat" if medicine else "warrior"])
	elif done < TogetherClan.LESSONS_TO_BE_READY:
		_say(npc, "That was great! Lessons done: %d / %d" % [done, TogetherClan.LESSONS_TO_BE_READY])


# --- Clan mentors training their apprentices ---------------------------------------------------

## A Clan mentor and their apprentice in camp, both free to go training ([mentor, apprentice])
func _free_pair() -> Array:
	var pairs := []
	for paw in t.camp_cats(["apprentice"]):
		var mentor_name := t.clan.mentor(paw.get_meta("base"))
		for npc in t.npcs:
			if npc.npc_name == mentor_name and npc.visible and not npc.has_meta("busy") \
					and not npc.has_meta("patient") and not npc.has_meta("retired") and npc.follow_target == null \
					and (npc.get_parent() == t.world or npc.get_parent() is Territory.DenRoom):
				pairs.append([npc, paw])
	return pairs.pick_random() if not pairs.is_empty() else []


## A Clan mentor takes their apprentice out to the Training Hollow, practices, and comes home
func _clan_training() -> void:
	var pair := _free_pair()
	if pair.is_empty():
		return
	_npc_out = true
	var mentor: Npc = pair[0]
	var paw: Npc = pair[1]
	# A mentor napping in their den wakes up and comes out (and goes back to bed afterwards)
	var room: Node = mentor.get_parent()
	var den_spot := mentor.position
	var from_den := room is Territory.DenRoom
	var was_sleeping := mentor.cat.sleeping
	t.bring_to_camp(mentor)
	for npc in [mentor, paw]:
		t.hold_npc(npc)
		npc.set_meta("training", true)
	_say(mentor, "Come on, %s! Training time!" % paw.npc_name)
	await get_tree().create_timer(1.0).timeout
	_say(paw, "Yay! Let's go!")
	paw.follow_target = mentor
	await mentor.walk_to(Territory.TUNNEL)
	await mentor.walk_to(Territory.OUTSIDE)
	await mentor.walk_to(HOLLOW + Vector2(-80, 30))
	paw.follow_target = null
	await paw.walk_to(HOLLOW + Vector2(80, 30))
	mentor.face_toward(paw.position)
	paw.face_toward(mentor.position)
	for round in 5:
		_say(mentor, MENTOR_TIPS.pick_random(), 1.6)
		await get_tree().create_timer(1.4).timeout
		var lunge := create_tween()
		lunge.tween_property(paw, "position", HOLLOW + Vector2(10, 30), 0.2)
		lunge.parallel().tween_property(paw.cat, "lift", 45.0, 0.2)
		lunge.tween_property(paw, "position", HOLLOW + Vector2(80, 30), 0.25)
		lunge.parallel().tween_property(paw.cat, "lift", 0.0, 0.25)
		await lunge.finished
		Fx.burst(t.world, HOLLOW + Vector2(0, -20), Color.WHITE, 10)
		mentor.cat.bounce(0.3)
		if round % 2 == 1:
			_say(paw, APPRENTICE_LINES.pick_random(), 1.4)
		await get_tree().create_timer(1.2).timeout
	t.clan.add_lesson(paw.get_meta("base"))
	Fx.hearts(t.world, paw.position + Vector2(0, -70), 8)
	_say(mentor, "Great training today, %s!" % paw.npc_name)
	await get_tree().create_timer(2.0).timeout
	paw.follow_target = mentor
	await mentor.walk_to(Territory.OUTSIDE)
	await mentor.walk_to(Territory.TUNNEL)
	paw.follow_target = null
	for npc in [mentor, paw]:
		npc.remove_meta("training")
	t.release_npc(paw)
	if from_den:
		await mentor.walk_to(t.doors[t.rooms.find_key(room)])
		mentor.reparent(room)
		mentor.position = den_spot
		mentor.set_meta("den_cat", true)
		mentor.cat.sleeping = was_sleeping
		t.release_npc(mentor, false)
	else:
		await t.release_npc(mentor)
	_npc_out = false


## Talking to a Clan cat who is out training
func training_chat(npc: Npc) -> void:
	_say(npc, TRAINING_CHATS.pick_random())
