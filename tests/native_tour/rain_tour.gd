extends SceneTree
## Agent-operated native visual tour for HPA-860 town rain. Runs the real
## app windowed (not headless), loads the seeded save through the real
## Continue flow, drives real input events, and saves viewport captures as
## PNGs for human/vision review. Read-only toward gameplay: it only presses
## keys, walks, interacts, observes, and quits.
##
## Env: TOUR_WEATHER=rainy|sunny, TOUR_OUT=<png dir>,
## PHOENIX_SAVE_PATH / PHOENIX_SETTINGS_PATH must point into an isolated dir.
##
## Evidence-only one-off: backs the validation note, not maintained or run
## in CI; uses test seams (clock_running opt-out, direct node access) the
## headless suite never touches. Rerun directions live in the note.

const APP_SCENE := preload("res://scenes/app/app.tscn")

var _app: Node
var _world: WorldShell
var _rainy: bool
var _label: String
var _out_dir: String
var _failures: Array[String] = []
var _first_layer_id: int = 0

func _initialize() -> void:
	_label = OS.get_environment("TOUR_WEATHER")
	_rainy = _label == "rainy"
	_out_dir = OS.get_environment("TOUR_OUT")
	if _out_dir.is_empty():
		_failures.append("TOUR_OUT is empty; captures cannot be written")
	elif DirAccess.make_dir_recursive_absolute(_out_dir) != OK:
		_failures.append("output dir unusable: %s (make_dir failed)" % _out_dir)
	# Keep the game window unoccludable: an occluded macOS window stops
	# drawing and every later capture would silently return a stale frame.
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, true)
	_app = APP_SCENE.instantiate()
	_app.name = "App"
	root.add_child.call_deferred(_app)
	_run.call_deferred()

func _run() -> void:
	await _frames(5)
	_log("window_size=%s canvas=%s screen=%s" % [
		str(root.size), str(root.get_visible_rect().size),
		str(DisplayServer.screen_get_usable_rect(0).size),
	])
	# Bring the window forward so the passive clock can run (may fail from a
	# headless desktop; recorded either way).
	DisplayServer.window_move_to_foreground()
	await _title_continue()
	await _wait_world()
	await _frames(10)
	DisplayServer.window_move_to_foreground()

	await _phase_farm()
	await _phase_travel_to_town()
	if _rainy:
		await _phase_town_full()
	else:
		await _phase_town_quick()
	await _phase_travel_home()
	await _frames(30)
	await _shot("90-return-farm")
	_observe("return-farm")
	_finish()

# --- phases ---------------------------------------------------------------

func _phase_farm() -> void:
	await _frames(40)  # let streaks fall / settle
	await _shot("10-farm-spawn")
	_observe("farm-spawn")
	await _frames(15)
	await _shot("11-farm-motion-a")
	await _frames(15)
	await _shot("12-farm-motion-b")
	await _walk_to_grid(Vector2(12.2, 7.9))
	await _face("move_up", 0)
	await _frames(10)
	await _shot("13-farm-bed-house-depth")
	_observe("farm-bed")
	await _walk_to_grid(Vector2(21.4, 10.3))  # floor (21,10); RIGHT offset (+1,-1) -> truck (22,9)
	await _face("move_right", 1)
	await _frames(10)
	await _shot("14-farm-truck-prompt")
	_observe("farm-truck")

func _phase_travel_to_town() -> void:
	await _burst("14-farm-truck-seq", 8)
	_interact()
	await _wait_map_location(false)
	await _burst("20-town-arrival-seq", 12)
	await _frames(18)
	await _shot("20-town-arrival")
	_observe("town-arrival")

