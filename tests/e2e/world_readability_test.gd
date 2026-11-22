# HPA-743 real-input e2e smoke: one live new game drives near-contact E on
# the five interactables the plan names — farm bed, shipping bin, farm truck,
# town Seed Shop, one villager — plus an isolated wrong-facing E refusal.
# Every pose is derived from the contract interact regions (a footprint edge
# midpoint pushed a few pixels out along its outward screen normal, inside
# the near-contact reach) so the HPA-743 contact resolver, not the exact
# raw-cell fallback, answers each press. The GUT contact tables stay the
# exhaustive every-reachable-face coverage; this e2e intentionally samples
# one representative pose per object on one desktop platform.
extends GdUnitE2ETestSuite

const WORLD := "/root/AppRoot/World"
const GAME_HUD := WORLD + "/GameHud"
const HUD := GAME_HUD + "/HudRoot"
const PLAYER := WORLD + "/%Player"
const TARGET_HIGHLIGHT := WORLD + "/TargetHighlight"
const DAY := HUD + "/Chrome/ClockCard/Surface/Body/Row/Meta/DayTag/DayRow/Day"

const CONTACT_REACH_PX := WorldContract.INTERACT_REACH_PIXELS
const POSE_STANDOFF_PX := 8.0

const UP := WorldMath.Facing.UP
const RIGHT := WorldMath.Facing.RIGHT
const DOWN := WorldMath.Facing.DOWN
const LEFT := WorldMath.Facing.LEFT

var _save_path := ""


# Footprint polygon edges in contract order: 0 north, 1 east, 2 south,
# 3 west (the projected diamond's four sides, matching the GUT face rows).
# Returns the edge midpoint pushed POSE_STANDOFF_PX along the outward screen
# normal, plus that normal, so callers can pick a positively faced standing.
func _contact_pose(footprint: Rect2, side: int) -> Dictionary:
	var polygon := WorldMath.footprint_to_polygon(footprint)
	var edge_start: Vector2 = polygon[side]
	var edge_end: Vector2 = polygon[(side + 1) % 4]
	var mid := (edge_start + edge_end) * 0.5
	var edge_direction := (edge_end - edge_start).normalized()
	var outward := Vector2(edge_direction.y, -edge_direction.x)
	var center := WorldMath.grid_to_world(footprint.get_center())
	if outward.dot(center - mid) > 0.0:
		outward = -outward
	var position := mid + outward * POSE_STANDOFF_PX
	var contact := WorldMath.closest_contact(position, footprint)
	assert_float(position.distance_to(contact)).is_less_equal(CONTACT_REACH_PX)
	return {"position": position, "outward": outward}


# The screen direction a Facing walks, matching WorldMath's projection sign.
func _screen_direction(facing: int) -> Vector2:
	match facing:
		UP:
			return Vector2(0, -1)
		RIGHT:
			return Vector2(1, 0)
		DOWN:
			return Vector2(0, 1)
	return Vector2(-1, 0)


# Teleport to a near-contact pose and face it. With `faced` the facing must
# see the contact (positive dot); otherwise the pose must be a negative-dot
# wrong-facing pose (the refusal case). Either way the polarity is pinned
# before any key is pressed.
func _stand_at_contact(game, footprint: Rect2, side: int, facing: int, faced := true) -> void:
	var pose := _contact_pose(footprint, side)
	var dot := _screen_direction(facing).dot(-pose["outward"])
	if faced:
		assert_float(dot).is_greater(0.0)
	else:
		assert_float(dot).is_less(0.0)
	assert_bool(
		await game.set_property(PLAYER, "global_position", pose["position"])
	).is_true()
	assert_bool(await game.set_property(PLAYER, "facing", facing)).is_true()


# Canonical cell -> collision footprint from the active map's contract table.
func _region_footprint(farm: bool, cell: Vector2i) -> Rect2:
	var regions: Array = (
		WorldContract.interact_regions() if farm else TownContract.interact_regions()
	)
	for region in regions:
		if region["cell"] == cell:
			return region["footprint"]
	fail("no interact region for cell %s (farm=%s)" % [cell, farm])
	return Rect2()


