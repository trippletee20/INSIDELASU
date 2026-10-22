extends CharacterBody3D

@export var move_speed: float = 6.3
@export var run_speed: float = 10.5
@export var jump_velocity: float = 5.0
@export var mouse_sensitivity: float = 0.0025

var gravity: float = 18.0
var camera_pivot: Node3D
var camera: Camera3D
var nearby_feature: Node3D = null
var avatar_left_arm: Node3D
var avatar_right_arm: Node3D
var avatar_left_leg: Node3D
var avatar_right_leg: Node3D
var walk_cycle: float = 0.0
var is_sitting: bool = false
var avatar_gender: String = "Prefer not to say"
var avatar_student_name: String = "Student"
var sitting_anchor: Node3D = null
var pre_sit_position: Vector3 = Vector3.ZERO
var pre_sit_rotation: Vector3 = Vector3.ZERO

func _ready() -> void:
    name = "Player"
    _create_student_avatar()
    var collision := CollisionShape3D.new()
    var shape := CapsuleShape3D.new()
    shape.radius = 0.35
    shape.height = 1.7
    collision.shape = shape
    collision.position.y = 0.9
    add_child(collision)
    camera_pivot = Node3D.new()
    camera_pivot.position.y = 1.4
    add_child(camera_pivot)
    camera = Camera3D.new()
    camera.position = Vector3(0, 2.0, 6.8)
    camera.rotation_degrees.x = -14.0
    camera.current = true
    if OS.has_feature("web"):
        camera.far = 220.0
    camera_pivot.add_child(camera)
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if OS.has_feature("web") else Input.MOUSE_MODE_CAPTURED

func _avatar_block(parent: Node3D, name_text: String, pos: Vector3, size: Vector3, color: Color) -> void:
    var node := MeshInstance3D.new()
    node.name = name_text
    var mesh := BoxMesh.new()
    mesh.size = size
    node.mesh = mesh
    node.position = pos
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.roughness = 0.88
    node.material_override = material
    parent.add_child(node)

func _avatar_sphere(parent: Node3D, name_text: String, pos: Vector3, scale_value: Vector3, color: Color) -> MeshInstance3D:
    var piece: MeshInstance3D = MeshInstance3D.new()
    piece.name = name_text
    var sphere: SphereMesh = SphereMesh.new()
    sphere.radius = 0.24
    sphere.height = 0.48
    sphere.radial_segments = 14
    sphere.rings = 8
    piece.mesh = sphere
    piece.position = pos
    piece.scale = scale_value
    var mat: StandardMaterial3D = StandardMaterial3D.new()
    mat.albedo_color = color
    mat.roughness = 0.89
    piece.material_override = mat
    parent.add_child(piece)
    return piece

func _avatar_capsule(parent: Node3D, name_text: String, pos: Vector3, radius: float, height: float, color: Color) -> MeshInstance3D:
    var piece: MeshInstance3D = MeshInstance3D.new()
    piece.name = name_text
    var capsule: CapsuleMesh = CapsuleMesh.new()
    capsule.radius = radius
    capsule.height = maxf(height, radius * 2.05)
    capsule.radial_segments = 12
    capsule.rings = 6
    piece.mesh = capsule
    piece.position = pos
    var mat: StandardMaterial3D = StandardMaterial3D.new()
    mat.albedo_color = color
    mat.roughness = 0.88
    piece.material_override = mat
    parent.add_child(piece)
    return piece

func apply_profile_appearance(gender: String, student_name: String = "Student") -> void:
    avatar_gender = gender
    avatar_student_name = student_name
    for existing_name in ["Torso", "Neck", "Head", "Hair", "Backpack", "LeftStrap", "RightStrap", "LeftArmRig", "RightArmRig", "LeftLegRig", "RightLegRig"]:
        var previous: Node = get_node_or_null(existing_name)
        if previous != null:
            remove_child(previous)
            previous.queue_free()
    _create_student_avatar()

