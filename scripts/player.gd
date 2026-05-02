class_name Player
extends CharacterBody3D

@export var track_generator_path: NodePath
@export var forward_speed: float = 20.0
@export var lane_switch_time: float = 0.15
@export var jump_height: float = 0.9
@export var max_speed: float = 35.0
@export var speed_ramp: float = 0.8

var _track_gen: Node = null
var _current_lane: int = 1
var _target_lane: int = 1
var _switch_timer: float = 0.0
var _is_switching: bool = false
var _switch_start_x: float = 0.0
var _path_index: float = 0.0
var _run_time: float = 0.0
var _distance_traveled: float = 0.0

var _body: Node3D
var _left_arm: Node3D
var _right_arm: Node3D
var _left_leg: Node3D
var _right_leg: Node3D
var _score_label: Label = null

func _ready() -> void:
    _track_gen = get_node_or_null(track_generator_path)
    _build_character()
    _build_ui()
    if _track_gen != null:
        var path_points: Array = _track_gen.get("path_points")
        if path_points.size() > 0:
            var t: Transform3D = path_points[0]
            var lane_x: float = _get_lane_x(_current_lane)
            position = t.origin + t.basis * Vector3(lane_x, 0, 0)
            transform.basis = t.basis

func _build_ui() -> void:
    var canvas := CanvasLayer.new()
    canvas.name = "UI"
    add_child(canvas)
    
    _score_label = Label.new()
    _score_label.name = "ScoreLabel"
    _score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    _score_label.anchor_left = 1.0
    _score_label.anchor_right = 1.0
    _score_label.offset_left = -220
    _score_label.offset_right = -24
    _score_label.offset_top = 16
    _score_label.offset_bottom = 56
    _score_label.add_theme_font_size_override("font_size", 32)
    _score_label.add_theme_color_override("font_color", Color.WHITE)
    _score_label.add_theme_constant_override("outline_size", 5)
    _score_label.add_theme_color_override("font_outline_color", Color.BLACK)
    canvas.add_child(_score_label)

func _get_lane_x(lane: int) -> float:
    match lane:
        0: return -4.5
        1: return 0.0
        2: return 4.5
    return 0.0

func _build_character() -> void:
    _body = Node3D.new()
    _body.name = "Body"
    _body.position = Vector3(0, 1.15, 0)
    _body.scale = Vector3(1.5, 1.5, 1.5)
    add_child(_body)

    var skin_mat := _make_mat(Color(0.96, 0.8, 0.69))
    var shirt_mat := _make_mat(Color(0.92, 0.2, 0.2))
    var pants_mat := _make_mat(Color(0.15, 0.28, 0.5))
    var shoes_mat := _make_mat(Color(0.95, 0.95, 0.95))
    var hair_mat := _make_mat(Color(0.25, 0.12, 0.04))
    var pack_mat := _make_mat(Color(0.15, 0.65, 0.25))
    var eye_mat := _make_mat(Color(0.05, 0.05, 0.05))
    var cap_mat := _make_mat(Color(0.9, 0.15, 0.15))

    # Torso
    var torso := MeshInstance3D.new()
    torso.mesh = BoxMesh.new()
    torso.mesh.size = Vector3(0.48, 0.72, 0.28)
    torso.material_override = shirt_mat
    _body.add_child(torso)

    # Head
    var head := MeshInstance3D.new()
    head.mesh = SphereMesh.new()
    head.mesh.radius = 0.23
    head.mesh.height = 0.46
    head.material_override = skin_mat
    head.position = Vector3(0, 0.56, 0)
    _body.add_child(head)

    # Hair
    var hair := MeshInstance3D.new()
    hair.mesh = BoxMesh.new()
    hair.mesh.size = Vector3(0.48, 0.14, 0.48)
    hair.material_override = hair_mat
    hair.position = Vector3(0, 0.1, -0.02)
    head.add_child(hair)

    # Cap
    var cap := MeshInstance3D.new()
    cap.mesh = BoxMesh.new()
    cap.mesh.size = Vector3(0.5, 0.06, 0.32)
    cap.material_override = cap_mat
    cap.position = Vector3(0, 0.18, 0.04)
    head.add_child(cap)

    # Cap brim
    var brim := MeshInstance3D.new()
    brim.mesh = BoxMesh.new()
    brim.mesh.size = Vector3(0.5, 0.03, 0.14)
    brim.material_override = cap_mat
    brim.position = Vector3(0, 0.14, 0.22)
    head.add_child(brim)

    # Eyes
    for side in [-1.0, 1.0]:
        var eye := MeshInstance3D.new()
        eye.mesh = SphereMesh.new()
        eye.mesh.radius = 0.032
        eye.mesh.height = 0.064
        eye.material_override = eye_mat
        eye.position = Vector3(side * 0.09, 0.02, 0.19)
        head.add_child(eye)

    # Backpack
    var pack := MeshInstance3D.new()
    pack.mesh = BoxMesh.new()
    pack.mesh.size = Vector3(0.38, 0.45, 0.22)
    pack.material_override = pack_mat
    pack.position = Vector3(0, 0.08, -0.3)
    _body.add_child(pack)

    # Arms
    _left_arm = _create_limb("LeftArm", Vector3(-0.32, 0.26, 0), skin_mat, shirt_mat, true)
    _right_arm = _create_limb("RightArm", Vector3(0.32, 0.26, 0), skin_mat, shirt_mat, true)

    # Legs
    _left_leg = _create_limb("LeftLeg", Vector3(-0.14, -0.36, 0), pants_mat, shoes_mat, false)
    _right_leg = _create_limb("RightLeg", Vector3(0.14, -0.36, 0), pants_mat, shoes_mat, false)

    # Face the camera (opposite direction of running)
    _body.rotation.y = PI

