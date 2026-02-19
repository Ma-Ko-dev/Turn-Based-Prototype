extends Resource
class_name UnitData

# --- Signal ---
# Notify UI to refresh everything
signal data_updated

#region --- ENUMS ---
enum Alignment {
	LAWFUL_GOOD, NEUTRAL_GOOD, CHAOTIC_GOOD,
	LAWFUL_NEUTRAL, TRUE_NEUTRAL, CHAOTIC_NEUTRAL,
	LAWFUL_EVIL, NEUTRAL_EVIL, CHAOTIC_EVIL
}
enum Size { FINE, DIMINUTIVE, TINY, SMALL, MEDIUM, LARGE, HUGE, GARGANTUAN, COLOSSAL }
enum UnitType { HUMANOID, UNDEAD, CONSTRUCT, ELEMENTAL, BEAST }
enum Encumbrance { LIGHT, MEDIUM, HEAVY, OVERLOADED }
#endregion
#region --- Variables: Identity ---
@export_group("Identity")
@export var name: String = "Unknown Unit"
@export var size: Size = Size.MEDIUM
@export var unit_type: UnitType = UnitType.HUMANOID
@export var alignment: Alignment = Alignment.TRUE_NEUTRAL
@export var texture: Texture2D
#endregion
#region --- Variables: Progression ---
@export_group("Progression")
@export var level: int = 1
@export var current_xp: int = 0
@export var xp_reward: int = 100
@export var threat_rating: float = 1.0
@export var is_player_data: bool = false
#endregion
#region --- Variables: Stats ---
@export_group("Stats")
@export var hp_dice_count: int = 1
@export var hp_dice_sides: int = 10
@export var flat_hp_bonus: int = 0
@export var movement_range: int = 10
@export var sight_range: int = 12
var extra_initiative_bonus: int = 0
#endregion
#region --- Variables: Combat Stats ---
@export_group("Combat Stats")
var _generated_max_hp: int = 0
@export var base_attack_bonus: int = 0
@export var base_fortitude: int = 0
@export var base_reflex: int = 0
@export var base_will: int = 0
@export var damage_dice_count: int = 1
@export var damage_dice_sides: int = 3
@export var resistances: Array[ResistanceEntry] = []
#endregion
#region --- Variables: Attributes ---
@export_group("Attributes")
@export_range(1, 30) var strength: int = 10
@export_range(1, 30) var dexterity: int = 10
@export_range(1, 30) var constitution: int = 10
@export_range(1, 30) var intelligence: int = 10
@export_range(1, 30) var wisdom: int = 10
@export_range(1, 30) var charisma: int = 10
#endregion
#region --- Variables: AC Bonusses ---
@export_group("AC Bonus")
@export var armor_bonus: int = 0 # from actual armor
@export var shield_bonus: int = 0
@export var natural_armor: int = 0
#endregion
#region --- Variables: Equipment & Inventory Slots ---
@export_group("Starting Equipment")
@export var starting_items: Array[ItemData] = []
var equipped_gear: Dictionary = {}
var inventory_items: Array[ItemData] = []
#endregion


# --- LOGIC SECTOR ---
#region --- Logic: Math Helpfers ---
## Returns the attribute modifier based on a score (e.g., 10 -> 0, 12 -> +1)
func get_modifier(score: int) -> int:
	return int(floor((score - 10) /  2.0))
## Returns the AC and Attack modifier based on unit size.
func get_size_modifier() -> int:
	match size:
		Size.FINE: return 8
		Size.DIMINUTIVE: return 4
		Size.TINY: return 2
		Size.SMALL: return 1
		Size.LARGE: return -1
		Size.HUGE: return -2
		Size.GARGANTUAN: return -4
		Size.COLOSSAL: return -8
		_: return 0 # Medium
#endregion
#region --- Logic: HP & Defense ---
## Calculates the starting HP based on hit dice and constitution.
func calculate_initial_hp() -> int:
	var con_mod = get_modifier(constitution)
	var base_hp = 0
	if is_player_data and level == 1:
		# Maximize the first hit die: (1 * sides) + con
		base_hp = hp_dice_sides + con_mod
	else:
		# Default roll for everyone else
		base_hp = Dice.roll(hp_dice_count, hp_dice_sides, con_mod)
	return max(1, base_hp + flat_hp_bonus)
## Returns the maximum health points for this unit.
func get_max_hp() -> int: 
	if _generated_max_hp <= 0:
		_generated_max_hp = calculate_initial_hp()
	return _generated_max_hp
