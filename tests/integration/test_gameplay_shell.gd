extends GutTest

const SETTINGS_PATH := "user://phoenix-task9-gameplay-settings.cfg"

func before_each() -> void:
    _clean_settings()

func after_each() -> void:
    _clean_settings()

func _clean_settings() -> void:
    if FileAccess.file_exists(SETTINGS_PATH):
        DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS_PATH))

func _spawn_world(acknowledge_intro: bool, settings: UiSettings = null) -> WorldShell:
    var packed := load("res://scenes/world/world.tscn") as PackedScene
    assert_not_null(packed)
    if packed == null:
        return null
    var world := packed.instantiate() as WorldShell
    assert_not_null(world)
    if world == null:
        return null
    if settings != null:
        world.configure(null, null, settings)
    add_child_autoqfree(world)
    if acknowledge_intro:
        var accepted := InputEventAction.new()
        accepted.action = &"ui_accept"
        accepted.pressed = true
        world.get_viewport().push_input(accepted)
        var released := InputEventAction.new()
        released.action = &"ui_accept"
        released.pressed = false
        world.get_viewport().push_input(released)
    return world

func _world() -> WorldShell:
    return _spawn_world(true)

func _settings_world() -> WorldShell:
    return _spawn_world(true, UiSettings.load(SETTINGS_PATH))

func _locked_world() -> WorldShell:
    return _spawn_world(false)

func test_fresh_opening_blocks_world_input() -> void:
    var world := _locked_world()
    var opening := world.hud.get_node(
        "HudRoot/OnboardingOverlay/OpeningPanel"
    ) as Control
    assert_true(opening.visible)
    assert_false(world._world_input_enabled)
    assert_false(world._session.state()["intro_acknowledged"])
    var action_button := world.hud.get_node("HudRoot/Action_1") as Button
    assert_true(action_button.disabled)

func test_start_releases_gate_and_tutorial_card_guides_first_actions() -> void:
    var world := _world()
    if world == null:
        return
    var overlay := world.hud.get_node("HudRoot/OnboardingOverlay") as OnboardingOverlay
    var card := overlay.get_node("TutorialCard") as Control
    assert_false(overlay.is_opening_visible())
    assert_true(card.visible)
    assert_eq((card.get_node("Title") as Label).text, "PREPARE THE FIELD")

    var selected: Array[int] = []
    world.hud.select_action_requested.connect(func(action: int) -> void:
        selected.append(action)
    )

    var hoe_button := world.hud.get_node("HudRoot/Action_0") as Button
    assert_false(hoe_button.disabled)
    hoe_button.pressed.emit()
    assert_eq(selected, [GameRules.FarmingAction.HOE])
    assert_true(world._world_input_enabled)

    var dismiss := card.get_node("Dismiss") as Button
    dismiss.pressed.emit()
    assert_false(card.visible)
    assert_false(world._session.snapshot()["tutorial"][&"farm_basics"])

    var cell: Vector2i = WorldContract.farm_cells()[0]
    await _place_target(world, cell)
    world.use_selected_action()
    assert_true(world._session.snapshot()["tutorial"][&"farm_basics"])
    assert_true(card.visible)
    assert_eq((card.get_node("Title") as Label).text, "PLANT A SEED")

func test_repeated_seed_slot_cycles_selected_seed() -> void:
    var world := _world()
    world.select_action_slot(2)
    assert_eq(world._session.snapshot()["selected_seed"], &"turnip")
    world.select_action_slot(2)
    assert_eq(world._session.snapshot()["selected_seed"], &"potato")
    world.select_action_slot(2)
    assert_eq(world._session.snapshot()["selected_seed"], &"pumpkin")
    world.select_action_slot(2)
    assert_eq(world._session.snapshot()["selected_seed"], &"turnip")

func test_objective_label_counts_down_to_market_day() -> void:
    var world := _world()
    if world == null:
        return
    var hud := _hud(world)
    if hud == null:
        return
    var objective := hud.get_node("HudRoot/Objective") as Label
    var snapshot := world._session.snapshot()
    snapshot["day"] = 1
    hud.render(snapshot)
    assert_eq(objective.text, "Harvest Market: Day 14 · 13 days left")
    snapshot["day"] = GameRules.MAX_DAY
    hud.render(snapshot)
    assert_eq(
        objective.text,
        "Harvest Market today — ship crops first, then visit the village path stall.",
    )

func _cell_center(cell: Vector2i) -> Vector2:
    return WorldMath.grid_to_world(Vector2(cell) + Vector2(0.5, 0.5))

func _release_movement_actions() -> void:
    for action in ["move_up", "move_right", "move_down", "move_left"]:
        Input.action_release(action)

func test_farm_soil_is_non_y_sorted_layer() -> void:
    var world := _world()
    if world == null:
        return
    var farm_soil := world.get_node_or_null("FarmSoil") as Node2D
    assert_not_null(farm_soil)
    if farm_soil == null:
        return
    assert_false(farm_soil.y_sort_enabled)
    assert_eq(farm_soil.z_index, 5)

func test_nine_soil_sprites_use_farm_cell_centers() -> void:
    var world := _world()
    if world == null:
        return
    var farm_soil := world.get_node_or_null("FarmSoil") as Node2D
    assert_not_null(farm_soil)
    if farm_soil == null:
        return
    var cells := WorldContract.farm_cells()
    assert_eq(farm_soil.get_child_count(), cells.size())
    for index in cells.size():
        var soil := farm_soil.get_child(index) as Sprite2D
        assert_not_null(soil)
        if soil == null:
            continue
        assert_true(
            soil.position.distance_to(_cell_center(cells[index])) <= 0.0001,
            "soil %s center" % cells[index],
        )
        assert_eq(soil.texture.resource_path, "res://assets/sprites/proof-soil.png")
        assert_eq(soil.hframes, 2)

func test_entities_is_farm_view_and_only_y_sort_node() -> void:
    var world := _world()
    if world == null:
        return
    var entities := world.get_node_or_null("Entities") as Node2D
    assert_not_null(entities)
    if entities == null:
        return
    var farm_view := entities as FarmView
    assert_not_null(farm_view)
    if farm_view == null:
        return
    assert_true(entities.y_sort_enabled)

    var enabled_y_sort_nodes: Array[CanvasItem] = []
    if world.y_sort_enabled:
        enabled_y_sort_nodes.append(world)
    for node in world.find_children("*", "CanvasItem", true, false):
        var canvas_item := node as CanvasItem
        if canvas_item != null and canvas_item.y_sort_enabled:
            enabled_y_sort_nodes.append(canvas_item)
    assert_eq(enabled_y_sort_nodes.size(), 1)
    if enabled_y_sort_nodes.size() == 1:
        assert_eq(enabled_y_sort_nodes[0], entities)

func test_nine_crop_roots_are_direct_entities_children_at_cell_centers() -> void:
    var world := _world()
    if world == null:
        return
    var entities := world.get_node_or_null("Entities") as Node2D
    assert_not_null(entities)
    if entities == null:
        return
    var cells := WorldContract.farm_cells()
    assert_eq(entities.get_child_count(), 8 + cells.size())
    if entities.get_child_count() < 8 + cells.size():
        return
    for index in cells.size():
        var cell: Vector2i = cells[index]
        var crop_root := entities.get_child(8 + index) as Node2D
        assert_not_null(crop_root)
        if crop_root == null:
            continue
        assert_eq(String(crop_root.name), "FarmCrop_%d_%d" % [cell.x, cell.y])
        assert_eq(crop_root.get_parent(), entities)
        assert_true(
            crop_root.position.distance_to(_cell_center(cell)) <= 0.0001,
            "crop %s center" % cell,
        )
        assert_eq(crop_root.get_child_count(), 2)
        var crop_shadow := crop_root.get_child(0) as Sprite2D
        assert_not_null(crop_shadow)
        if crop_shadow == null:
            continue
        assert_eq(String(crop_shadow.name), "Shadow")
        assert_eq(crop_shadow.texture.resource_path, "res://assets/sprites/proof-shadow.png")
        assert_false(crop_shadow.visible)
        var crop_sprite := crop_root.get_child(1) as Sprite2D
        assert_not_null(crop_sprite)
        if crop_sprite == null:
            continue
        assert_eq(crop_sprite.texture.resource_path, "res://assets/sprites/proof-crops.png")
        assert_eq(crop_sprite.hframes, 4)
        assert_eq(crop_sprite.vframes, 3)
        assert_eq(crop_sprite.offset, Vector2(0, -24))
        assert_false(crop_sprite.visible)

