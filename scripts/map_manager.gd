extends Node
class_name MapManager

# --- References ---
## Reference to the base terrain layer (used for map boundaries)
var ground_layer: TileMapLayer
## Reference to the layer containing walls, trees, or other blockades
var obstacle_layer: TileMapLayer
## Reference to the decoration layer (swamps, mud, etc.) that affects cost
var deco_layer: TileMapLayer


# --- Grid Configuration ---
## The size of a single grid cell in pixels (standard for your tileset)
@export var grid_size: int = 64
## The AStarGrid2D instance handling pathfinding logic and tile weights
var astar_grid: AStarGrid2D = AStarGrid2D.new()


## Initializes the manager with layers from the current level and builds the navigation grid
func setup_level(level_node: Node2D):
	# Link the required TileMapLayers from the instantiated level
	ground_layer = level_node.get_node("GroundLayer")
	obstacle_layer = level_node.get_node("ObstacleLayer")
	deco_layer = level_node.get_node("DecorationLayer")
	# Generate the A* grid based on the newly assigned layers
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
			# Start with ground cost (default 1.0)
			var final_cost = 1.0
			var ground_data = ground_layer.get_cell_tile_data(coords)
			if ground_data:
				var g_cost = ground_data.get_custom_data("movement_cost")
				# If g_cost is 0 (because someone forgot to set the cost) take 1.0
				final_cost = g_cost if g_cost > 0 else 1.0
			# Check decoration layer
			var deco_data = deco_layer.get_cell_tile_data(coords)
			if deco_data:
				var deco_cost = deco_data.get_custom_data("movement_cost")
				final_cost = max(final_cost, deco_cost)
			# Check obstacle Layer
			var obs_data = obstacle_layer.get_cell_tile_data(coords)
			if obs_data:
				var obs_cost = obs_data.get_custom_data("movement_cost")
				if obs_cost >= 99:
					astar_grid.set_point_solid(coords, true)
					continue
				final_cost = max(final_cost, obs_cost)
			astar_grid.set_point_weight_scale(coords, final_cost)
	# Final update to apply all point modifications
	astar_grid.update()


# Converts global mouse coordinates to grid coordinates (Vector2i)
func get_grid_coords(global_mouse_pos: Vector2) -> Vector2i:
	var local_pos = ground_layer.to_local(global_mouse_pos)
	return ground_layer.local_to_map(local_pos)
