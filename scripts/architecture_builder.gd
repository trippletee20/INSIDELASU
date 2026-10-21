extends RefCounted
# Inside LASU — procedural architecture system v0.5.
# Decorative meshes remain inside each existing feature's approved footprint.
# All positions are local to the original v0.4 StaticBody3D feature.

var material_cache: Dictionary = {}

func _mat(color: Color, metallic: float = 0.0, roughness: float = 0.82) -> StandardMaterial3D:
    var key = "%s_%s_%s" % [color.to_html(), str(metallic), str(roughness)]
    if material_cache.has(key):
        return material_cache[key]
    var m = StandardMaterial3D.new()
    m.albedo_color = color
    m.metallic = metallic
    m.roughness = roughness
    material_cache[key] = m
    return m

func _block(parent: Node3D, pos: Vector3, size: Vector3, color: Color, title: String = "") -> MeshInstance3D:
    var node = MeshInstance3D.new()
    node.name = title if not title.is_empty() else "ArchitecturalDetail"
    var mesh = BoxMesh.new()
    mesh.size = Vector3(max(size.x, 0.05), max(size.y, 0.05), max(size.z, 0.05))
    node.mesh = mesh
    node.position = pos
    node.material_override = _mat(color)
    parent.add_child(node)
    return node

func _cylinder(parent: Node3D, pos: Vector3, radius: float, height: float, color: Color, sides: int = 12) -> void:
    var node = MeshInstance3D.new()
    var mesh = CylinderMesh.new()
    mesh.top_radius = radius
    mesh.bottom_radius = radius
    mesh.height = height
    mesh.radial_segments = sides
    node.mesh = mesh
    node.position = pos
    node.material_override = _mat(color)
    parent.add_child(node)

func _sign(parent: Node3D, caption: String, pos: Vector3, width: float, color: Color = Color(0.08, 0.23, 0.33)) -> void:
    _block(parent, pos, Vector3(width, 1.05, 0.17), color, "EntranceSignBoard")
    var label = Label3D.new()
    label.text = caption
    label.position = pos + Vector3(0, 0.0, 0.12)
    label.font_size = 34
    label.pixel_size = 0.008
    label.modulate = Color(1.0, 0.97, 0.83)
    label.outline_size = 4
    label.outline_modulate = Color(0.03, 0.09, 0.15)
    label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
    parent.add_child(label)

func _windows(parent: Node3D, width: float, depth: float, height: float, floors: int, tint: Color) -> void:
    # Windows share one mesh + material via MultiMesh, avoiding thousands of nodes.
    var mm = MultiMesh.new()
    mm.transform_format = MultiMesh.TRANSFORM_3D
    var pane = BoxMesh.new()
    pane.size = Vector3(1.65, 1.32, 0.11)
    mm.mesh = pane
    var transforms: Array[Transform3D] = []
    var row_height = height / float(floors)
    var count_x: int = clampi(int(width / 4.4), 2, 13)
    var count_z: int = clampi(int(depth / 4.6), 1, 9)
    for level in range(floors):
        var y = row_height * (float(level) + 0.56)
        if y > height - 0.7:
            continue
        for ix in range(count_x):
            var x = -width * 0.42 + width * 0.84 * (float(ix) + 0.5) / float(count_x)
            # Keep the front centre free for the door at ground level.
            if level == 0 and abs(x) < 2.2:
                continue
            transforms.append(Transform3D(Basis.IDENTITY, Vector3(x, y, depth * 0.5 + 0.07)))
            transforms.append(Transform3D(Basis.IDENTITY, Vector3(x, y, -depth * 0.5 - 0.07)))
        for iz in range(count_z):
            var z = -depth * 0.40 + depth * 0.80 * (float(iz) + 0.5) / float(count_z)
            var side_basis = Basis(Vector3.UP, PI * 0.5)
            transforms.append(Transform3D(side_basis, Vector3(width * 0.5 + 0.07, y, z)))
            transforms.append(Transform3D(side_basis, Vector3(-width * 0.5 - 0.07, y, z)))
    mm.instance_count = transforms.size()
    for i in range(transforms.size()):
        mm.set_instance_transform(i, transforms[i])
    var inst = MultiMeshInstance3D.new()
    inst.name = "ReflectiveWindows"
    inst.multimesh = mm
    inst.material_override = _mat(tint, 0.2, 0.25)
    parent.add_child(inst)

