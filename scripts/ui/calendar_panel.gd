class_name CalendarPanel
extends Control

signal close_requested

const WEATHER_TEXTURES := {
    &"sunny": "res://assets/ui/icons/sun.png",
    &"rainy": "res://assets/ui/icons/rain.png",
}
const CROP_TEXTURES: Array[String] = [
    "res://assets/ui/crops/turnip.png",
    "res://assets/ui/crops/potato.png",
    "res://assets/ui/crops/pumpkin.png",
]

var _snapshot: Dictionary = {}
var _cells: Array[Panel] = []

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_STOP
    for day in range(1, GameRules.MAX_DAY + 1):
        _cells.append(get_node("Frame/Body/Day_%02d" % day) as Panel)
    _style_tree(self)
    _update_calendar()

func open_panel(snapshot: Dictionary) -> void:
    present(snapshot)
    visible = true

func present(snapshot: Dictionary) -> void:
    _snapshot = snapshot.duplicate(true)
    _update_calendar()

func _update_calendar() -> void:
    if not has_node("Frame"):
        return
    var current_day := int(_snapshot.get("day", 1))
    var market_text := (
        "HARVEST MARKET TODAY"
        if current_day >= GameRules.MAX_DAY
        else "%d DAYS TO MARKET" % (GameRules.MAX_DAY - current_day)
    )
    (get_node("Frame/Header/Market") as Label).text = market_text
    var market_value := get_node_or_null("Frame/Header/MarketBadge/MarketValue") as Label
    if market_value != null:
        market_value.text = market_text
    var history: Array = _snapshot.get("weather_history", [])
    var readiness := _readiness_markers(current_day)
    for index in range(_cells.size()):
        var day := index + 1
        var cell := _cells[index]
        var is_today := day == current_day
        var is_market := day == GameRules.MAX_DAY
        cell.add_theme_stylebox_override(
            "panel",
            UiStyle.panel(
                UiStyle.WARNING_FILL if is_market else UiStyle.KEYCAP_FILL if is_today else UiStyle.INSET,
                UiStyle.GOLD if is_today or is_market else UiStyle.BORDER,
                2 if is_today or is_market else 1,
            ),
        )
        var day_label := cell.get_node("Day") as Label
        day_label.text = "%d" % day
        UiStyle.text(day_label, 11, UiStyle.GOLD if is_today or is_market else UiStyle.MUTED, 800, true)
        var today_label := cell.get_node("Today") as Label
        today_label.visible = is_today
        today_label.text = "TODAY"
        UiStyle.text(today_label, 8, UiStyle.GOLD, 800, true)
        var weather := cell.get_node("Weather") as TextureRect
        var known_weather := index < history.size()
        weather.visible = known_weather
        if known_weather:
            weather.texture = load(WEATHER_TEXTURES.get(StringName(history[index]), WEATHER_TEXTURES[&"sunny"])) as Texture2D
        var market := cell.get_node("Market") as TextureRect
        market.visible = is_market
        var readiness_icon := cell.get_node("ReadinessIcon") as TextureRect
        var readiness_label := cell.get_node("ReadinessLabel") as Label
        var crop_kinds: Array = readiness.get(day, [])
        var has_readiness := not crop_kinds.is_empty()
        var combined_market := is_today and is_market and has_readiness
        readiness_icon.visible = crop_kinds.size() == 1 and not combined_market
        readiness_label.visible = crop_kinds.size() == 1 and not combined_market
        if combined_market:
            today_label.visible = false
            market.visible = false
        var multi_label := cell.get_node_or_null("ReadinessMultiLabel") as Label
        if multi_label != null:
            multi_label.visible = crop_kinds.size() > 1 and not combined_market
            if multi_label.visible:
                multi_label.text = "EARLIEST"
                UiStyle.text(multi_label, 6, UiStyle.GREEN, 700, true)
        for multi_index in range(3):
            var multi_icon := cell.get_node_or_null("ReadinessMultiIcon_%d" % (multi_index + 1)) as TextureRect
            if multi_icon == null:
                continue
            multi_icon.visible = multi_index < crop_kinds.size() and crop_kinds.size() > 1 and not combined_market
            if multi_icon.visible:
                multi_icon.texture = load(CROP_TEXTURES[int(crop_kinds[multi_index])]) as Texture2D
        if crop_kinds.size() == 1:
            readiness_icon.texture = load(CROP_TEXTURES[int(crop_kinds[0])]) as Texture2D
            readiness_label.text = "EARLIEST"
            UiStyle.text(readiness_label, 7, UiStyle.GREEN, 700, true)
        var last_night := cell.get_node_or_null("LastNight") as Label
        if last_night != null:
            last_night.visible = day == GameRules.MAX_DAY - 1
        var market_label := cell.get_node_or_null("MarketLabel") as Label
        if market_label != null:
            market_label.visible = is_market and not combined_market
        if is_market:
            if market_label != null:
                UiStyle.text(market_label, 8, UiStyle.GOLD, 800, true)
        var combined_today := cell.get_node_or_null("CombinedToday") as Label
        var combined_market_icon := cell.get_node_or_null("CombinedMarket") as TextureRect
        var combined_market_label := cell.get_node_or_null("CombinedMarketLabel") as Label
        if combined_today != null:
            combined_today.visible = combined_market
            combined_today.text = "TODAY"
            UiStyle.text(combined_today, 7, UiStyle.GOLD, 800, true)
        if combined_market_icon != null:
            combined_market_icon.visible = combined_market
        if combined_market_label != null:
            combined_market_label.visible = combined_market
            combined_market_label.text = "MARKET"
            UiStyle.text(combined_market_label, 6, UiStyle.GOLD, 800, true)
        if combined_market:
            readiness_icon.visible = crop_kinds.size() == 1
            readiness_label.visible = crop_kinds.size() == 1
            multi_label = cell.get_node_or_null("ReadinessMultiLabel") as Label
            if multi_label != null:
                multi_label.visible = crop_kinds.size() > 1
            for multi_index in range(3):
                var combined_icon := cell.get_node_or_null("ReadinessMultiIcon_%d" % (multi_index + 1)) as TextureRect
                if combined_icon == null:
                    continue
                combined_icon.visible = multi_index < crop_kinds.size() and crop_kinds.size() > 1
                if combined_icon.visible:
                    combined_icon.texture = load(CROP_TEXTURES[int(crop_kinds[multi_index])]) as Texture2D
            if crop_kinds.size() == 1:
                readiness_icon.texture = load(CROP_TEXTURES[int(crop_kinds[0])]) as Texture2D
                readiness_label.text = "EARLIEST"
                UiStyle.text(readiness_label, 6, UiStyle.GREEN, 700, true)
            if multi_label != null and multi_label.visible:
                multi_label.text = "EARLIEST"
                UiStyle.text(multi_label, 6, UiStyle.GREEN, 700, true)
    var history_day := mini(history.size(), GameRules.MAX_DAY)
    var legend := get_node("Frame/Footer/Legend") as Label
    legend.text = "KNOWN WEATHER THROUGH DAY %d · EARLIEST READINESS" % history_day
    UiStyle.text(legend, 9, UiStyle.MUTED, 600)

