extends Resource
class_name UnitData

# --- ENUMS ---
enum Alignment {
	LAWFUL_GOOD, NEUTRAL_GOOD, CHAOTIC_GOOD,
	LAWFUL_NEUTRAL, TRUE_NEUTRAL, CHAOTIC_NEUTRAL,
	LAWFUL_EVIL, NEUTRAL_EVIL, CHAOTIC_EVIL
}
enum Size { FINE, DIMINUTIVE, TINY, SMALL, MEDIUM, LARGE, HUGE, GARGANTUAN, COLOSSAL }
enum UnitType { HUMANOID, UNDEAD, CONSTRUCT, ELEMENTAL, BEAST }
enum Encumbrance { LIGHT, MEDIUM, HEAVY, OVERLOADED }
var inventory_items: Array[ItemData] = []

# --- Starting Equipment ---
@export_group("Starting Equipment")
@export var starting_items: Array[ItemData] = []
var shoulder_item: ItemData
var head_item: ItemData
var neck_item: ItemData
var cloak_item: ItemData
var body_armor: ArmorData
var gloves_item: ItemData
var belt_item: ItemData
var boot_item: ItemData
var ring1_item: ItemData
var ring2_item: ItemData
var quick1_item: ItemData
var quick2_item: ItemData
var main_hand: WeaponData
var off_hand: ItemData # can be a shield (armor data) or weapon (weapon data)
var both_hand: WeaponData

# --- Progression ---
@export_group("Progression")
@export var level: int = 1
@export var current_xp: int = 0
@export var xp_reward: int = 100
@export var threat_rating: float = 1.0
@export var is_player_data: bool = false

# --- Identity ---
@export_group("Identity")
@export var name: String = "Unknown Unit"
@export var size: Size = Size.MEDIUM
@export var unit_type: UnitType = UnitType.HUMANOID
@export var alignment: Alignment = Alignment.TRUE_NEUTRAL
@export var texture: Texture2D

# --- Stats ---
@export_group("Stats")
@export var hp_dice_count: int = 1
@export var hp_dice_sides: int = 10
@export var flat_hp_bonus: int = 0
@export var movement_range: int = 10
@export var sight_range: int = 12
var extra_initiative_bonus: int = 0

# --- Resistance Stats ---
@export var resistances: Array[ResistanceEntry] = []

# --- Combat Stats ---
@export_group("Combat Stats")
@export var base_attack_bonus: int = 0
@export var base_fortitude: int = 0
@export var base_reflex: int = 0
@export var base_will: int = 0
@export var damage_dice_count: int = 1
@export var damage_dice_sides: int = 8

# --- Attributes ---
@export_group("Attributes")
@export_range(1, 30) var strength: int = 10
@export_range(1, 30) var dexterity: int = 10
@export_range(1, 30) var constitution: int = 10
@export_range(1, 30) var intelligence: int = 10
@export_range(1, 30) var wisdom: int = 10
@export_range(1, 30) var charisma: int = 10

# --- AC Bonusses ---
@export_group("AC Bonus")
@export var armor_bonus: int = 0 # from actual armor
@export var shield_bonus: int = 0
@export var natural_armor: int = 0


# --- Calculation Helpers ---
func get_modifier(score: int) -> int:
	return int(floor((score - 10) /  2.0))


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


# Starting equippment helper
func initialize_inventory() -> void:
	# Clear existing inventory to start fresh
	inventory_items.clear()
	_clear_equipment_slots()
	for starting_item in starting_items:
		if not starting_item: continue
		var item = starting_item.duplicate()
		var slotted = false
		# Try to equip the item if it has a valid equipment slot
		if item.slot_type != ItemData.EquipmentSlot.NONE:
			slotted = _auto_equip_item(item)
		# If it couldnt be equipped (slot full or no slot), put it in the backpack
		if not slotted:
			inventory_items.append(item)

