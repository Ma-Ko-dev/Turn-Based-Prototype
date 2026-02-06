extends Resource
class_name UnitData

# --- Identity ---
@export_group("Identity")
@export var name: String = "Unknown Unit"
@export var texture: Texture2D

# --- Stats ---
@export_group("Stats")
@export var hp_dice_count: int = 1
@export var hp_dice_sides: int = 10
var armor_class: int = 10 #Base AC is always 10, no editing necessary
@export var movement_range: int = 10
#@export var initiative_bonus: int = 0
var extra_initiative_bonus: int = 0
@export var sight_range: int = 12

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
@export var size_bonus: int = 0 # +1 for Small, -1 for Large, 0 Medium


## Helper: Pathfinder modifier calculation
func get_modifier(score: int) -> int:
	return floor((score - 10) /  2.0)

## The "True" AC of this unit type
func get_armor_class() -> int:
	return 10 + get_modifier(dexterity) + armor_bonus + shield_bonus + size_bonus

## Calculate HP
func calculate_initial_hp() -> int:
	var roll = Dice.roll(hp_dice_count, hp_dice_sides, get_modifier(constitution))
	return max(1, roll)

## Dynamically calculate the total Initiative Bonus
func get_initiative_bonus() -> int:
	return get_modifier(dexterity) + extra_initiative_bonus
