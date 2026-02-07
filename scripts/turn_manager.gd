extends Node

# --- Signals for UI Interaction ---
signal turn_mode_changed(is_combat: bool)
signal active_unit_changed(unit: Unit)

# --- State Definitions ---
enum State { EXPLORATION, COMBAT }

var current_state = State.EXPLORATION
var round_count: int = 1
var combat_queue: Array[Unit] = []
var active_unit_index: int = 0


# --- Exploration Logic ---
func end_exploration_turn():
	round_count += 1
	GameEvents.log_requested.emit("--- Round %s Started ---" % round_count)


# --- Combat Logic ---
## Starts combat with a specific list of enemies
func start_combat(triggered_enemies: Array[Unit], starter: Unit):
	# Check if there are any VALID players left before starting
	var living_players = get_tree().get_nodes_in_group("players")
	if living_players.is_empty():
		return
	if current_state == State.COMBAT: return # already in combat
	
	current_state = State.COMBAT
	GameEvents.log_requested.emit("!!! %s spotted you! Starting combat !!!" % starter.display_name)
	var participants: Array[Unit] = []
	
	for node in get_tree().get_nodes_in_group("players"):
		participants.append(node as Unit)
	for enemy in triggered_enemies:
		participants.append(enemy as Unit)
		if enemy != starter:
			GameEvents.log_requested.emit("%s was alarmed by %s!" % [enemy.display_name, starter.display_name])
	
	# Calculate Initiative: Bonus + d20 roll
	for unit in participants:
		if unit.data:
			unit.current_initiative_score = Dice.roll(1, 20, unit.data.get_initiative_bonus())
			GameEvents.log_requested.emit("> %s rolled %s for initiative" % [unit.display_name, unit.current_initiative_score])
		else:
			unit.current_initiative_score = Dice.roll(1, 20, 0)
			GameEvents.log_requested.emit("> %s rolled %s for initiative" % [unit.display_name, unit.current_initiative_score])
	
	# Sort participants by initiative score (highest first)
	participants.sort_custom(func(a, b): 
		return a.current_initiative_score > b.current_initiative_score
	)
	
	combat_queue = participants
	active_unit_index = 0
	
	# Notify UI that combat has started
	turn_mode_changed.emit(true)
	_start_active_unit_turn()


func _start_active_unit_turn():
	# Security check: skip dead objects that might still be in queue
	while active_unit_index < combat_queue.size() and not is_instance_valid(combat_queue[active_unit_index]):
		combat_queue.remove_at(active_unit_index)
	if combat_queue.is_empty():
		end_combat()
		return	
	
	var current_unit = combat_queue[active_unit_index]
	
	# Ensure only the active unit has the 'is_active_unit' flag
	for unit in combat_queue:
		unit.is_active_unit = false
	
	current_unit.is_active_unit = true
	
	# Notify UI which unit is currently taking its turn
	active_unit_changed.emit(current_unit)
	
	current_unit.start_new_turn()


func next_combat_turn():
	# If combat ended during the last action (e.g. death), stop here
	if current_state == State.EXPLORATION:
		return
	active_unit_index += 1
	
	# If we reach the end of the queue, start a new round
	if active_unit_index >= combat_queue.size():
		active_unit_index = 0
		round_count += 1
		GameEvents.log_requested.emit("--- Combat Round %s ---" % round_count)
	
	_start_active_unit_turn()


func end_combat():
	current_state = State.EXPLORATION
	round_count = 0
	combat_queue.clear()
	
	# Notify UI to hide combat-specific elements
	turn_mode_changed.emit(false)


## Removes a unit from combat (e.g., when it dies)
func remove_unit_from_combat(unit: Unit):
	var index = combat_queue.find(unit)
	if index != -1:
		combat_queue.remove_at(index)
		# If the deleted unit was BEFORE or IS the current active unit, 
		# we must adjust the index so we don't skip anyone
		if index <= active_unit_index and active_unit_index > 0:
			active_unit_index -= 1
	# Check if any players are left
	var players = combat_queue.filter(func(u): return u.is_in_group("players"))
	if players.is_empty():
		trigger_game_over()
		return
	# If no enemies are left, end combat
	var enemies = combat_queue.filter(func(u): return u.is_in_group("enemies"))
	if enemies.is_empty():
		end_combat()


func trigger_game_over():
	GameEvents.log_requested.emit("--- GAME OVER ---")
	GameEvents.log_requested.emit("The hero has fallen. Time for a new character sheet...")
	# Later: Show a UI Screen. For now, we stop the game.
	end_combat()
