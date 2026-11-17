extends "res://tests/native_tour/rain_tour_base.gd"

const SEEDED_DAY := 1
const FARM_CELLS := 3

var _out_dir: String
var _t0 := -1
var _start_clock_minutes := -1
var _start_acc := 0.0
var _bed_clock_minutes := -1
var _bed_acc := 0.0
var _active_seconds := 0.0
var _credited_seconds := 0.0
var _ungated_frames := 0
var _clock_focused_frames := 0
var _window_focus_seen := false
var _day1_frozen := false
var _day2_active_seconds := 0.0
var _day2_credited_seconds := 0.0
var _day2_ungated_frames := 0
var _day2_clock_focused_frames := 0

func _initialize() -> void:
	_out_dir = OS.get_environment("TOUR_OUT")
	if _out_dir.is_empty():
		_failures.append("TOUR_OUT is empty; captures cannot be written")
	elif DirAccess.make_dir_recursive_absolute(_out_dir) != OK:
		_failures.append("output dir unusable: %s (make_dir failed)" % _out_dir)
	if not _failures.is_empty() or not _seed_save():
		_finish("tour=hpa-775-day")
		return
	if not _boot_app():
		return
	_track_clock.call_deferred()
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

func _track_clock() -> void:
	var last := Time.get_ticks_msec()
	while true:
		await process_frame
		var now := Time.get_ticks_msec()
		if _world != null and _t0 >= 0:
			if root.has_focus():
				_window_focus_seen = true
			if _world._clock_window_focused:
				if _day1_frozen:
					_day2_clock_focused_frames += 1
				else:
					_clock_focused_frames += 1
				if _world.clock_running and _world._world_input_enabled:
					var span := (now - last) / 1000.0
					var credited := minf(span, WorldShell.CLOCK_DELTA_CLAMP)
					if _day1_frozen:
						_day2_active_seconds += span
						_day2_credited_seconds += credited
						_day2_ungated_frames += 1
					else:
						_active_seconds += span
						_credited_seconds += credited
						_ungated_frames += 1
		last = now

func _mark(label: String) -> void:
	var snapshot := _world._session.snapshot()
	_log(
		(
			"%s wall=%s elapsed=%.2fs active=%.2fs day2_active=%.2fs "
			+ "clock=%s acc=%.4f "
			+ "window_focus=%s clock_focused=%s gated=%s"
		)
		% [
			label,
			Time.get_datetime_string_from_system(),
			(Time.get_ticks_msec() - _t0) / 1000.0,
			_active_seconds,
			_day2_active_seconds,
			GameRules.format_time(int(snapshot["time_minutes"])),
			_world._clock_elapsed_seconds,
			str(root.has_focus()),
			str(_world._clock_window_focused),
			str(not _world._world_input_enabled),
		]
	)

func _stand_at(stand: Vector2, action: String, facing: WorldMath.Facing) -> void:
	await _walk_to_grid(stand)
	_world.player.global_position = WorldMath.grid_to_world(stand)
	await _face(action, facing)
	_world.player.global_position = WorldMath.grid_to_world(stand)
	await _frames(3)

func _work_cell(cell: Vector2i, farm_index: int) -> void:
	await _stand_at(
		_stand_facing(cell, WorldMath.Facing.DOWN, Vector2(0.5, 0.5)),
		"move_down",
		WorldMath.Facing.DOWN
	)
	if _world.player.current_target_cell() != cell:
		_failures.append(
			"farm: not facing cell %s (target %s)"
			% [str(cell), str(_world.player.current_target_cell())]
		)
		return
	await _key(KEY_SPACE)
	var tile: Dictionary = _world._session.snapshot()["farm"][farm_index]
	if tile["cell"] != cell:
		_failures.append(
			"farm: snapshot slot %d holds %s, expected %s"
			% [farm_index, str(tile["cell"]), str(cell)]
		)
		return
	if not bool(tile["tilled"]):
		_failures.append(
			"farm: cell %s not tilled (toast '%s')"
			% [str(cell), _world.hud.toast_text()]
		)
		return
	await _key(KEY_SPACE)
	tile = _world._session.snapshot()["farm"][farm_index]
	if tile["crop"] == null:
		_failures.append(
			"farm: cell %s not planted (toast '%s')"
			% [str(cell), _world.hud.toast_text()]
		)
		return
	await _key(KEY_SPACE)
	tile = _world._session.snapshot()["farm"][farm_index]
	if not bool(tile["crop"]["watered_today"]):
		_failures.append(
			"farm: cell %s not watered (toast '%s')"
			% [str(cell), _world.hud.toast_text()]
		)
		return
	_mark("worked %s" % str(cell))

