extends Node2D

@export var start_level: PackedScene 
@export var player_scene: PackedScene

@onready var map_manager = $MapManager
var player: Unit


func _ready():
	if start_level and player_scene:
		setup_game()
	else:
		print("No level or player loaded")


func setup_game():
	var level_instance = start_level.instantiate()
	add_child(level_instance)
	map_manager.setup_level(level_instance)
	player = player_scene.instantiate()
	var p_layer = level_instance.get_node("PreviewLayer")
	var s_layer = level_instance.get_node("SelectionLayer")
	var m_label = $CanvasLayer/MovementLabel
	player.setup_player_references(map_manager, m_label, p_layer, s_layer)
	level_instance.get_node("Units").add_child(player)
	var spawn_node = level_instance.get_node_or_null("Markers/PlayerSpawn")
	if spawn_node:
		#player.global_position = spawn_node.global_position
		var actual_grid_pos = map_manager.get_grid_coords(spawn_node.global_position)
		player.teleport_to_grid_pos(actual_grid_pos)
		#player.global_position = map_manager.ground_layer.map_to_local(actual_grid_pos)
		#player.grid_pos = actual_grid_pos
		
	#TurnManager.begine_game()