# Helper to reset all slots
func _clear_equipment_slots() -> void:
	shoulder_item = null; head_item = null; neck_item = null; cloak_item = null
	body_armor = null; gloves_item = null; belt_item = null; boot_item = null
	ring1_item = null; ring2_item = null; quick1_item = null; quick2_item = null
	main_hand = null; off_hand = null; both_hand = null

# Mapping logic for all slot types
func _auto_equip_item(item: ItemData) -> bool:
	match item.slot_type:
		ItemData.EquipmentSlot.SHOULDER:
			if not shoulder_item:
				shoulder_item = item
				return true
		ItemData.EquipmentSlot.HEAD:
			if not head_item:
				head_item = item
				return true
		ItemData.EquipmentSlot.NECK:
			if not neck_item:
				neck_item = item
				return true
		ItemData.EquipmentSlot.CLOAK:
			if not cloak_item:
				cloak_item = item
				return true
		ItemData.EquipmentSlot.BODY:
			if not body_armor:
				body_armor = item
				return true
		ItemData.EquipmentSlot.GLOVES:
			if not gloves_item:
				gloves_item = item
				return true
		ItemData.EquipmentSlot.BELT:
			if not belt_item:
				belt_item = item
				return true
		ItemData.EquipmentSlot.BOOT:	
			if not boot_item:
				boot_item = item
				return true
		ItemData.EquipmentSlot.RING:
			if not ring1_item:
				ring1_item = item
				return true
			elif not ring2_item:
				ring2_item = item
				return true
		ItemData.EquipmentSlot.QUICK:
			if not quick1_item:
				quick1_item = item
				return true
			elif not quick2_item:
				quick2_item = item
				return true
		ItemData.EquipmentSlot.MAIN_HAND:
			if not main_hand:
				main_hand = item
				return true
		ItemData.EquipmentSlot.OFF_HAND:
			if not off_hand:
				off_hand = item
				return true
		ItemData.EquipmentSlot.BOTH_HANDS:
			if not both_hand:
				both_hand = item
				return true
	
	# No free slot found for this type
	return false

# --- Logic Getters ---
func get_clamped_dex_modifier() -> int:
	var dex_mod = get_modifier(dexterity)
	var effective = get_effective_encumbrance()
	var limit = 99
	match effective:
		Encumbrance.MEDIUM: limit = 3
		Encumbrance.HEAVY: limit = 1
		Encumbrance.OVERLOADED: limit = -5 
	if body_armor:
		# Return the smaller value: either actual dex or the armor's limit
		limit = min(limit, body_armor.max_dex_bonus)
	return min(dex_mod, limit)
func get_armor_bonus() -> int:
	# Use armor item bonus if present, otherwise fallback to hardcoded natural/base bonus
	var bonus = natural_armor
	if body_armor: 
		bonus += body_armor.ac_bonus
	return bonus
func get_shield_bonus() -> int:
	if off_hand is ArmorData: # Shields are ArmorData with slot_type OFF_HAND
		return off_hand.ac_bonus
	return 0
func get_armor_class() -> int: return 10 + get_clamped_dex_modifier() + get_armor_bonus() + get_shield_bonus() + get_size_modifier()
func get_touch_ac() -> int: return 10 + get_modifier(dexterity) + get_size_modifier()
func get_flat_ac() -> int: return 10 + armor_bonus + shield_bonus + natural_armor + get_size_modifier()

func get_dr_for_type(damage_type: int) -> int:
	for res in resistances:
		if res.type == damage_type:
			return res.amount
	return 0


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

func get_max_hp() -> int: return calculate_initial_hp()

func get_initiative_bonus() -> int: return get_modifier(dexterity) + extra_initiative_bonus

func get_attack_bonus() -> int: return base_attack_bonus + get_modifier(strength) + get_size_modifier()
func get_ranged_bonus() -> int: return base_attack_bonus + get_modifier(dexterity) + get_size_modifier()

