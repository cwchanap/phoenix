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
    if not _expect(WorldContract.MAP_SIZE == Vector2i(12, 12), "map size contract"):
        return
    if not _expect(WorldContract.TILE_SIZE == Vector2(64.0, 32.0), "tile size contract"):
        return
    if not _expect(WorldContract.PROJECTION_ORIGIN == Vector2(384.0, 0.0), "origin contract"):
        return
    if not _expect(WorldContract.PLAYER_SPAWN == Vector2(2.5, 9.5), "spawn contract"):
        return
    if not _expect(is_equal_approx(WorldContract.PLAYER_HALF_EXTENT, 0.18), "player extent contract"):
        return
    if not _expect(is_equal_approx(WorldContract.MOVE_SPEED, 96.0), "move speed contract"):
        return
    if not _expect(
        WorldContract.TREE_FOOTPRINT == Rect2(7.2, 4.2, 0.6, 0.6), "tree footprint contract"
    ):
        return
    if not _expect(WorldContract.TREE_ANCHOR == Vector2(480.0, 192.0), "tree anchor contract"):
        return
    if not _expect(
        WorldContract.BUILDING_FOOTPRINT == Rect2(7.0, 7.0, 2.0, 2.0), "building footprint contract"
    ):
        return
    if not _expect(
        WorldContract.BUILDING_ANCHOR == Vector2(384.0, 288.0), "building anchor contract"
    ):
        return
    if not _expect(is_equal_approx(WorldContract.CAMERA_TOP_PADDING, 96.0), "camera padding contract"):
        return
    if not _expect(
        WorldContract.CAMERA_BOUNDS == Rect2(0.0, -96.0, 768.0, 480.0), "camera bounds contract"
    ):
        return
    if not _expect(
        WorldContract.FARM_PATCH == Rect2i(2, 7, 3, 3), "farm patch contract"
    ):
        return
    if not _expect(WorldContract.PATH_ROW == Rect2i(3, 6, 7, 1), "path row contract"):
        return
    if not _expect(WorldContract.SHOP_CELL == Vector2i(6, 7), "shop cell contract"):
        return
    if not _expect(WorldContract.BED_CELL == Vector2i(6, 8), "bed cell contract"):
        return
    if not _expect(WorldContract.SHIPPING_CELL == Vector2i(6, 10), "shipping cell contract"):
        return
    if not _expect(
        WorldContract.SHIPPING_FOOTPRINT == Rect2(6.2, 10.2, 0.6, 0.6),
        "shipping footprint contract",
    ):
        return
    if not _expect(WorldContract.farm_cells().size() == 9, "farm cell count"):
        return
    if not _expect(WorldContract.path_cells().size() == 7, "path cell count"):
        return

    for point in [Vector2(0.0, 0.0), Vector2(2.5, 9.5), Vector2(12.0, 12.0)]:
        var projected := WorldMath.grid_to_world(point)
        var round_trip := WorldMath.world_to_grid(projected)
        if not _expect_vec2(round_trip, point, "fractional round trip %s" % point):
            return

    var edge_cases := [
        [Vector2(0.5, 0.5), Vector2i(0, 0)],
        [Vector2(11.999999, 11.999999), Vector2i(11, 11)],
        [Vector2(0.5, 6.5), Vector2i(0, 6)],
        [Vector2(11.5, 6.5), Vector2i(11, 6)],
        [Vector2(6.5, 0.5), Vector2i(6, 0)],
        [Vector2(6.5, 11.5), Vector2i(6, 11)],
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
            Vector2(384.0, 0.0),
            Vector2(416.0, 16.0),
            Vector2(384.0, 32.0),
            Vector2(352.0, 16.0),
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

    if not _expect_polygon(
        WorldMath.footprint_to_polygon(WorldContract.TREE_FOOTPRINT),
        PackedVector2Array([
            Vector2(480.0, 182.4),
            Vector2(499.2, 192.0),
            Vector2(480.0, 201.6),
            Vector2(460.8, 192.0),
        ]),
        "tree footprint polygon",
    ):
        return
    if not _expect_polygon(
        WorldMath.footprint_to_polygon(WorldContract.BUILDING_FOOTPRINT),
        PackedVector2Array([
            Vector2(384.0, 224.0),
            Vector2(448.0, 256.0),
            Vector2(384.0, 288.0),
            Vector2(320.0, 256.0),
        ]),
        "building footprint polygon",
    ):
        return
    if not _expect_polygon(
        WorldMath.centered_player_footprint_polygon(WorldContract.PLAYER_SPAWN),
        PackedVector2Array([
            Vector2(160.0, 186.24),
            Vector2(171.52, 192.0),
            Vector2(160.0, 197.76),
            Vector2(148.48, 192.0),
        ]),
        "centered player footprint polygon",
    ):
        return

    print("world math smoke passed")
    quit(0)
