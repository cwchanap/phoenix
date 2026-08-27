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
