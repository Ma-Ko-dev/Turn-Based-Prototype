extends ItemData
class_name ArmorData

enum ArmorType { LIGHT, MEDIUM, HEAVY, SHIELD }

@export_group("Defense Stats")
@export var armor_type: ArmorType = ArmorType.LIGHT
@export var ac_bonus: int = 0
@export var max_dex_bonus: int = 10
@export var armor_check_penalty: = 0
@export_range(0, 100, 5) var arcane_spell_failure: int = 0 # Percent (15 for 15%) 

@export_group("Movement")
@export var speed_penalty: int = 0 #reduction in gridpoints