## Returns the Damage Reduction (DR) for a specific damage type.
func get_dr_for_type(damage_type: int) -> int:
	for res in resistances:
		if res.type == damage_type:
			return res.amount
	return 0
## Calculates the total armor bonus from natural armor and equipped gear.
func get_armor_bonus() -> int:
	# Use armor item bonus if present, otherwise fallback to hardcoded natural/base bonus
	var bonus = natural_armor
	var armor = get_item_by_slot_type(ItemData.EquipmentSlot.BODY)
	if armor and armor is ArmorData: 
		bonus += armor.ac_bonus
	return bonus
## Returns the AC bonus from an equipped shield in the off-hand.
func get_shield_bonus() -> int:
	var off_hand = get_item_by_slot_type(ItemData.EquipmentSlot.OFF_HAND)
	if off_hand and off_hand is ArmorData: # Shields are ArmorData with slot_type OFF_HAND
		return off_hand.ac_bonus
	return 0
## Calculates the final Armor Class (10 + Dex + Armor + Shield + Size)
func get_armor_class() -> int: return 10 + get_clamped_dex_modifier() + get_armor_bonus() + get_shield_bonus() + get_size_modifier()
## Returns AC against touch attacks (ignores armor and shields)
func get_touch_ac() -> int: return 10 + get_modifier(dexterity) + get_size_modifier()
## Returns AC when caught flat-footed (ignores Dex bonus)
func get_flat_ac() -> int: return 10 + get_armor_bonus() + get_shield_bonus() + get_size_modifier()
## Calculates the Fortitude saving throw total
func get_fort_save() -> int: return base_fortitude + get_modifier(constitution)
## Calculates the Reflex saving throw total
func get_reflex_save() -> int: return base_reflex + get_modifier(dexterity)
## Calculates the Will saving throw total
func get_will_save() -> int: return base_will + get_modifier(wisdom)
#endregion
#region --- Logic: Combat & Offense ---
## Returns the initiative bonus (Dexterity + Misc bonuses)
func get_initiative_bonus() -> int: return get_modifier(dexterity) + extra_initiative_bonus
## Calculates the melee Attack Bonus (BAB + Str + Size)
func get_attack_bonus() -> int: return base_attack_bonus + get_modifier(strength) + get_size_modifier()
## Calculates the ranged Attack Bonus (BAB + Dex + Size)
func get_ranged_bonus() -> int: return base_attack_bonus + get_modifier(dexterity) + get_size_modifier()
## Returns the damage dice string (e.g., "1d8") based on weapon and size
func get_weapon_damage_dice() -> String:
	var main_hand = get_item_by_slot_type(ItemData.EquipmentSlot.MAIN_HAND)
	if main_hand:
		return main_hand.damage_medium if size >= Size.MEDIUM else main_hand.damage_small
		# Fallback to hardcoded stats if no weapon is equipped
	return "%dd%d" % [damage_dice_count, damage_dice_sides]
## Returns a dictionary with dice count and sides for damage calculations
func get_damage_data() -> Dictionary:
	var dice_string = get_weapon_damage_dice() #1d3 1d8 etc
	var parts = dice_string.split("d")
	return { "count": int(parts[0]), "sides": int(parts[1])}
## Returns the reach of the unit in feet (default 5ft)
func get_attack_reach() -> int:
	var main_hand = get_item_by_slot_type(ItemData.EquipmentSlot.MAIN_HAND)
	return main_hand.reach_ft if main_hand else 5
## Calculates the Combat Maneuver Bonus
func get_cmb() -> int: return base_attack_bonus + get_modifier(strength) - get_size_modifier()
## Calculates the Combat Maneuver Defense
func get_cmd() -> int: return 10 + base_attack_bonus + get_modifier(strength) + get_modifier(dexterity) - get_size_modifier()
#endregion
#region --- Logic: Inventory & Weight ---
## Calculates the maximum carrying capacity based on Strength and Size
func get_max_weight() -> float:
	var max_w = 0.0
	if strength <= 10:
		max_w = strength * 10
	else:
		# Every 5 points of STR triples the capacity (roughly)
		max_w = 100.0 * pow(4.0, (strength - 10.0) / 10.0)
	# Apply size multiplier
	var multiplier = 1.0
	match size:
		Size.SMALL: multiplier = 0.75
		Size.LARGE: multiplier = 2.0
	return max_w * multiplier
