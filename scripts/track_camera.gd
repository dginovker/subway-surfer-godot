class_name TrackCamera
extends Camera3D

@export var player_path: NodePath
@export var height_offset: float = 4.5
@export var back_offset: float = 10.0
@export var look_ahead: float = 20.0

var _player: Node3D = null

func _ready() -> void:
    _player = get_node_or_null(player_path)

func _process(delta: float) -> void:
    if _player == null:
        return

    var player_pos: Vector3 = _player.position
    var player_basis: Basis = _player.transform.basis

    var target_pos: Vector3 = player_pos + player_basis.y * height_offset + player_basis.z * back_offset
    var target_look: Vector3 = player_pos - player_basis.z * look_ahead
    
    # Get current look target before moving
    var current_look: Vector3 = position - transform.basis.z * look_ahead
    
    # Smooth position and rotation with frame-rate independent damping
    var pos_weight: float = 1.0 - exp(-12.0 * delta)
    var rot_weight: float = 1.0 - exp(-10.0 * delta)
    position = position.lerp(target_pos, pos_weight)
    var smoothed_look: Vector3 = current_look.lerp(target_look, rot_weight)
    look_at(smoothed_look, player_basis.y)
