extends SceneTree

var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        print("FAIL: ", label)

func _pool_empty(crowd) -> bool:
    for actor in crowd.pool:
        if actor.id != "": return false
    return true

func _initialize() -> void:
    if OS.get_environment("INSIDE_LASU_TEST") != "1":
        quit(2)
        return
    call_deferred("run")

func run() -> void:
    var game = load("res://scenes/main.tscn").instantiate()
    root.add_child(game)
    current_scene = game
    await process_frame
    var crowd = game.campus_npcs
    game.profile_name_input.text = "Campus NPC tester"
    game._create_student_profile()
    crowd.hour_override = 12
    crowd.context = "campus"
    var poses := {}
    var market: Dictionary
    for quality in ["low", "medium", "high"]:
        game.preferences.quality = quality
        for anchor in crowd.anchors:
            crowd.clear_pool()
            game.player.global_position = anchor.position
            crowd._refresh()
            var count := 0
            for actor in crowd.pool:
                if actor.id == "": continue
                count += 1
                poses[actor.activity] = true
                check(actor.position.distance_to(anchor.position) <= crowd.config.pool.release_radius, "actor within interest radius")
            check(count > 0 and count <= crowd.config.pool.quality_caps[quality], quality + " count at " + anchor.site)
            if anchor.site == "AJ Market": market = anchor
    for pose in ["walk", "chat", "sit", "phone", "queue", "read"]:
        check(poses.has(pose), "visible activity " + pose)
    for hour in range(24):
        crowd.hour_override = hour
        var routine: Dictionary = crowd.config.routine[crowd.routine_index()]
        check(hour >= routine.start and hour < routine.end, "routine covers hour " + str(hour))
    game.player.global_position = market.position
    crowd.hour_override = 12
    crowd.clear_pool()
    crowd._refresh()
    var seller: Dictionary
    for actor in crowd.pool:
        if actor.id == "staff_AJ Market": seller = actor
    check(not seller.is_empty(), "vendor on duty")
    if not seller.is_empty():
        game.player.global_position = seller.position
        check(game.try_campus_interaction(game.player), "interact with nearby vendor")
        check(game.task_title_label.text.contains("Vendor"), "vendor dialogue opens")
        var buttons = game.task_buttons_container.get_children()
        buttons[0].pressed.emit()
        check(game.task_status_label.text == crowd.config.dialogue.greeting, "greet")
        buttons[1].pressed.emit()
        check(not game.task_status_label.text.is_empty(), "chat")
        buttons[2].pressed.emit()
        check(game.task_title_label.text == "AJ MARKET", "vendor opens site tasks and shop")
        # Services respect the existing rule that purchases happen inside.
        game._enter_interior("AJ Market")
        check(crowd.batch.multimesh.visible_instance_count == 0, "outdoor NPC batch hidden on interior entry")
        check(_pool_empty(crowd), "outdoor NPC pool cleared on interior entry")
        game._enter_campus_room(0)
        check(_pool_empty(crowd), "NPC pool cleared on room transition")
        await process_frame
        crowd.clear_pool()
        crowd._refresh()
        var bought := false
        for staff in crowd.pool:
            if staff.id == "" or staff.role != "vendor": continue
            game.player.global_position = staff.position
            check(game.try_campus_interaction(game.player), "indoor vendor interaction")
            game.task_buttons_container.get_child(2).pressed.emit()
            for button in game.task_buttons_container.get_children():
                if button.get_child_count() == 0 or not button.get_child(0) is Label: continue
                var caption: String = button.get_child(0).text
                for entry in game.task_catalog["AJ Market"]:
                    if entry.kind != "purchase" or not caption.begins_with(entry.title): continue
                    var balance: int = game.wallet_balance
                    var count: int = game.task_inventory.size()
                    button.pressed.emit()
                    bought = game.task_inventory.size() == count + 1 and game.wallet_balance == balance - game._activity_price(entry)
                    break
                if bought: break
            break
        check(bought, "vendor purchase records receipt and deducts listed price")
        game._close_task_panel()
        game._leave_interior()
    crowd.talking_id = ""
    crowd.hour_override = 23
    crowd._refresh()
    for actor in crowd.pool: check(actor.id != "staff_AJ Market", "off-duty vendor released")
    game.player.global_position = Vector3(9999, 0, 9999)
    crowd._refresh()
    for actor in crowd.pool: check(actor.id == "", "distant slots released")
    print("NPC REGRESSION: %d checks, %d failures" % [checks, failures])
    game.queue_free()
    await process_frame
    quit(0 if failures == 0 else 1)
