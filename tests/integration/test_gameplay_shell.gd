extends GutTest

const SETTINGS_PATH := "user://phoenix-task9-gameplay-settings.cfg"
const OVERNIGHT_SAVE_PATH := "user://phoenix-hpa-460-overnight-ownership.json"

func before_each() -> void:
    _clean_settings()

func after_each() -> void:
    _clean_settings()

func _clean_settings() -> void:
    for path in [SETTINGS_PATH, OVERNIGHT_SAVE_PATH]:
        if FileAccess.file_exists(path):
            DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

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
    var badge := world.hud.get_node("HudRoot/Action_1/Badge") as Label
    # Starting seeds are [3, 0, 0]; the badge must track the selected seed, not
    # always Turnip, or cycling `2` shows the wrong quantity.
    world.select_action_slot(2)
    assert_eq(world._session.snapshot()["selected_seed"], &"turnip")
    assert_eq(badge.text, "×3")
    world.select_action_slot(2)
    assert_eq(world._session.snapshot()["selected_seed"], &"potato")
    assert_eq(badge.text, "×0")
    world.select_action_slot(2)
    assert_eq(world._session.snapshot()["selected_seed"], &"pumpkin")
    assert_eq(badge.text, "×0")
    world.select_action_slot(2)
    assert_eq(world._session.snapshot()["selected_seed"], &"turnip")
    assert_eq(badge.text, "×3")

func test_settings_change_keeps_tutorial_card_hidden_under_open_modal() -> void:
    var world := _world()
    if world == null:
        return
    var overlay := world.hud.get_node("HudRoot/OnboardingOverlay") as OnboardingOverlay
    var card := overlay.get_node("TutorialCard") as Control
    assert_true(card.visible, "tutorial card visible before opening modal")
    world.hud.open_pause()
    world.hud.open_settings()
    var settings := world.hud._settings_panel
    assert_true(settings.visible)
    assert_false(card.visible, "modal hides tutorial card")
    # Adjusting a setting re-runs apply_settings -> set_tutorial_cards_enabled,
    # which would re-show the card over the open settings panel unless the
    # settings-change path re-reconciles modal presentation.
    settings._adjust(1)
    assert_true(settings.visible)
    assert_false(card.visible, "tutorial card must stay hidden under open settings")
    # Closing the modal restores normal tutorial visibility.
    world.hud.close_settings()
    world.hud.close_pause()
    assert_false(world.hud.has_blocking_modal())
    assert_true(card.visible, "tutorial card restored after modal closes")

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

func test_thirty_soil_sprites_use_farm_cell_centers() -> void:
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

const ENTITY_STATIC_NAMES := [
    "Player",
    "House",
    "ShopStall",
    "TreeForest",
    "TreeBank",
    "TreeNorth",
    "RockYard",
    "RockMeadow",
    "TreeNorth2",
    "TreeNorth3",
    "TreeNorth4",
    "RockNorth1",
    "TreeNorth5",
    "TreeNorth6",
    "RockNorth2",
    "TreeNorth7",
    "FarmFence_1",
    "FarmFence_2",
    "FarmFence_3",
    "Workbench",
    "VillageSign",
    "Shipping",
    "HarvestMarket",
    "VillagerShopkeeper",
    "VillagerFarmer",
    "VillagerResident",
]

func test_crop_roots_are_direct_entities_children_at_cell_centers() -> void:
    var world := _world()
    if world == null:
        return
    var entities := world.get_node_or_null("Entities") as Node2D
    assert_not_null(entities)
    if entities == null:
        return
    var cells := WorldContract.farm_cells()
    var static_count := ENTITY_STATIC_NAMES.size()
    assert_eq(entities.get_child_count(), static_count + cells.size())
    if entities.get_child_count() < static_count + cells.size():
        return
    for index in static_count:
        assert_eq(String(entities.get_child(index).name), ENTITY_STATIC_NAMES[index])
    for index in cells.size():
        var cell: Vector2i = cells[index]
        var crop_root := entities.get_child(static_count + index) as Node2D
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

func _place_target(
    world: WorldShell,
    target: Vector2i,
    facing := WorldMath.Facing.DOWN,
) -> void:
    var player := world.get_node_or_null("Entities/Player") as PlayerController
    assert_not_null(player)
    if player == null:
        return
    var target_offset: Vector2i = WorldMath.TARGET_OFFSETS[facing]
    var logical_position := Vector2(target - target_offset) + Vector2.ONE * 0.5
    player.global_position = WorldMath.grid_to_world(logical_position)
    player.facing = facing
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
        {"cell": WorldContract.SHOP_CELL, "facing": WorldMath.Facing.UP, "panel": "ShopPanel", "close": "close_shop"},
        {"cell": WorldContract.SHIPPING_CELL, "facing": WorldMath.Facing.DOWN, "panel": "ShippingPanel", "close": "close_shipping"},
        {"cell": WorldContract.BED_CELL, "facing": WorldMath.Facing.UP, "panel": "SleepPanel", "close": "close_sleep_confirmation"},
    ]:
        await _place_target(world, entry["cell"], entry["facing"])
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

func test_shop_four_row_navigation_wraps_and_selected_kind_stays_on_crops() -> void:
    var world := _world()
    if world == null:
        return
    var hud := _hud(world)
    if hud == null:
        return
    hud.render(world._session.snapshot())
    hud.open_shop()
    var panel := _panel(hud, "ShopPanel")
    assert_true(panel.has_method("selected_row"))
    assert_eq(int(panel.call("selected_row")), 0)
    assert_eq(int(panel.call("selected_kind")), GameRules.CropKind.TURNIP)

    for _i in range(3):
        await _press_panel_action("move_down")
    assert_eq(int(panel.call("selected_row")), 3)
    assert_eq(
        int(panel.call("selected_kind")),
        GameRules.CropKind.PUMPKIN,
        "row 3 selection must not leak into the crop kind",
    )

    await _press_panel_action("move_down")
    assert_eq(int(panel.call("selected_row")), 0, "S wraps row 3 to Turnip")
    assert_eq(int(panel.call("selected_kind")), GameRules.CropKind.TURNIP)

    await _press_panel_action("move_up")
    assert_eq(int(panel.call("selected_row")), 3, "W wraps Turnip to row 3")
    assert_eq(int(panel.call("selected_kind")), GameRules.CropKind.TURNIP)

    await _press_panel_action("move_up")
    assert_eq(int(panel.call("selected_row")), 2)
    assert_eq(int(panel.call("selected_kind")), GameRules.CropKind.PUMPKIN)
    hud.close_shop()

