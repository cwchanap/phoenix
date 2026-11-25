extends SceneTree

class IsoAStar extends AStarGrid2D:
    func _compute_cost(from_id: Vector2i, to_id: Vector2i) -> float:
        return _projected_cost(to_id - from_id)

    func _estimate_cost(from_id: Vector2i, end_id: Vector2i) -> float:
        return _projected_cost(end_id - from_id)

    func _projected_cost(delta: Vector2i) -> float:
        return WorldMath.grid_delta_to_world(Vector2(delta)).length()

const REOPENED_CELLS: Array[Vector2i] = [
    Vector2i(42, 0),
    Vector2i(43, 0),
    Vector2i(42, 1),
    Vector2i(43, 1),
    Vector2i(42, 2),
    Vector2i(43, 2),
    Vector2i(23, 35),
    Vector2i(24, 35),
]
const FENCE_GATES: Array[Vector2i] = [
    Vector2i(18, 10),
    Vector2i(23, 14),
    Vector2i(24, 14),
    Vector2i(30, 11),
    Vector2i(30, 12),
    Vector2i(21, 20),
    Vector2i(21, 21),
]
const DOOR_START := Vector2i(23, 10)

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

func _cell_blocked(cell: Vector2i, footprints: Array) -> bool:
    var half := WorldContract.PLAYER_HALF_EXTENT
    var box := Rect2(
        Vector2(cell) + Vector2.ONE * (0.5 - half),
        Vector2.ONE * half * 2.0,
    )
    for footprint: Rect2 in footprints:
        if box.intersects(footprint):
            return true
    return false

func _flood_reachable(map_size: Vector2i, start: Vector2i, footprints: Array) -> Dictionary:
    var reached := {}
    if _cell_blocked(start, footprints):
        return reached
    var queue: Array[Vector2i] = [start]
    reached[start] = true
    while not queue.is_empty():
        var cell: Vector2i = queue.pop_back()
        for direction in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
            var next: Vector2i = cell + direction
            if (
                next.x < 0
                or next.y < 0
                or next.x >= map_size.x
                or next.y >= map_size.y
            ):
                continue
            if reached.has(next) or _cell_blocked(next, footprints):
                continue
            reached[next] = true
            queue.append(next)
    return reached

func _expect_stand_reachable(reached: Dictionary, target: Vector2i, label: String) -> bool:
    for facing in WorldMath.TARGET_OFFSETS:
        if reached.has(target - WorldMath.TARGET_OFFSETS[facing]):
            return true
    return _expect(false, "%s: no reachable facing stand for %s" % [label, target])

## Every coarse physical blocker: blocking terrain cells, every blocking prop
## footprint, all 85 fence cells and the four perimeter bands.
func _physical_footprints(include_interactables := true) -> Array[Rect2]:
    var footprints: Array[Rect2] = []
    for y in WorldContract.MAP_SIZE.y:
        for x in WorldContract.MAP_SIZE.x:
            if WorldContract.blocks_movement(Vector2i(x, y)):
                footprints.append(Rect2(x, y, 1, 1))
    for entry in WorldContract.blocking_props():
        if not include_interactables and entry["node"] in ["Shipping", "Truck"]:
            continue
        footprints.append(entry["footprint"])
    footprints.append_array(WorldContract.fence_footprints())
    footprints.append_array(WorldContract.perimeter_footprints(WorldContract.MAP_SIZE))
    return footprints

func _free_cell_count(footprints: Array) -> int:
    var count := 0
    for y in WorldContract.MAP_SIZE.y:
        for x in WorldContract.MAP_SIZE.x:
            if not _cell_blocked(Vector2i(x, y), footprints):
                count += 1
    return count

func _iso_grid(footprints: Array) -> IsoAStar:
    var grid := IsoAStar.new()
    grid.region = Rect2i(Vector2i.ZERO, WorldContract.MAP_SIZE)
    grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
    grid.update()
    for y in WorldContract.MAP_SIZE.y:
        for x in WorldContract.MAP_SIZE.x:
            grid.set_point_solid(Vector2i(x, y), _cell_blocked(Vector2i(x, y), footprints))
    return grid

