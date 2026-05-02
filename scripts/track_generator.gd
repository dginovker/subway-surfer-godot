class_name TrackGenerator
extends Node3D

@export var segment_length: float = 2.0
@export var platform_width: float = 14.0
@export var wall_height: float = 6.0
@export var wall_offset: float = 8.0
@export var tunnel_height: float = 7.0
@export var tunnel_offset: float = 9.0

const RAIL_OFFSETS: Array[float] = [-5.8, -3.2, -1.3, 1.3, 3.2, 5.8]
const TRACK_CENTERS: Array[float] = [-4.5, 0.0, 4.5]

var path_points: Array[Transform3D] = []
var turn_rates: Array[float] = []

func _ready() -> void:
    _generate_path()
    _build_platform()
    _build_rails()
    _build_sleepers()
    _build_ballast()
    _build_track_details()
    _build_sidewalks()
    _build_trees()
    _build_clouds()
    _build_distant_city()

func _generate_path() -> void:
    var pos := Vector3.ZERO
    var fwd := Vector3.FORWARD
    var up := Vector3.UP
    
    var sections: Array = [
        [50, 0.0],
        [30, 1.0],
        [40, 0.0],
        [25, -1.5],
        [60, 0.0],
        [20, 1.8],
        [50, 0.0],
        [30, -0.8],
        [60, 0.0],
    ]
    
    for section in sections:
        var segs: int = section[0]
        var turn: float = deg_to_rad(section[1])
        for i in segs:
            var right := fwd.cross(up).normalized()
            var seg_basis := Basis(right, up, -fwd)
            path_points.append(Transform3D(seg_basis, pos))
            turn_rates.append(turn)
            pos += fwd * segment_length
            if turn != 0.0:
                fwd = fwd.rotated(up, turn).normalized()

func _local_to_world(t: Transform3D, local_pos: Vector3) -> Vector3:
    return t.origin + t.basis * local_pos

func _create_multimesh(node_name: String, mesh: Mesh, count: int, mat: Material) -> MultiMeshInstance3D:
    var mm := MultiMeshInstance3D.new()
    mm.name = node_name
    mm.multimesh = MultiMesh.new()
    mm.multimesh.transform_format = MultiMesh.TRANSFORM_3D
    mm.multimesh.mesh = mesh
    mm.multimesh.instance_count = count
    mm.material_override = mat
    add_child(mm)
    return mm

func _build_platform() -> void:
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color(0.65, 0.65, 0.68)
    mat.roughness = 0.92
    
    var mesh := BoxMesh.new()
    mesh.size = Vector3(platform_width, 0.35, segment_length)
    var mm := _create_multimesh("Platform", mesh, path_points.size(), mat)
    
    for i in path_points.size():
        var t := path_points[i]
        var pos := _local_to_world(t, Vector3(0.0, -0.175, 0.0))
        mm.multimesh.set_instance_transform(i, Transform3D(t.basis, pos))

func _build_rails() -> void:
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color(0.35, 0.35, 0.38)
    mat.metallic = 0.85
    mat.roughness = 0.25
    
    var mesh := BoxMesh.new()
    mesh.size = Vector3(0.12, 0.22, segment_length)
    
    for rail_idx in RAIL_OFFSETS.size():
        var offset: float = RAIL_OFFSETS[rail_idx]
        var mm := _create_multimesh("Rail%d" % rail_idx, mesh, path_points.size(), mat)
        
        for i in path_points.size():
            var t := path_points[i]
            var pos := _local_to_world(t, Vector3(offset, 0.05, 0.0))
            mm.multimesh.set_instance_transform(i, Transform3D(t.basis, pos))

