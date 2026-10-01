extends Node3D

const PLAYER_SCENE := preload("res://scenes/player/Player.tscn")
const CROWN_SCENE := preload("res://scenes/crown/Crown.tscn")
const GAME_MANAGER_SCRIPT := preload("res://scripts/game/game_manager.gd")

var local_player: CharacterBody3D
var dummy_player: CharacterBody3D
var camera: Camera3D

func _ready() -> void:
    camera = $Camera
    _spawn_gameplay()

func _process(_delta: float) -> void:
    if local_player == null or camera == null:
        return
    camera.global_position = local_player.global_position + Vector3(0, 10, 10)
    camera.look_at(local_player.global_position + Vector3(0, 0.5, 0), Vector3.UP)

func _spawn_gameplay() -> void:
    local_player = PLAYER_SCENE.instantiate()
    local_player.name = "Player_1"
    local_player.is_local_player = true
    local_player.global_position = Vector3(-4, 1.0, 0)
    add_child(local_player)

    dummy_player = PLAYER_SCENE.instantiate()
    dummy_player.name = "Player_2"
    dummy_player.is_dummy = true
    dummy_player.global_position = Vector3(4, 1.0, 0)
    add_child(dummy_player)
    dummy_player.set_target(local_player)

    _apply_player_material(local_player, Color(0.2, 0.55, 1.0))
    _apply_player_material(dummy_player, Color(1.0, 0.3, 0.3))

    var crown := CROWN_SCENE.instantiate()
    crown.name = "Crown"
    add_child(crown)

    var game_manager := Node.new()
    game_manager.name = "GameManager"
    game_manager.set_script(GAME_MANAGER_SCRIPT)
    add_child(game_manager)
    game_manager.create_ui(self)
    game_manager.setup([local_player, dummy_player], crown)

func _apply_player_material(player: Node3D, color: Color) -> void:
    var body := player.get_node("Body") as MeshInstance3D
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.roughness = 0.65
    body.material_override = material
