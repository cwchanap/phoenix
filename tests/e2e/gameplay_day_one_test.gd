# Real e2e gameplay: drive the live app through onboarding, a full Day 1
# farm loop, the shop, and real keyboard movement. The player is positioned
# remotely (grid -> projected pixels) so each command targets a known cell.
extends GdUnitE2ETestSuite

const WORLD := "/root/AppRoot/World"
const GAME_HUD := WORLD + "/GameHud"
const HUD := GAME_HUD + "/HudRoot"
const CHROME := HUD + "/Chrome"
const DAY := CHROME + "/ClockCard/Surface/Body/Row/Meta/DayTag/DayRow/Day"
const STAMINA := CHROME + "/Stamina/Row/Numbers/Value"
const PLAYER := WORLD + "/%Player"
const UP := WorldMath.Facing.UP
const RIGHT := WorldMath.Facing.RIGHT
const LEFT := WorldMath.Facing.LEFT

# Save path the child is told to write via PHOENIX_SAVE_PATH. Kept so the
# sleep test can assert the file actually exists, pinning the isolation
# seam in CI rather than relying on a one-off mtime check.
var _save_path := ""


func _start_new_game() -> Variant:
	var options := E2ELaunchOptions.new()
	options.scene_path = "res://scenes/app/app.tscn"
	var fps := OS.get_environment("PHOENIX_E2E_FIXED_FPS")
	if fps != "":
		options.extra_godot_args = PackedStringArray(["--fixed-fps", fps])
	# AppRoot reads PHOENIX_SAVE_PATH: point the child's overnight save at the
	# suite temp dir (user://tmp) instead of the developer's real save. The
	# child inherits this env at spawn, so unsetting after launch is safe.
	_save_path = create_temp_dir("phoenix-save-e2e") + "/save.json"
	# gdUnit's click_node coordinates are logical viewport coordinates. Keep
	# this fixture windowed so the 1920x1080 window matches the base viewport
	# 1:1 (CI's xvfb screen is 1920x1080, so the window never shrinks).
	var settings_path := create_temp_dir("phoenix-settings-e2e") + "/settings.cfg"
	var settings := ConfigFile.new()
	settings.set_value("ui", "fullscreen", false)
	# The HUD asserts English copy ("Day 1"); pin the language so a ja or
	# zh_TW OS locale does not pick a translation.
	settings.set_value("ui", "language", "en")
	assert_int(settings.save(settings_path)).is_equal(OK)
	OS.set_environment("PHOENIX_SAVE_PATH", _save_path)
	OS.set_environment("PHOENIX_SETTINGS_PATH", settings_path)
	var game := await launch_game(options)
	OS.unset_environment("PHOENIX_SAVE_PATH")
	OS.unset_environment("PHOENIX_SETTINGS_PATH")
	if game == null or is_failure():
		return null
	assert_bool(
		await game.click_node("/root/AppRoot/TitleScreen/Menu/NewGame")
	).is_true()
	assert_bool(await game.input_action("ui_accept", true)).is_true()
	assert_bool(await game.input_action("ui_accept", false)).is_true()
	assert_bool(await game.wait_for_property(DAY, "text", "Day 1", 10.0)).is_true()
	return game


# The stamina pill shows "N / 20"; its Value label carries N.
func _assert_stamina(game, expected: int) -> void:
	assert_bool(
		await game.wait_for_property(STAMINA, "text", "%d" % expected, 5.0)
	).is_true()


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


func _soil_path(cell: Vector2i) -> String:
	return WORLD + "/FarmMap/FarmSoil/Soil_%d_%d" % [cell.x, cell.y]


func _crop_path(cell: Vector2i) -> String:
	return WORLD + "/FarmMap/Entities/FarmCrop_%d_%d" % [cell.x, cell.y]


func _tap_key(game, keycode: Key, physical := true) -> void:
	assert_bool(await game.input_key(keycode, true, physical)).is_true()
	assert_bool(await game.input_key(keycode, false, physical)).is_true()


# Successes raise no HUD text (only refusals toast), so each caller asserts
# the world change itself; a refusal toast here means the action failed.
# Transport errors surface via is_failure().
func _use_action(game) -> void:
	await _tap_key(game, KEY_SPACE)
	if is_failure():
		return
	assert_str(await game.call_method(GAME_HUD, "toast_text")).is_equal("")