func _build_sleepers() -> void:
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color(0.4, 0.25, 0.12)
    mat.roughness = 0.95
    
    var count := int((path_points.size() + 1) / 2.0)
    var mesh := BoxMesh.new()
    mesh.size = Vector3(12.8, 0.14, 0.55)
    var mm := _create_multimesh("Sleepers", mesh, count, mat)
    
    var idx := 0
    for i in path_points.size():
        if i % 2 != 0:
            continue
        var t := path_points[i]
        var pos := _local_to_world(t, Vector3(0.0, -0.05, 0.0))
        mm.multimesh.set_instance_transform(idx, Transform3D(t.basis, pos))
        idx += 1

func _build_ballast() -> void:
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color(0.45, 0.45, 0.48)
    mat.roughness = 1.0
    
    var rng := RandomNumberGenerator.new()
    rng.seed = 12345
    
    var stones_per_segment := 6
    var total := path_points.size() * stones_per_segment
    var mesh := BoxMesh.new()
    mesh.size = Vector3(0.25, 0.15, 0.25)
    var mm := _create_multimesh("Ballast", mesh, total, mat)
    
    var idx := 0
    for t in path_points:
        for j in stones_per_segment:
            var s := rng.randf_range(0.6, 1.4)
            var lx := rng.randf_range(-6.5, 6.5)
            var lz := rng.randf_range(-segment_length * 0.45, segment_length * 0.45)
            var ly := -0.25 - rng.randf_range(0.0, 0.1)
            var pos := _local_to_world(t, Vector3(lx, ly, lz))
            var scaled_basis := t.basis.scaled(Vector3(s, s * 0.6, s))
            mm.multimesh.set_instance_transform(idx, Transform3D(scaled_basis, pos))
            idx += 1

func _build_walls() -> void:
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color(0.55, 0.55, 0.58)
    mat.roughness = 0.88
    
    var mesh := BoxMesh.new()
    mesh.size = Vector3(0.9, wall_height, segment_length)
    
    for side_idx in 2:
        var side := -1.0 if side_idx == 0 else 1.0
        var mm := _create_multimesh("Wall%s" % ("Left" if side < 0 else "Right"), mesh, path_points.size(), mat)
        
        for i in path_points.size():
            var t := path_points[i]
            var pos := _local_to_world(t, Vector3(side * wall_offset, wall_height * 0.5 - 0.5, 0.0))
            mm.multimesh.set_instance_transform(i, Transform3D(t.basis, pos))

func _build_tunnel_roof() -> void:
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color(0.6, 0.6, 0.63)
    mat.roughness = 0.85
    
    var mesh := BoxMesh.new()
    mesh.size = Vector3(tunnel_offset * 2.2, 0.5, segment_length)
    var mm := _create_multimesh("TunnelRoof", mesh, path_points.size(), mat)
    
    for i in path_points.size():
        var t := path_points[i]
        var pos := _local_to_world(t, Vector3(0.0, tunnel_height, 0.0))
        mm.multimesh.set_instance_transform(i, Transform3D(t.basis, pos))

func _build_overhead_beams() -> void:
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color(0.55, 0.4, 0.25)
    mat.roughness = 0.7
    mat.metallic = 0.3
    
    var count := int((path_points.size() + 7) / 8.0)
    var mesh := BoxMesh.new()
    mesh.size = Vector3(tunnel_offset * 2.0, 0.35, 0.6)
    var mm := _create_multimesh("OverheadBeams", mesh, count, mat)
    
    var idx := 0
    for i in path_points.size():
        if i % 8 != 0:
            continue
        var t := path_points[i]
        var pos := _local_to_world(t, Vector3(0.0, tunnel_height - 0.4, 0.0))
        mm.multimesh.set_instance_transform(idx, Transform3D(t.basis, pos))
        idx += 1