func test_farm_view_refresh_uses_snapshot_presentation_state() -> void:
    var world := _world()
    if world == null:
        return
    var entities := world.get_node_or_null("Entities") as Node2D
    assert_not_null(entities)
    if entities == null:
        return
    var farm_view := entities as FarmView
    assert_not_null(farm_view)
    if farm_view == null:
        return
    var session := GameSession.new()
    var cell := WorldContract.farm_cells()[0]
    var farm_soil := world.get_node_or_null("FarmSoil") as Node2D
    assert_not_null(farm_soil)
    if farm_soil == null:
        return
    var soil := farm_soil.get_child(0) as Sprite2D
    var crop := entities.get_node_or_null("FarmCrop_%d_%d/Sprite2D" % [cell.x, cell.y]) as Sprite2D
    assert_not_null(soil)
    assert_not_null(crop)
    if soil == null or crop == null:
        return

    farm_view.refresh(session.snapshot())
    assert_false(soil.visible)
    assert_false(crop.visible)

    assert_eq(session.hoe(cell), GameRules.CommandCode.SOIL_TILLED)
    assert_eq(session.plant(cell), GameRules.CommandCode.CROP_PLANTED)
    assert_eq(session.water(cell), GameRules.CommandCode.CROP_WATERED)
    farm_view.refresh(session.snapshot())
    assert_true(soil.visible)
    assert_eq(soil.frame, 1)
    assert_true(crop.visible)
    assert_eq(crop.frame, 0)

func test_set_input_enabled_false_zeros_and_stops_player_movement() -> void:
    _release_movement_actions()
    var world := _world()
    if world == null:
        return
    var player := world.get_node_or_null("Entities/Player") as PlayerController
    assert_not_null(player)
    if player == null:
        return
    assert_true(player.has_method("set_input_enabled"))
    if not player.has_method("set_input_enabled"):
        return
    player.velocity = Vector2(96, 0)
    player.set_input_enabled(false)
    assert_eq(player.velocity, Vector2.ZERO)

    var before := player.global_position
    Input.action_press("move_right")
    await get_tree().physics_frame
    Input.action_release("move_right")
    await get_tree().physics_frame
    assert_eq(player.velocity, Vector2.ZERO)
    assert_true(player.global_position.distance_to(before) <= 0.0001)

func test_current_target_cell_matches_world_math() -> void:
    var world := _world()
    if world == null:
        return
    var player := world.get_node_or_null("Entities/Player") as PlayerController
    assert_not_null(player)
    if player == null:
        return
    assert_true(player.has_method("current_target_cell"))
    if not player.has_method("current_target_cell"):
        return
    var expected: Variant = WorldMath.target_cell(
        WorldMath.world_to_grid(player.global_position),
        player.facing,
    )
    var actual: Variant = player.current_target_cell()
    assert_eq(actual, expected)

func _hud(world: WorldShell) -> GameHud:
    var hud := world.get_node_or_null("GameHud") as GameHud
    assert_not_null(hud)
    return hud

func _place_target(world: WorldShell, target: Vector2i) -> void:
    var player := world.get_node_or_null("Entities/Player") as PlayerController
    assert_not_null(player)
    if player == null:
        return
    var target_offset: Vector2i = WorldMath.TARGET_OFFSETS[WorldMath.Facing.DOWN]
    var logical_position := Vector2(target - target_offset) + Vector2.ONE * 0.5
    player.global_position = WorldMath.grid_to_world(logical_position)
    player.facing = WorldMath.Facing.DOWN
    player.velocity = Vector2.ZERO
    await get_tree().physics_frame

func _panel(hud: GameHud, name: String) -> Control:
    return hud.get_node("HudRoot/%s" % name) as Control

func test_interaction_targets_open_only_their_modal() -> void:
    var world := _world()
    if world == null:
        return
    var hud := _hud(world)
    if hud == null:
        return

    for entry in [
        {"cell": WorldContract.SHOP_CELL, "panel": "ShopPanel", "close": "close_shop"},
        {"cell": WorldContract.SHIPPING_CELL, "panel": "ShippingPanel", "close": "close_shipping"},
        {"cell": WorldContract.BED_CELL, "panel": "SleepPanel", "close": "close_sleep_confirmation"},
    ]:
        await _place_target(world, entry["cell"])
        world.interact()
        assert_true(_panel(hud, entry["panel"]).visible)
        for panel_name in ["ShopPanel", "ShippingPanel", "SleepPanel", "MorningSummaryPanel"]:
            if panel_name != entry["panel"]:
                assert_false(_panel(hud, panel_name).visible)
        hud.call(entry["close"])
        assert_false(hud.has_blocking_modal())

func test_shop_keyboard_rows_update_quantity_max_and_enter_request() -> void:
    var world := _world()
    if world == null:
        return
    var hud := _hud(world)
    if hud == null:
        return
    var requests: Array[Dictionary] = []
    hud.buy_requested.connect(func(kind: int, quantity: int) -> void:
        requests.append({"kind": kind, "quantity": quantity})
    )

    var snapshot := world._session.snapshot()
    snapshot["money"] = 150
    snapshot["seeds"] = {&"turnip": 3, &"potato": 0, &"pumpkin": 0}
    hud.render(snapshot)
    hud.open_shop()
    var panel := _panel(hud, "ShopPanel")
    assert_true(panel.has_method("selected_kind"))
    assert_true(panel.has_method("selected_quantity"))
    assert_eq(int(panel.call("selected_kind")), GameRules.CropKind.TURNIP)
    assert_eq(int(panel.call("selected_quantity")), 1)

    await _press_panel_action("move_right")
    assert_eq(int(panel.call("selected_quantity")), 2)
    await _press_panel_action("panel_max")
    assert_eq(int(panel.call("selected_quantity")), 7)
    await _press_panel_action("ui_accept")
    assert_eq(requests, [{"kind": GameRules.CropKind.TURNIP, "quantity": 7}])

func test_shipping_keyboard_rows_update_quantity_max_and_enter_request() -> void:
    var world := _world()
    if world == null:
        return
    var hud := _hud(world)
    if hud == null:
        return
    var requests: Array[Dictionary] = []
    hud.deposit_requested.connect(func(kind: int, quantity: int) -> void:
        requests.append({"kind": kind, "quantity": quantity})
    )

    var snapshot := world._session.snapshot()
    snapshot["day"] = GameRules.MAX_DAY
    snapshot["harvested"] = {&"turnip": 7, &"potato": 0, &"pumpkin": 0}
    snapshot["pending_shipment"] = {&"turnip": 0, &"potato": 0, &"pumpkin": 0}
    hud.render(snapshot)
    hud.open_shipping()
    var panel := _panel(hud, "ShippingPanel")
    assert_true(panel.has_method("selected_kind"))
    assert_true(panel.has_method("selected_quantity"))
    assert_eq(int(panel.call("selected_kind")), GameRules.CropKind.TURNIP)
    assert_eq(int(panel.call("selected_quantity")), 1)

    await _press_panel_action("move_right")
    assert_eq(int(panel.call("selected_quantity")), 2)
    await _press_panel_action("panel_max")
    assert_eq(int(panel.call("selected_quantity")), 7)
    await _press_panel_action("ui_accept")
    assert_eq(requests, [{"kind": GameRules.CropKind.TURNIP, "quantity": 7}])

func test_inventory_modal_keys_are_exclusive_same_key_closes_and_gate_input() -> void:
    var world := _world()
    if world == null:
        return
    var hud := _hud(world)
    if hud == null:
        return
    assert_eq(hud._primary_modals.size(), 10)
    for entry in [
        {"action": &"toggle_bag", "panel": "BagPanel"},
        {"action": &"toggle_almanac", "panel": "AlmanacPanel"},
        {"action": &"toggle_calendar", "panel": "CalendarPanel"},
    ]:
        await _press_panel_action(entry["action"])
        assert_true(_panel(hud, entry["panel"]).visible)
        var visible_count := 0
        for panel in hud._primary_modals:
            if panel.visible:
                visible_count += 1
        assert_eq(visible_count, 1)
        assert_false(world._world_input_enabled)

        await _press_panel_action(entry["action"])
        assert_false(_panel(hud, entry["panel"]).visible)
        assert_true(world._world_input_enabled)

