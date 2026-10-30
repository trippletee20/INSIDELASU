extends RefCounted
# Batch only static architecture boxes, grouped per building/material/detail tier.
# Original nodes stay as hidden geometry metadata for seat/footprint consumers.
static func batch(parent: Node3D) -> void:
    var groups: Dictionary = {}
    for child in parent.get_children():
        if not child is MeshInstance3D or not child.mesh is BoxMesh or not child.visible: continue
        var small: bool = child.mesh.size.length() < 4.0
        var key: String = str(child.material_override.get_instance_id()) + ":" + str(small)
        if not groups.has(key): groups[key] = []
        groups[key].append(child)
    for key in groups:
        var pieces: Array = groups[key]
        if pieces.size() < 3: continue
        var multi := MultiMesh.new()
        multi.transform_format = MultiMesh.TRANSFORM_3D
        multi.mesh = BoxMesh.new()
        multi.instance_count = pieces.size()
        for i in range(pieces.size()):
            var source: MeshInstance3D = pieces[i]
            var pose: Transform3D = source.transform
            pose.basis = pose.basis * Basis.from_scale(source.mesh.size)
            multi.set_instance_transform(i, pose)
            source.visible = false
        var instance := MultiMeshInstance3D.new()
        instance.name = "ArchitectureBatch"
        instance.multimesh = multi
        instance.material_override = pieces[0].material_override
        parent.add_child(instance)
        if pieces[0].mesh.size.length() < 4.0:
            instance.add_to_group("performance_detail")
            instance.visibility_range_end_margin = 8.0

static func apply_lod(tree: SceneTree, quality: String) -> void:
    for detail in tree.get_nodes_in_group("performance_detail"):
        detail.visibility_range_end = {"low": 65.0, "medium": 100.0, "high": 150.0}[quality]

static func road_boxes(parent: Node3D, transforms: Array[Transform3D], material: Material) -> void:
    # Spatial chunks retain useful culling instead of one campus-wide batch.
    var cells: Dictionary = {}
    for pose in transforms:
        var cell := Vector2i(floori(pose.origin.x / 32.0), floori(pose.origin.z / 32.0))
        if not cells.has(cell): cells[cell] = []
        cells[cell].append(pose)
    for cell in cells:
        var multi := MultiMesh.new()
        multi.transform_format = MultiMesh.TRANSFORM_3D
        multi.mesh = BoxMesh.new()
        multi.instance_count = cells[cell].size()
        for i in range(multi.instance_count): multi.set_instance_transform(i, cells[cell][i])
        var instance := MultiMeshInstance3D.new()
        instance.name = "RoadVisualBatch"
        instance.multimesh = multi
        instance.material_override = material
        parent.add_child(instance)
