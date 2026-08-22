extends SceneTree

func _fail(message: String) -> void:
    push_error(message)
    quit(1)

func _init() -> void:
    var version := Engine.get_version_info()
    if version["major"] != 4 or version["minor"] != 7 or version["patch"] != 1:
        _fail("Phoenix requires Godot 4.7.1")
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
    quit(0)
