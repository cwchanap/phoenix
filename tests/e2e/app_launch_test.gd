# godot-e2e smoke: launch the app, start a new game from the title screen,
# and confirm the live World appears.
extends GdUnitE2ETestSuite

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
