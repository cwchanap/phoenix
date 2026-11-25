# HPA-863 acceptance harness, not a CI test. The Godot MCP runtime bridge can
# only press BaseButtons, so this scene exposes one button per real-input step:
# every movement and interaction below still travels through Input actions and
# the live WorldShell/collision path — nothing teleports or edits the session.
# Remaining fixture controls are presentation-only: `ClockOff` pauses the
# passive day clock, `EnglishUI` changes the runtime locale, `DismissTutorial`
# presses the real tip dismiss button and `ToggleUI` hides this panel. They do
# not touch player position, facing or session state.
extends Node

const APP_SCENE := preload("res://scenes/app/app.tscn")
const DEFAULT_LOG_PATH := "res://test_output/mcp_acceptance/actions.jsonl"
const LOG_DIR := "res://test_output/mcp_acceptance"
const PLAYTEST_SAVE_PATH := "res://test_output/mcp_acceptance/playtest-save.json"
const PLAYTEST_SETTINGS_PATH := "res://test_output/mcp_acceptance/playtest-settings.cfg"
const STANDOFF_PX := 8.0
const ARRIVE_PX := 2.5
const WALK_TIMEOUT_MS := 45000
const MOVE_ACTIONS: Array[StringName] = [
	&"move_left", &"move_right", &"move_up", &"move_down",
]
const FACE_ACTIONS: Array[StringName] = [
	&"move_up", &"move_right", &"move_down", &"move_left",
]

var app: Node
var log_file: FileAccess
var log_path := DEFAULT_LOG_PATH
var panel: PanelContainer
var status: Label
var state: Node
var _busy := false
var _playtest_save_path := PLAYTEST_SAVE_PATH
var _playtest_settings_path := PLAYTEST_SETTINGS_PATH


func configure_storage_dir(directory: String) -> void:
	assert(not is_inside_tree())
	_playtest_save_path = directory.path_join("playtest-save.json")
	_playtest_settings_path = directory.path_join("playtest-settings.cfg")


func _ready() -> void:
	var requested := OS.get_environment("PHOENIX_MCP_LOG")
	if not requested.is_empty():
		log_path = requested
	var absolute := ProjectSettings.globalize_path(log_path)
	var directory := absolute.get_base_dir()
	DirAccess.make_dir_recursive_absolute(directory)
	var playtest_directory := ProjectSettings.globalize_path(_playtest_save_path).get_base_dir()
	DirAccess.make_dir_recursive_absolute(playtest_directory)
	log_file = FileAccess.open(log_path, FileAccess.WRITE)
	_build_ui()
	app = APP_SCENE.instantiate()
	app.name = "App"
	app.configure(
		SaveRepository.new(_playtest_save_path),
		UiSettings.load(_playtest_settings_path),
	)
	add_child(app)
	_set_state("Idle")
	_log("boot", {"log_path": log_path})


func _build_ui() -> void:
	state = Node.new()
	state.name = "State"
	add_child(state)
	var layer := CanvasLayer.new()
	layer.name = "DriverLayer"
	layer.layer = 100
	add_child(layer)
	panel = PanelContainer.new()
	panel.name = "DriverPanel"
	panel.position = Vector2(16, 16)
	panel.modulate = Color(1.0, 1.0, 1.0, 0.9)
	layer.add_child(panel)
	var box := VBoxContainer.new()
	box.name = "Rows"
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)
	status = Label.new()
	status.name = "Status"
	status.text = "MCP acceptance driver"
	box.add_child(status)
	for action_name in [
		"EnglishUI", "SkipIntro", "DismissTutorial", "ClockOff", "ToggleUI", "Cancel", "Interact", "Action",
		"WalkFrontDoor", "WalkStorehouse", "WalkField", "WalkBin", "WalkBed", "WalkFarmTruck",
		"WalkShop", "WalkInert", "WalkTownTruck", "WalkSouthWest",
		"WalkNorthEast", "WalkTownWest", "WalkTownEast", "WalkTownCentre",
		"WalkBambooA", "WalkBambooB",
		"WalkUnreachable", "CrossYardWestGate", "CrossYardEastGate",
		"CrossYardSouthGate", "CrossFieldEastGate",
	]:
		var button := Button.new()
		button.name = action_name
		button.text = action_name
		button.add_theme_font_size_override("font_size", 16)
		button.pressed.connect(_on_button.bind(action_name))
		box.add_child(button)


