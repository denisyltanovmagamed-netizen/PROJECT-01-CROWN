extends CharacterBody3D

@export var move_speed: float = 7.0
@export var acceleration: float = 25.0
@export var braking: float = 30.0
@export var turn_speed: float = 14.0
@export var is_local_player: bool = false
@export var is_dummy: bool = false

var target: Node3D
var ai_target_point: Vector3
var ai_use_target_point: bool = false
var movement_enabled: bool = false
var arena_limit: float = 15.0
var all_players: Array[CharacterBody3D] = []
var ai_slot: int = 0
var ai_state: String = "CHASE"
var ai_bias: float = 0.0

var facing_direction: Vector3 = Vector3.FORWARD
var ai_stop_distance: float = 0.0

func _physics_process(delta: float) -> void:
    if not movement_enabled:
        velocity = Vector3.ZERO
        move_and_slide()
        return

    if is_local_player:
        _handle_local_input(delta)
    elif is_dummy:
        _handle_dummy_ai(delta)
    else:
        velocity = Vector3.ZERO

    move_and_slide()
    global_position.x = clampf(global_position.x, -arena_limit, arena_limit)
    global_position.z = clampf(global_position.z, -arena_limit, arena_limit)

    _update_facing(delta)

func _handle_local_input(delta: float) -> void:
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

    var target_velocity := direction * move_speed
    var rate := acceleration if direction.length_squared() > 0.001 else braking
    velocity.x = move_toward(velocity.x, target_velocity.x, rate * delta)
    velocity.z = move_toward(velocity.z, target_velocity.z, rate * delta)
    velocity.y = 0.0

func _handle_dummy_ai(delta: float) -> void:
    var desired := Vector3.ZERO

    if ai_use_target_point:
        desired = ai_target_point - global_position
    elif target != null:
        desired = target.global_position - global_position

    desired.y = 0.0

    if desired.length_squared() <= 0.04:
        velocity.x = move_toward(velocity.x, 0.0, braking * delta)
        velocity.z = move_toward(velocity.z, 0.0, braking * delta)
        velocity.y = 0.0
        return

    desired = desired.normalized()
    desired = _choose_clear_direction(desired)

    var target_velocity := desired * move_speed
    if ai_state == "HOLDER_ESCAPE":
        target_velocity *= 1.0

    velocity.x = move_toward(velocity.x, target_velocity.x, acceleration * delta)
    velocity.z = move_toward(velocity.z, target_velocity.z, acceleration * delta)
    velocity.y = 0.0

func _choose_clear_direction(desired: Vector3) -> Vector3:
    var candidates: Array[Vector3] = [desired]

    for degrees in [-60.0, -35.0, -18.0, 18.0, 35.0, 60.0, 90.0, -90.0]:
        var angle := deg_to_rad(degrees)
        candidates.append(desired.rotated(Vector3.UP, angle).normalized())

    var best_direction := desired
    var best_score := -INF

    for candidate in candidates:
        var clearance := _ray_clearance(candidate)
        var alignment := candidate.dot(desired)
        var separation := _separation_score(candidate)
        var score := alignment * 2.4 + clearance * 1.5 + separation * 0.8

        if score > best_score:
            best_score = score
            best_direction = candidate

    return best_direction.normalized()

func _ray_clearance(direction: Vector3) -> float:
    var space := get_world_3d().direct_space_state
    var origin := global_position + Vector3.UP * 0.65
    var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * 2.4)
    query.collision_mask = 1
    query.exclude = [self]

    var hit := space.intersect_ray(query)
    if hit.is_empty():
        return 1.0

    var distance: float = origin.distance_to(hit.position)
    return clampf(distance / 2.4, 0.0, 1.0)

func _separation_score(direction: Vector3) -> float:
    var score := 1.0

    for other in all_players:
        if other == self:
            continue

        var offset := other.global_position - global_position
        offset.y = 0.0
        var distance := offset.length()

        if distance <= 0.05 or distance >= 2.2:
            continue

        var toward_other := direction.dot(offset.normalized())
        var danger := (2.2 - distance) / 2.2

        if toward_other > 0.15:
            score -= danger * toward_other

    return clampf(score, 0.0, 1.0)

func _update_facing(delta: float) -> void:
    var flat_velocity := Vector3(velocity.x, 0.0, velocity.z)

    if flat_velocity.length_squared() <= 0.04:
        return

    var desired := flat_velocity.normalized()
    facing_direction = facing_direction.slerp(desired, clampf(turn_speed * delta, 0.0, 1.0)).normalized()

    var visual := get_node_or_null("CharacterVisual")
    if visual != null:
        visual.rotation.y = atan2(facing_direction.x, facing_direction.z)

func set_target(new_target: Node3D) -> void:
    target = new_target
    ai_use_target_point = false
    ai_state = "CHASE"

func set_crown_target(new_target: Node3D) -> void:
    target = new_target
    ai_use_target_point = false
    ai_state = "CROWN_APPROACH"

func set_target_point(new_target: Node3D, point: Vector3) -> void:
    target = new_target
    ai_target_point = point
    ai_use_target_point = true
    ai_state = "INTERCEPT"

func set_ai_state(new_state: String) -> void:
    ai_state = new_state

func set_ai_context(new_players: Array[CharacterBody3D]) -> void:
    all_players = new_players

func set_ai_slot(slot: int) -> void:
    ai_slot = slot
    ai_bias = -1.0 if slot % 2 == 0 else 1.0

func set_movement_enabled(enabled: bool) -> void:
    movement_enabled = enabled
    if not enabled:
        velocity = Vector3.ZERO