func test_shop_upgrade_row_ignores_quantity_keys_and_unaffordable_enter_requests_once() -> void:
    var world := _world()
    if world == null:
        return
    var hud := _hud(world)
    if hud == null:
        return
    var requests: Array[bool] = []
    hud.upgrade_requested.connect(func() -> void: requests.append(true))
    var snapshot := world._session.snapshot()
    snapshot["money"] = 150
    hud.render(snapshot)
    hud.open_shop()
    var panel := _panel(hud, "ShopPanel")
    for _i in range(3):
        await _press_panel_action("move_down")
    assert_eq(int(panel.call("selected_row")), 3)
    var footer := panel.get_node("Frame/Footer/Action") as Label
    assert_eq(footer.text, "BUY · %dG" % GameRules.WATERING_CAN_UPGRADE_PRICE)
    var quantity_before := int(panel.call("selected_quantity"))

    await _press_panel_action("move_left")
    await _press_panel_action("move_right")
    await _press_panel_action("panel_max")
    assert_eq(int(panel.call("selected_quantity")), quantity_before, "A/D/M no-op on row 3")
    assert_eq(footer.text, "BUY · %dG" % GameRules.WATERING_CAN_UPGRADE_PRICE)

    await _press_panel_action("ui_accept")
    assert_eq(requests.size(), 1, "unaffordable Enter still emits one upgrade request")
    hud.close_shop()

func test_shop_upgrade_purchase_refreshes_open_shop_to_55g_owned_and_owned_enter_emits_nothing() -> void:
    var world := _world()
    if world == null:
        return
    var hud := _hud(world)
    if hud == null:
        return
    var state := world._session.state()
    state["money"] = 255
    assert_true(world._session.restore_state(state))
    world._refresh_from_session()
    await _place_target(world, WorldContract.SHOP_CELL, WorldMath.Facing.UP)
    world.interact()
    var shop := _panel(hud, "ShopPanel") as ShopPanel
    assert_true(shop.visible)
    for _i in range(3):
        await _press_panel_action("move_down")
    assert_eq(int(shop.call("selected_row")), 3)

    await _press_panel_action("ui_accept")
    assert_eq(
        int(world._session.snapshot()["money"]),
        255 - GameRules.WATERING_CAN_UPGRADE_PRICE,
    )
    assert_eq((shop.get_node("Frame/Header/MoneyValue") as Label).text, "55")
    assert_eq((shop.get_node("Frame/Footer/Action") as Label).text, "OWNED")

    var requests: Array[bool] = []
    hud.upgrade_requested.connect(func() -> void: requests.append(true))
    await _press_panel_action("ui_accept")
    assert_eq(requests.size(), 0, "owned row Enter emits nothing")
    assert_eq(int(world._session.snapshot()["money"]), 55)
    hud.close_shop()

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
    await _place_target(world, WorldContract.SHOP_CELL, WorldMath.Facing.UP)
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
    await _place_target(world, WorldContract.SHOP_CELL, WorldMath.Facing.UP)
    world.interact()
    var before := world._session.snapshot()
    hud.close_shop()
    assert_true(world._world_input_enabled)
    assert_eq(world._session.snapshot(), before)

func test_successful_shop_refresh_preserves_modal_mask_until_close() -> void:
    var world := _world()
    if world == null:
        return
    var hud := _hud(world)
    if hud == null:
        return
    var tutorial := hud.get_node("HudRoot/OnboardingOverlay/TutorialCard") as Control
    var topbar := hud.get_node("HudRoot/TopBar") as Control
    var resource_strip := hud.get_node("HudRoot/ResourceStrip") as Control
    var hotbar := hud.get_node("HudRoot/Hotbar") as Control

    await _place_target(world, WorldContract.SHOP_CELL, WorldMath.Facing.UP)
    world.interact()
    var shop := _panel(hud, "ShopPanel") as ShopPanel
    assert_true(shop.visible)
    assert_eq(shop.selected_quantity(), 1)
    assert_false(topbar.visible)
    assert_false(tutorial.visible)

    shop.buy_requested.emit(GameRules.CropKind.TURNIP, 1)

    assert_eq(
        int(world._session.snapshot()["money"]),
        150 - GameRules.seed_price(GameRules.CropKind.TURNIP),
    )
    assert_true(shop.visible)
    assert_false(topbar.visible)
    assert_false(resource_strip.visible)
    assert_false(hotbar.visible)
    assert_false(tutorial.visible)

    hud.close_shop()
    assert_true(topbar.visible)
    assert_true(resource_strip.visible)
    assert_true(hotbar.visible)
    assert_true(tutorial.visible)