func _on_button(action_name: String) -> void:
	if _busy and action_name != "ToggleUI":
		_log("busy", {"requested": action_name})
		return
	match action_name:
		"EnglishUI":
			TranslationServer.set_locale("en")
			_log("english_ui", {})
		"ToggleUI":
			panel.visible = not panel.visible
			_log("toggle_ui", {"visible": panel.visible})
		"SkipIntro":
			var skip := app.find_child("Skip", true, false) as BaseButton
			if skip != null:
				skip.pressed.emit()
			_log("skip_intro", {"found": skip != null})
		"DismissTutorial":
			var dismiss := app.find_child("Dismiss", true, false) as BaseButton
			if dismiss != null and dismiss.is_visible_in_tree():
				dismiss.pressed.emit()
			_log("dismiss_tutorial", {"found": dismiss != null})
		"ClockOff":
			var world := _world()
			if world != null:
				world.clock_running = false
			_log("clock_off", {"clock_running": world.clock_running if world != null else null})
		"Cancel":
			_tap(&"ui_cancel")
		"Interact":
			_tap(&"interact")
		"Action":
			_tap(&"use_action")
		"WalkField":
			_goto_interact(_farm_pose(Vector2i(15, 24), WorldContract.FARM_PATCH, 2, "field"))
		"WalkFrontDoor":
			_goto_interact(_farm_pose(Vector2i(23, 10), WorldContract.HOUSE_FOOTPRINT, 2, "front_door"))
		"WalkStorehouse":
			_goto_interact(_farm_pose(Vector2i(14, 12), WorldContract.prop_footprint("Storehouse"), 2, "storehouse"))
		"WalkBin":
			_goto_interact(_farm_pose(WorldContract.SHIPPING_CELL, WorldContract.SHIPPING_FOOTPRINT, 0, "bin"))
		"WalkBed":
			_goto_interact(_farm_pose(WorldContract.BED_CELL, WorldContract.bed_contact_footprint(), 2, "bed"))
		"WalkFarmTruck":
			_goto_interact(_farm_pose(WorldContract.TRUCK_CELL, WorldContract.TRUCK_FOOTPRINT, 3, "farm_truck"))
		"WalkShop":
			_goto_interact(_town_pose(TownContract.SHOP_CELL, TownContract.SHOP_FOOTPRINT, 2, "shop"))
		"WalkInert":
			_goto_interact(_town_pose(Vector2i(2, 4), TownContract.STATION_FOOTPRINT, 2, "inert"))
		"WalkTownTruck":
			_goto_interact(_town_pose(TownContract.TRUCK_CELL, TownContract.TRUCK_FOOTPRINT, 3, "town_truck"))
		"WalkSouthWest":
			_goto_cell(Vector2i(3, 34), "southwest")
		"WalkNorthEast":
			_goto_cell(Vector2i(43, 0), "northeast")
		"WalkTownWest":
			_goto_cell(Vector2i(1, 10), "town_west")
		"WalkTownEast":
			_goto_cell(Vector2i(14, 1), "town_east")
		"WalkTownCentre":
			_goto_cell(Vector2i(8, 6), "town_centre")
		"WalkBambooA":
			_goto_cell(Vector2i(4, 7), "bamboo_a")
		"WalkBambooB":
			_goto_cell(Vector2i(10, 7), "bamboo_b")
		"WalkUnreachable":
			_goto_cell(Vector2i(999, 999), "unreachable")
		"CrossYardWestGate":
			_cross_gate(Vector2i(19, 10), Vector2i(17, 10), "yard_west_gate")
		"CrossYardEastGate":
			_cross_gate(Vector2i(29, 11), Vector2i(31, 11), "yard_east_gate")
		"CrossYardSouthGate":
			_cross_gate(Vector2i(23, 13), Vector2i(23, 16), "yard_south_gate")
		"CrossFieldEastGate":
			_cross_gate(Vector2i(22, 20), Vector2i(20, 20), "field_east_gate")


func _farm_pose(cell: Vector2i, footprint: Rect2, side: int, label: String) -> Dictionary:
	return _contact_pose(footprint, side, label, cell)


func _town_pose(cell: Vector2i, footprint: Rect2, side: int, label: String) -> Dictionary:
	return _contact_pose(footprint, side, label, cell)


func _contact_pose(footprint: Rect2, side: int, label: String, cell: Vector2i) -> Dictionary:
	var polygon := WorldMath.footprint_to_polygon(footprint)
	var edge_start: Vector2 = polygon[side]
	var edge_end: Vector2 = polygon[(side + 1) % 4]
	var mid := (edge_start + edge_end) * 0.5
	var edge_direction := (edge_end - edge_start).normalized()
	var outward := Vector2(edge_direction.y, -edge_direction.x)
	var center := WorldMath.grid_to_world(footprint.get_center())
	if outward.dot(center - mid) > 0.0:
		outward = -outward
	return {
		"cell": cell,
		"label": label,
		"position": mid + outward * STANDOFF_PX,
		"facing": _facing_for_screen(-outward),
	}