func _make_mat(color: Color) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mat.roughness = 0.55
    return mat

func _create_limb(limb_name: String, pos: Vector3, main_mat: Material, detail_mat: Material, is_arm: bool) -> Node3D:
    var pivot := Node3D.new()
    pivot.name = limb_name + "Pivot"
    pivot.position = pos
    _body.add_child(pivot)

    var limb := MeshInstance3D.new()
    if is_arm:
        limb.mesh = CapsuleMesh.new()
        limb.mesh.radius = 0.07
        limb.mesh.height = 0.58
        limb.position = Vector3(0, -0.24, 0)
    else:
        limb.mesh = CapsuleMesh.new()
        limb.mesh.radius = 0.08
        limb.mesh.height = 0.72
        limb.position = Vector3(0, -0.32, 0)
    limb.material_override = main_mat
    pivot.add_child(limb)

    var detail := MeshInstance3D.new()
    if is_arm:
        detail.mesh = CapsuleMesh.new()
        detail.mesh.radius = 0.075
        detail.mesh.height = 0.22
        detail.position = Vector3(0, 0.12, 0)
    else:
        detail.mesh = BoxMesh.new()
        detail.mesh.size = Vector3(0.18, 0.12, 0.3)
        detail.position = Vector3(0, -0.34, 0.02)
    detail.material_override = detail_mat
    pivot.add_child(detail)

    return pivot

func _process(delta: float) -> void:
    if _track_gen == null:
        return

    var path_points: Array = _track_gen.get("path_points")
    var segment_length: float = _track_gen.get("segment_length")
    if path_points.is_empty():
        return

    # Input
    if not _is_switching:
        if Input.is_action_just_pressed("ui_left"):
            if _current_lane > 0:
                _target_lane = _current_lane - 1
                _start_switch()
        elif Input.is_action_just_pressed("ui_right"):
            if _current_lane < 2:
                _target_lane = _current_lane + 1
                _start_switch()

    # Speed ramp over time
    forward_speed = minf(forward_speed + speed_ramp * delta, max_speed)
    
    # Score tracking
    _distance_traveled += forward_speed * delta
    if _score_label != null:
        _score_label.text = "Score: %d" % int(_distance_traveled)
    
    # Forward movement
    _path_index += (forward_speed / segment_length) * delta
    if _path_index >= path_points.size() - 2:
        _path_index = 0.0

    var idx: int = int(_path_index)
    var frac: float = _path_index - idx
    var t1: Transform3D = path_points[idx]
    var t2: Transform3D = path_points[min(idx + 1, path_points.size() - 1)]

    var track_pos: Vector3 = t1.origin.lerp(t2.origin, frac)
    
    # Smoothly interpolate segment forward direction to avoid snaps at boundaries
    var fwd1: Vector3 = -t1.basis.z
    var fwd2: Vector3 = -t2.basis.z
    var forward: Vector3 = fwd1.slerp(fwd2, frac).normalized()
    if forward.is_zero_approx():
        forward = -t1.basis.z

    var up: Vector3 = Vector3.UP
    var right: Vector3 = forward.cross(up).normalized()
    if right.is_zero_approx():
        right = Vector3.RIGHT
    up = right.cross(forward).normalized()
    var track_basis := Basis(right, up, -forward)

    # Lane position
    var lane_x: float
    if _is_switching:
        _switch_timer += delta
        var st: float = _switch_timer / lane_switch_time
        if st >= 1.0:
            st = 1.0
            _is_switching = false
            _current_lane = _target_lane
        var ease_t: float = sin(st * PI * 0.5)
        lane_x = lerpf(_switch_start_x, _get_lane_x(_target_lane), ease_t)

        # Jump arc + lean
        _body.position.y = 1.15 + sin(st * PI) * jump_height
        var lean_dir: float = sign(_get_lane_x(_target_lane) - _switch_start_x)
        _body.rotation.z = sin(st * PI) * 0.35 * lean_dir
        _body.rotation.x = -sin(st * PI) * 0.15

        # Arms flare during jump
        _left_arm.rotation.x = -sin(st * PI) * 1.2 + 0.3
        _right_arm.rotation.x = -sin(st * PI) * 1.2 + 0.3
        _left_arm.rotation.z = -0.4 * lean_dir
        _right_arm.rotation.z = -0.4 * lean_dir
        _left_leg.rotation.x = 0.4
        _right_leg.rotation.x = 0.4
    else:
        lane_x = _get_lane_x(_current_lane)
        _run_time += delta * forward_speed * 0.6
        # Running cycle
        _left_arm.rotation.x = sin(_run_time) * 0.8
        _right_arm.rotation.x = -sin(_run_time) * 0.8
        _left_leg.rotation.x = -sin(_run_time) * 0.95
        _right_leg.rotation.x = sin(_run_time) * 0.95
        _body.position.y = 1.15 + abs(sin(_run_time * 2.0)) * 0.05
        _body.rotation.z = 0.0
        _body.rotation.x = 0.0
        _left_arm.rotation.z = 0.0
        _right_arm.rotation.z = 0.0

    var final_pos: Vector3 = track_pos + track_basis * Vector3(lane_x, 0, 0)
    transform = Transform3D(track_basis, final_pos)

func _start_switch() -> void:
    _is_switching = true
    _switch_timer = 0.0
    _switch_start_x = _get_lane_x(_current_lane)
