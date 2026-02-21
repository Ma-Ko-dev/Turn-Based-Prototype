extends ItemData
class_name WeaponData

enum DamageType { BLUDGEONING, PIERCING, SLASHING }
enum WeaponCategory { MELEE, RANGED }

@export_group("Combat Stats")
@export var weapon_category: WeaponCategory = WeaponCategory.MELEE
@export var damage_type: DamageType = DamageType.SLASHING
@export var reach: int = 5

@export_group("Damage")
@export var damage_small: String = "1d4"
@export var damage_medium: String = "1d6"
@export var critical_range: int = 20 #19 means 19-20
@export var critical_multiplier: int = 2

@export_group("Flags")
@export var is_two_handed: bool = false
@export var requires_ammo: bool = false
