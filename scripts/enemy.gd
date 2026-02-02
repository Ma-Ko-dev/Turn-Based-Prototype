extends Unit

@export var data: UnitData # Reference to the .tres resource file containing unit stats


func _ready():
	# Transfer data from Resource to Unit logic
	if data:
		self.texture = data.texture
		self.movement_range = data.movement_range
		self.initiative_bonus = data.initiative_bonus
	
	super._ready()
	add_to_group("enemies")


func start_new_turn():
	super.start_new_turn()
	print(data.name, " is thinking...")
	# Artificial delay to simulate "thinking" time
	await get_tree().create_timer(1.0).timeout
	_ai_logic()


func _ai_logic():
	# Find potential targets
	var players = get_tree().get_nodes_in_group("players")
	if players.is_empty():
		_end_turn()
		return
		
	var target_player = players[0]
	
	# Define adjacent tiles (Up, Down, Left, Right)
	# Note: Diagonals are currently excluded to prevent "squeezing" through corners
	var neighbors = [
		target_player.grid_pos + Vector2i.UP,
		target_player.grid_pos + Vector2i.DOWN,
		target_player.grid_pos + Vector2i.LEFT,
		target_player.grid_pos + Vector2i.RIGHT
	]
	
	var best_target = grid_pos # Default to staying put
	var min_dist = 9999
	
	# Search for the best reachable neighboring tile to the player
	for n in neighbors:
		# Check if tile is within map bounds and not blocked by other units
		if astar_grid.is_in_bounds(n.x, n.y) and not astar_grid.is_point_solid(n):
			# Use squared length for efficient distance comparison
			var d = (grid_pos - n).length_squared()
			if d < min_dist:
				min_dist = d
				best_target = n
	
	# Calculate path to the chosen neighbor tile
	var result = get_path_and_cost(best_target)
	var path = result["path"]
	var cost = result["cost"]
	
	if path.size() > 1:
		# If the target is further than the available movement, trim the path
		if cost > remaining_movement:
			path = path.slice(0, remaining_movement + 1)
			cost = remaining_movement
		
		execute_movement(path, cost)
	else:
		# Log if already in range or completely blocked
		print(data.name, " cannot move or is already at the destination.")
		_end_turn()


func on_movement_finished_logic():
	# Only proceed with combat flow if we are in combat state
	if TurnManager.current_state == TurnManager.State.COMBAT:
		_end_turn()


func _end_turn():
	is_active_unit = false
	# Small delay before switching turns for better visual pacing
	await get_tree().create_timer(0.5).timeout
	TurnManager.next_combat_turn()
