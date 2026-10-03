class_name FriendPlay
extends Node
## Things the two players can do with each other in ThunderClan Together.
## Walk up to the other player's cat and press your key:
##   Say something, share tongues (purr!), play tag, race to a special place, share a mouse,
##   and medicine cats can ask their friend to find herbs.
## Games need the other player to say yes first.

const PHRASES := ["Hi, friend!", "Let's go hunting!", "Follow me!", "You're the best!", "Look over there!",
		"Good job!", "Let's go to Fourtrees!"]
const TAG_TIME := 40.0
const RACE_TIME := 90.0
const TAG_REACH := 95.0
const FINISH_REACH := 190.0

var t: Territory
var _mode := ""  # "", "tag" or "race"
var _time_left := 0.0
var _counting := false  # "3, 2, 1, GO!" before a race
var _it := 0  # who is "it" in tag
var _safe := 0.0  # a moment after a tag when you can't tag back
var _it_label: Label
var _target := 0  # where the race goes (a place in Territory.PLACES)
var _game_back: Panel
var _game_label: Label
var _arrows: Array[RaceArrow] = []
var _map: Territory.MiniMap


func _init(territory: Territory) -> void:
	t = territory


func running() -> bool:
	return _mode != ""


func make_hud(hud: CanvasLayer, map: Territory.MiniMap) -> void:
	_map = map
	_game_back = Panel.new()
	_game_back.position = Vector2(470, 536)
	_game_back.size = Vector2(340, 50)
	_game_back.add_theme_stylebox_override("panel", Fx.cute_panel(18))
	_game_back.visible = false
	hud.add_child(_game_back)
	_game_label = Fx.ink_label("", 26, Fx.PINK_DARK)
	_game_label.size = Vector2(340, 50)
	_game_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_game_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_game_back.add_child(_game_label)
	for i in 2:
		var arrow := RaceArrow.new()
		arrow.position = Vector2(30 + i * 1100, 110)
		arrow.size = Vector2(120, 120)
		arrow.visible = false
		hud.add_child(arrow)
		_arrows.append(arrow)


## Player i walked up to the other player and pressed their key
func friend_menu(i: int) -> void:
	var j := 1 - i
	var friend: String = t.infos[j].name
	var options := ["Say something", "Share tongues", "Play tag!", "Race!"]
	if t.carrying[i] > 0:
		options.append("Share a mouse")
	if t.infos[i].medicine and not t.infos[j].medicine and t.medicine.errands[j].is_empty():
		options.append("Ask for herbs")
	if t.medicine.can_give(i, j):
		options.append("Give your herbs")
	options.append("Never mind")
	var pick: int = await t.ask(i, "What do you want to do with %s?" % friend, options)
	if pick < 0:
		return
	match options[pick]:
		"Say something":
			var said: int = await t.ask(i, "What will you say?", PHRASES + ["Never mind"])
			if said >= 0 and said < PHRASES.size():
				t.say(i, PHRASES[said], 3.0)
				Fx.hearts(t.world, t.players[i].position + Vector2(0, -60), 4)
		"Share tongues":
			if await _invite(i, "%s wants to share tongues with you! (That's how cats show they're friends.)" % t.infos[i].name):
				await _share_tongues(i)
		"Play tag!":
			if await _invite(i, "%s wants to play tag! They'll be IT first. Run!" % t.infos[i].name):
				_play_tag(i)
		"Race!":
			if await _invite(i, "%s wants to race you! Ready?" % t.infos[i].name):
				_race()
		"Share a mouse":
			_share_mouse(i)
		"Ask for herbs":
			t.medicine.ask_friend(i)
		"Give your herbs":
			t.medicine.put_away(i)


## Asks the other player if they want to play. True if they said yes.
func _invite(i: int, question: String) -> bool:
	var j := 1 - i
	if not t.available(j):
		t.say(i, "%s is busy right now. Try again soon!" % t.infos[j].name, 2.5)
		return false
	var yes: int = await t.ask(j, question, ["Yes!", "Not now"])
	if yes != 0:
		t.say(j, "Not now, maybe later!", 2.5)
		return false
	t.say(j, "Yes!", 1.5)
	return true


func _share_tongues(i: int) -> void:
	var j := 1 - i
	for k in 2:
		t.busy[k] = true
		t.players[k].frozen = true
	t.players[i].cat.facing = signf(t.players[j].position.x - t.players[i].position.x)
	t.players[j].cat.facing = -t.players[i].cat.facing
	for beat in 3:
		for k in 2:
			Fx.hearts(t.world, t.players[k].position + Vector2(0, -70), 6)
			t.players[k].cat.bounce(0.2)
		Sfx.play("select", 0.8 + beat * 0.1)
		if beat == 1:
			t.say(i, "Purr...", 1.5)
			t.say(j, "Purrrr!", 1.5)
		await get_tree().create_timer(0.9).timeout
	Fx.popup_text(t.world, (t.players[0].position + t.players[1].position) / 2.0 + Vector2(0, -150), "Best friends!",
			Color("ff9ec0"), 30)
	Sfx.play("powerup")
	for k in 2:
		t.players[k].frozen = false
		t.busy[k] = false


func _share_mouse(i: int) -> void:
	var j := 1 - i
	t.carrying[i] -= 1
	t.update_carrying(i)
	Sfx.play("collect")
	for k in 2:
		Fx.hearts(t.world, t.players[k].position + Vector2(0, -60), 8)
		t.players[k].cat.bounce(0.3)
	t.say(i, "Here, let's share!", 2.0)
	t.say(j, "Yum! Thank you!", 2.0)


