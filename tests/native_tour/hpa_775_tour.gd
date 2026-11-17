extends "res://tests/native_tour/rain_tour_base.gd"

const SEEDED_DAY := GameRules.MAX_DAY

var _out_dir: String

func _initialize() -> void:
	_out_dir = OS.get_environment("TOUR_OUT")
	if _out_dir.is_empty():
		_failures.append("TOUR_OUT is empty; captures cannot be written")
	elif DirAccess.make_dir_recursive_absolute(_out_dir) != OK:
		_failures.append("output dir unusable: %s (make_dir failed)" % _out_dir)
	if not _failures.is_empty() or not _seed_save():
		_finish("tour=hpa-775")
		return
	if not _boot_app():
		return
	_run.call_deferred()

func _seed_save() -> bool:
	var save_path := OS.get_environment("PHOENIX_SAVE_PATH")
	var resolved := ProjectSettings.globalize_path(save_path).simplify_path()
	var default_resolved := (
		ProjectSettings.globalize_path(SaveRepository.DEFAULT_PATH).simplify_path()
	)
	if save_path.is_empty() or resolved == default_resolved:
		_failures.append(
			"PHOENIX_SAVE_PATH must point to an isolated non-default save file"
		)
		return false
	var session := GameSession.new()
	var state := session.state()
	state["day"] = SEEDED_DAY
	state["time_minutes"] = GameRules.DAY_START_MINUTES
	state["stamina"] = GameRules.MAX_STAMINA
	state["weather"] = "sunny"
	state["weather_history"] = []
	for index in SEEDED_DAY:
		state["weather_history"].append("sunny")
	state["intro_acknowledged"] = true
	var error := SessionStateValidator.state_error(state)
	if error != "":
		_failures.append("Seeded state invalid: %s" % error)
		return false
	var save_error := SaveRepository.new(save_path).save(state)
	if save_error != OK:
		_failures.append("Seed save failed: save_error=%d" % save_error)
		return false
	_log("seeded day=%d save at %s" % [SEEDED_DAY, save_path])
	return true

func _run() -> void:
	await _frames(5)
	DisplayServer.window_move_to_foreground()
	_log("window_size=%s canvas=%s" % [str(root.size), str(root.get_visible_rect().size)])
	var title := _app.get_node("TitleScreen")
	var waited := 0.0
	while not bool(title._continue_available) and waited < 15.0:
		await _frames(10)
		waited += 0.3
	if not bool(title._continue_available):
		_failures.append("title: Continue never became available")
		_finish("tour=hpa-775")
		return
	await _frames(10)
	_log("title selection=%s (expect continue)" % str(title.selected_action()))
	if str(title.selected_action()) != "continue":
		_failures.append(
			"title: unfinished save did not default to Continue (got %s)"
			% str(title.selected_action())
		)
	await _shot("A1-title-continue")
	await _title_continue()
	await _wait_world()
	var day := int(_world._session.state()["day"])
	_log("world day=%d (expect %d)" % [day, SEEDED_DAY])
	if day != SEEDED_DAY:
		_failures.append("Continue resumed day %d, expected %d" % [day, SEEDED_DAY])
	var reread := SaveRepository.new(OS.get_environment("PHOENIX_SAVE_PATH")).load()
	if reread["status"] != &"loaded" or int(reread["state"]["day"]) != SEEDED_DAY:
		_failures.append(
			"save slot changed after launch: status=%s day=%s"
			% [str(reread["status"]), str(reread.get("state", {}).get("day", "?"))]
		)
	await _phase_travel()
	await _phase_market()
	_finish("tour=hpa-775")

func _await_overlay_opaque(overlay: Control) -> void:
	while overlay.visible and overlay.modulate.a < 0.9:
		await _frames(1)

func _tap_key(keycode: Key) -> void:
	var press := InputEventKey.new()
	press.keycode = keycode
	press.physical_keycode = keycode
	press.pressed = true
	Input.parse_input_event(press)
	await _frames(1)
	var release := InputEventKey.new()
	release.keycode = keycode
	release.physical_keycode = keycode
	Input.parse_input_event(release)
	await _frames(1)

func _stand_at(stand: Vector2, action: String, facing: WorldMath.Facing) -> void:
	await _walk_to_grid(stand)
	_world.player.global_position = WorldMath.grid_to_world(stand)
	await _face(action, facing)
	_world.player.global_position = WorldMath.grid_to_world(stand)
	await _frames(3)