func test_upgrade_request_chain_gates_target_and_refreshes_hud() -> void:
    var world := _world()
    var hud := _hud(world)
    var shop := _panel(hud, "ShopPanel") as ShopPanel
    var forwarded: Array[bool] = []
    hud.upgrade_requested.connect(func() -> void: forwarded.append(true))
    shop.upgrade_requested.emit()
    assert_eq(forwarded.size(), 1, "ShopPanel upgrade request must forward as GameHud signal")

    var feedback := hud.get_node("HudRoot/Feedback") as Label
    var sfx := hud.get_node("SfxPlayer") as AudioStreamPlayer

    # Wrong target: the shop guard holds and nothing mutates.
    await _place_target(world, WorldContract.farm_cells()[0])
    hud.upgrade_requested.emit()
    assert_eq(feedback.text, "Stand at the shop.")
    assert_false(world._session.snapshot()["watering_can_upgraded"])
    assert_eq(int(world._session.snapshot()["money"]), 150)

    # Funded and standing at the shop: real command runs, HUD refreshes.
    var state := world._session.state()
    state["money"] = 250
    assert_true(world._session.restore_state(state))
    world._refresh_from_session()
    await _place_target(world, WorldContract.SHOP_CELL, WorldMath.Facing.UP)
    hud.upgrade_requested.emit()
    assert_true(world._session.snapshot()["watering_can_upgraded"])
    assert_eq(int(world._session.snapshot()["money"]), 250 - GameRules.WATERING_CAN_UPGRADE_PRICE)
    assert_eq(feedback.text, "Watering can upgraded.")
    assert_eq(sfx.stream.resource_path, "res://assets/audio/commerce.wav")
    assert_eq(
        (hud.get_node("HudRoot/Action_2/Icon") as TextureRect).texture.resource_path,
        "res://assets/ui/icons/watering-can-efficient.png",
    )

    # Repeat purchase: truthful failure text on the cancel path, money intact.
    hud.upgrade_requested.emit()
    assert_eq(feedback.text, "Watering can is already upgraded.")
    assert_eq(sfx.stream.resource_path, "res://assets/audio/cancel.wav")
    assert_eq(int(world._session.snapshot()["money"]), 250 - GameRules.WATERING_CAN_UPGRADE_PRICE)

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
    await _place_target(world, WorldContract.BED_CELL, WorldMath.Facing.UP)
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
    await _place_target(world, WorldContract.SHOP_CELL, WorldMath.Facing.UP)
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
    assert_eq(hint.text, "Space — Till soil · 3 stamina")

    world.use_selected_action()
    world._process(0.0)
    assert_eq(world.player.target_highlight.default_color, PlayerController.TARGET_INVALID)
    assert_eq(hint.text, "Soil is already tilled.")

    world.select_action_slot(2)
    world._process(0.0)
    assert_eq(world.player.target_highlight.default_color, PlayerController.TARGET_VALID)

    await _place_target(world, WorldContract.SHOP_CELL, WorldMath.Facing.UP)
    world._process(0.0)
    assert_eq(world.player.target_highlight.default_color, PlayerController.TARGET_NEUTRAL)
    assert_eq(hint.text, "Shop — E")

func _grow_mature_turnip(world: WorldShell, cell: Vector2i) -> void:
    var session := world._session
    assert_eq(session.hoe(cell), GameRules.CommandCode.SOIL_TILLED)
    assert_eq(session.plant(cell), GameRules.CommandCode.CROP_PLANTED)
    var state := session.state()
    var index := WorldContract.farm_cells().find(cell)
    state["farm"][index]["crop"]["growth"] = GameRules.growth_nights(
        GameRules.CropKind.TURNIP,
    )
    assert_true(session.restore_state(state))
    world._refresh_from_session()

func test_farming_hint_copy_is_action_specific_from_structured_preview() -> void:
    var world := _world()
    var hud := _hud(world)
    var hint := hud.get_node("HudRoot/InteractionHint") as Label
    var cells := WorldContract.farm_cells()

    await _place_target(world, cells[0])
    world._process(0.0)
    assert_eq(hint.text, "Space — Till soil · 3 stamina")

    world.use_selected_action()
    world.select_action_slot(2)
    world._process(0.0)
    assert_eq(hint.text, "Space — Plant Turnip · 1 stamina")

    world.use_selected_action()
    world.select_action_slot(3)
    world._process(0.0)
    assert_eq(hint.text, "Space — Water Turnip · 2 stamina")

    _grow_mature_turnip(world, cells[1])
    world.select_action_slot(4)
    await _place_target(world, cells[1])
    world._process(0.0)
    assert_eq(hint.text, "Space — Harvest Turnip · 1 stamina")

func _readiness_sparkle(world: WorldShell, cell: Vector2i) -> Sprite2D:
    var crop_root := world.farm_view.get_node(
        "FarmCrop_%d_%d" % [cell.x, cell.y],
    ) as Node2D
    return crop_root.get_node("Sprite2D/ReadinessSparkle") as Sprite2D

func _visible_readiness_cue_count(world: WorldShell) -> int:
    var count := 0
    for cell in WorldContract.farm_cells():
        if _readiness_sparkle(world, cell).visible:
            count += 1
    return count

func test_readiness_sparkle_contract_is_peak_frame_at_documented_offset() -> void:
    var world := _world()
    var sparkle := _readiness_sparkle(world, WorldContract.farm_cells()[0])
    assert_eq(FarmView.SPARKLE_CROP_OFFSET, Vector2(0, -44))
    assert_eq(sparkle.texture, preload("res://assets/sprites/polish/harvest-sparkle.png"))
    assert_eq(sparkle.hframes, 3)
    # tests/visual/hpa-458/README.md: frame 1 is the 4-point star peak.
    assert_eq(sparkle.frame, 1)
    assert_eq(sparkle.offset, FarmView.SPARKLE_CROP_OFFSET)
    assert_false(sparkle.visible)

func test_mature_crop_cue_shows_only_while_targeted_regardless_of_tool() -> void:
    var world := _world()
    var cells := WorldContract.farm_cells()
    _grow_mature_turnip(world, cells[0])
    var sparkle := _readiness_sparkle(world, cells[0])
    assert_false(sparkle.visible)

    # Non-Hands tool on a mature crop: the Hoe preview is invalid (CROP_PRESENT)
    # yet readiness must still show.
    world.select_action_slot(1)
    await _place_target(world, cells[0])
    world._process(0.0)
    assert_eq(world.player.target_highlight.default_color, PlayerController.TARGET_INVALID)
    assert_true(sparkle.visible)
    assert_eq(_visible_readiness_cue_count(world), 1)

    await _place_target(world, cells[1])
    world._process(0.0)
    assert_false(sparkle.visible)
    assert_eq(_visible_readiness_cue_count(world), 0)

