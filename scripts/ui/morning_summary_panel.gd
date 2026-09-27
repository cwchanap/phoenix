class_name MorningSummaryPanel
extends Control

signal acknowledged

var _compact_rows: Array[Panel] = []

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_STOP
    _compact_rows = [
        $Frame/CompactShipmentRows/Row_0 as Panel,
        $Frame/CompactShipmentRows/Row_1 as Panel,
        $Frame/CompactShipmentRows/Row_2 as Panel,
    ]
    ($Acknowledge as Button).pressed.connect(_on_acknowledge_pressed)
    _style_authored_tree(self)
    _apply_authored_style()
    ($Acknowledge as Button).modulate = Color(1, 1, 1, 0)
    visible = false

func present(summary: Dictionary) -> void:
    var completed_day := int(summary.get("completed_day", 0))
    var next_day := int(summary.get("next_day", 0))
    ($Frame/Header/CompletedDay as Label).text = "%d" % completed_day
    ($Frame/Header/NextDay as Label).text = "%d" % next_day

    var crops_advanced := int(summary.get("crops_advanced", 0))
    ($Frame/Card_0/Value as Label).text = "+%d" % crops_advanced
    ($Frame/Card_0/Caption as Label).text = "CROPS GREW"

    var weather := StringName(summary.get("next_weather", &"sunny"))
    var rainy := weather == GameRules.weather_key(GameRules.Weather.RAINY)
    ($Frame/Card_1/Value as Label).text = "RAINY" if rainy else "SUNNY"
    ($Frame/Card_1/Caption as Label).text = (
        "TODAY — NO\nWATERING NEEDED" if rainy else "TODAY —\nWATER AS USUAL"
    )

    var stamina := int(summary.get("stamina_restored", 0))
    ($Frame/Card_2/Value as Label).text = "%d" % stamina
    ($Frame/Card_2/Caption as Label).text = "STAMINA FULL" if stamina > 0 else "STAMINA"

    var income := int(summary.get("shipping_income", 0))
    ($Frame/Card_3/Value as Label).text = "+%d" % income
    ($Frame/Card_3/Caption as Label).text = "SHIPPED"

    var shipments: Array = summary.get("shipments", [])
    assert(shipments.size() <= _compact_rows.size(), "morning summary has too many shipment lines")
    var normal_row := $Frame/ShipmentRow as Panel
    var compact_rows := $Frame/CompactShipmentRows as Control
    normal_row.visible = shipments.size() == 1
    compact_rows.visible = shipments.size() > 1
    if normal_row.visible:
        _render_shipment_row(normal_row, shipments[0])
    for index in _compact_rows.size():
        var row := _compact_rows[index]
        row.visible = compact_rows.visible and index < shipments.size()
        if row.visible:
            _render_shipment_row(row, shipments[index])
    ($Frame/EmptyShipment as Label).visible = shipments.is_empty()

    ($Frame/MoneyRow/Amount as Label).text = "%dG" % int(summary.get("money_after_shipping", 0))
    ($Frame/Footer/ActionText as Label).text = "START DAY %d" % next_day
    visible = true

func _render_shipment_row(row: Panel, shipment: Dictionary) -> void:
    var crop_key := StringName(shipment.get("crop", &"turnip"))
    var kind := GameRules.CROP_KEYS.find(crop_key)
    (row.get_node("Name") as Label).text = "%s ×%d" % [
        GameRules.crop_display_name(kind),
        int(shipment.get("quantity", 0)),
    ]
    (row.get_node("Amount") as Label).text = "%dG" % int(shipment.get("amount", 0))
    (row.get_node("Icon") as TextureRect).texture = load(
        "res://assets/ui/crops/%s.png" % crop_key
    ) as Texture2D

func set_save_status(status: StringName, message: String = "") -> void:
    match status:
        &"idle":
            ($SaveStatus as Label).text = ""
            ($Frame/SaveBadge/Caption as Label).text = ""
            ($Frame/SaveBadge as Panel).visible = false
        &"saved":
            ($SaveStatus as Label).text = "Saved."
            ($Frame/SaveBadge/Caption as Label).text = "SAVED"
            ($Frame/SaveBadge as Panel).visible = true
        &"error":
            ($SaveStatus as Label).text = message
            ($Frame/SaveBadge/Caption as Label).text = "SAVE ERROR"
            ($Frame/SaveBadge as Panel).visible = true
        _:
            assert(false, "unknown save status")

func _on_acknowledge_pressed() -> void:
    acknowledged.emit()

