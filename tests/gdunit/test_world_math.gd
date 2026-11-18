# GdUnit4 sample unit test — proves the GdUnit4 runner is wired up.
# The GUT suite under tests/unit and tests/integration remains the source of truth.
class_name WorldMathGdUnitTest
extends GdUnitTestSuite

# HPA-743 pure contact seam: WorldMath.closest_contact() and the pinned
# WorldContract.INTERACT_REACH_PIXELS reach. The facing/dot/reach policy is
# deliberately NOT re-exported as public math helpers; it is pinned through
# WorldShell._resolve_interactable() behavior in
# tests/integration/test_gameplay_shell.gd.

## Reference minimum-distance point on the polygon boundary, computed
## edge-by-edge exactly the way closest_contact() must be implemented.
func _reference_closest_point(polygon: PackedVector2Array, position: Vector2) -> Vector2:
	var best := Vector2.ZERO
	var best_distance := INF
	for index in polygon.size():
		var edge_start := polygon[index]
		var edge_end := polygon[(index + 1) % polygon.size()]
		var candidate := Geometry2D.get_closest_point_to_segment(position, edge_start, edge_end)
		var distance := position.distance_to(candidate)
		if distance < best_distance:
			best_distance = distance
			best = candidate
	return best

func test_grid_world_round_trip() -> void:
	var point := Vector2(2.5, 9.5)
	var restored: Vector2 = WorldMath.world_to_grid(WorldMath.grid_to_world(point))
	assert_vector(restored).is_equal_approx(point, Vector2(0.0001, 0.0001))

func test_world_to_grid_at_origin() -> void:
	assert_vector(WorldMath.world_to_grid(WorldContract.PROJECTION_ORIGIN)).is_equal_approx(Vector2.ZERO, Vector2(0.0001, 0.0001))

func test_expanded_map_edge_targeting() -> void:
	assert_that(WorldContract.MAP_SIZE).is_equal(Vector2i(24, 20))
	# Targets inside the expanded east/south margins that the old 12x12 map rejected.
	assert_that(WorldMath.target_cell(Vector2(22.5, 17.5), WorldMath.Facing.DOWN, WorldContract.MAP_SIZE)).is_equal(Vector2i(23, 18))
	assert_that(WorldMath.target_cell(Vector2(23.5, 19.5), WorldMath.Facing.UP, WorldContract.MAP_SIZE)).is_equal(Vector2i(22, 18))
	assert_that(WorldMath.target_cell(Vector2(0.25, 0.25), WorldMath.Facing.UP, WorldContract.MAP_SIZE)).is_null()
	assert_that(WorldMath.target_cell(Vector2(23.75, 19.75), WorldMath.Facing.DOWN, WorldContract.MAP_SIZE)).is_null()

func test_town_map_size_targets_its_own_bounds() -> void:
	assert_that(TownContract.MAP_SIZE).is_equal(Vector2i(16, 12))
	assert_that(WorldMath.target_cell(Vector2(14.5, 10.5), WorldMath.Facing.DOWN, TownContract.MAP_SIZE)).is_equal(Vector2i(15, 11))
	assert_that(WorldMath.target_cell(Vector2(22.5, 17.5), WorldMath.Facing.DOWN, TownContract.MAP_SIZE)).is_null()

func test_frozen_camera_bounds_equal_derived_bounds() -> void:
	assert_that(WorldMath.map_camera_bounds(WorldContract.MAP_SIZE)).is_equal(WorldContract.CAMERA_BOUNDS)
	assert_that(WorldMath.map_camera_bounds(TownContract.MAP_SIZE)).is_equal(Rect2(384.0, -96.0, 896.0, 544.0))

func test_footprint_ground_anchor_matches_spec_anchors() -> void:
	assert_that(WorldMath.footprint_ground_anchor(WorldContract.HOUSE_FOOTPRINT)).is_equal(Vector2(976, 336))
	assert_vector(WorldMath.footprint_ground_anchor(TownContract.SHOP_FOOTPRINT)).is_equal_approx(Vector2(896, 196.8), Vector2(0.0001, 0.0001))
	assert_vector(WorldMath.footprint_ground_anchor(TownContract.MARKET_FOOTPRINT)).is_equal_approx(Vector2(992, 340.8), Vector2(0.0001, 0.0001))

# --- HPA-743: closest-contact seam ---

## Square logical footprint Rect2(5, 5, 2, 2) projected through the locked
## origin: A(768,160) top, B(832,192) east, C(768,224) south, D(704,192) west.
func test_closest_contact_finds_nearest_boundary_point() -> void:
	var footprint := Rect2(5.0, 5.0, 2.0, 2.0)

	# Directly screen-below the south vertex C(768,224): perpendicular feet on
	# both adjacent edges fall past their endpoints, so the vertex answers.
	assert_vector(WorldMath.closest_contact(Vector2(768, 264), footprint)).is_equal_approx(Vector2(768, 224), Vector2(0.0001, 0.0001))

	# Directly screen-east of the east vertex B(832,192).
	assert_vector(WorldMath.closest_contact(Vector2(872, 192), footprint)).is_equal_approx(Vector2(832, 192), Vector2(0.0001, 0.0001))

	# Ten pixels off the middle of the screen lower-left edge D->C: the
	# perpendicular foot itself answers.
	assert_vector(WorldMath.closest_contact(Vector2(731.528, 216.944), footprint)).is_equal_approx(Vector2(736, 208), Vector2(0.01, 0.01))

	# A probe inside the footprint still contacts the boundary (ties across
	# symmetric edges are resolved deterministically; only the distance is
	# pinned here because any minimal edge answers).
	var centre := WorldMath.closest_contact(Vector2(768, 192), footprint)
	assert_float(Vector2(768, 192).distance_to(centre)).is_equal_approx(
		sqrt(819.2), 0.01
	)

func test_closest_contact_matches_geometry2d_reference_on_contract_footprints() -> void:
	var footprints := [
		WorldContract.HOUSE_FOOTPRINT,
		WorldContract.SHIPPING_FOOTPRINT,
		WorldContract.TRUCK_FOOTPRINT,
		TownContract.SHOP_FOOTPRINT,
		TownContract.MARKET_FOOTPRINT,
		TownContract.VILLAGER_FOOTPRINTS[0],
	]
	for footprint: Rect2 in footprints:
		var polygon := WorldMath.footprint_to_polygon(footprint)
		for corner_offset in [
			Vector2(-8.0, -12.0), Vector2(6.0, -4.0), Vector2(14.0, 9.0), Vector2.ZERO,
		]:
			var probe: Vector2 = WorldMath.grid_to_world(footprint.get_center()) + corner_offset
			var got := WorldMath.closest_contact(probe, footprint)
			var expected := _reference_closest_point(polygon, probe)
			assert_vector(got).is_equal_approx(expected, Vector2(0.0001, 0.0001))

func test_interact_reach_pixel_constant_is_pinned() -> void:
	# The near-contact reach itself is the inclusive <= 14 gap pinned by the
	# plan's Decision 1; its boundary behavior is exercised through the
	# resolver in tests/integration/test_gameplay_shell.gd.
	assert_that(WorldContract.INTERACT_REACH_PIXELS).is_equal(14.0)
