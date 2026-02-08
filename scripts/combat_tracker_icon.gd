extends TextureRect


func setup(unit: Unit) -> void:
	# Set the unit image from its data
	texture = unit.data.texture
	# Use instance ID as node name for easy lookup
	name = str(unit.get_instance_id())
	set_active(false)


func set_active(is_active: bool) -> void:
	if is_active:
		self.modulate = Color(0.0, 0.0, 0.0, 1.0)
		# Slight scale effect when it's this unit's turn
	else:
		modulate = Color(0.6, 0.6, 0.6, 0.7)