func test_inventory_escape_closes_one_surface_and_morning_summary_guard_wins() -> void:
    var world := _world()
    if world == null:
        return
    var hud := _hud(world)
    if hud == null:
        return

    await _press_panel_action("toggle_bag")
    assert_true(_panel(hud, "BagPanel").visible)
    await _press_escape()
    assert_false(_panel(hud, "BagPanel").visible)
    assert_false(_panel(hud, "PausePanel").visible)
    assert_true(world._world_input_enabled)

    var snapshot := world._session.snapshot()
    snapshot["pending_morning_summary"] = {"completed_day": 2, "next_day": 3}
    hud.render(snapshot)
    assert_true(_panel(hud, "MorningSummaryPanel").visible)
    await _press_panel_action("toggle_bag")
    assert_false(_panel(hud, "BagPanel").visible)
    assert_true(_panel(hud, "MorningSummaryPanel").visible)
    assert_false(world._world_input_enabled)

func test_inventory_shortcuts_respect_opening_and_close_friend_blockers() -> void:
    var locked_world := _locked_world()
    var locked_hud := _hud(locked_world)
    var opening := locked_hud.get_node("HudRoot/OnboardingOverlay/OpeningPanel") as Control
    assert_true(opening.visible)
    for action in [&"toggle_bag", &"toggle_almanac", &"toggle_calendar"]:
        await _press_panel_action(action)
        assert_true(opening.visible)
        assert_false(_panel(locked_hud, "BagPanel").visible)
        assert_false(_panel(locked_hud, "AlmanacPanel").visible)
        assert_false(_panel(locked_hud, "CalendarPanel").visible)

    var world := _world()
    var hud := _hud(world)
    var villager_id := VillagerRules.VillagerId.RESIDENT
    var lines: Array[String] = VillagerRules.close_friend_dialogue_lines(villager_id)
    var result := {
        "code": GameRules.CommandCode.VILLAGER_TALKED,
        "lines": lines,
        "points_gained": 0,
        "gift_reaction": &"",
        "close_friend_sequence": true,
    }
    hud.open_dialogue(villager_id, result, world._session.snapshot())
    var dialogue := _panel(hud, "DialoguePanel") as DialoguePanel
    var line := dialogue.get_node("Panel/Line") as Label
    assert_true(dialogue.visible)
    assert_eq(line.text, "“%s”" % lines[0])
    for action in [&"toggle_bag", &"toggle_almanac", &"toggle_calendar"]:
        await _press_panel_action(action)
        assert_true(dialogue.visible)
        assert_eq(line.text, "“%s”" % lines[0])
        assert_false(_panel(hud, "BagPanel").visible)
        assert_false(_panel(hud, "AlmanacPanel").visible)
        assert_false(_panel(hud, "CalendarPanel").visible)
    hud.close_dialogue()

func test_bag_all_pending_crops_use_compact_in_pane_payout_summary() -> void:
    var world := _world()
    if world == null:
        return
    var hud := _hud(world)
    if hud == null:
        return
    var state := world._session.state()
    state["pending_shipment"] = {&"turnip": 1, &"potato": 2, &"pumpkin": 1}
    var restored := GameSession.new()
    assert_true(restored.restore_state(state))
    hud.render(restored.snapshot())
    hud.open_bag()
    await _press_panel_action("move_down")
    await _press_panel_action("move_down")
    var bag := _panel(hud, "BagPanel") as BagPanel
    var shelf := bag.get_node("Frame/Body/Left/Shelf_2") as Control
    var compact := bag.get_node("Frame/Body/Left/PayoutCompact") as Control
    assert_true((shelf.get_node("Slot_0") as Panel).visible)
    assert_true((shelf.get_node("Slot_1") as Panel).visible)
    assert_true((shelf.get_node("Slot_2") as Panel).visible)
    assert_false((shelf.get_node("PayoutValue") as Label).visible)
    assert_true(compact.visible)
    assert_eq((compact.get_node("Value") as Label).text, "325G")
    assert_eq((compact.get_node("Text") as Label).text, "Pays out tomorrow morning")
    assert_true(compact.position.x + compact.size.x <= 270.0)

func test_calendar_readiness_preserves_mixed_crop_kinds_per_day() -> void:
    var world := _world()
    if world == null:
        return
    var hud := _hud(world)
    if hud == null:
        return
    var state := world._session.state()
    state["day"] = 3
    state["weather"] = &"sunny"
    state["weather_history"] = [&"sunny", &"rainy", &"sunny"]
    var farm: Array = state["farm"]
    farm[0]["tilled"] = true
    farm[0]["crop"] = {
        "kind": &"turnip",
        "growth": 0,
        "watered_today": false,
    }
    farm[1]["tilled"] = true
    farm[1]["crop"] = {
        "kind": &"potato",
        "growth": 2,
        "watered_today": false,
    }
    farm[2]["tilled"] = true
    farm[2]["crop"] = {
        "kind": &"turnip",
        "growth": 0,
        "watered_today": false,
    }
    state["farm"] = farm
    var restored := GameSession.new()
    assert_true(restored.restore_state(state))
    hud.render(restored.snapshot())
    hud.open_calendar()
    var calendar := _panel(hud, "CalendarPanel") as CalendarPanel
    var markers: Dictionary = calendar.call("_readiness_markers", 3)
    assert_eq(markers[6], [GameRules.CropKind.TURNIP, GameRules.CropKind.POTATO])
    var day_six := calendar.get_node("Frame/Body/Day_06") as Panel
    assert_true((day_six.get_node("ReadinessMultiIcon_1") as TextureRect).visible)
    assert_true((day_six.get_node("ReadinessMultiIcon_2") as TextureRect).visible)
    assert_false((day_six.get_node("ReadinessMultiIcon_3") as TextureRect).visible)
    assert_true((day_six.get_node("ReadinessMultiLabel") as Label).visible)
    assert_false((day_six.get_node("ReadinessIcon") as TextureRect).visible)

func test_calendar_day14_current_market_readiness_has_separate_authored_markers() -> void:
    var world := _world()
    if world == null:
        return
    var hud := _hud(world)
    if hud == null:
        return
    var state := world._session.state()
    state["day"] = GameRules.MAX_DAY
    state["weather"] = &"sunny"
    state["weather_history"] = []
    for _day in GameRules.MAX_DAY:
        state["weather_history"].append(&"sunny")
    var farm: Array = state["farm"]
    farm[0]["tilled"] = true
    farm[0]["crop"] = {
        "kind": &"turnip",
        "growth": GameRules.growth_nights(GameRules.CropKind.TURNIP),
        "watered_today": false,
    }
    farm[1]["tilled"] = true
    farm[1]["crop"] = {
        "kind": &"pumpkin",
        "growth": GameRules.growth_nights(GameRules.CropKind.PUMPKIN),
        "watered_today": false,
    }
    state["farm"] = farm
    var restored := GameSession.new()
    assert_true(restored.restore_state(state))
    hud.render(restored.snapshot())
    hud.open_calendar()
    var calendar := _panel(hud, "CalendarPanel") as CalendarPanel
    var day_fourteen := calendar.get_node("Frame/Body/Day_14") as Panel
    assert_true((day_fourteen.get_node("CombinedToday") as Label).visible)
    assert_true((day_fourteen.get_node("CombinedMarket") as TextureRect).visible)
    assert_true((day_fourteen.get_node("CombinedMarketLabel") as Label).visible)
    assert_false((day_fourteen.get_node("Today") as Label).visible)
    assert_false((day_fourteen.get_node("Market") as TextureRect).visible)
    assert_false((day_fourteen.get_node("MarketLabel") as Label).visible)
    assert_true((day_fourteen.get_node("ReadinessMultiIcon_1") as TextureRect).visible)
    assert_true((day_fourteen.get_node("ReadinessMultiIcon_2") as TextureRect).visible)
    assert_false((day_fourteen.get_node("ReadinessMultiIcon_3") as TextureRect).visible)
    assert_true((day_fourteen.get_node("ReadinessMultiLabel") as Label).visible)

func test_calendar_day14_current_market_layout_without_readiness() -> void:
    var world := _world()
    if world == null:
        return
    var hud := _hud(world)
    if hud == null:
        return
    var state := world._session.state()
    state["day"] = GameRules.MAX_DAY
    state["weather"] = &"sunny"
    state["weather_history"] = []
    for _day in GameRules.MAX_DAY:
        state["weather_history"].append(&"sunny")
    var restored := GameSession.new()
    assert_true(restored.restore_state(state))
    hud.render(restored.snapshot())
    hud.open_calendar()
    var calendar := _panel(hud, "CalendarPanel") as CalendarPanel
    var day_fourteen := calendar.get_node("Frame/Body/Day_14") as Panel
    assert_true((day_fourteen.get_node("CombinedToday") as Label).visible)
    assert_true((day_fourteen.get_node("CombinedMarket") as TextureRect).visible)
    assert_true((day_fourteen.get_node("CombinedMarketLabel") as Label).visible)
    assert_false((day_fourteen.get_node("Today") as Label).visible)
    assert_false((day_fourteen.get_node("Market") as TextureRect).visible)
    assert_false((day_fourteen.get_node("MarketLabel") as Label).visible)
    assert_false((day_fourteen.get_node("ReadinessIcon") as TextureRect).visible)
    assert_false((day_fourteen.get_node("ReadinessLabel") as Label).visible)
    assert_false((day_fourteen.get_node("ReadinessMultiLabel") as Label).visible)

