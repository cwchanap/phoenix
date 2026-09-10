# Real e2e gameplay: drive the live app through onboarding, a full Day 1
# farm loop, the shop, and real keyboard movement. The player is positioned
# remotely (grid -> projected pixels) so each command targets a known cell.
extends GdUnitE2ETestSuite

const WORLD := "/root/AppRoot/World"
const HUD := WORLD + "/GameHud/HudRoot"
const PLAYER := WORLD + "/Entities/Player"
const UP := WorldMath.Facing.UP
const RIGHT := WorldMath.Facing.RIGHT

# The redesigned HUD renders stamina as 20 pips under TopBar: a pip is lit
# (green, g≈0.75) when its index < stamina and dark (g≈0.19) otherwise.
# 0.5 cleanly separates the two states.
const STAMINA_LIT_THRESHOLD := 0.5

# Save path the child is told to write via PHOENIX_SAVE_PATH. Kept so the
# sleep test can assert the file actually exists, pinning the isolation
# seam in CI rather than relying on a one-off mtime check.
var _save_path := ""


func _start_new_game() -> Variant:
	var options := E2ELaunchOptions.new()
	options.scene_path = "res://scenes/app/app.tscn"
	# AppRoot reads PHOENIX_SAVE_PATH: point the child's overnight save at the
	# suite temp dir (user://tmp) instead of the developer's real save. The
	# child inherits this env at spawn, so unsetting after launch is safe.
	_save_path = create_temp_dir("phoenix-save-e2e") + "/save.json"
	# gdUnit's click_node coordinates are logical viewport coordinates. Keep
	# this fixture at 1x so the selector reaches the 640x360 production view;
	# the shipped default remains 2x.
	var settings_path := create_temp_dir("phoenix-settings-e2e") + "/settings.cfg"
	var settings := ConfigFile.new()
	settings.set_value("ui", "window_scale", 1)
	assert_int(settings.save(settings_path)).is_equal(OK)
	OS.set_environment("PHOENIX_SAVE_PATH", _save_path)
	OS.set_environment("PHOENIX_SETTINGS_PATH", settings_path)
	var game := await launch_game(options)
	OS.unset_environment("PHOENIX_SAVE_PATH")
	OS.unset_environment("PHOENIX_SETTINGS_PATH")
	if game == null or is_failure():
		return null
	assert_bool(
		await game.click_node("/root/AppRoot/TitleScreen/Panel/NewGame")
	).is_true()
	assert_bool(await game.input_action("ui_accept", true)).is_true()
	assert_bool(await game.input_action("ui_accept", false)).is_true()
	assert_bool(await game.wait_for_property(HUD + "/TopBar/DayValue", "text", "1", 10.0)).is_true()
	return game


# The redesigned HUD shows stamina as 20 lit/dark pips rather than a text
# label. Verify the pip at index (expected-1) is lit and, when expected < 20,
# the pip at index expected is dark.
func _assert_stamina(game, expected: int) -> void:
	var lit: Color = await game.get_property(
		HUD + "/TopBar/StaminaPip_%02d" % (expected - 1), "color"
	)
	assert_float(lit.g).is_greater(STAMINA_LIT_THRESHOLD)
	if expected < 20:
		var dark: Color = await game.get_property(
			HUD + "/TopBar/StaminaPip_%02d" % expected, "color"
		)
		assert_float(dark.g).is_less(STAMINA_LIT_THRESHOLD)


# Stand at a grid position with a facing so current_target_cell() resolves
# to the cell we want (facing UP targets floor(pos) + (-1, -1)).
func _stand(game, grid: Vector2, facing: int) -> void:
	assert_bool(
		await game.set_property(PLAYER, "global_position", WorldMath.grid_to_world(grid))
	).is_true()
	assert_bool(await game.set_property(PLAYER, "facing", facing)).is_true()


# Stand one cell off a WorldContract target opposite its facing offset (the
# same derivation as the integration suite's _place_target) so the target
# resolves to the contract cell. No literal stand positions.
func _stand_at_target(game, target: Vector2i, facing: int) -> void:
	var offset: Vector2i = WorldMath.TARGET_OFFSETS[facing]
	await _stand(game, Vector2(target - offset) + Vector2(0.5, 0.5), facing)
	assert_that(await game.call_method(PLAYER, "current_target_cell")).is_equal(target)


func _use_action(game, button: String, feedback: String) -> void:
	assert_bool(await game.click_node(HUD + "/" + button)).is_true()
	# use_selected_action returns void; transport errors surface via is_failure().
	await game.call_method(WORLD, "use_selected_action")
	if is_failure():
		return
	assert_bool(
		await game.wait_for_property(HUD + "/Feedback", "text", feedback, 5.0)
	).is_true()


