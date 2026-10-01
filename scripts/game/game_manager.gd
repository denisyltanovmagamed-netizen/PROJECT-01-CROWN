extends Node

const ROUND_TIME: float = 180.0
const CLAIM_DISTANCE: float = 1.65
const STEAL_DISTANCE: float = 1.40
const STEAL_COOLDOWN: float = 0.70
const COUNTDOWN_TIME: float = 3.0
const ARENA_LIMIT: float = 15.0
const PREDICTION_TIME: float = 0.80
const STEAL_FRONT_DOT: float = 0.55

var round_time: float = ROUND_TIME
var countdown_time: float = COUNTDOWN_TIME
var steal_cooldown: float = 0.0
var ai_rethink_timer: float = 0.0
var crown_holder: CharacterBody3D = null
var players: Array[CharacterBody3D] = []
var scores: Dictionary = {}
var round_started: bool = false
var round_finished: bool = false

var crown: Node3D
var crown_start_position: Vector3

var timer_label: Label
var owner_label: Label
var score_label: Label
var status_label: Label
var interaction_label: Label
var claim_request: bool = false

func setup(new_players: Array[CharacterBody3D], new_crown: Node3D) -> void:
    players = new_players
    crown = new_crown
    crown_start_position = Vector3(0.0, 1.35, 0.0)

    round_time = ROUND_TIME
    countdown_time = COUNTDOWN_TIME
    steal_cooldown = 0.0
    ai_rethink_timer = 0.0
    round_started = false
    round_finished = false

    var dummy_slot := 0
    for player in players:
        scores[player.name] = 0.0
        player.set_meta("crown_holder", false)
        player.set_movement_enabled(false)
        player.set_ai_context(players)
        if player.is_dummy:
            player.set_ai_slot(dummy_slot)
            dummy_slot += 1

    crown_holder = null
    crown.global_position = crown_start_position

    _update_ui()
    _update_interaction_ui()
    status_label.text = "3"

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.pressed and not event.canceled and event.button_index == MOUSE_BUTTON_RIGHT:
        claim_request = true

func _process(delta: float) -> void:
    if round_finished:
        return

    if not round_started:
        countdown_time -= delta
        var countdown_number: int = int(ceil(countdown_time))

        if countdown_number > 0:
            status_label.text = str(countdown_number)
        else:
            round_started = true
            for player in players:
                player.set_movement_enabled(true)
            status_label.text = "СТАРТ!"

        _update_ui()
        return

    round_time = maxf(0.0, round_time - delta)
    steal_cooldown = maxf(0.0, steal_cooldown - delta)
    ai_rethink_timer = maxf(0.0, ai_rethink_timer - delta)

    if crown_holder != null:
        scores[crown_holder.name] += delta
        _update_crown()
        _check_steal()
    else:
        _check_claim_input()

    if ai_rethink_timer <= 0.0:
        ai_rethink_timer = 0.18
        _update_ai_targets()

    _update_ui()
    _update_interaction_ui()

    if round_time <= 0.0:
        _finish_round()

func _check_claim_input() -> void:
    if claim_request:
        claim_request = false
        var local_player := _get_local_player()
        if local_player != null and _horizontal_distance(local_player.global_position, crown_start_position) <= CLAIM_DISTANCE:
            _set_crown_holder(local_player)
            status_label.text = "ТЫ ЗАБРАЛ КОРОНУ"
            return

    var closest_ai: CharacterBody3D = null
    var closest_distance := INF

    for player in players:
        if not player.is_dummy:
            continue

        var distance := _horizontal_distance(player.global_position, crown_start_position)
        if distance <= CLAIM_DISTANCE and distance < closest_distance:
            closest_distance = distance
            closest_ai = player

    if closest_ai != null:
        _set_crown_holder(closest_ai)
        status_label.text = "%s забрал корону!" % closest_ai.name

func _check_steal() -> void:
    if crown_holder == null or steal_cooldown > 0.0:
        claim_request = false
        return

    if claim_request:
        claim_request = false
        var local_player := _get_local_player()
        if local_player != null and local_player != crown_holder and _can_steal(local_player, crown_holder):
            _set_crown_holder(local_player)
            steal_cooldown = STEAL_COOLDOWN
            status_label.text = "ТЫ УКРАЛ КОРОНУ"
            return

    var best_attacker: CharacterBody3D = null
    var best_score := INF

    for player in players:
        if player == crown_holder or not player.is_dummy:
            continue
        if not _can_steal(player, crown_holder):
            continue

        var distance := _horizontal_distance(player.global_position, crown_holder.global_position)
        if distance < best_score:
            best_score = distance
            best_attacker = player

    if best_attacker != null:
        _set_crown_holder(best_attacker)
        steal_cooldown = STEAL_COOLDOWN
        status_label.text = "%s украл корону!" % best_attacker.name