func _shell(parent: Node3D, w: float, d: float, h: float, wall: Color, roof: Color, trim: Color, floors: int, name: String) -> void:
    _block(parent, Vector3(0, h * 0.5, 0), Vector3(w, h, d), wall, "BuildingMass")
    _block(parent, Vector3(0, h + 0.28, 0), Vector3(w + 0.85, 0.56, d + 0.85), roof, "RoofSlab")
    # A shadow line separates each floor and reads well from a third-person camera.
    for i in range(1, floors):
        var y = h * float(i) / float(floors)
        _block(parent, Vector3(0, y, 0), Vector3(w + 0.32, 0.14, d + 0.32), trim, "FloorBand")
    _windows(parent, w, d, h, floors, Color(0.19, 0.38, 0.47))
    # Main entrance is recessed visually, with canopy, steps and paired pillars.
    var face = d * 0.5
    _block(parent, Vector3(0, 1.75, face + 0.10), Vector3(2.5, 3.3, 0.18), Color(0.10, 0.21, 0.29), "EntranceDoors")
    _block(parent, Vector3(0, 0.18, face + 1.35), Vector3(4.8, 0.32, 2.65), Color(0.77, 0.76, 0.69), "EntranceLanding")
    _block(parent, Vector3(0, 0.08, face + 2.5), Vector3(5.8, 0.16, 1.2), Color(0.67, 0.67, 0.62), "FrontStep")
    _block(parent, Vector3(0, 4.15, face + 1.05), Vector3(6.2, 0.27, 2.3), roof, "EntranceCanopy")
    for sign in [-1.0, 1.0]:
        _block(parent, Vector3(sign * 2.65, 2.05, face + 1.75), Vector3(0.34, 4.1, 0.34), trim, "EntranceColumn")
    _sign(parent, _short_name(name), Vector3(0, 4.9, face + 0.55), min(max(w * 0.76, 7.0), 17.0))

func _short_name(name: String) -> String:
    var abbreviations = {
        "Buba Marwa Auditorium": "BUBA MARWA AUDITORIUM",
        "Senate Building": "SENATE BUILDING",
        "New Library": "NEW LIBRARY",
        "LASU Chapel": "LASU CHAPEL",
        "Faculty of Social Sciences": "SOCIAL SCIENCES",
        "Faculty of Management Sciences": "MANAGEMENT SCIENCES",
        "Faculty of Education": "FACULTY OF EDUCATION",
        "Faculty of Arts": "FACULTY OF ARTS",
        "Faculty of Law": "FACULTY OF LAW",
        "Bola Ahmed Tinubu Science Complex": "SCIENCE COMPLEX",
        "LASU International School": "INTERNATIONAL SCHOOL",
        "LASU Healthcare Centre": "LASU HEALTH CENTRE"
    }
    if abbreviations.has(name):
        return abbreviations[name]
    if name.length() > 29:
        return name.substr(0, 28).to_upper()
    return name.to_upper()

func _pavilion(parent: Node3D, x: float, z: float, w: float, d: float, h: float, accent: Color) -> void:
    # Open-sided tiered spectators' stand with roof and support columns.
    var concrete = Color(0.73, 0.72, 0.67)
    for i in range(4):
        var rise = float(i) * 0.52
        var tread_depth = d / 4.0
        var z_step = z - d * 0.5 + tread_depth * (float(i) + 0.5)
        _block(parent, Vector3(x, 0.30 + rise * 0.5, z_step), Vector3(w, 0.6 + rise, tread_depth), concrete, "GrandstandTier")
        _block(parent, Vector3(x, 0.65 + rise, z_step), Vector3(w * 0.96, 0.10, tread_depth * 0.62), accent, "SpectatorBench")
    for side in [-1.0, 1.0]:
        for offset in [-0.38, 0.38]:
            _block(parent, Vector3(x + side * w * 0.46, h * 0.5, z + offset * d), Vector3(0.28, h, 0.28), Color(0.85, 0.86, 0.83), "PavilionColumn")
    _block(parent, Vector3(x, h + 0.2, z), Vector3(w + 1.6, 0.40, d + 1.5), accent, "PavilionRoof")