func get_weapon_damage_dice() -> String:
	if main_hand:
		return main_hand.damage_medium if size >= Size.MEDIUM else main_hand.damage_small
		# Fallback to hardcoded stats if no weapon is equipped
	return "%dd%d" % [damage_dice_count, damage_dice_sides]
func get_damage_data() -> Dictionary:
	var dice_string = get_weapon_damage_dice() #1d3 1d8 etc
	var parts = dice_string.split("d")
	return { "count": int(parts[0]), "sides": int(parts[1])}
func get_attack_reach() -> int:
	return main_hand.reach_ft if main_hand else 5

func get_cmb() -> int: return base_attack_bonus + get_modifier(strength) - get_size_modifier()
func get_cmd() -> int: return 10 + base_attack_bonus + get_modifier(strength) + get_modifier(dexterity) - get_size_modifier()

func get_fort_save() -> int: return base_fortitude + get_modifier(constitution)
func get_reflex_save() -> int: return base_reflex + get_modifier(dexterity)
func get_will_save() -> int: return base_will + get_modifier(wisdom)

func get_required_xp() -> int:
	# Maybe 1000 -> 3000 -> 6000 etc
	return int((level * (level + 1) / 2.0) * 1000)

func get_alignment_name() -> String:
	# Returns the string name of the alignment enum instead of its index
	return Alignment.keys()[alignment].replace("_", " ").capitalize()

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

func get_current_weight() -> float:
	var total = 0.0
	# Weight from equipped items
	for slot_type in ItemData.EquipmentSlot.values():
		if slot_type != ItemData.EquipmentSlot.NONE:
			var item = get_item_by_slot_type(slot_type)
			if item:
				total += item.weight 

	for item in inventory_items:
		if item:
			total += item.weight * item.amount
	return total

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

# Returns the combined encumbrance from armor AND weight
func get_effective_encumbrance() -> Encumbrance:
	var weight_enc = get_encumbrance_level()
	var armor_enc = Encumbrance.LIGHT
	if body_armor:
		if body_armor.armor_type == ArmorData.ArmorType.MEDIUM:
			armor_enc = Encumbrance.MEDIUM
		elif body_armor.armor_type == ArmorData.ArmorType.HEAVY:
			armor_enc = Encumbrance.HEAVY
	return max(weight_enc, armor_enc) as Encumbrance

func get_current_movement_range() -> int:
	var base_move = movement_range
	var armor_pen = 0
	var weight_pen = 0
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

func get_effective_acp() -> int:
	var armor_acp = 0
	if body_armor:
		armor_acp = abs(body_armor.armor_check_penalty)
	if off_hand is ArmorData:
		armor_acp += abs(off_hand.armor_check_penalty)
	var weight_acp = 0
	match get_encumbrance_level():
		Encumbrance.MEDIUM: weight_acp = 3
		Encumbrance.HEAVY: weight_acp = 6
	return -max(armor_acp, weight_acp)


func get_item_by_slot_type(slot_type: ItemData.EquipmentSlot) -> ItemData:
	match slot_type:
		ItemData.EquipmentSlot.SHOULDER: return shoulder_item
		ItemData.EquipmentSlot.HEAD: return head_item
		ItemData.EquipmentSlot.NECK: return neck_item
		ItemData.EquipmentSlot.CLOAK: return cloak_item
		ItemData.EquipmentSlot.BODY: return body_armor
		ItemData.EquipmentSlot.GLOVES: return gloves_item
		ItemData.EquipmentSlot.BELT: return belt_item
		ItemData.EquipmentSlot.BOOT: return boot_item
		ItemData.EquipmentSlot.RING: return ring1_item
		ItemData.EquipmentSlot.QUICK: return quick1_item
		ItemData.EquipmentSlot.MAIN_HAND: return main_hand
		ItemData.EquipmentSlot.OFF_HAND: return off_hand
		ItemData.EquipmentSlot.BOTH_HANDS: return both_hand
	return null


func add_xp(amount: int) -> bool:
	current_xp += amount
	if current_xp >= get_required_xp():
		# level_up() later
		return true
	return false
