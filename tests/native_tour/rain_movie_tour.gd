extends SceneTree
## HPA-860 round-2 temporal-continuity recording. Drives the real app
## (windowed, real Continue flow, real input events) through the rainy farm
## truck travel, the town camera-edge walk, and the travel home while Godot
## Movie Maker mode writes EVERY rendered frame to the movie: unlike the
## discrete get_image captures in rain_tour.gd there are no gaps between
## frames, so a brief rendering gap cannot hide between samples. Movie
## Maker runs a fixed timestep, so frames cannot be dropped by construction.
## Read-only toward gameplay. Run from the repo root (HOME,
## PHOENIX_SAVE_PATH, PHOENIX_SETTINGS_PATH isolated; seed the save first
## with tests/native_tour/seed_save.gd):
##
##   TOUR_WEATHER=rainy godot --path . --resolution 1920x1080 \
##     --write-movie /tmp/hpa860-rec/rain-travel.avi --fixed-fps 30 \
##     -s res://tests/native_tour/rain_movie_tour.gd

const APP_SCENE := preload("res://scenes/app/app.tscn")

var _app: Node
var _world: WorldShell
var _failures: Array[String] = []
var _first_layer_id: int = 0

func _initialize() -> void:
	# Keep the window unoccluded so macOS cannot stop drawing it.
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, true)
	_app = APP_SCENE.instantiate()
	_app.name = "App"
	root.add_child.call_deferred(_app)
	_run.call_deferred()

func _run() -> void:
	await _frames(5)
	_log("window_size=%s screen=%s" % [
		str(root.size), str(DisplayServer.screen_get_usable_rect(0).size)])
	DisplayServer.window_move_to_foreground()
	await _title_continue()
	await _wait_world()
	await _frames(30)
	_observe("farm-spawn")
	await _walk_to_grid(Vector2(21.4, 10.3))  # floor (21,10); RIGHT offset (+1,-1) -> truck (22,9)
	await _face("move_right", 1)
	await _frames(20)
	_observe("farm-truck")
	_interact()
	await _wait_map_location(false)
	await _frames(30)
	_observe("town-arrival")
	await _walk_to_grid(Vector2(13.2, 9.2))  # deepest walkable spot: south-east band corner
	await _frames(20)
	_observe("town-edge")
	await _walk_to_grid(Vector2(3.4, 8.3))  # floor (3,8); LEFT offset (-1,+1) -> town truck (2,9)
	await _face("move_left", 3)
	await _frames(20)
	_observe("town-truck")
	_interact()
	await _wait_map_location(true)
	await _frames(30)
	_observe("return-farm")
	_finish()

# --- helpers ---------------------------------------------------------------

func _frames(n: int) -> void:
	for index in n:
		await process_frame

func _log(message: String) -> void:
	print("TOUR|frame=", Engine.get_frames_drawn(), "|", message)

func _observe(phase: String) -> void:
	if _world == null:
		_log("OBS " + phase + " world=null")
		return
	var rain: AudioStreamPlayer = _world.hud._rain_ambience_player
	var falling: bool = _world.rain_layer.is_rain_falling()
	var layer_id: int = _world.rain_layer.get_instance_id()
	_log("OBS " + phase
		+ " | weather=" + str(_world._session.snapshot()["weather"])
		+ " location=" + str(_world._session.snapshot()["location"])
		+ " rain_layer_id=" + str(layer_id)
		+ " rain_falling=" + str(falling)
		+ " rain_audio=" + str(rain.playing)
		+ " window_focus=" + str(root.has_focus())
		+ " time_minutes=" + str(_world._session.snapshot()["time_minutes"]))
	if not falling:
		_failures.append("%s: rain_falling=false (movie tour is rainy-only)" % phase)
	if _first_layer_id == 0:
		_first_layer_id = layer_id
	elif layer_id != _first_layer_id:
		_failures.append("%s: rain layer instance changed %d -> %d" % [phase, _first_layer_id, layer_id])

func _title_continue() -> void:
	var title := _app.get_node("TitleScreen")
	var waited := 0.0
	while not bool(title._continue_available) and waited < 15.0:
		await _frames(10)
		waited += 0.3
	if not bool(title._continue_available):
		_failures.append("title: Continue never became available")
		_finish()
		return
	_log("title continue available; selecting Continue")
	_key(KEY_W)  # move_down selects Continue
	await _frames(10)
	_log("title selection=%s" % str(title.selected_action()))
	if str(title.selected_action()) != "continue":
		_failures.append("title: Continue not selected")
		_finish()
		return
	_key(KEY_ENTER)