func _sports(parent: Node3D, w: float, d: float) -> void:
    # Composite sports centre: playing field + covered stand + sports hall.
    # All elements fit inside the existing approved Sports Centre footprint.
    var hall_w: float = minf(w * 0.26, 24.0)
    var field_w: float = w * 0.54
    var field_d: float = d * 0.65
    var field_x: float = -w * 0.10
    var green = Color(0.20, 0.53, 0.30)
    _block(parent, Vector3(field_x, 0.09, 0), Vector3(field_w, 0.17, field_d), green, "SportsPlayingField")
    # White touchlines and halfway stripe.
    var white = Color(0.91, 0.93, 0.84)
    for s in [-1.0, 1.0]:
        _block(parent, Vector3(field_x, 0.20, s * (field_d * 0.5 - 0.28)), Vector3(field_w - 0.7, 0.025, 0.16), white, "FieldTouchline")
        _block(parent, Vector3(field_x + s * (field_w * 0.5 - 0.32), 0.20, 0), Vector3(0.16, 0.025, field_d - 0.7), white, "FieldGoalLine")
    _block(parent, Vector3(field_x, 0.20, 0), Vector3(0.16, 0.025, field_d - 0.7), white, "FieldHalfwayLine")
    # Two goal frames with uprights and crossbars.
    for side in [-1.0, 1.0]:
        var gx: float = field_x + float(side) * (field_w * 0.5 - 1.2)
        for zz in [-2.2, 2.2]:
            _block(parent, Vector3(gx, 1.35, zz), Vector3(0.17, 2.7, 0.17), white, "GoalPost")
        _block(parent, Vector3(gx, 2.65, 0), Vector3(0.17, 0.17, 4.6), white, "GoalCrossbar")
    # Spectators' gallery sits on one long side of the field.
    _pavilion(parent, field_x, -d * 0.35, field_w * 0.64, d * 0.19, 5.2, Color(0.15, 0.34, 0.48))
    # Covered indoor sports hall at the opposite end of the same sports site.
    var hall_x: float = w * 0.5 - hall_w * 0.5 - 1.5
    var hall_d: float = d * 0.77
    _block(parent, Vector3(hall_x, 5.4, 0), Vector3(hall_w, 10.8, hall_d), Color(0.79, 0.81, 0.76), "SportsHallMass")
    _block(parent, Vector3(hall_x, 11.0, 0), Vector3(hall_w + 1.3, 0.65, hall_d + 1.3), Color(0.19, 0.36, 0.49), "SportsHallRoof")
    for j in range(4):
        var xx = hall_x - hall_w * 0.35 + hall_w * 0.7 * float(j) / 3.0
        _block(parent, Vector3(xx, 6.6, hall_d * 0.5 + 0.08), Vector3(1.6, 3.0, 0.12), Color(0.20, 0.43, 0.54), "SportsHallWindow")
    _block(parent, Vector3(hall_x, 2.0, hall_d * 0.5 + 0.12), Vector3(3.5, 3.8, 0.18), Color(0.13, 0.23, 0.30), "SportsHallEntrance")
    _sign(parent, "LASU SPORTS HALL", Vector3(hall_x, 9.3, hall_d * 0.5 + 0.20), hall_w * 0.80)
    # Distinct sports-centre sign facing the road.
    _sign(parent, "LASU SPORTS CENTRE", Vector3(-w * 0.29, 1.65, d * 0.5 - 0.7), min(19.0, w * 0.3))