func _unhandled_input(event: InputEvent) -> void:
    if not visible or not event.is_action_pressed("ui_accept"):
        return
    get_viewport().set_input_as_handled()
    acknowledged.emit()

func _style_authored_tree(node: Node) -> void:
    for child in node.get_children():
        if child is Label:
            UiStyle.text(child as Label)
        elif child is Button:
            UiStyle.button(child as Button)
        _style_authored_tree(child)

func _apply_authored_style() -> void:
    ($Frame as Panel).add_theme_stylebox_override(
        "panel",
        UiStyle.panel(UiStyle.PRIMARY, UiStyle.FRAME_BORDER, 2),
    )
    ($Frame/Header as Panel).add_theme_stylebox_override(
        "panel",
        UiStyle.panel(UiStyle.HEADER, UiStyle.BORDER, 0),
    )
    ($Frame/ShipmentRow as Panel).add_theme_stylebox_override(
        "panel",
        UiStyle.panel(UiStyle.INSET, UiStyle.BORDER, 1),
    )
    for row in _compact_rows:
        row.add_theme_stylebox_override(
            "panel",
            UiStyle.panel(UiStyle.INSET, UiStyle.BORDER, 1),
        )
    ($Frame/MoneyRow as Panel).add_theme_stylebox_override(
        "panel",
        UiStyle.panel(UiStyle.HEADER, UiStyle.BORDER, 1),
    )
    ($Frame/Footer as Panel).add_theme_stylebox_override(
        "panel",
        UiStyle.panel(UiStyle.HEADER, UiStyle.BORDER, 0),
    )
    ($Frame/SaveBadge as Panel).add_theme_stylebox_override(
        "panel",
        UiStyle.panel(UiStyle.INSET, UiStyle.GREEN, 1),
    )
    for index in 4:
        var card := $Frame.get_node("Card_%d" % index) as Panel
        card.add_theme_stylebox_override(
            "panel",
            UiStyle.panel(
                UiStyle.WARNING_FILL if index == 3 else UiStyle.INSET,
                UiStyle.GOLD if index == 3 else Color("6b8bc4") if index == 1 else UiStyle.BORDER,
                1,
            ),
        )
    ($Frame/Footer/EnterKeycap as Panel).add_theme_stylebox_override(
        "panel",
        UiStyle.panel(UiStyle.KEYCAP_FILL, UiStyle.GOLD, 1),
    )
    UiStyle.text($Frame/Header/DayCaption as Label, 10, UiStyle.MUTED, 700)
    UiStyle.text($Frame/Header/CompletedDay as Label, 16, UiStyle.MUTED, 800, true)
    UiStyle.text($Frame/Header/Arrow as Label, 14, UiStyle.MUTED, 800)
    UiStyle.text($Frame/Header/NextDay as Label, 24, UiStyle.GOLD, 800, true)
    UiStyle.text($Frame/SaveBadge/Caption as Label, 8, UiStyle.GREEN, 800)
    for index in 4:
        var card := $Frame.get_node("Card_%d" % index) as Panel
        var value := card.get_node("Value") as Label
        var caption := card.get_node("Caption") as Label
        UiStyle.text(
            value,
            17,
            Color("6b8bc4") if index == 1 else UiStyle.GOLD if index == 3 else UiStyle.GREEN,
            800,
        )
        UiStyle.text(caption, 8, UiStyle.MUTED, 700)
    UiStyle.text($Frame/SectionTitle as Label, 8, UiStyle.MUTED, 700, true)
    UiStyle.text($Frame/ShipmentRow/Name as Label, 10, UiStyle.CREAM, 800)
    UiStyle.text($Frame/ShipmentRow/Amount as Label, 12, UiStyle.GREEN, 800)
    for row in _compact_rows:
        UiStyle.text(row.get_node("Name") as Label, 8, UiStyle.CREAM, 800)
        UiStyle.text(row.get_node("Amount") as Label, 8, UiStyle.GREEN, 800)
    UiStyle.text($Frame/EmptyShipment as Label, 9, UiStyle.MUTED, 400)
    UiStyle.text($Frame/MoneyRow/Caption as Label, 9, UiStyle.TEXT, 700)
    UiStyle.text($Frame/MoneyRow/Amount as Label, 13, UiStyle.GOLD, 800)
    UiStyle.text($Frame/Footer/EnterKey as Label, 8, UiStyle.GOLD, 800, true)
    UiStyle.text($Frame/Footer/ActionText as Label, 10, UiStyle.GOLD, 800)
    UiStyle.button($Acknowledge as Button, 8, true)