func _wait_for_call_value(game, path: String, method: String, expected: Variant, timeout := 5.0) -> Variant:
	var deadline_msec := Time.get_ticks_msec() + int(timeout * 1000.0)
	var value: Variant = await game.call_method(path, method)
	while value != expected and Time.get_ticks_msec() < deadline_msec:
		await game.wait_seconds(0.1)
		value = await game.call_method(path, method)
	return value


func _wait_travel_release(game) -> void:
	assert_bool(
		await _wait_for_call_value(game, GAME_HUD, "has_blocking_modal", false, 10.0)
	).is_false()


func test_day_one_town_trip_farming_loop_and_sleep() -> void:
	var game = await _start_new_game()
	if game == null or is_failure():
		return

	assert_bool(await game.set_property(WORLD, "clock_running", false)).is_true()
	var clock_path := CHROME + "/ClockCard/Surface/Body/Row/Clock"
	var start_clock: String = await game.get_property(clock_path, "text")
	var start_parts := start_clock.split(":")
	var expected_clock := GameRules.format_time(
		start_parts[0].to_int() * 60 + start_parts[1].to_int() + 200
	)

	await _stand_at_target(game, WorldContract.TRUCK_CELL, RIGHT)
	assert_str(await game.call_method(GAME_HUD, "prompt_text")).is_equal(
		"[E] Drive to town"
	)
	await _tap_key(game, KEY_E)
	assert_bool(await game.wait_for_node(WORLD + "/TownMap", 5.0)).is_true()
	await _wait_travel_release(game)

	await _stand_at_target(game, TownContract.SHOP_CELL, RIGHT)
	await _tap_key(game, KEY_E)
	if is_failure():
		return
	assert_bool(
		await game.wait_for_property(HUD + "/ShopPanel", "visible", true, 5.0)
	).is_true()
	assert_bool(await game.input_action("ui_accept", true)).is_true()
	assert_bool(await game.input_action("ui_accept", false)).is_true()
	assert_bool(
		await game.wait_for_property(
			CHROME + "/TopRight/Money/Row/Value", "text", "130G", 5.0
		)
	).is_true()
	assert_bool(await game.input_action("ui_cancel", true)).is_true()
	assert_bool(await game.input_action("ui_cancel", false)).is_true()
	assert_bool(
		await game.wait_for_property(HUD + "/ShopPanel", "visible", false, 5.0)
	).is_true()

	await _stand_at_target(game, TownContract.TRUCK_CELL, LEFT)
	assert_str(await game.call_method(GAME_HUD, "prompt_text")).is_equal(
		"[E] Drive home"
	)
	await _tap_key(game, KEY_E)
	assert_bool(await game.wait_for_node(WORLD + "/FarmMap", 5.0)).is_true()
	await _wait_travel_release(game)

	# Hoe, plant, and water a farm cell well outside the old 3x3 patch, from
	# its south-east. The farm view pre-creates all crop sprites hidden, so
	# visibility is the observable.
	var farm_cell: Vector2i = WorldContract.FARM_PATCH.position + Vector2i(4, 3)
	var soil_path := _soil_path(farm_cell)
	var crop_path := _crop_path(farm_cell)
	await _stand_at_target(game, farm_cell, UP)
	assert_bool(await game.get_property(soil_path, "visible")).is_false()
	await _use_action(game)
	assert_bool(await game.wait_for_property(soil_path, "visible", true, 5.0)).is_true()
	assert_bool(
		await game.get_property(crop_path + "/Sprite2D", "visible")
	).is_false()
	await _use_action(game)
	assert_bool(
		await game.wait_for_property(crop_path + "/Sprite2D", "visible", true, 5.0)
	).is_true()
	await _use_action(game)
	if is_failure():
		return
	assert_int(int(await game.get_property(soil_path, "frame"))).is_equal(1)
	await _assert_stamina(game, 14)

	var bought_cell: Vector2i = WorldContract.FARM_PATCH.position + Vector2i(2, 3)
	var bought_soil := _soil_path(bought_cell)
	var bought_crop := _crop_path(bought_cell)
	await _stand_at_target(game, bought_cell, UP)
	await _use_action(game)
	assert_bool(
		await game.wait_for_property(bought_soil, "visible", true, 5.0)
	).is_true()
	await _use_action(game)
	assert_bool(
		await game.wait_for_property(bought_crop + "/Sprite2D", "visible", true, 5.0)
	).is_true()
	await _use_action(game)
	if is_failure():
		return
	assert_int(int(await game.get_property(bought_soil, "frame"))).is_equal(1)
	assert_str(
		await game.get_property(CHROME + "/SeedCard/Row/Tile/Badge/Count", "text")
	).is_equal("×2")
	await _assert_stamina(game, 8)
	assert_bool(
		await game.wait_for_property(clock_path, "text", expected_clock, 5.0)
	).is_true()

	# Walk-free trip to the contract bed cell: interact, confirm, acknowledge.
	await _stand_at_target(game, WorldContract.BED_CELL, UP)
	await _tap_key(game, KEY_E)
	if is_failure():
		return
	assert_bool(
		await game.wait_for_property(HUD + "/SleepPanel", "visible", true, 5.0)
	).is_true()
	assert_bool(await game.click_node(
		HUD + "/SleepPanel/Center/PhoneFrame/Screen/Column/BottomBar/Rows/Footer/Row/Actions/Confirm"
	)).is_true()
	assert_bool(await game.wait_for_property(DAY, "text", "Day 2", 10.0)).is_true()
	assert_bool(
		await game.wait_for_property(HUD + "/MorningSummaryPanel", "visible", true, 5.0)
	).is_true()
	# The overnight save landed (status resets once the summary is dismissed).
	assert_str(
		await game.call_method(HUD + "/MorningSummaryPanel", "save_status_text")
	).is_equal("Saved.")
	# Pin the save-isolation seam: the child must have written the file at the
	# PHOENIX_SAVE_PATH we set, not the developer's real user://phoenix-save.json.
	# Parent and child share the same user:// root (same project), so this sees
	# the child's write. If AppRoot stops honoring the env override, this fails.
	assert_bool(FileAccess.file_exists(_save_path)).is_true()
	assert_bool(await game.click_node(
		HUD + "/MorningSummaryPanel/Center/PhoneFrame/Screen/Column/BottomBar/Rows/Footer/Row/Actions/Acknowledge"
	)).is_true()
	assert_bool(
		await game.wait_for_property(HUD + "/MorningSummaryPanel", "visible", false, 5.0)
	).is_true()
	await _assert_stamina(game, 20)


