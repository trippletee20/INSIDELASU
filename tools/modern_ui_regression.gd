extends SceneTree
var checks: int = 0
var failures: int = 0
func check(ok: bool, title: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        print("FAIL: ", title)
func _initialize() -> void:
    if OS.get_environment("INSIDE_LASU_TEST") != "1": quit(2); return
    call_deferred("run")
func run() -> void:
    preload("res://scripts/mobile_controls.gd")._touch_available = 1
    var game = load("res://scenes/main.tscn").instantiate()
    root.add_child(game)
    current_scene = game
    await process_frame
    game.profile_name_input.text = "Modern HUD tester"
    game._create_student_profile()
    await process_frame
    for dimensions in [Vector2i(320,568),Vector2i(393,873),Vector2i(873,393),Vector2i(1280,720)]:
        root.size = dimensions
        await process_frame
        await process_frame
        await process_frame
        var hud = game.student_ui
        check(not hud.clock_pill.get_global_rect().intersects(hud.wallet_pill.get_global_rect()), "separate status pills " + str(dimensions))
        check(not hud.hud_toggle.get_global_rect().intersects(hud.wallet_pill.get_global_rect()), "toggle leaves wallet readable " + str(dimensions))
        check(hud.clock_pill.size.y < 70 and hud.wallet_pill.size.y < 70, "no large top HUD panels " + str(dimensions))
        var dock: Rect2 = hud.dock.get_global_rect()
        check(dock.position.x >= 0 and dock.end.x <= dimensions.x and dock.end.y <= dimensions.y, "dock fits viewport " + str(dimensions))
        var button: Button = hud.phone_button
        check(button.get_theme_stylebox("normal") is StyleBoxFlat, "modern native button style applied")
        hud.set_expanded(true)
        game._sync_mobile_controls()
        await process_frame
        await process_frame
        var sheet: Rect2 = hud.status_panel.get_global_rect()
        check(sheet.position.y >= 0 and sheet.end.y <= dock.position.y + 1, "location sheet stays above dock " + str(dimensions))
        check(not game.mobile_controls.enabled and not game.player.is_physics_processing(), "expanded sheet prevents background movement")
        hud.phone_button.pressed.emit()
        await process_frame
        check(game.campus_phone.panel.visible and not hud.hud_expanded, "phone opens cleanly from expanded dashboard")
        game.campus_phone.close()
        game._sync_mobile_controls()
        check(game.player.is_physics_processing(), "phone close restores movement")
    game.queue_free()
    await process_frame
    print("MODERN UI: %d checks, %d failures" % [checks, failures])
    quit(0 if failures == 0 else 1)