func test_read_only_panels_render_rules_and_only_known_calendar_weather() -> void:
    var world := _world()
    if world == null:
        return
    var hud := _hud(world)
    if hud == null:
        return
    var state := world._session.state()
    state["day"] = 3
    state["weather"] = &"sunny"
    state["weather_history"] = [&"sunny", &"rainy", &"sunny"]
    var farm: Array = state["farm"]
    farm[0]["tilled"] = true
    farm[0]["crop"] = {
        "kind": GameRules.crop_key(GameRules.CropKind.TURNIP),
        "growth": 0,
        "watered_today": false,
    }
    farm[1]["tilled"] = true
    farm[1]["crop"] = {
        "kind": GameRules.crop_key(GameRules.CropKind.PUMPKIN),
        "growth": 1,
        "watered_today": false,
    }
    state["farm"] = farm
    state["pending_shipment"] = {&"turnip": 4, &"potato": 0, &"pumpkin": 0}
    var restored := GameSession.new()
    assert_true(restored.restore_state(state))
    hud.render(restored.snapshot())

    hud.open_bag()
    var bag := _panel(hud, "BagPanel")
    assert_eq((bag.get_node("Frame/Body/Detail/Title") as Label).text, "Turnip seeds")
    assert_eq((bag.get_node("Frame/Body/Detail/Economy") as Label).text, "20G buy · 35G sell")
    assert_eq((bag.get_node("Frame/Body/Detail/Favourite") as Label).text, "June's favourite")
    await _press_panel_action("move_down")
    await _press_panel_action("move_down")
    assert_eq((bag.get_node("Frame/Body/Left/Shelf_2/PayoutValue") as Label).text, "140G")
    assert_eq(
        (bag.get_node("Frame/Body/Left/Shelf_2/PayoutText") as Label).text,
        "Pays out tomorrow morning",
    )
    assert_true((bag.get_node("Frame/Body/Left/Shelf_2/Slot_0") as Panel).visible)
    assert_false((bag.get_node("Frame/Body/Left/Shelf_2/Slot_1") as Panel).visible)
    hud.close_bag()

    var season_end_state := state.duplicate(true)
    season_end_state["day"] = GameRules.MAX_DAY
    season_end_state["weather"] = &"sunny"
    var season_weather: Array[StringName] = []
    for _day in GameRules.MAX_DAY:
        season_weather.append(&"sunny")
    season_end_state["weather_history"] = season_weather
    season_end_state["pending_shipment"] = {&"turnip": 1, &"potato": 0, &"pumpkin": 0}
    var season_end_pending := GameSession.new()
    assert_true(season_end_pending.restore_state(season_end_state))
    hud.render(season_end_pending.snapshot())
    hud.open_bag()
    bag = _panel(hud, "BagPanel")
    await _press_panel_action("move_down")
    await _press_panel_action("move_down")
    assert_eq(
        (bag.get_node("Frame/Body/Detail/Description") as Label).text,
        "Payout is collected at season end.",
    )
    assert_eq(
        (bag.get_node("Frame/Body/Left/Shelf_2/PayoutText") as Label).text,
        "Paid at season end",
    )
    hud.close_bag()

    state["day"] = 3
    state["weather"] = &"sunny"
    state["weather_history"] = [&"sunny", &"rainy", &"sunny"]
    state["pending_shipment"] = {&"turnip": 0, &"potato": 1, &"pumpkin": 0}
    var sparse_pending := GameSession.new()
    assert_true(sparse_pending.restore_state(state))
    hud.render(sparse_pending.snapshot())
    hud.open_bag()
    bag = _panel(hud, "BagPanel")
    await _press_panel_action("move_down")
    await _press_panel_action("move_down")
    assert_eq(bag.selected_kind(), GameRules.CropKind.POTATO)
    assert_false((bag.get_node("Frame/Body/Left/Shelf_2/Slot_0") as Panel).visible)
    assert_true((bag.get_node("Frame/Body/Left/Shelf_2/Slot_1") as Panel).visible)
    await _press_panel_action("move_right")
    assert_eq(bag.selected_kind(), GameRules.CropKind.POTATO)
    hud.close_bag()

    state["pending_shipment"] = {&"turnip": 0, &"potato": 0, &"pumpkin": 0}
    var empty_pending := GameSession.new()
    assert_true(empty_pending.restore_state(state))
    hud.render(empty_pending.snapshot())
    hud.open_bag()
    bag = _panel(hud, "BagPanel")
    await _press_panel_action("move_down")
    await _press_panel_action("move_down")
    assert_false((bag.get_node("Frame/Body/Left/Shelf_2/Slot_0") as Panel).visible)
    assert_false((bag.get_node("Frame/Body/Left/Shelf_2/Slot_1") as Panel).visible)
    assert_false((bag.get_node("Frame/Body/Left/Shelf_2/Slot_2") as Panel).visible)
    assert_false((bag.get_node("Frame/Body/Left/Shelf_2/PayoutValue") as Label).visible)
    hud.close_bag()

    hud.open_almanac()
    var almanac := _panel(hud, "AlmanacPanel")
    assert_eq((almanac.get_node("Frame/Body/Card_0/Name") as Label).text, "Turnip")
    assert_eq((almanac.get_node("Frame/Body/Card_1/SellValue") as Label).text, "75G")
    assert_eq((almanac.get_node("Frame/Body/Card_2/MarginValue") as Label).text, "+70")
    hud.close_almanac()

    hud.open_calendar()
    var calendar := _panel(hud, "CalendarPanel")
    assert_true((calendar.get_node("Frame/Body/Day_06/ReadinessIcon") as TextureRect).visible)
    assert_eq((calendar.get_node("Frame/Body/Day_06/ReadinessLabel") as Label).text, "EARLIEST")
    assert_true((calendar.get_node("Frame/Body/Day_09/ReadinessIcon") as TextureRect).visible)
    assert_eq(
        (calendar.get_node("Frame/Body/Day_09/ReadinessIcon") as TextureRect).texture.resource_path,
        "res://assets/ui/crops/pumpkin.png",
    )
    assert_false((calendar.get_node("Frame/Body/Day_04/Weather") as TextureRect).visible)
    assert_true((calendar.get_node("Frame/Body/Day_03/Weather") as TextureRect).visible)

func _press_panel_action(action: StringName) -> void:
    var press := InputEventAction.new()
    press.action = action
    press.pressed = true
    get_viewport().push_input(press)
    var release := InputEventAction.new()
    release.action = action
    release.pressed = false
    get_viewport().push_input(release)
    await get_tree().process_frame

func _press_physical_key(keycode: Key) -> void:
    var press := InputEventKey.new()
    press.keycode = keycode
    press.physical_keycode = keycode
    press.pressed = true
    get_viewport().push_input(press)
    var release := InputEventKey.new()
    release.keycode = keycode
    release.physical_keycode = keycode
    release.pressed = false
    get_viewport().push_input(release)
    await get_tree().process_frame

func test_primary_modal_registry_keeps_surfaces_exclusive() -> void:
    var world := _world()
    if world == null:
        return
    var hud := _hud(world)
    if hud == null:
        return
    assert_eq(hud._primary_modals.size(), 10)
    for entry in [
        {"name": "ShopPanel", "open": Callable(hud, "open_shop"), "close": Callable(hud, "close_shop")},
        {"name": "ShippingPanel", "open": Callable(hud, "open_shipping"), "close": Callable(hud, "close_shipping")},
        {"name": "SleepPanel", "open": Callable(hud, "open_sleep_confirmation"), "close": Callable(hud, "close_sleep_confirmation")},
        {"name": "DialoguePanel", "open": Callable(hud, "open_dialogue").bind(
            VillagerRules.VillagerId.RESIDENT,
            {"code": GameRules.CommandCode.VILLAGER_TALKED, "lines": ["Hello"]},
            world._session.snapshot(),
        ), "close": Callable(hud, "close_dialogue")},
    ]:
        (entry["open"] as Callable).call()
        var visible_count := 0
        for panel in hud._primary_modals:
            if panel.visible:
                visible_count += 1
        assert_eq(visible_count, 1, entry["name"])
        assert_true(hud.has_blocking_modal())
        (entry["close"] as Callable).call()
        assert_false(hud.has_blocking_modal())

