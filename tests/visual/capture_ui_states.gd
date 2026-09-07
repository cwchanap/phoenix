extends SceneTree

const HOST_SCENE := preload("res://tests/visual/ui_capture_host.tscn")
const VISUAL_STATES := [
    "01-hud",
    "02-seed-shop",
    "03-shipping-day14",
    "04-bag",
    "05-almanac",
    "06-calendar",
    "07-dialogue",
    "08-morning-summary",
    "09-sleep",
    "10-pause",
    "11-settings",
    "12-intro",
    "13-title",
    "14-result-heart-of-harvest",
]

func _initialize() -> void:
    var state_name := "01-hud"
    var output_path := ""
    var evidence_path := ""
    for argument in OS.get_cmdline_user_args():
        if argument.begins_with("--state="):
            state_name = argument.trim_prefix("--state=")
        elif argument.begins_with("--output="):
            output_path = argument.trim_prefix("--output=")
        elif argument.begins_with("--evidence="):
            evidence_path = argument.trim_prefix("--evidence=")

    if not VISUAL_STATES.has(state_name):
        push_error("unsupported visual state: %s" % state_name)
        quit(2)
        return
    if output_path == "":
        output_path = ProjectSettings.globalize_path("res://test_output/ui-visual/%s.png" % state_name)
    if evidence_path == "":
        evidence_path = output_path.get_basename() + "-2x.png"
    DirAccess.make_dir_recursive_absolute(output_path.get_base_dir())

    var host := HOST_SCENE.instantiate() as UiCaptureHost
    host.configure(UiFixtureFactory.state_for(state_name), state_name)
    root.add_child(host)
    await process_frame
    await host.prepare_state()
    var raw := await host.capture_root()
    if raw == null or raw.is_empty() or raw.get_width() != 640 or raw.get_height() != 360:
        push_error("capture did not produce a non-empty 640x360 image: %s" % output_path)
        quit(2)
        return
    var output_error := raw.save_png(output_path)
    if output_error != OK:
        push_error("could not write capture %s: %s" % [output_path, output_error])
        quit(2)
        return
    var evidence_error := UiCaptureHost.evidence_2x(raw).save_png(evidence_path)
    if evidence_error != OK:
        push_error("could not write evidence %s: %s" % [evidence_path, evidence_error])
        quit(2)
        return
    print("captured %s raw=%s evidence=%s" % [state_name, output_path, evidence_path])
    quit(0)