func test_day_one_farming_loop_and_sleep() -> void:
	var game = await _start_new_game()
	if game == null or is_failure():
		return

	# Hoe, plant, and water a farm cell well outside the old 3x3 patch, from
	# its south-east. The farm view pre-creates all crop sprites hidden, so
	# visibility is the observable.
	var farm_cell: Vector2i = WorldContract.FARM_PATCH.position + Vector2i(4, 3)
	var soil_path := WORLD + "/FarmSoil/Soil_%d_%d" % [farm_cell.x, farm_cell.y]
	var crop_path := WORLD + "/Entities/FarmCrop_%d_%d" % [farm_cell.x, farm_cell.y]
	await _stand_at_target(game, farm_cell, UP)
	assert_bool(await game.get_property(soil_path, "visible")).is_false()
	await _use_action(game, "Action_0", "Soil tilled.")
	assert_bool(await game.get_property(soil_path, "visible")).is_true()
	assert_bool(
		await game.get_property(crop_path + "/Sprite2D", "visible")
	).is_false()
	await _use_action(game, "Action_1", "Crop planted.")
	assert_bool(
		await game.get_property(crop_path + "/Sprite2D", "visible")
	).is_true()
	await _use_action(game, "Action_2", "Crop watered.")
	if is_failure():
		return
	await _assert_stamina(game, 14)

	# Walk-free trip to the contract bed cell: interact, confirm, acknowledge.
	await _stand_at_target(game, WorldContract.BED_CELL, UP)
	await game.call_method(WORLD, "interact")
	if is_failure():
		return
	assert_bool(
		await game.wait_for_property(HUD + "/SleepPanel", "visible", true, 5.0)
	).is_true()
	assert_bool(await game.click_node(HUD + "/SleepPanel/Confirm")).is_true()
	assert_bool(await game.wait_for_property(HUD + "/TopBar/DayValue", "text", "2", 10.0)).is_true()
	assert_bool(
		await game.wait_for_property(HUD + "/MorningSummaryPanel", "visible", true, 5.0)
	).is_true()
	# The overnight save landed (status resets once the summary is dismissed).
	assert_str(
		await game.get_property(HUD + "/MorningSummaryPanel/SaveStatus", "text")
	).is_equal("Saved.")
	# Pin the save-isolation seam: the child must have written the file at the
	# PHOENIX_SAVE_PATH we set, not the developer's real user://phoenix-save.json.
	# Parent and child share the same user:// root (same project), so this sees
	# the child's write. If AppRoot stops honoring the env override, this fails.
	assert_bool(FileAccess.file_exists(_save_path)).is_true()
	assert_bool(
		await game.click_node(HUD + "/MorningSummaryPanel/Acknowledge")
	).is_true()
	assert_bool(
		await game.wait_for_property(HUD + "/MorningSummaryPanel", "visible", false, 5.0)
	).is_true()
	await _assert_stamina(game, 20)


func test_player_moves_with_real_input() -> void:
	var game = await _start_new_game()
	if game == null or is_failure():
		return

	var start_x: float = (await game.get_property(PLAYER, "global_position"))["x"]
	assert_bool(await game.input_action("move_left", true)).is_true()
	assert_bool(await game.wait_seconds(0.6)).is_true()
	assert_bool(await game.input_action("move_left", false)).is_true()
	var end_x: float = (await game.get_property(PLAYER, "global_position"))["x"]
	assert_float(end_x).is_less(start_x - 30.0)


func test_shop_purchase_updates_money() -> void:
	var game = await _start_new_game()
	if game == null or is_failure():
		return

	# Target the contract shop cell from its south-west with facing RIGHT.
	await _stand_at_target(game, WorldContract.SHOP_CELL, RIGHT)
	await game.call_method(WORLD, "interact")
	if is_failure():
		return
	assert_bool(
		await game.wait_for_property(HUD + "/ShopPanel", "visible", true, 5.0)
	).is_true()

	# The selected Turnip row defaults to one seed; Enter uses the real panel
	# request path and costs 20.
	assert_bool(await game.input_action("ui_accept", true)).is_true()
	assert_bool(await game.input_action("ui_accept", false)).is_true()
	assert_bool(
		await game.wait_for_property(HUD + "/TopBar/MoneyValue", "text", "130", 5.0)
	).is_true()
	assert_bool(await game.input_action("ui_cancel", true)).is_true()
	assert_bool(await game.input_action("ui_cancel", false)).is_true()
	assert_bool(
		await game.wait_for_property(HUD + "/ShopPanel", "visible", false, 5.0)
	).is_true()
