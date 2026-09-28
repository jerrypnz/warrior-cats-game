extends SceneTree
## Runs a scene for a fixed amount of game time, pressing input actions on a schedule,
## then optionally saves a screenshot. Driven by tools/check_game.py — see that file.
##
## User args (after "--"):
##   --scene res://path.tscn   --seconds 3   --screenshot /abs/out.png
##   --hold action:start:end   (seconds; repeatable)

var seconds := 3.0
var screenshot_path := ""
var holds: Array = []  # of [action: String, start: float, end: float]
var held := {}
var elapsed := 0.0
var stopped := false


func _initialize() -> void:
	var scene_path := str(ProjectSettings.get_setting("application/run/main_scene", ""))
	var args := OS.get_cmdline_user_args()
	var i := 0
	while i < args.size():
		var value: String = args[i + 1] if i + 1 < args.size() else ""
		match args[i]:
			"--scene":
				scene_path = value
			"--seconds":
				seconds = value.to_float()
			"--screenshot":
				screenshot_path = value
			"--hold":
				var parts := value.split(":")
				holds.append([parts[0], parts[1].to_float(), parts[2].to_float()])
		i += 2

	for hold in holds:
		if not InputMap.has_action(hold[0]):
			printerr("CHECK ERROR: no input action named '%s'. Known actions: %s" % [hold[0], _game_actions()])
			_stop()
			return

	if scene_path.is_empty():
		printerr("CHECK ERROR: no main scene is set in project.godot (application/run/main_scene)")
		_stop()
		return
	var err := change_scene_to_file(scene_path)
	if err != OK:
		printerr("CHECK ERROR: could not load scene %s (%s)" % [scene_path, error_string(err)])
		_stop()
		return
	print("CHECK: running %s for %.1f seconds" % [scene_path, seconds])


func _process(delta: float) -> bool:
	if stopped:
		return true
	elapsed += delta
	# An action can have several windows (taps); it is down if any of them is active.
	var wanted := {}
	for hold in holds:
		var in_window: bool = elapsed >= hold[1] and elapsed < hold[2]
		wanted[hold[0]] = wanted.get(hold[0], false) or in_window
	for action in wanted:
		var active: bool = wanted[action]
		# Re-press every frame while active: Godot releases held actions when the window
		# loses focus, which happens when the screenshot window opens behind other apps.
		if (active and not Input.is_action_pressed(action)) or (not active and held.get(action, false)):
			var event := InputEventAction.new()
			event.action = action
			event.pressed = active
			Input.parse_input_event(event)
		held[action] = active
	if elapsed < seconds:
		return false

	if not screenshot_path.is_empty():
		var image := root.get_texture().get_image()
		if image == null or image.is_empty():
			printerr("CHECK ERROR: could not capture a screenshot (is a display available?)")
		else:
			image.save_png(screenshot_path)
			print("CHECK: screenshot saved")
	print("CHECK: finished")
	return true


func _game_actions() -> Array:
	return InputMap.get_actions().filter(func(a): return not str(a).begins_with("ui_"))


func _stop() -> void:
	stopped = true
	quit(1)
