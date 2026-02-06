class_name Dice

## Rolls X amount of Y-sided dice and adds a modifier.
## Example: Dice.roll(1, 10, 2) for "1d10 + 2"
static func roll(amount: int, sides: int, modifier: int = 0) -> int:
	var total = 0
	for i in range(amount):
		total += randi_range(1, sides)
	var result = total + modifier
	# debug
	print("Rolling ", amount, "d", sides, " + ", modifier, " -> Result: ", result)
	return result
