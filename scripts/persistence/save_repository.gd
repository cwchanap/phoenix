class_name SaveRepository
extends RefCounted

const DEFAULT_PATH := "user://phoenix-save.json"
var _path: String

func _init(path: String = DEFAULT_PATH) -> void:
    _path = path

func load() -> Dictionary:
    if not FileAccess.file_exists(_path):
        return {"status": &"missing"}
    var file := FileAccess.open(_path, FileAccess.READ)
    if file == null:
        return {
            "status": &"io_error",
            "error": "Could not open save: %s" % error_string(FileAccess.get_open_error()),
        }
    var text := file.get_as_text()
    file.close()
    var decoded := SaveFileCodec.decode(text)
    if not decoded["ok"]:
        return {"status": &"invalid", "error": decoded["error"]}
    return {"status": &"loaded", "state": decoded["state"].duplicate(true)}

func save(state: Dictionary) -> Error:
    var file := FileAccess.open(_path, FileAccess.WRITE)
    if file == null:
        return FileAccess.get_open_error()
    file.store_string(SaveFileCodec.encode(state))
    file.flush()
    var write_error := file.get_error()
    file.close()
    return write_error
