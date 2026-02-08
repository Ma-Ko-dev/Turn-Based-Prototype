extends Unit

# --- Misc ---
var _detection_timer: float = 0.0
var _detection_interval: float = 0.3
var _current_sight_range: int = 0


# --- Lifecycle ---
func _ready() -> void:
	super._ready()
	add_to_group("enemies")
	# Transfer data from Resource to Unit logic
	if data:
		_current_sight_range = data.sight_range


func _process(delta: float) -> void:
	# only check during exploration
	if TurnManager.current_state == TurnManager.State.EXPLORATION:
		_detection_timer += delta
		if _detection_timer >= _detection_interval:
			_detection_timer = 0.0
			_check_for_player_exploration()


# --- Detection Logic ---
func _check_for_player_exploration() -> void:
	var players = get_tree().get_nodes_in_group("players")
	if players.is_empty(): return
	var player = players[0]
	# calculate distance
	var diff = (player.grid_pos - grid_pos).abs()
	var dist = max(diff.x, diff.y)
	if dist <= _current_sight_range:
		# check if LOS is clear
		if map_manager.is_line_of_sight_clear(grid_pos, player.grid_pos):
			_trigger_combat_neighborhood()


func _trigger_combat_neighborhood() -> void:
	var triggered_enemies: Array[Unit] = []
	var alert_radius = 3
	var all_enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in all_enemies:
		var d = (enemy.grid_pos - grid_pos).abs()
		if max(d.x, d.y) <= alert_radius:
			triggered_enemies.append(enemy)
	TurnManager.start_combat(triggered_enemies, self)


# --- AI Turn Logic ---
func start_new_turn() -> void:
	super.start_new_turn()
	print(self.name, " is thinking...")
	# Artificial delay to simulate "thinking" time
	await get_tree().create_timer(1.5).timeout
	#_ai_logic()
	_execute_ai_behaviour()


func _execute_ai_behaviour() -> void:
	# Find potential targets
	var players = get_tree().get_nodes_in_group("players")
	if players.is_empty():
		_finish_turn()
		return
	var target_player = players[0]
	# Check if already in range to attack before moving
	if is_adjacent_to(target_player):
		attack_target(target_player)
		_finish_turn()
		return
	var best_tile = _find_best_attack_position(target_player)
	var result = get_path_and_cost(best_tile)
	var path = result["path"]
	var cost = result["cost"]
	if path.size() > 1:
		# Trim path if it exceeds movement range
		if cost > remaining_movement:
			path = path.slide(0, remaining_movement + 1)
			cost = remaining_movement
		execute_movement(path, cost)
	else:
		# Cannot move or no path found
		_finish_turn()


func _find_best_attack_position(target: Unit) -> Vector2i:
	var neighbors = [
		target.grid_pos + Vector2i.UP,
		target.grid_pos + Vector2i.DOWN,
		target.grid_pos + Vector2i.LEFT,
		target.grid_pos + Vector2i.RIGHT
	]
	var best_tile = grid_pos
	var min_dist = 9999.0
	for n in neighbors:
		if astar_grid.is_in_boundsv(n) and not astar_grid.is_point_solid(n):
			var d = Vector2(grid_pos).distance_to(Vector2(n))
			if d < min_dist:
				min_dist = d
				best_tile = n
	return best_tile


func _finish_turn() -> void:
	is_active_unit = false
	await get_tree().create_timer(0.5).timeout
	TurnManager.next_combat_turn()


# --- Overridden Hooks ---
func _on_movement_finished_logic() -> void:
	# Only proceed with combat flow if we are in combat state
	if TurnManager.current_state == TurnManager.State.COMBAT:
		# Check for attack after movement finishes
		var players = get_tree().get_nodes_in_group("players")
		if not players.is_empty():
			var target_player = players[0]
			if is_adjacent_to(target_player):
				attack_target(target_player)
		_finish_turn()