# --- tag ---------------------------------------------------------------------------------------

func _play_tag(it: int) -> void:
	_mode = "tag"
	_it = it
	_safe = 2.0  # a head start for the other cat
	_time_left = TAG_TIME
	_it_label = Fx.make_label("IT!", 30, Color("ff5d73"), 8)
	_it_label.size = Vector2(120, 40)
	_it_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place_it_label()
	_game_back.visible = true
	t.show_banner("TAG! %s is IT! Pounce to tag!" % t.infos[it].name)


func _place_it_label() -> void:
	var player := t.players[_it]
	if _it_label.get_parent():
		_it_label.reparent(player, false)
	else:
		player.add_child(_it_label)
	_it_label.position = Vector2(-60, -112 * player.cat.size - 74)


func _tag_turn(delta: float) -> void:
	_safe -= delta
	var it := t.players[_it]
	var runner := t.players[1 - _it]
	var close := it.position.distance_to(runner.position)
	if _safe <= 0.0 and (close < 55.0 or (it.is_pouncing() and close < TAG_REACH)):
		_it = 1 - _it
		_safe = 1.5
		_place_it_label()
		Sfx.play("enemy_bonk")
		Fx.burst(t.world, runner.position + Vector2(0, -60), Color("ff5d73"), 16)
		runner.cat.bounce(0.4)
		Fx.popup_text(t.world, runner.position + Vector2(0, -150), "Tag! You're IT!", Color("ff9ec0"), 28)
	_game_label.text = "TAG!  %s is IT  %d" % [t.infos[_it].name, ceili(_time_left)]
	if _time_left <= 0.0:
		_mode = ""
		_it_label.queue_free()
		_game_back.visible = false
		Sfx.play("win")
		for k in 2:
			Fx.confetti(t.world, t.players[k].position + Vector2(0, -120), 40)
		t.show_banner("What a fun game of tag!")


# --- races -------------------------------------------------------------------------------------

func _race() -> void:
	# Race somewhere far from both of you
	var middle := (t.map_position(0) + t.map_position(1)) / 2.0
	var far := []
	for k in Territory.PLACES.size():
		if Territory.PLACES[k][1].distance_to(middle) > 700.0:
			far.append(k)
	_target = far.pick_random() if not far.is_empty() else randi() % Territory.PLACES.size()
	var place: String = Territory.PLACES[_target][0]
	_mode = "race"
	_time_left = RACE_TIME
	_map.target = Territory.PLACES[_target][1]
	for k in 2:
		t.busy[k] = true
		t.players[k].frozen = true
		_arrows[k].place = place
		_arrows[k].visible = true
	_game_back.visible = true
	_counting = true
	t.show_banner("Race to %s! Follow the arrow!" % place)
	for count in ["3", "2", "1", "GO!"]:
		_game_label.text = count
		Sfx.play("click" if count != "GO!" else "powerup")
		await get_tree().create_timer(0.8).timeout
	_counting = false
	for k in 2:
		t.players[k].frozen = false
		t.busy[k] = false


func _race_turn() -> void:
	var goal: Vector2 = Territory.PLACES[_target][1]
	for k in 2:
		_arrows[k].angle = (goal - t.map_position(k)).angle()
		_arrows[k].queue_redraw()
	if _counting:
		_time_left = RACE_TIME
		return
	_game_label.text = "Race!  %d" % ceili(_time_left)
	for k in 2:
		if t.inside[k] == "" and t.players[k].position.distance_to(goal) < FINISH_REACH:
			_end_race(k)
			return
	if _time_left <= 0.0:
		_end_race(-1)


func _end_race(winner: int) -> void:
	_mode = ""
	_map.target = Vector2.INF
	_game_back.visible = false
	for arrow in _arrows:
		arrow.visible = false
	Sfx.play("win")
	if winner < 0:
		t.show_banner("Time's up! What a long way!")
		return
	Fx.confetti(t.world, t.players[winner].position + Vector2(0, -120), 70)
	t.players[winner].cat.bounce(0.5)
	t.show_banner("%s wins the race!" % t.infos[winner].name)
	t.say(1 - winner, "Great race, %s!" % t.infos[winner].name, 3.0)


func _process(delta: float) -> void:
	if _mode == "" or not t.playing:
		return
	_time_left -= delta
	if _mode == "tag":
		_tag_turn(delta)
	elif _mode == "race":
		_race_turn()


class RaceArrow extends Control:
	## A big arrow pointing the way in a race, with the place's name under it
	var angle := 0.0
	var place := ""

	func _draw() -> void:
		var center := Vector2(60, 50)
		draw_circle(center, 44, Fx.OUTLINE)
		draw_circle(center, 40, Fx.CREAM)
		var tip := center + Vector2.from_angle(angle) * 30
		var back := center - Vector2.from_angle(angle) * 22
		var side := Vector2.from_angle(angle + PI / 2) * 18
		draw_colored_polygon(PackedVector2Array([tip, back + side, back - side]), Fx.PINK_DARK)
		var font := ThemeDB.fallback_font
		draw_string_outline(font, Vector2(-40, 118), place, HORIZONTAL_ALIGNMENT_CENTER, 200, 22, 6, Fx.OUTLINE)
		draw_string(font, Vector2(-40, 118), place, HORIZONTAL_ALIGNMENT_CENTER, 200, 22, Color("ffd966"))
