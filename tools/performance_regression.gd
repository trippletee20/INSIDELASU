extends SceneTree
var checks: int = 0
var failures: int = 0
func check(ok: bool, message: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        print("FAIL: ", message)
func _initialize() -> void:
    if OS.get_environment("INSIDE_LASU_TEST") != "1": quit(2); return
    call_deferred("run")
func run() -> void:
    var game = load("res://scenes/main.tscn").instantiate()
    root.add_child(game)
    current_scene = game
    await process_frame
    check(game.interior_builder.current_floor == null and game.interior_builder.designs.is_empty(), "interiors and metadata stay unloaded at boot")
    var batches: Array = game.find_children("ArchitectureBatch*", "MultiMeshInstance3D", true, false)
    var replaced: int = 0
    for batch in batches:
        replaced += batch.multimesh.instance_count
    check(batches.size() > 0 and replaced > batches.size(), "repeated architecture produces fewer render instances")
    print("BATCH STRUCTURE: ", replaced, " original box draws -> ", batches.size(), " batches; theoretical unculled reduction ", replaced - batches.size(), "; not a frame draw count")
    var settings = preload("res://scripts/game_settings.gd")
    check(settings.validated({}).quality == "auto", "new and old saves without quality default to auto")
    for q in ["low", "medium", "high"]:
        check(settings.effective_quality(settings.validated({"quality":q})) == q, "manual quality preserved " + q)
        game.update_setting("quality", q)
        for detail in get_nodes_in_group("performance_detail"):
            check(detail.visibility_range_end == {"low":65.0,"medium":100.0,"high":150.0}[q], "detail culling follows preset")
    var owner := Node3D.new()
    root.add_child(owner)
    var mat := StandardMaterial3D.new()
    var originals: Array[Transform3D] = []
    for i in range(3):
        var box := MeshInstance3D.new()
        box.mesh = BoxMesh.new()
        box.mesh.size = Vector3(2, 3, 4)
        box.position = Vector3(i * 4, 0, 0)
        box.rotation.y = 0.7
        box.material_override = mat
        owner.add_child(box)
        originals.append(box.transform)
    preload("res://scripts/render_budget.gd").batch(owner)
    var batch: MultiMeshInstance3D = owner.get_child(3)
    for i in range(3):
        check(not owner.get_child(i).visible, "original draw hidden after batching")
        check(owner.get_child(i).transform.is_equal_approx(originals[i]), "source transform retained for metadata consumers")
    check(batch.material_override == mat, "batch retains material")
    owner.queue_free()
    var names: Array = game.interior_catalog.keys()
    names.sort()
    game.interior_builder.show_floor(str(names[0]), "Test", 0)
    check(not game.interior_builder.designs.is_empty(), "interior metadata loaded on entry")
    game.interior_builder.clear_interior()
    check(game.interior_builder.current_floor == null and game.interior_builder.designs.is_empty() and game.interior_builder.material_cache.is_empty(), "interior resources released on exit")
    print("PERFORMANCE REGRESSION: ", checks, " checks, ", failures, " failures")
    game.queue_free()
    await process_frame
    quit(1 if failures else 0)
