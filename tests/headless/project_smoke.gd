extends SceneTree

func _fail(message: String) -> void:
    push_error(message)
    quit(1)

func _init() -> void:
    var version := Engine.get_version_info()
    if version["major"] != 4 or version["minor"] != 7 or version["patch"] != 1:
        _fail("Phoenix requires Godot 4.7.1")
        return
    if ProjectSettings.get_setting("application/run/main_scene") != "res://scenes/app/app.tscn":
        _fail("main scene must be the HPA-598 app root")
        return
    if ProjectSettings.get_setting("display/window/size/viewport_width") != 640:
        _fail("viewport width must be 640")
        return
    if ProjectSettings.get_setting("display/window/size/viewport_height") != 360:
        _fail("viewport height must be 360")
        return
    if ProjectSettings.get_setting("display/window/stretch/mode") != "viewport":
        _fail("stretch mode must be viewport")
        return
    if ProjectSettings.get_setting("display/window/stretch/aspect") != "keep":
        _fail("stretch aspect must be keep")
        return
    if ProjectSettings.get_setting("display/window/stretch/scale_mode") != "integer":
        _fail("stretch scale mode must be integer")
        return
    if ProjectSettings.get_setting("rendering/textures/canvas_textures/default_texture_filter") != 0:
        _fail("default CanvasItem texture filter must be nearest")
        return
    for path in [
        "res://assets/ui/icons/hoe.png",
        "res://assets/ui/crops/turnip.png",
        "res://assets/ui/portraits/mira.png",
        "res://assets/ui/logo/phoenix.png",
        "res://assets/ui/fonts/open-sans-variable.ttf",
        "res://assets/ui/fonts/jetbrains-mono-variable.ttf",
    ]:
        if not ResourceLoader.exists(path):
            _fail("missing required resource: %s" % path)
            return
    for path in [
        "res://assets/audio/river-ambience.wav",
        "res://assets/audio/rain-ambience.wav",
    ]:
        if not ResourceLoader.exists(path):
            _fail("missing ambience resource: %s" % path)
            return
        var loaded: Resource = ResourceLoader.load(path)
        if not loaded is AudioStreamWAV:
            _fail("ambience resource is not an AudioStreamWAV: %s" % path)
            return
        var stream: AudioStreamWAV = loaded
        if stream.mix_rate != 22050:
            _fail("ambience mix_rate must be 22050: %s" % path)
            return
        if stream.stereo:
            _fail("ambience must be mono: %s" % path)
            return
        if stream.loop_mode != AudioStreamWAV.LOOP_FORWARD:
            _fail("ambience loop_mode must be LOOP_FORWARD: %s" % path)
            return
        if stream.get_length() < 4.0 or stream.get_length() > 6.0:
            _fail("ambience duration must be 4-6 seconds: %s" % path)
            return
    quit(0)