func _create_student_avatar() -> void:
    # Low-poly rounded characters: gender presentation affects hair and clothing,
    # with no difference in movement, hitbox, gameplay privilege or body height.
    var female_presentation: bool = avatar_gender == "Female"
    var look_seed: int = avatar_student_name.length() % 4
    var skin_choices: Array[Color] = [Color(0.35, 0.20, 0.13), Color(0.49, 0.29, 0.19), Color(0.61, 0.38, 0.25), Color(0.72, 0.49, 0.35)]
    var skin: Color = skin_choices[look_seed]
    var shirt: Color = Color(0.73, 0.32, 0.39) if female_presentation else Color(0.12, 0.37, 0.56)
    if avatar_gender == "Prefer not to say":
        shirt = Color(0.21, 0.51, 0.42)
    var trousers: Color = Color(0.14, 0.17, 0.25)
    var shoe: Color = Color(0.94, 0.94, 0.88)
    _avatar_capsule(self, "Torso", Vector3(0, 1.12, 0), 0.26, 0.73, shirt)
    _avatar_capsule(self, "Neck", Vector3(0, 1.49, 0), 0.07, 0.15, skin)
    _avatar_sphere(self, "Head", Vector3(0, 1.68, -0.01), Vector3(0.90, 1.02, 0.86), skin)
    var hair: MeshInstance3D = _avatar_sphere(self, "Hair", Vector3(0, 1.855, 0.035), Vector3(1.02, 0.48, 0.92), Color(0.08, 0.06, 0.065))
    if female_presentation:
        # Stylised long braids tucked behind the shoulders; lightweight mesh objects.
        for side in [-1.0, 1.0]:
            _avatar_capsule(hair, "Braid", Vector3(float(side) * 0.18, -0.28, 0.14), 0.055, 0.55, Color(0.085, 0.06, 0.055))
        _avatar_sphere(hair, "HairBun", Vector3(0, -0.10, 0.24), Vector3(0.60, 0.55, 0.75), Color(0.07, 0.06, 0.055))
    else:
        for side in [-1.0, 1.0]:
            _avatar_sphere(hair, "HairTexture", Vector3(float(side) * 0.13, 0.08, 0), Vector3(0.31, 0.30, 0.38), Color(0.11, 0.085, 0.085))
    # Face looks toward -Z, as in the original third-person model.
    for side in [-1.0, 1.0]:
        _avatar_sphere(self, "Eye", Vector3(float(side) * 0.085, 1.70, -0.202), Vector3(0.13, 0.13, 0.08), Color(0.10, 0.085, 0.09))
        _avatar_sphere(self, "Brow", Vector3(float(side) * 0.086, 1.756, -0.189), Vector3(0.26, 0.08, 0.09), Color(0.08, 0.065, 0.06))
    _avatar_sphere(self, "Nose", Vector3(0, 1.645, -0.225), Vector3(0.15, 0.19, 0.18), skin)
    _avatar_sphere(self, "Mouth", Vector3(0, 1.589, -0.207), Vector3(0.29, 0.07, 0.08), Color(0.27, 0.12, 0.13))
    # Backpack and straps are deliberately compact so the player fits paths.
    _avatar_sphere(self, "Backpack", Vector3(0, 1.12, 0.252), Vector3(0.85, 1.06, 0.43), Color(0.79, 0.52, 0.20))
    _avatar_block(self, "LeftStrap", Vector3(-0.17, 1.19, 0.18), Vector3(0.075, 0.58, 0.055), Color(0.30, 0.22, 0.17))
    _avatar_block(self, "RightStrap", Vector3(0.17, 1.19, 0.18), Vector3(0.075, 0.58, 0.055), Color(0.30, 0.22, 0.17))
    avatar_left_arm = Node3D.new()
    avatar_left_arm.name = "LeftArmRig"
    avatar_left_arm.position = Vector3(-0.31, 1.37, 0)
    add_child(avatar_left_arm)
    _avatar_capsule(avatar_left_arm, "LeftSleeve", Vector3(0, -0.22, 0), 0.115, 0.41, shirt)
    _avatar_sphere(avatar_left_arm, "LeftHand", Vector3(0, -0.52, 0), Vector3(0.34, 0.48, 0.35), skin)
    avatar_right_arm = Node3D.new()
    avatar_right_arm.name = "RightArmRig"
    avatar_right_arm.position = Vector3(0.31, 1.37, 0)
    add_child(avatar_right_arm)
    _avatar_capsule(avatar_right_arm, "RightSleeve", Vector3(0, -0.22, 0), 0.115, 0.41, shirt)
    _avatar_sphere(avatar_right_arm, "RightHand", Vector3(0, -0.52, 0), Vector3(0.34, 0.48, 0.35), skin)
    avatar_left_leg = Node3D.new()
    avatar_left_leg.name = "LeftLegRig"
    avatar_left_leg.position = Vector3(-0.135, 0.81, 0)
    add_child(avatar_left_leg)
    _avatar_capsule(avatar_left_leg, "LeftTrouserLeg", Vector3(0, -0.29, 0), 0.12, 0.55, trousers)
    _avatar_sphere(avatar_left_leg, "LeftShoe", Vector3(0, -0.66, -0.09), Vector3(0.62, 0.30, 1.0), shoe)
    avatar_right_leg = Node3D.new()
    avatar_right_leg.name = "RightLegRig"
    avatar_right_leg.position = Vector3(0.135, 0.81, 0)
    add_child(avatar_right_leg)
    _avatar_capsule(avatar_right_leg, "RightTrouserLeg", Vector3(0, -0.29, 0), 0.12, 0.55, trousers)
    _avatar_sphere(avatar_right_leg, "RightShoe", Vector3(0, -0.66, -0.09), Vector3(0.62, 0.30, 1.0), shoe)

