extends RefCounted
static func reveal(panel: Control) -> void:
    if panel.has_meta("reveal_tween"):
        var previous: Tween = panel.get_meta("reveal_tween")
        if previous.is_valid(): previous.kill()
    panel.modulate.a = 1.0
    if OS.has_feature("web") and bool(JavaScriptBridge.eval("matchMedia('(prefers-reduced-motion: reduce)').matches")): return
    panel.modulate.a = 0.0
    var tween := panel.create_tween()
    panel.set_meta("reveal_tween", tween)
    tween.tween_property(panel, "modulate:a", 1.0, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
