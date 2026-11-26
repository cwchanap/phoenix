# Real-key UI navigation: pause, nested settings, the contextual tip, and
# return to the world.
extends GdUnitE2ETestSuite

const WORLD := "/root/AppRoot/World"
const GAME_HUD := WORLD + "/GameHud"
const HUD := GAME_HUD + "/HudRoot"
const ONBOARDING := HUD + "/OnboardingOverlay"
const ONBOARDING_OPENING := ONBOARDING + "/OpeningPanel"
const TUTORIAL := ONBOARDING + "/TutorialCard"
const BAG := HUD + "/BagPanel"
const PLAYER := WORLD + "/%Player"

# Settings path of the last launch, for the Music persistence check below.
var _settings_path := ""

func _tap_key(game: Variant, keycode: Key, physical := true) -> void:
	assert_bool(await game.input_key(keycode, true, physical)).is_true()
	assert_bool(await game.input_key(keycode, false, physical)).is_true()

func _focus_owner_label(game: Variant) -> String:
	var owner: Variant = await game.call_method("/root", "gui_get_focus_owner")
	if owner == null:
		return ""
	if owner is Dictionary:
		return String(owner.get("_str", "focus"))
	return str(owner)

# One isolated new game, prologue skipped, on the farm world.
func _launch_new_game() -> Variant:
	var options := E2ELaunchOptions.new()
	options.scene_path = "res://scenes/app/app.tscn"
	var save_path := create_temp_dir("phoenix-task9-save") + "/save.json"
	_settings_path = create_temp_dir("phoenix-task9-settings") + "/settings.cfg"
	var settings := ConfigFile.new()
	settings.set_value("ui", "fullscreen", false)
	assert_int(settings.save(_settings_path)).is_equal(OK)
	OS.set_environment("PHOENIX_SAVE_PATH", save_path)
	OS.set_environment("PHOENIX_SETTINGS_PATH", _settings_path)
	var game := await launch_game(options)
	OS.unset_environment("PHOENIX_SAVE_PATH")
	OS.unset_environment("PHOENIX_SETTINGS_PATH")
	if game == null or is_failure():
		return null

	assert_bool(await game.click_node("/root/AppRoot/TitleScreen/Menu/NewGame")).is_true()
	assert_bool(await game.wait_for_node(WORLD, 10.0)).is_true()
	# Esc skips the visible prologue through a real key, not ui_cancel injection.
	assert_bool(
		await game.wait_for_property(ONBOARDING_OPENING, "visible", true, 5.0)
	).is_true()
	await _tap_key(game, KEY_ESCAPE, false)
	assert_bool(
		await game.wait_for_property(ONBOARDING_OPENING, "visible", false, 5.0)
	).is_true()
	# The clock test seam keeps snapshot comparisons free of passive ticks.
	assert_bool(await game.set_property(WORLD, "clock_running", false)).is_true()
	return game

func test_real_keys_navigate_pause_and_settings() -> void:
	var game: Variant = await _launch_new_game()
	if game == null or is_failure():
		return

	# Physical Tab dismisses the visible contextual tip and nothing else: the
	# world gate, focus, player, and the whole gameplay snapshot stay put.
	assert_bool(await game.wait_for_property(TUTORIAL, "visible", true, 5.0)).is_true()
	assert_str(await game.get_property(ONBOARDING, "_current_prompt_id")).is_equal(
		"farm_basics"
	)
	assert_array(await game.get_property(ONBOARDING, "_dismissed")).is_empty()
	assert_bool(await game.get_property(WORLD, "_world_input_enabled")).is_true()
	var snapshot_before: Dictionary = await game.get_property(GAME_HUD, "_last_snapshot")
	var focus_before := await _focus_owner_label(game)
	var player_before: Vector2 = await game.get_property(PLAYER, "global_position")

	await _tap_key(game, KEY_TAB)

	assert_bool(await game.wait_for_property(TUTORIAL, "visible", false, 5.0)).is_true()
	assert_str(await game.get_property(ONBOARDING, "_current_prompt_id")).is_equal("")
	assert_array(await game.get_property(ONBOARDING, "_dismissed")).is_equal(
		["farm_basics"]
	)
	assert_bool(await game.get_property(WORLD, "_world_input_enabled")).is_true()
	assert_str(await _focus_owner_label(game)).is_equal(focus_before)
	assert_dict(await game.get_property(GAME_HUD, "_last_snapshot")).is_equal(
		snapshot_before
	)
	assert_vector(await game.get_property(PLAYER, "global_position")).is_equal_approx(
		player_before, Vector2(0.01, 0.01)
	)

	await _tap_key(game, KEY_ESCAPE, false)
	assert_bool(await game.wait_for_property(HUD + "/PausePanel", "visible", true, 5.0)).is_true()

	await _tap_key(game, KEY_O)
	assert_bool(await game.wait_for_property(HUD + "/SettingsPanel", "visible", true, 5.0)).is_true()
	assert_bool(await game.get_property(HUD + "/PausePanel", "visible")).is_false()

	await _tap_key(game, KEY_D)
	var saved_settings := ConfigFile.new()
	assert_int(saved_settings.load(_settings_path)).is_equal(OK)
	assert_int(int(saved_settings.get_value("ui", "music"))).is_equal(UiSettings.DEFAULT_MUSIC + 1)

	await _tap_key(game, KEY_ESCAPE, false)
	assert_bool(await game.wait_for_property(HUD + "/SettingsPanel", "visible", false, 5.0)).is_true()
	assert_bool(await game.get_property(HUD + "/PausePanel", "visible")).is_true()

	await _tap_key(game, KEY_ESCAPE, false)
	assert_bool(await game.wait_for_property(HUD + "/PausePanel", "visible", false, 5.0)).is_true()

