extends Node

const ROUND_TIME := 60.0
const STEAL_DISTANCE := 1.8
const STEAL_COOLDOWN := 0.75

var round_time := ROUND_TIME
var steal_cooldown := 0.0
var crown_holder: CharacterBody3D
var players: Array[CharacterBody3D] = []
var scores: Dictionary = {}

var crown: Node3D
var timer_label: Label
var owner_label: Label
var score_label: Label
var status_label: Label

func setup(new_players: Array[CharacterBody3D], new_crown: Node3D) -> void:
    players = new_players
    crown = new_crown
    for player in players:
        scores[player.name] = 0.0
    if players.size() > 0:
        _set_crown_holder(players[0])

func _process(delta: float) -> void:
    if players.is_empty() or crown_holder == null:
        return

    round_time = max(0.0, round_time - delta)
    steal_cooldown = max(0.0, steal_cooldown - delta)
    scores[crown_holder.name] += delta

    _update_crown()
    _check_steal()
    _update_ui()

    if round_time <= 0.0:
        _finish_round()

func _check_steal() -> void:
    if steal_cooldown > 0.0:
        return

    for player in players:
        if player == crown_holder:
            continue
        if player.global_position.distance_to(crown_holder.global_position) <= STEAL_DISTANCE:
            _set_crown_holder(player)
            steal_cooldown = STEAL_COOLDOWN
            status_label.text = "%s украл корону!" % player.name
            return

func _set_crown_holder(player: CharacterBody3D) -> void:
    if crown_holder != null:
        crown_holder.set_meta("crown_holder", false)
    crown_holder = player
    crown_holder.set_meta("crown_holder", true)
    if status_label != null:
        status_label.text = "%s владеет короной" % crown_holder.name

func _update_crown() -> void:
    if crown == null or crown_holder == null:
        return
    crown.global_position = crown_holder.global_position + Vector3(0, 2.0, 0)
    crown.rotate_y(2.5 * get_process_delta_time())

func _update_ui() -> void:
    if timer_label != null:
        timer_label.text = "Время: %02d" % int(ceil(round_time))
    if owner_label != null:
        owner_label.text = "Корона: %s" % crown_holder.name
    if score_label != null:
        var lines: Array[String] = []
        for player in players:
            lines.append("%s: %d с" % [player.name, int(scores[player.name]))])
        score_label.text = "\n".join(lines)

func _finish_round() -> void:
    set_process(false)
    status_label.text = "Раунд окончен"
    var winner: String = crown_holder.name
    for player in players:
        if scores[player.name] > scores[winner]:
            winner = player.name
    owner_label.text = "Победил по времени: %s" % winner

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
    status_label.add_theme_font_size_override("font_size", 24)
    layer.add_child(status_label)
