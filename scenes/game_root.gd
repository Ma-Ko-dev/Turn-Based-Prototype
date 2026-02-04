extends Node2D

@export var start_level: PackedScene 

@onready var map_manager = $MapManager
@onready var player = $PlayerToken


func _ready():
	if start_level:
		setup_game()
	else:
		print("No level loaded")


func setup_game():
	var level_instance = start_level.instantiate()
	add_child(level_instance)
	map_manager.setup_level(level_instance)
	var spawn_node = level_instance.get_node_or_null("Markers/PlayerSpawn")
	if spawn_node:
		player.global_position = spawn_node.global_position
	TurnManager.begine_game()
