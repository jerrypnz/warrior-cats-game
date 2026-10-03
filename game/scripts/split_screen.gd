class_name SplitScreen
extends RefCounted
## Two players on one screen: the left half follows Player 1 and the right half follows
## Player 2, but both halves show the same world.

const HALF := Vector2(636, 720)  # each player's half of the screen (with a thin line between)


## Puts the world inside two side-by-side views and gives each view its own camera.
## Returns the two cameras: move them to follow the players.
static func make(parent: Node, world: Node2D, map: Rect2) -> Array[Camera2D]:
	var views: Array[SubViewport] = []
	for i in 2:
		var box := SubViewportContainer.new()
		box.position = Vector2(i * (1280 - HALF.x), 0)
		box.size = HALF
		box.stretch = true
		parent.add_child(box)
		var view := SubViewport.new()
		view.size = Vector2i(HALF)
		view.handle_input_locally = false
		box.add_child(view)
		views.append(view)
	views[0].add_child(world)
	views[1].world_2d = views[0].world_2d  # both views look at the same world
	var cameras: Array[Camera2D] = []
	for i in 2:
		var camera := Camera2D.new()
		camera.limit_left = int(map.position.x)
		camera.limit_top = int(map.position.y)
		camera.limit_right = int(map.end.x)
		camera.limit_bottom = int(map.end.y)
		camera.position_smoothing_enabled = true
		camera.position_smoothing_speed = 7.0
		views[i].add_child(camera)
		cameras.append(camera)
	return cameras


## The pink line down the middle of the screen
static func divider(hud: CanvasLayer) -> void:
	var line := ColorRect.new()
	line.color = Fx.PINK_DARK
	line.position = Vector2(HALF.x, 0)
	line.size = Vector2(1280 - HALF.x * 2, 720)
	hud.add_child(line)


## A player's cat from a save slot, using Player 1's or Player 2's keys
static func make_player(info: Dictionary, index: int, bounds: Rect2) -> TopDownPlayer:
	var player := TopDownPlayer.new()
	player.custom = info
	player.controls = "p%d" % (index + 1)
	player.bounds = bounds
	player.speed = 270.0
	player.can_pounce = true
	player.frozen = true
	return player
