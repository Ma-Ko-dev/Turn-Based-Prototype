extends Resource
class_name ItemData

enum ItemType { WEAPON, ARMOR, SHIELD, CONSUMABLE, MISC }
enum EquipmentSlot { NONE, SHOULDER, HEAD, NECK, CLOAK, BODY, GLOVES, BELT, BOOT, RING, QUICK, MAIN_HAND, OFF_HAND, BOTH_HANDS }

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


func get_actions(unit_data: UnitData, is_equipped: bool, slot: PanelContainer) -> Array:
	var actions = []
	actions.append({
		"label": "Inspect",
		"callback": func(): print("Inspecting " + item_name)
	})
	
	
	if item_type == ItemType.CONSUMABLE:
		actions.append({
			"label": "Use",
			"callback": func(): 
				var players = slot.get_tree().get_nodes_in_group("players")
				if not players.is_empty():
					use(players[0]) # Hier wird jetzt die überschriebene Funktion aufgerufen
		})
	
	# Ausrüstungs-Logik nur für Waffen/Rüstung anzeigen
	elif slot_type != EquipmentSlot.NONE:
		if not is_equipped:
			actions.append({
				"label": "Equip",
				"callback": func(): slot._equip_via_menu(unit_data)
			})
		else:
			actions.append({
				"label": "Unequip",
				"callback": func(): slot._unequip_via_menu(unit_data)
			})
		
		
	actions.append({
		"label": "Drop",
		"callback": func(): slot._drop_item_logic(unit_data)
	})
	return actions

## Base function, overridden by subclasses like ConsumableData.
func use(_target: Unit) -> void:
	pass