func test_off_target_interact_reports_nothing_without_session_mutation() -> void:
    var world := _world()
    if world == null:
        return
    var hud := _hud(world)
    if hud == null:
        return
    var before := world._session.snapshot()
    world.interact()
    assert_eq(world._session.snapshot(), before)
    var feedback := hud.get_node("HudRoot/Feedback") as Label
    assert_not_null(feedback)
    if feedback != null:
        assert_true(feedback.text.contains("Nothing"))

func test_opening_shop_immediately_blocks_movement_and_world_commands() -> void:
    var world := _world()
    if world == null:
        return
    var player := world.get_node_or_null("Entities/Player") as PlayerController
    var hud := _hud(world)
    assert_not_null(player)
    if player == null or hud == null:
        return
    await _place_target(world, WorldContract.SHOP_CELL)
    world.interact()
    assert_false(world._world_input_enabled)
    assert_eq(player.velocity, Vector2.ZERO)
    var before := world._session.snapshot()
    world.select_action_slot(1)
    world.use_selected_action()
    world.interact()
    assert_eq(world._session.snapshot(), before)
    hud.close_shop()
    assert_true(world._world_input_enabled)

func test_primary_shop_modal_covers_tutorial_card_and_restores_it() -> void:
    var world := _world()
    if world == null:
        return
    var hud := _hud(world)
    if hud == null:
        return
    var tutorial := hud.get_node("HudRoot/OnboardingOverlay/TutorialCard") as Control
    assert_true(tutorial.visible)

    hud.open_shop()
    assert_true(_panel(hud, "ShopPanel").visible)
    assert_false(tutorial.visible)
    assert_false((hud.get_node("HudRoot/TopBar") as Control).visible)
    assert_false((hud.get_node("HudRoot/ResourceStrip") as Control).visible)
    assert_false((hud.get_node("HudRoot/Hotbar") as Control).visible)

    hud.close_shop()
    assert_true(tutorial.visible)
    assert_true((hud.get_node("HudRoot/Hotbar") as Control).visible)

func test_closing_shop_restores_input_without_session_refresh() -> void:
    var world := _world()
    if world == null:
        return
    var hud := _hud(world)
    if hud == null:
        return
    await _place_target(world, WorldContract.SHOP_CELL)
    world.interact()
    var before := world._session.snapshot()
    hud.close_shop()
    assert_true(world._world_input_enabled)
    assert_eq(world._session.snapshot(), before)

func test_opening_shipping_immediately_gates_world_input() -> void:
    var world := _world()
    if world == null:
        return
    var hud := _hud(world)
    if hud == null:
        return
    await _place_target(world, WorldContract.SHIPPING_CELL)
    world.interact()
    assert_false(world._world_input_enabled)
    hud.close_shipping()
    assert_true(world._world_input_enabled)

func test_opening_sleep_immediately_gates_world_input() -> void:
    var world := _world()
    if world == null:
        return
    var hud := _hud(world)
    if hud == null:
        return
    await _place_target(world, WorldContract.BED_CELL)
    world.interact()
    assert_false(world._world_input_enabled)
    hud.close_sleep_confirmation()
    assert_true(world._world_input_enabled)

func test_morning_summary_save_status_shows_saved_error_and_clears() -> void:
    var world := _world()
    if world == null:
        return
    var session := GameSession.new(func() -> float: return 0.9)
    assert_eq(session.sleep(WorldContract.BED_CELL), GameRules.CommandCode.DAY_ADVANCED)
    world.hud.render(session.snapshot())

    var status := world.hud.get_node(
        "HudRoot/MorningSummaryPanel/SaveStatus"
    ) as Label

    world.hud.set_save_status(&"saved")
    assert_eq(status.text, "Saved.")

    world.hud.set_save_status(&"error", "Save failed — this morning is not persisted.")
    assert_eq(status.text, "Save failed — this morning is not persisted.")

    world.hud.set_save_status(&"idle")
    assert_eq(status.text, "")

func test_summary_snapshot_derives_morning_modal_visibility() -> void:
    var world := _world()
    if world == null:
        return
    var hud := _hud(world)
    if hud == null:
        return
    var snapshot := world._session.snapshot()
    snapshot["pending_morning_summary"] = {"completed_day": 1, "next_day": 2}
    hud.render(snapshot)
    assert_true(_panel(hud, "MorningSummaryPanel").visible)
    var visible_primary_count := 0
    for panel in hud._primary_modals:
        if panel.visible:
            visible_primary_count += 1
    assert_eq(visible_primary_count, 1)
    assert_true(hud.has_blocking_modal())

func test_task8_fixture_values_render_in_authored_social_and_morning_nodes() -> void:
    var world := _world()
    if world == null:
        return
    var hud := _hud(world)
    if hud == null:
        return

    var dialogue_snapshot := world._session.snapshot()
    dialogue_snapshot["harvested"] = {&"turnip": 7, &"potato": 2, &"pumpkin": 0}
    var relationships: Dictionary = dialogue_snapshot["relationships"]
    var mira: Dictionary = relationships[&"shopkeeper"]
    mira["points"] = 13
    mira["level"] = VillagerRules.relationship_key(VillagerRules.RelationshipLevel.FRIEND)
    mira["talked_today"] = true
    relationships[&"shopkeeper"] = mira
    dialogue_snapshot["relationships"] = relationships
    hud.open_dialogue(
        VillagerRules.VillagerId.SHOPKEEPER,
        {
            "code": GameRules.CommandCode.VILLAGER_TALKED,
            "lines": ["Your fields are starting to look dependable."],
            "points_gained": 1,
            "gift_reaction": &"",
            "close_friend_sequence": false,
            "selected_crop_kind": GameRules.CropKind.POTATO,
        },
        dialogue_snapshot,
    )
    var dialogue := _panel(hud, "DialoguePanel") as DialoguePanel
    assert_eq((dialogue.get_node("Panel/Name") as Label).text, "Mira")
    assert_eq((dialogue.get_node("Panel/Relationship") as Label).text, "FRIEND  ·  13/18")
    assert_eq(
        (dialogue.get_node("Panel/Line") as Label).text,
        "“Your fields are starting to look dependable.”",
    )
    var gifts := dialogue.get_node("Panel/GiftButtons") as HBoxContainer
    assert_eq((gifts.get_node("Gift_0/Count") as Label).text, "7")
    assert_eq((gifts.get_node("Gift_1/Count") as Label).text, "2")
    assert_eq((gifts.get_node("Gift_1/Value") as Label).text, "+5 ♥")
    assert_true((gifts.get_node("Gift_1") as Button).has_focus())
    assert_true((gifts.get_node("Gift_2") as Button).disabled)
    assert_eq((dialogue.get_node("Panel/Footer/ActionText") as Label).text, "GIVE POTATO")
    hud.close_dialogue()

    var summary_snapshot := world._session.snapshot()
    summary_snapshot["day"] = 4
    summary_snapshot["pending_morning_summary"] = {
        "completed_day": 3,
        "next_day": 4,
        "crops_advanced": 2,
        "next_weather": GameRules.weather_key(GameRules.Weather.RAINY),
        "stamina_restored": GameRules.MAX_STAMINA,
        "shipments": [{"crop": &"turnip", "quantity": 2, "amount": 70}],
        "shipping_income": 70,
        "money_after_shipping": 220,
    }
    hud.render(summary_snapshot)
    var summary := _panel(hud, "MorningSummaryPanel")
    assert_eq((summary.get_node("Frame/Header/CompletedDay") as Label).text, "3")
    assert_eq((summary.get_node("Frame/Header/NextDay") as Label).text, "4")
    assert_eq((summary.get_node("Frame/Card_0/Value") as Label).text, "+2")
    assert_eq((summary.get_node("Frame/Card_1/Value") as Label).text, "RAINY")
    assert_eq((summary.get_node("Frame/Card_2/Value") as Label).text, "20")
    assert_eq((summary.get_node("Frame/Card_3/Value") as Label).text, "+70")
    assert_eq((summary.get_node("Frame/ShipmentRow/Name") as Label).text, "Turnip ×2")
    assert_eq((summary.get_node("Frame/ShipmentRow/Amount") as Label).text, "70G")
    assert_false((summary.get_node("Frame/CompactShipmentRows") as Control).visible)
    assert_eq((summary.get_node("Frame/MoneyRow/Amount") as Label).text, "220G")

    summary_snapshot["pending_morning_summary"]["shipments"] = [
        {"crop": &"turnip", "quantity": 2, "amount": 70},
        {"crop": &"potato", "quantity": 1, "amount": 80},
        {"crop": &"pumpkin", "quantity": 3, "amount": 300},
    ]
    hud.render(summary_snapshot)
    var compact := summary.get_node("Frame/CompactShipmentRows") as Control
    assert_false((summary.get_node("Frame/ShipmentRow") as Panel).visible)
    assert_true(compact.visible)
    assert_eq((compact.get_node("Row_0/Name") as Label).text, "Turnip ×2")
    assert_eq((compact.get_node("Row_0/Amount") as Label).text, "70G")
    assert_true((compact.get_node("Row_1") as Panel).visible)
    assert_eq((compact.get_node("Row_1/Name") as Label).text, "Potato ×1")
    assert_eq((compact.get_node("Row_1/Amount") as Label).text, "80G")
    assert_true((compact.get_node("Row_2") as Panel).visible)
    assert_eq((compact.get_node("Row_2/Name") as Label).text, "Pumpkin ×3")
    assert_eq((compact.get_node("Row_2/Amount") as Label).text, "300G")
    var frame := summary.get_node("Frame") as Panel
    var money := summary.get_node("Frame/MoneyRow") as Panel
    var footer := summary.get_node("Frame/Footer") as Panel
    assert_true(
        compact.position.y + compact.size.y <= frame.size.y
        and footer.position.y + footer.size.y <= frame.size.y
        and money.position == Vector2(14, 228)
        and footer.position == Vector2(2, 270),
        "compact payout rows and footer must stay inside the authored frame",
    )