func test_blocking_modal_clears_mature_readiness_cue() -> void:
    var world := _world()
    var cells := WorldContract.farm_cells()
    _grow_mature_turnip(world, cells[0])
    await _place_target(world, cells[0])
    world._process(0.0)
    assert_true(_readiness_sparkle(world, cells[0]).visible)

    world.hud.open_bag()
    world._process(0.0)
    assert_eq(_visible_readiness_cue_count(world), 0)
    assert_eq((world.hud.get_node("HudRoot/InteractionHint") as Label).text, "")

func test_blocking_intro_never_advertises_farm_action() -> void:
    var world := _locked_world()
    var hud := _hud(world)
    await _place_target(world, WorldContract.farm_cells()[0])
    world._process(0.0)
    assert_eq(world.player.target_highlight.default_color, PlayerController.TARGET_NEUTRAL)
    assert_eq((hud.get_node("HudRoot/InteractionHint") as Label).text, "")

func _farm_effects(world: WorldShell) -> Node2D:
    return world.get_node_or_null("FarmActionEffects") as Node2D

func _await_effects_settled() -> void:
    # Longest effect chain (tool motion + cell strip) stays under 0.6 s.
    await get_tree().create_timer(1.0).timeout

func _fx_name(prefix: String, cell: Vector2i) -> String:
    return "%s_%d_%d" % [prefix, cell.x, cell.y]

func test_successful_till_spawns_transient_tool_and_soil_effects() -> void:
    var world := _world()
    var effects := _farm_effects(world)
    assert_not_null(effects, "FarmActionEffects exists directly under World")
    if effects == null:
        return
    var cell: Vector2i = WorldContract.farm_cells()[0]
    await _place_target(world, cell)
    world.use_selected_action()
    # Observe the real transient nodes immediately after dispatch.
    var impact := effects.get_node_or_null(_fx_name("SoilFx", cell)) as Sprite2D
    assert_not_null(impact, "cell-centered soil impact spawns at the captured cell")
    if impact != null:
        assert_eq(impact.texture.resource_path, "res://assets/sprites/polish/soil-impact.png")
        assert_eq(impact.position, WorldMath.grid_to_world(Vector2(cell) + Vector2(0.5, 0.5)))
        assert_eq(impact.frame, 0)
        assert_eq(impact.scale, Vector2(2, 2))
    var tool := world.player.get_node_or_null("ToolFx") as Sprite2D
    assert_not_null(tool, "tool overlay is a child of the Player root")
    if tool != null:
        assert_eq(tool.texture.resource_path, "res://assets/sprites/polish/hoe-overlay.png")
        # DOWN facing: frame 0 at (4, -16) per the HPA-458 tool-facing contract.
        assert_eq(tool.frame, 0)
        assert_eq(tool.position, Vector2(4, -16))
        assert_false(tool.flip_h)
    await _await_effects_settled()
    assert_null(effects.get_node_or_null(_fx_name("SoilFx", cell)), "cell effect frees")
    assert_null(world.player.get_node_or_null("ToolFx"), "tool overlay frees")

func test_tool_redispatch_inside_tool_motion_stays_error_free() -> void:
    var world := _world()
    var cells: Array = WorldContract.farm_cells()
    await _place_target(world, cells[0])
    world.use_selected_action()
    assert_not_null(world.player.get_node_or_null("ToolFx"))
    # Re-dispatch inside the 150 ms tool motion: the replacement frees the
    # old overlay while its tween's trailing release is still pending.
    await get_tree().create_timer(0.05).timeout
    var offset: Vector2i = WorldMath.TARGET_OFFSETS[WorldMath.Facing.DOWN]
    world.player.global_position = WorldMath.grid_to_world(
        Vector2(cells[1] - offset) + Vector2.ONE * 0.5
    )
    world.player.facing = WorldMath.Facing.DOWN
    world.use_selected_action()
    var replacement := world.player.get_node_or_null("ToolFx") as Sprite2D
    assert_not_null(replacement, "second dispatch replaces the tool overlay")
    if replacement != null:
        assert_false(
            replacement.is_queued_for_deletion(),
            "replacement tool node stays valid",
        )
    await _await_effects_settled()
    assert_null(world.player.get_node_or_null("ToolFx"), "replacement tool frees")

func test_tool_overlay_follows_hpa458_facing_table() -> void:
    var world := _world()
    var effects := _farm_effects(world)
    assert_not_null(effects)
    if effects == null:
        return
    var cells: Array = WorldContract.farm_cells()
    var cases := [
        [WorldMath.Facing.UP, 1, false, Vector2(0, -22)],
        [WorldMath.Facing.RIGHT, 2, false, Vector2(10, -21)],
        [WorldMath.Facing.DOWN, 0, false, Vector2(4, -16)],
        [WorldMath.Facing.LEFT, 2, true, Vector2(-10, -21)],
    ]
    for index in cases.size():
        var entry: Array = cases[index]
        var cell: Vector2i = cells[index]
        await _place_target(world, cell, entry[0])
        world.use_selected_action()
        var tool := world.player.get_node_or_null("ToolFx") as Sprite2D
        assert_not_null(tool, "tool overlay for facing %s" % [entry[0]])
        if tool != null:
            assert_eq(tool.frame, entry[1], "frame for facing %s" % [entry[0]])
            assert_eq(tool.flip_h, entry[2], "flip for facing %s" % [entry[0]])
            assert_eq(tool.position, entry[3], "anchor for facing %s" % [entry[0]])
        await _await_effects_settled()
        assert_null(world.player.get_node_or_null("ToolFx"))