# Critical held-row flow: each real held gesture works one stage across a
# three-cell row. Stamina math:
# 3 x (3 + 1 + 2) = 18 of 20; all three starter seeds are spent.
func test_day_one_held_row_works_three_cells() -> void:
	var game = await _start_new_game()
	if game == null or is_failure():
		return

	var origin: Vector2i = WorldContract.FARM_PATCH.position
	var cells: Array[Vector2i] = [
		origin, origin + Vector2i(1, 0), origin + Vector2i(2, 0),
	]
	var tail: Array[Vector2i] = [cells[1], cells[2]]
	# Generous multiple of the dwell: CI/xvfb jitter margin, not gameplay timing.
	var hold_wait := WorldShell.ACTION_HOLD_DWELL_SECONDS * 4.0

	# The first target applies on the press itself; this gesture stays Hoe-locked.
	await _stand_at_target(game, cells[0], UP)
	assert_bool(await game.input_action("use_action", true)).is_true()
	assert_bool(
		await game.wait_for_property(_soil_path(cells[0]), "visible", true, 5.0)
	).is_true()
	for cell in tail:
		await _stand_at_target(game, cell, UP)
		assert_bool(await game.wait_seconds(hold_wait)).is_true()
		assert_bool(await game.get_property(_soil_path(cell), "visible")).is_true()
		assert_bool(
			await game.get_property(_crop_path(cell) + "/Sprite2D", "visible")
		).is_false()
	for cell in cells:
		assert_bool(
			await game.get_property(_crop_path(cell) + "/Sprite2D", "visible")
		).is_false()
	assert_bool(await game.input_action("use_action", false)).is_true()
	if is_failure():
		return

	# A fresh gesture plants the row.
	await _stand_at_target(game, cells[0], UP)
	assert_bool(await game.input_action("use_action", true)).is_true()
	assert_bool(
		await game.wait_for_property(
			_crop_path(cells[0]) + "/Sprite2D", "visible", true, 5.0
		)
	).is_true()
	for cell in tail:
		await _stand_at_target(game, cell, UP)
		assert_bool(await game.wait_seconds(hold_wait)).is_true()
		assert_bool(
			await game.get_property(_crop_path(cell) + "/Sprite2D", "visible")
		).is_true()
	assert_bool(await game.input_action("use_action", false)).is_true()
	if is_failure():
		return

	# One more fresh held gesture waters the row.
	await _stand_at_target(game, cells[2], UP)
	assert_bool(await game.input_action("use_action", true)).is_true()
	for cell in [cells[1], cells[0]]:
		await _stand_at_target(game, cell, UP)
		assert_bool(await game.wait_seconds(hold_wait)).is_true()
	assert_bool(await game.input_action("use_action", false)).is_true()
	if is_failure():
		return

	# Exactly one operation per cell: tilled watered soil and a standing crop.
	for cell in cells:
		assert_bool(await game.get_property(_soil_path(cell), "visible")).is_true()
		assert_int(int(await game.get_property(_soil_path(cell), "frame"))).is_equal(1)
		assert_bool(
			await game.get_property(_crop_path(cell) + "/Sprite2D", "visible")
		).is_true()
	assert_str(
		await game.get_property(CHROME + "/SeedCard/Row/Tile/Badge/Count", "text")
	).is_equal("×0")
	await _assert_stamina(game, 2)


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

	# Drive the farm truck to town through the real E interaction, then
	# target the authored shop cell.
	await _stand_at_target(game, WorldContract.TRUCK_CELL, RIGHT)
	await game.call_method(WORLD, "interact")
	await _wait_travel_release(game)
	await _stand_at_target(game, TownContract.SHOP_CELL, RIGHT)
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
		await game.wait_for_property(CHROME + "/TopRight/Money/Row/Value", "text", "130G", 5.0)
	).is_true()
	assert_bool(await game.input_action("ui_cancel", true)).is_true()
	assert_bool(await game.input_action("ui_cancel", false)).is_true()
	assert_bool(
		await game.wait_for_property(HUD + "/ShopPanel", "visible", false, 5.0)
	).is_true()


