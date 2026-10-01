extends CharacterBody3D

@export var move_speed: float = 6.0
@export var is_local_player: bool = false
@export var is_dummy: bool = false

var target: Node3D
var arena_limit := 9.0

func _physics_process(delta: float) -> void:
    if is_local_player:
        _handle_local_input()
    elif is_dummy:
        _handle_dummy_ai(delta)
    else:
        velocity = Vector3.ZERO

    move_and_slide()
    global_position.x = clamp(global_position.x, -arena_limit, arena_limit)
    global_position.z = clamp(global_position.z, -arena_limit, arena_limit)

func _handle_local_input() -> void:
    var input_vec := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
    var direction := Vector3(input_vec.x, 0.0, input_vec.y)

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

func _handle_dummy_ai(delta: float) -> void:
    if target == null:
        velocity = Vector3.ZERO
        return

    var distance := global_position.distance_to(target.global_position)
    var direction := (target.global_position - global_position)
    direction.y = 0.0

    if direction.length_squared() > 0.01:
        direction = direction.normalized()

    var desired_direction := direction
    var crown_holder := target.get_meta("crown_holder", false)
    if crown_holder:
        desired_direction = -direction

    velocity.x = desired_direction.x * move_speed * 0.75
    velocity.z = desired_direction.z * move_speed * 0.75
    velocity.y = 0.0

func set_target(new_target: Node3D) -> void:
    target = new_target