## Calculates the total weight of all carried and equipped items
func get_current_weight() -> float:
	var total = 0.0
	# Weight from equipped items
	for item in equipped_gear.values():
		if item:
			total += item.weight
	# Weight from backpack
	for item in inventory_items:
		if item:
			total += item.weight * item.amount
	return total
## Returns the encumbrance level based on current weight vs limit
func get_encumbrance_level() -> Encumbrance:
	var current = get_current_weight()
	var limit = get_max_weight()
	if current <= limit / 3.0:
		return Encumbrance.LIGHT
	elif current <= (limit * 2.0) / 3.0:
		return Encumbrance.MEDIUM
	elif current <= limit:
		return Encumbrance.HEAVY
	else:
		return Encumbrance.OVERLOADED
## Returns the effective encumbrance, considering both weight and armor type
func get_effective_encumbrance() -> Encumbrance:
	var weight_enc = get_encumbrance_level()
	var armor_enc = Encumbrance.LIGHT
	var body_armor = get_item_by_slot_type(ItemData.EquipmentSlot.BODY)
	if body_armor:
		if body_armor.armor_type == ArmorData.ArmorType.MEDIUM:
			armor_enc = Encumbrance.MEDIUM
		elif body_armor.armor_type == ArmorData.ArmorType.HEAVY:
			armor_enc = Encumbrance.HEAVY
	return max(weight_enc, armor_enc) as Encumbrance
## Returns the Dex modifier, limited by armor or heavy load
func get_clamped_dex_modifier() -> int:
	var dex_mod = get_modifier(dexterity)
	var effective = get_effective_encumbrance()
	var limit = 99
	var body_armor = get_item_by_slot_type(ItemData.EquipmentSlot.BODY)
	match effective:
		Encumbrance.MEDIUM: limit = 3
		Encumbrance.HEAVY: limit = 1
		Encumbrance.OVERLOADED: limit = -5 
	if body_armor and body_armor is ArmorData:
		# Return the smaller value: either actual dex or the armor's limit
		limit = min(limit, body_armor.max_dex_bonus)
	return min(dex_mod, limit)
## Calculates movement range after applying armor and weight penalties
func get_current_movement_range() -> int:
	var base_move = movement_range
	var armor_pen = 0
	var weight_pen = 0
	var body_armor = get_item_by_slot_type(ItemData.EquipmentSlot.BODY)
	if body_armor:
		armor_pen = body_armor.speed_penalty
	var load_status = get_encumbrance_level()
	match load_status:
		Encumbrance.MEDIUM, Encumbrance.HEAVY:
			weight_pen = 2
		Encumbrance.OVERLOADED:
			return 0
	var final_penalty = max(armor_pen, weight_pen)
	return max(1, base_move - final_penalty)
## Calculates the total Armor Check Penalty (ACP) from gear and load
func get_effective_acp() -> int:
	var armor_acp = 0
	var body_armor = get_item_by_slot_type(ItemData.EquipmentSlot.BODY)
	var off_hand = get_item_by_slot_type(ItemData.EquipmentSlot.OFF_HAND)
	if body_armor:
		armor_acp = abs(body_armor.armor_check_penalty)
	if off_hand is ArmorData:
		armor_acp += abs(off_hand.armor_check_penalty)
	var weight_acp = 0
	match get_encumbrance_level():
		Encumbrance.MEDIUM: weight_acp = 3
		Encumbrance.HEAVY: weight_acp = 6
	return -max(armor_acp, weight_acp)
#endregion
#region --- Logic: Item Management ---
## Initializes inventory and auto-equips starting items.
func initialize_inventory() -> void:
	_setup_gear_slots()
	inventory_items.clear()
	for starting_item in starting_items:
		if not starting_item: continue
		var item = starting_item.duplicate()
		var slotted = false
		# Try to equip the item if it has a valid equipment slot
		if item.slot_type != ItemData.EquipmentSlot.NONE:
			slotted = _auto_equip_item(item, false)
		# If it couldnt be equipped (slot full or no slot), put it in the backpack
		if not slotted:
			inventory_items.append(item)
	data_updated.emit()
## Internal: Removes all items from equipment slots
func _clear_equipment_slots() -> void:
	_setup_gear_slots()
## Internal: Attempts to put an item into its designated equipment slot
func _auto_equip_item(item: ItemData, emit: bool = true) -> bool:
	if item.slot_type == ItemData.EquipmentSlot.NONE:
		return false
	if item.slot_type == ItemData.EquipmentSlot.RING:
		if get_item_by_slot_type(ItemData.EquipmentSlot.RING) == null:
			_set_item_in_slot(ItemData.EquipmentSlot.RING, item, emit)
			return true
		return false
	if get_item_by_slot_type(item.slot_type) == null:
		_set_item_in_slot(item.slot_type, item)
		return true
	return false
