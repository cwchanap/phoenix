extends SceneTree
## Shared runner helpers for the HPA-860 native macOS rain tours.
##
## Requires PHOENIX_SAVE_PATH and PHOENIX_SETTINGS_PATH to be set to isolated
## non-default files before launching the live app. Drives real input events
## (including truck travel and passive clock ticking; does not write saves) and
## inspects live scene-tree state via WorldShell/GameHud/GameSession seams.

const APP_SCENE := preload("res://scenes/app/app.tscn")

var _app: Node
var _world: WorldShell
var _failures: Array[String] = []
var _first_layer_id: int = 0

func _boot_app() -> bool:
	if not _require_isolated_paths():
		_finish()
		return false
	# Keep the game window unoccludable: an occluded macOS window stops
	# drawing and every later capture would silently return a stale frame.
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, true)
	_app = APP_SCENE.instantiate()
	_app.name = "App"
	root.add_child.call_deferred(_app)
	return true

func _require_isolated_paths() -> bool:
	var save_path := OS.get_environment("PHOENIX_SAVE_PATH")
	var settings_path := OS.get_environment("PHOENIX_SETTINGS_PATH")
	if save_path.is_empty() or save_path == SaveRepository.DEFAULT_PATH:
		_failures.append("PHOENIX_SAVE_PATH must point to an isolated non-default save file")
	if settings_path.is_empty() or settings_path == UiSettings.DEFAULT_PATH:
		_failures.append(
			"PHOENIX_SETTINGS_PATH must point to an isolated non-default settings file"
		)
	return _failures.is_empty()

func _log(message: String) -> void:
	print("TOUR|", message)

func _frames(n: int) -> void:
	for index in n:
		await process_frame

func _stand_facing(
	target_cell: Vector2i, facing: WorldMath.Facing, cell_offset: Vector2
) -> Vector2:
	var offset: Vector2i = WorldMath.TARGET_OFFSETS[facing]
	return Vector2(target_cell - offset) + cell_offset

func _live_rain_layer() -> RainLayer:
	if _world == null:
		return null
	return _world.get_node_or_null("RainLayer") as RainLayer

func _check_rain_layer(phase: String, expect_falling: bool) -> int:
	var live_rain := _live_rain_layer()
	if live_rain == null:
		_failures.append("%s: World/RainLayer missing from scene tree" % phase)
		return 0
	if live_rain != _world.rain_layer:
		_failures.append("%s: World/RainLayer differs from cached world.rain_layer" % phase)
	if not live_rain.is_inside_tree():
		_failures.append("%s: RainLayer is not inside scene tree" % phase)
	if not live_rain.visible or not live_rain.is_visible_in_tree():
		_failures.append("%s: RainLayer is not visible in tree" % phase)
	var falling := live_rain.is_rain_falling()
	if falling != expect_falling:
		_failures.append("%s: rain_falling=%s expected %s" % [phase, str(falling), str(expect_falling)])
	if live_rain.is_processing() != expect_falling:
		_failures.append(
			"%s: rain_processing=%s expected %s"
			% [phase, str(live_rain.is_processing()), str(expect_falling)]
		)
	var layer_id := live_rain.get_instance_id()
	if _first_layer_id == 0:
		_first_layer_id = layer_id
	elif layer_id != _first_layer_id:
		_failures.append(
			"%s: rain layer instance changed %d -> %d" % [phase, _first_layer_id, layer_id]
		)
	return layer_id

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
	await _key(KEY_S)  # move_down selects Continue
	await _frames(10)
	_log("title selection=%s" % str(title.selected_action()))
	if str(title.selected_action()) != "continue":
		_failures.append("title: Continue not selected")
		_finish()
		return
	await _key(KEY_ENTER)

func _wait_world() -> void:
	var waited := 0.0
	while waited < 20.0:
		var world := _app.get_node_or_null("World") as WorldShell
		if world != null and world.farm_view != null:
			_world = world
			_log("world ready; weather=%s" % str(_session_weather()))
			return
		await _frames(10)
		waited += 0.3
	_failures.append("world never became ready")
	_finish()

func _session_weather() -> String:
	return str(_world._session.snapshot()["weather"])

func _wait_map_location(farm_expected: bool) -> void:
	var waited := 0.0
	var on_farm := true
	while waited < 30.0:
		on_farm = _world.farm_view != null
		if on_farm == farm_expected and not _world.hud.has_blocking_modal():
			var live_rain := _live_rain_layer()
			var layer_id := live_rain.get_instance_id() if live_rain != null else 0
			_log("map swapped; farm=%s rain_layer_id=%d" % [str(on_farm), layer_id])
			return
		await _frames(1)
		waited += 1.0 / 60.0
	_log("swap-poll timeout: on_farm=" + str(on_farm)
		+ " blocking=" + str(_world.hud.has_blocking_modal()))
	_failures.append("map swap to %s timed out" % ("farm" if farm_expected else "town"))

func _walk_to_grid(grid_target: Vector2, on_mid_step: Callable = Callable()) -> void:
	var world_target := WorldMath.grid_to_world(grid_target)
	var elapsed := 0.0
	var captured := 0
	while elapsed < 30.0:
		var position: Vector2 = _world.player.global_position
		var delta := world_target - position
		if absf(delta.x) < 8.0 and absf(delta.y) < 8.0:
			break
		_press_movement(delta)
		await process_frame
		elapsed += 1.0 / 60.0
		if on_mid_step.is_valid() and captured < 5 and elapsed > 2.0 + 2.0 * captured:
			captured += 1
			_release_all()
			await on_mid_step.call(captured)
	_release_all()
	await _frames(5)
	var final_delta := world_target - _world.player.global_position
	_log("walk done grid=%s target=%s" % [
		str(WorldMath.world_to_grid(_world.player.global_position)), str(grid_target),
	])
	if absf(final_delta.x) >= 8.0 or absf(final_delta.y) >= 8.0:
		_failures.append("walk to %s did not arrive; final grid=%s" % [
			str(grid_target),
			str(WorldMath.world_to_grid(_world.player.global_position)),
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
	# Press-poll: a short blind press can fall between physics ticks at high
	# refresh rates; hold until the controller reports the expected facing.
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
	# Built-in actions (ui_accept/ui_cancel) bind by keycode; project actions
	# bind by physical keycode — set both so every action matches.
	if keycode == KEY_E and _world != null:
		_log("E-press target=" + str(_world.player.current_target_cell())
			+ " facing=" + str(_world.player.facing)
			+ " grid=" + str(WorldMath.world_to_grid(_world.player.global_position))
			+ " gated=" + str(not _world._world_input_enabled))
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

func _close_modals() -> void:
	var waited := 0.0
	while _world.hud.has_blocking_modal() and waited < 4.0:
		await _key(KEY_ESCAPE)
		await _frames(10)
		waited += 0.5
	_log("modals closed blocking=%s" % str(_world.hud.has_blocking_modal()))

func _finish(label: String = "tour") -> void:
	if _failures.is_empty():
		_log("DONE clean %s" % label)
		quit(0)
	else:
		for failure in _failures:
			_log("FAIL %s" % failure)
		_log("DONE with %d failures %s" % [_failures.size(), label])
		quit(2)
