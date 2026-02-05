extends Resource
class_name UnitData

# --- Identity ---
@export var name: String = "Unknown Unit"
@export var texture: Texture2D

# --- Attributes ---
@export var movement_range: int = 5
@export var initiative_bonus: int = 0
@export var health: int = 10
@export var sight_range: int = 12

# Expand this resource later with things like 'damage', 'armor', or 'attack_range'
