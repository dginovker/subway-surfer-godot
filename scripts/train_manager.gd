class_name TrainManager
extends Node3D

@export var track_generator_path: NodePath
@export var player_path: NodePath
@export var spawn_distance: float = 70.0
@export var despawn_distance: float = 25.0
@export var min_gap: float = 6.0
@export var max_gap: float = 14.0
@export var min_train_length: int = 3
@export var max_train_length: int = 9

var _track_gen: Node = null
var _player: Node = null
var _trains: Array[Dictionary] = []
var _car_pool: Array[Node3D] = []
var _next_spawn_idx: float = 35.0

func _ready() -> void:
    _track_gen = get_node_or_null(track_generator_path)
    _player = get_node_or_null(player_path)
    if _player != null:
        _next_spawn_idx = fposmod(_player.get("_path_index") + 35.0, _track_gen.path_points.size())

func _process(_delta: float) -> void:
    if _track_gen == null or _player == null:
        return

    var player_idx: float = _player.get("_path_index")
    var path_size: int = _track_gen.path_points.size()

    # Spawn trains ahead (scale spawn distance with player speed)
    var speed_ratio: float = _player.forward_speed / 20.0
    var adjusted_spawn: float = spawn_distance * speed_ratio
    while _dist_forward(player_idx, _next_spawn_idx, path_size) < adjusted_spawn:
        _spawn_train(path_size)

    # Update visuals & collision
    for i in range(_trains.size() - 1, -1, -1):
        var train: Dictionary = _trains[i]
        _update_train_visuals(train)

        if _check_collision(train, player_idx, path_size):
            _on_collision()

        if _is_behind(train["start_idx"], player_idx, path_size, despawn_distance):
            _despawn_train(i)

func _dist_forward(from: float, to: float, path_size: int) -> float:
    var d: float = to - from
    if d < 0.0:
        d += path_size
    return d

func _is_behind(idx: float, player_idx: float, path_size: int, margin: float) -> bool:
    var diff: float = player_idx - idx
    if diff > path_size / 2.0:
        diff -= path_size
    elif diff < -path_size / 2.0:
        diff += path_size
    return diff > margin

func _spawn_train(path_size: int) -> void:
    # Find which lanes have trains near spawn point
    var blocked: Array[bool] = [false, false, false]
    for train in _trains:
        if _dist_forward(_next_spawn_idx, train["start_idx"], path_size) < 6.0:
            blocked[train["lane"]] = true

    var available: Array[int] = []
    for i in 3:
        if not blocked[i]:
            available.append(i)

    if available.is_empty():
        _next_spawn_idx = fposmod(_next_spawn_idx + min_gap, path_size)
        return

    available.shuffle()
    var num: int = mini(randi() % 2 + 1, available.size())
    var length: int = randi_range(min_train_length, max_train_length)

    for i in num:
        var lane: int = available[i]
        var train := {
            "lane": lane,
            "start_idx": _next_spawn_idx,
            "length": length,
            "cars": [],
        }
        _create_train_cars(train)
        _trains.append(train)

    _next_spawn_idx = fposmod(_next_spawn_idx + length + randf_range(min_gap, max_gap), path_size)

func _create_train_cars(train: Dictionary) -> void:
    for i in train["length"]:
        var car: Node3D = _get_car_from_pool()
        train["cars"].append(car)

func _get_car_from_pool() -> Node3D:
    if _car_pool.is_empty():
        return _build_train_car()
    var car: Node3D = _car_pool.pop_back()
    car.visible = true
    return car

