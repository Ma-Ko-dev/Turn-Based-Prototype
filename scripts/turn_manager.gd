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
	# This will be perfect for the Combat Log tomorrow!
	print("Exploration round ended. New round: ", round_count)


# --- Combat Logic ---
## Starts combat with a specific list of enemies
func start_combat(triggered_enemies: Array[Unit], starter: Unit):
	if current_state == State.COMBAT: return # already in combat
	
	current_state = State.COMBAT
	# later in UI
	print(starter.name, " spotted you! Starting combat...")
	var participants: Array[Unit] = []
	
	for node in get_tree().get_nodes_in_group("players"):
		participants.append(node as Unit)
	for enemy in triggered_enemies:
		participants.append(enemy as Unit)
		if enemy != starter:
			print(enemy.name, " was alarmed by ", starter.name, "!")
	
	# Calculate Initiative: Bonus + d20 roll
	for unit in participants:
		unit.current_initiative_score = unit.initiative_bonus + randi_range(1, 20)
	
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
	var current_unit = combat_queue[active_unit_index]
	
	# Ensure only the active unit has the 'is_active_unit' flag
	for unit in combat_queue:
		unit.is_active_unit = false
	
	current_unit.is_active_unit = true
	
	# Notify UI which unit is currently taking its turn
	active_unit_changed.emit(current_unit)
	
	current_unit.start_new_turn()
	#print("Currently active: ", current_unit.name)


func next_combat_turn():
	active_unit_index += 1
	
	# If we reach the end of the queue, start a new round
	if active_unit_index >= combat_queue.size():
		active_unit_index = 0
		round_count += 1
		print("New Combat Round: ", round_count)
	
	_start_active_unit_turn()


func end_combat():
	current_state = State.EXPLORATION
	round_count = 0
	combat_queue.clear()
	
	# Notify UI to hide combat-specific elements
	turn_mode_changed.emit(false)