# One valid schema-4 save seeded before launch: 255G, unowned efficient can,
# intro acknowledged, and one tilled/planted/unwatered Turnip on the first
# contract farm cell.
func _seed_upgrade_save(path: String) -> void:
	var session := GameSession.new(func() -> float: return 0.9)
	var seeded := session.state()
	seeded["money"] = 255
	seeded["intro_acknowledged"] = true
	seeded["farm"][0]["tilled"] = true
	seeded["farm"][0]["crop"] = {
		"kind": &"turnip",
		"growth": 0,
		"dry_nights": 0,
		"watered_today": false,
	}
	assert_str(SessionStateValidator.state_error(seeded)).is_equal("")
	assert_bool(session.restore_state(seeded)).is_true()
	assert_int(SaveRepository.new(path).save(session.state())).is_equal(OK)


# Single-launch fixture: seed the upgrade save at the isolated PHOENIX_SAVE_PATH
# before spawn, then Continue instead of New Game. No intro overlay plays
# (intro is acknowledged in the seed), so no ui_accept tap is needed.
func _continue_seeded_game() -> Variant:
	var options := E2ELaunchOptions.new()
	options.scene_path = "res://scenes/app/app.tscn"
	var fps := OS.get_environment("PHOENIX_E2E_FIXED_FPS")
	if fps != "":
		options.extra_godot_args = PackedStringArray(["--fixed-fps", fps])
	_save_path = create_temp_dir("phoenix-save-e2e") + "/save.json"
	_seed_upgrade_save(_save_path)
	var settings_path := create_temp_dir("phoenix-settings-e2e") + "/settings.cfg"
	var settings := ConfigFile.new()
	settings.set_value("ui", "fullscreen", false)
	# The HUD asserts English copy ("Day 1"); pin the language so a ja or
	# zh_TW OS locale does not pick a translation.
	settings.set_value("ui", "language", "en")
	assert_int(settings.save(settings_path)).is_equal(OK)
	OS.set_environment("PHOENIX_SAVE_PATH", _save_path)
	OS.set_environment("PHOENIX_SETTINGS_PATH", settings_path)
	var game := await launch_game(options)
	OS.unset_environment("PHOENIX_SAVE_PATH")
	OS.unset_environment("PHOENIX_SETTINGS_PATH")
	if game == null or is_failure():
		return null
	assert_bool(await game.click_node("/root/AppRoot/TitleScreen/Menu/Continue")).is_true()
	assert_bool(await game.wait_for_node(WORLD, 10.0)).is_true()
	assert_bool(
		await game.wait_for_property(DAY, "text", "Day 1", 10.0)
	).is_true()
	return game


