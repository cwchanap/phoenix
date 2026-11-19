extends "res://tests/native_tour/rain_tour_base.gd"
## HPA-743 agent-operated native visual tour. Boots the real app windowed on
## the seeded Day-1 farm, then captures 1920x1080 PNGs at named contract-
## derived poses: near-contact E prompts with the gold diamond, one isolated
## wrong-facing E refusal, the foreground fade/restoration pairs (house,
## fence, shipping bin, farm truck, town shop, town station), the farm
## truck's east edge (Linear B2 comparison) and the south-west river corner.
## Interaction behavior is pinned by the GUT/e2e suites; walking is transport
## only, so poses are teleported directly (the integration tables pin each
## pose's overlap/contact behavior — not walk-in reachability or collider
## standoff) and real key input drives every E press and modal. Evidence-only
## one-off like rain_tour.gd: not run in CI. The tour writes a seeded Day-1
## save to PHOENIX_SAVE_PATH and a windowed+English settings fixture to
## PHOENIX_SETTINGS_PATH (prompt text is asserted in English), so the
## operator must supply isolated paths for both.
##
## Env: TOUR_OUT=<png dir>; PHOENIX_SAVE_PATH / PHOENIX_SETTINGS_PATH must
## point into an isolated dir (rain_tour_base refuses the defaults).
## Supported capture environment: a desktop whose usable area holds the
## full windowed 1920x1080 (UiSettings.WINDOW_SIZE).
## Each capture verifies its own 1920x1080 dimensions and the boot check
## fails fast when the environment cannot provide that size.
## Rerun: godot --path . --script res://tests/native_tour/hpa_743_tour.gd

const SEEDED_DAY := 1
const SETTLE_FRAMES := 45  # camera-smoothing convergence
const OCCLUDER_WAIT_MSEC := 4000  # wall-clock deadline for the alpha polls
const TOUR_LABEL := "hpa743"

# Integration-table fade/restore poses (tests/integration/test_gameplay_shell.gd,
# HPA-743 section): each is proven physically reachable and overlap-holding.
const HOUSE_FADE := Vector2(1017.6, 259.2)      # north lawn, behind the house
const HOUSE_RESTORE := Vector2(976.0, 360.0)    # south of the house root
const FENCE_FADE := Vector2(448.0, 320.0)       # behind FarmFence_2
const FENCE_RESTORE := Vector2(448.0, 388.0)    # south of the fence root
const TRUCK_RESTORE := Vector2(1152.0, 544.0)   # south of the truck tip anchor
const SHOP_FADE := Vector2(840.0, 160.0)        # north strip of the Seed Shop
const SHOP_RESTORE := Vector2(864.0, 216.0)     # south of the shop root
const STATION_FADE := Vector2(704.0, 80.0)      # north strip of the Station
const STATION_RESTORE := Vector2(704.0, 140.0)  # south of the station root

var _out_dir: String


func _initialize() -> void:
	_out_dir = OS.get_environment("TOUR_OUT")
	if _out_dir.is_empty():
		_failures.append("TOUR_OUT is empty; captures cannot be written")
	elif DirAccess.make_dir_recursive_absolute(_out_dir) != OK:
		_failures.append("output dir unusable: %s (make_dir failed)" % _out_dir)
	# Both env paths are validated before either fixture write: a launch that
	# is going to be rejected must leave an existing PHOENIX_SAVE_PATH file
	# untouched.
	if (
		not _failures.is_empty()
		or not _require_isolated_paths()
		or not _write_settings_fixture()
		or not _seed_save()
	):
		_finish("tour=hpa-743")
		return
	if not _boot_app():
		return
	_run.call_deferred()


## Tour-owned settings: windowed and English, so the capture size and the
## asserted prompt text are deterministic whatever the desktop locale is.
func _write_settings_fixture() -> bool:
	var settings_path := OS.get_environment("PHOENIX_SETTINGS_PATH")
	var settings := ConfigFile.new()
	settings.set_value("ui", "fullscreen", false)
	settings.set_value("ui", "language", "en")
	var error := settings.save(settings_path)
	if error != OK:
		_failures.append(
			"settings fixture not written: err=%d path=%s" % [error, settings_path]
		)
		return false
	return true


