extends Node
class_name MapManager

# --- References ---
@onready var obstacle_layer: TileMapLayer = get_node("../ObstacleLayer")
@onready var ground_layer: TileMapLayer = get_node("../GroundLayer")

# --- Grid Configuration ---
@export var grid_size: int = 64
var astar_grid: AStarGrid2D = AStarGrid2D.new()


func _ready():
	setup_astar()


func setup_astar():
	# Define the grid area based on the ground layer size
	var rect = ground_layer.get_used_rect()
	astar_grid.region = rect
	astar_grid.cell_size = Vector2(grid_size, grid_size)
	
	# Using Chebyshev heuristic for grid-based movement
	astar_grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_CHEBYSHEV
	
	# DIAGONAL_MODE_AT_LEAST_ONE_WALKABLE: Allows diagonal movement 
	# unless both adjacent orthogonal tiles are blocked.
	astar_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_AT_LEAST_ONE_WALKABLE
	astar_grid.update()

	# Iterate through every tile in the used rectangle to set movement costs and obstacles
	for x in range(rect.position.x, rect.end.x):
		for y in range(rect.position.y, rect.end.y):
			var coords = Vector2i(x,y)
			var tile_data = obstacle_layer.get_cell_tile_data(coords)
			
			if tile_data:
				# Fetch custom 'movement_cost' metadata from the TileSet
				var cost = tile_data.get_custom_data("movement_cost")
				
				# If cost is exceptionally high, mark as solid obstacle
				if cost >= 99:
					astar_grid.set_point_solid(coords, true)
				else:
					astar_grid.set_point_weight_scale(coords, cost)
			else:
				# Default weight for empty/ground tiles
				astar_grid.set_point_weight_scale(coords, 1)
				
	# Final update to apply all point modifications
	astar_grid.update()


# Converts global mouse coordinates to grid coordinates (Vector2i)
func get_grid_coords(global_mouse_pos: Vector2) -> Vector2i:
	var local_pos = ground_layer.to_local(global_mouse_pos)
	return ground_layer.local_to_map(local_pos)
