extends ItemData
class_name ConsumableData

@export var effect: Effect

## Uses the item and triggers its effect.
func use(target_unit: Unit) -> void:
	if effect:
		effect.apply(target_unit)
		# Potions are usually used up after one use
		target_unit.data.remove_item_from_inventory(self)
		GameEvents.log_requested.emit("%s consumed %s." % [target_unit.display_name, item_name])
