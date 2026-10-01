extends CharacterBody3D

@export var move_speed: float = 6.0
@export var is_local_player: bool = false
@export var is_dummy: bool = false

var target: Node3D
var ai_target_is_crown: bool = false
var movement_enabled: bool = false
var arena_limit: float = 9.0

func _physics_process(_delta: float) -> void:
    if not movement_enabled:
        velocity = Vector3.ZERO
        move_and_slide()
        return

    if is_local_player:
        _handle_local_input()
    elif is_dummy:
        _handle_dummy_ai()
    else:
        velocity = Vector3.ZERO

    move_and_slide()
    global_position.x = clampf(global_position.x, -arena_limit, arena_limit)
    global_position.z = clampf(global_position.z, -arena_limit, arena_limit)

func _handle_local_input() -> void:
    var input_vec: Vector2 = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
    var direction: Vector3 = Vector3(input_vec.x, 0.0, input_vec.y)

    if Input.is_key_pressed(KEY_A):
        direction.x -= 1.0
    if Input.is_key_pressed(KEY_D):
        direction.x += 1.0
    if Input.is_key_pressed(KEY_W):
        direction.z -= 1.0
    if Input.is_key_pressed(KEY_S):
        direction.z += 1.0

    if direction.length_squared() > 1.0:
        direction = direction.normalized()

    velocity.x = direction.x * move_speed
    velocity.z = direction.z * move_speed
    velocity.y = 0.0

func _handle_dummy_ai() -> void:
    if target == null:
        velocity = Vector3.ZERO
        return

    var direction: Vector3 = target.global_position - global_position
    direction.y = 0.0

    if direction.length_squared() <= 0.01:
        velocity = Vector3.ZERO
        return

    direction = direction.normalized()

    if ai_target_is_crown:
        velocity.x = direction.x * move_speed * 0.78
        velocity.z = direction.z * move_speed * 0.78
    elif get_meta("crown_holder", false):
        var distance_from_center := Vector2(global_position.x, global_position.z).length()
        var escape_direction: Vector3

        # Inside the safe area, run directly away from the opponent.
        # This prevents the holder from steering back into the central pedestal.
        if distance_from_center < 6.0:
            escape_direction = -direction
        else:
            # Near the arena edge, keep moving away from the opponent while
            # steering back toward the center.
            var center_direction := Vector3(-global_position.x, 0.0, -global_position.z).normalized()
            escape_direction = (-direction * 0.8 + center_direction * 0.6).normalized()

        velocity.x = escape_direction.x * move_speed * 0.72
        velocity.z = escape_direction.z * move_speed * 0.72
    else:
        var target_is_crown_holder: bool = target.get_meta("crown_holder", false)
        if target_is_crown_holder:
            velocity.x = direction.x * move_speed * 0.78
            velocity.z = direction.z * move_speed * 0.78
        else:
            velocity.x = -direction.x * move_speed * 0.78
            velocity.z = -direction.z * move_speed * 0.78

    velocity.y = 0.0

func set_target(new_target: Node3D) -> void:
    target = new_target
    ai_target_is_crown = false

func set_crown_target(new_target: Node3D) -> void:
    target = new_target
    ai_target_is_crown = true

func set_movement_enabled(enabled: bool) -> void:
    movement_enabled = enabled
    if not enabled:
        velocity = Vector3.ZERO
