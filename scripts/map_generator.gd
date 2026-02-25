@tool
extends Node2D

@export_group("Map Dimensions")
@export var map_width: int = 50
@export var map_height: int = 50
@export_group("Object Density")
@export_range(0.0, 1.0) var base_density: float = 0.05 # Base chance for a new cluster
@export_range(0.0, 1.0) var cluster_strength: float = 0.6 # Bonus chance if neighbor is a tree
@export_group("Tile Settings")
@export var tile_ground: Vector2i = Vector2i(0,0)
@export var tiles_path: Array[Vector2i] = [Vector2i(1,0), Vector2i(2,0), Vector2i(3,0), Vector2i(4,0)]
@export var tiles_obstacles: Array[Vector2i] = [
	Vector2i(5,0), Vector2i(6,0), Vector2i(7,0),
	Vector2i(0,1), Vector2i(1,1), Vector2i(2,1), Vector2i(3,1), Vector2i(4,1), Vector2i(5,1),
	Vector2i(0,2), Vector2i(1,2), Vector2i(2,2), Vector2i(3,2), Vector2i(4,2), Vector2i(5,2), Vector2i(6,2), 
]
@export_tool_button("Generate Map") var map_gen_button = generate_full_map


@onready var ground_layer: TileMapLayer = $GroundLayer
@onready var decoration_layer: TileMapLayer = $DecorationLayer
@onready var obstacle_layer: TileMapLayer = $ObstacleLayer


func _ready() -> void:
	generate_full_map()

func generate_full_map() -> void:
	_clear_layers()
	_fill_ground()
	_generate_organic_paths()
	_populate_objects()
	_sync_systems()

func _clear_layers() -> void:
	ground_layer.clear()
	decoration_layer.clear()
	obstacle_layer.clear()

func _fill_ground() -> void:
	for x in range(map_width):
		for y in range(map_height):
			# make sure to use the alternative 1 of the tile_ground
			ground_layer.set_cell(Vector2i(x, y), 0, tile_ground)

func _sync_systems() -> void:
	var map_manager = get_tree().get_first_node_in_group("map_manager")
	if map_manager and map_manager.has_method("update_astar_grid"):
		map_manager.update_astar_grid()
	var player = get_tree().get_first_node_in_group("players")
	if player and player.has_method("update_camera_limits"):
		player.update_camera_limits()

func _generate_organic_paths() -> void:
	var h_start = Vector2i(0, randi_range(5, map_height - 5))
	var h_end = Vector2i(map_width - 1, randi_range(5, map_height - 5))
	_create_path_connection(h_start, h_end)
	var v_start = Vector2i(randi_range(5, map_width - 5), 0)
	var v_end = Vector2i(randi_range(5, map_width - 5), map_height - 1)
	_create_path_connection(v_start, v_end)

func _create_path_connection(start: Vector2i, end: Vector2i) -> void:
	if tiles_path.is_empty():
		push_error("MapGenerator: tiles_path is empty! Check Inspector.")
		return
	var curr = start
	var steps = 0
	var max_steps = map_width * map_height 
	while curr != end and steps < max_steps:
		steps += 1
		decoration_layer.set_cell(curr, 0, tiles_path.pick_random())
		if randf() < 0.5 and curr.x != end.x:
			curr.x += 1 if end.x > curr.x else -1
		elif curr.y != end.y:
			curr.y += 1 if end.y > curr.y else -1
		decoration_layer.set_cell(curr, 0, tiles_path.pick_random())
		if curr.y + 1 < map_height:
			decoration_layer.set_cell(curr + Vector2i.DOWN, 0, tiles_path.pick_random())

func _populate_objects() -> void:
	for x in range(map_width):
		for y in range(map_height):
			var coords = Vector2i(x, y)
			if decoration_layer.get_cell_source_id(coords) != -1: continue # keep paths clear
			var chance = base_density
			# Check if left or top neighbor is already a tree
			var has_neighbor = false
			if obstacle_layer.get_cell_source_id(coords + Vector2i.LEFT) != -1: has_neighbor = true
			if obstacle_layer.get_cell_source_id(coords + Vector2i.UP) != -1: has_neighbor = true
			# If neighbor exists, drastically increase chance
			if has_neighbor:
				chance += cluster_strength
			if randf() < chance:
				obstacle_layer.set_cell(coords, 0, tiles_obstacles.pick_random())
			
			
			
			
			
			
			
			
			
			
			
			
			
			
			
			
			
			
			