func _unhandled_input(event: InputEvent) -> void:
    if OS.has_feature("web") and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
    if event.is_action_pressed("toggle_mouse_capture"):
        Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED
    if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
        rotate_y(-event.relative.x * mouse_sensitivity)
        camera_pivot.rotate_x(-event.relative.y * mouse_sensitivity)
        camera_pivot.rotation.x = clamp(camera_pivot.rotation.x, deg_to_rad(-35), deg_to_rad(20))
    if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F:
        if is_sitting:
            stand_up_from_seat()
            get_viewport().set_input_as_handled()
            return
        var scene_root: Node = get_tree().current_scene
        if scene_root != null and scene_root.has_method("try_seat_interaction"):
            if scene_root.try_seat_interaction(self):
                get_viewport().set_input_as_handled()
                return
    if event.is_action_pressed("interact"):
        if is_sitting:
            stand_up_from_seat()
            get_viewport().set_input_as_handled()
            return
        var scene_root := get_tree().current_scene
        # Transport interactions take priority, followed by seating and campus sites.
        if scene_root != null and scene_root.has_method("try_vehicle_interaction"):
            if scene_root.try_vehicle_interaction(self):
                get_viewport().set_input_as_handled()
                return
        if nearby_feature != null and scene_root != null and scene_root.has_method("show_interaction"):
            scene_root.show_interaction(str(nearby_feature.get_meta("campus_name", "Campus location")))
            get_viewport().set_input_as_handled()

func sit_on_seat(anchor: Node3D) -> void:
    if anchor == null or is_sitting:
        return
    is_sitting = true
    sitting_anchor = anchor
    pre_sit_position = global_position
    pre_sit_rotation = rotation
    var target_position: Vector3 = anchor.global_position
    global_position = target_position
    var surface_position: Vector3 = anchor.get_meta("seat_surface_position", target_position)
    var look_target := Vector3(surface_position.x, global_position.y, surface_position.z)
    if Vector2(look_target.x - global_position.x, look_target.z - global_position.z).length() > 0.05:
        look_at(look_target, Vector3.UP)
    velocity = Vector3.ZERO
    _set_sitting_pose(true)
    set_physics_process(false)

func stand_up_from_seat() -> void:
    if not is_sitting:
        return
    is_sitting = false
    set_physics_process(true)
    global_position = pre_sit_position
    rotation = pre_sit_rotation
    velocity = Vector3.ZERO
    _set_sitting_pose(false)
    sitting_anchor = null