func _build_pillars() -> void:
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color(0.55, 0.55, 0.58)
    mat.roughness = 0.9
    
    var count := int((path_points.size() + 11) / 12.0)
    var mesh := BoxMesh.new()
    mesh.size = Vector3(0.8, tunnel_height, 0.8)
    
    for side_idx in 2:
        var side := -1.0 if side_idx == 0 else 1.0
        var mm := _create_multimesh("Pillar%s" % ("Left" if side < 0 else "Right"), mesh, count, mat)
        
        var idx := 0
        for i in path_points.size():
            if i % 12 != 0:
                continue
            var t := path_points[i]
            var pos := _local_to_world(t, Vector3(side * (wall_offset + 1.2), tunnel_height * 0.5 - 0.5, 0.0))
            mm.multimesh.set_instance_transform(idx, Transform3D(t.basis, pos))
            idx += 1

func _build_wall_lights() -> void:
    var container := Node3D.new()
    container.name = "Lights"
    add_child(container)
    
    for i in path_points.size():
        if i % 15 != 0:
            continue
        var t := path_points[i]
        for side_idx in 2:
            var side := -1.0 if side_idx == 0 else 1.0
            var light := OmniLight3D.new()
            light.light_color = Color(0.9, 0.85, 0.7)
            light.light_energy = 1.2
            light.omni_range = 15.0
            light.omni_attenuation = 1.5
            var pos := _local_to_world(t, Vector3(side * (wall_offset - 0.6), 3.5, 0.0))
            light.transform = Transform3D(t.basis, pos)
            container.add_child(light)
            
            var fixture := MeshInstance3D.new()
            fixture.mesh = BoxMesh.new()
            fixture.mesh.size = Vector3(0.3, 0.15, 0.6)
            var fmat := StandardMaterial3D.new()
            fmat.albedo_color = Color(0.8, 0.8, 0.75)
            fmat.emission_enabled = true
            fmat.emission = Color(0.9, 0.85, 0.7)
            fmat.emission_energy = 0.8
            fixture.material_override = fmat
            fixture.transform = Transform3D(t.basis, pos)
            container.add_child(fixture)

func _build_track_details() -> void:
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color(0.1, 0.1, 0.12)
    mat.roughness = 0.5
    
    var cables_per_track := int((path_points.size() + 2) / 3.0)
    var total_cables := cables_per_track * TRACK_CENTERS.size()
    var mesh := BoxMesh.new()
    mesh.size = Vector3(0.08, 0.08, segment_length)
    var mm := _create_multimesh("Cables", mesh, total_cables, mat)
    
    var idx := 0
    for track_center in TRACK_CENTERS:
        for i in path_points.size():
            if i % 3 != 0:
                continue
            var t := path_points[i]
            var pos := _local_to_world(t, Vector3(track_center, 0.3, 0.0))
            mm.multimesh.set_instance_transform(idx, Transform3D(t.basis, pos))
            idx += 1

func _build_sidewalks() -> void:
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color(0.72, 0.72, 0.74)
    mat.roughness = 0.85
    
    var mesh := BoxMesh.new()
    mesh.size = Vector3(2.0, 0.12, segment_length)
    
    for side_idx in 2:
        var side := -1.0 if side_idx == 0 else 1.0
        var mm := _create_multimesh("Sidewalk%s" % ("Left" if side < 0 else "Right"), mesh, path_points.size(), mat)
        
        for i in path_points.size():
            var t := path_points[i]
            var pos := _local_to_world(t, Vector3(side * (platform_width * 0.5 + 1.0), -0.06, 0.0))
            mm.multimesh.set_instance_transform(i, Transform3D(t.basis, pos))

