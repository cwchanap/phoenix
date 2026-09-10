extends SceneTree

func _fail(message: String) -> void:
    push_error(message)
    quit(1)

func _expect(condition: bool, message: String) -> bool:
    if condition:
        return true
    _fail(message)
    return false

func _expect_vec2(actual: Vector2, expected: Vector2, label: String) -> bool:
    return _expect(actual.distance_to(expected) <= 1e-4, "%s: %s != %s" % [label, actual, expected])

func _expect_vec2i(actual: Vector2i, expected: Vector2i, label: String) -> bool:
    return _expect(actual == expected, "%s: %s != %s" % [label, actual, expected])

func _expect_polygon(
    actual: PackedVector2Array, expected: PackedVector2Array, label: String
) -> bool:
    if not _expect(actual.size() == expected.size(), "%s: polygon size mismatch" % label):
        return false
    for index in actual.size():
        if not _expect_vec2(actual[index], expected[index], "%s[%d]" % [label, index]):
            return false
    return true

func _init() -> void:
    if not _expect(WorldContract.MAP_SIZE == Vector2i(24, 20), "map size contract"):
        return
    if not _expect(WorldContract.TILE_SIZE == Vector2(64.0, 32.0), "tile size contract"):
        return
    if not _expect(WorldContract.PROJECTION_ORIGIN == Vector2(768.0, 0.0), "origin contract"):
        return
    if not _expect(WorldContract.PLAYER_SPAWN == Vector2(11.5, 8.5), "spawn contract"):
        return
    if not _expect(is_equal_approx(WorldContract.PLAYER_HALF_EXTENT, 0.18), "player extent contract"):
        return
    if not _expect(is_equal_approx(WorldContract.MOVE_SPEED, 96.0), "move speed contract"):
        return
    if not _expect(is_equal_approx(WorldContract.CAMERA_TOP_PADDING, 96.0), "camera padding contract"):
        return
    if not _expect(
        WorldContract.CAMERA_BOUNDS == Rect2(128.0, -96.0, 1408.0, 800.0), "camera bounds contract"
    ):
        return
    if not _expect(WorldContract.FARM_PATCH == Rect2i(4, 10, 6, 5), "farm patch contract"):
        return
    if not _expect(
        WorldContract.HOUSE_FOOTPRINT == Rect2(10.0, 4.0, 4.0, 3.0), "house footprint contract"
    ):
        return
    if not _expect(WorldContract.BED_CELL == Vector2i(12, 7), "bed cell contract"):
        return
    if not _expect(WorldContract.SHOP_CELL == Vector2i(17, 9), "shop cell contract"):
        return
    if not _expect(
        WorldContract.SHOP_STALL_FOOTPRINT == Rect2(15.0, 7.0, 1.0, 2.0),
        "shop stall footprint contract",
    ):
        return
    if not _expect(WorldContract.SHIPPING_CELL == Vector2i(10, 13), "shipping cell contract"):
        return
    if not _expect(
        WorldContract.SHIPPING_FOOTPRINT == Rect2(10.2, 13.2, 0.6, 0.6),
        "shipping footprint contract",
    ):
        return
    if not _expect(WorldContract.MARKET_CELL == Vector2i(19, 10), "market cell contract"):
        return
    if not _expect(
        WorldContract.MARKET_FOOTPRINT == Rect2(19.2, 10.2, 0.6, 0.6), "market footprint contract"
    ):
        return
    if not _expect(
        WorldContract.VILLAGER_CELLS
        == [Vector2i(16, 8), Vector2i(18, 8), Vector2i(17, 11)],
        "villager cells contract",
    ):
        return
    var farm_cells := WorldContract.farm_cells()
    if not _expect(farm_cells.size() == 30, "farm cell count"):
        return
    if not _expect_vec2i(farm_cells[0], Vector2i(4, 10), "first farm cell"):
        return
    if not _expect_vec2i(farm_cells[29], Vector2i(9, 14), "last farm cell"):
        return

    for point in [Vector2(0.0, 0.0), Vector2(11.5, 8.5), Vector2(24.0, 20.0)]:
        var projected := WorldMath.grid_to_world(point)
        var round_trip := WorldMath.world_to_grid(projected)
        if not _expect_vec2(round_trip, point, "fractional round trip %s" % point):
            return

    var edge_cases := [
        [Vector2(0.5, 0.5), Vector2i(0, 0)],
        [Vector2(23.999999, 19.999999), Vector2i(23, 19)],
        [Vector2(0.5, 10.5), Vector2i(0, 10)],
        [Vector2(23.5, 10.5), Vector2i(23, 10)],
        [Vector2(12.5, 0.5), Vector2i(12, 0)],
        [Vector2(12.5, 19.5), Vector2i(12, 19)],
    ]
    for edge_case in edge_cases:
        var cell := WorldMath.grid_cell_at_world(WorldMath.grid_to_world(edge_case[0]))
        if not _expect_vec2i(cell, edge_case[1], "map edge cell %s" % edge_case[0]):
            return

    var epsilon_below := WorldMath.grid_cell_at_world(
        WorldMath.grid_to_world(Vector2(0.999999, 4.5))
    )
    if not _expect_vec2i(epsilon_below, Vector2i(0, 4), "boundary epsilon below"):
        return
    var epsilon_inside := WorldMath.grid_cell_at_world(
        WorldMath.grid_to_world(Vector2(0.9999999995, 4.5))
    )
    if not _expect_vec2i(epsilon_inside, Vector2i(1, 4), "boundary epsilon inside"):
        return

    var diamond := WorldMath.cell_diamond(Vector2i(0, 0))
    if not _expect_polygon(
        diamond,
        PackedVector2Array([
            Vector2(768.0, 0.0),
            Vector2(800.0, 16.0),
            Vector2(768.0, 32.0),
            Vector2(736.0, 16.0),
        ]),
        "cell diamond",
    ):
        return

    if not _expect(
        WorldMath.facing_for_input(Vector2(0.0, -1.0), WorldMath.Facing.DOWN)
            == WorldMath.Facing.UP,
        "up facing",
    ):
        return
    if not _expect(
        WorldMath.facing_for_input(Vector2(1.0, 1.0), WorldMath.Facing.UP)
            == WorldMath.Facing.RIGHT,
        "horizontal tie facing",
    ):
        return
    if not _expect(
        WorldMath.facing_for_input(Vector2(-1.0, -1.0), WorldMath.Facing.DOWN)
            == WorldMath.Facing.LEFT,
        "negative horizontal tie facing",
    ):
        return
    if not _expect(
        WorldMath.facing_for_input(Vector2(0.0, 1.0), WorldMath.Facing.UP)
            == WorldMath.Facing.DOWN,
        "down facing",
    ):
        return
    if not _expect(
        WorldMath.facing_for_input(Vector2(-1.0, 0.0), WorldMath.Facing.RIGHT)
            == WorldMath.Facing.LEFT,
        "left facing",
    ):
        return
    if not _expect(
        WorldMath.facing_for_input(Vector2.ZERO, WorldMath.Facing.UP) == WorldMath.Facing.UP,
        "idle facing retention",
    ):
        return

    var player := Vector2(5.5, 5.5)
    if not _expect(
        WorldMath.target_cell(player, WorldMath.Facing.UP) == Vector2i(4, 4), "up target"
    ):
        return
    if not _expect(
        WorldMath.target_cell(player, WorldMath.Facing.RIGHT) == Vector2i(6, 4), "right target"
    ):
        return
    if not _expect(
        WorldMath.target_cell(player, WorldMath.Facing.DOWN) == Vector2i(6, 6), "down target"
    ):
        return
    if not _expect(
        WorldMath.target_cell(player, WorldMath.Facing.LEFT) == Vector2i(4, 6), "left target"
    ):
        return
    if not _expect(
        WorldMath.target_cell(Vector2(0.25, 0.25), WorldMath.Facing.UP) == null,
        "off-map target",
    ):
        return
    if not _expect(
        WorldMath.target_cell(Vector2(23.75, 19.75), WorldMath.Facing.DOWN) == null,
        "expanded off-map corner target",
    ):
        return
    if not _expect(
        WorldMath.target_cell(Vector2(22.5, 17.5), WorldMath.Facing.DOWN) == Vector2i(23, 18),
        "expanded in-bounds south-east target",
    ):
        return

    if not _expect_polygon(
        WorldMath.footprint_to_polygon(WorldContract.HOUSE_FOOTPRINT),
        PackedVector2Array([
            Vector2(960.0, 224.0),
            Vector2(1088.0, 288.0),
            Vector2(992.0, 336.0),
            Vector2(864.0, 272.0),
        ]),
        "house footprint polygon",
    ):
        return
    if not _expect_polygon(
        WorldMath.footprint_to_polygon(WorldContract.SHOP_STALL_FOOTPRINT),
        PackedVector2Array([
            Vector2(1024.0, 352.0),
            Vector2(1056.0, 368.0),
            Vector2(992.0, 400.0),
            Vector2(960.0, 384.0),
        ]),
        "shop stall footprint polygon",
    ):
        return
    if not _expect_polygon(
        WorldMath.centered_player_footprint_polygon(WorldContract.PLAYER_SPAWN),
        PackedVector2Array([
            Vector2(864.0, 314.24),
            Vector2(875.52, 320.0),
            Vector2(864.0, 325.76),
            Vector2(852.48, 320.0),
        ]),
        "centered player footprint polygon",
    ):
        return

    if not _expect(
        WorldContract.CAMERA_BOUNDS == WorldMath.map_camera_bounds(),
        "frozen camera bounds must equal derived map camera bounds",
    ):
        return
    if not _expect_vec2(
        WorldMath.footprint_ground_anchor(WorldContract.HOUSE_FOOTPRINT),
        Vector2(976.0, 336.0),
        "derived house ground anchor",
    ):
        return
    if not _expect_vec2(
        WorldMath.footprint_ground_anchor(WorldContract.SHOP_STALL_FOOTPRINT),
        Vector2(1008.0, 400.0),
        "derived shop stall ground anchor",
    ):
        return
    if not _expect_vec2(
        WorldContract.MARKET_ANCHOR,
        WorldMath.grid_to_world(Vector2(WorldContract.MARKET_CELL) + Vector2(0.5, 0.5)),
        "market anchor projection",
    ):
        return

    print("world math smoke passed")
    quit(0)
