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
var inventory_items: Array[ItemData] = []

# --- Starting Equipment ---
@export_group("Starting Equipment")
@export var starting_items: Array[ItemData] = []
@export var main_hand: WeaponData
@export var off_hand: ItemData # can be a shield (armor data) or weapon (weapon data)
@export var body_armor: ArmorData

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
	for item in starting_items:
		inventory_items.append(item.duplicate())


# --- Logic Getters ---
func get_clamped_dex_modifier() -> int:
	var dex_mod = get_modifier(dexterity)
	if body_armor:
		# Return the smaller value: either actual dex or the armor's limit
		return min(dex_mod, body_armor.max_dex_bonus)
	return dex_mod
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
	# Smaller units carry less, larger carry more. Medium is 5
	var multiplier = 5.0
	match size:
		Size.SMALL: multiplier = 3.5
		Size.LARGE: multiplier = 10.0
	return strength * multiplier

func get_current_weight() -> float:
	var total = 0.0
	# Weight from equipped items
	if main_hand: total += main_hand.weight
	if off_hand: total += off_hand.weight
	if body_armor: total += body_armor.weight
	
	for item in inventory_items:
		total += item.weight * item.amount
	return total

func get_item_by_slot_type(slot_type: ItemData.EquipmentSlot) -> ItemData:
	match slot_type:
		ItemData.EquipmentSlot.MAIN_HAND: return main_hand
		ItemData.EquipmentSlot.BODY: return body_armor
		# TODO Add more later
	return null


func add_xp(amount: int) -> bool:
	current_xp += amount
	if current_xp >= get_required_xp():
		# level_up() later
		return true
	return false