func test_plant_and_water_spawn_their_distinct_cell_effects() -> void:
    var world := _world()
    var effects := _farm_effects(world)
    assert_not_null(effects)
    if effects == null:
        return
    var cell: Vector2i = WorldContract.farm_cells()[0]
    await _place_target(world, cell)
    world.use_selected_action()
    await _await_effects_settled()
    world.select_action_slot(2)
    world.use_selected_action()
    var seed_fx := effects.get_node_or_null(_fx_name("SeedFx", cell)) as Sprite2D
    assert_not_null(seed_fx, "plant spawns the seed drop at the captured cell")
    if seed_fx != null:
        assert_eq(seed_fx.texture.resource_path, "res://assets/sprites/polish/planting-seed.png")
    assert_null(world.player.get_node_or_null("ToolFx"), "plant uses no tool overlay")
    await _await_effects_settled()
    assert_null(effects.get_node_or_null(_fx_name("SeedFx", cell)))

    world.select_action_slot(3)
    await _place_target(world, cell, WorldMath.Facing.RIGHT)
    world.use_selected_action()
    var can := world.player.get_node_or_null("ToolFx") as Sprite2D
    assert_not_null(can, "water spawns the can overlay")
    if can != null:
        assert_eq(can.texture.resource_path, "res://assets/sprites/polish/watering-can-overlay.png")
        assert_eq(can.frame, 2)
        assert_eq(can.position, Vector2(10, -21))
        assert_false(can.flip_h)
    var splash := effects.get_node_or_null(_fx_name("SplashFx", cell)) as Sprite2D
    assert_not_null(splash, "water spawns the splash at the captured cell")
    if splash != null:
        assert_eq(splash.texture.resource_path, "res://assets/sprites/polish/water-splash.png")
        assert_eq(splash.frame, 0)
        assert_eq(splash.scale, Vector2(2, 2))
    await _await_effects_settled()
    assert_null(effects.get_node_or_null(_fx_name("SplashFx", cell)))
    assert_null(world.player.get_node_or_null("ToolFx"))

func test_harvest_effect_keeps_premutation_crop_kind_under_entities() -> void:
    var world := _world()
    var effects := _farm_effects(world)
    assert_not_null(effects)
    if effects == null:
        return
    var cells: Array = WorldContract.farm_cells()
    var cell: Vector2i = cells[1]
    var index := cells.find(cell)
    _grow_mature_turnip(world, cell)
    world.select_action_slot(4)
    assert_eq(world._session.preview_selected_action(cell)["crop"], GameRules.CropKind.TURNIP)
    var rest_children := world.farm_view.get_child_count()
    await _place_target(world, cell)
    world.use_selected_action()
    assert_null(world._session.snapshot()["farm"][index]["crop"], "session refresh removed the crop")
    var pop := world.farm_view.get_node_or_null(_fx_name("HarvestPop", cell)) as Node2D
    assert_not_null(pop, "harvest pop stays under the Entities Y-sort owner")
    if pop != null:
        assert_eq(pop.position, WorldMath.grid_to_world(Vector2(cell) + Vector2(0.5, 0.5)))
        var crop := pop.get_node("Sprite2D") as Sprite2D
        assert_eq(crop.texture.resource_path, "res://assets/sprites/proof-crops.png")
        assert_eq(crop.frame, GameRules.CropKind.TURNIP * 4 + 3, "mature turnip frame")
        var sparkle := crop.get_node("Sparkle") as Sprite2D
        assert_eq(sparkle.texture.resource_path, "res://assets/sprites/polish/harvest-sparkle.png")
        assert_eq(sparkle.offset, FarmView.SPARKLE_CROP_OFFSET)
        assert_not_null(pop.get_node_or_null("PlusOne"))
    await _await_effects_settled()
    assert_null(world.farm_view.get_node_or_null(_fx_name("HarvestPop", cell)), "pop frees")
    assert_eq(world.farm_view.get_child_count(), rest_children, "rest-state Entities list restored")

func test_invalid_farming_commands_spawn_no_effects() -> void:
    var world := _world()
    var effects := _farm_effects(world)
    assert_not_null(effects)
    if effects == null:
        return
    var cell: Vector2i = WorldContract.farm_cells()[0]
    await _place_target(world, cell)
    world.use_selected_action()
    await _await_effects_settled()
    assert_eq(effects.get_child_count(), 0)

    world.use_selected_action()
    assert_eq(world._session.preview_selected_action(cell)["code"], GameRules.CommandCode.ALREADY_TILLED)
    assert_eq(effects.get_child_count(), 0, "blocked till spawns no effect")
    assert_null(world.player.get_node_or_null("ToolFx"))

    await _place_target(world, WorldContract.SHOP_CELL, WorldMath.Facing.UP)
    world.use_selected_action()
    assert_eq(effects.get_child_count(), 0, "non-farm target spawns no effect")
    assert_null(world.player.get_node_or_null("ToolFx"))

func test_farming_success_codes_resolve_to_four_distinct_streams() -> void:
    var world := _world()
    var hud := world.hud
    var hoe := hud._sfx_for_code(GameRules.CommandCode.SOIL_TILLED)
    var plant := hud._sfx_for_code(GameRules.CommandCode.CROP_PLANTED)
    var water := hud._sfx_for_code(GameRules.CommandCode.CROP_WATERED)
    var harvest := hud._sfx_for_code(GameRules.CommandCode.CROP_HARVESTED)
    for stream: AudioStream in [hoe, plant, water, harvest]:
        assert_not_null(stream)
    assert_ne(hoe, plant)
    assert_ne(hoe, water)
    assert_ne(hoe, harvest)
    assert_ne(plant, water)
    assert_ne(plant, harvest)
    assert_ne(water, harvest)
    assert_eq(
        hud._sfx_for_code(GameRules.CommandCode.ACTION_SELECTED),
        hud._sfx_for_code(GameRules.CommandCode.SEED_SELECTED),
        "selection keeps the shared ACTION_SFX",
    )
    assert_eq(
        hud._sfx_for_code(GameRules.CommandCode.ALREADY_TILLED),
        hud._sfx_for_code(GameRules.CommandCode.INSUFFICIENT_STAMINA),
        "failures keep the shared cancel cue",
    )

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
    assert_eq(sfx.stream.resource_path, "res://assets/audio/farm-hoe.wav")
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


