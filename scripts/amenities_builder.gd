extends RefCounted
# Inside LASU v0.6 — build only new roadside set dressing.
# Approved campus centres/roads are sourced from the existing JSON, unchanged.
# All measurements here are metres. Data positions use map coordinates * WORLD_SCALE.

var _cached_materials: Dictionary = {}

func _material(color: Color, metallic: float = 0.0) -> StandardMaterial3D:
    var key: String = color.to_html() + "_" + str(metallic)
    if _cached_materials.has(key):
        return _cached_materials[key] as StandardMaterial3D
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mat.metallic = metallic
    mat.roughness = 0.74
    _cached_materials[key] = mat
    return mat

func _box(parent: Node3D, pos: Vector3, dimensions: Vector3, tint: Color, object_name: String) -> MeshInstance3D:
    var mesh_instance := MeshInstance3D.new()
    mesh_instance.name = object_name
    var box_mesh := BoxMesh.new()
    box_mesh.size = dimensions
    mesh_instance.mesh = box_mesh
    mesh_instance.position = pos
    mesh_instance.material_override = _material(tint)
    parent.add_child(mesh_instance)
    return mesh_instance

func _pole(parent: Node3D, pos: Vector3, radius: float, height: float, tint: Color, object_name: String) -> void:
    var instance := MeshInstance3D.new()
    instance.name = object_name
    var mesh := CylinderMesh.new()
    mesh.top_radius = radius
    mesh.bottom_radius = radius
    mesh.height = height
    mesh.radial_segments = 9
    instance.mesh = mesh
    instance.position = pos
    instance.material_override = _material(tint, 0.2)
    parent.add_child(instance)

func _label(parent: Node3D, caption: String, pos: Vector3, size: int = 48, color: Color = Color.WHITE, back: bool = false) -> void:
    var label := Label3D.new()
    label.text = caption
    label.name = "SignText"
    label.position = pos
    label.font_size = size
    label.pixel_size = 0.012
    label.modulate = color
    label.outline_size = 5
    label.outline_modulate = Color(0.04, 0.09, 0.14)
    label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
    if back:
        label.rotation.y = PI
    parent.add_child(label)

func _collision_box(parent: StaticBody3D, pos: Vector3, dimensions: Vector3) -> void:
    var collision := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = dimensions
    collision.shape = shape
    collision.position = pos
    parent.add_child(collision)

func create_all(parent: Node3D, data: Dictionary, scale: float) -> void:
    var collection := Node3D.new()
    collection.name = "CampusAmenities_v0_6"
    parent.add_child(collection)
    for record in data.get("shelters", []):
        _shelter(collection, record, scale)
    for record in data.get("billboards", []):
        _billboard(collection, record, scale)
    for record in data.get("vehicles", []):
        _parked_vehicle(collection, record, scale)

func _site_node(parent: Node3D, item: Dictionary, scale: float) -> Node3D:
    var node := Node3D.new()
    node.name = str(item.get("id", "NewAmenity"))
    var p: Array = item.get("position", [0.0, 0.0])
    node.position = Vector3(float(p[0]) * scale, 0.0, float(p[1]) * scale)
    node.rotation_degrees.y = float(item.get("rotation_degrees", 0.0))
    node.set_meta("amenity_id", str(item.get("id", "")))
    parent.add_child(node)
    return node

