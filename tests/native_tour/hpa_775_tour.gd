extends "res://tests/native_tour/rain_tour_base.gd"

const SEEDED_DAY := 5

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
	_finish("tour=hpa-775")

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
