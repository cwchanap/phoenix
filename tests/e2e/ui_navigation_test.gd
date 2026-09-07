# Real-key UI navigation: pause, nested settings, and return to the world.
extends GdUnitE2ETestSuite

const WORLD := "/root/AppRoot/World"
const HUD := WORLD + "/GameHud/HudRoot"

func _tap_key(game: Variant, keycode: Key, physical := true) -> void:
	assert_bool(await game.input_key(keycode, true, physical)).is_true()
	assert_bool(await game.input_key(keycode, false, physical)).is_true()

func test_real_keys_navigate_pause_and_settings() -> void:
	var options := E2ELaunchOptions.new()
	options.scene_path = "res://scenes/app/app.tscn"
	var save_path := create_temp_dir("phoenix-task9-save") + "/save.json"
	var settings_path := create_temp_dir("phoenix-task9-settings") + "/settings.cfg"
	var settings := ConfigFile.new()
	settings.set_value("ui", "window_scale", 1)
	assert_int(settings.save(settings_path)).is_equal(OK)
	OS.set_environment("PHOENIX_SAVE_PATH", save_path)
	OS.set_environment("PHOENIX_SETTINGS_PATH", settings_path)
	var game := await launch_game(options)
	OS.unset_environment("PHOENIX_SAVE_PATH")
	OS.unset_environment("PHOENIX_SETTINGS_PATH")
	if game == null or is_failure():
		return

	assert_bool(await game.click_node("/root/AppRoot/TitleScreen/Panel/NewGame")).is_true()
	assert_bool(await game.input_action("ui_accept", true)).is_true()
	assert_bool(await game.input_action("ui_accept", false)).is_true()
	assert_bool(await game.wait_for_node(WORLD, 10.0)).is_true()

	await _tap_key(game, KEY_ESCAPE, false)
	assert_bool(await game.wait_for_property(HUD + "/PausePanel", "visible", true, 5.0)).is_true()

	await _tap_key(game, KEY_O)
	assert_bool(await game.wait_for_property(HUD + "/SettingsPanel", "visible", true, 5.0)).is_true()
	assert_bool(await game.get_property(HUD + "/PausePanel", "visible")).is_false()

	await _tap_key(game, KEY_D)
	var saved_settings := ConfigFile.new()
	assert_int(saved_settings.load(settings_path)).is_equal(OK)
	assert_int(int(saved_settings.get_value("ui", "music"))).is_equal(UiSettings.DEFAULT_MUSIC + 1)

	await _tap_key(game, KEY_ESCAPE, false)
	assert_bool(await game.wait_for_property(HUD + "/SettingsPanel", "visible", false, 5.0)).is_true()
	assert_bool(await game.get_property(HUD + "/PausePanel", "visible")).is_true()

	await _tap_key(game, KEY_ESCAPE, false)
	assert_bool(await game.wait_for_property(HUD + "/PausePanel", "visible", false, 5.0)).is_true()
