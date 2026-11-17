extends GdUnitE2ETestSuite

const WORLD := "/root/AppRoot/World"
const GAME_HUD := WORLD + "/GameHud"
const HUD := GAME_HUD + "/HudRoot"
const MARKET_PANEL := HUD + "/MarketConfirmPanel"
const PLAYER := WORLD + "/%Player"
const RESULT := "/root/AppRoot/ResultScreen"
const RIGHT := WorldMath.Facing.RIGHT
const DOWN := WorldMath.Facing.DOWN

var _save_path := ""

func _seed_day14_save(path: String) -> void:
	var session := GameSession.new(func() -> float: return 0.9)
	var seeded := session.state()
	seeded["day"] = GameRules.MAX_DAY
	seeded["weather_history"] = []
	for _day in GameRules.MAX_DAY:
		seeded["weather_history"].append(&"sunny")
	seeded["intro_acknowledged"] = true
	assert_str(SessionStateValidator.state_error(seeded)).is_empty()
	assert_bool(session.restore_state(seeded)).is_true()
	assert_int(SaveRepository.new(path).save(session.state())).is_equal(OK)

func _stand_at_target(game, target: Vector2i, facing: int) -> void:
	var offset: Vector2i = WorldMath.TARGET_OFFSETS[facing]
	var grid := Vector2(target - offset) + Vector2(0.5, 0.5)
	assert_bool(
		await game.set_property(
			PLAYER, "global_position", WorldMath.grid_to_world(grid)
		)
	).is_true()
	assert_bool(await game.set_property(PLAYER, "facing", facing)).is_true()
	assert_that(
		await game.call_method(PLAYER, "current_target_cell")
	).is_equal(target)

func _tap_key(game, keycode: Key, physical := true) -> void:
	assert_bool(await game.input_key(keycode, true, physical)).is_true()
	assert_bool(await game.input_key(keycode, false, physical)).is_true()

func test_day14_market_cancel_then_confirm_finale() -> void:
	var options := E2ELaunchOptions.new()
	options.scene_path = "res://scenes/app/app.tscn"
	_save_path = create_temp_dir("phoenix-save-e2e") + "/save.json"
	_seed_day14_save(_save_path)
	var settings_path := create_temp_dir("phoenix-settings-e2e") + "/settings.cfg"
	var settings := ConfigFile.new()
	settings.set_value("ui", "fullscreen", false)
	settings.set_value("ui", "language", "en")
	assert_int(settings.save(settings_path)).is_equal(OK)
	OS.set_environment("PHOENIX_SAVE_PATH", _save_path)
	OS.set_environment("PHOENIX_SETTINGS_PATH", settings_path)
	var game := await launch_game(options)
	OS.unset_environment("PHOENIX_SAVE_PATH")
	OS.unset_environment("PHOENIX_SETTINGS_PATH")
	if game == null or is_failure():
		return

	assert_bool(await game.click_node("/root/AppRoot/TitleScreen/Menu/Continue")).is_true()
	assert_bool(await game.wait_for_node(WORLD, 10.0)).is_true()
	assert_bool(await game.set_property(WORLD, "clock_running", false)).is_true()

	await _stand_at_target(game, WorldContract.TRUCK_CELL, RIGHT)
	await _tap_key(game, KEY_E)
	assert_bool(await game.wait_for_node(WORLD + "/TownMap", 5.0)).is_true()

	await _stand_at_target(game, TownContract.MARKET_CELL, DOWN)
	await _tap_key(game, KEY_E)
	assert_bool(
		await game.wait_for_property(MARKET_PANEL, "visible", true, 5.0)
	).is_true()
	var seeded_reread := SaveRepository.new(_save_path).load()
	assert_bool(bool(seeded_reread["state"]["finale_triggered"])).is_false()

	await _tap_key(game, KEY_ESCAPE, false)
	assert_bool(
		await game.wait_for_property(MARKET_PANEL, "visible", false, 5.0)
	).is_true()
	assert_bool(await game.get_property(WORLD, "_world_input_enabled")).is_true()
	assert_that(SaveRepository.new(_save_path).load()).is_equal(seeded_reread)

	await _tap_key(game, KEY_E)
	assert_bool(
		await game.wait_for_property(MARKET_PANEL, "visible", true, 5.0)
	).is_true()
	await _tap_key(game, KEY_ENTER, false)
	assert_bool(
		await game.wait_for_property(RESULT, "visible", true, 15.0)
	).is_true()
	var final_save := SaveRepository.new(_save_path).load()
	assert_bool(bool(final_save["state"]["finale_triggered"])).is_true()
