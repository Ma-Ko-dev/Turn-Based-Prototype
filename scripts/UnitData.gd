extends Resource
class_name UnitData

# --- Identity ---
@export_group("Identity")
@export var name: String = "Unknown Unit"
@export var texture: Texture2D

# --- Stats ---
@export_group("Stats")
@export var health: int = 10
@export var armor_class: int = 10
@export var movement_range: int = 10
@export var initiative_bonus: int = 0
@export var sight_range: int = 12

# --- Attributes ---
@export_group("Attributes")
@export_range(1, 30) var strength: int = 10
@export_range(1, 30) var dexterity: int = 10
@export_range(1, 30) var constitution: int = 10
@export_range(1, 30) var intelligence: int = 10
@export_range(1, 30) var wisdom: int = 10
@export_range(1, 30) var charisma: int = 10


# helper for stat modi
func get_modifier(score: int) -> int:
	return floor((score - 10) /  2.0)
