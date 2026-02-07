extends Unit

#@export var data: UnitData # Reference to the .tres resource file containing unit stats

# --- Misc ---
var detection_timer: float = 0.0
var detection_interval: float = 0.3
var current_sight_range: int = 0


func _process(delta):
	# only check during exploration
	if TurnManager.current_state == TurnManager.State.EXPLORATION:
		detection_timer += delta
		if detection_timer >= detection_interval:
			detection_timer = 0.0
			_check_for_player_exploration()


func _ready():
	super._ready()
	# Transfer data from Resource to Unit logic
	if data:
		#self.texture = data.texture
		#self.movement_range = data.movement_range
		#self.initiative_bonus = data.initiative_bonus
		current_sight_range = data.sight_range
	add_to_group("enemies")


func _check_for_player_exploration():
	var players = get_tree().get_nodes_in_group("players")
	if players.is_empty(): return
	var player = players[0]
	# calculate distance
	var diff = (player.grid_pos - grid_pos).abs()
	var dist = max(diff.x, diff.y)
	if dist <= current_sight_range:
		# check if LOS is clear
		if map_manager.is_line_of_sight_clear(grid_pos, player.grid_pos):
			_trigger_combat_neighborhood()


func _trigger_combat_neighborhood():
	var triggered_enemies: Array[Unit] = []
	var alert_radius = 3
	var all_enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in all_enemies:
		var d = (enemy.grid_pos - grid_pos).abs()
		if max(d.x, d.y) <= alert_radius:
			triggered_enemies.append(enemy)
	TurnManager.start_combat(triggered_enemies, self)


func _ai_logic():
	# Find potential targets
	var players = get_tree().get_nodes_in_group("players")
	if players.is_empty():
		_end_turn()
		return
		
	var target_player = players[0]
	
	# Check if already in range to attack before moving
	if is_adjacent_to(target_player):
		attack_target(target_player)
		_end_turn()
		return
	
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
		print(self.name, " cannot move or is already at the destination.")
		_end_turn()


func _end_turn():
	is_active_unit = false
	# Small delay before switching turns for better visual pacing
	await get_tree().create_timer(0.5).timeout
	TurnManager.next_combat_turn()


func start_new_turn():
	super.start_new_turn()
	print(self.name, " is thinking...")
	# Artificial delay to simulate "thinking" time
	await get_tree().create_timer(1.5).timeout
	_ai_logic()


func on_movement_finished_logic():
	# Only proceed with combat flow if we are in combat state
	if TurnManager.current_state == TurnManager.State.COMBAT:
		# Check for attack after movement finishes
		var players = get_tree().get_nodes_in_group("players")
		if not players.is_empty():
			var target_player = players[0]
			if is_adjacent_to(target_player):
				attack_target(target_player)
		_end_turn()