func _build_train_car() -> Node3D:
    var root := Node3D.new()

    # Main red body (taller)
    var body := MeshInstance3D.new()
    body.mesh = BoxMesh.new()
    body.mesh.size = Vector3(2.6, 2.6, 1.85)
    var body_mat := StandardMaterial3D.new()
    body_mat.albedo_color = Color(0.82, 0.08, 0.08)
    body_mat.roughness = 0.35
    body_mat.metallic = 0.25
    body.material_override = body_mat
    root.add_child(body)

    # Dark side panels
    for side in [-1.0, 1.0]:
        var panel := MeshInstance3D.new()
        panel.mesh = BoxMesh.new()
        panel.mesh.size = Vector3(0.08, 2.2, 1.6)
        var panel_mat := StandardMaterial3D.new()
        panel_mat.albedo_color = Color(0.6, 0.05, 0.05)
        panel.material_override = panel_mat
        panel.position = Vector3(side * 1.27, 0.0, 0.0)
        root.add_child(panel)

    # Roof
    var roof := MeshInstance3D.new()
    roof.mesh = BoxMesh.new()
    roof.mesh.size = Vector3(2.4, 0.14, 1.65)
    var roof_mat := StandardMaterial3D.new()
    roof_mat.albedo_color = Color(0.22, 0.22, 0.26)
    roof.material_override = roof_mat
    roof.position = Vector3(0, 1.35, 0)
    root.add_child(roof)

    # Roof vents
    for z in [-0.5, 0.0, 0.5]:
        var vent := MeshInstance3D.new()
        vent.mesh = BoxMesh.new()
        vent.mesh.size = Vector3(1.8, 0.1, 0.18)
        var vent_mat := StandardMaterial3D.new()
        vent_mat.albedo_color = Color(0.3, 0.3, 0.35)
        vent.material_override = vent_mat
        vent.position = Vector3(0, 1.5, z)
        root.add_child(vent)

    # White stripe
    var stripe := MeshInstance3D.new()
    stripe.mesh = BoxMesh.new()
    stripe.mesh.size = Vector3(2.65, 0.1, 1.8)
    var stripe_mat := StandardMaterial3D.new()
    stripe_mat.albedo_color = Color(0.92, 0.92, 0.95)
    stripe.material_override = stripe_mat
    stripe.position = Vector3(0, 0.35, 0)
    root.add_child(stripe)

    # Glowing windows - two rows
    for side in [-1.0, 1.0]:
        for row in 2:
            for col in range(4):
                var win := MeshInstance3D.new()
                win.mesh = BoxMesh.new()
                win.mesh.size = Vector3(0.07, 0.42, 0.28)
                var win_mat := StandardMaterial3D.new()
                win_mat.albedo_color = Color(0.95, 0.88, 0.35)
                win_mat.emission_enabled = true
                win_mat.emission = Color(0.95, 0.88, 0.35)
                win_mat.emission_energy = 0.7
                win.material_override = win_mat
                win.position = Vector3(side * 1.32, 0.2 + row * 0.55, -0.52 + col * 0.35)
                root.add_child(win)

    # Wheels / bogies
    for side in [-1.0, 1.0]:
        for w in 2:
            var bogie := MeshInstance3D.new()
            bogie.mesh = BoxMesh.new()
            bogie.mesh.size = Vector3(0.35, 0.4, 0.5)
            var bogie_mat := StandardMaterial3D.new()
            bogie_mat.albedo_color = Color(0.08, 0.08, 0.1)
            bogie.material_override = bogie_mat
            bogie.position = Vector3(side * 0.9, -1.15, -0.5 + w * 1.0)
            root.add_child(bogie)

    # Headlight (front face)
    var hl := MeshInstance3D.new()
    hl.mesh = SphereMesh.new()
    hl.mesh.radius = 0.16
    hl.mesh.height = 0.32
    var hl_mat := StandardMaterial3D.new()
    hl_mat.albedo_color = Color(1.0, 1.0, 0.85)
    hl_mat.emission_enabled = true
    hl_mat.emission = Color(1.0, 1.0, 0.8)
    hl_mat.emission_energy = 2.5
    hl.material_override = hl_mat
    hl.position = Vector3(0, -0.35, 0.95)
    root.add_child(hl)

    # Taillight (back face)
    var tl := MeshInstance3D.new()
    tl.mesh = SphereMesh.new()
    tl.mesh.radius = 0.12
    tl.mesh.height = 0.24
    var tl_mat := StandardMaterial3D.new()
    tl_mat.albedo_color = Color(0.9, 0.1, 0.1)
    tl_mat.emission_enabled = true
    tl_mat.emission = Color(0.9, 0.05, 0.05)
    tl_mat.emission_energy = 1.5
    tl.material_override = tl_mat
    tl.position = Vector3(0, -0.3, -0.95)
    root.add_child(tl)

    # Bumper (front)
    var bumper := MeshInstance3D.new()
    bumper.mesh = BoxMesh.new()
    bumper.mesh.size = Vector3(2.5, 0.22, 0.12)
    var bumper_mat := StandardMaterial3D.new()
    bumper_mat.albedo_color = Color(0.15, 0.15, 0.18)
    bumper.material_override = bumper_mat
    bumper.position = Vector3(0, -1.0, 0.95)
    root.add_child(bumper)

    add_child(root)
    return root