func _tap_key(game, keycode: Key) -> void:
	assert_bool(await game.input_key(keycode, true, true)).is_true()
	assert_bool(await game.input_key(keycode, false, true)).is_true()


func _wait_travel_release(game) -> void:
	var deadline_msec := Time.get_ticks_msec() + 10000
	while bool(await game.call_method(GAME_HUD, "has_blocking_modal")):
		if Time.get_ticks_msec() >= deadline_msec:
			break
		await game.wait_seconds(0.1)
	assert_bool(await game.call_method(GAME_HUD, "has_blocking_modal")).is_false()


func _close_top_modal(game) -> void:
	assert_bool(await game.input_action("ui_cancel", true)).is_true()
	assert_bool(await game.input_action("ui_cancel", false)).is_true()


func _restore_env(name: String, was_set: bool, original: String) -> void:
	if was_set:
		OS.set_environment(name, original)
	else:
		OS.unset_environment(name)


func _start_new_game() -> Variant:
	var options := E2ELaunchOptions.new()
	options.scene_path = "res://scenes/app/app.tscn"
	var fps := OS.get_environment("PHOENIX_E2E_FIXED_FPS")
	if fps != "":
		options.extra_godot_args = PackedStringArray(["--fixed-fps", fps])
	_save_path = create_temp_dir("phoenix-save-e2e") + "/save.json"
	var settings_path := create_temp_dir("phoenix-settings-e2e") + "/settings.cfg"
	var settings := ConfigFile.new()
	settings.set_value("ui", "fullscreen", false)
	settings.set_value("ui", "language", "en")
	assert_int(settings.save(settings_path)).is_equal(OK)
	# The runner may already carry these overrides: record them so the
	# post-launch teardown restores the original value instead of unsetting.
	var save_path_set := OS.has_environment("PHOENIX_SAVE_PATH")
	var save_path_before := OS.get_environment("PHOENIX_SAVE_PATH")
	var settings_path_set := OS.has_environment("PHOENIX_SETTINGS_PATH")
	var settings_path_before := OS.get_environment("PHOENIX_SETTINGS_PATH")
	OS.set_environment("PHOENIX_SAVE_PATH", _save_path)
	OS.set_environment("PHOENIX_SETTINGS_PATH", settings_path)
	var game := await launch_game(options)
	_restore_env("PHOENIX_SAVE_PATH", save_path_set, save_path_before)
	_restore_env("PHOENIX_SETTINGS_PATH", settings_path_set, settings_path_before)
	if game == null or is_failure():
		return null
	assert_bool(
		await game.click_node("/root/AppRoot/TitleScreen/Menu/NewGame")
	).is_true()
	assert_bool(await game.input_action("ui_cancel", true)).is_true()
	assert_bool(await game.input_action("ui_cancel", false)).is_true()
	assert_bool(await game.wait_for_property(DAY, "text", "Day 1", 10.0)).is_true()
	assert_bool(await game.set_property(WORLD, "clock_running", false)).is_true()
	return game


