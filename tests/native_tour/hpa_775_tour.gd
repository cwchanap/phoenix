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
	var frames := 0
	while overlay.visible and overlay.modulate.a < 0.9 and frames < 900:
		await _frames(1)
		frames += 1
	if overlay.visible and overlay.modulate.a < 0.9:
		_failures.append("travel: overlay never reached the opaque phase")

func _push_key_event(keycode: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = pressed
	Input.parse_input_event(event)

func _push_click(screen_point: Vector2) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = screen_point
	press.global_position = screen_point
	Input.parse_input_event(press)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.position = screen_point
	release.global_position = screen_point
	Input.parse_input_event(release)

func _fire_beat_probes() -> void:
	for code: Key in [KEY_E, KEY_SPACE, KEY_2, KEY_I, KEY_ESCAPE]:
		_push_key_event(code, true)
		_push_key_event(code, false)
	var seed_card := _world.hud.find_child("SeedCard", true, false) as Control
	if seed_card != null:
		_push_click(seed_card.get_global_rect().get_center())
	var dismiss := _world.hud.find_child("Dismiss", true, false) as Control
	if dismiss != null and dismiss.is_visible_in_tree():
		_push_click(dismiss.get_global_rect().get_center())

func _observe_beat(overlay: Control, watch: Dictionary) -> void:
	var elapsed0 := -1.0
	var minutes0 := -1
	var last_pos: Vector2 = _world.player.global_position
	var last_on_farm := _world.farm_view != null
	var armed := 0
	while not overlay.visible and armed < 300:
		await _frames(1)
		armed += 1
	var frames := 0
	while overlay.visible and frames < 1200:
		await _frames(1)
		frames += 1
		if not overlay.visible:
			break
		watch["frames"] = int(watch["frames"]) + 1
		if _world._world_input_enabled or not _world.hud.has_blocking_modal():
			watch["gate_gaps"] = int(watch["gate_gaps"]) + 1
		if elapsed0 < 0.0:
			elapsed0 = _world._clock_elapsed_seconds
		elif _world._clock_elapsed_seconds != elapsed0:
			watch["elapsed_violations"] = int(watch["elapsed_violations"]) + 1
		var minutes := int(_world._session.snapshot()["time_minutes"])
		if minutes0 < 0:
			minutes0 = minutes
		elif minutes != minutes0:
			watch["minutes_violations"] = int(watch["minutes_violations"]) + 1
		var pos: Vector2 = _world.player.global_position
		watch["last_pos"] = pos
		if pos != last_pos:
			watch["position_changes"] = int(watch["position_changes"]) + 1
			last_pos = pos
		var on_farm := _world.farm_view != null
		if on_farm != last_on_farm:
			watch["swap_flips"] = int(watch["swap_flips"]) + 1
			last_on_farm = on_farm
		for panel in _world.hud._primary_modals:
			if panel.visible:
				watch["modal_opens"] = int(watch["modal_opens"]) + 1
	watch["done"] = true

func _stand_at(stand: Vector2, action: String, facing: WorldMath.Facing) -> void:
	await _walk_to_grid(stand)
	_world.player.global_position = WorldMath.grid_to_world(stand)
	await _face(action, facing)
	_world.player.global_position = WorldMath.grid_to_world(stand)
	await _frames(3)

func _run_beat(
	truck_cell: Vector2i,
	stand: Vector2,
	face_action: String,
	facing: WorldMath.Facing,
	expect_town: bool,
	shot_name: String
) -> void:
	_world.clock_running = false
	await _stand_at(stand, face_action, facing)
	if _world.player.current_target_cell() != truck_cell:
		_failures.append(
			"travel: not facing the truck (target %s)"
			% str(_world.player.current_target_cell())
		)
		return
	var overlay := _world.hud.get_node_or_null("HudRoot/TravelOverlay") as Control
	if overlay == null:
		_failures.append("travel: HudRoot/TravelOverlay missing")
		return
	var pause := _world.hud.get_node("HudRoot/PausePanel") as Control
	var onboarding := _world.hud._onboarding_overlay
	var dismiss := _world.hud.find_child("Dismiss", true, false) as Button
	var minutes_before := int(_world._session.snapshot()["time_minutes"])
	var seed_before := _world._session.selected_seed()
	var dismissed_before := onboarding._dismissed.size()
	var watch := {
		"frames": 0,
		"gate_gaps": 0,
		"elapsed_violations": 0,
		"minutes_violations": 0,
		"position_changes": 0,
		"modal_opens": 0,
		"swap_flips": 0,
		"seed_requests": 0,
		"dismiss_presses": 0,
	}
	_world.hud.select_seed_requested.connect(
		func(_kind: int) -> void: watch["seed_requests"] = int(watch["seed_requests"]) + 1
	)
	if dismiss != null:
		dismiss.pressed.connect(
			func() -> void: watch["dismiss_presses"] = int(watch["dismiss_presses"]) + 1
		)
	_world._clock_elapsed_seconds = 0.0
	_observe_beat(overlay, watch)
	var beat_start := Time.get_ticks_msec()
	_push_key_event(KEY_E, true)
	await _frames(1)
	_push_key_event(KEY_E, false)
	if (
		not overlay.visible
		or not _world.hud.has_blocking_modal()
		or _world._world_input_enabled
	):
		_failures.append("travel: overlay did not gate input synchronously")
	_world.clock_running = true
	_world._clock_window_focused = true
	Input.action_press("move_right")
	_fire_beat_probes()
	await _await_overlay_opaque(overlay)
	if not overlay.visible:
		_failures.append("travel: beat ended before the mid-transition frame")
	else:
		await _shot(shot_name)
	var waited := 0
	while overlay.visible and int(watch["swap_flips"]) == 0 and waited < 900:
		await _frames(1)
		waited += 1
	if int(watch["swap_flips"]) == 0:
		_failures.append("travel: map swap never fired inside the beat")
	elif overlay.visible:
		_fire_beat_probes()
	await _wait_map_location(not expect_town)
	Input.action_release("move_right")
	await _frames(3)
	_log(
		"beat released after %.2fs over %d observed frames"
		% [(Time.get_ticks_msec() - beat_start) / 1000.0, int(watch["frames"])]
	)
	if int(watch["frames"]) == 0:
		_failures.append("travel: observer never sampled the live beat")
	if int(watch["gate_gaps"]) != 0:
		_failures.append(
			"travel: input gate flickered on %d mid-beat frames" % int(watch["gate_gaps"])
		)
	if int(watch["elapsed_violations"]) != 0:
		_failures.append(
			"travel: passive clock accumulated on %d mid-beat frames"
			% int(watch["elapsed_violations"])
		)
	if int(watch["minutes_violations"]) != 0:
		_failures.append(
			"travel: session minutes changed on %d mid-beat frames"
			% int(watch["minutes_violations"])
		)
	if int(watch["swap_flips"]) != 1:
		_failures.append(
			"travel: map flipped %d times, expected exactly one swap"
			% int(watch["swap_flips"])
		)
	if int(watch["position_changes"]) != 1:
		_failures.append(
			"travel: player moved %d times; only the swap teleport is allowed"
			% int(watch["position_changes"])
		)
	if int(watch["modal_opens"]) != 0:
		_failures.append(
			"travel: a modal opened on %d mid-beat frames" % int(watch["modal_opens"])
		)
	if int(watch["seed_requests"]) != 0:
		_failures.append(
			"travel: SeedCard saw %d mid-beat clicks" % int(watch["seed_requests"])
		)
	if int(watch["dismiss_presses"]) != 0:
		_failures.append(
			"travel: tutorial Dismiss saw %d mid-beat clicks"
			% int(watch["dismiss_presses"])
		)
	if onboarding._dismissed.size() != dismissed_before:
		_failures.append("travel: tutorial dismissals changed during the beat")
	if _world._session.selected_seed() != seed_before:
		_failures.append("travel: selected seed changed during the beat")
	if pause.visible:
		_failures.append("travel: Esc opened Pause during the beat")
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
	var arrival := (
		TownContract.TRUCK_ARRIVAL if expect_town else WorldContract.TRUCK_ARRIVAL
	)
	var expected_spawn := WorldMath.grid_to_world(Vector2(arrival) + Vector2(0.5, 0.5))
	if watch.get("last_pos") != expected_spawn:
		_failures.append(
			"travel: player left the arrival spawn during the beat (%s != %s)"
			% [str(watch.get("last_pos")), str(expected_spawn)]
		)
	var elapsed_at_release := _world._clock_elapsed_seconds
	await _frames(3)
	if (
		_world._clock_elapsed_seconds <= elapsed_at_release
		and int(_world._session.snapshot()["time_minutes"])
		== minutes_before + GameRules.TRAVEL_MINUTES
	):
		_failures.append("travel: passive clock did not resume after release")
	_world.clock_running = false

func _phase_travel() -> void:
	await _run_beat(
		WorldContract.TRUCK_CELL,
		_stand_facing(WorldContract.TRUCK_CELL, WorldMath.Facing.RIGHT, Vector2(0.4, 0.3)),
		"move_right",
		WorldMath.Facing.RIGHT,
		true,
		"B1-driving-to-town",
	)
	await _run_beat(
		TownContract.TRUCK_CELL,
		_stand_facing(TownContract.TRUCK_CELL, WorldMath.Facing.LEFT, Vector2(0.4, 0.3)),
		"move_left",
		WorldMath.Facing.LEFT,
		false,
		"B1-driving-home",
	)
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