func _path_cost(path: Array[Vector2i]) -> float:
    var total := 0.0
    for index in range(1, path.size()):
        total += WorldMath.grid_delta_to_world(Vector2(path[index] - path[index - 1])).length()
    return total

func _init() -> void:
    if not _expect(WorldContract.MAP_SIZE == Vector2i(48, 40), "map size contract"):
        return
    if not _expect(WorldContract.TILE_SIZE == Vector2(64.0, 32.0), "tile size contract"):
        return
    if not _expect(WorldContract.PROJECTION_ORIGIN == Vector2(768.0, 0.0), "origin contract"):
        return
    if not _expect(WorldContract.PLAYER_SPAWN == Vector2(23.5, 11.5), "spawn contract"):
        return
    if not _expect(is_equal_approx(WorldContract.PLAYER_HALF_EXTENT, 0.18), "player extent contract"):
        return
    if not _expect(is_equal_approx(WorldContract.MOVE_SPEED, 96.0), "move speed contract"):
        return
    if not _expect(is_equal_approx(WorldContract.CAMERA_TOP_PADDING, 96.0), "camera padding contract"):
        return
    if not _expect(
        WorldMath.map_camera_bounds(WorldContract.MAP_SIZE)
        == Rect2(-512.0, -96.0, 2816.0, 1504.0),
        "camera bounds derive from the 48x40 map without a second top padding",
    ):
        return
    if not _expect(WorldContract.FARM_PATCH == Rect2i(15, 19, 6, 5), "farm patch contract"):
        return
    if not _expect(
        WorldContract.HOUSE_FOOTPRINT == Rect2(22.0, 7.0, 3.0, 3.0), "house footprint contract"
    ):
        return
    if not _expect(WorldContract.BED_CELL == Vector2i(23, 10), "bed cell contract"):
        return
    if not _expect(WorldContract.SHIPPING_CELL == Vector2i(22, 19), "shipping cell contract"):
        return
    if not _expect(
        WorldContract.SHIPPING_FOOTPRINT == Rect2(22.0, 19.0, 1.0, 1.0),
        "shipping footprint is the full approved cell, not the old 0.6 inset",
    ):
        return
    if not _expect(WorldContract.TRUCK_CELL == Vector2i(33, 12), "farm truck cell contract"):
        return
    if not _expect(
        WorldContract.TRUCK_ARRIVAL == Vector2i(32, 13), "farm truck arrival contract"
    ):
        return
    if not _expect(
        WorldContract.TRUCK_FOOTPRINT == Rect2(33.0, 12.0, 1.0, 1.0),
        "farm truck footprint contract",
    ):
        return
    if not _expect(TownContract.MAP_SIZE == Vector2i(16, 12), "town map size contract"):
        return
    if not _expect(TownContract.TRUCK_CELL == Vector2i(2, 9), "town truck cell contract"):
        return
    if not _expect(
        TownContract.TRUCK_ARRIVAL == Vector2i(3, 8), "town truck arrival contract"
    ):
        return
    if not _expect(
        TownContract.TRUCK_FOOTPRINT == Rect2(2.0, 9.0, 1.0, 1.0),
        "town truck footprint contract",
    ):
        return
    if not _expect(
        TownContract.STATION_FOOTPRINT == Rect2(1.85, 3.85, 1.3, 1.3),
        "station footprint contract",
    ):
        return
    if not _expect(
        TownContract.SHOP_FOOTPRINT == Rect2(6.85, 2.85, 1.3, 1.3),
        "town shop footprint contract",
    ):
        return
    if not _expect(
        TownContract.CAFE_FOOTPRINT == Rect2(10.85, 2.85, 1.3, 1.3),
        "cafe footprint contract",
    ):
        return
    if not _expect(
        TownContract.MARKET_FOOTPRINT == Rect2(12.85, 5.85, 1.3, 1.3),
        "town market footprint contract",
    ):
        return
    if not _expect(TownContract.SHOP_CELL == Vector2i(7, 4), "town shop cell contract"):
        return
    if not _expect(TownContract.MARKET_CELL == Vector2i(13, 7), "town market cell contract"):
        return
    if not _expect(
        TownContract.VILLAGER_CELLS == [Vector2i(9, 4), Vector2i(5, 7), Vector2i(11, 6)],
        "town villager cells contract",
    ):
        return
    if not _expect(
        TownContract.VILLAGER_FOOTPRINTS
        == [Rect2(9.2, 4.2, 0.6, 0.6), Rect2(5.2, 7.2, 0.6, 0.6), Rect2(11.2, 6.2, 0.6, 0.6)],
        "town villager footprints contract",
    ):
        return
    if not _expect(
        TownContract.villager_at(Vector2i(9, 4)) == VillagerRules.VillagerId.SHOPKEEPER
        and TownContract.villager_at(Vector2i(5, 7)) == VillagerRules.VillagerId.FARMER
        and TownContract.villager_at(Vector2i(11, 6)) == VillagerRules.VillagerId.RESIDENT
        and TownContract.villager_at(Vector2i(0, 0)) == -1
        and TownContract.villager_at(null) == -1,
        "town villager lookup",
    ):
        return
    if not _expect(
        TownContract.CAMERA_BOUNDS == Rect2(384.0, -96.0, 896.0, 544.0),
        "town camera bounds contract",
    ):
        return
    if not _expect(
        WorldContract.prop_footprint("Storehouse") == Rect2(12.0, 8.0, 5.0, 4.0)
        and WorldContract.bamboo_cells().size() == 18,
        "prop_footprint lookup and 18 bamboo grove cells",
    ):
        return
    var house_fp := WorldContract.HOUSE_FOOTPRINT
    if not _expect(
        WorldMath.is_in_front_of_footprint(Vector2(23.5, 10.18), house_fp)
        and WorldMath.is_in_front_of_footprint(Vector2(25.18, 8.5), house_fp)
        and not WorldMath.is_in_front_of_footprint(Vector2(21.5, 9.5), house_fp)
        and not WorldMath.is_in_front_of_footprint(Vector2(23.5, 6.8), house_fp)
        and not WorldMath.is_in_front_of_footprint(Vector2(25.2, 6.5), house_fp),
        "is_in_front_of_footprint matches isometric front edges",
    ):
        return
    if not _expect(
        TownContract.CAMERA_BOUNDS == WorldMath.map_camera_bounds(TownContract.MAP_SIZE),
        "frozen town camera bounds must equal derived map camera bounds",
    ):
        return
    var expected_perimeter: Array[Rect2] = [
        Rect2(0.0, -1.0, 48.0, 1.0),
        Rect2(48.0, 0.0, 1.0, 40.0),
        Rect2(0.0, 40.0, 48.0, 1.0),
        Rect2(-1.0, 0.0, 1.0, 40.0),
    ]
    if not _expect(
        WorldContract.perimeter_footprints(WorldContract.MAP_SIZE) == expected_perimeter,
        "perimeter footprints contract",
    ):
        return
    var expected_town_perimeter: Array[Rect2] = [
        Rect2(0.0, -1.0, 16.0, 1.0),
        Rect2(16.0, 0.0, 1.0, 12.0),
        Rect2(0.0, 12.0, 16.0, 1.0),
        Rect2(-1.0, 0.0, 1.0, 12.0),
    ]
    if not _expect(
        WorldContract.perimeter_footprints(TownContract.MAP_SIZE) == expected_town_perimeter,
        "town perimeter footprints contract",
    ):
        return

    # --- Terrain: 28 ordered last-writer-wins rects ---
    if not _expect(WorldContract.TERRAIN_RECTS.size() == 28, "28 ordered terrain rects"):
        return
    if not _expect(
        WorldContract.TERRAIN_BLOCKING_MATERIALS == ["bamboo", "forest", "paddy", "reeds", "water"],
        "terrain blocking material list",
    ):
        return
    for cell in REOPENED_CELLS:
        if not _expect(
            not WorldContract.blocks_movement(cell),
            "road/pier stroke must reopen %s through the blocking band" % cell,
        ):
            return
    if not _expect(WorldContract.material_at(Vector2i(42, 0)) == "road", "road reopens forest"):
        return
    if not _expect(WorldContract.material_at(Vector2i(23, 35)) == "pier", "pier reopens water"):
        return
    # A later stroke wins even when an earlier rect also covers the cell.
    if not _expect(
        WorldContract.material_at(Vector2i(18, 8)) == "yard",
        "yard stroke wins over the earlier lot",
    ):
        return
    if not _expect(
        WorldContract.material_at(Vector2i(15, 19)) == "field",
        "field stroke wins over the earlier fallow-free grass",
    ):
        return
    # Outside the map the lookup clamps to the edge cell instead of inventing
    # grass or a shore.
    if not _expect(
        WorldContract.material_at(Vector2i(-5, 10)) == WorldContract.material_at(Vector2i(0, 10)),
        "out-of-map lookup clamps to the west edge material",
    ):
        return
    if not _expect(
        WorldContract.material_at(Vector2i(60, 60))
        == WorldContract.material_at(WorldContract.MAP_SIZE - Vector2i.ONE),
        "out-of-map lookup clamps to the south-east corner material",
    ):
        return

    # --- Fences: 12 straight approved runs, 35 bamboo + 50 wood cells ---
    var runs := WorldContract.fence_runs()
    if not _expect(runs.size() == 12, "12 straight fence runs"):
        return
    var bamboo_cells: Array[Vector2i] = []
    var wood_cells: Array[Vector2i] = []
    for run in runs:
        var target: Array[Vector2i] = bamboo_cells if run["material"] == "bamboo" else wood_cells
        for index in int(run["length"]):
            target.append(run["start"] + run["step"] * index)
    if not _expect(bamboo_cells.size() == 35, "35 bamboo fence cells"):
        return
    if not _expect(wood_cells.size() == 50, "50 wooden fence cells"):
        return
    var fence_cells := WorldContract.fence_cells()
    if not _expect(fence_cells.size() == 85, "85 occupied fence cells"):
        return
    if not _expect(WorldContract.fence_footprints().size() == 85, "85 fence footprints"):
        return
    var unique_cells := {}
    for cell in fence_cells:
        unique_cells[cell] = true
    if not _expect(unique_cells.size() == 85, "fence runs never overlap"):
        return
    for gate in FENCE_GATES:
        if not _expect(not fence_cells.has(gate), "approved fence gate %s stays open" % gate):
            return

    # --- Blocking props: full approved footprints and exact 1x1s ---
    var props := WorldContract.blocking_props()
    if not _expect(props.size() == 47, "47 blocking sprite roots"):
        return
    var one_by_one := 0
    for entry in props:
        var footprint: Rect2 = entry["footprint"]
        if footprint.size == Vector2.ONE:
            one_by_one += 1
            if not _expect(
                footprint == Rect2(footprint.position, Vector2.ONE)
                and footprint.position == footprint.position.floor(),
                "%s uses the exact approved 1x1 cell footprint" % entry["node"],
            ):
                return
    if not _expect(one_by_one == 41, "41 exact 1x1 blocking prop footprints"):
        return
    var prop_lookup := {}
    for entry in props:
        prop_lookup[entry["node"]] = entry["footprint"]
    if not _expect(prop_lookup["House"] == Rect2(22, 7, 3, 3), "house approved footprint"):
        return
    if not _expect(prop_lookup["Workbench"] == Rect2(27, 10, 1, 1), "workbench full-cell footprint"):
        return
    if not _expect(
        prop_lookup["Shipping"] == Rect2(22, 19, 1, 1), "shipping bin full-cell footprint"
    ):
        return
    if not _expect(prop_lookup["Truck"] == Rect2(33, 12, 1, 1), "farm truck full-cell footprint"):
        return
    if not _expect(prop_lookup["Storehouse"] == Rect2(12, 8, 5, 4), "storehouse footprint"):
        return
    if not _expect(prop_lookup["Greenhouse"] == Rect2(27, 19, 5, 4), "greenhouse footprint"):
        return
    if not _expect(prop_lookup["Shrine"] == Rect2(6, 4, 2, 2), "shrine footprint"):
        return
    if not _expect(prop_lookup["Camphor"] == Rect2(36, 7, 2, 2), "camphor footprint"):
        return

    # --- Interact regions: a real area each, and the door slice not the origin ---
    var regions := WorldContract.interact_regions()
    if not _expect(regions.size() == 3, "three farm E regions"):
        return
    for region in regions:
        if not _expect(
            region["footprint"].has_area(),
            "farm E region %s must have area" % region["cell"],
        ):
            return
    if not _expect(
        WorldContract.bed_contact_footprint() == Rect2(23.0, 9.75, 1.0, 0.25),
        "bed contact is the narrow southern house slice",
    ):
        return
    if not _expect(
        WorldContract.bed_contact_footprint().has_area(),
        "bed contact slice keeps a physical area",
    ):
        return
    if not _expect(
        regions[0]["footprint"] == WorldContract.bed_contact_footprint(),
        "bed E region uses the door slice",
    ):
        return
    for cell in WorldContract.RIVER_RIPPLE_CELLS:
        if not _expect(
            WorldContract.material_at(cell) == "water",
            "river ripple cell %s must sit on contract water" % cell,
        ):
            return

    var farm_cells := WorldContract.farm_cells()
    if not _expect(farm_cells.size() == 30, "farm cell count"):
        return
    if not _expect_vec2i(farm_cells[0], Vector2i(15, 19), "first farm cell"):
        return
    if not _expect_vec2i(farm_cells[29], Vector2i(20, 23), "last farm cell"):
        return

    for point in [Vector2(0.0, 0.0), Vector2(23.5, 11.5), Vector2(48.0, 40.0)]:
        var projected := WorldMath.grid_to_world(point)
        var round_trip := WorldMath.world_to_grid(projected)
        if not _expect_vec2(round_trip, point, "fractional round trip %s" % point):
            return

    var edge_cases := [
        [Vector2(0.5, 0.5), Vector2i(0, 0)],
        [Vector2(47.5, 39.5), Vector2i(47, 39)],
        [Vector2(0.5, 10.5), Vector2i(0, 10)],
        [Vector2(23.5, 10.5), Vector2i(23, 10)],
        [Vector2(12.5, 0.5), Vector2i(12, 0)],
        [Vector2(12.5, 39.5), Vector2i(12, 39)],
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
        WorldMath.target_cell(player, WorldMath.Facing.UP, WorldContract.MAP_SIZE) == Vector2i(4, 4),
        "up target",
    ):
        return
    if not _expect(
        WorldMath.target_cell(player, WorldMath.Facing.RIGHT, WorldContract.MAP_SIZE) == Vector2i(6, 4),
        "right target",
    ):
        return
    if not _expect(
        WorldMath.target_cell(player, WorldMath.Facing.DOWN, WorldContract.MAP_SIZE) == Vector2i(6, 6),
        "down target",
    ):
        return
    if not _expect(
        WorldMath.target_cell(player, WorldMath.Facing.LEFT, WorldContract.MAP_SIZE) == Vector2i(4, 6),
        "left target",
    ):
        return
    if not _expect(
        WorldMath.target_cell(Vector2(0.25, 0.25), WorldMath.Facing.UP, WorldContract.MAP_SIZE) == null,
        "off-map target",
    ):
        return
    if not _expect(
        WorldMath.target_cell(Vector2(47.75, 39.75), WorldMath.Facing.DOWN, WorldContract.MAP_SIZE) == null,
        "expanded off-map corner target",
    ):
        return
    if not _expect(
        WorldMath.target_cell(Vector2(46.5, 37.5), WorldMath.Facing.DOWN, WorldContract.MAP_SIZE) == Vector2i(47, 38),
        "expanded in-bounds south-east target",
    ):
        return
    if not _expect(
        WorldMath.target_cell(Vector2(22.5, 17.5), WorldMath.Facing.DOWN, TownContract.MAP_SIZE) == null,
        "same position is off the smaller town map",
    ):
        return
    if not _expect(
        WorldMath.target_cell(Vector2(14.5, 10.5), WorldMath.Facing.DOWN, TownContract.MAP_SIZE) == Vector2i(15, 11),
        "town in-bounds south-east target",
    ):
        return

    if not _expect_polygon(
        WorldMath.footprint_to_polygon(WorldContract.HOUSE_FOOTPRINT),
        PackedVector2Array([
            Vector2(1248.0, 464.0),
            Vector2(1344.0, 512.0),
            Vector2(1248.0, 560.0),
            Vector2(1152.0, 512.0),
        ]),
        "house footprint polygon",
    ):
        return
    if not _expect_polygon(
        WorldMath.centered_player_footprint_polygon(WorldContract.PLAYER_SPAWN),
        PackedVector2Array([
            Vector2(1152.0, 554.24),
            Vector2(1163.52, 560.0),
            Vector2(1152.0, 565.76),
            Vector2(1140.48, 560.0),
        ]),
        "centered player footprint polygon",
    ):
        return
    if not _expect_vec2(
        WorldMath.footprint_ground_anchor(WorldContract.HOUSE_FOOTPRINT),
        Vector2(1248.0, 560.0),
        "derived house ground anchor",
    ):
        return

    # --- Physical reachability: 1,129 coarse cells, 1,127 unoccupied ---
    var coarse_footprints := _physical_footprints(false)
    if not _expect(_free_cell_count(coarse_footprints) == 1129, "1,129 coarse free cells"):
        return
    var physical_footprints := _physical_footprints(true)
    if not _expect(_free_cell_count(physical_footprints) == 1127, "1,127 physically free cells"):
        return
    var reached := _flood_reachable(
        WorldContract.MAP_SIZE, WorldContract.TRUCK_ARRIVAL, physical_footprints
    )
    if not _expect(reached.size() == 1127, "farm flood reaches every physically free cell"):
        return
    var spawn_cell := Vector2i(
        floori(WorldContract.PLAYER_SPAWN.x), floori(WorldContract.PLAYER_SPAWN.y)
    )
    if not _expect(not _cell_blocked(spawn_cell, physical_footprints), "spawn cell is clear"):
        return
    if not _expect(reached.has(spawn_cell), "truck arrival reaches the house spawn"):
        return
    if not _expect(
        not _cell_blocked(WorldContract.TRUCK_ARRIVAL, physical_footprints),
        "truck arrival is clear",
    ):
        return
    if not _expect(
        _cell_blocked(WorldContract.SHIPPING_CELL, physical_footprints),
        "the shipping bin cell is physically occupied",
    ):
        return
    if not _expect(
        _cell_blocked(WorldContract.TRUCK_CELL, physical_footprints),
        "the farm truck cell is physically occupied",
    ):
        return
    for gate in FENCE_GATES:
        if not _expect(reached.has(gate), "approved fence gate %s is physically reachable" % gate):
            return
    for fence_cell in fence_cells:
        if not _expect(
            _cell_blocked(fence_cell, physical_footprints),
            "fence cell %s blocks a player-sized stand" % fence_cell,
        ):
            return
    for cell in farm_cells:
        if not _expect(reached.has(cell), "canonical farm cell %s is reachable" % cell):
            return
    for target in [WorldContract.BED_CELL, WorldContract.SHIPPING_CELL, WorldContract.TRUCK_CELL]:
        if not _expect_stand_reachable(reached, target, "farm target"):
            return
    # Player half-extent clearance: a 1-cell gate admits the centre stand and
    # the adjacent fence cells refuse the same player-sized box.
    for gate in [Vector2i(18, 10), Vector2i(21, 20)]:
        if not _expect(
            not _cell_blocked(gate, physical_footprints),
            "half-extent player fits through the 1-cell gate %s" % gate,
        ):
            return
    if not _expect(
        _cell_blocked(Vector2i(18, 9), physical_footprints)
        and _cell_blocked(Vector2i(18, 11), physical_footprints),
        "the bamboo gate's flanking fence cells stay solid for the player box",
    ):
        return

    # --- Town stays exactly as it was ---
    var town_blockers: Array = [
        TownContract.STATION_FOOTPRINT,
        TownContract.SHOP_FOOTPRINT,
        TownContract.CAFE_FOOTPRINT,
        TownContract.MARKET_FOOTPRINT,
        TownContract.TRUCK_FOOTPRINT,
    ]
    town_blockers.append_array(TownContract.VILLAGER_FOOTPRINTS)
    town_blockers.append_array(WorldContract.perimeter_footprints(TownContract.MAP_SIZE))
    if not _expect(
        not _cell_blocked(TownContract.TRUCK_ARRIVAL, town_blockers),
        "town truck arrival is collision-free",
    ):
        return
    var town_reached := _flood_reachable(
        TownContract.MAP_SIZE, TownContract.TRUCK_ARRIVAL, town_blockers
    )
    var town_walkable := 0
    for y in TownContract.MAP_SIZE.y:
        for x in TownContract.MAP_SIZE.x:
            if not _cell_blocked(Vector2i(x, y), town_blockers):
                town_walkable += 1
    if not _expect(
        town_reached.size() == town_walkable,
        "town flood reaches every walkable cell",
    ):
        return
    var town_targets: Array[Vector2i] = [
        TownContract.SHOP_CELL,
        TownContract.MARKET_CELL,
        TownContract.TRUCK_CELL,
    ]
    town_targets.append_array(TownContract.VILLAGER_CELLS)
    for target in town_targets:
        if not _expect_stand_reachable(town_reached, target, "town target"):
            return

    # --- Iso-weighted A* door routes at 96 px/s (documented +/-0.02 s) ---
    var grid := _iso_grid(physical_footprints)
    var bin_costs: Array[float] = []
    for contact in [Vector2i(22, 18), Vector2i(23, 19)]:
        var bin_path := grid.get_id_path(DOOR_START, contact)
        if not _expect(not bin_path.is_empty(), "bin contact %s has an open route" % contact):
            return
        bin_costs.append(_path_cost(bin_path))
    if not _expect(
        absf(bin_costs.min() / WorldContract.MOVE_SPEED - 3.28) <= 0.02,
        "nearest legal bin contact is ~3.28 s from the door",
    ):
        return
    if not _expect(
        absf(bin_costs.max() / WorldContract.MOVE_SPEED - 3.35) <= 0.02,
        "the second bin contact is ~3.35 s from the door",
    ):
        return
    var truck_costs: Array[float] = []
    var truck_paths := []
    for contact in [Vector2i(32, 13), Vector2i(32, 12)]:
        var truck_path := grid.get_id_path(DOOR_START, contact)
        if not _expect(not truck_path.is_empty(), "truck contact %s has an open route" % contact):
            return
        truck_paths.append(truck_path)
        truck_costs.append(_path_cost(truck_path))
    if not _expect(
        absf(truck_costs.min() / WorldContract.MOVE_SPEED - 3.24) <= 0.02,
        "nearest legal truck contact is ~3.24 s from the door",
    ):
        return
    if not _expect(
        absf(truck_costs.max() / WorldContract.MOVE_SPEED - 3.28) <= 0.02,
        "the second truck contact is ~3.28 s from the door",
    ):
        return
    # The measured routes are the real open gates, not paths through fences.
    var first_truck_path: Array[Vector2i] = truck_paths[0]
    var uses_yard_gate := (
        first_truck_path.has(Vector2i(30, 11)) or first_truck_path.has(Vector2i(30, 12))
    )
    if not _expect(uses_yard_gate, "truck route leaves the yard through the east gate"):
        return
    var bin_path: Array[Vector2i] = grid.get_id_path(DOOR_START, Vector2i(22, 18))
    if not _expect(
        bin_path.has(Vector2i(23, 14)), "bin route leaves the yard through the south gate"
    ):
        return
    for index in range(1, bin_path.size()):
        var step: Vector2i = bin_path[index] - bin_path[index - 1]
        if not _expect(
            absi(step.x) <= 1 and absi(step.y) <= 1,
            "bin route only steps to adjacent cells",
        ):
            return
        if step.x != 0 and step.y != 0:
            if not _expect(
                not grid.is_point_solid(bin_path[index - 1] + Vector2i(step.x, 0))
                and not grid.is_point_solid(bin_path[index - 1] + Vector2i(0, step.y)),
                "bin route never cuts a diagonal corner",
            ):
                return

    print("world math smoke passed")
    quit(0)