func _build_trees() -> void:
    var rng := RandomNumberGenerator.new()
    rng.seed = 77777
    
    var tree_count := int((path_points.size() + 2) / 3.0)
    var total := tree_count * 2
    
    # Shared trunk mesh (different heights per type)
    var trunk_mat := StandardMaterial3D.new()
    trunk_mat.albedo_color = Color(0.4, 0.25, 0.1)
    trunk_mat.roughness = 0.9
    
    var trunk_mesh := BoxMesh.new()
    trunk_mesh.size = Vector3(0.5, 3.0, 0.5)
    var trunks := _create_multimesh("TreeTrunks", trunk_mesh, total, trunk_mat)
    
    # Oak foliage - large round canopy
    var oak_mat := StandardMaterial3D.new()
    oak_mat.albedo_color = Color(0.18, 0.6, 0.18)
    oak_mat.roughness = 0.8
    var oak_mesh := SphereMesh.new()
    oak_mesh.radius = 1.6
    oak_mesh.height = 3.2
    var oaks := _create_multimesh("OakFoliage", oak_mesh, total, oak_mat)
    
    # Pine foliage - cone shape
    var pine_mat := StandardMaterial3D.new()
    pine_mat.albedo_color = Color(0.1, 0.45, 0.15)
    pine_mat.roughness = 0.85
    var pine_mesh := CylinderMesh.new()
    pine_mesh.top_radius = 0.0
    pine_mesh.bottom_radius = 1.6
    pine_mesh.height = 4.0
    var pines := _create_multimesh("PineFoliage", pine_mesh, total, pine_mat)
    
    # Bush foliage - multiple small spheres
    var bush_mat := StandardMaterial3D.new()
    bush_mat.albedo_color = Color(0.3, 0.65, 0.2)
    bush_mat.roughness = 0.8
    var bush_mesh := SphereMesh.new()
    bush_mesh.radius = 0.7
    bush_mesh.height = 1.4
    var bushes := _create_multimesh("BushFoliage", bush_mesh, total * 3, bush_mat)
    
    var oak_idx := 0
    var pine_idx := 0
    var bush_idx := 0
    var trunk_idx := 0
    
    for i in path_points.size():
        if i % 3 != 0:
            continue
        var t := path_points[i]
        for side_idx in 2:
            var side := -1.0 if side_idx == 0 else 1.0
            var dist := rng.randf_range(10.0, 16.0)
            var lz := rng.randf_range(-segment_length * 0.4, segment_length * 0.4)
            var tree_type := rng.randi() % 3
            
            var trunk_pos := _local_to_world(t, Vector3(side * dist, 1.5, lz))
            trunks.multimesh.set_instance_transform(trunk_idx, Transform3D(t.basis, trunk_pos))
            trunk_idx += 1
            
            match tree_type:
                0:  # Oak - round canopy
                    var f_pos := _local_to_world(t, Vector3(side * dist, 3.8, lz))
                    var f_scale := rng.randf_range(0.9, 1.5)
                    oaks.multimesh.set_instance_transform(oak_idx, Transform3D(t.basis.scaled(Vector3(f_scale, f_scale * 0.8, f_scale)), f_pos))
                    oak_idx += 1
                1:  # Pine - tall cone
                    var f_pos := _local_to_world(t, Vector3(side * dist, 4.5, lz))
                    var f_scale := rng.randf_range(0.8, 1.3)
                    pines.multimesh.set_instance_transform(pine_idx, Transform3D(t.basis.scaled(Vector3(f_scale, f_scale, f_scale)), f_pos))
                    pine_idx += 1
                2:  # Bushy - clusters
                    for b in 3:
                        var bx := side * dist + rng.randf_range(-0.6, 0.6)
                        var by := rng.randf_range(2.0, 3.5)
                        var bz := lz + rng.randf_range(-0.5, 0.5)
                        var f_pos := _local_to_world(t, Vector3(bx, by, bz))
                        var f_scale := rng.randf_range(0.5, 1.0)
                        bushes.multimesh.set_instance_transform(bush_idx, Transform3D(t.basis.scaled(Vector3(f_scale, f_scale * 0.8, f_scale)), f_pos))
                        bush_idx += 1

