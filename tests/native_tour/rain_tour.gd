extends "res://tests/native_tour/rain_tour_base.gd"
## Agent-operated native visual tour for HPA-860 town rain. Runs the real
## app windowed (not headless), loads the seeded save through the real
## Continue flow, drives real input events (walking, truck travel, Seed Shop,
## Hana talk, Day-14 Market refusal, with the passive clock running), saves
## viewport captures as PNGs for human/vision review, and quits without writing
## saves.
##
## Env: TOUR_WEATHER=rainy|sunny, TOUR_OUT=<png dir>,
## PHOENIX_SAVE_PATH / PHOENIX_SETTINGS_PATH must point into an isolated dir.
##
## Evidence-only one-off: backs the validation note, not maintained or run
## in CI; uses direct node inspection seams the headless suite never touches.
## Rerun directions live in the validation note.

var _rainy: bool
var _label: String
var _out_dir: String

func _initialize() -> void:
	_label = OS.get_environment("TOUR_WEATHER")
	_rainy = _label == "rainy"
	_out_dir = OS.get_environment("TOUR_OUT")
	if _out_dir.is_empty():
		_failures.append("TOUR_OUT is empty; captures cannot be written")
	elif DirAccess.make_dir_recursive_absolute(_out_dir) != OK:
		_failures.append("output dir unusable: %s (make_dir failed)" % _out_dir)
	if not _failures.is_empty():
		_finish("tour=%s" % _label)
		return
	if not _boot_app():
		return
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
	_finish("tour=%s" % _label)

# --- phases ---------------------------------------------------------------

func _phase_farm() -> void:
	await _frames(40)  # let streaks fall / settle
	await _shot("10-farm-spawn")
	_observe("farm-spawn")
	await _frames(15)
	await _shot("11-farm-motion-a")
	await _frames(15)
	await _shot("12-farm-motion-b")
	await _walk_to_grid(Vector2(WorldContract.BED_CELL) + Vector2(0.2, 0.9))
	await _face("move_up", WorldMath.Facing.UP)
	await _frames(10)
	await _shot("13-farm-bed-house-depth")
	_observe("farm-bed")
	await _walk_to_grid(
		_stand_facing(WorldContract.TRUCK_CELL, WorldMath.Facing.RIGHT, Vector2(0.4, 0.3))
	)
	await _face("move_right", WorldMath.Facing.RIGHT)
	await _frames(10)
	await _shot("14-farm-truck-prompt")
	_observe("farm-truck")

func _phase_travel_to_town() -> void:
	await _burst("14-farm-truck-seq", 8)
	await _interact()
	await _wait_map_location(false)
	await _burst("20-town-arrival-seq", 12)
	await _frames(18)
	await _shot("20-town-arrival")
	_observe("town-arrival")

func _phase_town_full() -> void:
	# Camera-edge walk with mid-walk captures: rain must track smoothly.
	# Town perimeter bands sit 2 cells inside each edge.
	await _walk_to_grid(Vector2(TownContract.MAP_SIZE) - Vector2(2.8, 2.8), _capture_walk_sample)
	await _shot("21-town-east-edge")
	_observe("town-edge")
	await _walk_to_grid(
		_stand_facing(TownContract.SHOP_CELL, WorldMath.Facing.RIGHT, Vector2(0.4, 0.3))
	)
	await _face("move_right", WorldMath.Facing.RIGHT)
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
	var hana_cell := TownContract.villager_cell(VillagerRules.VillagerId.RESIDENT)
	await _walk_to_grid(Vector2(hana_cell) + Vector2(-1.0, 2.0))
	await _walk_to_grid(
		_stand_facing(hana_cell, WorldMath.Facing.UP, Vector2(0.45, 0.4))
	)
	await _face("move_up", WorldMath.Facing.UP)
	await _frames(10)
	await _shot("24-hana-prompt")
	await _interact()
	await _frames(20)
	await _shot("25-hana-dialogue")
	if not _world.hud.has_blocking_modal():
		_failures.append("hana dialogue did not open (target %s)" % str(_world.player.current_target_cell()))
	_observe("town-dialogue")
	await _close_modals()
	await _walk_to_grid(
		_stand_facing(TownContract.MARKET_CELL, WorldMath.Facing.DOWN, Vector2(0.3, 0.3))
	)
	await _face("move_down", WorldMath.Facing.DOWN)
	await _frames(10)
	await _interact()
	await _frames(8)
	await _shot("26-market-refusal")
	if _world.hud.toast_text().find("Day 14") == -1:
		_failures.append("market refusal toast missing: '%s'" % _world.hud.toast_text())
	_observe("town-market-refusal")
	await _frames(60)
	var gen_cell := TownContract.villager_cell(VillagerRules.VillagerId.FARMER)
	await _walk_to_grid(Vector2(TownContract.MAP_SIZE.x - 5.5, float(gen_cell.y) + 2.5))
	await _walk_to_grid(
		_stand_facing(TownContract.TRUCK_CELL, WorldMath.Facing.LEFT, Vector2(0.4, 0.3))
	)
	await _face("move_left", WorldMath.Facing.LEFT)
	await _frames(10)
	await _shot("27-town-truck-prompt")
	_observe("town-truck")

func _phase_town_quick() -> void:
	await _walk_to_grid(Vector2(TownContract.MAP_SIZE) - Vector2(2.8, 2.8), _capture_walk_sample)
	await _shot("21-town-east-edge")
	_observe("town-edge")
	var gen_cell := TownContract.villager_cell(VillagerRules.VillagerId.FARMER)
	await _walk_to_grid(Vector2(TownContract.MAP_SIZE.x - 5.5, float(gen_cell.y) + 2.5))
	await _walk_to_grid(
		_stand_facing(TownContract.TRUCK_CELL, WorldMath.Facing.LEFT, Vector2(0.4, 0.3))
	)
	await _face("move_left", WorldMath.Facing.LEFT)
	await _frames(10)
	await _shot("27-town-truck-prompt")
	_observe("town-truck")

func _phase_travel_home() -> void:
	await _burst("27-town-truck-seq", 8)
	await _interact()
	await _wait_map_location(true)
	await _burst("30-return-farm-seq", 12)
	await _frames(10)

# --- captures & observation -----------------------------------------------

func _capture_walk_sample(sample_index: int) -> void:
	await _shot("21-town-edge-mid%d" % sample_index)
	await _frames(5)

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

func _observe(phase: String) -> void:
	if _world == null:
		_log("OBS %s world=null" % phase)
		return
	var hud := _world.hud
	var rain: AudioStreamPlayer = hud._rain_ambience_player
	var river: AudioStreamPlayer = hud._river_ambience_player
	var layer_id := _check_rain_layer(phase, _rainy)
	var live_rain := _live_rain_layer()
	var falling := live_rain.is_rain_falling() if live_rain != null else false
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

func _ripple_count() -> int:
	var farm := _world._map as FarmMap
	if farm == null:
		return -1
	var ambience := farm.get_node_or_null("HomesteadAmbience") as HomesteadAmbience
	if ambience == null:
		return -1
	var count := 0
	for child in ambience.get_children():
		if child is Sprite2D and child.visible:
			count += 1
	return count