func test_public_primary_opens_are_denied_while_morning_summary_is_visible() -> void:
    var world := _world()
    if world == null:
        return
    var hud := _hud(world)
    if hud == null:
        return
    var snapshot := world._session.snapshot()
    snapshot["pending_morning_summary"] = {"completed_day": 1, "next_day": 2}
    hud.render(snapshot)

    var summary := _panel(hud, "MorningSummaryPanel")
    var shop := _panel(hud, "ShopPanel")
    var shipping := _panel(hud, "ShippingPanel")
    assert_true(summary.visible)
    assert_false(shop.visible)
    assert_false(shipping.visible)
    assert_false((hud.get_node("HudRoot/TopBar") as Control).visible)

    hud.open_shop()
    hud.open_shipping()

    assert_true(summary.visible)
    assert_false(shop.visible)
    assert_false(shipping.visible)
    assert_false((hud.get_node("HudRoot/TopBar") as Control).visible)
    var visible_primary_count := 0
    for panel in hud._primary_modals:
        if panel.visible:
            visible_primary_count += 1
    assert_eq(visible_primary_count, 1)

func test_acknowledgment_clears_summary_and_restores_input() -> void:
    var world := _world()
    if world == null:
        return
    var hud := _hud(world)
    if hud == null:
        return
    var snapshot := world._session.snapshot()
    snapshot["pending_morning_summary"] = {"completed_day": 1, "next_day": 2}
    hud.render(snapshot)
    assert_false(world._world_input_enabled)

    hud.morning_summary_acknowledged.emit()
    assert_false(_panel(hud, "MorningSummaryPanel").visible)
    assert_true(world._world_input_enabled)

func test_blocked_routing_leaves_session_snapshot_unchanged() -> void:
    var world := _world()
    if world == null:
        return
    await _place_target(world, WorldContract.SHOP_CELL)
    world.interact()
    var before := world._session.snapshot()
    world.select_action_slot(2)
    world.hud.select_seed_requested.emit(GameRules.CropKind.POTATO)
    world.use_selected_action()
    world.interact()
    assert_eq(world._session.snapshot(), before)

func test_modal_gates_toggle_buttons_so_hud_matches_session_after_close() -> void:
    var world := _world()
    if world == null:
        return
    var hud := _hud(world)
    if hud == null:
        return
    var action_button := hud.get_node("HudRoot/Action_1") as Button
    var potato_button := hud.get_node("HudRoot/Seed_1") as Button
    assert_not_null(action_button)
    assert_not_null(potato_button)
    if action_button == null or potato_button == null:
        return

    hud.open_shop()

    # While gated, toggles are unclickable, so their local state cannot drift.
    assert_true(action_button.disabled)
    assert_true(potato_button.disabled)
    var before := world._session.snapshot()

    hud.close_shop()
    assert_false(action_button.disabled)
    assert_false(potato_button.disabled)

    var snapshot := world._session.snapshot()
    assert_eq(snapshot, before)
    assert_eq(
        action_button.button_pressed,
        GameRules.action_key(GameRules.FarmingAction.SEEDS) == snapshot["selected_action"],
    )
    assert_eq(
        potato_button.button_pressed,
        GameRules.crop_key(GameRules.CropKind.POTATO) == snapshot["selected_seed"],
    )

func test_day_fourteen_boundary_copy_is_explicit_about_shipped_only() -> void:
    var world := _world()
    if world == null:
        return
    var hud := _hud(world)
    if hud == null:
        return
    var snapshot := world._session.snapshot()
    snapshot["day"] = GameRules.MAX_DAY
    snapshot["harvested"] = {&"turnip": 2, &"potato": 0, &"pumpkin": 0}
    hud.render(snapshot)

    hud.open_shipping()
    var shipping_boundary := _panel(hud, "ShippingPanel").get_node("Boundary") as Label
    assert_true(shipping_boundary.text.contains("only crops deposited here count"))

    hud.open_sleep_confirmation()
    var sleep_boundary := _panel(hud, "SleepPanel").get_node("Boundary") as Label
    assert_true(sleep_boundary.text.contains("this ends the season and settles the bin"))

func test_market_target_hint_and_pre_finale_routing() -> void:
    var world := _world()
    if world == null:
        return
    var hud := _hud(world)
    if hud == null:
        return
    await _place_target(world, WorldContract.MARKET_CELL)
    # WorldShell._process refreshes the hint after the process_frame signal
    # fires, so a single frame can still observe the pre-placement hint.
    await get_tree().process_frame
    await get_tree().process_frame
    var hint := hud.get_node("HudRoot/InteractionHint") as Label
    assert_eq(hint.text, "Harvest Market — E")

    var before := world._session.snapshot()
    world.interact()
    assert_eq(world._session.snapshot(), before)
    var feedback := hud.get_node("HudRoot/Feedback") as Label
    assert_true(feedback.text.contains("opens on Day 14"))

func test_farm_preview_uses_green_red_reason_and_non_farm_gold() -> void:
    var world := _world()
    var hud := _hud(world)
    var hint := hud.get_node("HudRoot/InteractionHint") as Label
    var cell: Vector2i = WorldContract.farm_cells()[0]

    await _place_target(world, cell)
    world._process(0.0)
    assert_eq(world.player.target_highlight.default_color, PlayerController.TARGET_VALID)
    assert_eq(hint.text, "Space — use selected action")

    world.use_selected_action()
    world._process(0.0)
    assert_eq(world.player.target_highlight.default_color, PlayerController.TARGET_INVALID)
    assert_eq(hint.text, "Soil is already tilled.")

    world.select_action_slot(2)
    world._process(0.0)
    assert_eq(world.player.target_highlight.default_color, PlayerController.TARGET_VALID)

    await _place_target(world, WorldContract.SHOP_CELL)
    world._process(0.0)
    assert_eq(world.player.target_highlight.default_color, PlayerController.TARGET_NEUTRAL)
    assert_eq(hint.text, "Shop — E")

func test_blocking_intro_never_advertises_farm_action() -> void:
    var world := _locked_world()
    var hud := _hud(world)
    await _place_target(world, WorldContract.farm_cells()[0])
    world._process(0.0)
    assert_eq(world.player.target_highlight.default_color, PlayerController.TARGET_NEUTRAL)
    assert_eq((hud.get_node("HudRoot/InteractionHint") as Label).text, "")

func test_villager_interaction_opens_dialogue_and_gates_world_input() -> void:
    var world := _world()
    if world == null:
        return
    var hud := _hud(world)
    if hud == null:
        return
    var june := VillagerRules.VillagerId.RESIDENT
    await _place_target(world, WorldContract.villager_cell(june))
    world.interact()

    var panel := _panel(hud, "DialoguePanel") as DialoguePanel
    assert_true(panel.visible)
    assert_false(world._world_input_enabled)
    assert_eq((panel.get_node("Panel/Name") as Label).text, "June")

    var before := world._session.snapshot()
    world.select_action_slot(2)
    world.use_selected_action()
    world.interact()
    assert_eq(world._session.snapshot(), before)

    hud.close_dialogue()
    assert_true(world._world_input_enabled)
    assert_null(get_viewport().gui_get_focus_owner())

