# GdUnit4 sample unit test — proves the GdUnit4 runner is wired up.
# The GUT suite under tests/unit and tests/integration remains the source of truth.
class_name WorldMathGdUnitTest
extends GdUnitTestSuite

# HPA-743 red-first seam: the pure contact helpers below are implemented by
# Task 2. They are invoked dynamically (Script.call) so this suite still
# compiles and reports a clean per-test failure instead of a parse error
# while the APIs are missing.
var _world_math_script: GDScript = preload("res://scripts/world/world_math.gd")
var _world_contract_script: GDScript = preload("res://scripts/world/world_contract.gd")

func _require_api(script: Script, method: String) -> bool:
	if script.has_method(method):
		return true
	assert_bool(false).override_failure_message(
		"%s.%s() is missing — HPA-743 red-first seam, implemented by Task 2" % [
			script.resource_path.get_file(),
			method,
		],
	).is_true()
	return false

func _require_constant(script: Script, constant: String) -> Variant:
	var constants: Dictionary = script.get_script_constant_map()
	if constants.has(constant):
		return constants[constant]
	assert_bool(false).override_failure_message(
		"%s.%s is missing — HPA-743 red-first seam, implemented by Task 2" % [
			script.resource_path.get_file(),
			constant,
		],
	).is_true()
	return null

func _footprint_polygon(rect: Rect2) -> PackedVector2Array:
	return WorldMath.footprint_to_polygon(rect)

## Reference minimum-distance point on the polygon boundary, computed
## edge-by-edge exactly the way Task 2 must implement the helper.
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

# --- HPA-743 red-first: pure contact seam (Task 2 implements) ---

## Square logical footprint Rect2(5, 5, 2, 2) projected through the locked
## origin: A(768,160) top, B(832,192) east, C(768,224) south, D(704,192) west.
func _probe_polygon() -> PackedVector2Array:
	return _footprint_polygon(Rect2(5.0, 5.0, 2.0, 2.0))

func test_closest_polygon_contact_finds_nearest_boundary_point() -> void:
	if not _require_api(_world_math_script, "closest_polygon_contact"):
		return
	var polygon := _probe_polygon()

	# Directly screen-below the south vertex C(768,224): perpendicular feet on
	# both adjacent edges fall past their endpoints, so the vertex answers.
	var below_south: Variant = _world_math_script.call(
		"closest_polygon_contact", polygon, Vector2(768, 264)
	)
	assert_vector(below_south).is_equal_approx(Vector2(768, 224), Vector2(0.0001, 0.0001))

	# Directly screen-east of the east vertex B(832,192).
	var east_of_b: Variant = _world_math_script.call(
		"closest_polygon_contact", polygon, Vector2(872, 192)
	)
	assert_vector(east_of_b).is_equal_approx(Vector2(832, 192), Vector2(0.0001, 0.0001))

	# Ten pixels off the middle of the screen lower-left edge D->C: the
	# perpendicular foot itself answers.
	var edge_probe: Variant = _world_math_script.call(
		"closest_polygon_contact", polygon, Vector2(731.528, 216.944)
	)
	assert_vector(edge_probe).is_equal_approx(Vector2(736, 208), Vector2(0.01, 0.01))

	# A probe inside the footprint still contacts the boundary (ties across
	# symmetric edges are resolved deterministically; only the distance is
	# pinned here because any minimal edge answers).
	var centre: Variant = _world_math_script.call(
		"closest_polygon_contact", polygon, Vector2(768, 192)
	)
	assert_vector(centre).is_not_null()
	assert_float(Vector2(768, 192).distance_to(centre)).is_equal_approx(
		sqrt(819.2), 0.01
	)