# Single-launch purchase proof: Continue into the seeded 255G save, buy the
# 200G Efficient Can through the real shop rows (one Enter), then verify the
# ownership signals and one real watering. Stop there — no relaunch, no
# sleep; the Task 3 integration tests own persistence.
func test_continue_seeded_save_buys_upgrade_and_waters_with_one_stamina() -> void:
	var game = await _continue_seeded_game()
	if game == null or is_failure():
		return

	# Drive to town, then real shop entry at the contract cell and real
	# W/S navigation down to the Efficient Can row.
	await _stand_at_target(game, WorldContract.TRUCK_CELL, RIGHT)
	await game.call_method(WORLD, "interact")
	await _wait_travel_release(game)
	await _stand_at_target(game, TownContract.SHOP_CELL, RIGHT)
	await game.call_method(WORLD, "interact")
	if is_failure():
		return
	assert_bool(
		await game.wait_for_property(HUD + "/ShopPanel", "visible", true, 5.0)
	).is_true()
	for _row in ShopPanel.UPGRADE_ROW:
		assert_bool(await game.input_action("move_down", true)).is_true()
		assert_bool(await game.input_action("move_down", false)).is_true()
	assert_str(
		await game.call_method(HUD + "/ShopPanel", "selected_action_text")
	).is_equal("Buy 1 · 200G")

	# One Enter buys through the real panel request path: 255 - 200 = 55.
	assert_bool(await game.input_action("ui_accept", true)).is_true()
	assert_bool(await game.input_action("ui_accept", false)).is_true()
	assert_str(
		await _wait_for_call_value(game, HUD + "/ShopPanel", "money_text", "55")
	).is_equal("55")
	assert_str(
		await game.call_method(HUD + "/ShopPanel", "selected_action_text")
	).is_equal("OWNED")

	# Esc closes the shop; ownership now shows on the world HUD.
	assert_bool(await game.input_action("ui_cancel", true)).is_true()
	assert_bool(await game.input_action("ui_cancel", false)).is_true()
	assert_bool(
		await game.wait_for_property(HUD + "/ShopPanel", "visible", false, 5.0)
	).is_true()

	await _stand_at_target(game, TownContract.TRUCK_CELL, LEFT)
	await game.call_method(WORLD, "interact")
	await _wait_travel_release(game)

	# Primary feedback: the Water prompt reads 1 stamina. Secondary: its
	# icon swapped to the efficient-can glint.
	await _stand_at_target(game, WorldContract.farm_cells()[0], UP)
	assert_bool(
		await game.wait_for_property(
			CHROME + "/Prompt/Bubble/Row/Detail", "text", "· 1 stamina", 5.0
		)
	).is_true()
	assert_str(await game.call_method(GAME_HUD, "prompt_text")).is_equal(
		"[Space] Water Turnip · 1 stamina"
	)
	assert_str(
		await game.get_property(
			CHROME + "/Prompt/Bubble/Row/Icon", "texture:resource_path"
		)
	).is_equal("res://assets/ui/icons/watering-can-efficient.png")

	# One real watering succeeds and spends exactly one stamina (20 -> 19).
	await _use_action(game)
	if is_failure():
		return
	await _assert_stamina(game, 19)


func _find_node_path(game, base: String, node_name: String) -> String:
	var tree: Dictionary = await game.get_tree(base, 8)
	return _walk_for_name(tree, node_name)


func _walk_for_name(node: Dictionary, node_name: String) -> String:
	if String(node.get("name", "")) == node_name:
		return String(node.get("path", ""))
	for child in node.get("children", []):
		var found := _walk_for_name(child, node_name)
		if found != "":
			return found
	return ""


func _phys_tap(keycode: int) -> Array:
	return [
		{"type": "key", "keycode": keycode, "pressed": true, "physical": true},
		{"type": "key", "keycode": keycode, "pressed": false, "physical": true},
	]


func _tap(keycode: int) -> Array:
	return [
		{"type": "key", "keycode": keycode, "pressed": true},
		{"type": "key", "keycode": keycode, "pressed": false},
	]


func _send_specs(game, specs: Array) -> void:
	var res = await game.send_command("input_sequence", {"specs": specs})
	assert_bool(res.ok).is_true()
	var results: Array = (
		res.value.get("results", []) if res.value is Dictionary else []
	)
	assert_int(results.size()).is_equal(specs.size())
	for entry in results:
		assert_bool(bool(entry.get("ok", false))).is_true()