func test_near_contact_e_opens_five_interactables_and_wrong_facing_refuses() -> void:
	var game = await _start_new_game()
	if game == null or is_failure():
		return

	# Farm bed: a south-lawn near-contact opens the sleep confirmation, and
	# the prompt, gold E diamond and command agree on the canonical cell.
	var bed_footprint := _region_footprint(true, WorldContract.BED_CELL)
	await _stand_at_contact(game, bed_footprint, 2, UP)
	assert_str(await game.call_method(GAME_HUD, "prompt_text")).is_equal(
		"[E] Go to bed"
	)
	assert_bool(
		await game.get_property(TARGET_HIGHLIGHT, "visible")
	).is_true()
	await _tap_key(game, KEY_E)
	if is_failure():
		return
	assert_bool(
		await game.wait_for_property(HUD + "/SleepPanel", "visible", true, 5.0)
	).is_true()
	await _close_top_modal(game)
	assert_bool(
		await game.wait_for_property(HUD + "/SleepPanel", "visible", false, 5.0)
	).is_true()

	# Shipping bin: the approved field fence seals the west face, so a north
	# near-contact (faced down-screen) opens the shipping panel.
	var bin_footprint := _region_footprint(true, WorldContract.SHIPPING_CELL)
	await _stand_at_contact(game, bin_footprint, 0, DOWN)
	assert_str(await game.call_method(GAME_HUD, "prompt_text")).is_equal(
		"[E] Shipping"
	)
	await _tap_key(game, KEY_E)
	if is_failure():
		return
	assert_bool(
		await game.wait_for_property(HUD + "/ShippingPanel", "visible", true, 5.0)
	).is_true()
	await _close_top_modal(game)
	assert_bool(
		await game.wait_for_property(HUD + "/ShippingPanel", "visible", false, 5.0)
	).is_true()

	# Farm truck, wrong facing: the pose is in near-contact reach (so the
	# raw-cell fallback cannot rescue it) but nothing is faced — E refuses
	# with the red toast and shows no prompt.
	var truck_footprint := _region_footprint(true, WorldContract.TRUCK_CELL)
	await _stand_at_contact(game, truck_footprint, 3, LEFT, false)
	assert_str(await game.call_method(GAME_HUD, "prompt_text")).is_equal("")
	await _tap_key(game, KEY_E)
	if is_failure():
		return
	assert_str(await game.call_method(GAME_HUD, "toast_text")).is_equal(
		"Nothing to interact with."
	)

	# Farm truck, faced: the same pose with a positive-dot facing prompts
	# and drives to town through the real travel overlay. The refusal toast
	# from the wrong-facing press is still showing; the successful travel
	# must clear it.
	await _stand_at_contact(game, truck_footprint, 3, RIGHT)
	assert_str(await game.call_method(GAME_HUD, "prompt_text")).is_equal(
		"[E] Drive to town"
	)
	await _tap_key(game, KEY_E)
	assert_bool(await game.wait_for_node(WORLD + "/TownMap", 5.0)).is_true()
	await _wait_travel_release(game)
	assert_str(await game.call_method(GAME_HUD, "toast_text")).is_equal("")

	# Town Seed Shop: a south near-contact opens the shop.
	var shop_footprint := _region_footprint(false, TownContract.SHOP_CELL)
	await _stand_at_contact(game, shop_footprint, 2, UP)
	assert_str(await game.call_method(GAME_HUD, "prompt_text")).is_equal(
		"[E] Seed Shop"
	)
	await _tap_key(game, KEY_E)
	if is_failure():
		return
	assert_bool(
		await game.wait_for_property(HUD + "/ShopPanel", "visible", true, 5.0)
	).is_true()
	await _close_top_modal(game)
	assert_bool(
		await game.wait_for_property(HUD + "/ShopPanel", "visible", false, 5.0)
	).is_true()

	# One villager: a west near-contact prompts the resident's display name
	# and a real E opens their dialogue.
	var sato_cell: Vector2i = TownContract.VILLAGER_CELLS[VillagerRules.VillagerId.SHOPKEEPER]
	var sato_footprint := _region_footprint(false, sato_cell)
	await _stand_at_contact(game, sato_footprint, 3, RIGHT)
	assert_str(await game.call_method(GAME_HUD, "prompt_text")).is_equal(
		"[E] %s" % VillagerRules.display_name(VillagerRules.VillagerId.SHOPKEEPER)
	)
	await _tap_key(game, KEY_E)
	if is_failure():
		return
	assert_bool(
		await game.wait_for_property(HUD + "/DialoguePanel", "visible", true, 5.0)
	).is_true()
	await _close_top_modal(game)
	assert_bool(
		await game.wait_for_property(HUD + "/DialoguePanel", "visible", false, 5.0)
	).is_true()
