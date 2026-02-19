extends Sprite2D
class_name Unit


#region --- Signals ---
signal hp_changed
signal movement_changed(new_amount: int)
#endregion
#region --- Variables: Data & Scenes ---
@export var data: UnitData
@export var damage_text_scene: PackedScene
#endregion
#region --- Variables: State (Grid & Position)
var grid_pos: Vector2i: 
	set(value):
		grid_pos = value
		# Synchronize pixel position with grid coordinates whenever grid_pos changes
		position = Vector2(grid_pos) * grid_size + Vector2(grid_size / 2.0, grid_size / 2.0)
var grid_size: float:
	get:
		return map_manager.grid_size
#endregion
#region --- Variables: State (Stats & Status)
var remaining_movement: int = 0:
	set(value):
		remaining_movement = value
		movement_changed.emit(remaining_movement)
var display_name: String = ""
var current_health: int
var current_initiative_score: int = 0
var is_moving: bool = false
var is_selected: bool = false
var is_active_unit: bool = false
var has_attacked: bool = false
#endregion
#region --- Variables: References ---
var astar_grid: AStarGrid2D:
	get:
		return map_manager.astar_grid
var map_manager: MapManager
#endregion
#region --- Variables: Computed Stats (Getters) ---
## Returns the maximum health points, pulled live from UnitData.
var max_health: int:
	get: return data.get_max_hp() if data else 10
## Returns the current movement range, influenced by encumbrance, from UnitData.
var movement_range: int:
	get: return data.get_current_movement_range() if data else 6
#endregion

# --- LOGIC SECTOR ---

#region --- Logic: Lifecycle & Initialization ---
## Initializes the unit, connects data signals, and sets initial grid position.
func _ready() -> void:
	if not map_manager:
		await get_tree().process_frame
	_initialize_inventory()
	if data:
		data.data_updated.connect(_on_data_updated)
	_initialize_stats()
	if map_manager:
		# Calculate initial grid position based on the starting world position in the editor
		# Wait for a frame to ensure MapManager has initialized the AStar grid before occupying a cell
		await get_tree().process_frame
		_set_grid_occupancy(true)

## Sets initial display values and fills health/movement to their maximums.
func _initialize_stats() -> void:
	if not data: return
	if display_name == "":
		display_name = data.name
	texture = data.texture
	#max_health = data.calculate_initial_hp()
	current_health = max_health
	remaining_movement = movement_range

## Creates a unique duplicate of the UnitData to allow individual equipment tracking.
func _initialize_inventory() -> void:
	if not data: return
	data = data.duplicate(true)
	data.initialize_inventory()
#endregion
#region --- Logic: Signal Handlers ---
## Reacts to changes in UnitData (e.g., weight changes) and updates stats accordingly.
func _on_data_updated() -> void:
	if not data: return
	hp_changed.emit()
	if TurnManager.current_state == TurnManager.State.EXPLORATION or is_active_unit:
		remaining_movement = min(remaining_movement, movement_range)
#endregion
#region --- Logic: Combat & Damage ---
## Performs an attack on a target unit including animations, hit rolls, and critical logic.
func attack_target(target: Unit) -> void:
	if has_attacked:
		GameEvents.log_requested.emit("%s has no actions left!" % display_name)
		return
	# Start the visual bump animation before calculating results
	await  _play_attack_animation(target.position)
	var weapon = data.get_item_by_slot_type(ItemData.EquipmentSlot.MAIN_HAND) as WeaponData
	var attack_bonus = data.get_attack_bonus()
	var total_roll = Dice.roll(1, 20, attack_bonus)
	var raw_roll = total_roll - attack_bonus # we do it that way to keep the nat20/1 logic working and also keep the dice roll debug accurate
	var target_ac = target.data.get_armor_class() if target.data else 10
	var crit_threshold = weapon.critical_range if weapon else 20
	GameEvents.log_requested.emit("%s attacks %s!" % [display_name, target.display_name])	
	# Pathfinder Rules: Natural 20 is always a hit, Natural 1 is always a miss
	if raw_roll >= 20:
		GameEvents.log_requested.emit("CRITICAL HIT! (Nat 20 vs AC %d)" % target_ac)
		_apply_damage(target, true)
	elif raw_roll <= 1:
		GameEvents.log_requested.emit("CRITICAL MISS! (Nat 1 vs AC %d)" % target_ac)
	elif total_roll >= target_ac:
		if raw_roll >= crit_threshold:
			GameEvents.log_requested.emit("CRITICAL HIT! (%d is in range)" % raw_roll)
			_apply_damage(target, true)
		else:
			GameEvents.log_requested.emit("HIT! (%d + %d = %d vs AC %d)" % [raw_roll, attack_bonus, total_roll, target_ac])
			_apply_damage(target, false)
	else:
		GameEvents.log_requested.emit("MISS! (%d + %d = %d vs AC %d)" % [raw_roll, attack_bonus, total_roll, target_ac])
	has_attacked = true

## Reduces health, handles damage resistance, and triggers death if HP <= 0.
func take_damage(amount: int, is_crit: bool = false, type: int = -1) -> void:
	var final_damage = amount
	var reduction = 0
	if type != -1:
			reduction = data.get_dr_for_type(type)
			final_damage -= reduction
			if reduction > 0:
				GameEvents.log_requested.emit("%s resists %d damage!" % [display_name, reduction])
	final_damage = max(0, final_damage) # Ensure damage doesn't become healing
	current_health -= final_damage
	# Emit signal so UI/Tracker can react
	hp_changed.emit()
	# Play the hit feedback
	_play_hit_animation()
	if damage_text_scene:
		var dmg_text = damage_text_scene.instantiate()
		# Add to the level, not the unit, so it doesn't move with the unit
		get_parent().add_child(dmg_text)
		dmg_text.global_position = global_position + Vector2(0, -20)
		dmg_text.setup(amount, is_crit)
	GameEvents.log_requested.emit("%s takes %s damage! (HP: %s/%s)" % [display_name, final_damage, current_health, max_health])
	if current_health <= 0:
		_award_xp_to_player()
		_die()