func _arcade(parent: Node3D, w: float, d: float, h: float) -> void:
    # LASU Arcade: GROUND FLOOR + ONE UPPER FLOOR (two levels total).
    # Dedicated retail architecture rather than a row of open-air market stalls.
    # Body, balcony and facade remain inside the inherited approved site outline.
    var cream := Color(0.87, 0.82, 0.70)
    var dark := Color(0.12, 0.27, 0.32)
    var teal := Color(0.11, 0.47, 0.52)
    var trim := Color(0.95, 0.91, 0.80)
    var front: float = d * 0.42
    var body_w: float = w * 0.92
    var body_d: float = d * 0.84
    var floor_height: float = h * 0.50
    _block(parent, Vector3(0, h * 0.5, 0), Vector3(body_w, h, body_d), cream, "ArcadeTwoStoreyMass")
    _block(parent, Vector3(0, floor_height, 0), Vector3(body_w + 0.16, 0.30, body_d + 0.16), trim, "VisibleFloorSeparation")
    _block(parent, Vector3(0, h + 0.18, 0), Vector3(body_w + 0.35, 0.36, body_d + 0.28), dark, "ArcadeRoof")
    _block(parent, Vector3(0, h + 0.52, -body_d * 0.44), Vector3(body_w * 0.92, 0.66, 0.28), cream, "RooftopParapetRear")
    for side in [-1.0, 1.0]:
        _block(parent, Vector3(side * body_w * 0.49, h + 0.52, 0), Vector3(0.24, 0.66, body_d * 0.93), cream, "RooftopParapetSide")
    # Ground floor retail front: distinct shopfront bays and door openings.
    var shop_count: int = 6
    var bay_w: float = body_w * 0.90 / float(shop_count)
    for i in range(shop_count):
        var bx: float = -body_w * 0.45 + bay_w * (float(i) + 0.5)
        _block(parent, Vector3(bx, floor_height * 0.48, front + 0.09), Vector3(bay_w * 0.77, floor_height * 0.70, 0.14), Color(0.14, 0.37, 0.46), "GroundFloorShopGlazing")
        _block(parent, Vector3(bx, floor_height * 0.85, front + 0.16), Vector3(bay_w * 0.83, 0.26, 0.18), teal if i % 2 == 0 else dark, "ShopfrontAwning")
        _block(parent, Vector3(bx, 0.46, front + 0.17), Vector3(bay_w * 0.70, 0.85, 0.18), Color(0.31, 0.46, 0.49), "ShopDoor")
        # Upper level has an independent row of windows above its balcony.
        _block(parent, Vector3(bx, floor_height + floor_height * 0.52, front + 0.09), Vector3(bay_w * 0.76, floor_height * 0.45, 0.14), Color(0.13, 0.36, 0.46), "UpperLevelWindow")
    # Continuous upstairs gallery with railings; clearly shows the accessible upper floor.
    _block(parent, Vector3(0, floor_height + 0.07, front + 0.54), Vector3(body_w * 0.90, 0.18, 0.95), Color(0.78, 0.78, 0.74), "UpstairsGalleryFloor")
    _block(parent, Vector3(0, floor_height + 0.75, front + 0.98), Vector3(body_w * 0.88, 0.12, 0.10), dark, "UpperGalleryHandrail")
    for j in range(13):
        var rx: float = -body_w * 0.42 + float(j) * body_w * 0.84 / 12.0
        _block(parent, Vector3(rx, floor_height + 0.42, front + 0.97), Vector3(0.07, 0.76, 0.07), dark, "UpperBalconyBaluster")
    _block(parent, Vector3(0, floor_height + 0.09, front + 0.15), Vector3(body_w * 0.94, 0.30, 0.24), teal, "ArcadeFloorBand")
    _block(parent, Vector3(0, 0.10, front + 0.48), Vector3(body_w * 0.94, 0.20, 0.90), Color(0.80, 0.78, 0.68), "CoveredShoppingWalkway")
    _sign(parent, "LASU STUDENT ARCADE", Vector3(0, floor_height + 0.90, front + 0.24), minf(body_w * 0.75, 22.0), dark)

func _market(parent: Node3D, w: float, d: float, name: String) -> void:
    var pavement = Color(0.74, 0.70, 0.61)
    _block(parent, Vector3(0, 0.10, 0), Vector3(w, 0.20, d), pavement, "MarketPlaza")
    var stalls = clampi(int(w / 5.0), 2, 7)
    for i in range(stalls):
        var x = -w * 0.43 + w * 0.86 * (float(i) + 0.5) / float(stalls)
        var z = -d * 0.16
        _block(parent, Vector3(x, 1.2, z), Vector3(min(3.3, w / float(stalls) * 0.80), 2.3, d * 0.38), Color(0.91, 0.78, 0.55), "MarketStall")
        var roof_color: Color = Color(0.84, 0.36, 0.23) if i % 2 == 0 else Color(0.20, 0.49, 0.66)
        _block(parent, Vector3(x, 2.6, z), Vector3(min(3.8, w / float(stalls) * 0.90), 0.26, d * 0.48), roof_color, "MarketCanopy")
    _sign(parent, _short_name(name), Vector3(0, 3.0, d * 0.42), min(w * 0.8, 16.0))

