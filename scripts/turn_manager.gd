extends Node

# --- Signals  ---
signal turn_mode_changed(is_combat: bool)
signal active_unit_changed(unit: Unit)
signal combat_queue_updated

# --- State ---
enum State { EXPLORATION, COMBAT }

var current_state = State.EXPLORATION
var round_count: int = 1
var combat_queue: Array[Unit] = []
var active_unit_index: int = 0
var is_game_over: bool = false
var _exploration_round_backup: int = 1


# --- Lifecycle ---
func _ready() -> void:
	await get_tree().process_frame
	GameEvents.log_requested.emit("--- Exploration Round 1 Started ---")


# --- Exploration Logic ---
func end_exploration_turn() -> void:
	if current_state != State.EXPLORATION: return
	round_count += 1
	GameEvents.log_requested.emit("--- Exploration Round %s Started ---" % round_count)
	var players = get_tree().get_nodes_in_group("players")
	if not players.is_empty():
		active_unit_changed.emit(players[0])


# --- Combat Logic ---
## Starts combat with a specific list of enemies
func start_combat(triggered_enemies: Array[Unit], starter: Unit) -> void:
	if current_state == State.COMBAT: return # already in combat
	
	# Check if there are any VALID players left before starting
	var living_players = get_tree().get_nodes_in_group("players")
	if living_players.is_empty(): return
	_exploration_round_backup = round_count
	current_state = State.COMBAT
	round_count = 1
	GameEvents.log_requested.emit("--- Combat Round %s ---" % round_count)
	GameEvents.log_requested.emit("!!! %s spotted you! Starting combat !!!" % starter.display_name)
	# Collect all participants
	var participants: Array[Unit] = []
	for node in living_players:
		participants.append(node as Unit)
	for enemy in triggered_enemies:
		participants.append(enemy as Unit)
		if enemy != starter:
			GameEvents.log_requested.emit("%s was alarmed by %s!" % [enemy.display_name, starter.display_name])
	_roll_initiative(participants)
	combat_queue = participants
	active_unit_index = 0
	turn_mode_changed.emit(true)
	_start_active_unit_turn()


func _roll_initiative(units: Array[Unit]) -> void:
	# Calculate Initiative: Bonus + d20 roll
	for unit in units:
		var bonus = unit.data.get_initiative_bonus() if unit.data else 0
		unit.current_initiative_score = Dice.roll(1, 20, bonus)
		GameEvents.log_requested.emit("> %s rolled %s for initiative" % [unit.display_name, unit.current_initiative_score])
	units.sort_custom(func(a, b): return a.current_initiative_score > b.current_initiative_score)
	# Announce the unit that goes first
	if not units.is_empty():
		GameEvents.log_requested.emit("!!! %s takes the lead! !!!" % units[0].display_name)


func _start_active_unit_turn() -> void:
	# Security check: skip dead objects that might still be in queue
	while active_unit_index < combat_queue.size() and not is_instance_valid(combat_queue[active_unit_index]):
		combat_queue.remove_at(active_unit_index)
	if combat_queue.is_empty():
		end_combat()
		return	
	var current_unit = combat_queue[active_unit_index]
	# Ensure only the active unit has the 'is_active_unit' flag
	for unit in combat_queue:
		if is_instance_valid(unit):
			unit.is_active_unit = (unit == current_unit)
	# Notify UI which unit is currently taking its turn
	active_unit_changed.emit(current_unit)
	GameEvents.log_requested.emit(">>> %s's Turn <<<" % current_unit.display_name)
	current_unit.start_new_turn()


func next_combat_turn() -> void:
	# If combat ended during the last action (e.g. death), stop here
	if current_state != State.COMBAT: return
	active_unit_index += 1
	# If we reach the end of the queue, start a new round
	if active_unit_index >= combat_queue.size():
		active_unit_index = 0
		round_count += 1
		GameEvents.log_requested.emit("--- Combat Round %s ---" % round_count)
	_start_active_unit_turn()


func end_combat() -> void:
	# Log victory stats before resetting combat data
	if not is_game_over:
		var living_players = combat_queue.filter(func(u): return u.is_in_group("players"))
		if not living_players.is_empty():
			GameEvents.log_requested.emit("--- VICTORY ---")
			GameEvents.log_requested.emit("The battle ended after %d rounds." % round_count)
	current_state = State.EXPLORATION
	round_count = _exploration_round_backup
	combat_queue.clear()
	# Notify UI to hide combat-specific elements
	turn_mode_changed.emit(false)
	if not is_game_over:
		var players = get_tree().get_nodes_in_group("players")
		if not players.is_empty() and players[0].is_visible:
			GameEvents.log_requested.emit("--- Back to Exploration (Round %s) ---" % round_count)


# --- Unit Management ---
## Removes a unit from combat (e.g., when it dies)
func remove_unit_from_combat(unit: Unit) -> void:
	var index = combat_queue.find(unit)
	if index != -1:
		combat_queue.remove_at(index)
		combat_queue_updated.emit()
		# If the deleted unit was BEFORE or IS the current active unit, 
		# we must adjust the index so we don't skip anyone
		if index <= active_unit_index and active_unit_index > 0:
			active_unit_index -= 1
	_check_combat_end_conditions()


func _check_combat_end_conditions() -> void:	
	# Check if any players are left
	var players = combat_queue.filter(func(u): return u.is_in_group("players"))
	if players.is_empty():
		_trigger_game_over()
		return
	# If no enemies are left, end combat
	var enemies = combat_queue.filter(func(u): return u.is_in_group("enemies"))
	if enemies.is_empty():
		end_combat()


func _trigger_game_over():
	is_game_over = true
	GameEvents.log_requested.emit("--- GAME OVER ---")
	GameEvents.log_requested.emit("The hero has fallen. Time for a new character sheet...")
	# Later: Show a UI Screen. For now, we stop the game.
	end_combat()
