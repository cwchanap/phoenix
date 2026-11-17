# godot-e2e smoke: launch the app, start a new game from the title screen,
# and confirm the live World appears.
extends GdUnitE2ETestSuite

const DAY := (
	"/root/AppRoot/World/GameHud/HudRoot/Chrome/ClockCard/Surface/Body/Row/Meta/DayTag/DayRow/Day"
)

func test_new_game_reaches_world() -> void:
	var options := E2ELaunchOptions.new()
	options.scene_path = "res://scenes/app/app.tscn"
	# gdUnit's click_node coordinates are logical viewport coordinates. Keep
	# this fixture windowed so the 1920x1080 window matches the base viewport
	# 1:1 (CI's xvfb screen is 1920x1080, so the window never shrinks).
	var settings_path := create_temp_dir("phoenix-settings-e2e") + "/settings.cfg"
	var settings := ConfigFile.new()
	settings.set_value("ui", "fullscreen", false)
	assert_int(settings.save(settings_path)).is_equal(OK)
	OS.set_environment("PHOENIX_SETTINGS_PATH", settings_path)
	var game := await launch_game(options)
	OS.unset_environment("PHOENIX_SETTINGS_PATH")
	if game == null or is_failure():
		return

	assert_bool(await game.wait_for_node("/root/AppRoot/TitleScreen", 10.0)).is_true()
	if is_failure():
		return

	assert_bool(await game.click_node("/root/AppRoot/TitleScreen/Menu/NewGame")).is_true()
	if is_failure():
		return

	assert_bool(await game.wait_for_node("/root/AppRoot/World", 10.0)).is_true()


func test_unfinished_save_enter_resumes_seeded_day() -> void:
	var save_path := create_temp_dir("phoenix-save-e2e") + "/save.json"
	var session := GameSession.new()
	var seeded := session.state()
	seeded["day"] = 5
	seeded["weather"] = &"sunny"
	seeded["weather_history"] = []
	for _index in 5:
		seeded["weather_history"].append(&"sunny")
	seeded["intro_acknowledged"] = true
	assert_str(SessionStateValidator.state_error(seeded)).is_empty()
	assert_bool(session.restore_state(seeded)).is_true()
	assert_int(SaveRepository.new(save_path).save(session.state())).is_equal(OK)

	var options := E2ELaunchOptions.new()
	options.scene_path = "res://scenes/app/app.tscn"
	var settings_path := create_temp_dir("phoenix-settings-e2e") + "/settings.cfg"
	var settings := ConfigFile.new()
	settings.set_value("ui", "fullscreen", false)
	settings.set_value("ui", "language", "en")
	assert_int(settings.save(settings_path)).is_equal(OK)
	OS.set_environment("PHOENIX_SAVE_PATH", save_path)
	OS.set_environment("PHOENIX_SETTINGS_PATH", settings_path)
	var game := await launch_game(options)
	OS.unset_environment("PHOENIX_SAVE_PATH")
	OS.unset_environment("PHOENIX_SETTINGS_PATH")
	if game == null or is_failure():
		return

	assert_bool(
		await game.wait_for_node("/root/AppRoot/TitleScreen", 10.0)
	).is_true()
	assert_str(
		await game.call_method("/root/AppRoot/TitleScreen", "selected_action")
	).is_equal("continue")
	assert_bool(await game.input_key(KEY_ENTER, true)).is_true()
	assert_bool(await game.input_key(KEY_ENTER, false)).is_true()
	assert_bool(await game.wait_for_node("/root/AppRoot/World", 10.0)).is_true()
	assert_bool(await game.wait_for_property(DAY, "text", "Day 5", 10.0)).is_true()

	var reread := SaveRepository.new(save_path).load()
	assert_str(String(reread["status"])).is_equal("loaded")
	assert_int(int(reread["state"]["day"])).is_equal(5)
