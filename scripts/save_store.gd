extends RefCounted
## Versioned local saves. The last valid file survives interrupted writes.
const VERSION: int = 2
const PATH: String = "user://inside_lasu_save.json"

static func _parse_file(path: String) -> Variant:
    if not FileAccess.file_exists(path):
        return null
    var parser := JSON.new()
    if parser.parse(FileAccess.get_file_as_string(path)) != OK:
        return null
    return parser.data

static func _validated(path: String) -> Dictionary:
    var value: Variant = _parse_file(path)
    if not value is Dictionary or not value.get("profile", {}) is Dictionary:
        return {}
    for key in ["wallet_balance", "total_earned", "total_spent", "last_daily_reward_amount", "last_room_rest_unix", "energy", "stamina", "stress", "social_reputation", "save_version"]:
        if value.has(key) and not typeof(value[key]) in [TYPE_INT, TYPE_FLOAT]:
            return {}
    for key in ["skills", "skill_xp", "skill_daily_xp", "location_visits", "task_completion_counts", "task_daily_completions"]:
        if value.has(key) and not value[key] is Dictionary:
            return {}
    for key in ["room_furniture", "task_inventory", "transactions"]:
        if value.has(key) and not value[key] is Array:
            return {}
    if int(value.get("save_version", 1)) > VERSION:
        return {}
    # Add only new fields. Existing money, profile, room and skill values are retained.
    if not value.has("transactions"):
        value["transactions"] = []
    value["save_version"] = VERSION
    return value

static func load_profile(path: String = PATH) -> Dictionary:
    var saved: Dictionary = _validated(path)
    if not saved.is_empty():
        return saved
    return _validated(path + ".backup")

static func save_profile(data: Dictionary, path: String = PATH) -> Error:
    if FileAccess.file_exists(path):
        var previous: Variant = _parse_file(path)
        if previous is Dictionary and typeof(previous.get("save_version", 1)) in [TYPE_INT, TYPE_FLOAT] and int(previous.get("save_version", 1)) > VERSION:
            return ERR_UNAVAILABLE
    var temporary: String = path + ".tmp"
    var file: FileAccess = FileAccess.open(temporary, FileAccess.WRITE)
    if file == null:
        return FileAccess.get_open_error()
    file.store_string(JSON.stringify(data, "\t"))
    file.flush()
    file.close()
    if _validated(temporary).is_empty():
        return ERR_FILE_CORRUPT
    if not _validated(path).is_empty():
        var backup_error: Error = DirAccess.copy_absolute(ProjectSettings.globalize_path(path), ProjectSettings.globalize_path(path + ".backup"))
        if backup_error != OK:
            return backup_error
    elif FileAccess.file_exists(path):
        var damaged: String = path + ".damaged." + str(int(Time.get_unix_time_from_system()))
        var preserve_error: Error = DirAccess.copy_absolute(ProjectSettings.globalize_path(path), ProjectSettings.globalize_path(damaged))
        if preserve_error != OK:
            return preserve_error
    return DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), ProjectSettings.globalize_path(path))