func _seed_save() -> bool:
	var save_path := OS.get_environment("PHOENIX_SAVE_PATH")
	var resolved := ProjectSettings.globalize_path(save_path).simplify_path()
	var default_resolved := (
		ProjectSettings.globalize_path(SaveRepository.DEFAULT_PATH).simplify_path()
	)
	if save_path.is_empty() or resolved == default_resolved:
		_failures.append(
			"PHOENIX_SAVE_PATH must point to an isolated non-default save file"
		)
		return false
	var session := GameSession.new()
	var state := session.state()
	state["day"] = SEEDED_DAY
	state["time_minutes"] = GameRules.DAY_START_MINUTES
	state["stamina"] = GameRules.MAX_STAMINA
	state["weather"] = "sunny"
	state["weather_history"] = []
	for index in SEEDED_DAY:
		state["weather_history"].append("sunny")
	state["intro_acknowledged"] = true
	var error := SessionStateValidator.state_error(state)
	if error != "":
		_failures.append("Seeded state invalid: %s" % error)
		return false
	var save_error := SaveRepository.new(save_path).save(state)
	if save_error != OK:
		_failures.append("Seed save failed: save_error=%d" % save_error)
		return false
	_log("seeded day=%d save at %s" % [SEEDED_DAY, save_path])
	return true


func _run() -> void:
	await _frames(5)
	DisplayServer.window_move_to_foreground()
	await _title_continue()
	await _wait_world()
	await _frames(10)
	DisplayServer.window_move_to_foreground()
	# The captures are pose evidence, not pacing evidence: freeze the passive
	# clock so slow software-rendered frames cannot race the day (the clamp
	# still allows ~1 game-minute per frame at llvmpipe's 6-10 fps). Travel
	# commands add their own TRAVEL_MINUTES independent of this flag.
	_world.clock_running = false

	var window_size := DisplayServer.window_get_size()
	var size_ok := window_size == UiSettings.WINDOW_SIZE
	_expect(
		size_ok,
		"capture environment must hold the full %s windowed (got %s; usable screen area too small)"
			% [str(UiSettings.WINDOW_SIZE), str(window_size)],
	)
	if not size_ok:
		_finish("tour=hpa-743")
		return

	await _phase_farm()
	if not await _phase_travel_to_town():
		_finish("tour=hpa-743")
		return
	await _phase_town()
	if not await _phase_travel_home():
		_finish("tour=hpa-743")
		return
	var house_alpha := await _wait_occluder_alpha("House", 1.0)
	await _shot("40-return-farm-restored")
	_expect(
		house_alpha == 1.0,
		"map swap must restore farm occluders (house alpha %s)" % str(house_alpha),
	)
	_finish("tour=hpa-743")


# --- contact poses ---------------------------------------------------------

## Same derivation as the e2e suite: a footprint edge midpoint pushed a few
## pixels out along its outward screen normal, well inside the 14 px reach.
func _contact_pose(footprint: Rect2, side: int) -> Dictionary:
	var polygon := WorldMath.footprint_to_polygon(footprint)
	var edge_start: Vector2 = polygon[side]
	var edge_end: Vector2 = polygon[(side + 1) % 4]
	var mid := (edge_start + edge_end) * 0.5
	var edge_direction := (edge_end - edge_start).normalized()
	var outward := Vector2(edge_direction.y, -edge_direction.x)
	var center := WorldMath.grid_to_world(footprint.get_center())
	if outward.dot(center - mid) > 0.0:
		outward = -outward
	return {"position": mid + outward * 8.0, "outward": outward}


func _screen_direction(facing: WorldMath.Facing) -> Vector2:
	match facing:
		WorldMath.Facing.UP:
			return Vector2(0, -1)
		WorldMath.Facing.RIGHT:
			return Vector2(1, 0)
		WorldMath.Facing.DOWN:
			return Vector2(0, 1)
	return Vector2(-1, 0)


## Teleport to a near-contact pose and face it. With `faced` the facing must
## be one of the edge's positive-dot facings; otherwise the pose must be a
## negative-dot wrong-facing pose (the refusal case).
func _goto_contact(
	footprint: Rect2, side: int, facing: WorldMath.Facing, faced := true
) -> void:
	var pose := _contact_pose(footprint, side)
	var dot := _screen_direction(facing).dot(-pose["outward"])
	if faced:
		_expect(dot > 0.0, "contact pose facing must see the footprint (side %d)" % side)
	else:
		_expect(dot < 0.0, "wrong-facing pose must not see the footprint (side %d)" % side)
	await _teleport(pose["position"], facing)


func _region_footprint(farm: bool, cell: Vector2i) -> Rect2:
	var regions: Array = (
		WorldContract.interact_regions() if farm else TownContract.interact_regions()
	)
	for region in regions:
		if region["cell"] == cell:
			return region["footprint"]
	_failures.append("no interact region for cell %s (farm=%s)" % [cell, farm])
	return Rect2()


