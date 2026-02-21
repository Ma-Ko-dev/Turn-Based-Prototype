extends Effect
class_name HealEffect


@export var dice_count: int = 1
@export var dice_sides: int = 8
@export var bonus: int = 0


## Rolls for healing and applies it to the target unit.
func apply(target: Unit) -> void:
	var amount = Dice.roll(dice_count, dice_sides, bonus)
	if target.has_method("heal"):
		target.heal(amount)
