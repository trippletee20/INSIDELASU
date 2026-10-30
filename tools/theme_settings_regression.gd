extends SceneTree
var checks: int = 0
var failures: int = 0
const SETTINGS = preload("res://scripts/game_settings.gd")
const THEME = preload("res://scripts/ui_theme.gd")
func check(ok: bool, title: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        print("FAIL: ", title)
func _initialize() -> void:
    if OS.get_environment("INSIDE_LASU_TEST") != "1": quit(2); return
    call_deferred("run")
func frames() -> void:
    for i in range(4): await process_frame
func contrast(a: Color, b: Color) -> float:
    var x: float = a.srgb_to_linear().get_luminance()
    var y: float = b.srgb_to_linear().get_luminance()
    return (maxf(x,y) + 0.05) / (minf(x,y) + 0.05)
func run() -> void:
    check(SETTINGS.validated({}).theme == "system", "old saves default to device theme")
    var corrupt := SETTINGS.validated({"theme": "wrong", "quality": [], "volume": 99, "control_size": -1, "mouse_sensitivity": "x", "future_setting": true})
    check(corrupt.theme == "system" and corrupt.volume == 1.0 and is_equal_approx(corrupt.control_size, 0.85) and corrupt.mouse_sensitivity == 1.0 and corrupt.future_setting, "invalid settings sanitised and unknown fields retained")
    var game = load("res://scenes/main.tscn").instantiate()
    root.add_child(game)
    current_scene = game
    await frames()
    game.profile_name_input.text = "Theme Settings Tester"
    game._create_student_profile()
    await frames()
    var original_money: int = game.wallet_balance
    var original_profile: Dictionary = game.SAVE_STORE.load_profile().profile.duplicate(true)
    game.save_extras["future_game_field"] = "keep"
    for mode in ["light", "dark"]:
        game.update_setting("theme", mode)
        await frames()
        check(THEME.dark == (mode == "dark"), "theme switched " + mode)
        check(contrast(THEME.colors.text, THEME.colors.surface) >= 7, "surface text contrast " + mode)
        check(contrast(THEME.colors.text, THEME.colors.field) >= 7, "button text contrast " + mode)
        check(game.student_ui.clock.get_theme_color("font_color") == THEME.colors.text, "HUD inherits live theme " + mode)
        check(game.student_ui.clock_pill.get_theme_stylebox("panel").bg_color == THEME.colors.surface, "HUD panel follows theme " + mode)
        check(game.task_panel.get_theme_stylebox("panel").bg_color == THEME.colors.surface, "activity panel follows theme " + mode)
        check(game.shuttle_menu.get_theme_stylebox("panel").bg_color == THEME.colors.surface, "shuttle panel follows theme " + mode)
    game.open_settings()
    await frames()
    game._sync_mobile_controls()
    check(game.campus_phone.app == "Settings" and game.campus_phone.panel.visible, "Settings opens")
    check(not game.player.is_physics_processing() and not game.mobile_controls.enabled, "Settings prevents background movement")
    check(game.campus_phone.body.find_child("Setting_resolution_scale", true, false) != null, "desktop resolution control")
    game.update_setting("resolution_scale", 0.65)
    game.update_setting("mouse_sensitivity", 1.5)
    game.update_setting("volume", 0.0)
    check(is_equal_approx(root.scaling_3d_scale, 0.65), "3D resolution scale applied")
    check(is_equal_approx(game.player.mouse_sensitivity, 0.00375), "mouse sensitivity applied")
    check(AudioServer.is_bus_mute(0), "volume zero mutes")
    game.update_setting("quality", "high")
    check(root.msaa_3d == Viewport.MSAA_2X and game.player.camera.far == 300, "quality changes actual rendering")
    var saved: Dictionary = game.SAVE_STORE.load_profile()
    check(saved.settings.theme == "dark" and saved.settings.volume == 0.0 and saved.settings.resolution_scale == 0.65, "settings persisted in versioned save")
    check(saved.profile == original_profile and saved.wallet_balance == original_money and saved.future_game_field == "keep", "settings preserve existing profile money and unknown fields")
    game.campus_phone.close()
    var close := InputEventKey.new()
    close.keycode = KEY_F2
    close.pressed = true
    game._unhandled_input(close)
    check(game.campus_phone.app == "Settings" and game.campus_phone.panel.visible, "F2 opens Settings")
    close.keycode = KEY_ESCAPE
    game._unhandled_input(close)
    check(not game.campus_phone.panel.visible and game.player.is_physics_processing(), "Escape closes Settings and restores movement")
    preload("res://scripts/mobile_controls.gd")._touch_available = 1
    game.mobile_controls.available = true
    for dimensions in [Vector2i(320,568), Vector2i(393,873), Vector2i(873,393), Vector2i(640,360)]:
        root.size = dimensions
        await frames()
        game.open_settings()
        await frames()
        check(game.campus_phone.body.find_child("Setting_control_size", true, false) != null, "mobile control-size setting " + str(dimensions))
        check(game.campus_phone.body.find_child("Setting_resolution_scale", true, false) == null, "mobile uses quality scale " + str(dimensions))
        var rect: Rect2 = game.campus_phone.panel.get_global_rect()
        check(rect.position.x >= 0 and rect.end.x <= dimensions.x and rect.end.y <= dimensions.y, "Settings fits " + str(dimensions))
        game.campus_phone.show_app("Home")
        await frames()
        for tile in game.campus_phone.app_grid.get_children():
            check(tile.size.x <= game.campus_phone.panel.size.x / 2 and tile.size.y == game.campus_phone.app_grid.get_child(0).size.y, "aligned app tile " + str(dimensions))
        game.campus_phone.close()
        for side in ["left", "right"]:
            for size_value in [0.85, 1.2]:
                game.update_setting("control_size", size_value)
                game.update_setting("stick_position", side)
                game._sync_mobile_controls()
                var touch = game.mobile_controls
                check((touch.center.x > dimensions.x * 0.5) == (side == "right"), "stick side " + side)
                for action in ["interact", "jump", "more"]:
                    var b: Button = touch.buttons[action]
                    var bounds := Rect2(b.position, b.size * b.scale)
                    check(bounds.position.x >= 0 and bounds.end.x <= dimensions.x and bounds.position.y >= 0 and bounds.end.y <= dimensions.y - 126, "touch bounds " + action + str(dimensions))
                var actions: Array = ["interact", "jump", "more", "sit", "run"]
                for i in range(actions.size()):
                    var first: Button = touch.buttons[actions[i]]
                    var first_rect := Rect2(first.position, first.size * first.scale)
                    check(first_rect.size.x >= 43.99 and first_rect.size.y >= 43.99, "minimum touch target")
                    for j in range(i + 1, actions.size()):
                        var second: Button = touch.buttons[actions[j]]
                        check(not first_rect.intersects(Rect2(second.position, second.size * second.scale)), "touch buttons do not overlap " + actions[i] + "/" + actions[j] + str(dimensions))
                var event := InputEventScreenTouch.new()
                event.pressed = true
                event.index = 8
                event.position = touch.center
                touch._input(event)
                check(touch.move_finger == 8, "stick accepts correct hand")
                event.pressed = false
                touch._input(event)
        game.update_setting("quality", "low")
        check(is_equal_approx(root.scaling_3d_scale, 0.65), "mobile quality lowers 3D scale")
    check(game.world_labels.labels.size() > 80, "campus signs registered without editing topology")
    for entry in game.world_labels.labels:
        check(entry.card.theme == THEME.RESOURCE and entry.card.mouse_filter == Control.MOUSE_FILTER_IGNORE, "world card shares theme and cannot block input")
    var test_camera := Camera3D.new()
    game.add_child(test_camera)
    test_camera.global_position = Vector3(10000,100,10000)
    test_camera.current = true
    var anchor := Label3D.new()
    anchor.text = "Distance test"
    game.add_child(anchor)
    anchor.global_position = test_camera.global_position + Vector3(0,0,-100)
    await frames()
    game.world_labels._process(0.1)
    var last = game.world_labels.labels.back()
    check(not last.card.visible, "far labels culled")
    anchor.global_position = test_camera.global_position + Vector3(0,0,-10)
    game.world_labels._process(0.1)
    check(last.card.visible and not anchor.visible, "near label uses only rounded card")
    var near_scale: float = last.card.scale.x
    anchor.global_position = test_camera.global_position + Vector3(0,0,-40)
    game.world_labels._process(0.1)
    check(last.card.visible and last.card.scale.x < near_scale, "label scales with distance")
    anchor.global_position = test_camera.global_position + Vector3(0,0,10)
    game.world_labels._process(0.1)
    check(not last.card.visible, "behind-camera label hidden")
    var before_count: int = game.world_labels.labels.size()
    anchor.queue_free()
    await frames()
    game.world_labels._process(0.1)
    check(game.world_labels.labels.size() == before_count - 1, "removed sign releases its card")
    game.player.camera.current = true
    test_camera.queue_free()
    var expected: Dictionary = game.preferences.duplicate(true)
    game._save_game()
    game.queue_free()
    await frames()
    game = load("res://scenes/main.tscn").instantiate()
    root.add_child(game)
    current_scene = game
    await frames()
    check(game.preferences == expected and game.profile_data == original_profile, "reload restores settings and existing profile")
    check(THEME.dark and game.mobile_controls.stick_right, "reload applies saved presentation and controls")
    game.queue_free()
    await frames()
    print("THEME SETTINGS: %d checks, %d failures" % [checks, failures])
    quit(0 if failures == 0 else 1)
