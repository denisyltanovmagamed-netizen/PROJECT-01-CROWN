extends Node

const ROUND_TIME: float = 180.0
const CLAIM_DISTANCE: float = 2.0
const STEAL_DISTANCE: float = 1.15
const STEAL_COOLDOWN: float = 1.5
const COUNTDOWN_TIME: float = 3.0

var round_time: float = ROUND_TIME
var countdown_time: float = COUNTDOWN_TIME
var steal_cooldown: float = 0.0
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

    for player in players:
        scores[player.name] = 0.0
        player.set_meta("crown_holder", false)
        player.set_movement_enabled(false)
        player.set_ai_context(players)

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

    if crown_holder != null:
        scores[crown_holder.name] += delta
        _update_crown()
        _check_steal()
    else:
        _check_claim_input()

    _update_ai_targets()
    _update_ui()
    _update_interaction_ui()

    if round_time <= 0.0:
        _finish_round()

func _check_claim_input() -> void:
    if claim_request:
        claim_request = false
        for player in players:
            if player.is_local_player and _horizontal_distance(player.global_position, crown_start_position) <= CLAIM_DISTANCE:
                _set_crown_holder(player)
                status_label.text = "%s забрал корону!" % player.name
                return

    for player in players:
        if not player.is_dummy:
            continue
        if _horizontal_distance(player.global_position, crown_start_position) <= CLAIM_DISTANCE:
            _set_crown_holder(player)
            status_label.text = "%s забрал корону!" % player.name
            return

func _check_steal() -> void:
    if steal_cooldown > 0.0:
        return

    if claim_request:
        claim_request = false
        for player in players:
            if player == crown_holder or not player.is_local_player:
                continue
            if _horizontal_distance(player.global_position, crown_holder.global_position) <= STEAL_DISTANCE:
                _set_crown_holder(player)
                steal_cooldown = STEAL_COOLDOWN
                status_label.text = "%s украл корону!" % player.name
                return

    for player in players:
        if player == crown_holder or not player.is_dummy:
            continue
        if _horizontal_distance(player.global_position, crown_holder.global_position) <= STEAL_DISTANCE:
            _set_crown_holder(player)
            steal_cooldown = STEAL_COOLDOWN
            status_label.text = "%s украл корону!" % player.name
            return

func _horizontal_distance(a: Vector3, b: Vector3) -> float:
    var a_flat := Vector2(a.x, a.z)
    var b_flat := Vector2(b.x, b.z)
    return a_flat.distance_to(b_flat)

func _set_crown_holder(player: CharacterBody3D) -> void:
    if crown_holder != null:
        crown_holder.set_meta("crown_holder", false)

    crown_holder = player
    crown_holder.set_meta("crown_holder", true)
    steal_cooldown = STEAL_COOLDOWN

func _update_crown() -> void:
    if crown == null or crown_holder == null:
        return

    crown.global_position = crown_holder.global_position + Vector3(0.0, 2.35, 0.0)
    crown.rotate_y(2.5 * get_process_delta_time())

func _update_ai_targets() -> void:
    if not round_started:
        return

    if crown_holder == null:
        var dummy_index := 0
        for player in players:
            if not player.is_dummy:
                continue

            var angle := (TAU / 3.0) * dummy_index
            var approach_point := crown.global_position + Vector3(cos(angle), 0.0, sin(angle)) * 1.0
            player.set_target_point(crown, approach_point)
            dummy_index += 1
        return

    var attackers: Array[CharacterBody3D] = []
    for player in players:
        if player.is_dummy and player != crown_holder:
            attackers.append(player)

    var direct_attacker: CharacterBody3D = null
    var direct_distance := INF

    for player in attackers:
        var distance := _horizontal_distance(player.global_position, crown_holder.global_position)
        if distance < direct_distance:
            direct_distance = distance
            direct_attacker = player

    var flank_index := 0
    for player in players:
        if not player.is_dummy:
            continue

        if player == crown_holder:
            var nearest_opponent: CharacterBody3D = _find_nearest_opponent(player)
            player.set_target(nearest_opponent)
            continue

        if player == direct_attacker:
            player.set_target(crown_holder)
            continue

        var flank_angle := (TAU / 2.0) * flank_index + PI * 0.5
        var flank_point := crown_holder.global_position + Vector3(cos(flank_angle), 0.0, sin(flank_angle)) * 2.6
        player.set_target_point(crown_holder, flank_point)
        flank_index += 1

func _find_nearest_opponent(from_player: CharacterBody3D) -> CharacterBody3D:
    var nearest: CharacterBody3D = null
    var nearest_distance: float = INF

    for player in players:
        if player == from_player:
            continue

        var distance: float = from_player.global_position.distance_to(player.global_position)
        if distance < nearest_distance:
            nearest_distance = distance
            nearest = player

    return nearest

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
    score_label.add_theme_font_size_override("font_size", 20)
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
        if _horizontal_distance(local_player.global_position, crown_holder.global_position) <= STEAL_DISTANCE:
            interaction_label.text = "ПКМ — УКРАСТЬ КОРОНУ"
        else:
            interaction_label.text = ""

func _get_local_player() -> CharacterBody3D:
    for player in players:
        if player.is_local_player:
            return player
    return null