func test_dialogue_ui_cancel_closes_and_releases_focus() -> void:
    var world := _world()
    if world == null:
        return
    var hud := _hud(world)
    if hud == null:
        return
    var june := VillagerRules.VillagerId.RESIDENT
    await _place_target(world, WorldContract.villager_cell(june))
    world.interact()

    var panel := _panel(hud, "DialoguePanel") as DialoguePanel
    var close_button := panel.get_node("Panel/Close") as Button
    close_button.grab_focus()
    assert_eq(get_viewport().gui_get_focus_owner(), close_button)

    var cancel := InputEventAction.new()
    cancel.action = &"ui_cancel"
    cancel.pressed = true
    get_viewport().push_input(cancel)
    await get_tree().process_frame

    assert_false(panel.visible)
    assert_true(world._world_input_enabled)
    assert_null(get_viewport().gui_get_focus_owner())

func test_close_friend_dialogue_uses_native_focus_and_cancel_progression() -> void:
    var world := _world()
    if world == null:
        return
    var hud := _hud(world)
    if hud == null:
        return
    var june := VillagerRules.VillagerId.RESIDENT
    var snapshot := world._session.snapshot()
    var relationships: Dictionary = snapshot["relationships"]
    var june_relationship: Dictionary = relationships[&"resident"]
    june_relationship["points"] = 18
    june_relationship["level"] = VillagerRules.relationship_key(VillagerRules.RelationshipLevel.CLOSE_FRIEND)
    relationships[&"resident"] = june_relationship
    snapshot["relationships"] = relationships
    var lines: Array[String] = VillagerRules.close_friend_dialogue_lines(june)
    var result := {
        "code": GameRules.CommandCode.VILLAGER_TALKED,
        "lines": lines,
        "points_gained": 0,
        "gift_reaction": &"",
        "close_friend_sequence": true,
    }

    hud.open_dialogue(june, result, snapshot)
    var panel := _panel(hud, "DialoguePanel") as DialoguePanel
    var continue_button := panel.get_node("Panel/Continue") as Button
    var close_button := panel.get_node("Panel/Close") as Button
    var line := panel.get_node("Panel/Line") as Label
    assert_eq(get_viewport().gui_get_focus_owner(), continue_button)
    assert_eq(line.text, "“%s”" % lines[0])

    var cancel := InputEventAction.new()
    cancel.action = &"ui_cancel"
    cancel.pressed = true
    get_viewport().push_input(cancel)
    await get_tree().process_frame
    assert_true(panel.visible)
    assert_eq(line.text, "“%s”" % lines[0])

    var accept_press := InputEventAction.new()
    accept_press.action = &"ui_accept"
    accept_press.pressed = true
    get_viewport().push_input(accept_press)
    var accept_release := InputEventAction.new()
    accept_release.action = &"ui_accept"
    accept_release.pressed = false
    get_viewport().push_input(accept_release)
    await get_tree().process_frame
    assert_eq(line.text, "“%s”" % lines[1])
    assert_eq(panel._line_index, 1)

    close_button.pressed.emit()
    assert_false(panel.visible)
    assert_null(get_viewport().gui_get_focus_owner())

func test_close_friend_line_one_cannot_be_closed_or_gifted_early() -> void:
    var world := _world()
    if world == null:
        return
    var hud := _hud(world)
    if hud == null:
        return
    var june := VillagerRules.VillagerId.RESIDENT
    var seeded: Array[int] = [1, 0, 0]
    world._session.set("_harvested_counts", seeded)
    var snapshot := world._session.snapshot()
    var lines: Array[String] = VillagerRules.close_friend_dialogue_lines(june)
    var result := {
        "code": GameRules.CommandCode.VILLAGER_TALKED,
        "lines": lines,
        "points_gained": 0,
        "gift_reaction": &"",
        "close_friend_sequence": true,
    }

    hud.open_dialogue(june, result, snapshot)
    var panel := _panel(hud, "DialoguePanel") as DialoguePanel
    var continue_button := panel.get_node("Panel/Continue") as Button
    var close_button := panel.get_node("Panel/Close") as Button
    var gift_buttons := panel.get_node("Panel/GiftButtons") as HBoxContainer
    assert_false(close_button.visible)
    assert_eq(_visible_gift_count(gift_buttons), 0)

    var tab := InputEventAction.new()
    tab.action = &"ui_focus_next"
    tab.pressed = true
    get_viewport().push_input(tab)
    await get_tree().process_frame
    assert_eq(get_viewport().gui_get_focus_owner(), continue_button)

    var accept_press := InputEventAction.new()
    accept_press.action = &"ui_accept"
    accept_press.pressed = true
    get_viewport().push_input(accept_press)
    var accept_release := InputEventAction.new()
    accept_release.action = &"ui_accept"
    accept_release.pressed = false
    get_viewport().push_input(accept_release)
    await get_tree().process_frame

    assert_eq(panel._line_index, 1)
    assert_true(close_button.visible)
    hud.close_dialogue()

func test_gift_button_round_trips_through_session_and_updates_open_panel() -> void:
    var world := _world()
    if world == null:
        return
    var hud := _hud(world)
    if hud == null:
        return
    var june := VillagerRules.VillagerId.RESIDENT
    var seeded: Array[int] = [1, 0, 0]
    world._session.set("_harvested_counts", seeded)
    assert_eq(world._session.snapshot()["harvested"][&"turnip"], 1)

    await _place_target(world, WorldContract.villager_cell(june))
    world.interact()
    var panel := _panel(hud, "DialoguePanel") as DialoguePanel
    var gift_buttons := panel.get_node("Panel/GiftButtons") as HBoxContainer
    assert_eq(_visible_gift_count(gift_buttons), 1)
    var give_turnip := gift_buttons.get_node("Gift_0") as Button
    assert_eq((give_turnip.get_node("Value") as Label).text, "+5 ♥")

    give_turnip.pressed.emit()

    assert_eq(world._session.snapshot()["harvested"][&"turnip"], 0)
    assert_eq(world._session.snapshot()["relationships"][&"resident"]["points"], 6)
    assert_eq(
        (panel.get_node("Panel/Line") as Label).text,
        "“%s”" % VillagerRules.gift_line(june, GameRules.CropKind.TURNIP),
    )
    assert_true((panel.get_node("Panel/Feedback") as Label).text.contains("Favourite gift"))
    assert_eq(_visible_gift_count(gift_buttons), 0)

func _visible_gift_count(gifts: HBoxContainer) -> int:
    var count := 0
    for child in gifts.get_children():
        var button := child as Button
        if button.visible and not button.disabled:
            count += 1
    return count

func test_all_villagers_route_through_same_direct_interaction_path() -> void:
    var world := _world()
    if world == null:
        return
    var hud := _hud(world)
    if hud == null:
        return
    for id in range(VillagerRules.VillagerId.size()):
        await _place_target(world, WorldContract.villager_cell(id))
        world.interact()
        var panel := _panel(hud, "DialoguePanel") as DialoguePanel
        assert_true(panel.visible)
        assert_eq((panel.get_node("Panel/Name") as Label).text, VillagerRules.display_name(id))
        assert_eq((panel.get_node("Panel/Role") as Label).text, VillagerRules.role_label(id).to_upper())
        assert_eq(
            (panel.get_node("Panel/Line") as Label).text,
            "“%s”" % VillagerRules.dialogue_line(id, VillagerRules.RelationshipLevel.STRANGER),
        )
        hud.close_dialogue()
        assert_true(world._world_input_enabled)
        assert_null(get_viewport().gui_get_focus_owner())

func test_dialogue_portrait_matches_each_villager() -> void:
    var world := _world()
    if world == null:
        return
    var hud := _hud(world)
    if hud == null:
        return
    var expected_paths := [
        "res://assets/ui/portraits/mira-full.png",
        "res://assets/ui/portraits/rowan.png",
        "res://assets/ui/portraits/june.png",
    ]
    var result := {
        "code": GameRules.CommandCode.VILLAGER_TALKED,
        "lines": ["A line for the portrait regression."],
        "points_gained": 0,
        "gift_reaction": &"",
        "close_friend_sequence": false,
    }
    for id in range(VillagerRules.VillagerId.size()):
        hud.open_dialogue(id, result, world._session.snapshot())
        var panel := _panel(hud, "DialoguePanel") as DialoguePanel
        assert_eq(
            (panel.get_node("Portrait") as TextureRect).texture.resource_path,
            expected_paths[id],
        )
        hud.close_dialogue()

