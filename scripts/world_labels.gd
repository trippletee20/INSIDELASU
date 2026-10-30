extends CanvasLayer
## Shared 2D cards projected at existing sign anchors; no per-sign viewport/texture.
const THEME = preload("res://scripts/ui_theme.gd")
const MAX_DISTANCE: float = 55.0
var game: Node
var labels: Array = []
var elapsed: float = 0.0

func _ready() -> void:
    layer = 5
    _scan(game)
    get_tree().node_added.connect(_added)

func _scan(node: Node) -> void:
    if node is Label3D: _register(node)
    for child in node.get_children(): _scan(child)

func _added(node: Node) -> void:
    if node is Label3D: _register.call_deferred(node)

func _register(source: Label3D) -> void:
    if not is_instance_valid(source) or not source.is_inside_tree() or source.is_queued_for_deletion(): return
    if not game.is_ancestor_of(source) or source.has_meta("campus_card"): return
    # Keep player identity/presence labels separate from campus signs.
    if source.get_parent().is_in_group("online_students"): return
    if game.player.is_ancestor_of(source) or (game.campus_social != null and game.campus_social.is_ancestor_of(source)): return
    source.set_meta("campus_card", true)
    var card := Label.new()
    card.theme = THEME.RESOURCE
    card.theme_type_variation = "WorldLabel"
    card.text = source.text
    card.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    card.max_lines_visible = 3
    card.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
    card.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    card.mouse_filter = Control.MOUSE_FILTER_IGNORE
    card.visible = false
    add_child(card)
    source.visible = false
    labels.append({"source": source, "card": card})
    source.tree_exiting.connect(func():
        labels = labels.filter(func(entry): return entry.source != source)
        card.queue_free())

func _process(delta: float) -> void:
    elapsed += delta
    if elapsed < 0.05: return
    elapsed = 0.0
    var camera: Camera3D = get_viewport().get_camera_3d()
    if camera == null: return
    var occupied: Array[Rect2] = []
    var shown: int = 0
    var screen: Vector2 = get_viewport().get_visible_rect().size
    # Interior rebuilds and deferred scene teardown can free anchors between ticks.
    for entry in labels:
        if not is_instance_valid(entry.source) and is_instance_valid(entry.card): entry.card.queue_free()
    labels = labels.filter(func(entry): return is_instance_valid(entry.source) and is_instance_valid(entry.card))
    var nearby: Array = []
    for entry in labels:
        entry.card.visible = false
        var source: Label3D = entry.source
        if not source.get_parent() is Node3D or not source.get_parent().is_visible_in_tree(): continue
        var distance: float = camera.global_position.distance_to(source.global_position)
        if distance > MAX_DISTANCE or camera.is_position_behind(source.global_position): continue
        entry["distance"] = distance
        nearby.append(entry)
    nearby.sort_custom(func(a, b): return a.distance < b.distance)
    for entry in nearby:
        if shown >= 12: break
        var source: Label3D = entry.source
        var card: Label = entry.card
        var distance: float = entry.distance
        card.text = source.text
        card.custom_minimum_size.x = minf(240, screen.x - 32)
        card.size = Vector2(card.custom_minimum_size.x, 0)
        var factor: float = lerpf(1.0, 0.85, clampf(distance / MAX_DISTANCE, 0, 1))
        factor = minf(factor, (screen.x - 16) / maxf(1, card.size.x))
        card.scale = Vector2.ONE * factor
        var point: Vector2 = camera.unproject_position(source.global_position)
        var rect := Rect2(point - card.size * factor * 0.5, card.size * factor)
        if rect.position.x < 8 or rect.end.x > screen.x - 8 or rect.position.y < 80 or rect.end.y > screen.y - 130: continue
        var overlaps: bool = false
        for other in occupied:
            if rect.grow(4).intersects(other): overlaps = true; break
        if overlaps: continue
        card.position = rect.position
        card.visible = true
        occupied.append(rect)
        shown += 1
