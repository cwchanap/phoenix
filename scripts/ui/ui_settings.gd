class_name UiSettings
extends RefCounted

const DEFAULT_PATH := "user://phoenix-settings.cfg"
const DEFAULT_MUSIC := 4
const DEFAULT_SOUND := 7
const DEFAULT_FULLSCREEN := false
const DEFAULT_TUTORIAL_CARDS := true
# The one windowed size: the 1920x1080 base viewport at 1:1. It shrinks only
# when a smaller screen cannot hold it.
const WINDOW_SIZE := Vector2i(1920, 1080)
const MIN_WINDOW_SIZE := Vector2i(960, 540)
# Locale codes registered with TranslationServer. English is the source text
# (CSV keys), so it needs no translation file.
const LANGUAGES: Array[String] = ["en", "zh_TW", "ja"]

const _SECTION := "ui"

var music: int = DEFAULT_MUSIC
var sound: int = DEFAULT_SOUND
var fullscreen: bool = DEFAULT_FULLSCREEN
var tutorial_cards: bool = DEFAULT_TUTORIAL_CARDS
var language: String = default_language(OS.get_locale())
var _path: String

func _init(path: String = DEFAULT_PATH) -> void:
    _path = path

static func load(path: String = DEFAULT_PATH) -> UiSettings:
    var settings := UiSettings.new(path)
    var config := ConfigFile.new()
    if config.load(path) != OK:
        return settings

    settings.music = _read_level(config.get_value(_SECTION, "music", DEFAULT_MUSIC), DEFAULT_MUSIC)
    settings.sound = _read_level(config.get_value(_SECTION, "sound", DEFAULT_SOUND), DEFAULT_SOUND)
    var fullscreen_value: Variant = config.get_value(_SECTION, "fullscreen", DEFAULT_FULLSCREEN)
    if fullscreen_value is bool:
        settings.fullscreen = fullscreen_value
    var tutorial_value: Variant = config.get_value(
        _SECTION,
        "tutorial_cards",
        DEFAULT_TUTORIAL_CARDS,
    )
    if tutorial_value is bool:
        settings.tutorial_cards = tutorial_value
    var language_value: Variant = config.get_value(_SECTION, "language", settings.language)
    if language_value is String and LANGUAGES.has(language_value):
        settings.language = language_value
    return settings

## Maps an OS locale such as `ja_JP`, `zh_Hant_HK` or `zh_TW` to a supported
## language; Simplified Chinese and everything else fall back to English.
static func default_language(os_locale: String) -> String:
    var parts := os_locale.replace("-", "_").split("_")
    match parts[0].to_lower():
        "ja":
            return "ja"
        "zh":
            var subtags := Array(parts.slice(1)).map(func(part: String) -> String: return part.to_lower())
            if subtags.has("hans"):
                return "en"
            for subtag in subtags:
                if ["hant", "tw", "hk", "mo"].has(subtag):
                    return "zh_TW"
    return "en"

func set_music(level: int) -> Error:
    music = clampi(level, 0, 10)
    return _save()

func set_sound(level: int) -> Error:
    sound = clampi(level, 0, 10)
    return _save()

func set_fullscreen(enabled: bool) -> Error:
    fullscreen = enabled
    return _save()

func set_tutorial_cards(enabled: bool) -> Error:
    tutorial_cards = enabled
    return _save()

func set_language(value: String) -> Error:
    if not LANGUAGES.has(value):
        return ERR_INVALID_PARAMETER
    language = value
    return _save()

func apply_language() -> void:
    TranslationServer.set_locale(language)

func db_for_level(level: int) -> float:
    var clamped := clampi(level, 0, 10)
    if clamped == 0:
        return -80.0
    return -40.0 + float(clamped) * 4.0

func apply_window(window: Window) -> void:
    if window == null:
        return
    if fullscreen:
        window.mode = Window.MODE_FULLSCREEN
        return
    window.mode = Window.MODE_WINDOWED
    window.size = windowed_size(DisplayServer.screen_get_usable_rect(window.current_screen).size)
    if window.is_inside_tree():
        window.move_to_center()

## WINDOW_SIZE when the screen's usable area holds it, otherwise the largest
## 16:9 size that fits with a margin for the title bar. An unknown (empty)
## screen, as under --headless, keeps WINDOW_SIZE.
static func windowed_size(usable: Vector2i) -> Vector2i:
    if usable.x <= 0 or usable.y <= 0:
        return WINDOW_SIZE
    if usable.x >= WINDOW_SIZE.x and usable.y >= WINDOW_SIZE.y:
        return WINDOW_SIZE
    var fit := 0.9 * minf(float(usable.x) / WINDOW_SIZE.x, float(usable.y) / WINDOW_SIZE.y)
    return Vector2i((Vector2(WINDOW_SIZE) * fit).round())

static func _read_level(value: Variant, fallback: int) -> int:
    if value is int:
        return clampi(value, 0, 10)
    if value is float and is_finite(value):
        return clampi(int(value), 0, 10)
    return fallback

func _save() -> Error:
    var config := ConfigFile.new()
    config.set_value(_SECTION, "music", music)
    config.set_value(_SECTION, "sound", sound)
    config.set_value(_SECTION, "fullscreen", fullscreen)
    config.set_value(_SECTION, "tutorial_cards", tutorial_cards)
    config.set_value(_SECTION, "language", language)
    return config.save(_path)