func get_item_by_slot_type(slot_type: ItemData.EquipmentSlot) -> ItemData:
	return equipped_gear.get(slot_type, null)
## Removes an item from the backpack at the given index
func drop_item(index: int) -> void:
	if index < inventory_items.size():
		inventory_items.remove_at(index)
		data_updated.emit()
## Equips an item from the backpack and returns the old item to the inventory
func equip_item_from_backpack(item: ItemData, index: int) -> void:
	var old_item = get_item_by_slot_type(item.slot_type)
	inventory_items.remove_at(index)
	if old_item:
		inventory_items.insert(index, old_item)
	_set_item_in_slot(item.slot_type, item)
	data_updated.emit()
## Moves an equipped item back into the backpack
func unequip_slot(slot: ItemData.EquipmentSlot) -> void:
	var item = get_item_by_slot_type(slot)
	if item: 
		_set_item_in_slot(slot, null)
		inventory_items.append(item)
		data_updated.emit()
## Removes an equipped item from the unit entirely
func drop_equipped_item(slot: ItemData.EquipmentSlot) -> void:
	_set_item_in_slot(slot, null)
	data_updated.emit()
## Internal: Sets the reference for a specific equipment slot
func _set_item_in_slot(slot: ItemData.EquipmentSlot, item: ItemData, emit: bool = true) -> void:
	if equipped_gear.has(slot):
		equipped_gear[slot] = item
		if emit:
			data_updated.emit()
## Handles complex logic for moving items between slots and backpack via Drag & Drop
func handle_drag_drop(from_slot: ItemData.EquipmentSlot, from_idx: int, to_slot: ItemData.EquipmentSlot, to_idx: int) -> void:
	#  Case 1: Moving/Swapping within Backpack
	if from_slot == ItemData.EquipmentSlot.NONE and to_slot == ItemData.EquipmentSlot.NONE:
		if from_idx < inventory_items.size():
			var item_to_move = inventory_items[from_idx]
			if to_idx < inventory_items.size():
				#  Real swap (prevents item duplication/loss)
				var temp = inventory_items[to_idx]
				inventory_items[to_idx] = item_to_move
				inventory_items[from_idx] = temp
			else:
				# Moving to an empty slot at the end
				inventory_items.remove_at(from_idx)
				inventory_items.append(item_to_move)
	# Case 2: From Backpack to Equipment (Equip/Swap)
	elif from_slot == ItemData.EquipmentSlot.NONE and to_slot != ItemData.EquipmentSlot.NONE:
		equip_item_from_backpack(inventory_items[from_idx], from_idx)
		return # equip_item_from_backpack already emits
	# Case 3: From Equipment to Backpack (Unequip/Swap)
	elif from_slot != ItemData.EquipmentSlot.NONE and to_slot == ItemData.EquipmentSlot.NONE:
		var equipped_item = get_item_by_slot_type(from_slot)
		if to_idx < inventory_items.size():
			# Swapping equipped item with a backpack item
			var backpack_item = inventory_items[to_idx]
			if backpack_item.slot_type == from_slot:
				# Only swap if the backpack item fits the slot
				inventory_items[to_idx] = equipped_item
				_set_item_in_slot(from_slot, backpack_item)
			else:
				# If it doesn't fit, just unequip to the end of backpack
				unequip_slot(from_slot)
		else:
			#  To empty space in backpack
			unequip_slot(from_slot)
		return
	data_updated.emit()
func _setup_gear_slots() -> void:
	equipped_gear.clear()
	for slot in ItemData.EquipmentSlot.values():
		if slot != ItemData.EquipmentSlot.NONE:
			equipped_gear[slot] = null
#endregion
#region --- Logic: Progression & Misc ---
## Adds experience points and checks for level up
func add_xp(amount: int) -> bool:
	current_xp += amount
	if current_xp >= get_required_xp():
		# level_up() later
		return true
	return false
## Returns the amount of XP needed for the next level
func get_required_xp() -> int:
	# Maybe 1000 -> 3000 -> 6000 etc
	return int((level * (level + 1) / 2.0) * 1000)
## Returns the readable name of the unit's alignment
func get_alignment_name() -> String:
	return Alignment.keys()[alignment].replace("_", " ").capitalize()
#endregion