func _build_clouds() -> void:
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color(0.95, 0.95, 0.98)
    mat.roughness = 1.0
    
    var count := 80
    var mesh := SphereMesh.new()
    mesh.radius = 3.0
    mesh.height = 6.0
    var mm := _create_multimesh("Clouds", mesh, count, mat)
    
    var rng := RandomNumberGenerator.new()
    rng.seed = 88888
    
    for i in count:
        var seg_idx := rng.randi_range(0, max(0, path_points.size() - 1))
        var t := path_points[seg_idx]
        var lx := rng.randf_range(-60.0, 60.0)
        var ly := rng.randf_range(45.0, 80.0)
        var lz := rng.randf_range(-segment_length * 2.0, segment_length * 2.0)
        var pos := _local_to_world(t, Vector3(lx, ly, lz))
        var s := rng.randf_range(1.0, 3.0)
        var scaled_basis := t.basis.scaled(Vector3(s * 2.5, s * 0.5, s * 1.5))
        mm.multimesh.set_instance_transform(i, Transform3D(scaled_basis, pos))

func _build_distant_city() -> void:
    var rng := RandomNumberGenerator.new()
    rng.seed = 54321
    
    var count := 200
    var mesh := BoxMesh.new()
    mesh.size = Vector3(4.0, 8.0, 4.0)
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color(0.3, 0.3, 0.35)
    mat.roughness = 0.95
    var mm := _create_multimesh("CityBlocks", mesh, count, mat)
    
    var window_mesh := BoxMesh.new()
    window_mesh.size = Vector3(0.22, 0.32, 0.06)
    var window_mat := StandardMaterial3D.new()
    window_mat.albedo_color = Color(0.92, 0.88, 0.45)
    window_mat.emission_enabled = true
    window_mat.emission = Color(0.92, 0.88, 0.45)
    window_mat.emission_energy = 0.8
    var win_per_building := 12
    var windows := _create_multimesh("CityWindows", window_mesh, count * win_per_building, window_mat)
    
    var antenna_mesh := BoxMesh.new()
    antenna_mesh.size = Vector3(0.1, 1.5, 0.1)
    var antenna_mat := StandardMaterial3D.new()
    antenna_mat.albedo_color = Color(0.5, 0.5, 0.55)
    var antennas := _create_multimesh("CityAntennas", antenna_mesh, int(count * 0.4), antenna_mat)
    var ant_idx := 0
    
    for i in count:
        var seg_idx := rng.randi_range(0, path_points.size() - 1)
        var t := path_points[seg_idx]
        var side := 1.0 if rng.randf() > 0.5 else -1.0
        var dist := rng.randf_range(18.0, 50.0)
        var width := rng.randf_range(3.0, 7.0)
        var depth := rng.randf_range(3.0, 7.0)
        var height := rng.randf_range(6.0, 30.0)
        var lz := rng.randf_range(-segment_length * 0.5, segment_length * 0.5)
        
        var building_color := Color(
            rng.randf_range(0.25, 0.45),
            rng.randf_range(0.25, 0.4),
            rng.randf_range(0.3, 0.5)
        )
        mat.albedo_color = building_color
        
        var pos := _local_to_world(t, Vector3(side * dist, height * 0.5 - 2.0, lz))
        var scaled_basis := t.basis.scaled(Vector3(width / 4.0, height / 8.0, depth / 4.0))
        mm.multimesh.set_instance_transform(i, Transform3D(scaled_basis, pos))
        
        # Windows - 3x4 grid pattern on building face
        for w in range(win_per_building):
            var row := w / 3
            var col := w % 3
            var wy := (row + 0.8) * (height / 5.5) - 2.0
            var wz := lz + (col - 1.0) * depth * 0.18
            var wpos := _local_to_world(t, Vector3(side * (dist + width * 0.13), wy, wz))
            windows.multimesh.set_instance_transform(i * win_per_building + w, Transform3D(t.basis, wpos))
        
        # Antenna (40% chance)
        if rng.randf() < 0.4 and ant_idx < antennas.multimesh.instance_count:
            var apos := _local_to_world(t, Vector3(side * dist, height - 1.0, lz))
            antennas.multimesh.set_instance_transform(ant_idx, Transform3D(t.basis.scaled(Vector3(1.0, rng.randf_range(0.5, 2.0), 1.0)), apos))
            ant_idx += 1