func _teleport(position: Vector2, facing: int) -> void:
	_world.player.velocity = Vector2.ZERO
	_world.player.global_position = position
	_world.player.facing = facing
	await _frames(SETTLE_FRAMES)


# --- farm phase ------------------------------------------------------------

func _phase_farm() -> void:
	# Near-contact E prompts: the gold diamond, prompt and command agree.
	await _goto_contact(
		_region_footprint(true, WorldContract.BED_CELL), 2, WorldMath.Facing.UP
	)
	await _check_prompt("10-farm-bed-contact", "Go to bed")
	await _goto_contact(
		_region_footprint(true, WorldContract.SHIPPING_CELL), 3, WorldMath.Facing.DOWN
	)
	await _check_prompt("11-farm-bin-contact", "Shipping")

	# Fade/restoration pairs from the integration table's named poses.
	await _teleport(HOUSE_FADE, WorldMath.Facing.DOWN)
	await _check_faded("12-house-faded", "House")
	await _teleport(HOUSE_RESTORE, WorldMath.Facing.UP)
	await _check_restored("13-house-restored", "House")
	await _teleport(FENCE_FADE, WorldMath.Facing.DOWN)
	await _check_faded("14-fence-faded", "FarmFence_2")
	await _teleport(FENCE_RESTORE, WorldMath.Facing.UP)
	await _check_restored("15-fence-restored", "FarmFence_2")
	# The bin's cell-centre root: minus-side contact fades, plus-side
	# contact restores in place.
	await _goto_contact(
		WorldContract.SHIPPING_FOOTPRINT, 3, WorldMath.Facing.DOWN
	)
	await _check_faded("16-bin-faded", "Shipping")
	await _goto_contact(
		WorldContract.SHIPPING_FOOTPRINT, 1, WorldMath.Facing.LEFT
	)
	await _check_restored("17-bin-restored", "Shipping")
	# Truck: behind the north face fades; south of the tip anchor restores;
	# the west contact prompt doubles as the east-edge B2 comparison view.
	await _goto_contact(
		WorldContract.TRUCK_FOOTPRINT, 0, WorldMath.Facing.DOWN
	)
	await _check_faded("18-truck-faded", "Truck")
	await _teleport(TRUCK_RESTORE, WorldMath.Facing.UP)
	await _check_restored("19-truck-east-edge-restored", "Truck")
	await _goto_contact(
		WorldContract.TRUCK_FOOTPRINT, 3, WorldMath.Facing.RIGHT
	)
	await _check_prompt("20-truck-east-edge-prompt", "Drive to town")

	# Isolated wrong-facing refusal: same contact pose, opposite facing —
	# no prompt, and E raises the red nothing-to-interact toast.
	await _goto_contact(
		WorldContract.TRUCK_FOOTPRINT, 3, WorldMath.Facing.LEFT, false
	)
	_expect(
		_world.hud.prompt_text() == "",
		"wrong-facing contact must hide the prompt (got '%s')"
			% _world.hud.prompt_text(),
	)
	await _shot("21-truck-wrong-facing-refused")
	await _interact()
	await _frames(10)
	var toast := _world.hud.toast_text()
	_expect(
		toast == "Nothing to interact with.",
		"wrong-facing E must refuse with the red toast (got '%s')" % toast,
	)
	await _shot("22-truck-wrong-facing-toast")

	# South-west river corner: the backdrop must read grass/river, no grey.
	await _teleport(Vector2(352.0, 320.0), WorldMath.Facing.LEFT)
	await _shot("23-farm-southwest-river")


# --- town phase ------------------------------------------------------------

func _phase_town() -> void:
	await _goto_contact(
		_region_footprint(false, TownContract.SHOP_CELL), 2, WorldMath.Facing.UP
	)
	await _check_prompt("30-town-shop-contact", "Seed Shop")
	await _teleport(SHOP_FADE, WorldMath.Facing.DOWN)
	await _check_faded("31-town-shop-faded", "SeedShop")
	await _teleport(SHOP_RESTORE, WorldMath.Facing.UP)
	await _check_restored("32-town-shop-restored", "SeedShop")
	await _teleport(STATION_FADE, WorldMath.Facing.DOWN)
	await _check_faded("33-town-station-faded", "Station")
	await _teleport(STATION_RESTORE, WorldMath.Facing.UP)
	await _check_restored("34-town-station-restored", "Station")
	await _goto_contact(
		_region_footprint(false, TownContract.VILLAGER_CELLS[0]),
		3,
		WorldMath.Facing.RIGHT,
	)
	await _check_prompt("35-town-sato-contact", "Sato-san")


# --- travel ----------------------------------------------------------------

