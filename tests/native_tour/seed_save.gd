extends SceneTree
## Headless helper: seeds a schema-v4 save with a forced weather through the
## real GameSession/SaveRepository so the native rain tour can Continue into
## rainy or sunny weather deterministically. Env: TOUR_WEATHER, and
## PHOENIX_SAVE_PATH pointing at the tour's isolated save file.
## Evidence-only one-off companion of the rain tours; not run in CI.

func _initialize() -> void:
	var save_path := OS.get_environment("PHOENIX_SAVE_PATH")
	var resolved := ProjectSettings.globalize_path(save_path).simplify_path()
	var default_resolved := ProjectSettings.globalize_path(SaveRepository.DEFAULT_PATH).simplify_path()
	if save_path.is_empty() or resolved == default_resolved:
		push_error("PHOENIX_SAVE_PATH must point to an isolated non-default save file")
		quit(1)
		return
	var rainy: bool = OS.get_environment("TOUR_WEATHER") == "rainy"
	var session := GameSession.new()
	var state := session.state()
	state["day"] = 2
	state["time_minutes"] = GameRules.DAY_START_MINUTES
	state["stamina"] = GameRules.MAX_STAMINA
	state["weather"] = "rainy" if rainy else "sunny"
	state["weather_history"] = ["sunny", state["weather"]]
	state["intro_acknowledged"] = true
	var error := SessionStateValidator.state_error(state)
	if error != "":
		push_error("Seeded state invalid: %s" % error)
		quit(1)
		return
	var repository := SaveRepository.new(save_path)
	var save_error := repository.save(state)
	print("SEED weather=%s save_error=%d" % [state["weather"], save_error])
	quit(0 if save_error == OK else 1)
