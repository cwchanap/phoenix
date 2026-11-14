extends "res://tests/native_tour/rain_tour_base.gd"
## HPA-860 round-2 temporal-continuity recording. Drives the real app
## (windowed, real Continue flow, real input events — truck travel and
## camera-edge walk with the passive clock running; does not write saves) while
## Godot Movie Maker mode writes EVERY rendered frame to the movie: unlike the
## discrete get_image captures in rain_tour.gd there are no gaps between
## frames, so a brief rendering gap cannot hide between samples. Movie
## Maker runs a fixed timestep, so frames cannot be dropped by construction.
##
## Evidence-only one-off: backs the validation note, not maintained or run
## in CI; uses direct node inspection seams the headless suite never touches.
## Rerun directions live in the validation note. Run from the repo root (HOME,
## PHOENIX_SAVE_PATH, PHOENIX_SETTINGS_PATH isolated; seed the save first
## with tests/native_tour/seed_save.gd):
##
##   TOUR_WEATHER=rainy godot --path . --resolution 1920x1080 \
##     --write-movie /tmp/hpa860-rec/rain-travel.avi --fixed-fps 30 \
##     -s res://tests/native_tour/rain_movie_tour.gd

func _initialize() -> void:
	if not _boot_app():
		return
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
	await _walk_to_grid(
		_stand_facing(WorldContract.TRUCK_CELL, WorldMath.Facing.RIGHT, Vector2(0.4, 0.3))
	)
	await _face("move_right", WorldMath.Facing.RIGHT)
	await _frames(20)
	_observe("farm-truck")
	await _interact()
	await _wait_map_location(false)
	await _frames(30)
	_observe("town-arrival")
	await _walk_to_grid(Vector2(TownContract.MAP_SIZE) - Vector2(2.8, 2.8))
	await _frames(20)
	_observe("town-edge")
	await _walk_to_grid(
		_stand_facing(TownContract.TRUCK_CELL, WorldMath.Facing.LEFT, Vector2(0.4, 0.3))
	)
	await _face("move_left", WorldMath.Facing.LEFT)
	await _frames(20)
	_observe("town-truck")
	await _interact()
	await _wait_map_location(true)
	await _frames(30)
	_observe("return-farm")
	_finish("movie tour")

func _log(message: String) -> void:
	print("TOUR|frame=", Engine.get_frames_drawn(), "|", message)

func _observe(phase: String) -> void:
	if _world == null:
		_log("OBS " + phase + " world=null")
		return
	var rain: AudioStreamPlayer = _world.hud._rain_ambience_player
	var layer_id := _check_rain_layer(phase, true)
	var live_rain := _live_rain_layer()
	var falling := live_rain.is_rain_falling() if live_rain != null else false
	_log("OBS " + phase
		+ " | weather=" + str(_world._session.snapshot()["weather"])
		+ " location=" + str(_world._session.snapshot()["location"])
		+ " rain_layer_id=" + str(layer_id)
		+ " rain_falling=" + str(falling)
		+ " rain_audio=" + str(rain.playing)
		+ " window_focus=" + str(root.has_focus())
		+ " time_minutes=" + str(_world._session.snapshot()["time_minutes"]))