func _phase_travel() -> void:
	_world.clock_running = false
	await _stand_at(
		_stand_facing(WorldContract.TRUCK_CELL, WorldMath.Facing.RIGHT, Vector2(0.4, 0.3)),
		"move_right",
		WorldMath.Facing.RIGHT
	)
	if _world.player.current_target_cell() != WorldContract.TRUCK_CELL:
		_failures.append(
			"travel: not facing the farm truck (target %s)"
			% str(_world.player.current_target_cell())
		)
		return
	var minutes_before := int(_world._session.snapshot()["time_minutes"])
	var beat_start := Time.get_ticks_msec()
	await _tap_key(KEY_E)
	var overlay := _world.hud.get_node_or_null("HudRoot/TravelOverlay") as Control
	if overlay == null:
		_failures.append("travel: HudRoot/TravelOverlay missing")
		return
	if (
		not overlay.visible
		or not _world.hud.has_blocking_modal()
		or _world._world_input_enabled
	):
		_failures.append("travel: overlay did not gate input synchronously")
	var pause := _world.hud.get_node("HudRoot/PausePanel") as Control
	await _tap_key(KEY_ESCAPE)
	await _await_overlay_opaque(overlay)
	if pause.visible:
		_failures.append("travel: Esc opened Pause during the beat")
	if not overlay.visible:
		_failures.append("travel: beat ended before the mid-transition frame")
	await _shot("B1-driving-to-town")
	await _wait_map_location(false)
	_log("beat released after %.2fs" % ((Time.get_ticks_msec() - beat_start) / 1000.0))
	if (
		overlay.visible
		or _world.hud.has_blocking_modal()
		or not _world._world_input_enabled
	):
		_failures.append("travel: gate did not release after the beat")
	if (
		int(_world._session.snapshot()["time_minutes"])
		!= minutes_before + GameRules.TRAVEL_MINUTES
	):
		_failures.append("travel: drive did not spend exactly TRAVEL_MINUTES")

	await _stand_at(
		_stand_facing(TownContract.TRUCK_CELL, WorldMath.Facing.LEFT, Vector2(0.4, 0.3)),
		"move_left",
		WorldMath.Facing.LEFT
	)
	if _world.player.current_target_cell() != TownContract.TRUCK_CELL:
		_failures.append(
			"travel: not facing the town truck (target %s)"
			% str(_world.player.current_target_cell())
		)
		return
	beat_start = Time.get_ticks_msec()
	await _tap_key(KEY_E)
	if not overlay.visible:
		_failures.append("travel: home beat did not reactivate the overlay")
	await _await_overlay_opaque(overlay)
	await _shot("B1-driving-home")
	await _wait_map_location(true)
	_log("home beat released after %.2fs" % ((Time.get_ticks_msec() - beat_start) / 1000.0))
	if not _world._world_input_enabled:
		_failures.append("travel: input gate did not release on the farm")

	await _stand_at(
		_stand_facing(WorldContract.TRUCK_CELL, WorldMath.Facing.RIGHT, Vector2(0.4, 0.3)),
		"move_right",
		WorldMath.Facing.RIGHT
	)
	await _interact()
	await _wait_map_location(false)

func _phase_market() -> void:
	_world.clock_running = false
	await _walk_to_grid(Vector2(14.5, 9.5))
	await _stand_at(
		_stand_facing(TownContract.MARKET_CELL, WorldMath.Facing.UP, Vector2(0.5, 0.5)),
		"move_up",
		WorldMath.Facing.UP
	)
	if _world.player.current_target_cell() != TownContract.MARKET_CELL:
		_failures.append(
			"market: could not face MARKET_CELL (target %s)"
			% str(_world.player.current_target_cell())
		)
		return
	await _frames(10)
	var state_before := _world._session.state()
	await _interact()
	await _frames(10)
	var panel := _world.hud.get_node_or_null("HudRoot/MarketConfirmPanel") as Control
	if panel == null or not panel.visible:
		_failures.append(
			"market: Day-14 E did not open MarketConfirmPanel (target %s)"
			% str(_world.player.current_target_cell())
		)
		return
	if _world._session.state() != state_before:
		_failures.append("market: opening the confirmation changed the session state")
	await _shot("A2-market-confirm")
	await _key(KEY_ESCAPE)
	await _frames(10)
	if panel.visible:
		_failures.append("market: Esc did not close the confirmation")
	if _world._session.state() != state_before:
		_failures.append("market: Esc changed the session state")
	if not _world._world_input_enabled:
		_failures.append("market: world input stayed gated after Esc")
	await _shot("A2-market-cancelled")
	await _interact()
	await _frames(10)
	if not panel.visible:
		_failures.append("market: second E did not reopen the confirmation")
		return
	await _key(KEY_ENTER)
	var waited := 0.0
	var result := _app.get_node_or_null("ResultScreen") as ResultScreen
	while (result == null or not result.visible) and waited < 15.0:
		await _frames(10)
		waited += 0.3
		result = _app.get_node_or_null("ResultScreen") as ResultScreen
	if result == null or not result.visible:
		_failures.append("market: result screen never appeared after confirm")
		return
	await _shot("A2-market-result")
	_log("market: result visible after one confirm")

func _shot(shot_name: String) -> void:
	await process_frame
	await process_frame
	var image: Image = root.get_texture().get_image()
	var path := "%s/hpa-775-%s.png" % [_out_dir, shot_name]
	var error := image.save_png(path)
	if error != OK:
		_failures.append(
			"capture %s not saved: save_png err=%d path=%s" % [shot_name, error, path]
		)
	_log(
		"shot %s -> %s (%dx%d) err=%d"
		% [shot_name, path, image.get_width(), image.get_height(), error]
	)
