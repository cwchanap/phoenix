# GdUnit4 sample unit test — proves the GdUnit4 runner is wired up.
# The GUT suite under tests/unit and tests/integration remains the source of truth.
class_name WorldMathGdUnitTest
extends GdUnitTestSuite

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
