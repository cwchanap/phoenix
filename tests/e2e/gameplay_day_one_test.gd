# Real e2e gameplay: drive the live app through onboarding, a full Day 1
# farm loop, the shop, and real keyboard movement. The player is positioned
# remotely (grid -> projected pixels) so each command targets a known cell.
extends GdUnitE2ETestSuite

const WORLD := "/root/AppRoot/World"
const HUD := WORLD + "/GameHud/HudRoot"
const PLAYER := WORLD + "/Entities/Player"
const UP := WorldMath.Facing.UP
const RIGHT := WorldMath.Facing.RIGHT


func _start_new_game() -> Variant:
	var options := E2ELaunchOptions.new()
	options.scene_path = "res://scenes/app/app.tscn"
	# AppRoot reads PHOENIX_SAVE_PATH: point the child's overnight save at the
	# suite temp dir (user://tmp) instead of the developer's real save. The
	# child inherits this env at spawn, so unsetting after launch is safe.
	OS.set_environment("PHOENIX_SAVE_PATH", create_temp_dir("phoenix-save-e2e") + "/save.json")
	var game := await launch_game(options)
	OS.unset_environment("PHOENIX_SAVE_PATH")
	if game == null or is_failure():
		return null
	assert_bool(
		await game.click_node("/root/AppRoot/TitleScreen/Panel/NewGame")
	).is_true()
	assert_bool(
		await game.click_node(HUD + "/OnboardingOverlay/OpeningPanel/Start")
	).is_true()
	assert_bool(await game.wait_for_property(HUD + "/Day", "text", "Day 1", 10.0)).is_true()
	return game


# Stand at a grid position with a facing so current_target_cell() resolves
# to the cell we want (facing UP targets floor(pos) + (-1, -1)).
func _stand(game, grid: Vector2, facing: int) -> void:
	assert_bool(
		await game.set_property(PLAYER, "global_position", WorldMath.grid_to_world(grid))
	).is_true()
	assert_bool(await game.set_property(PLAYER, "facing", facing)).is_true()


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

	# Hoe, plant, and water farm cell (3, 8) from below. The farm view
	# pre-creates all crop sprites hidden, so visibility is the observable.
	await _stand(game, Vector2(4.5, 9.5), UP)
	assert_bool(
		await game.get_property(WORLD + "/FarmSoil/Soil_3_8", "visible")
	).is_false()
	await _use_action(game, "Action_0", "Soil tilled.")
	assert_bool(
		await game.get_property(WORLD + "/FarmSoil/Soil_3_8", "visible")
	).is_true()
	assert_bool(
		await game.get_property(WORLD + "/Entities/FarmCrop_3_8/Sprite2D", "visible")
	).is_false()
	await _use_action(game, "Action_1", "Crop planted.")
	assert_bool(
		await game.get_property(WORLD + "/Entities/FarmCrop_3_8/Sprite2D", "visible")
	).is_true()
	await _use_action(game, "Action_2", "Crop watered.")
	if is_failure():
		return
	assert_str(await game.get_property(HUD + "/Stamina", "text")).is_equal("Stamina: 14/20")

	# Walk-free trip to the bed: interact, confirm, acknowledge Day 2.
	await _stand(game, Vector2(7.5, 9.5), UP)
	await game.call_method(WORLD, "interact")
	if is_failure():
		return
	assert_bool(
		await game.wait_for_property(HUD + "/SleepPanel", "visible", true, 5.0)
	).is_true()
	assert_bool(await game.click_node(HUD + "/SleepPanel/Confirm")).is_true()
	assert_bool(await game.wait_for_property(HUD + "/Day", "text", "Day 2", 10.0)).is_true()
	assert_bool(
		await game.wait_for_property(HUD + "/MorningSummaryPanel", "visible", true, 5.0)
	).is_true()
	# The overnight save landed (status resets once the summary is dismissed).
	assert_str(
		await game.get_property(HUD + "/MorningSummaryPanel/SaveStatus", "text")
	).is_equal("Saved.")
	assert_bool(
		await game.click_node(HUD + "/MorningSummaryPanel/Acknowledge")
	).is_true()
	assert_bool(
		await game.wait_for_property(HUD + "/MorningSummaryPanel", "visible", false, 5.0)
	).is_true()
	assert_str(await game.get_property(HUD + "/Stamina", "text")).is_equal("Stamina: 20/20")


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

	# Target the shop cell (6, 7) from the left with facing RIGHT.
	await _stand(game, Vector2(5.5, 8.5), RIGHT)
	await game.call_method(WORLD, "interact")
	if is_failure():
		return
	assert_bool(
		await game.wait_for_property(HUD + "/ShopPanel", "visible", true, 5.0)
	).is_true()

	# Row_0 quantity SpinBox defaults to 1: one turnip seed costs 20.
	assert_bool(await game.click_node(HUD + "/ShopPanel/Row_0/Buy")).is_true()
	assert_bool(
		await game.wait_for_property(HUD + "/Money", "text", "Money: 130G", 5.0)
	).is_true()
	assert_bool(await game.click_node(HUD + "/ShopPanel/Close")).is_true()
	assert_bool(
		await game.wait_for_property(HUD + "/ShopPanel", "visible", false, 5.0)
	).is_true()
