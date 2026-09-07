class_name UiCaptureHost
extends Control

const HUD_SCENE := preload("res://scenes/ui/game_hud.tscn")
const TITLE_SCENE := preload("res://scenes/ui/title_screen.tscn")
const RESULT_SCENE := preload("res://scenes/ui/result_screen.tscn")
const CAPTURE_SETTLE_FRAMES := 2

var _state: Dictionary = {}
var _state_name := "01-hud"
var _hud: GameHud

func configure(state: Dictionary, state_name: String = "01-hud") -> void:
    _state = state.duplicate(true)
    _state_name = state_name

func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    if _state_name == "13-title":
        var title := TITLE_SCENE.instantiate() as TitleScreen
        add_child(title)
        title.set_continue_state(false, "Save is incompatible; start a New Game.")
        return
    if _state_name == "14-result-heart-of-harvest":
        var result := RESULT_SCENE.instantiate() as ResultScreen
        add_child(result)
        var restored_result := GameSession.new()
        assert(restored_result.restore_state(_state), "result fixture must restore through GameSession")
        result.present(ContentRules.build_harvest_result(restored_result.state()))
        return
    var restored := GameSession.new()
    assert(restored.restore_state(_state), "visual fixture must restore through GameSession")
    _state = restored.snapshot()

    var plate := TextureRect.new()
    plate.name = "WorldPlate"
    plate.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var plate_path := (
        "res://tests/visual/plates/shipping.png"
        if _state_name == "03-shipping-day14"
        else "res://tests/visual/plates/morning.png"
        if _state_name == "08-morning-summary"
        else "res://tests/visual/plates/sleep.png"
        if _state_name == "09-sleep"
        else "res://tests/visual/plates/farm.png"
    )
    plate.texture = ImageTexture.create_from_image(load_raw(plate_path))
    plate.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    plate.stretch_mode = TextureRect.STRETCH_SCALE
    plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(plate)

    _hud = HUD_SCENE.instantiate() as GameHud
    add_child(_hud)
    _hud.configure(UiSettings.new())
    _hud.render(_state)
    _hud.set_interaction_hint("E SHOP")
    _hud.show_feedback(GameRules.CommandCode.SOIL_TILLED)

func prepare_state() -> void:
    match _state_name:
        "02-seed-shop":
            _hud.open_shop()
            for _step in 4:
                await _press_panel_action("move_right")
        "03-shipping-day14":
            _hud.open_shipping()
            await _press_panel_action("panel_max")
        "04-bag":
            _hud.open_bag()
        "05-almanac":
            _hud.open_almanac()
        "06-calendar":
            _hud.open_calendar()
        "07-dialogue":
            _hud.open_dialogue(
                VillagerRules.VillagerId.SHOPKEEPER,
                UiFixtureFactory.dialogue_result(),
                _state,
            )
        "08-morning-summary":
            pass
        "09-sleep":
            _hud.open_sleep_confirmation()
        "10-pause":
            _hud.open_pause()
        "11-settings":
            _hud.open_pause()
            _hud.open_settings()

func _press_panel_action(action: StringName) -> void:
    var press := InputEventAction.new()
    press.action = action
    press.pressed = true
    get_viewport().push_input(press)
    var release := InputEventAction.new()
    release.action = action
    release.pressed = false
    get_viewport().push_input(release)
    await get_tree().process_frame

func capture_root() -> Image:
    for _step in CAPTURE_SETTLE_FRAMES:
        await get_tree().process_frame
    var image := get_viewport().get_texture().get_image()
    return image

static func evidence_2x(source: Image) -> Image:
    var result := source.duplicate()
    result.resize(1280, 720, Image.INTERPOLATE_NEAREST)
    return result

static func load_raw(path: String) -> Image:
    return Image.load_from_file(ProjectSettings.globalize_path(path))
