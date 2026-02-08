class_name Dice

## Rolls X amount of Y-sided dice and adds a modifier.
## Example: Dice.roll(1, 10, 2) for "1d10 + 2"
static func roll(amount: int, sides: int, modifier: int = 0) -> int:
	var total = 0
	for i in range(amount):
		total += randi_range(1, sides)
	var result = total + modifier
	# Internal logging
	_print_roll_result(amount, sides, modifier, result)
	return result


static func _print_roll_result(amount: int, sides: int, modifier: int, result: int) -> void:
	print("Dice: %sd%s + %s -> Result: %s" % [amount, sides, modifier, result])