func _shelter(parent: Node3D, item: Dictionary, scale: float) -> void:
    # Fully covered, open-front waiting shelter with seating and curbside sign.
    var node := _site_node(parent, item, scale)
    node.set_meta("amenity_name", str(item.get("name", "Shuttle Stop")))
    var shelter_colliders := StaticBody3D.new()
    shelter_colliders.name = "ShelterPostsAndRearWallCollision"
    node.add_child(shelter_colliders)
    var width: float = float(item.get("width_m", 9.2))
    var depth: float = float(item.get("depth_m", 4.2))
    var concrete := Color(0.77, 0.75, 0.69)
    var charcoal := Color(0.16, 0.24, 0.29)
    var teal := Color(0.06, 0.46, 0.54)
    var wood := Color(0.66, 0.44, 0.25)
    _box(node, Vector3(0, 0.10, 0), Vector3(width, 0.20, depth), concrete, "RaisedWaitingPlatform")
    _box(node, Vector3(0, 0.24, depth * 0.50 - 0.10), Vector3(width, 0.16, 0.22), Color(0.91, 0.86, 0.65), "TactileBoardingEdge")
    # Shelter back, roof and structural posts leave the front accessible.
    _box(node, Vector3(0, 1.56, -depth * 0.48 + 0.12), Vector3(width * 0.90, 2.45, 0.12), Color(0.57, 0.77, 0.79), "ShelterRearGlazing")
    _collision_box(shelter_colliders, Vector3(0, 1.56, -depth * 0.48 + 0.12), Vector3(width * 0.90, 2.45, 0.12))
    for side in [-1.0, 1.0]:
        for fore_aft in [-1.0, 1.0]:
            var post_position := Vector3(side * (width * 0.45), 1.63, fore_aft * (depth * 0.43))
            _pole(node, post_position, 0.11, 3.24, charcoal, "ShelterSteelPost")
            _collision_box(shelter_colliders, post_position, Vector3(0.24, 3.24, 0.24))
    _box(node, Vector3(0, 3.32, 0), Vector3(width + 0.38, 0.30, depth + 0.32), teal, "CoveredShelterRoof")
    _box(node, Vector3(0, 3.17, depth * 0.51), Vector3(width, 0.46, 0.15), charcoal, "ShuttleSignFascia")
    _label(node, "LASU SHUTTLE STOP", Vector3(0, 3.17, depth * 0.51 + 0.092), 39)
    # Three separate benches; their backrests and feet make them recognisable at ground level.
    for x in [-width * 0.29, 0.0, width * 0.29]:
        _box(node, Vector3(x, 0.75, -0.50), Vector3(width * 0.23, 0.16, 0.65), wood, "ShelterBenchSeat")
        _box(node, Vector3(x, 1.18, -0.79), Vector3(width * 0.23, 0.80, 0.13), wood, "ShelterBenchBackrest")
        for dx in [-width * 0.085, width * 0.085]:
            _box(node, Vector3(x + dx, 0.46, -0.48), Vector3(0.12, 0.70, 0.10), charcoal, "BenchFrame")
    _box(node, Vector3(width * 0.40, 0.54, 0.46), Vector3(0.72, 0.92, 0.72), Color(0.30, 0.43, 0.36), "ShelterWasteBin")
    _pole(node, Vector3(-width * 0.56, 1.65, 0), 0.11, 3.3, charcoal, "StopSignPole")
    _box(node, Vector3(-width * 0.56, 3.15, 0), Vector3(1.0, 0.72, 0.18), teal, "StopSign")
    _label(node, "BUS", Vector3(-width * 0.56, 3.15, 0.12), 35)