func test_sleep_warning_box_only_shows_on_day14() -> void:
    var world := _world()
    if world == null:
        return
    var hud := _hud(world)
    if hud == null:
        return
    var sleep := _panel(hud, "SleepPanel") as SleepPanel
    var snapshot := world._session.snapshot()
    snapshot["day"] = 1
    hud.render(snapshot)
    assert_false((sleep.get_node("Frame/WarningBox") as Panel).visible)
    assert_false((sleep.get_node("Boundary") as Label).visible)
    snapshot["day"] = GameRules.MAX_DAY
    hud.render(snapshot)
    assert_true((sleep.get_node("Frame/WarningBox") as Panel).visible)
    assert_true((sleep.get_node("Boundary") as Label).visible)

func _press_escape() -> void:
    var pressed := InputEventAction.new()
    pressed.action = &"ui_cancel"
    pressed.pressed = true
    Input.parse_input_event(pressed)
    await get_tree().process_frame

    var released := InputEventAction.new()
    released.action = &"ui_cancel"
    released.pressed = false
    Input.parse_input_event(released)
    await get_tree().process_frame

func test_escape_does_not_open_help_over_blocking_intro() -> void:
    var world := _locked_world()
    var hud := _hud(world)
    var overlay := hud.get_node("HudRoot/OnboardingOverlay") as OnboardingOverlay
    assert_true(overlay.is_opening_visible())

    await _press_escape()

    assert_true(overlay.is_opening_visible())
    assert_false(_panel(hud, "PausePanel").visible)
    assert_false(world._world_input_enabled)


func test_escape_toggles_code_built_help_and_world_gate() -> void:
    var world := _world()
    var hud := _hud(world)
    var help := _panel(hud, "PausePanel")

    await _press_escape()
    assert_true(help.visible)
    var visible_primary_count := 0
    for panel in hud._primary_modals:
        if panel.visible:
            visible_primary_count += 1
    assert_eq(visible_primary_count, 1)
    assert_false(world._world_input_enabled)

    await _press_escape()
    assert_false(help.visible)
    assert_true(world._world_input_enabled)

func test_pause_settings_nesting_keeps_world_gated_until_pause_closes() -> void:
    var world := _settings_world()
    var hud := _hud(world)
    var pause := _panel(hud, "PausePanel")
    var settings := _panel(hud, "SettingsPanel")
    var gate_samples: Array[bool] = []
    hud.modal_state_changed.connect(func() -> void:
        gate_samples.append(world._world_input_enabled)
    )

    await _press_escape()
    assert_true(pause.visible)
    assert_false(settings.visible)
    assert_false(world._world_input_enabled)
    await _press_physical_key(KEY_ENTER)
    assert_true(pause.visible)
    assert_false(settings.visible)
    assert_false(world._world_input_enabled)

    gate_samples.clear()
    await _press_panel_action(&"open_settings")
    assert_false(pause.visible)
    assert_true(settings.visible)
    assert_false(world._world_input_enabled)
    assert_eq(gate_samples, [false])

    gate_samples.clear()
    await _press_escape()
    assert_true(pause.visible)
    assert_false(settings.visible)
    assert_false(world._world_input_enabled)
    assert_eq(gate_samples, [false])

    await _press_escape()
    assert_false(pause.visible)
    assert_false(settings.visible)
    assert_true(world._world_input_enabled)

func test_open_settings_is_only_available_from_pause() -> void:
    var world := _settings_world()
    var hud := _hud(world)
    var settings := _panel(hud, "SettingsPanel")
    hud.open_shop()
    await _press_panel_action(&"open_settings")
    assert_false(settings.visible)
    hud.close_shop()
    await _press_escape()
    await _press_panel_action(&"open_settings")
    assert_true(settings.visible)

func test_settings_adjustment_persists_in_isolated_path_and_applies_audio() -> void:
    var world := _settings_world()
    var hud := _hud(world)
    hud.open_pause()
    await _press_panel_action(&"open_settings")
    var settings := _panel(hud, "SettingsPanel") as SettingsPanel
    assert_eq(settings.selected_setting_name(), &"music")

    await _press_panel_action(&"move_right")

    assert_eq(hud._settings.music, UiSettings.DEFAULT_MUSIC + 1)
    assert_eq(
        (hud.get_node("MusicPlayer") as AudioStreamPlayer).volume_db,
        hud._settings.db_for_level(UiSettings.DEFAULT_MUSIC + 1),
    )
    var config := ConfigFile.new()
    assert_eq(config.load(SETTINGS_PATH), OK)
    assert_eq(int(config.get_value("ui", "music")), UiSettings.DEFAULT_MUSIC + 1)


func test_escape_closes_shop_before_help() -> void:
    var world := _world()
    var hud := _hud(world)
    hud.open_shop()

    await _press_escape()

    assert_false(_panel(hud, "ShopPanel").visible)
    assert_false(_panel(hud, "PausePanel").visible)


func test_escape_closes_shipping_before_help() -> void:
    var world := _world()
    var hud := _hud(world)
    hud.open_shipping()

    await _press_escape()

    assert_false(_panel(hud, "ShippingPanel").visible)
    assert_false(_panel(hud, "PausePanel").visible)


func test_escape_closes_sleep_before_help() -> void:
    var world := _world()
    var hud := _hud(world)
    hud.open_sleep_confirmation()

    await _press_escape()

    assert_false(_panel(hud, "SleepPanel").visible)
    assert_false(_panel(hud, "PausePanel").visible)


func test_dialogue_consumes_escape_before_help() -> void:
    var world := _world()
    var hud := _hud(world)
    var villager_id := VillagerRules.VillagerId.SHOPKEEPER
    var result := world._session.talk_to(
        villager_id,
        WorldContract.villager_cell(villager_id),
    )
    hud.open_dialogue(villager_id, result, world._session.snapshot())

    await _press_escape()

    assert_false(_panel(hud, "DialoguePanel").visible)
    assert_false(_panel(hud, "PausePanel").visible)


func test_weather_tint_matches_rainy_and_sunny_snapshots() -> void:
    var world := _world()
    var hud := _hud(world)
    var tint := hud.get_node("HudRoot/WeatherTint") as ColorRect
    var snapshot := world._session.snapshot()
    snapshot["weather"] = GameRules.weather_key(GameRules.Weather.RAINY)
    hud.render(snapshot)
    assert_eq(tint.color, GameHud.RAINY_TINT)
    snapshot["weather"] = GameRules.weather_key(GameRules.Weather.SUNNY)
    hud.render(snapshot)
    assert_eq(tint.color, GameHud.SUNNY_TINT)


func test_hud_audio_players_and_representative_feedback_streams() -> void:
    var world := _world()
    var sfx := world.hud.get_node("SfxPlayer") as AudioStreamPlayer
    var music := world.hud.get_node("MusicPlayer") as AudioStreamPlayer
    assert_not_null(sfx)
    assert_not_null(music)
    assert_eq(music.stream.resource_path, "res://assets/audio/farm-day-loop.wav")
    assert_eq((music.stream as AudioStreamWAV).loop_mode, AudioStreamWAV.LOOP_FORWARD)

    world.hud.show_feedback(GameRules.CommandCode.SOIL_TILLED)
    assert_eq(sfx.stream.resource_path, "res://assets/audio/action.wav")
    world.hud.show_feedback(GameRules.CommandCode.SEEDS_PURCHASED)
    assert_eq(sfx.stream.resource_path, "res://assets/audio/commerce.wav")
    world.hud.show_feedback(GameRules.CommandCode.CROP_GIFTED)
    assert_eq(sfx.stream.resource_path, "res://assets/audio/social.wav")
    world.hud.show_feedback(GameRules.CommandCode.DAY_ADVANCED)
    assert_eq(sfx.stream.resource_path, "res://assets/audio/day-transition.wav")
    world.hud.show_feedback(GameRules.CommandCode.FINALE_TRIGGERED)
    assert_eq(sfx.stream.resource_path, "res://assets/audio/finale.wav")
    world.hud.show_feedback(GameRules.CommandCode.INSUFFICIENT_STAMINA)
    assert_eq(sfx.stream.resource_path, "res://assets/audio/cancel.wav")


func test_escape_over_morning_summary_keeps_lock_and_help_hidden() -> void:
    var world := _world()
    var hud := _hud(world)
    var snapshot := world._session.snapshot()
    snapshot["pending_morning_summary"] = {"completed_day": 1, "next_day": 2}
    hud.render(snapshot)
    assert_true(_panel(hud, "MorningSummaryPanel").visible)

    await _press_escape()

    assert_true(_panel(hud, "MorningSummaryPanel").visible)
    assert_false(_panel(hud, "PausePanel").visible)
    assert_false(world._world_input_enabled)