func test_closest_polygon_contact_matches_geometry2d_reference_on_contract_footprints() -> void:
	if not _require_api(_world_math_script, "closest_polygon_contact"):
		return
	var footprints := [
		WorldContract.HOUSE_FOOTPRINT,
		WorldContract.SHIPPING_FOOTPRINT,
		WorldContract.TRUCK_FOOTPRINT,
		TownContract.SHOP_FOOTPRINT,
		TownContract.MARKET_FOOTPRINT,
		TownContract.VILLAGER_FOOTPRINTS[0],
	]
	for footprint in footprints:
		var polygon := _footprint_polygon(footprint)
		for corner_offset in [
			Vector2(-8.0, -12.0), Vector2(6.0, -4.0), Vector2(14.0, 9.0), Vector2.ZERO,
		]:
			var probe: Vector2 = WorldMath.grid_to_world(footprint.get_center()) + corner_offset
			var got: Variant = _world_math_script.call("closest_polygon_contact", polygon, probe)
			var expected := _reference_closest_point(polygon, probe)
			assert_vector(got).is_equal_approx(expected, Vector2(0.0001, 0.0001))

func test_facing_screen_directions_are_screen_cardinal() -> void:
	if not _require_api(_world_math_script, "facing_screen_direction"):
		return
	assert_vector(_world_math_script.call("facing_screen_direction", WorldMath.Facing.UP)).is_equal(Vector2(0, -1))
	assert_vector(_world_math_script.call("facing_screen_direction", WorldMath.Facing.RIGHT)).is_equal(Vector2(1, 0))
	assert_vector(_world_math_script.call("facing_screen_direction", WorldMath.Facing.DOWN)).is_equal(Vector2(0, 1))
	assert_vector(_world_math_script.call("facing_screen_direction", WorldMath.Facing.LEFT)).is_equal(Vector2(-1, 0))

func test_faces_contact_requires_strict_positive_dot_half_plane() -> void:
	if not _require_api(_world_math_script, "faces_contact"):
		return
	# dot > 0 faces the contact.
	assert_bool(_world_math_script.call(
		"faces_contact", WorldMath.Facing.DOWN, Vector2.ZERO, Vector2(0, 10)
	)).is_true()
	# Negative dot looks away.
	assert_bool(_world_math_script.call(
		"faces_contact", WorldMath.Facing.DOWN, Vector2.ZERO, Vector2(0, -10)
	)).is_false()
	# Exactly perpendicular (dot == 0) is refused: strict positivity, no cone.
	assert_bool(_world_math_script.call(
		"faces_contact", WorldMath.Facing.DOWN, Vector2.ZERO, Vector2(10, 0)
	)).is_false()
	# A contact coincident with the player is never "faced": no fallback.
	assert_bool(_world_math_script.call(
		"faces_contact", WorldMath.Facing.DOWN, Vector2(4, 4), Vector2(4, 4)
	)).is_false()

	# Screen-cardinal facings project both positive directions onto each
	# slanted isometric face: standing ten pixels off the middle of the
	# probe polygon's south face, UP and RIGHT face inward, DOWN and LEFT
	# look away.
	var probe := Vector2(731.528, 216.944)
	var contact := Vector2(736, 208)
	assert_bool(_world_math_script.call("faces_contact", WorldMath.Facing.UP, probe, contact)).is_true()
	assert_bool(_world_math_script.call("faces_contact", WorldMath.Facing.RIGHT, probe, contact)).is_true()
	assert_bool(_world_math_script.call("faces_contact", WorldMath.Facing.DOWN, probe, contact)).is_false()
	assert_bool(_world_math_script.call("faces_contact", WorldMath.Facing.LEFT, probe, contact)).is_false()

func test_interact_reach_pixel_constant_is_pinned_and_inclusive() -> void:
	var reach: Variant = _require_constant(_world_contract_script, "INTERACT_REACH_PIXELS")
	if reach == null:
		return
	assert_that(reach).is_equal(14.0)
	if not _require_api(_world_math_script, "is_within_interact_reach"):
		return
	assert_bool(_world_math_script.call("is_within_interact_reach", 0.0)).is_true()
	assert_bool(_world_math_script.call("is_within_interact_reach", 13.9999)).is_true()
	# The boundary itself is inside: near-contact reach is the inclusive
	# <= 14 gap pinned by the plan's Decision 1.
	assert_bool(_world_math_script.call("is_within_interact_reach", 14.0)).is_true()
	assert_bool(_world_math_script.call("is_within_interact_reach", 14.001)).is_false()