## Hold-to-work: deterministic hold-state contract. Hold tests drive
## _advance_action_hold() with explicit deltas and must not let a real frame
## pass while a hold is armed, so placement uses the await-free _set_target
## and presses use the synchronous push_input seam.

func _push_use_action(world: WorldShell, pressed: bool) -> void:
    var event := InputEventAction.new()
    event.action = &"use_action"
    event.pressed = pressed
    world.get_viewport().push_input(event)

func _set_target(
    world: WorldShell,
    target: Vector2i,
    facing := WorldMath.Facing.DOWN,
) -> void:
    var offset: Vector2i = WorldMath.TARGET_OFFSETS[facing]
    world.player.global_position = WorldMath.grid_to_world(
        Vector2(target - offset) + Vector2.ONE * 0.5
    )
    world.player.facing = facing
    world.player.velocity = Vector2.ZERO

func _hold_preview(world: WorldShell, target: Variant) -> Dictionary:
    return world._session.preview_selected_action(target)

func test_hold_fresh_press_attempts_once_and_release_clears_gesture() -> void:
    var world := _world()
    var cells := WorldContract.farm_cells()
    await _place_target(world, cells[0])

    _push_use_action(world, true)
    assert_true(world._session.snapshot()["farm"][0]["tilled"])
    assert_true(world._action_hold_active)
    assert_eq(world._action_hold_target, cells[0])
    assert_eq(world._action_hold_dwell, 0.0)

    _push_use_action(world, false)
    assert_false(world._action_hold_active)
    assert_null(world._action_hold_target)

func test_hold_blocked_press_never_arms_and_unblock_needs_fresh_press() -> void:
    var world := _world()
    var cells := WorldContract.farm_cells()
    await _place_target(world, cells[0])
    world.hud.open_shop()
    assert_false(world._world_input_enabled)

    _push_use_action(world, true)
    assert_false(world._action_hold_active, "press must not touch hold while gated")
    assert_false(world._session.snapshot()["farm"][0]["tilled"])

    world.hud.close_shop()
    assert_true(world._world_input_enabled)
    assert_false(world._advance_action_hold(1.0, cells[0], _hold_preview(world, cells[0])))
    assert_false(world._session.snapshot()["farm"][0]["tilled"])

    _push_use_action(world, true)
    assert_true(world._action_hold_active)
    assert_true(world._session.snapshot()["farm"][0]["tilled"])

func test_hold_same_cell_never_repeats_and_new_target_needs_dwell() -> void:
    var world := _world()
    var cells := WorldContract.farm_cells()
    var first: Vector2i = cells[0]
    var second: Vector2i = cells[1]
    await _place_target(world, first)
    _push_use_action(world, true)
    assert_true(world._session.snapshot()["farm"][0]["tilled"])

    var worked_preview := _hold_preview(world, first)
    assert_eq(worked_preview["code"], GameRules.CommandCode.ALREADY_TILLED)
    for _poll in 10:
        assert_false(world._advance_action_hold(0.05, first, worked_preview))
    assert_false(world._session.snapshot()["farm"][1]["tilled"])

    _set_target(world, second)
    var fresh_preview := _hold_preview(world, second)
    assert_eq(fresh_preview["code"], GameRules.CommandCode.SOIL_TILLED)
    assert_false(world._advance_action_hold(0.14, second, fresh_preview))
    assert_false(world._session.snapshot()["farm"][1]["tilled"])
    assert_false(world._advance_action_hold(0.14, second, fresh_preview))
    assert_false(world._session.snapshot()["farm"][1]["tilled"])
    assert_true(world._advance_action_hold(0.01, second, fresh_preview))
    assert_true(world._session.snapshot()["farm"][1]["tilled"])
    assert_false(world._advance_action_hold(0.5, second, _hold_preview(world, second)))

func test_hold_revisiting_worked_cell_skips_and_later_cell_continues() -> void:
    var world := _world()
    var cells := WorldContract.farm_cells()
    await _place_target(world, cells[0])
    _push_use_action(world, true)

    _set_target(world, cells[1])
    assert_false(world._advance_action_hold(0.0, cells[1], _hold_preview(world, cells[1])))
    assert_true(world._advance_action_hold(0.15, cells[1], _hold_preview(world, cells[1])))
    assert_true(world._session.snapshot()["farm"][1]["tilled"])

    _set_target(world, cells[0])
    var worked_preview := _hold_preview(world, cells[0])
    for _poll in 6:
        assert_false(world._advance_action_hold(0.1, cells[0], worked_preview))

    _set_target(world, cells[2])
    assert_false(world._advance_action_hold(0.14, cells[2], _hold_preview(world, cells[2])))
    assert_false(world._advance_action_hold(0.14, cells[2], _hold_preview(world, cells[2])))
    assert_true(world._advance_action_hold(0.02, cells[2], _hold_preview(world, cells[2])))
    assert_true(world._session.snapshot()["farm"][2]["tilled"])