func _chapel(parent: Node3D, w: float, d: float, h: float) -> void:
    _shell(parent, w * 0.87, d * 0.85, h * 0.72, Color(0.92, 0.86, 0.72), Color(0.35, 0.22, 0.22), Color(0.84, 0.77, 0.66), 2, "LASU Chapel")
    _block(parent, Vector3(0, h * 0.83, 0), Vector3(w * 0.42, h * 0.28, d * 0.33), Color(0.86, 0.80, 0.67), "ChapelTower")
    _block(parent, Vector3(0, h * 1.12, 0), Vector3(0.30, 3.0, 0.30), Color(0.73, 0.55, 0.26), "ChapelCrossVertical")
    _block(parent, Vector3(0, h * 1.17, 0), Vector3(2.1, 0.30, 0.30), Color(0.73, 0.55, 0.26), "ChapelCrossHorizontal")

func _auditorium(parent: Node3D, w: float, d: float, h: float, name: String) -> void:
    _shell(parent, w, d, h * 0.82, Color(0.86, 0.73, 0.55), Color(0.21, 0.32, 0.41), Color(0.94, 0.85, 0.66), 2, name)
    # Distinctive portico, curved-looking roof profile in low-poly sections.
    _block(parent, Vector3(0, h * 0.84, 0), Vector3(w + 1.3, 0.62, d + 1.3), Color(0.23, 0.35, 0.43), "AuditoriumRoof")
    for i in range(4):
        var xx = -w * 0.35 + w * 0.7 * float(i) / 3.0
        _cylinder(parent, Vector3(xx, 2.75, d * 0.5 + 1.9), 0.23, 5.5, Color(0.94, 0.92, 0.85))

func _incomplete(parent: Node3D, w: float, d: float, h: float) -> void:
    var concrete = Color(0.58, 0.60, 0.61)
    var floors: int = clampi(int(round(h / 4.0)), 2, 4)
    for i in range(floors):
        var y = float(i) * h / float(floors)
        _block(parent, Vector3(0, y + 0.17, 0), Vector3(w, 0.34, d), concrete, "UnfinishedFloorSlab")
    for sx in [-1.0, 1.0]:
        for sz in [-1.0, 1.0]:
            _block(parent, Vector3(sx * (w * 0.5 - 0.55), h * 0.5, sz * (d * 0.5 - 0.55)), Vector3(0.75, h, 0.75), concrete, "UnfinishedPillar")
    _block(parent, Vector3(0, 0.65, d * 0.5 + 0.3), Vector3(min(w * 0.65, 6.0), 1.3, 0.3), Color(0.75, 0.45, 0.20), "ConstructionBarrier")

func _garden(parent: Node3D, w: float, d: float, name: String) -> void:
    _block(parent, Vector3(0, 0.08, 0), Vector3(w, 0.15, d), Color(0.30, 0.62, 0.37), "GardenLawn")
    _block(parent, Vector3(0, 0.17, 0), Vector3(1.7, 0.10, d * 0.85), Color(0.85, 0.77, 0.58), "GardenWalkway")
    for side in [-1.0, 1.0]:
        for i in range(3):
            var z = -d * 0.34 + d * 0.34 * float(i)
            _block(parent, Vector3(side * w * 0.31, 0.40, z), Vector3(2.3, 0.27, 0.6), Color(0.48, 0.32, 0.19), "ParkBench")
            _block(parent, Vector3(side * w * 0.31, 0.85, z + 0.30), Vector3(2.3, 0.78, 0.17), Color(0.48, 0.32, 0.19), "BenchBack")

func _gate(parent: Node3D, name: String, w: float, d: float) -> void:
    var span: float = maxf(w * 0.70, 8.0)
    var height: float = 5.5
    for side in [-1.0, 1.0]:
        _block(parent, Vector3(side * span * 0.5, height * 0.5, 0), Vector3(1.0, height, 1.0), Color(0.88, 0.83, 0.68), "GatePillar")
        _block(parent, Vector3(side * span * 0.5, 0.4, 0), Vector3(1.55, 0.8, 1.55), Color(0.46, 0.47, 0.44), "GateBase")
    _block(parent, Vector3(0, height + 0.2, 0), Vector3(span + 1.0, 0.65, 1.4), Color(0.13, 0.36, 0.46), "GateBeam")
    _sign(parent, _short_name(name), Vector3(0, height + 0.25, 0.83), span * 0.78)