func _billboard(parent: Node3D, item: Dictionary, scale: float) -> void:
    var node := _site_node(parent, item, scale)
    var board_id: String = str(item.get("id", "AD-000"))
    var billboard_colliders := StaticBody3D.new()
    billboard_colliders.name = "BillboardSupportCollision"
    node.add_child(billboard_colliders)
    var tier: String = str(item.get("size", "medium"))
    var panel_width: float = 6.4
    var panel_height: float = 3.15
    var center_y: float = 5.05
    if tier == "large":
        panel_width = 9.5
        panel_height = 4.3
        center_y = 6.5
    elif tier == "small":
        panel_width = 3.5
        panel_height = 2.05
        center_y = 3.9
    var navy := Color(0.11, 0.19, 0.29)
    var board_tint := Color(0.08, 0.48, 0.57) if tier != "small" else Color(0.75, 0.37, 0.21)
    var pole_height: float = center_y - panel_height * 0.5 + 0.25
    for side in [-1.0, 1.0]:
        var post_x: float = float(side) * panel_width * 0.34
        _pole(node, Vector3(post_x, pole_height * 0.5, 0), 0.17, pole_height, navy, "BillboardStructuralPost")
        _collision_box(billboard_colliders, Vector3(post_x, pole_height * 0.5, 0), Vector3(0.38, pole_height, 0.38))
        _box(node, Vector3(post_x, 0.10, 0), Vector3(0.8, 0.20, 0.80), Color(0.60, 0.60, 0.56), "BillboardFooting")
    _box(node, Vector3(0, center_y, 0), Vector3(panel_width + 0.20, panel_height + 0.2, 0.22), navy, "DoubleSidedBillboardFrame")
    for front in [true, false]:
        var z: float = 0.127 if front else -0.127
        var back: bool = not bool(front)
        _box(node, Vector3(0, center_y, z), Vector3(panel_width, panel_height, 0.04), board_tint, "AdvertisingPanel")
        _box(node, Vector3(0, center_y + panel_height * 0.32, z + (0.025 if front else -0.025)), Vector3(panel_width * 0.92, 0.12, 0.025), Color(0.95, 0.73, 0.40), "AdAccentStripe")
        var text_z: float = z + (0.045 if front else -0.045)
        _label(node, "YOUR AD HERE", Vector3(0, center_y + 0.20, text_z), 43 if tier == "small" else 73, Color(1.0, 0.98, 0.89), back)
        _label(node, board_id + "  |  INSIDE LASU", Vector3(0, center_y - panel_height * 0.24, text_z), 25 if tier == "small" else 33, Color(1.0, 0.90, 0.72), back)
    # Stable machine-readable IDs for future legitimate, moderated paid ad inventory.
    node.set_meta("ad_slot_id", board_id)
    node.set_meta("creative_key", str(item.get("creative_key", "")))
    node.set_meta("campaign_id", "")
    node.set_meta("live_ad_enabled", false)
    node.set_meta("ad_tier", tier)
    # Distance culling limits draw calls on low-powered laptop GPUs when 100
    # static ad slots exist. Slot metadata persists even when visuals are culled.
    var visual_range: float = 90.0 if tier == "small" else (160.0 if tier == "medium" else 240.0)
    for child_variant in node.get_children():
        var graphic: GeometryInstance3D = child_variant as GeometryInstance3D
        if graphic != null:
            graphic.visibility_range_end = visual_range

func _wheel(parent: Node3D, x: float, z: float, radius: float) -> void:
    var wheel := MeshInstance3D.new()
    wheel.name = "RubberTyre"
    var mesh := CylinderMesh.new()
    mesh.top_radius = radius
    mesh.bottom_radius = radius
    mesh.height = 0.27
    mesh.radial_segments = 12
    wheel.mesh = mesh
    wheel.position = Vector3(x, radius + 0.04, z)
    wheel.rotation.x = PI * 0.5
    wheel.material_override = _material(Color(0.10, 0.12, 0.13))
    parent.add_child(wheel)
    var hub := MeshInstance3D.new()
    hub.name = "SilverWheelHub"
    var hub_mesh := CylinderMesh.new()
    hub_mesh.top_radius = radius * 0.45
    hub_mesh.bottom_radius = radius * 0.45
    hub_mesh.height = 0.32
    hub_mesh.radial_segments = 10
    hub.mesh = hub_mesh
    hub.position = Vector3(x, radius + 0.04, z + (0.06 if z >= 0 else -0.06))
    hub.rotation.x = PI * 0.5
    hub.material_override = _material(Color(0.64, 0.69, 0.69), 0.40)
    parent.add_child(hub)