func test_hold_invalid_and_nonfarm_targets_never_dispatch_or_restart_feedback() -> void:
    var world := _world()
    var hud := _hud(world)
    var cells := WorldContract.farm_cells()
    await _place_target(world, cells[0])
    _push_use_action(world, true)
    assert_true(world._session.snapshot()["farm"][0]["tilled"])
    var feedback := hud.get_node("HudRoot/Feedback") as Label
    var sfx := hud.get_node("SfxPlayer") as AudioStreamPlayer
    assert_eq(feedback.text, "Soil tilled.")
    assert_eq(sfx.stream.resource_path, "res://assets/audio/farm-hoe.wav")

    # Invalid farm target: crop already planted while the Hoe is selected.
    assert_eq(world._session.hoe(cells[1]), GameRules.CommandCode.SOIL_TILLED)
    assert_eq(world._session.plant(cells[1]), GameRules.CommandCode.CROP_PLANTED)
    var invalid_preview := _hold_preview(world, cells[1])
    assert_eq(invalid_preview["code"], GameRules.CommandCode.CROP_PRESENT)
    # Non-farm target alongside it.
    _set_target(world, WorldContract.SHOP_CELL, WorldMath.Facing.UP)
    var shop_preview := _hold_preview(world, WorldContract.SHOP_CELL)
    assert_eq(shop_preview["code"], GameRules.CommandCode.NOT_FARM_CELL)
    var before := world._session.snapshot()

    for _poll in 10:
        assert_false(world._advance_action_hold(0.1, cells[1], invalid_preview))
        assert_false(world._advance_action_hold(0.1, WorldContract.SHOP_CELL, shop_preview))
    assert_eq(world._session.snapshot(), before, "hold polling must not dispatch")
    assert_eq(feedback.text, "Soil tilled.", "feedback text must not restart")
    assert_eq(
        sfx.stream.resource_path,
        "res://assets/audio/farm-hoe.wav",
        "SFX stream must not restart",
    )

    # A later eligible target resets dwell and continues the same hold.
    _set_target(world, cells[2])
    assert_false(world._advance_action_hold(0.14, cells[2], _hold_preview(world, cells[2])))
    assert_false(world._advance_action_hold(0.14, cells[2], _hold_preview(world, cells[2])))
    assert_true(world._advance_action_hold(0.01, cells[2], _hold_preview(world, cells[2])))
    assert_true(world._session.snapshot()["farm"][2]["tilled"])

func test_hold_tool_and_seed_selection_cancel_the_gesture() -> void:
    var world := _world()
    var hud := _hud(world)
    var cells := WorldContract.farm_cells()
    await _place_target(world, cells[0])

    # Tool selection through the slot route.
    _push_use_action(world, true)
    assert_true(world._action_hold_active)
    world.select_action_slot(2)
    assert_false(world._action_hold_active)
    _set_target(world, cells[1])
    assert_false(world._advance_action_hold(1.0, cells[1], _hold_preview(world, cells[1])))
    assert_null(world._session.snapshot()["farm"][1]["crop"])

    # Fresh press plants; the HUD seed-request route clears the new gesture.
    # The row cell is tilled at session level so the press can plant it.
    assert_eq(world._session.hoe(cells[1]), GameRules.CommandCode.SOIL_TILLED)
    _push_use_action(world, true)
    assert_not_null(world._session.snapshot()["farm"][1]["crop"])
    assert_true(world._action_hold_active)
    hud.select_seed_requested.emit(GameRules.CropKind.POTATO)
    assert_false(world._action_hold_active)
    _set_target(world, cells[2])
    assert_false(world._advance_action_hold(1.0, cells[2], _hold_preview(world, cells[2])))
    assert_null(world._session.snapshot()["farm"][2]["crop"])

    # Fresh press arms again (the potato attempt fails but the gesture is
    # live); a seed cycle through the slot route clears it.
    _push_use_action(world, true)
    assert_true(world._action_hold_active)
    world.select_action_slot(2)
    assert_false(world._action_hold_active)

    # ...and the HUD action-request route clears a fresh gesture too.
    _push_use_action(world, true)
    assert_true(world._action_hold_active)
    hud.select_action_requested.emit(GameRules.FarmingAction.HOE)
    assert_false(world._action_hold_active)
    _set_target(world, cells[0])
    assert_false(world._advance_action_hold(1.0, cells[0], _hold_preview(world, cells[0])))

func test_hold_blocking_modal_cancels_and_closing_does_not_resume() -> void:
    var world := _world()
    var cells := WorldContract.farm_cells()
    await _place_target(world, cells[0])
    _push_use_action(world, true)
    assert_true(world._action_hold_active)

    world.hud.open_bag()
    assert_false(world._world_input_enabled)
    assert_false(world._action_hold_active)
    _set_target(world, cells[1])
    assert_false(world._advance_action_hold(1.0, cells[1], _hold_preview(world, cells[1])))
    world.hud.close_bag()
    assert_true(world._world_input_enabled)
    assert_false(world._advance_action_hold(1.0, cells[1], _hold_preview(world, cells[1])))
    assert_null(world._session.snapshot()["farm"][1]["crop"])

func test_hold_focus_loss_and_day_or_finale_gates_clear_the_gesture() -> void:
    var world := _world()
    var cells := WorldContract.farm_cells()
    await _place_target(world, cells[0])

    _push_use_action(world, true)
    world.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
    assert_false(world._action_hold_active)
    _push_use_action(world, false)

    _push_use_action(world, true)
    world.notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
    assert_false(world._action_hold_active)
    _push_use_action(world, false)

    # Successful day transition: the morning-summary gate clears the hold.
    await _place_target(world, WorldContract.BED_CELL, WorldMath.Facing.UP)
    _push_use_action(world, true)
    assert_true(world._action_hold_active)
    world._on_sleep_requested()
    assert_false(world._world_input_enabled)
    assert_false(world._action_hold_active)
    world.hud.morning_summary_acknowledged.emit()
    assert_true(world._world_input_enabled)
    assert_false(world._advance_action_hold(
        1.0, WorldContract.BED_CELL, _hold_preview(world, WorldContract.BED_CELL)
    ))

    # The terminal finale lock cancels through the same gate transition.
    _push_use_action(world, true)
    assert_true(world._action_hold_active)
    world._finale_in_progress = true
    world._refresh_from_session()
    assert_false(world._action_hold_active)
    assert_false(world._advance_action_hold(
        1.0, WorldContract.BED_CELL, _hold_preview(world, WorldContract.BED_CELL)
    ))