func _facing_for_screen(direction: Vector2) -> int:
	if absf(direction.x) > absf(direction.y):
		return WorldMath.Facing.RIGHT if direction.x > 0.0 else WorldMath.Facing.LEFT
	return WorldMath.Facing.DOWN if direction.y > 0.0 else WorldMath.Facing.UP


func _goto_interact(goal: Dictionary) -> void:
	_begin_operation()
	if not await _walk_to(goal["position"], goal["label"]):
		_end_operation()
		return
	if not await _face_via_input(goal["facing"]):
		_log("walk_error", {
			"goal": goal["label"],
			"error": "facing",
			"expected": goal["facing"],
			"actual": player().facing,
		})
		_set_state("Error")
		_end_operation()
		return
	_log("goto", {
		"goal": goal["label"],
		"cell": goal["cell"],
		"facing": player().facing,
		"target": player().current_target_cell(),
	})
	_set_state("At_%s" % goal["label"])
	_end_operation()


func _goto_cell(cell: Vector2i, label: String) -> void:
	_begin_operation()
	await _goto_cell_body(cell, label)
	_end_operation()


func _goto_cell_body(cell: Vector2i, label: String) -> bool:
	var position := WorldMath.grid_to_world(Vector2(cell) + Vector2(0.5, 0.5))
	if not await _walk_to(position, label):
		return false
	_log("goto", {"goal": label, "cell": cell})
	_set_state("At_%s" % label)
	return true


# Two real-input walks across a fence gap. The retained walk route lists the
# exact cells, including the gate cell(s), so evidence does not rely on a
# teleported pose.
func _cross_gate(inside: Vector2i, outside: Vector2i, label: String) -> void:
	_begin_operation()
	if not await _goto_cell_body(inside, "%s_inside" % label):
		_log("gate_error", {"goal": label, "leg": "inside"})
		_end_operation()
		return
	if not await _goto_cell_body(outside, "%s_outside" % label):
		_log("gate_error", {"goal": label, "leg": "outside"})
		_end_operation()
		return
	_log("gate_crossing", {"goal": label, "from": inside, "to": outside})
	_end_operation()


# One direction action held for one physics tick establishes facing through the
# live PlayerController sampler; the ~1.6 px step stays inside the 8 px
# contact standoff. This is deliberately not a direct `player.facing` write.
func _face_via_input(facing: int) -> bool:
	_release_moves()
	_set_move(FACE_ACTIONS[facing], true)
	await get_tree().physics_frame
	_release_moves()
	await get_tree().physics_frame
	return player().facing == facing


func _begin_operation() -> void:
	_busy = true
	_set_state("Busy")


func _end_operation() -> void:
	_busy = false
	if status != null and state.get_child_count() > 0:
		status.text = "MCP acceptance: %s" % state.get_child(0).name


func _walk_to(target: Vector2, label: String, timeout_ms := WALK_TIMEOUT_MS) -> bool:
	var world := _world()
	if world == null:
		_log("walk_error", {"goal": label, "error": "no world"})
		_set_state("Error")
		return false
	var start_cell: Vector2i = WorldMath.world_to_grid(player().global_position)
	var target_cell: Vector2i = WorldMath.world_to_grid(target)
	var path := _path(start_cell, target_cell)
	if path.is_empty():
		_log("walk_error", {"goal": label, "error": "no path", "from": start_cell, "to": target_cell})
		_release_moves()
		_set_state("Error")
		return false
	for cell in path:
		if not await _seek(
			WorldMath.grid_to_world(Vector2(cell) + Vector2(0.5, 0.5)),
			label,
			timeout_ms,
		):
			_set_state("Error")
			return false
	if not await _seek(target, label, timeout_ms):
		_set_state("Error")
		return false
	_release_moves()
	_log("walk", {
		"goal": label,
		"start": start_cell,
		"end_cell": WorldMath.world_to_grid(player().global_position),
		"end_position": player().global_position,
		"route_cells": path.size(),
		"route": path,
	})
	return true