## Helper: Calculates damage based on weapon data and modifiers, then applies it to the target.
func _apply_damage(target: Unit, is_crit: bool) -> void:
	var weapon = data.get_item_by_slot_type(ItemData.EquipmentSlot.MAIN_HAND) as WeaponData
	var modifier = data.get_modifier(data.strength)
	var dmg_stats = data.get_damage_data()
	var damage = Dice.roll(dmg_stats.count, dmg_stats.sides, modifier)
	var dmg_type = weapon.damage_type if weapon else -1
	# Use weapon's crit multiplier if it exists, otherwise default to 2
	var crit_mult = weapon.critical_multiplier if weapon else 2
	if is_crit: damage *= crit_mult
	target.take_damage(max(1, damage), is_crit, dmg_type)

## Handles cleanup, XP distribution, and removal from combat or the scene.
func _die() -> void:
	GameEvents.log_requested.emit("!!! %s has been defeated !!!" % display_name)
	_set_grid_occupancy(false)
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
#endregion
#region --- Logic: Pathfinding & Movement ---
## Calculates a path and its total movement cost to a target cell using AStar.
func get_path_and_cost(target_cell: Vector2i) -> Dictionary:
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

## Animates the unit along a path and updates its grid position and remaining movement.
func execute_movement(path: Array[Vector2i], cost: float) -> void:
	# Cancel if the path is invalid or too short
	if path.size() <= 1 or cost > remaining_movement:
		is_moving = false
		_on_movement_finished_logic()
		return
	# Unmark the old cell as occupied so other units could potentially pass through
	_set_grid_occupancy(false)
	is_moving = true
	_on_movement_start_logic()
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
	_set_grid_occupancy(true)
	# Trigger post-movement logic (handled in Player/Enemy subclasses)
	_on_movement_finished_logic()
#endregion
#region --- Logic: Visuals & Animations ---
## Plays a procedural lunge animation towards the target position.
func _play_attack_animation(target_pos: Vector2) -> void:
	#Calculate half distance to target for the "bump"
	var strike_pos = position + (target_pos - position) * 0.4
	var original_pos = position
	var tween = create_tween()
	# Fast lunge forward
	tween.tween_property(self, "position", strike_pos, 0.1).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	await tween.finished
	# Snap back to original position
	var return_tween = create_tween()
	return_tween.tween_property(self, "position", original_pos, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

## Plays a visual feedback effect (red flash and shake) when the unit is hit.
func _play_hit_animation() -> void:
	# Create a shake and flash effect
	var tween = create_tween()
	tween.set_parallel(true)
	# Flash red
	modulate = Color.RED
	tween.tween_property(self, "modulate", Color.WHITE, 0.2)
	# Shake effect using offset to not interfere with grid position
	var shake_tween = create_tween()
	for i in range(4):
		var shake_offset = Vector2(randf_range(-5, 5), randf_range(-5, 5))
		shake_tween.tween_property(self, "offset", shake_offset, 0.05)
	# Reset offset
	shake_tween.tween_property(self, "offset", Vector2.ZERO, 0.05)
#endregion
#region --- Logic: Grid Helpers ---
## Toggles whether the unit's current grid cell is considered "solid" for AStar.
func _set_grid_occupancy(is_occupied: bool) -> void:
	# Marks the unit's current tile as solid/blocked in the shared AStar grid
	if astar_grid:
		astar_grid.set_point_solid(grid_pos, is_occupied)

## Returns true if the other unit is in any of the 8 surrounding tiles.
func is_adjacent_to(other_unit: Unit) -> bool:
	var diff = (grid_pos - other_unit.grid_pos).abs()
	# In a grid, if both X and Y differences are <= 1, they are adjacent
	return diff.x <= 1 and diff.y <= 1

## Instantly moves the unit to a new grid cell and updates occupancy.
func teleport_to_grid_pos(new_grid_pos: Vector2i) -> void:
	_set_grid_occupancy(false)
	grid_pos = new_grid_pos
	_set_grid_occupancy(true)
#endregion
#region --- Logic: Turn Management & Hooks ---
## Resets movement and attack status at the beginning of the unit's turn.
func start_new_turn() -> void:
	# Reset movement points; this function is typically overridden in subclasses
	remaining_movement = data.get_current_movement_range()
	has_attacked = false

## Virtual hook called just before a unit begins its movement animation.
func _on_movement_start_logic() -> void:
	# Placeholder for logic triggered when the unit begins moving
	pass

## Virtual hook called after a unit has finished moving.
func _on_movement_finished_logic() -> void:
	# Placeholder for logic triggered when the unit stops moving
	pass
#endregion
#region --- Logic: Progression ---
## Calculates and distributes XP to all players when this unit (enemy) dies.
func _award_xp_to_player() -> void:
	# Only non-players (enemies) should award XP when they die
	if is_in_group("players") or not data:
		return
	var xp_to_give = data.xp_reward
	var players = get_tree().get_nodes_in_group("players")
	if players.size() > 0:
		for player in players:
			if player is Unit and player.data:
				var leveled_up = player.data.add_xp(xp_to_give)
				GameEvents.log_requested.emit("%s gains %d XP!" % [player.display_name, xp_to_give])
				if leveled_up:
					GameEvents.log_requested.emit("LEVEL UP! %s is now Level %d!" % [player.display_name, player.data.level])
#endregion