func test_upgraded_watering_hold_costs_one_stamina_per_cell() -> void:
    var world := _world()
    var hud := _hud(world)
    var session := world._session
    var cells := WorldContract.farm_cells()

    # Three eligible unwatered crops; prep spends stamina, so restore a full
    # 20 alongside the upgrade funds before purchasing.
    for index in 3:
        assert_eq(session.hoe(cells[index]), GameRules.CommandCode.SOIL_TILLED)
        assert_eq(session.plant(cells[index]), GameRules.CommandCode.CROP_PLANTED)
    var state := session.state()
    state["money"] = 250
    state["stamina"] = 20
    assert_true(session.restore_state(state))
    assert_eq(
        session.buy_watering_can_upgrade(WorldContract.SHOP_CELL),
        GameRules.CommandCode.WATERING_CAN_UPGRADED,
    )
    world._refresh_from_session()
    assert_true(session.snapshot()["watering_can_upgraded"])

    await _place_target(world, cells[0])
    world.select_action_slot(3)
    world._process(0.0)
    var hint := hud.get_node("HudRoot/InteractionHint") as Label
    assert_eq(hint.text, "Space — Water Turnip · 1 stamina")

    assert_eq(int(session.snapshot()["stamina"]), 20)
    _push_use_action(world, true)
    assert_true(session.snapshot()["farm"][0]["crop"]["watered_today"])
    assert_eq(int(session.snapshot()["stamina"]), 19)
    _set_target(world, cells[1])
    assert_false(world._advance_action_hold(0.0, cells[1], _hold_preview(world, cells[1])))
    assert_true(world._advance_action_hold(0.15, cells[1], _hold_preview(world, cells[1])))
    assert_true(session.snapshot()["farm"][1]["crop"]["watered_today"])
    _set_target(world, cells[2])
    assert_false(world._advance_action_hold(0.0, cells[2], _hold_preview(world, cells[2])))
    assert_true(world._advance_action_hold(0.15, cells[2], _hold_preview(world, cells[2])))
    assert_true(session.snapshot()["farm"][2]["crop"]["watered_today"])
    assert_eq(int(session.snapshot()["stamina"]), 17)

func _configured_world(initial_state: Variant, repository: SaveRepository) -> WorldShell:
    var packed := load("res://scenes/world/world.tscn") as PackedScene
    assert_not_null(packed)
    if packed == null:
        return null
    var world := packed.instantiate() as WorldShell
    assert_not_null(world)
    if world == null:
        return null
    world.configure(initial_state, repository)
    add_child_autoqfree(world)
    var accepted := InputEventAction.new()
    accepted.action = &"ui_accept"
    accepted.pressed = true
    world.get_viewport().push_input(accepted)
    var released := InputEventAction.new()
    released.action = &"ui_accept"
    released.pressed = false
    world.get_viewport().push_input(released)
    return world

func test_overnight_save_restores_upgrade_and_efficient_watering() -> void:
    var repository := SaveRepository.new(OVERNIGHT_SAVE_PATH)
    var world := _configured_world(null, repository)
    if world == null:
        return
    var session := world._session
    var cell: Vector2i = WorldContract.farm_cells()[0]
    # Pin the overnight roll so day 2 is sunny and the crop stays waterable.
    session._weather_roll = func() -> float: return 0.9
    assert_eq(session.hoe(cell), GameRules.CommandCode.SOIL_TILLED)
    assert_eq(session.plant(cell), GameRules.CommandCode.CROP_PLANTED)
    var funded := session.state()
    funded["money"] = 250
    assert_true(session.restore_state(funded))

    # Acquire through the real ownership command, then sleep at the bed so
    # the existing overnight path is the one and only save.
    assert_eq(
        session.buy_watering_can_upgrade(WorldContract.SHOP_CELL),
        GameRules.CommandCode.WATERING_CAN_UPGRADED,
    )
    assert_true(session.snapshot()["watering_can_upgraded"])
    await _place_target(world, WorldContract.BED_CELL, WorldMath.Facing.UP)
    world.hud.sleep_requested.emit()
    assert_eq(int(session.snapshot()["day"]), 2)
    assert_eq(session.snapshot()["weather"], &"sunny")

    var loaded := repository.load()
    assert_eq(loaded["status"], &"loaded")
    var saved_state: Dictionary = loaded["state"]
    assert_eq(GameSession.state_error(saved_state), "")
    assert_true(bool(saved_state["watering_can_upgraded"]))

    var restored := GameSession.new(func() -> float: return 0.9)
    assert_true(restored.restore_state(saved_state))
    assert_true(bool(restored.snapshot()["watering_can_upgraded"]))
    assert_eq(int(restored.snapshot()["stamina"]), GameRules.MAX_STAMINA)
    assert_eq(
        restored.acknowledge_morning_summary(),
        GameRules.CommandCode.DAY_STARTED,
    )
    assert_eq(
        restored.select_action(GameRules.FarmingAction.WATERING_CAN),
        GameRules.CommandCode.ACTION_SELECTED,
    )
    var preview := restored.preview_selected_action(cell)
    assert_eq(preview["code"], GameRules.CommandCode.CROP_WATERED)
    assert_eq(preview["cost"], {"minutes": 20, "stamina": 1})
    assert_eq(int(restored.snapshot()["stamina"]), GameRules.MAX_STAMINA)
    assert_eq(restored.water(cell), GameRules.CommandCode.CROP_WATERED)
    assert_eq(int(restored.snapshot()["stamina"]), GameRules.MAX_STAMINA - 1)

    # A fresh gameplay shell restores the loaded state in _ready and renders
    # the efficient icon straight from the snapshot.
    var shell := _configured_world(saved_state, null)
    if shell == null:
        return
    assert_true(bool(shell._session.snapshot()["watering_can_upgraded"]))
    assert_eq(
        (_hud(shell).get_node("HudRoot/Action_2/Icon") as TextureRect).texture.resource_path,
        "res://assets/ui/icons/watering-can-efficient.png",
    )