func _phase_town_full() -> void:
	# Camera-edge walk with mid-walk captures: rain must track smoothly.
	# Town perimeter bands sit 2 cells inside each edge, so the deepest
	# walkable spot is around (13.2, 9.2) — the south-east band corner.
	await _walk_to_grid(Vector2(13.2, 9.2), true)
	await _shot("21-town-east-edge")
	_observe("town-edge")
	await _walk_to_grid(Vector2(6.4, 5.3))  # floor (6,5); RIGHT -> shop (7,4)
	await _face("move_right", 1)
	await _frames(10)
	await _shot("22-shop-prompt")
	_observe("town-shop-prompt")
	await _interact()
	await _frames(20)
	await _shot("23-shop-modal")
	if not _world.hud.has_blocking_modal():
		_failures.append("shop modal did not open (target %s)" % str(_world.player.current_target_cell()))
	_observe("town-shop-modal")
	await _close_modals()
	# Villager footprints block straight hops: route south of Hana first.
	await _walk_to_grid(Vector2(10.0, 8.0))
	await _walk_to_grid(Vector2(12.45, 7.4))  # floor (12,7); UP offset (-1,-1) -> Hana (11,6)
	await _face("move_up", 0)
	await _frames(10)
	await _shot("24-hana-prompt")
	await _interact()
	await _frames(20)
	await _shot("25-hana-dialogue")
	if not _world.hud.has_blocking_modal():
		_failures.append("hana dialogue did not open (target %s)" % str(_world.player.current_target_cell()))
	await _observe("town-dialogue")
	await _close_modals()
	await _walk_to_grid(Vector2(12.3, 6.3))  # floor (12,6); DOWN offset (1,1) -> market (13,7)
	await _face("move_down", 2)
	await _frames(10)
	await _interact()
	await _frames(8)
	await _shot("26-market-refusal")
	if _world.hud.toast_text().find("Day 14") == -1:
		_failures.append("market refusal toast missing: '%s'" % _world.hud.toast_text())
	await _observe("town-market-refusal")
	await _frames(60)
	await _walk_to_grid(Vector2(10.5, 9.5))  # south lane, clears Gen-san
	await _walk_to_grid(Vector2(3.4, 8.3))  # floor (3,8); LEFT offset (-1,+1) -> town truck (2,9)
	await _face("move_left", 3)
	await _frames(10)
	await _shot("27-town-truck-prompt")
	await _observe("town-truck")

func _phase_town_quick() -> void:
	await _walk_to_grid(Vector2(13.2, 9.2), true)
	await _shot("21-town-east-edge")
	await _observe("town-edge")
	await _walk_to_grid(Vector2(10.5, 9.5))
	await _walk_to_grid(Vector2(3.4, 8.3))  # floor (3,8); LEFT -> town truck (2,9)
	await _face("move_left", 3)
	await _frames(10)
	await _shot("27-town-truck-prompt")
	await _observe("town-truck")

func _phase_travel_home() -> void:
	await _burst("27-town-truck-seq", 8)
	_interact()
	await _wait_map_location(true)
	await _burst("30-return-farm-seq", 12)
	await _frames(10)

# --- helpers --------------------------------------------------------------

func _frames(n: int) -> void:
	for index in n:
		await process_frame

func _shot(shot_name: String) -> void:
	await process_frame
	await process_frame
	_save_image(shot_name, root.get_texture().get_image())

func _burst(tag: String, count: int) -> void:
	# Temporal frame sequence: one capture per frame, in order, so review can
	# check rain renders on every sampled frame across a swap or camera move.
	var previous := PackedByteArray()
	var differing_pairs := 0
	for index in count:
		await process_frame
		var image: Image = root.get_texture().get_image()
		_save_image("%s-f%02d" % [tag, index], image)
		var current := image.get_data()
		if not previous.is_empty() and current != previous:
			differing_pairs += 1
		previous = current
	# Rain animates every drawn frame, so a rainy burst of byte-identical
	# frames means the renderer stalled and the sequence is stale evidence.
	if _rainy and differing_pairs == 0:
		_failures.append("burst %s: %d identical frames; capture looks stale" % [tag, count])
	_log("burst %s: %d/%d differing consecutive pairs" % [tag, differing_pairs, count - 1])