func _position_car(car: Node3D, path_idx: float, lane_x: float) -> void:
    var path_points: Array = _track_gen.path_points
    var path_size: int = path_points.size()
    var idx: int = int(fposmod(path_idx, path_size))
    var next_idx: int = (idx + 1) % path_size
    var frac: float = path_idx - int(path_idx)
    if frac < 0:
        frac += 1.0
    var t1: Transform3D = path_points[idx]
    var t2: Transform3D = path_points[next_idx]
    var pos: Vector3 = t1.origin.lerp(t2.origin, frac)
    var forward: Vector3 = (t2.origin - t1.origin).normalized()
    if forward.is_zero_approx():
        forward = -t1.basis.z
    var up: Vector3 = Vector3.UP
    var right: Vector3 = forward.cross(up).normalized()
    if right.is_zero_approx():
        right = Vector3.RIGHT
    up = right.cross(forward).normalized()
    var car_basis := Basis(right, up, -forward)
    # Face the player (opposite to track forward)
    var train_basis := car_basis.rotated(Vector3.UP, PI)
    var world_pos := pos + car_basis * Vector3(lane_x, 1.2, 0)
    car.transform = Transform3D(train_basis, world_pos)

func _update_train_visuals(train: Dictionary) -> void:
    var lane_x: float
    match train["lane"]:
        0: lane_x = -4.5
        1: lane_x = 0.0
        2: lane_x = 4.5

    for i in train["cars"].size():
        var car: Node3D = train["cars"][i]
        _position_car(car, train["start_idx"] + i, lane_x)

func _check_collision(train: Dictionary, player_idx: float, path_size: int) -> bool:
    if _player.get("_current_lane") != train["lane"]:
        return false
    if _player.get("_is_switching"):
        return false
    var dist: float = _dist_forward(train["start_idx"], player_idx, path_size)
    return dist >= 0.0 and dist <= train["length"]

func _despawn_train(index: int) -> void:
    var train: Dictionary = _trains[index]
    for car in train["cars"]:
        car.visible = false
        _car_pool.append(car)
    _trains.remove_at(index)

func _on_collision() -> void:
    print("HIT BY TRAIN! Resetting...")
    _player.set("_path_index", 0.0)
    _player.set("_current_lane", 1)
    _player.set("_target_lane", 1)
    _player.set("_is_switching", false)
    _player.set("_switch_timer", 0.0)
    _player.set("_distance_traveled", 0.0)
    _player.set("forward_speed", 20.0)
    var score_label: Label = _player.get("_score_label")
    if score_label != null:
        score_label.text = "Score: 0"
    var body: Node3D = _player.get_node("Body")
    if body != null:
        body.position = Vector3(0, 1.15, 0)
        body.rotation = Vector3(0, PI, 0)
