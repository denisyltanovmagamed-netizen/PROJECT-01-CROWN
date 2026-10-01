extends CharacterBody3D

@export var move_speed: float = 6.0
@export var is_local_player: bool = false
@export var is_dummy: bool = false

var target: Node3D
var ai_target_is_crown: bool = false
var ai_target_point: Vector3
var ai_use_target_point: bool = false
var movement_enabled: bool = false
var arena_limit: float = 9.0
var all_players: Array[CharacterBody3D] = []
var ai_slot: int = 0
var ai_state: String = "CHASE"
var ai_intercept_point: Vector3
var ai_use_intercept: bool = false

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

    var target_position := target.global_position
    if ai_use_target_point:
        target_position = ai_target_point

    var direction: Vector3 = target_position - global_position
    direction.y = 0.0

    if direction.length_squared() <= 0.0001:
        # Never freeze an AI on an interception point.
        if ai_use_target_point:
            direction = target.global_position - global_position
            direction.y = 0.0
        if direction.length_squared() <= 0.0001:
            velocity = Vector3.ZERO
            return

    var distance_to_target := direction.length()
    direction = direction.normalized()

    # Near the target, prioritize reaching the steal distance over separation.
    # Otherwise separation can push attackers away forever before they get close enough to steal.
    if distance_to_target > 1.8:
        direction = _apply_separation(direction)

    if get_meta("crown_holder", false):
        var distance_from_center := Vector2(global_position.x, global_position.z).length()
        var escape_direction := -direction

        if distance_from_center > 7.0:
            var center_direction := Vector3(-global_position.x, 0.0, -global_position.z).normalized()
            escape_direction = (escape_direction * 0.65 + center_direction * 0.9).normalized()

        if distance_to_target > 1.8:
            escape_direction = _apply_separation(escape_direction)
        velocity.x = escape_direction.x * move_speed * 0.76
        velocity.z = escape_direction.z * move_speed * 0.76
    else:
        velocity.x = direction.x * move_speed * 0.84
        velocity.z = direction.z * move_speed * 0.84

    velocity.y = 0.0

func _avoid_obstacles(direction: Vector3) -> Vector3:
    var space := get_world_3d().direct_space_state
    var origin := global_position + Vector3.UP * 0.65
    var forward := direction.normalized()
    var right := Vector3(-forward.z, 0.0, forward.x)
    var best := direction
    var blocked := false

    for offset in [0.0, 0.65, -0.65]:
        var ray_direction: Vector3 = (forward + right * offset).normalized()
        var query := PhysicsRayQueryParameters3D.create(origin, origin + ray_direction * 1.8)
        query.collision_mask = 1
        var hit := space.intersect_ray(query)
        if not hit.is_empty():
            blocked = true
            var normal: Vector3 = hit.normal
            normal.y = 0.0
            if normal.length_squared() > 0.001:
                best += normal.normalized() * 1.8

    if blocked:
        var side := 1.0 if ai_slot % 2 == 0 else -1.0
        best += right * side * 0.9
        best.y = 0.0
        return best.normalized()

    return direction

func _apply_separation(direction: Vector3) -> Vector3:
    var separation := Vector3.ZERO

    for other in all_players:
        if other == self:
            continue

        var offset: Vector3 = global_position - other.global_position
        offset.y = 0.0
        var distance := offset.length()

        if distance > 0.01 and distance < 2.8:
            var strength := (2.8 - distance) / 2.8
            separation += offset.normalized() * strength

    if separation.length_squared() <= 0.0001:
        return direction

    return (direction + separation * 3.2).normalized()

func set_target(new_target: Node3D) -> void:
    target = new_target
    ai_target_is_crown = false
    ai_use_target_point = false
    ai_state = "CHASE"
    ai_use_intercept = false

func set_crown_target(new_target: Node3D) -> void:
    target = new_target
    ai_target_is_crown = true
    ai_use_target_point = false

func set_target_point(new_target: Node3D, point: Vector3) -> void:
    target = new_target
    ai_target_is_crown = false
    ai_target_point = point
    ai_intercept_point = point
    ai_use_target_point = true
    ai_use_intercept = true
    ai_state = "INTERCEPT"

func set_ai_context(new_players: Array[CharacterBody3D]) -> void:
    all_players = new_players

func set_ai_slot(slot: int) -> void:
    ai_slot = slot

func set_movement_enabled(enabled: bool) -> void:
    movement_enabled = enabled
    if not enabled:
        velocity = Vector3.ZERO
