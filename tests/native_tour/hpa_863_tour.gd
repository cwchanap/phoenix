extends "res://tests/native_tour/rain_tour_base.gd"
## HPA-863 agent-operated native visual tour for the 48x40 farm and the
## unchanged town. Boots the real windowed app on a seeded Day-1 farm, teleports
## to the approved front-door, storehouse-yard, field, driveway/roadside, pier
## (including the reviewed standing-on-deck pose) and camera-extreme poses, then
## drives to town with the real truck E command
## and captures the town centre and edge. Screenshots are 1920x1080 native
## evidence only: interaction and geometry behaviour stay pinned by the
## headless/GUT/e2e suites, so movement here is transport, not a reachability
## proof. The passive clock is frozen so slow software-rendered frames cannot
## change the captured day.
##
## Env: TOUR_OUT=<png dir>; PHOENIX_SAVE_PATH / PHOENIX_SETTINGS_PATH must point
## into an isolated dir (rain_tour_base refuses the defaults).
## Rerun: DISPLAY=:99 godot --path . --script res://tests/native_tour/hpa_863_tour.gd

const SEEDED_DAY := 1
const SETTLE_FRAMES := 30  # camera-smoothing convergence
const TOUR_LABEL := "hpa863"

var _out_dir: String


func _initialize() -> void:
	_out_dir = OS.get_environment("TOUR_OUT")
	if _out_dir.is_empty():
		_failures.append("TOUR_OUT is empty; captures cannot be written")
	elif DirAccess.make_dir_recursive_absolute(_out_dir) != OK:
		_failures.append("output dir unusable: %s (make_dir failed)" % _out_dir)
	if (
		not _failures.is_empty()
		or not _require_isolated_paths()
		or not _write_settings_fixture()
		or not _seed_save()
	):
		_finish("tour=hpa-863")
		return
	if not _boot_app():
		return
	_run.call_deferred()


func _write_settings_fixture() -> bool:
	var settings_path := OS.get_environment("PHOENIX_SETTINGS_PATH")
	var settings := ConfigFile.new()
	settings.set_value("ui", "fullscreen", false)
	settings.set_value("ui", "language", "en")
	settings.set_value("ui", "tutorial_cards", false)
	var error := settings.save(settings_path)
	if error != OK:
		_failures.append("settings fixture not written: err=%d path=%s" % [error, settings_path])
		return false
	return true


func _seed_save() -> bool:
	var save_path := OS.get_environment("PHOENIX_SAVE_PATH")
	var session := GameSession.new()
	var state := session.state()
	state["day"] = SEEDED_DAY
	state["time_minutes"] = GameRules.DAY_START_MINUTES
	state["stamina"] = GameRules.MAX_STAMINA
	state["weather"] = "sunny"
	state["weather_history"] = ["sunny"]
	state["intro_acknowledged"] = true
	# Till all 30 cells and plant a 3-kind x stages 2-4 grid so the native
	# capture shows the 30 soil decals and readable crop stages.
	var planted := {
		Vector2i(16, 19): [&"turnip", 1], Vector2i(18, 19): [&"turnip", 2], Vector2i(20, 19): [&"turnip", 3],
		Vector2i(16, 20): [&"potato", 2], Vector2i(18, 20): [&"potato", 4], Vector2i(20, 20): [&"potato", 5],
		Vector2i(16, 21): [&"pumpkin", 3], Vector2i(18, 21): [&"pumpkin", 5], Vector2i(20, 21): [&"pumpkin", 7],
	}
	var farm: Array = state["farm"]
	for tile_variant in farm:
		var tile: Dictionary = tile_variant
		tile["tilled"] = true
		var planted_cell: Variant = planted.get(tile["cell"])
		if planted_cell != null:
			tile["crop"] = {
				"kind": planted_cell[0],
				"growth": planted_cell[1],
				"dry_nights": 0,
				"watered_today": false,
			}
	state["farm"] = farm
	var error := SessionStateValidator.state_error(state)
	if error != "":
		_failures.append("Seeded state invalid: %s" % error)
		return false
	var save_error := SaveRepository.new(save_path).save(state)
	if save_error != OK:
		_failures.append("Seed save failed: save_error=%d" % save_error)
		return false
	return true


