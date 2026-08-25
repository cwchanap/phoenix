class_name SaveFileCodec
extends RefCounted

const SCHEMA_VERSION := 1
const TYPE_MARKER := "__phoenix_type"
const VECTOR2I_MARKER := "Vector2i"

static func encode(state: Dictionary) -> String:
    return JSON.stringify({
        "schema_version": SCHEMA_VERSION,
        "state": _encode_variant(state),
    })

static func decode(text: String) -> Dictionary:
    var parser := JSON.new()
    var parse_error := parser.parse(text)
    if parse_error != OK:
        return {
            "ok": false,
            "error": "Invalid save JSON at line %d: %s" % [
                parser.get_error_line(),
                parser.get_error_message(),
            ],
        }
    if not (parser.data is Dictionary):
        return {"ok": false, "error": "Save envelope must be an object"}
    var envelope: Dictionary = parser.data
    if not envelope.has("schema_version"):
        return {"ok": false, "error": "Save schema version is missing"}
    if not (envelope["schema_version"] is int or envelope["schema_version"] is float):
        return {"ok": false, "error": "Save schema version must be numeric"}
    var schema_number := float(envelope["schema_version"])
    if not is_finite(schema_number) or schema_number != floor(schema_number):
        return {"ok": false, "error": "Save schema version must be an integer"}
    if int(schema_number) != SCHEMA_VERSION:
        return {"ok": false, "error": "Unsupported save schema"}
    if not envelope.has("state"):
        return {"ok": false, "error": "Save state is missing"}
    var decoded := _decode_variant(envelope["state"])
    if not decoded["ok"]:
        return decoded
    if not (decoded["value"] is Dictionary):
        return {"ok": false, "error": "Save state must be an object"}
    return {"ok": true, "state": decoded["value"]}

static func _encode_variant(value: Variant) -> Variant:
    if value is Vector2i:
        return {
            TYPE_MARKER: VECTOR2I_MARKER,
            "x": value.x,
            "y": value.y,
        }
    if value is StringName:
        return String(value)
    if value is Dictionary:
        var result: Dictionary = {}
        for key in value.keys():
            result[String(key)] = _encode_variant(value[key])
        return result
    if value is Array:
        var result: Array = []
        for entry in value:
            result.append(_encode_variant(entry))
        return result
    return value

static func _decode_variant(value: Variant) -> Dictionary:
    if value is Dictionary:
        var dictionary: Dictionary = value
        if dictionary.has(TYPE_MARKER):
            if dictionary[TYPE_MARKER] != VECTOR2I_MARKER:
                return {"ok": false, "error": "Unknown save type marker"}
            if dictionary.size() != 3 or not dictionary.has("x") or not dictionary.has("y"):
                return {
                    "ok": false,
                    "error": "Vector2i marker must contain exactly x and y",
                }
            var x_result := _decode_vector_component(dictionary["x"], "x")
            if not bool(x_result["ok"]):
                return x_result
            var y_result := _decode_vector_component(dictionary["y"], "y")
            if not bool(y_result["ok"]):
                return y_result
            return {
                "ok": true,
                "value": Vector2i(int(x_result["value"]), int(y_result["value"])),
            }

        var result: Dictionary = {}
        for key in dictionary.keys():
            var decoded := _decode_variant(dictionary[key])
            if not bool(decoded["ok"]):
                return decoded
            result[String(key)] = decoded["value"]
        return {"ok": true, "value": result}

    if value is Array:
        var result: Array = []
        for entry in value:
            var decoded := _decode_variant(entry)
            if not bool(decoded["ok"]):
                return decoded
            result.append(decoded["value"])
        return {"ok": true, "value": result}

    if value is float and is_finite(value) and value == floor(value):
        return {"ok": true, "value": int(value)}
    return {"ok": true, "value": value}

static func _decode_vector_component(value: Variant, axis: String) -> Dictionary:
    if not (value is int or value is float):
        return {"ok": false, "error": "Vector2i %s must be numeric" % axis}
    var number := float(value)
    if not is_finite(number) or number != floor(number):
        return {"ok": false, "error": "Vector2i %s must be an integer" % axis}
    return {"ok": true, "value": int(number)}