func _save_image(shot_name: String, image: Image) -> void:
	var path := "%s/%s-%s.png" % [_out_dir, _label, shot_name]
	var error := image.save_png(path)
	if error != OK:
		_failures.append("capture %s not saved: save_png err=%d path=%s" % [shot_name, error, path])
	_log("shot %s -> %s (%dx%d) err=%d" % [shot_name, path, image.get_width(), image.get_height(), error])

func _log(message: String) -> void:
	print("TOUR|", message)

func _observe(phase: String) -> void:
	if _world == null:
		_log("OBS %s world=null" % phase)
		return
	var hud := _world.hud
	var rain: AudioStreamPlayer = hud._rain_ambience_player
	var river: AudioStreamPlayer = hud._river_ambience_player
	var falling: bool = _world.rain_layer.is_rain_falling()
	var layer_id: int = _world.rain_layer.get_instance_id()
	_log("OBS " + phase
		+ " | weather=" + str(_session_weather())
		+ " rain_layer_id=" + str(layer_id)
		+ " rain_falling=" + str(falling) + "(expect " + str(_rainy) + ")"
		+ " rain_audio=" + str(rain.playing)
		+ " river_audio=" + str(river.playing)
		+ " tint=" + str(hud._weather_tint.color)
		+ " blocking_modal=" + str(hud.has_blocking_modal())
		+ " window_focus=" + str(root.has_focus())
		+ " clock_focused=" + str(_world._clock_window_focused)
		+ " farm_ripples=" + str(_ripple_count())
		+ " target=" + str(_world.player.current_target_cell())
		+ " facing=" + str(_world.player.facing))
	if falling != _rainy:
		_failures.append("%s: rain_falling=%s expected %s" % [phase, str(falling), str(_rainy)])
	if _first_layer_id == 0:
		_first_layer_id = layer_id
	elif layer_id != _first_layer_id:
		_failures.append("%s: rain layer instance changed %d -> %d" % [phase, _first_layer_id, layer_id])

func _session_weather() -> String:
	return str(_world._session.snapshot()["weather"])

func _ripple_count() -> int:
	var farm := _world._map as FarmMap
	if farm == null:
		return -1
	var count := 0
	for child in farm.ambience.get_children():
		if child is Sprite2D and child.visible:
			count += 1
	return count

func _title_continue() -> void:
	var title := _app.get_node("TitleScreen")
	var waited := 0.0
	while not bool(title._continue_available) and waited < 15.0:
		await _frames(10)
		waited += 0.3
	if not bool(title._continue_available):
		_failures.append("title: Continue never became available")
		_finish()
		return
	_log("title continue available; selecting Continue")
	_key(KEY_W)  # move_down selects Continue
	await _frames(10)
	_log("title selection=%s" % str(title.selected_action()))
	if str(title.selected_action()) != "continue":
		_failures.append("title: Continue not selected")
		_finish()
		return
	_key(KEY_ENTER)

func _wait_world() -> void:
	var waited := 0.0
	while waited < 20.0:
		var world := _app.get_node_or_null("World") as WorldShell
		if world != null and world.farm_view != null:
			_world = world
			_log("world ready; weather=%s" % str(_session_weather()))
			return
		await _frames(10)
		waited += 0.3
	_failures.append("world never became ready")
	_finish()

func _wait_map_location(farm_expected: bool) -> void:
	var waited := 0.0
	var on_farm := true
	while waited < 30.0:
		on_farm = _world.farm_view != null
		if on_farm == farm_expected and not _world.hud.has_blocking_modal():
			_log("map swapped; farm=%s rain_layer_id=%d"
				% [str(on_farm), _world.rain_layer.get_instance_id()])
			return
		await _frames(1)
		waited += 1.0 / 60.0
	_log("swap-poll timeout: on_farm=" + str(on_farm)
		+ " blocking=" + str(_world.hud.has_blocking_modal()))
	_failures.append("map swap to %s timed out" % ("farm" if farm_expected else "town"))

