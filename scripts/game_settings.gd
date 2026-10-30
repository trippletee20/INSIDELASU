extends RefCounted
const THEME = preload("res://scripts/ui_theme.gd")
const DEFAULTS = {"theme": "system", "quality": "auto", "resolution_scale": 1.0,
    "mouse_sensitivity": 1.0, "touch_sensitivity": 1.0, "volume": 1.0,
    "control_size": 1.0, "stick_position": "left"}

static func validated(raw: Variant) -> Dictionary:
    var result: Dictionary = raw.duplicate(true) if raw is Dictionary else {}
    for key in DEFAULTS:
        var fallback: Variant = DEFAULTS[key]
        if not result.has(key) or typeof(result[key]) != typeof(fallback):
            # JSON can represent a whole-number slider value as an integer.
            if fallback is float and result.get(key) is int: result[key] = float(result[key])
            else: result[key] = fallback
    if result.theme not in ["system", "light", "dark"]: result.theme = "system"
    if result.quality not in ["auto", "low", "medium", "high"]: result.quality = "auto"
    if result.stick_position not in ["left", "right"]: result.stick_position = "left"
    for key in ["mouse_sensitivity", "touch_sensitivity"]: result[key] = clampf(result[key], 0.25, 2.0) if is_finite(result[key]) else 1.0
    for key in ["resolution_scale", "volume", "control_size"]:
        var limits: Vector2 = {"resolution_scale": Vector2(0.5, 1.0), "volume": Vector2(0, 1), "control_size": Vector2(0.85, 1.2)}[key]
        result[key] = clampf(result[key], limits.x, limits.y) if is_finite(result[key]) else 1.0
    return result

static func device_dark() -> bool:
    if OS.has_feature("web"):
        return bool(JavaScriptBridge.eval("window.matchMedia('(prefers-color-scheme: dark)').matches"))
    return DisplayServer.is_dark_mode() if DisplayServer.is_dark_mode_supported() else false

static func apply(game: Node) -> void:
    var prefs: Dictionary = game.preferences
    var quality: String = effective_quality(prefs)
    var dark: bool = device_dark() if prefs.theme == "system" else prefs.theme == "dark"
    if THEME.colors.is_empty() or THEME.dark != dark:
        THEME.make(preload("res://assets/fonts/NotoSans.ttf"), dark)
    game.player.mouse_sensitivity = 0.0025 * prefs.mouse_sensitivity
    var viewport: Viewport = game.get_viewport()
    viewport.scaling_3d_scale = prefs.resolution_scale if not game.MOBILE_CONTROLS.touch_device() else {"low": 0.65, "medium": 0.85, "high": 1.0}[quality]
    viewport.msaa_3d = Viewport.MSAA_2X if quality == "high" else Viewport.MSAA_DISABLED
    game.player.camera.far = {"low": 140.0, "medium": 220.0, "high": 300.0}[quality]
    preload("res://scripts/render_budget.gd").apply_lod(game.get_tree(), quality)
    AudioServer.set_bus_volume_db(0, linear_to_db(maxf(0.0001, prefs.volume)))
    AudioServer.set_bus_mute(0, prefs.volume == 0)
    if game.mobile_controls != null:
        game.mobile_controls.control_scale = prefs.control_size
        game.mobile_controls.stick_right = prefs.stick_position == "right"
        game.mobile_controls._layout()

static func effective_quality(prefs: Dictionary) -> String:
    if prefs.quality != "auto": return prefs.quality
    if OS.has_feature("web"):
        # Conservative capability heuristic, not a measured GPU classification.
        return str(JavaScriptBridge.eval("(()=>{const n=navigator;const touch=matchMedia('(pointer:coarse)').matches;const ram=n.deviceMemory||4;const cores=n.hardwareConcurrency||4;return (n.connection?.saveData||ram<=2||cores<=2)?'low':(touch||ram<8||cores<8)?'medium':'high';})()"))
    return "medium"