func _phase_travel_to_town() -> bool:
	await _goto_contact(
		WorldContract.TRUCK_FOOTPRINT, 3, WorldMath.Facing.RIGHT
	)
	await _interact()
	if not await _wait_map_location(false):
		return false
	await _frames(SETTLE_FRAMES)
	return true


func _phase_travel_home() -> bool:
	await _goto_contact(
		TownContract.TRUCK_FOOTPRINT, 1, WorldMath.Facing.LEFT
	)
	await _check_prompt("36-town-truck-contact", "Drive home")
	await _interact()
	if not await _wait_map_location(true):
		return false
	await _frames(SETTLE_FRAMES)
	return true


# --- checks & captures -----------------------------------------------------

func _expect(condition: bool, message: String) -> void:
	if condition:
		_log("ok " + message)
	else:
		_failures.append(message)


func _prompt_expectations() -> String:
	var prompt := _world.hud.prompt_text()
	var highlight := _world.player.target_highlight
	var diamond_visible := highlight != null and highlight.visible
	var gold := (
		highlight != null
		and highlight.default_color.is_equal_approx(PlayerController.TARGET_NEUTRAL)
	)
	_expect(
		diamond_visible and gold,
		"contact prompt needs the visible gold diamond (visible=%s color=%s)"
			% [str(diamond_visible), str(highlight.default_color if highlight else null)],
	)
	return prompt


func _check_prompt(shot_name: String, expected_label: String) -> void:
	var prompt := _prompt_expectations()
	_expect(
		prompt == "[E] %s" % expected_label,
		"%s: prompt must read '[E] %s' (got '%s')" % [shot_name, expected_label, prompt],
	)
	await _shot(shot_name)


func _occluder_alpha(prop_name: String) -> float:
	if _world == null or _world._map == null:
		return -1.0
	var sprite := _world._map.get_node_or_null(
		"Entities/%s/Sprite2D" % prop_name
	) as Sprite2D
	if sprite == null:
		_failures.append("%s: occluder sprite missing" % prop_name)
		return -1.0
	return sprite.self_modulate.a


## Bounded wait for the fade to converge: _update_occluder_fade moves alpha by
## `delta` per frame, so a fixed frame count under-waits at high refresh rates
## and over-waits on slow renderers. Poll the sprite itself until the alpha
## arrives — approximately, since the Color channel's float32 storage never
## equals the float64 target exactly — or the wall-clock deadline expires;
## the caller's check then reports whatever alpha remains.
func _wait_occluder_alpha(prop_name: String, expected: float) -> float:
	var deadline_msec := Time.get_ticks_msec() + OCCLUDER_WAIT_MSEC
	var alpha := _occluder_alpha(prop_name)
	while (
		not is_equal_approx(alpha, expected)
		and alpha >= 0.0
		and Time.get_ticks_msec() < deadline_msec
	):
		await process_frame
		alpha = _occluder_alpha(prop_name)
	return alpha


func _check_faded(shot_name: String, prop_name: String) -> void:
	var alpha := await _wait_occluder_alpha(prop_name, WorldShell.FADE_ALPHA)
	_expect(
		absf(alpha - WorldShell.FADE_ALPHA) < 0.01,
		"%s: %s must fade to %s (alpha %s)" % [shot_name, prop_name, WorldShell.FADE_ALPHA, str(alpha)],
	)
	await _shot(shot_name)


func _check_restored(shot_name: String, prop_name: String) -> void:
	var alpha := await _wait_occluder_alpha(prop_name, 1.0)
	_expect(
		absf(alpha - 1.0) < 0.01,
		"%s: %s must restore to opaque (alpha %s)" % [shot_name, prop_name, str(alpha)],
	)
	await _shot(shot_name)


func _shot(shot_name: String) -> void:
	await process_frame
	await process_frame
	var image: Image = root.get_texture().get_image()
	var size := Vector2i(image.get_width(), image.get_height())
	# Check dimensions before saving: a wrong-size capture must not overwrite
	# a valid PNG from an earlier run.
	if size != UiSettings.WINDOW_SIZE:
		_failures.append(
			"capture %s is %s, binding size is %s; not saved"
				% [shot_name, str(size), str(UiSettings.WINDOW_SIZE)]
		)
		return
	var path := "%s/%s-%s.png" % [_out_dir, TOUR_LABEL, shot_name]
	var error := image.save_png(path)
	if error != OK:
		_failures.append("capture %s not saved: save_png err=%d path=%s" % [shot_name, error, path])
	_log("shot %s -> %s (%dx%d) err=%d" % [
		shot_name, path, image.get_width(), image.get_height(), error,
	])