func build(parent: Node3D, item: Dictionary, w: float, d: float, h: float) -> void:
    var name = str(item.get("name", "Building"))
    var kind = str(item.get("kind", "academic"))
    var lower = name.to_lower()
    if lower.contains("incomplete") or lower.contains("almost complete"):
        _incomplete(parent, w, d, h)
        return
    if name == "Sports Centre":
        _sports(parent, w, d)
        return
    if kind == "outdoor":
        _garden(parent, w, d, name)
        return
    if name == "Arcade":
        _arcade(parent, w, d, h)
        return
    if kind == "commercial":
        _market(parent, w, d, name)
        return
    if name == "LASU Chapel":
        _chapel(parent, w, d, h)
        return
    if lower.contains("auditorium") or lower.contains("hall") and name == "Femi Gbajabiamila Hall":
        _auditorium(parent, w, d, h, name)
        return
    var wall = Color(0.84, 0.79, 0.68)
    var roof = Color(0.19, 0.34, 0.43)
    var trim = Color(0.91, 0.89, 0.80)
    var floors: int = clampi(int(round(h / 5.0)), 2, 4)
    if name == "New Library":
        wall = Color(0.85, 0.88, 0.86)
        roof = Color(0.15, 0.35, 0.43)
        trim = Color(0.22, 0.49, 0.59)
        floors = 4
    elif name == "Senate Building":
        wall = Color(0.86, 0.79, 0.65)
        roof = Color(0.35, 0.27, 0.24)
        trim = Color(0.93, 0.85, 0.69)
    elif name == "LASU Radio":
        wall = Color(0.80, 0.87, 0.87)
        roof = Color(0.15, 0.35, 0.45)
        trim = Color(0.35, 0.65, 0.70)
        floors = 2
    elif name == "Mass Communication":
        wall = Color(0.85, 0.78, 0.69)
        roof = Color(0.23, 0.35, 0.47)
        trim = Color(0.42, 0.62, 0.65)
        floors = 3
    elif lower.contains("faculty") or lower.contains("sciences"):
        wall = Color(0.84, 0.79, 0.70)
        roof = Color(0.27, 0.39, 0.44)
        trim = Color(0.95, 0.87, 0.72)
    elif kind == "residential":
        wall = Color(0.91, 0.77, 0.67)
        roof = Color(0.44, 0.27, 0.24)
        trim = Color(0.99, 0.90, 0.76)
        floors = clampi(int(round(h / 5.0)), 2, 5)
    elif lower.contains("innovation") or lower.contains("stem"):
        wall = Color(0.79, 0.85, 0.86)
        roof = Color(0.16, 0.38, 0.48)
        trim = Color(0.29, 0.59, 0.67)
    _shell(parent, w, d, h, wall, roof, trim, floors, name)
    if name == "LASU Radio":
        # Short visible broadcast mast identifies the separate radio building.
        _block(parent, Vector3(0, h + 2.2, 0), Vector3(0.21, 4.4, 0.21), Color(0.55, 0.58, 0.62), "RadioMast")
        _block(parent, Vector3(0, h + 4.25, 0), Vector3(2.2, 0.15, 0.15), Color(0.68, 0.71, 0.75), "RadioAntennaBar")
    if name == "Mass Communication":
        # Distinctive glass-fronted academic media faculty, separate from radio.
        _block(parent, Vector3(0, h * 0.55, d * 0.5 + 0.13), Vector3(w * 0.45, h * 0.43, 0.18), Color(0.18, 0.40, 0.51), "MassCommGlassFacade")
    if name == "Senate Building":
        # Monumental entrance portico and broad administrative forecourt.
        _block(parent, Vector3(0, 0.10, d * 0.5 + 3.3), Vector3(w * 0.60, 0.18, 4.0), Color(0.80, 0.78, 0.69), "SenateForecourt")
    if name == "New Library":
        # Emphasise its multi-storey glazing and public entrance.
        _block(parent, Vector3(0, h * 0.50, d * 0.5 + 0.12), Vector3(w * 0.48, h * 0.78, 0.18), Color(0.17, 0.42, 0.51), "LibraryGlassAtrium")
        _block(parent, Vector3(0, h + 0.69, 0), Vector3(w * 0.44, 0.42, d * 0.30), Color(0.18, 0.34, 0.42), "LibraryRoofLantern")
