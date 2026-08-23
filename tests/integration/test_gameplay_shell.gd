extends GutTest

func _world() -> WorldShell:
    var packed := load("res://scenes/world/world.tscn") as PackedScene
    assert_not_null(packed)
    if packed == null:
        return null
    var world := packed.instantiate() as WorldShell
    assert_not_null(world)
    if world == null:
        return null
    add_child_autoqfree(world)
    return world

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
    assert_eq(entities.get_child_count(), 4 + cells.size())
    if entities.get_child_count() < 4 + cells.size():
        return
    for index in cells.size():
        var cell: Vector2i = cells[index]
        var crop_root := entities.get_child(4 + index) as Node2D
        assert_not_null(crop_root)
        if crop_root == null:
            continue
        assert_eq(String(crop_root.name), "FarmCrop_%d_%d" % [cell.x, cell.y])
        assert_eq(crop_root.get_parent(), entities)
        assert_true(
            crop_root.position.distance_to(_cell_center(cell)) <= 0.0001,
            "crop %s center" % cell,
        )
        assert_eq(crop_root.get_child_count(), 1)
        var crop_sprite := crop_root.get_child(0) as Sprite2D
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
    assert_true(hud.has_blocking_modal())

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

func test_day_fourteen_shipping_and_sleep_boundary_copy_is_visible() -> void:
    var world := _world()
    if world == null:
        return
    var hud := _hud(world)
    if hud == null:
        return
    var snapshot := world._session.snapshot()
    snapshot["day"] = GameRules.MAX_DAY
    hud.render(snapshot)

    hud.open_shipping()
    var shipping_boundary := _panel(hud, "ShippingPanel").get_node("Boundary") as Label
    assert_true(shipping_boundary.text.contains("pending crops won't settle at this boundary"))

    hud.open_sleep_confirmation()
    var sleep_boundary := _panel(hud, "SleepPanel").get_node("Boundary") as Label
    assert_true(sleep_boundary.text.contains("sleeping cannot advance/pay"))
    hud.show_feedback(GameRules.CommandCode.DAY_LIMIT_REACHED)
    var sleep_feedback := _panel(hud, "SleepPanel").get_node("InlineFeedback") as Label
    assert_true(sleep_feedback.text.contains("cannot advance/pay"))
