extends Sprite2D
class_name Unit


@export var data: UnitData

# --- State Variables ---
var grid_pos: Vector2i: 
	set(value):
		grid_pos = value
		# Synchronize pixel position with grid coordinates whenever grid_pos changes
		position = Vector2(grid_pos) * grid_size + Vector2(grid_size / 2.0, grid_size / 2.0)
var display_name: String = ""
var max_health: int
var current_health: int
var movement_range: int
var remaining_movement: int = 0:
	set(value):
		remaining_movement = value
		movement_changed.emit(remaining_movement)
signal movement_changed(new_amount: int)
var current_initiative_score: int = 0
var is_moving: bool = false
var is_selected: bool = false
var is_active_unit: bool = false
var has_attacked: bool = false

# --- References ---
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
	if not map_manager:
		await get_tree().process_frame
	if data:
		texture = data.texture
		movement_range = data.movement_range
		#initiative_bonus = data.initiative_bonus
		max_health = data.calculate_initial_hp()
		current_health = max_health
		if display_name == "":
			display_name = data.name
		print(display_name, " initialized with ", current_health, " HP") #debug
	if map_manager:
		# Calculate initial grid position based on the starting world position in the editor
		# Wait for a frame to ensure MapManager has initialized the AStar grid before occupying a cell
		await get_tree().process_frame
		set_grid_occupancy(true)
	remaining_movement = movement_range


# --- Pathfinding ---
func get_path_and_cost(target_cell: Vector2i):
	# Temporarily unblock the unit's own cell so AStar can calculate a path starting from it
	astar_grid.set_point_solid(grid_pos, false)
	var path = astar_grid.get_id_path(grid_pos, target_cell)
	astar_grid.set_point_solid(grid_pos, true)
	
	var total_cost = 0.0
	# Accumulate costs from all tiles in the path (excluding the starting tile)
	for i in range(1, path.size()):
		var cell = path[i]
		total_cost += astar_grid.get_point_weight_scale(cell)
		
	return {"path": path, "cost": total_cost}


# --- Core Movement Logic ---
func execute_movement(path: Array[Vector2i], cost: float):
	# Cancel if the path is invalid or too short
	if path.size() <= 1 or cost > remaining_movement:
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
	remaining_movement -= int(cost)
	is_moving = false
	
	# Mark the new cell as occupied
	set_grid_occupancy(true)
	
	# Trigger post-movement logic (handled in Player/Enemy subclasses)
	on_movement_finished_logic()


# --- Combat ---
## Checks if an incoming attack roll meets or exceeds this unit's Armor Class.
## According to Pathfinder rules, a roll equal to AC is a hit.
func check_hit(attack_roll: int) -> bool:
	# Default AC is 10 if no data is present
	var ac = 10
	if not data: return attack_roll >= ac
	ac = data.get_armor_class()
	var is_hit = attack_roll >= ac
	# Log the result for debugging (will be moved to UI Log later)
	print(self.display_name, " (AC ", ac, ") was targeted. Roll: ", attack_roll, " -> Hit: ", is_hit)
	return is_hit


## Handles the attack logic when right-clicking an enemy
func attack_target(target: Unit):
	if has_attacked:
		print(display_name, " has no actions left to attack!")
		return
	print(display_name, " attacks ", target.display_name, "!")
	# 1d20 + Strength Modifier + BAB
	var roll = Dice.roll(1, 20, data.get_attack_bonus())
	if target.check_hit(roll):
		print("HIT! Rolled ", roll)
		# Calculate damage: 1d8 (standard) + Strength modifier
		var damage_roll = Dice.roll(data.damage_dice_count, data.damage_dice_sides, data.get_modifier(data.strength))
		# Ensure at least 1 damage is dealt even with low strength
		var final_damage = max(1, damage_roll)
		target.take_damage(final_damage)
	else:
		print(display_name, " missed ", target.display_name)
	has_attacked = true


## Reduces health and checks for death
func take_damage(amount: int):
	current_health -= amount
	print(display_name, " takes ", amount, " damage! (HP: ", current_health, "/", max_health, ")")
	if current_health <= 0:
		die()


## Handles unit removal
func die():
	print(display_name, " has been defeated!")
	set_grid_occupancy(false)
	if TurnManager.current_state == TurnManager.State.COMBAT:
		TurnManager.remove_unit_from_combat(self)
	if is_in_group("players"):
		# Hide the player and stop processing logic
		visible = false
		is_selected = false
		set_process(false)
		set_physics_process(false)
		remove_from_group("players")
		if has_method("update_selection_visual"):
			call("update_selection_visual")
	else:
		queue_free()


# --- Grid Management ---
func set_grid_occupancy(is_occupied: bool):
	# Marks the unit's current tile as solid/blocked in the shared AStar grid
	if astar_grid:
		astar_grid.set_point_solid(grid_pos, is_occupied)


func teleport_to_grid_pos(new_grid_pos: Vector2i):
	set_grid_occupancy(false)
	grid_pos = new_grid_pos
	set_grid_occupancy(true)


# --- Turn Logic ---
func start_new_turn():
	# Reset movement points; this function is typically overridden in subclasses
	remaining_movement = movement_range
	has_attacked = false


# Checks if another unit is in melee range (adjacent or diagonal)
func is_adjacent_to(other_unit: Unit) -> bool:
	var diff = (grid_pos - other_unit.grid_pos).abs()
	# In a grid, if both X and Y differences are <= 1, they are adjacent
	return diff.x <= 1 and diff.y <= 1


# --- Hook Functions (Subclass Overrides) ---
func on_movement_start_logic():
	# Placeholder for logic triggered when the unit begins moving
	pass


func on_movement_finished_logic():
	# Placeholder for logic triggered when the unit stops moving
	pass
