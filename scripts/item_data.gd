extends Resource
class_name ItemData

enum ItemType { WEAPON, ARMOR, SHIELD, CONSUMABLE, MISC }
enum EquipmentSlot { NONE, MAIN_HAND, OFF_HAND, BOTH_HANDS, BODY, HEAD, RING1, RING2, AMULET, SHOULDER, CLOAK, QUICK1, QUICK2, BELT, BOOT, NECK, GLOVES }

@export_group("Identity")
@export var item_id: String = ""
@export var item_name: String = "New Item"
@export var item_type: ItemType = ItemType.MISC
@export var slot_type: EquipmentSlot = EquipmentSlot.NONE
@export var texture: Texture2D
@export_multiline var description: String = ""

@export_group("Economy & Weight")
@export var cost: int = 0
@export var weight: float = 1.0
@export var amount: int = 1