func _set_sitting_pose(enabled: bool) -> void:
    var torso := get_node_or_null("Torso") as MeshInstance3D
    var head := get_node_or_null("Head") as MeshInstance3D
    var hair := get_node_or_null("Hair") as MeshInstance3D
    var backpack := get_node_or_null("Backpack") as MeshInstance3D
    if enabled:
        if torso != null:
            torso.position = Vector3(0, 0.94, 0)
        if head != null:
            head.position = Vector3(0, 1.42, 0)
        if hair != null:
            hair.position = Vector3(0, 1.59, -0.01)
        if backpack != null:
            backpack.position = Vector3(0, 0.95, 0.22)
        for facial_name in ["Eye", "Brow", "Nose", "Mouth"]:
            for part in get_children():
                if part is MeshInstance3D and str(part.name).begins_with(facial_name):
                    part.position.y -= 0.25
        if avatar_left_arm != null:
            avatar_left_arm.position = Vector3(-0.31, 1.16, 0)
            avatar_left_arm.rotation.x = 0.35
        if avatar_right_arm != null:
            avatar_right_arm.position = Vector3(0.31, 1.16, 0)
            avatar_right_arm.rotation.x = 0.35
        if avatar_left_leg != null:
            avatar_left_leg.position = Vector3(-0.135, 0.54, -0.04)
            avatar_left_leg.rotation.x = 1.10
        if avatar_right_leg != null:
            avatar_right_leg.position = Vector3(0.135, 0.54, -0.04)
            avatar_right_leg.rotation.x = 1.10
    else:
        if torso != null:
            torso.position = Vector3(0, 1.10, 0)
        if head != null:
            head.position = Vector3(0, 1.67, 0)
        if hair != null:
            hair.position = Vector3(0, 1.84, -0.01)
        if backpack != null:
            backpack.position = Vector3(0, 1.10, 0.22)
        for facial_name in ["Eye", "Brow", "Nose", "Mouth"]:
            for part in get_children():
                if part is MeshInstance3D and str(part.name).begins_with(facial_name):
                    part.position.y += 0.25
        if avatar_left_arm != null:
            avatar_left_arm.position = Vector3(-0.31, 1.37, 0)
            avatar_left_arm.rotation = Vector3.ZERO
        if avatar_right_arm != null:
            avatar_right_arm.position = Vector3(0.31, 1.37, 0)
            avatar_right_arm.rotation = Vector3.ZERO
        if avatar_left_leg != null:
            avatar_left_leg.position = Vector3(-0.135, 0.81, 0)
            avatar_left_leg.rotation = Vector3.ZERO
        if avatar_right_leg != null:
            avatar_right_leg.position = Vector3(0.135, 0.81, 0)
            avatar_right_leg.rotation = Vector3.ZERO

func _physics_process(delta: float) -> void:
    if is_sitting:
        velocity = Vector3.ZERO
        return
    if not is_on_floor():
        velocity.y -= gravity * delta
    elif Input.is_action_just_pressed("jump"):
        velocity.y = jump_velocity
    var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
    var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
    var speed := run_speed if Input.is_key_pressed(KEY_SHIFT) else move_speed
    if direction.length() > 0.0:
        velocity.x = direction.x * speed
        velocity.z = direction.z * speed
    else:
        velocity.x = move_toward(velocity.x, 0.0, speed * 4.0 * delta)
        velocity.z = move_toward(velocity.z, 0.0, speed * 4.0 * delta)
    move_and_slide()
    var moving := Vector2(velocity.x, velocity.z).length() > 0.2
    if moving:
        walk_cycle += delta * (10.0 if speed == move_speed else 15.0)
    else:
        walk_cycle = move_toward(walk_cycle, 0.0, delta * 8.0)
    var swing := sin(walk_cycle) * (0.45 if moving else 0.0)
    avatar_left_arm.rotation.x = swing
    avatar_right_arm.rotation.x = -swing
    avatar_left_leg.rotation.x = -swing
    avatar_right_leg.rotation.x = swing
    _find_nearest_feature()

func _find_nearest_feature() -> void:
    nearby_feature = null
    var best: float = 9.5
    for node in get_tree().get_nodes_in_group("campus_features"):
        var feature := node as Node3D
        if feature == null:
            continue
        var dx: float = absf(feature.global_position.x - global_position.x)
        var dz: float = absf(feature.global_position.z - global_position.z)
        var half_w: float = float(feature.get_meta("feature_half_width", 0.0))
        var half_d: float = float(feature.get_meta("feature_half_depth", 0.0))
        var d: float = Vector2(maxf(dx - half_w, 0.0), maxf(dz - half_d, 0.0)).length()
        if d < best:
            best = d
            nearby_feature = feature