func _readiness_markers(current_day: int) -> Dictionary:
    var result: Dictionary = {}
    var farm: Array = _snapshot.get("farm", [])
    for entry_variant in farm:
        var entry: Dictionary = entry_variant
        var crop_variant: Variant = entry.get("crop", null)
        if crop_variant == null:
            continue
        var crop: Dictionary = crop_variant
        var kind := GameRules.CROP_KEYS.find(StringName(crop["kind"]))
        var ready_day := GameRules.earliest_ready_day(kind, int(crop["growth"]), current_day)
        if ready_day >= 1:
            var kinds: Array = result.get(ready_day, [])
            if not kinds.has(kind):
                kinds.append(kind)
                kinds.sort()
            result[ready_day] = kinds
    return result

func _style_tree(node: Node) -> void:
    for child in node.get_children():
        if child is Label:
            UiStyle.text(child as Label)
        elif child is Button:
            UiStyle.button(child as Button)
        _style_tree(child)
    (get_node("Frame") as Panel).add_theme_stylebox_override(
        "panel", UiStyle.panel(UiStyle.PRIMARY, UiStyle.FRAME_BORDER, 2)
    )
    var header_style := UiStyle.panel(UiStyle.HEADER, UiStyle.BORDER, 0)
    header_style.border_width_bottom = 2
    (get_node("Frame/Header") as Panel).add_theme_stylebox_override("panel", header_style)
    var footer_style := UiStyle.panel(UiStyle.HEADER, UiStyle.BORDER, 0)
    footer_style.border_width_top = 2
    (get_node("Frame/Footer") as Panel).add_theme_stylebox_override("panel", footer_style)
    (get_node("Frame/Header/MarketBadge") as Panel).add_theme_stylebox_override(
        "panel", UiStyle.panel(UiStyle.KEYCAP_FILL, UiStyle.GOLD, 1)
    )
    UiStyle.text(get_node("Frame/Header/Title") as Label, 13, UiStyle.CREAM, 800)
    UiStyle.text(get_node("Frame/Header/Market") as Label, 8, UiStyle.GOLD, 800)
    UiStyle.text(get_node("Frame/Header/MarketBadge/MarketValue") as Label, 9, UiStyle.GOLD, 800, true)
    UiStyle.text(get_node("Frame/Footer/Legend") as Label, 9, UiStyle.MUTED, 600)
    UiStyle.button(get_node("Frame/Footer/Close") as Button, 9)