func _walk_to_grid(grid_target: Vector2, capture_mid: bool = false) -> void:
	var world_target := WorldMath.grid_to_world(grid_target)
	var elapsed := 0.0
	var captured := 0
	while elapsed < 30.0:
		var position: Vector2 = _world.player.global_position
		var delta := world_target - position
		if absf(delta.x) < 8.0 and absf(delta.y) < 8.0:
			break
		_press_movement(delta)
		await process_frame
		elapsed += 1.0 / 60.0
		if capture_mid and captured < 5 and elapsed > 2.0 + 2.0 * captured:
			captured += 1
			_release_all()
			await _shot("21-town-edge-mid%d" % captured)
			await _frames(5)
	_release_all()
	await _frames(5)
	_log("walk done grid=%s target=%s" % [
		str(WorldMath.world_to_grid(_world.player.global_position)), str(grid_target),
	])

func _press_movement(delta: Vector2) -> void:
	_set_action("move_right", delta.x > 6.0)
	_set_action("move_left", delta.x < -6.0)
	_set_action("move_down", delta.y > 6.0)
	_set_action("move_up", delta.y < -6.0)

func _set_action(action: String, want: bool) -> void:
	if want:
		Input.action_press(action)
	else:
		Input.action_release(action)

func _release_all() -> void:
	for action in ["move_right", "move_left", "move_up", "move_down"]:
		Input.action_release(action)

func _face(action: String, expected_facing: int) -> void:
	# Press-poll: a short blind press can fall between physics ticks at high
	# refresh rates; hold until the controller reports the expected facing.
	Input.action_press(action)
	var waited := 0
	while int(_world.player.facing) != expected_facing and waited < 60:
		await _frames(1)
		waited += 1
		if waited % 10 == 0:
			Input.action_release(action)
			await _frames(1)
			Input.action_press(action)
	Input.action_release(action)
	await _frames(2)
	_log("face %s -> facing=%d (want %d)" % [action, int(_world.player.facing), expected_facing])
	if int(_world.player.facing) != expected_facing:
		_failures.append("face failed: %s want %d got %d" % [action, expected_facing, int(_world.player.facing)])

func _key(keycode: Key) -> void:
	# Built-in actions (ui_accept/ui_cancel) bind by keycode; project actions
	# bind by physical keycode — set both so every action matches.
	if keycode == KEY_E and _world != null:
		_log("E-press target=" + str(_world.player.current_target_cell())
			+ " facing=" + str(_world.player.facing)
			+ " grid=" + str(WorldMath.world_to_grid(_world.player.global_position))
			+ " gated=" + str(not _world._world_input_enabled))
	var press := InputEventKey.new()
	press.keycode = keycode
	press.physical_keycode = keycode
	press.pressed = true
	Input.parse_input_event(press)
	await _frames(4)
	if keycode == KEY_E and _world != null:
		_log("E-after toast='" + _world.hud.toast_text() + "' location_snapshot="
			+ str(_world._session.snapshot()["location"]))
	var release := InputEventKey.new()
	release.keycode = keycode
	release.physical_keycode = keycode
	release.pressed = false
	Input.parse_input_event(release)
	await _frames(4)

func _interact() -> void:
	await _key(KEY_E)

func _close_modals() -> void:
	var waited := 0.0
	while _world.hud.has_blocking_modal() and waited < 4.0:
		await _key(KEY_ESCAPE)
		await _frames(10)
		waited += 0.5
	_log("modals closed blocking=%s" % str(_world.hud.has_blocking_modal()))

func _finish() -> void:
	if _failures.is_empty():
		_log("DONE clean tour=%s" % _label)
		quit(0)
	else:
		for failure in _failures:
			_log("FAIL %s" % failure)
		_log("DONE with %d failures tour=%s" % [_failures.size(), _label])
		quit(2)