func _can_steal(attacker: CharacterBody3D, holder: CharacterBody3D) -> bool:
    if _horizontal_distance(attacker.global_position, holder.global_position) > STEAL_DISTANCE:
        return false

    var to_attacker := attacker.global_position - holder.global_position
    to_attacker.y = 0.0
    if to_attacker.length_squared() <= 0.001:
        return false

    to_attacker = to_attacker.normalized()
    var facing := holder.facing_direction
    facing.y = 0.0
    if facing.length_squared() <= 0.001:
        facing = Vector3.FORWARD
    facing = facing.normalized()

    # Front attacks are intentionally protected. The attacker must reach the side or back.
    return facing.dot(to_attacker) <= STEAL_FRONT_DOT

func _horizontal_distance(a: Vector3, b: Vector3) -> float:
    var a_flat := Vector2(a.x, a.z)
    var b_flat := Vector2(b.x, b.z)
    return a_flat.distance_to(b_flat)

func _set_crown_holder(player: CharacterBody3D) -> void:
    if crown_holder != null:
        crown_holder.set_meta("crown_holder", false)

    crown_holder = player
    crown_holder.set_meta("crown_holder", true)

func _update_crown() -> void:
    if crown == null or crown_holder == null:
        return

    crown.global_position = crown_holder.global_position + Vector3(0.0, 2.35, 0.0)
    crown.rotate_y(2.5 * get_process_delta_time())

func _update_ai_targets() -> void:
    if not round_started:
        return

    if crown_holder == null:
        _assign_crown_approach_targets()
        return

    var attackers: Array[CharacterBody3D] = []
    for player in players:
        if player.is_dummy and player != crown_holder:
            attackers.append(player)

    var holder_velocity := crown_holder.velocity
    holder_velocity.y = 0.0
    var predicted_position := crown_holder.global_position + holder_velocity * PREDICTION_TIME
    predicted_position.x = clampf(predicted_position.x, -ARENA_LIMIT + 1.5, ARENA_LIMIT - 1.5)
    predicted_position.z = clampf(predicted_position.z, -ARENA_LIMIT + 1.5, ARENA_LIMIT - 1.5)

    for index in range(attackers.size()):
        var player := attackers[index]

        if index % 4 == 0:
            # Direct pressure: forces the holder to react.
            player.set_target(crown_holder)
            player.set_ai_state("CHASE")
        elif index % 4 == 1:
            # Cut the route in front of the holder.
            var forward := holder_velocity.normalized()
            if forward.length_squared() <= 0.01:
                forward = (crown_holder.global_position - player.global_position).normalized()
            var point := predicted_position + forward * 1.2
            player.set_target_point(crown_holder, _clamp_arena_point(point))
            player.set_ai_state("INTERCEPT")
        elif index % 4 == 2:
            # Attack from a side, making a straight chase less likely.
            var lateral := Vector3(-holder_velocity.z, 0.0, holder_velocity.x).normalized()
            if lateral.length_squared() <= 0.01:
                lateral = Vector3(1.0, 0.0, 0.0)
            lateral *= -1.0 if player.ai_slot % 2 == 0 else 1.0
            var point := predicted_position + lateral * 1.15
            player.set_target_point(crown_holder, _clamp_arena_point(point))
            player.set_ai_state("FLANK")
        else:
            # A second interception lane keeps several bots from collapsing onto one point.
            var radial := (player.global_position - crown_holder.global_position)
            radial.y = 0.0
            if radial.length_squared() <= 0.01:
                radial = Vector3(1.0, 0.0, 0.0)
            radial = radial.normalized()
            var point := predicted_position + radial * 1.0
            player.set_target_point(crown_holder, _clamp_arena_point(point))
            player.set_ai_state("INTERCEPT")

    if crown_holder.is_dummy:
        var escape_point := _find_best_escape_point(crown_holder)
        crown_holder.set_target_point(crown_holder, escape_point)
        crown_holder.set_ai_state("HOLDER_ESCAPE")

func _assign_crown_approach_targets() -> void:
    var dummy_index := 0
    for player in players:
        if not player.is_dummy:
            continue

        var angle := (TAU / 7.0) * float(dummy_index)
        var approach_point := crown.global_position + Vector3(cos(angle), 0.0, sin(angle)) * 0.85
        player.set_target_point(crown, _clamp_arena_point(approach_point))
        player.set_ai_state("CROWN_APPROACH")
        dummy_index += 1

