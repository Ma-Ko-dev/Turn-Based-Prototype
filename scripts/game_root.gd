extends Node2D

## The level scene that will be loaded on start
@export var start_level: PackedScene 
## The player scene to be instantiated at the start marker
@export var player_scene: PackedScene

@onready var map_manager = $MapManager
var player: Unit
var _spawn_counts: Dictionary = {}


# --- Lifecycle ---
func _ready() -> void:
	# Validate that essential scenes are assigned before starting
	if start_level and player_scene:
		_setup_game()
	else:
		printerr("GameRoot: Essential scenes (level or player) are missing!")


# --- Main Setup Flow ---
## Main initialization flow: loads level, sets up grid, and spawns all units
func _setup_game() -> void:
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
				_spawn_player(marker, units_node, level_instance)
			else:        
				_spawn_enemy(marker, units_node)


# --- Spawning Logic ---
## Creates the player and injects all necessary system references
func _spawn_player(marker: SpawnMarker, container: Node, level: Node2D):
	player = player_scene.instantiate()
	player.map_manager = map_manager
	container.add_child(player)	
	# Dependency Injection: Providing the player with required system nodes
	player.setup_player_references(
		map_manager,
		level.get_node("PreviewLayer"),
		level.get_node("SelectionLayer")
	)
	# Ensure the player is identifiable by AI and turn logic
	player.add_to_group("players")
	_place_on_grid(player, marker.global_position)


## Creates an enemy using the template and data provided by the SpawnMarker
func _spawn_enemy(marker: SpawnMarker, container):
	if not marker.unit_scene: return
	# Instantiate the base enemy scene (e.g., Enemy.tscn)
	var enemy = marker.unit_scene.instantiate()
	enemy.map_manager = map_manager
	# Assign the specific stat resource (e.g., Goblin.tres) before the enemy enters the tree
	if marker.unit_data:
		enemy.data = marker.unit_data
		_assign_unique_name(enemy)
	else:
		push_warning("GameRoot: No unit_data for marker %s" % marker.name)
	# Add to the unit container (triggers _ready and visual setup)
	container.add_child(enemy)
	_place_on_grid(enemy, marker.global_position)


# --- Internal Helpers ---
func _place_on_grid(unit: Unit, world_pos: Vector2) -> void:
	var coords = map_manager.get_grid_coords(world_pos)
	unit.teleport_to_grid_pos(coords)


func _assign_unique_name(unit: Unit) -> void:
	var type_name = unit.data.name
	if not _spawn_counts.has(type_name):
		_spawn_counts[type_name] = 1
	var unique_id = "%s %d" % [type_name, _spawn_counts[type_name]]
	unit.name = unique_id
	unit.display_name = unique_id
	_spawn_counts[type_name] += 1
		
		
		
		
		
		
		
		
		
		
		