func _run() -> void:
	await _frames(5)
	DisplayServer.window_move_to_foreground()
	await _title_continue()
	await _wait_world()
	await _frames(10)
	DisplayServer.window_move_to_foreground()
	_world.clock_running = false
	if DisplayServer.window_get_size() != UiSettings.WINDOW_SIZE:
		_failures.append(
			"capture window must be %s (got %s)"
				% [str(UiSettings.WINDOW_SIZE), str(DisplayServer.window_get_size())]
		)
		_finish("tour=hpa-863")
		return
	await _phase_farm()
	await _phase_town()
	_finish("tour=hpa-863")


func _phase_farm() -> void:
	await _pose(Vector2(23.5, 10.3), WorldMath.Facing.UP, "01-farm-front-door-contact")
	await _pose(Vector2(23.5, 12.3), WorldMath.Facing.UP, "02-farm-yard")
	await _pose(Vector2(15.0, 15.0), WorldMath.Facing.UP, "03-farm-storehouse-yard")
	await _pose(Vector2(17.0, 22.0), WorldMath.Facing.DOWN, "04-farm-field")
	await _pose(Vector2(22.5, 20.5), WorldMath.Facing.LEFT, "05-farm-field-east-gate")
	await _pose(Vector2(37.0, 15.5), WorldMath.Facing.RIGHT, "06-farm-driveway-roadside")
	await _pose(Vector2(23.5, 33.5), WorldMath.Facing.DOWN, "07-farm-pier")
	# The review's legal deck stance: the player root (464,930) stands on a
	# plank rooted at Y=944; the below-actor deck must not cover the player.
	await _pose(Vector2(24.3125, 33.8125), WorldMath.Facing.DOWN, "08-farm-pier-standing")
	await _pose(Vector2(2.5, 36.5), WorldMath.Facing.LEFT, "09-farm-camera-southwest")
	await _pose(Vector2(45.5, 1.5), WorldMath.Facing.RIGHT, "10-farm-camera-northeast")


func _phase_town() -> void:
	# Real E at the truck: the travel overlay performs the map swap.
	await _pose(Vector2(32.78, 12.72), WorldMath.Facing.RIGHT, "11-farm-truck-contact", false)
	await _interact()
	if not await _wait_map_location(false):
		return
	await _frames(SETTLE_FRAMES)
	await _pose(_grid_centre(TownContract.TRUCK_ARRIVAL + Vector2i(2, 0)), WorldMath.Facing.LEFT, "11-town-centre")
	await _pose(Vector2(15.5, 1.5), WorldMath.Facing.UP, "12-town-camera-northeast")
	await _pose(Vector2(0.5, 10.5), WorldMath.Facing.LEFT, "13-town-camera-southwest")


func _grid_centre(cell: Vector2i) -> Vector2:
	return Vector2(cell) + Vector2(0.5, 0.5)


func _pose(grid_point: Vector2, facing: WorldMath.Facing, shot: String, capture := true) -> void:
	_world.player.global_position = WorldMath.grid_to_world(grid_point)
	_world.player.facing = facing
	await _frames(SETTLE_FRAMES)
	if capture:
		await _shot(shot)

func _shot(shot_name: String) -> void:
	await process_frame
	await process_frame
	var image: Image = root.get_texture().get_image()
	var size := Vector2i(image.get_width(), image.get_height())
	if size != UiSettings.WINDOW_SIZE:
		_failures.append(
			"capture %s is %s, binding size is %s; not saved"
				% [shot_name, str(size), str(UiSettings.WINDOW_SIZE)]
		)
		return
	var path := "%s/%s-%s.png" % [_out_dir, TOUR_LABEL, shot_name]
	var error := image.save_png(path)
	_log("shot %s -> %s (%dx%d) err=%d" % [shot_name, path, image.get_width(), image.get_height(), error])
	if error != OK:
		_failures.append("capture %s not saved: save_png err=%d path=%s" % [shot_name, error, path])
