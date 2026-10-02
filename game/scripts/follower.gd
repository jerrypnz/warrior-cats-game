class_name Follower
extends Node2D
## A Clanmate who follows behind a leader cat, walking (and jumping) along the same path.

var leader: Node2D
var gap := 70.0  # how far behind the leader to walk (along the path)
var display_name := ""
var cat: Cat

var _trail: Array[Vector2] = []


static func make(cat_name: String, follow: Node2D, distance: float) -> Follower:
	var f := Follower.new()
	var data: Dictionary = GameState.CATS[cat_name]
	f.display_name = Story.display_name(cat_name)
	f.leader = follow
	f.gap = distance
	f.cat = Cat.new()
	f.cat.set_look(data)
	f.cat.size = data.get("size", 1.0)
	f.add_child(f.cat)
	var label := Fx.make_label(f.display_name, 20, Color.WHITE, 6)
	label.size = Vector2(240, 30)
	label.position = Vector2(-120, -112 * f.cat.size - 26)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	f.add_child(label)
	return f


## Jump straight to just behind the leader (after respawning)
func reset() -> void:
	_trail.clear()
	var d := gap * 1.5
	while d >= 0.0:
		_trail.append(leader.position - Vector2(d, 0))
		d -= 4.0
	position = leader.position - Vector2(gap, 0)


func _ready() -> void:
	reset()


func _process(delta: float) -> void:
	var lead_pos := leader.position
	if _trail.is_empty() or _trail[-1].distance_to(lead_pos) > 4.0:
		_trail.append(lead_pos)
		if _trail.size() > 400:
			_trail.pop_front()
	# Walk back along the trail until we're "gap" away from the leader
	var dist := 0.0
	var target := _trail[0]
	for i in range(_trail.size() - 1, 0, -1):
		dist += _trail[i].distance_to(_trail[i - 1])
		if dist >= gap:
			target = _trail[i - 1]
			break
	var old := position
	position = position.lerp(target, minf(1.0, delta * 12.0))
	var moved := position - old
	cat.walk_amount = move_toward(cat.walk_amount, 1.0 if moved.length() > 0.6 else 0.0, delta * 6.0)
	if absf(moved.x) > 0.3:
		cat.facing = signf(moved.x)
