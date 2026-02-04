extends Sprite2D
class_name Unit

# --- Constants & Exports ---
@export var movement_range: int = 6
@export var initiative_bonus: int = 0

# --- State Variables ---
var grid_pos: Vector2i: 
	set(value):
		grid_pos = value
		# Synchronize pixel position with grid coordinates whenever grid_pos changes
		position = Vector2(grid_pos) * grid_size + Vector2(grid_size / 2.0, grid_size / 2.0)

var remaining_movement: int = 0
var current_initiative_score: int = 0
var is_moving: bool = false
var is_selected: bool = false
var is_active_unit: bool = false

# --- References ---
#@onready var map_manager: MapManager = get_node("../MapManager")
var map_manager: MapManager

# Helper properties to easily access grid data from the MapManager
var astar_grid: AStarGrid2D:
	get:
		return map_manager.astar_grid
var grid_size: float:
	get:
		return map_manager.grid_size


# --- Lifecycle Functions ---
func _ready():
	remaining_movement = movement_range
	if map_manager:
		# Calculate initial grid position based on the starting world position in the editor
		#grid_pos = Vector2i(floor(position.x / grid_size), floor(position.y / grid_size))
		# Wait for a frame to ensure MapManager has initialized the AStar grid before occupying a cell
		await get_tree().process_frame
		set_grid_occupancy(true)


# --- Pathfinding ---
func get_path_and_cost(target_cell: Vector2i):
	# Temporarily unblock the unit's own cell so AStar can calculate a path starting from it
	astar_grid.set_point_solid(grid_pos, false)
	var path = astar_grid.get_id_path(grid_pos, target_cell)
	astar_grid.set_point_solid(grid_pos, true)
	
	var total_cost = 0
	# Accumulate costs from all tiles in the path (excluding the starting tile)
	for i in range(1, path.size()):
		var cell = path[i]
		total_cost += astar_grid.get_point_weight_scale(cell)
		
	return {"path": path, "cost": total_cost}


# --- Core Movement Logic ---
func execute_movement(path: Array[Vector2i], cost: int):
	# Cancel if the path is invalid or too short
	if path.size() <= 1:
		is_moving = false
		on_movement_finished_logic()
		return
		
	# Unmark the old cell as occupied so other units could potentially pass through
	set_grid_occupancy(false)
	is_moving = true
	on_movement_start_logic()
	
	# Animate the movement tile-by-tile using a Tween
	var tween = create_tween()
	for i in range(1, path.size()):
		var target_pixel_pos = Vector2(path[i]) * grid_size + Vector2(grid_size / 2.0, grid_size / 2.0)
		tween.tween_property(self, "position", target_pixel_pos, 0.25).set_trans(Tween.TRANS_LINEAR)
	
	await tween.finished
	
	# Finalize state at the destination
	grid_pos = path[-1]
	remaining_movement -= cost
	is_moving = false
	
	# Mark the new cell as occupied
	set_grid_occupancy(true)
	
	# Trigger post-movement logic (handled in Player/Enemy subclasses)
	on_movement_finished_logic()


# --- Grid Management ---
func set_grid_occupancy(is_occupied: bool):
	# Marks the unit's current tile as solid/blocked in the shared AStar grid
	if astar_grid:
		astar_grid.set_point_solid(grid_pos, is_occupied)


func teleport_to_grid_pos(new_grid_pos: Vector2i):
	grid_pos = new_grid_pos
	set_grid_occupancy(true)


# --- Turn Logic ---
func start_new_turn():
	# Reset movement points; this function is typically overridden in subclasses
	remaining_movement = movement_range


# --- Hook Functions (Subclass Overrides) ---
func on_movement_start_logic():
	# Placeholder for logic triggered when the unit begins moving
	pass


func on_movement_finished_logic():
	# Placeholder for logic triggered when the unit stops moving
	pass