func _run_travel_beat(
	game, target: Vector2i, facing: int, dest_map: String, arrival: Vector2i
) -> void:
	var clock_path := CHROME + "/ClockCard/Surface/Body/Row/Clock"
	var overlay_path := HUD + "/TravelOverlay"
	var tutorial_path := HUD + "/OnboardingOverlay/TutorialCard"
	var seed_name_path := CHROME + "/SeedCard/Row/Info/Name"
	await _stand_at_target(game, target, facing)
	if is_failure():
		return
	var stand_pos: Vector2 = await game.get_property(
		PLAYER, "global_position"
	)

	var bag_path := HUD + "/BagPanel"
	var pause_path := HUD + "/PausePanel"
	var control_seed: String = await game.get_property(seed_name_path, "text")
	var dismissed_list: Variant = await game.get_property(
		HUD + "/OnboardingOverlay", "_dismissed"
	)
	var dismissed_control: int = (
		dismissed_list.size() if dismissed_list is Array else 0
	)
	var tutorial_open: bool = (
		await game.get_property(tutorial_path, "visible") == true
	)
	var dismiss_btn := await _find_node_path(
		game, HUD + "/OnboardingOverlay", "Dismiss"
	)
	await _send_specs(game, _phys_tap(KEY_I))
	await game.wait_seconds(0.5)
	assert_bool(await game.get_property(bag_path, "visible")).is_true()
	await _send_specs(game, _phys_tap(KEY_I))
	await game.wait_seconds(0.5)
	assert_bool(await game.get_property(bag_path, "visible")).is_false()
	await _send_specs(game, _tap(KEY_ESCAPE))
	await game.wait_seconds(0.5)
	assert_bool(await game.get_property(pause_path, "visible")).is_true()
	await _send_specs(game, _tap(KEY_ESCAPE))
	await game.wait_seconds(0.5)
	assert_bool(await game.get_property(pause_path, "visible")).is_false()
	await _send_specs(
		game,
		[
			{
				"type": "key",
				"keycode": KEY_SPACE,
				"pressed": true,
				"physical": true
			}
		]
	)
	await game.wait_seconds(0.5)
	assert_bool(await game.get_property(WORLD, "_action_hold_active")).is_true()
	await _send_specs(
		game,
		[
			{
				"type": "key",
				"keycode": KEY_SPACE,
				"pressed": false,
				"physical": true
			}
		]
	)
	await game.wait_seconds(0.5)
	assert_bool(await game.get_property(WORLD, "_action_hold_active")).is_false()
	if tutorial_open and dismiss_btn != "":
		await _send_specs(game, [{"type": "click", "path": dismiss_btn}])
		await game.wait_seconds(0.5)
		var dismissed_now: Variant = await game.get_property(
			HUD + "/OnboardingOverlay", "_dismissed"
		)
		assert_int(
			dismissed_now.size() if dismissed_now is Array else -1
		).is_equal(dismissed_control + 1)
	await _send_specs(game, _phys_tap(KEY_2))
	await game.wait_seconds(0.5)
	var after_two := str(await game.get_property(seed_name_path, "text"))
	assert_str(after_two).is_not_equal(control_seed)
	await _send_specs(game, [{"type": "click", "path": CHROME + "/SeedCard"}])
	await game.wait_seconds(0.5)
	assert_str(
		await game.get_property(seed_name_path, "text")
	).is_not_equal(after_two)

	var tutorial_visible: bool = (
		await game.get_property(tutorial_path, "visible") == true
	)
	var dismiss_path := await _find_node_path(
		game, HUD + "/OnboardingOverlay", "Dismiss"
	)
	var dismissed_before_list: Variant = await game.get_property(
		HUD + "/OnboardingOverlay", "_dismissed"
	)
	var dismissed_before: int = (
		dismissed_before_list.size() if dismissed_before_list is Array else 0
	)
	var seed_before: String = await game.get_property(seed_name_path, "text")
	var start_clock: String = await game.get_property(clock_path, "text")
	var spawn := WorldMath.grid_to_world(Vector2(arrival) + Vector2(0.5, 0.5))
	assert_bool(await game.get_property(WORLD, "_world_input_enabled")).is_true()
	assert_bool(
		await game.set_property(WORLD, "_clock_elapsed_seconds", 0.0)
	).is_true()
	assert_bool(await game.set_property(WORLD, "clock_running", true)).is_true()

	var observe_result = await game.send_command(
		"observe",
		{
			"while": {"path": overlay_path, "property": "visible", "value": true},
			"release_on": {
				"sample": "dest", "value": true, "actions": ["move_right"]
			},
			"arm_frames": 300,
			"max_frames": 1200,
			"samples": [
				{"name": "alpha", "path": overlay_path, "property": "modulate:a"},
				{"name": "cover", "path": overlay_path + "/Scrim", "property": "color:a"},
				{"name": "gate", "path": WORLD, "property": "_world_input_enabled"},
				{"name": "modal", "path": GAME_HUD, "method": "has_blocking_modal"},
				{"name": "elapsed", "path": WORLD, "property": "_clock_elapsed_seconds"},
				{"name": "clock", "path": clock_path, "property": "text"},
				{"name": "pos", "path": PLAYER, "property": "global_position"},
				{"name": "pause", "path": HUD + "/PausePanel", "property": "visible"},
				{"name": "bag", "path": HUD + "/BagPanel", "property": "visible"},
				{"name": "seed", "path": seed_name_path, "property": "text"},
				{"name": "dismissed", "path": HUD + "/OnboardingOverlay", "property": "_dismissed"},
				{"name": "dest", "exists": WORLD + "/" + dest_map},
			],
		}
	)
	assert_bool(observe_result.ok).is_true()
	var probe_specs: Array = [
		{"type": "action", "action_name": "move_right", "pressed": true},
	]
	probe_specs.append_array(_phys_tap(KEY_E))
	probe_specs.append_array(_phys_tap(KEY_E))
	probe_specs.append_array(_tap(KEY_ESCAPE))
	probe_specs.append_array(_phys_tap(KEY_SPACE))
	probe_specs.append_array(_phys_tap(KEY_2))
	probe_specs.append_array(_phys_tap(KEY_I))
	probe_specs.append({"type": "click", "path": CHROME + "/SeedCard"})
	if tutorial_visible and dismiss_path != "":
		probe_specs.append({"type": "click", "path": dismiss_path})
	await _send_specs(game, probe_specs)

	var observed: Dictionary = {}
	var observe_deadline := Time.get_ticks_msec() + 30000
	while Time.get_ticks_msec() < observe_deadline:
		await game.wait_seconds(0.4)
		var poll = await game.send_command("observe_result")
		if poll.ok and bool(poll.value.get("done", false)):
			observed = poll.value
			break
	assert_bool(observed.get("done", false)).is_true()
	assert_bool(observed.get("active", false)).is_true()
	assert_bool(bool(observed.get("released", false))).is_true()
	await game.input_action("move_right", false)
	var frames_data: Array = observed.get("data", [])
	assert_int(frames_data.size()).is_greater_equal(3)

	var frozen_elapsed := -1.0
	var depart_clock := ""
	var arrival_clock := ""
	var frozen_dismissed := -1
	var max_alpha := 0.0
	var pos_changes := 0
	var swap_flips := 0
	var swap_alpha := 0.0
	var swap_cover := 0.0
	var last_pos: Variant = null
	var last_dest := false
	var bad_frames: Array[String] = []
	for record in frames_data:
		if bool(record.get("gate", true)) != false:
			bad_frames.append("gate")
		if bool(record.get("modal", false)) != true:
			bad_frames.append("modal")
		var alpha_now := float(record.get("alpha", 0.0))
		max_alpha = maxf(max_alpha, alpha_now)
		var dest_now: bool = bool(record.get("dest", false))
		if dest_now != last_dest:
			swap_flips += 1
			swap_alpha = alpha_now
			swap_cover = alpha_now * float(record.get("cover", 0.0))
		last_dest = dest_now
		var elapsed_now = record.get("elapsed", null)
		if elapsed_now != null:
			if frozen_elapsed < 0.0:
				frozen_elapsed = float(elapsed_now)
			elif not is_equal_approx(float(elapsed_now), frozen_elapsed):
				bad_frames.append("elapsed")
		var clock_now := str(record.get("clock", ""))
		if clock_now != "":
			if not dest_now:
				if depart_clock == "":
					depart_clock = clock_now
				elif clock_now != depart_clock:
					bad_frames.append("clock")
			elif arrival_clock == "":
				arrival_clock = clock_now
			elif clock_now != arrival_clock:
				bad_frames.append("clock")
		var dismissed_now = record.get("dismissed", null)
		if dismissed_now is Array:
			if frozen_dismissed < 0:
				frozen_dismissed = dismissed_now.size()
			elif dismissed_now.size() != frozen_dismissed:
				bad_frames.append("dismissed")
		if str(record.get("seed", "")) != seed_before:
			bad_frames.append("seed")
		if bool(record.get("pause", false)):
			bad_frames.append("pause")
		if bool(record.get("bag", false)):
			bad_frames.append("bag")
		var pos_now = record.get("pos", null)
		if pos_now != null:
			if last_pos == null and not dest_now:
				assert_vector(pos_now).is_equal_approx(
					stand_pos, Vector2(2.0, 2.0)
				)
			elif last_pos != null and pos_now != last_pos:
				pos_changes += 1
				if not dest_now:
					bad_frames.append("move")
			last_pos = pos_now
	assert_array(bad_frames).is_empty()
	assert_float(max_alpha).is_greater_equal(0.9)
	assert_int(swap_flips).is_equal(1)
	assert_float(swap_alpha).append_failure_message(
		"the map swapped while the overlay was opaque"
	).is_greater_equal(0.9)
	assert_float(swap_cover).append_failure_message(
		"the map swapped while the scrim effectively covered the screen"
	).is_greater_equal(0.85)
	if arrival_clock != "":
		assert_str(arrival_clock).is_not_equal(depart_clock)
	assert_int(pos_changes).is_less_equal(1)
	assert_int(frozen_dismissed).is_equal(dismissed_before)
	if last_pos != null:
		assert_vector(last_pos).is_equal_approx(spawn, Vector2(2.0, 2.0))

	assert_bool(await game.get_property(overlay_path, "visible")).is_false()
	assert_bool(await game.get_property(WORLD, "_world_input_enabled")).is_true()
	assert_bool(
		await game.call_method(GAME_HUD, "has_blocking_modal")
	).is_false()
	assert_bool(await game.node_exists(WORLD + "/" + dest_map)).is_true()
	var pos_after = await game.get_property(PLAYER, "global_position")
	if pos_after != null:
		assert_vector(pos_after).is_equal_approx(spawn, Vector2(2.0, 2.0))
	assert_str(
		await game.get_property(clock_path, "text")
	).is_not_equal(start_clock)
	var release_clock := str(await game.get_property(clock_path, "text"))
	var resumed := false
	var resume_deadline := Time.get_ticks_msec() + 8000
	while Time.get_ticks_msec() < resume_deadline and not resumed:
		await game.wait_seconds(0.3)
		var clock_now: String = await game.get_property(clock_path, "text")
		if clock_now != "" and clock_now != release_clock:
			resumed = true
	assert_bool(resumed).is_true()
	assert_bool(await game.set_property(WORLD, "clock_running", false)).is_true()


