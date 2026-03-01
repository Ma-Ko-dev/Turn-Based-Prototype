class_name Dice

## Rolls X amount of Y-sided dice and adds a modifier.
## Example: Dice.roll(1, 10, 2) for "1d10 + 2"
static func roll(amount: int, sides: int, modifier: int = 0) -> int:
	var total_rolls: int = 0
	var individual_rolls: Array = []
	
	for i in range(amount):
		var r = GameRNG.game_rng.randi_range(1, sides)
		individual_rolls.append(r)
		total_rolls += r
	
	var final_result: int = total_rolls + modifier
	
	# Detailed logging
	_print_detailed_roll(amount, sides, modifier, individual_rolls, final_result)
	
	return final_result


static func _print_detailed_roll(amount: int, sides: int, modifier: int, rolls: Array, result: int) -> void:
	var rolls_str = str(rolls).replace("[", "").replace("]", "")
	var mod_str = (" + " + str(modifier)) if modifier != 0 else ""
	
	# Example: Dice: 1d20 (18) + 2 -> Result: 20
	print("Dice: %sd%s (%s)%s -> Result: %s" % [amount, sides, rolls_str, mod_str, result])
