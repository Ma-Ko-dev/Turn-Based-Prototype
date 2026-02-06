extends Node2D

## The level scene that will be loaded on start
@export var start_level: PackedScene 
## The player scene to be instantiated at the start marker
@export var player_scene: PackedScene

@onready var map_manager = $MapManager
var player: Unit
var spawn_counts: Dictionary = {}


func _ready():
	# Validate that essential scenes are assigned before starting
	if start_level and player_scene:
		setup_game()
	else:
		print("No level or player loaded")


## Main initialization flow: loads level, sets up grid, and spawns all units
func setup_game():
	# Instantiate and add the level to the scene tree
	var level_instance = start_level.instantiate()
	add_child(level_instance)
	
	# Initialize the A* grid and map bounds using the new level
	map_manager.setup_level(level_instance)
	
	# Define target containers for organization
	var markers_node = level_instance.get_node("Markers")
	var units_node = level_instance.get_node("Units")
	
	# Iterate through all children in the Markers container
	for marker in markers_node.get_children():
		if marker is SpawnMarker:
			# Differentiate between Player and Enemy based on marker settings
			if marker.is_player_spawn:
				spawn_player(marker, units_node, level_instance)
			else:        
				spawn_enemy(marker, units_node)


## Creates the player and injects all necessary system references
func spawn_player(marker, container, level):
	player = player_scene.instantiate()
	container.add_child(player)
	
	# Dependency Injection: Providing the player with required system nodes
	player.setup_player_references(
		map_manager,
		$CanvasLayer/MovementLabel,
		level.get_node("PreviewLayer"),
		level.get_node("SelectionLayer")
	)
	
	# Ensure the player is identifiable by AI and turn logic
	player.add_to_group("players")
	
	# Place player on the grid based on the marker's world position
	var grid_pos = map_manager.get_grid_coords(marker.global_position)
	player.teleport_to_grid_pos(grid_pos)


## Creates an enemy using the template and data provided by the SpawnMarker
func spawn_enemy(marker: SpawnMarker, container):
	if not marker.unit_scene:
		return
		
	# Instantiate the base enemy scene (e.g., Enemy.tscn)
	var enemy = marker.unit_scene.instantiate()
	
	# Assign the specific stat resource (e.g., Goblin.tres) before the enemy enters the tree
	if marker.unit_data:
		enemy.data = marker.unit_data
		# Unique naming logic
		var unit_type = enemy.data.name #for example "Goblin"
		# Initialize count if type is new
		if not spawn_counts.has(unit_type):
			spawn_counts[unit_type] = 1
		# assign name and increment counter
		var unique_name = unit_type + " " + str(spawn_counts[unit_type])
		enemy.name = unique_name # for scene tree
		enemy.display_name = unique_name # for logs
		#enemy.name = unit_type + " " + str(spawn_counts[unit_type])
		spawn_counts[unit_type] += 1
	else:
		print("WARNING: No unit_data assigned to marker: ", marker.name)
	
	# Provide the enemy with map access for pathfinding logic
	enemy.map_manager = map_manager
	
	# Add to the unit container (triggers _ready and visual setup)
	container.add_child(enemy)
	
	# Sync position with the grid
	var grid_pos = map_manager.get_grid_coords(marker.global_position)
	enemy.teleport_to_grid_pos(grid_pos)
