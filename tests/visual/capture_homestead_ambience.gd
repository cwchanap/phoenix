extends SceneTree
## HPA-462 evidence captures: fixed-phase sunny/rainy homestead states.
## Freezes HomesteadAmbience before the World enters the tree so ripples and
## rain stay deterministic, then captures the native 640x360 viewport into
## test_output/hpa-462/. Evidence only: no committed goldens.

const WORLD_SCENE := preload("res://scenes/world/world.tscn")
const OUTPUT_DIR := "res://test_output/hpa-462"
const SETTLE_FRAMES := 2

func _initialize() -> void:
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
    for capture in [["sunny", false], ["rainy", true]]:
        var image := await _capture(capture[1])
        if image == null or image.is_empty() or image.get_width() != 640 or image.get_height() != 360:
            push_error("capture %s did not produce a non-empty 640x360 image" % capture[0])
            quit(2)
            return
        var path := "%s/%s.png" % [OUTPUT_DIR, capture[0]]
        var save_error := image.save_png(ProjectSettings.globalize_path(path))
        if save_error != OK:
            push_error("could not write capture %s: %s" % [path, save_error])
            quit(2)
            return
        print("captured %s" % path)
    quit(0)

func _capture(rainy: bool) -> Image:
    var state := UiFixtureFactory.hud_state()
    if rainy:
        var rainy_key := GameRules.weather_key(GameRules.Weather.RAINY)
        state["weather"] = rainy_key
        var history: Array = state["weather_history"]
        history[history.size() - 1] = rainy_key
        state["weather_history"] = history
    var label := "rainy" if rainy else "sunny"
    var error := GameSession.state_error(state)
    assert(error == "", "invalid %s fixture state: %s" % [label, error])

    var world := WORLD_SCENE.instantiate() as WorldShell
    world.configure(state, null, UiSettings.new())
    var ambience := world.get_node("HomesteadAmbience") as HomesteadAmbience
    ambience.process_mode = Node.PROCESS_MODE_DISABLED
    root.add_child(world)
    for _step in SETTLE_FRAMES:
        await process_frame
    ambience.render(world._session.snapshot())
    await process_frame
    var image := root.get_texture().get_image()
    world.queue_free()
    await process_frame
    return image