func _find_best_escape_point(holder: CharacterBody3D) -> Vector3:
    var best_point := holder.global_position
    var best_score := -INF

    var threat_points: Array[Vector3] = []
    for player in players:
        if player == holder:
            continue
        threat_points.append(player.global_position)

    if threat_points.is_empty():
        return holder.global_position

    for index in range(16):
        var angle := (TAU / 16.0) * float(index)
        var candidate := holder.global_position + Vector3(cos(angle), 0.0, sin(angle)) * 6.0
        candidate = _clamp_arena_point(candidate)

        var nearest_threat := INF
        for threat in threat_points:
            nearest_threat = minf(nearest_threat, _horizontal_distance(candidate, threat))

        # Prefer open space, but avoid running directly into the arena boundary.
        var edge_margin := minf(
            minf(candidate.x + ARENA_LIMIT, ARENA_LIMIT - candidate.x),
            minf(candidate.z + ARENA_LIMIT, ARENA_LIMIT - candidate.z)
        )
        var score := nearest_threat * 2.0 + edge_margin * 0.8

        if score > best_score:
            best_score = score
            best_point = candidate

    return best_point

func _clamp_arena_point(point: Vector3) -> Vector3:
    point.x = clampf(point.x, -ARENA_LIMIT + 1.0, ARENA_LIMIT - 1.0)
    point.z = clampf(point.z, -ARENA_LIMIT + 1.0, ARENA_LIMIT - 1.0)
    point.y = 0.0
    return point

func _update_ui() -> void:
    if timer_label != null:
        timer_label.text = "Время: %03d" % int(ceil(round_time))

    if owner_label != null:
        if crown_holder == null:
            owner_label.text = "Корона: свободна"
        else:
            owner_label.text = "Корона: %s" % crown_holder.name

    if score_label != null:
        var lines: Array[String] = []
        for player in players:
            lines.append("%s: %d с" % [player.name, int(scores[player.name])])
        score_label.text = "\n".join(lines)

func _finish_round() -> void:
    round_finished = true

    for player in players:
        player.set_movement_enabled(false)

    status_label.text = "РАУНД ОКОНЧЕН"

    var winner: String = players[0].name
    for player in players:
        if scores[player.name] > scores[winner]:
            winner = player.name

    owner_label.text = "Больше всего времени: %s" % winner

func create_ui(parent: Node) -> void:
    var layer := CanvasLayer.new()
    parent.add_child(layer)

    timer_label = Label.new()
    timer_label.position = Vector2(24, 20)
    timer_label.add_theme_font_size_override("font_size", 28)
    layer.add_child(timer_label)

    owner_label = Label.new()
    owner_label.position = Vector2(24, 58)
    owner_label.add_theme_font_size_override("font_size", 22)
    layer.add_child(owner_label)

    score_label = Label.new()
    score_label.position = Vector2(24, 100)
    score_label.add_theme_font_size_override("font_size", 18)
    layer.add_child(score_label)

    status_label = Label.new()
    status_label.position = Vector2(24, 180)
    status_label.add_theme_font_size_override("font_size", 42)
    layer.add_child(status_label)

    interaction_label = Label.new()
    interaction_label.position = Vector2(24, 245)
    interaction_label.add_theme_font_size_override("font_size", 20)
    layer.add_child(interaction_label)

func _update_interaction_ui() -> void:
    if interaction_label == null or not round_started or round_finished:
        return

    var local_player := _get_local_player()
    if local_player == null:
        interaction_label.text = ""
        return

    if crown_holder == null:
        if _horizontal_distance(local_player.global_position, crown_start_position) <= CLAIM_DISTANCE:
            interaction_label.text = "ПКМ — ЗАБРАТЬ КОРОНУ"
        else:
            interaction_label.text = ""
    elif crown_holder != local_player:
        if _can_steal(local_player, crown_holder):
            interaction_label.text = "ПКМ — УКРАСТЬ КОРОНУ (СБОКУ/СЗАДИ)"
        elif _horizontal_distance(local_player.global_position, crown_holder.global_position) <= STEAL_DISTANCE:
            interaction_label.text = "ЗАЙДИ СБОКУ ИЛИ СЗАДИ"

func _get_local_player() -> CharacterBody3D:
    for player in players:
        if player.is_local_player:
            return player
    return null