func test_travel_overlay_blocks_input_and_resumes_the_clock() -> void:
	var game = await _start_new_game()
	if game == null or is_failure():
		return
	assert_bool(await game.set_property(WORLD, "clock_running", false)).is_true()
	assert_bool(
		await game.set_property(WORLD, "_clock_window_focused", true)
	).is_true()

	await _run_travel_beat(
		game, WorldContract.TRUCK_CELL, RIGHT, "TownMap", TownContract.TRUCK_ARRIVAL
	)
	await _run_travel_beat(
		game, TownContract.TRUCK_CELL, LEFT, "FarmMap", WorldContract.TRUCK_ARRIVAL
	)
	assert_bool(await game.node_exists(WORLD + "/TownMap")).is_false()


func test_observe_rejects_malformed_specs_and_keeps_the_armed_observer() -> void:
	var game = await _start_new_game()
	if game == null or is_failure():
		return
	var arm = await game.send_command(
		"observe",
		{
			"while": {"path": WORLD, "property": "visible", "value": true},
			"samples": [
				{"name": "gate", "path": WORLD, "property": "_world_input_enabled"}
			],
			"arm_frames": 300,
			"max_frames": 1200,
		}
	)
	assert_bool(arm.ok).is_true()
	for bad in [
		{"while": WORLD},
		{"while": {"path": WORLD}},
		{"while": {"path": WORLD, "property": "visible"}, "samples": {"name": "x"}},
		{"while": {"path": WORLD, "property": "visible"}, "samples": [{"name": "x"}]},
		{"while": {"path": WORLD, "property": "visible"}, "samples": [{"path": WORLD}]},
		{"while": {"path": WORLD, "property": "visible"}, "release_on": ["move_right"]},
		{"while": {"path": WORLD, "property": "visible"}, "release_on": {"sample": "x"}},
		{"while": {"path": WORLD, "property": "visible"}, "arm_frames": "lots"},
	]:
		var res = await game.send_command("observe", bad)
		assert_bool(res.ok).is_false()
	await game.wait_seconds(0.3)
	var poll = await game.send_command("observe_result")
	assert_bool(poll.ok).is_true()
	assert_bool(bool(poll.value.get("active", false))).is_true()
	var rearm = await game.send_command(
		"observe",
		{
			"while": {"path": WORLD, "property": "visible", "value": true},
			"max_frames": 2,
		}
	)
	assert_bool(rearm.ok).is_true()