func _seek(target: Vector2, label: String, timeout_ms: int) -> bool:
	var deadline := Time.get_ticks_msec() + timeout_ms
	var last := player().global_position
	var stuck_frames := 0
	while player().global_position.distance_to(target) > ARRIVE_PX:
		if Time.get_ticks_msec() > deadline:
			_log("walk_error", {"goal": label, "error": "timeout", "at": player().global_position, "target": target})
			_release_moves()
			return false
		var offset := target - player().global_position
		_set_move(&"move_left", offset.x < 0.0)
		_set_move(&"move_right", offset.x > 0.0)
		_set_move(&"move_up", offset.y < 0.0)
		_set_move(&"move_down", offset.y > 0.0)
		await get_tree().physics_frame
		if player().global_position.distance_to(last) < 0.1:
			stuck_frames += 1
			if stuck_frames > 90:
				_log("walk_error", {"goal": label, "error": "stuck", "at": player().global_position, "target": target})
				_release_moves()
				return false
		else:
			stuck_frames = 0
			last = player().global_position
	_release_moves()
	return true


func _path(from_cell: Vector2i, to_cell: Vector2i) -> Array[Vector2i]:
	var world := _world()
	if world == null:
		return []
	var town := world.get_node_or_null("TownMap") != null
	var map_size := TownContract.MAP_SIZE if town else WorldContract.MAP_SIZE
	var footprints: Array[Rect2] = []
	if town:
		footprints.append(TownContract.STATION_FOOTPRINT)
		footprints.append(TownContract.SHOP_FOOTPRINT)
		footprints.append(TownContract.CAFE_FOOTPRINT)
		footprints.append(TownContract.MARKET_FOOTPRINT)
		footprints.append(TownContract.TRUCK_FOOTPRINT)
		footprints.append_array(TownContract.VILLAGER_FOOTPRINTS)
	else:
		for y in map_size.y:
			for x in map_size.x:
				if WorldContract.blocks_movement(Vector2i(x, y)):
					footprints.append(Rect2(x, y, 1, 1))
		for entry in WorldContract.blocking_props():
			footprints.append(entry["footprint"])
		footprints.append_array(WorldContract.fence_footprints())
	footprints.append_array(WorldContract.perimeter_footprints(map_size))
	var grid := AStarGrid2D.new()
	grid.region = Rect2i(Vector2i.ZERO, map_size)
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	for y in map_size.y:
		for x in map_size.x:
			grid.set_point_solid(Vector2i(x, y), _blocked(Vector2i(x, y), footprints))
	if not grid.is_in_boundsv(from_cell) or not grid.is_in_boundsv(to_cell):
		return []
	if grid.is_point_solid(to_cell):
		return []
	return grid.get_id_path(from_cell, to_cell)


func _blocked(cell: Vector2i, footprints: Array[Rect2]) -> bool:
	var half := WorldContract.PLAYER_HALF_EXTENT
	var box := Rect2(
		Vector2(cell) + Vector2.ONE * (0.5 - half),
		Vector2.ONE * half * 2.0,
	)
	for footprint in footprints:
		if box.intersects(footprint):
			return true
	return false


func _tap(action: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)
	await get_tree().process_frame
	event = InputEventAction.new()
	event.action = action
	event.pressed = false
	Input.parse_input_event(event)
	await get_tree().process_frame
	_log("tap", {"action": action})


func _set_move(action: StringName, pressed: bool) -> void:
	if pressed:
		Input.action_press(action)
	else:
		Input.action_release(action)


func _release_moves() -> void:
	for action in MOVE_ACTIONS:
		Input.action_release(action)


func _world() -> WorldShell:
	return app.get_node_or_null("World") as WorldShell


func player() -> PlayerController:
	return _world().player


func _log(event_name: String, data: Dictionary) -> void:
	if log_file == null:
		return
	var world := _world()
	var entry := {
		"t_ms": Time.get_ticks_msec(),
		"event": event_name,
		"data": data,
	}
	if world != null:
		var snapshot: Dictionary = world._session.snapshot()
		entry["state"] = {
			"map": "town" if world.get_node_or_null("TownMap") != null else "farm",
			"player_cell": WorldMath.world_to_grid(player().global_position),
			"player_position": player().global_position,
			"facing": player().facing,
			"target": player().current_target_cell(),
			"day": snapshot["day"],
			"time_minutes": snapshot["time_minutes"],
			"money": snapshot["money"],
			"stamina": snapshot["stamina"],
			"modal": world.hud.has_blocking_modal(),
			"prompt": world.hud.prompt_text(),
			"toast": world.hud.toast_text(),
		}
	log_file.store_line(JSON.stringify(entry))
	log_file.flush()


func _set_state(name: String) -> void:
	for child in state.get_children():
		child.free()
	var marker := Node.new()
	marker.name = name
	state.add_child(marker)
	if status != null and not _busy:
		status.text = "MCP acceptance: %s" % name