func _drive(truck: Vector2i, stand: Vector2, action: String, facing: WorldMath.Facing, to_town: bool) -> void:
	await _stand_at(stand, action, facing)
	if _world.player.current_target_cell() != truck:
		_failures.append(
			"travel: not facing the truck (target %s)"
			% str(_world.player.current_target_cell())
		)
		return
	_mark("drive depart")
	await _interact()
	await _wait_map_location(not to_town)
	_mark("drive arrive")

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
		_finish("tour=hpa-775-day")
		return
	await _title_continue()
	await _wait_world()
	if _world == null:
		_finish("tour=hpa-775-day")
		return
	_t0 = Time.get_ticks_msec()
	_start_clock_minutes = int(_world._session.snapshot()["time_minutes"])
	_start_acc = _world._clock_elapsed_seconds
	_mark("day-start")
	var cells := WorldContract.farm_cells()
	for index in FARM_CELLS:
		await _work_cell(cells[index], index)
		if not _failures.is_empty():
			break
	_mark("farm-done")
	await _shot("day-farm-worked")
	await _drive(
		WorldContract.TRUCK_CELL,
		_stand_facing(WorldContract.TRUCK_CELL, WorldMath.Facing.RIGHT, Vector2(0.4, 0.3)),
		"move_right",
		WorldMath.Facing.RIGHT,
		true
	)
	await _shot("day-town-arrival")
	await _drive(
		TownContract.TRUCK_CELL,
		_stand_facing(TownContract.TRUCK_CELL, WorldMath.Facing.LEFT, Vector2(0.4, 0.3)),
		"move_left",
		WorldMath.Facing.LEFT,
		false
	)
	await _stand_at(
		_stand_facing(WorldContract.BED_CELL, WorldMath.Facing.UP, Vector2(0.5, 0.5)),
		"move_up",
		WorldMath.Facing.UP
	)
	if _world.player.current_target_cell() != WorldContract.BED_CELL:
		_failures.append(
			"bed: not facing the bed (target %s)"
			% str(_world.player.current_target_cell())
		)
		_finish("tour=hpa-775-day")
		return
	_mark("bed-side")
	await _interact()
	var sleep_panel := _world.hud.get_node_or_null("HudRoot/SleepPanel") as Control
	var sleep_deadline := Time.get_ticks_msec() + 15000
	while (
		(sleep_panel == null or not sleep_panel.visible)
		and Time.get_ticks_msec() < sleep_deadline
	):
		await _frames(1)
		sleep_panel = _world.hud.get_node_or_null("HudRoot/SleepPanel") as Control
	_day1_frozen = true
	if sleep_panel == null or not sleep_panel.visible:
		_failures.append("bed: sleep confirmation never opened")
		_finish("tour=hpa-775-day")
		return
	await _shot("day-sleep-confirm")
	_bed_clock_minutes = int(_world._session.snapshot()["time_minutes"])
	_bed_acc = _world._clock_elapsed_seconds
	_mark("sleep-confirm")
	await _key(KEY_ENTER)
	var summary := _world.hud.get_node_or_null("HudRoot/MorningSummaryPanel") as Control
	waited = 0.0
	while (summary == null or not summary.visible) and waited < 15.0:
		await _frames(10)
		waited += 0.3
		summary = _world.hud.get_node_or_null("HudRoot/MorningSummaryPanel") as Control
	if summary == null or not summary.visible:
		_failures.append("bed: morning summary never opened")
		_finish("tour=hpa-775-day")
		return
	_mark("morning-summary")
	await _shot("day2-morning-summary")
	await _key(KEY_ENTER)
	waited = 0.0
	while _world.hud.has_blocking_modal() and waited < 15.0:
		await _frames(10)
		waited += 0.3
	_mark("day-2-ready")
	var snapshot := _world._session.snapshot()
	if int(snapshot["day"]) != SEEDED_DAY + 1:
		_failures.append(
			"bed: day is %d, expected %d" % [int(snapshot["day"]), SEEDED_DAY + 1]
		)
	var reread := SaveRepository.new(OS.get_environment("PHOENIX_SAVE_PATH")).load()
	if reread["status"] != &"loaded" or int(reread["state"]["day"]) != SEEDED_DAY + 1:
		_failures.append(
			"bed: saved day %s, expected %d"
			% [str(reread.get("state", {}).get("day", "?")), SEEDED_DAY + 1]
		)
	var pre_observed := _start_clock_minutes - GameRules.DAY_START_MINUTES
	var observed_ticks := (
		_bed_clock_minutes
		- _start_clock_minutes
		- FARM_CELLS * 70
		- 2 * GameRules.TRAVEL_MINUTES
	)
	var credited_needed := (
		observed_ticks * GameRules.REAL_SECONDS_PER_GAME_MINUTE
		+ _bed_acc
		- _start_acc
	)
	_log(
		(
			"day-result observed_start=%s start_acc=%.4f bed_clock=%s "
			+ "bed_acc=%.4f action_minutes=%d travel_minutes=%d "
			+ "passive_ticks=%d pre_observed_ticks=%d active_wall=%.2fs "
			+ "clamp_credited=%.2fs credited_needed=%.2fs rate=%.4f "
			+ "ungated_frames=%d clock_focused_frames=%d window_focus_seen=%s"
		)
		% [
			GameRules.format_time(_start_clock_minutes),
			_start_acc,
			GameRules.format_time(_bed_clock_minutes),
			_bed_acc,
			FARM_CELLS * 70,
			2 * GameRules.TRAVEL_MINUTES,
			observed_ticks,
			pre_observed,
			_active_seconds,
			_credited_seconds,
			credited_needed,
			GameRules.REAL_SECONDS_PER_GAME_MINUTE,
			_ungated_frames,
			_clock_focused_frames,
			str(_window_focus_seen),
		]
	)
	var day2_clock := int(snapshot["time_minutes"])
	_log(
		(
			"day2-result clock=%s acc=%.4f passive_ticks=%d "
			+ "active_wall=%.2fs clamp_credited=%.2fs "
			+ "ungated_frames=%d clock_focused_frames=%d"
		)
		% [
			GameRules.format_time(day2_clock),
			_world._clock_elapsed_seconds,
			day2_clock - GameRules.DAY_START_MINUTES,
			_day2_active_seconds,
			_day2_credited_seconds,
			_day2_ungated_frames,
			_day2_clock_focused_frames,
		]
	)
	if _clock_focused_frames == 0 or not _window_focus_seen:
		_failures.append(
			"pacing evidence INVALID: window/clock never focused — zero passive "
			+ "ticks are not a successful observed run"
		)
	_finish("tour=hpa-775-day")

func _shot(shot_name: String) -> void:
	if _out_dir.is_empty():
		return
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
