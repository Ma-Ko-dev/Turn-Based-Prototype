extends Resource
class_name UnitData

# --- Progression ---
@export_group("Progression")
@export var level: int = 1
@export var is_player_data: bool = false

# --- Identity ---
enum Size { FINE, DIMINUTIVE, TINY, SMALL, MEDIUM, LARGE, HUGE, GARGANTUAN, COLOSSAL }
@export_group("Identity")
@export var name: String = "Unknown Unit"
@export var size: Size = Size.MEDIUM
@export var texture: Texture2D

# --- Stats ---
@export_group("Stats")
@export var hp_dice_count: int = 1
@export var hp_dice_sides: int = 10
@export var movement_range: int = 10
@export var sight_range: int = 12
var extra_initiative_bonus: int = 0

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


# --- Logic Getters ---
func get_armor_class() -> int:
	# Size bonus to AC is the same as the size bonus to Attack
	return 10 + get_modifier(dexterity) + armor_bonus + shield_bonus + get_size_modifier()
	
	
func calculate_initial_hp() -> int:
	var con_mod = get_modifier(constitution)
	if is_player_data and level == 1:
		# Maximize the first hit die: (1 * sides) + con
		return hp_dice_sides + get_modifier(constitution)
	# Default roll for everyone else
	var roll = Dice.roll(hp_dice_count, hp_dice_sides, con_mod)
	return max(1, roll)


func get_initiative_bonus() -> int:
	return get_modifier(dexterity) + extra_initiative_bonus


func get_attack_bonus() -> int:
	return base_attack_bonus + get_modifier(strength) + get_size_modifier()


func get_fort_save() -> int: return base_fortitude + get_modifier(constitution)
func get_reflex_save() -> int: return base_reflex + get_modifier(dexterity)
func get_will_save() -> int: return base_will + get_modifier(wisdom)