func _parked_vehicle(parent: Node3D, item: Dictionary, scale: float) -> void:
    # These are stationary props only; no road traffic and no vehicle boarding yet.
    var anchor := _site_node(parent, item, scale)
    var vehicle_type: String = str(item.get("type", "car"))
    var length: float = 6.5 if vehicle_type == "bus" else (5.3 if vehicle_type == "van" else 4.6)
    var breadth: float = 2.6 if vehicle_type == "bus" else 2.25
    var high: float = 2.95 if vehicle_type == "bus" else (2.55 if vehicle_type == "van" else 1.65)
    var main_color: Color = Color(0.94, 0.84, 0.53) if vehicle_type == "bus" else Color(0.93, 0.94, 0.91)
    if vehicle_type == "van":
        main_color = Color(0.21, 0.55, 0.63)
    elif vehicle_type == "car" and str(item.get("id", "")).ends_with("2"):
        main_color = Color(0.34, 0.47, 0.60)
    var vehicle := StaticBody3D.new()
    vehicle.name = "ParkedVehicle"
    vehicle.set_meta("vehicle_id", str(item.get("id", "")))
    vehicle.set_meta("status", "parked")
    anchor.add_child(vehicle)
    _box(vehicle, Vector3(0, 0.95, 0), Vector3(length, 1.15, breadth), main_color, "PaintedVehicleBody")
    _box(vehicle, Vector3(-length * 0.08, high * 0.67, 0), Vector3(length * 0.60, high * 0.66, breadth * 0.93), main_color, "VehiclePassengerCabin")
    _box(vehicle, Vector3(-length * 0.08, high + 0.06, 0), Vector3(length * 0.61, 0.14, breadth * 0.93), Color(0.16, 0.25, 0.31), "RoofPanel")
    _box(vehicle, Vector3(0, 1.0, breadth * 0.5 + 0.055), Vector3(length * 0.93, 0.15, 0.08), Color(0.10, 0.39, 0.47), "SideStripe")
    _box(vehicle, Vector3(0, 1.0, -breadth * 0.5 - 0.055), Vector3(length * 0.93, 0.15, 0.08), Color(0.10, 0.39, 0.47), "SideStripe")
    # Dark tinted side windows and windscreen.
    var glass := Color(0.14, 0.33, 0.43)
    for side in [-1.0, 1.0]:
        for i in range(3 if vehicle_type != "car" else 2):
            var divisions: int = 3 if vehicle_type != "car" else 2
            var window_x: float = -length * 0.32 + float(i) * length * 0.30 / float(maxi(divisions - 1, 1))
            _box(vehicle, Vector3(window_x, high * 0.79, float(side) * (breadth * 0.47 + 0.045)), Vector3(length * 0.16, high * 0.23, 0.065), glass, "PassengerWindow")
    _box(vehicle, Vector3(length * 0.20, high * 0.77, 0), Vector3(0.06, high * 0.24, breadth * 0.78), glass, "Windscreen")
    _box(vehicle, Vector3(length * 0.50 + 0.04, 1.05, -breadth * 0.31), Vector3(0.12, 0.25, 0.33), Color(1.0, 0.94, 0.72), "RightHeadlight")
    _box(vehicle, Vector3(length * 0.50 + 0.04, 1.05, breadth * 0.31), Vector3(0.12, 0.25, 0.33), Color(1.0, 0.94, 0.72), "LeftHeadlight")
    for x in [-length * 0.32, length * 0.31]:
        for side in [-1.0, 1.0]:
            _wheel(vehicle, x, float(side) * breadth * 0.48, 0.48 if vehicle_type == "car" else 0.55)
    if vehicle_type == "bus":
        _box(vehicle, Vector3(0, 1.14, breadth * 0.51), Vector3(length * 0.58, 0.22, 0.08), Color(0.13, 0.43, 0.53), "ShuttleBrandingStripe")
        _label(vehicle, "LASU SHUTTLE", Vector3(0, 1.27, breadth * 0.53 + 0.05), 30, Color(0.10, 0.21, 0.26))
    var collision := CollisionShape3D.new()
    var collision_box := BoxShape3D.new()
    collision_box.size = Vector3(length, high * 0.90, breadth)
    collision.shape = collision_box
    collision.position.y = high * 0.49
    vehicle.add_child(collision)
