extends Node3D

const PLAYER_SCENE := preload("res://scenes/player/Player.tscn")
const CROWN_SCENE := preload("res://scenes/crown/Crown.tscn")
const GAME_MANAGER_SCRIPT := preload("res://scripts/game/game_manager.gd")

var local_player: CharacterBody3D
var players: Array[CharacterBody3D] = []
var camera: Camera3D

func _ready() -> void:
    camera = $Camera
    _create_pedestal()
    _spawn_gameplay()

func _process(_delta: float) -> void:
    if local_player == null or camera == null:
        return

    camera.global_position = local_player.global_position + Vector3(0, 11, 11)
    camera.look_at(
        local_player.global_position + Vector3(0, 0.5, 0),
        Vector3.UP
    )

func _spawn_gameplay() -> void:
    var spawn_positions: Array[Vector3] = [
        Vector3(-4.5, 0.0, 0.0),
        Vector3(4.5, 0.0, 0.0),
        Vector3(0.0, 0.0, -4.5),
        Vector3(0.0, 0.0, 4.5)
    ]

    var player_colors: Array[Color] = [
        Color(0.2, 0.55, 1.0),
        Color(1.0, 0.3, 0.3),
        Color(0.3, 0.85, 0.35),
        Color(1.0, 0.8, 0.15)
    ]

    for index in range(spawn_positions.size()):
        var player: CharacterBody3D = PLAYER_SCENE.instantiate()
        player.name = "Player_%d" % (index + 1)
        player.is_local_player = index == 0
        player.is_dummy = index > 0
        add_child(player)
        player.global_position = spawn_positions[index]
        _apply_player_material(player, player_colors[index])
        players.append(player)

    local_player = players[0]

    var crown: Node3D = CROWN_SCENE.instantiate()
    crown.name = "Crown"
    add_child(crown)
    crown.global_position = Vector3(0.0, 1.35, 0.0)

    var game_manager := Node.new()
    game_manager.name = "GameManager"
    game_manager.set_script(GAME_MANAGER_SCRIPT)
    add_child(game_manager)
    game_manager.create_ui(self)

    game_manager.setup(players, crown)

func _create_pedestal() -> void:
    var pedestal := CSGCylinder3D.new()
    pedestal.name = "CrownPedestal"
    pedestal.radius = 1.0
    pedestal.height = 0.9
    pedestal.position = Vector3(0.0, 0.45, 0.0)
    add_child(pedestal)

    var material := StandardMaterial3D.new()
    material.albedo_color = Color(0.25, 0.25, 0.28)
    material.roughness = 0.7
    pedestal.material = material

    var top := CSGCylinder3D.new()
    top.name = "PedestalTop"
    top.radius = 1.25
    top.height = 0.18
    top.position = Vector3(0.0, 0.99, 0.0)
    add_child(top)
    top.material = material

func _apply_player_material(player: Node3D, color: Color) -> void:
    var visual := player.get_node("CharacterVisual")
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.roughness = 0.75

    for child in visual.get_children():
        if child is MeshInstance3D:
            child.material_override = material