# A fresh eligible tip stays visible over an ordinary phone menu, and a real
# physical Tab dismisses only the tip there: the open menu, the world gate, the
# player, and the session snapshot are untouched, and closing/reopening the menu
# never resurrects the dismissed prompt. Bag has no focusable control, so the
# focus-order proof that Tab is consumed lives in test_gameplay_shell.
func test_real_keys_dismiss_a_fresh_tip_inside_bag_menu() -> void:
	var game: Variant = await _launch_new_game()
	if game == null or is_failure():
		return

	assert_bool(await game.wait_for_property(TUTORIAL, "visible", true, 5.0)).is_true()
	assert_str(await game.get_property(ONBOARDING, "_current_prompt_id")).is_equal(
		"farm_basics"
	)
	assert_array(await game.get_property(ONBOARDING, "_dismissed")).is_empty()

	# Bag is an ordinary phone menu: it keeps the undismissed tip visible and
	# still gates the world.
	await _tap_key(game, KEY_I)
	assert_bool(await game.wait_for_property(BAG, "visible", true, 5.0)).is_true()
	assert_bool(await game.get_property(TUTORIAL, "visible")).is_true()
	assert_str(await game.get_property(ONBOARDING, "_current_prompt_id")).is_equal(
		"farm_basics"
	)
	assert_bool(await game.get_property(WORLD, "_world_input_enabled")).is_false()

	var snapshot_before: Dictionary = await game.get_property(GAME_HUD, "_last_snapshot")
	var focus_before := await _focus_owner_label(game)
	var player_before: Vector2 = await game.get_property(PLAYER, "global_position")

	await _tap_key(game, KEY_TAB)

	assert_bool(await game.wait_for_property(TUTORIAL, "visible", false, 5.0)).is_true()
	assert_str(await game.get_property(ONBOARDING, "_current_prompt_id")).is_equal("")
	assert_array(await game.get_property(ONBOARDING, "_dismissed")).is_equal(
		["farm_basics"]
	)
	assert_bool(await game.get_property(BAG, "visible")).is_true()
	assert_bool(await game.get_property(WORLD, "_world_input_enabled")).is_false()
	assert_str(await _focus_owner_label(game)).is_equal(focus_before)
	assert_dict(await game.get_property(GAME_HUD, "_last_snapshot")).is_equal(
		snapshot_before
	)
	assert_vector(await game.get_property(PLAYER, "global_position")).is_equal_approx(
		player_before, Vector2(0.01, 0.01)
	)

	# Close and reopen the menu: the dismissed prompt stays gone.
	await _tap_key(game, KEY_I)
	assert_bool(await game.wait_for_property(BAG, "visible", false, 5.0)).is_true()
	assert_bool(await game.get_property(TUTORIAL, "visible")).is_false()
	await _tap_key(game, KEY_I)
	assert_bool(await game.wait_for_property(BAG, "visible", true, 5.0)).is_true()
	assert_bool(await game.get_property(TUTORIAL, "visible")).is_false()
	assert_array(await game.get_property(ONBOARDING, "_dismissed")).is_equal(
		["farm_basics"]
	)
	await _tap_key(game, KEY_I)
	assert_bool(await game.wait_for_property(BAG, "visible", false, 5.0)).is_true()