func _wait_world() -> void:
	var waited := 0.0
	while waited < 20.0:
		var world := _app.get_node_or_null("World") as WorldShell
		if world != null and world.farm_view != null:
			_world = world
			_log("world ready; weather=%s" % str(_world._session.snapshot()["weather"]))
			return
		await _frames(10)
		waited += 0.3
	_failures.append("world never became ready")
	_finish()

func _wait_map_location(farm_expected: bool) -> void:
	var waited := 0.0
	var on_farm := true
	while waited < 30.0:
		on_farm = _world.farm_view != null
		if on_farm == farm_expected and not _world.hud.has_blocking_modal():
			_log("map swapped; farm=%s rain_layer_id=%d"
				% [str(on_farm), _world.rain_layer.get_instance_id()])
			return
		await _frames(1)
		waited += 1.0 / 60.0
	_log("swap-poll timeout: on_farm=" + str(on_farm)
		+ " blocking=" + str(_world.hud.has_blocking_modal()))
	_failures.append("map swap to %s timed out" % ("farm" if farm_expected else "town"))

func _walk_to_grid(grid_target: Vector2) -> void:
	var world_target := WorldMath.grid_to_world(grid_target)
	var elapsed := 0.0
	while elapsed < 30.0:
		var position: Vector2 = _world.player.global_position
		var delta := world_target - position
		if absf(delta.x) < 8.0 and absf(delta.y) < 8.0:
			break
		_press_movement(delta)
		await process_frame
		elapsed += 1.0 / 60.0
	_release_all()
	await _frames(5)
	_log("walk done grid=%s target=%s" % [
		str(WorldMath.world_to_grid(_world.player.global_position)), str(grid_target),
	])

func _press_movement(delta: Vector2) -> void:
	_set_action("move_right", delta.x > 6.0)
	_set_action("move_left", delta.x < -6.0)
	_set_action("move_down", delta.y > 6.0)
	_set_action("move_up", delta.y < -6.0)

func _set_action(action: String, want: bool) -> void:
	if want:
		Input.action_press(action)
	else:
		Input.action_release(action)

func _release_all() -> void:
	for action in ["move_right", "move_left", "move_up", "move_down"]:
		Input.action_release(action)

func _face(action: String, expected_facing: int) -> void:
	# Press-poll: hold until the controller reports the expected facing.
	Input.action_press(action)
	var waited := 0
	while int(_world.player.facing) != expected_facing and waited < 60:
		await _frames(1)
		waited += 1
		if waited % 10 == 0:
			Input.action_release(action)
			await _frames(1)
			Input.action_press(action)
	Input.action_release(action)
	await _frames(2)
	_log("face %s -> facing=%d (want %d)" % [action, int(_world.player.facing), expected_facing])
	if int(_world.player.facing) != expected_facing:
		_failures.append("face failed: %s want %d got %d" % [action, expected_facing, int(_world.player.facing)])

func _key(keycode: Key) -> void:
	# Built-in actions bind by keycode; project actions by physical — set both.
	if keycode == KEY_E and _world != null:
		_log("E-press target=" + str(_world.player.current_target_cell())
			+ " grid=" + str(WorldMath.world_to_grid(_world.player.global_position)))
	var press := InputEventKey.new()
	press.keycode = keycode
	press.physical_keycode = keycode
	press.pressed = true
	Input.parse_input_event(press)
	await _frames(4)
	if keycode == KEY_E and _world != null:
		_log("E-after toast='" + _world.hud.toast_text() + "' location_snapshot="
			+ str(_world._session.snapshot()["location"]))
	var release := InputEventKey.new()
	release.keycode = keycode
	release.physical_keycode = keycode
	release.pressed = false
	Input.parse_input_event(release)
	await _frames(4)

func _interact() -> void:
	await _key(KEY_E)

func _finish() -> void:
	if _failures.is_empty():
		_log("DONE clean movie tour")
		quit(0)
	else:
		for failure in _failures:
			_log("FAIL %s" % failure)
		_log("DONE with %d failures movie tour" % _failures.size())
		quit(2)
