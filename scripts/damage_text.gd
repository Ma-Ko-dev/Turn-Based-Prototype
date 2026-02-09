extends Label


func setup(amount: int, is_crit: bool = false) -> void:
	text = str(amount)
	var base_size = 48 if is_crit else 40
	add_theme_font_size_override("font_size", base_size)
	
	# Style based on hit type
	if is_crit:
		modulate = Color.GOLD
		scale =Vector2(1.5, 1.5)
	else:
		modulate = Color.RED
	await get_tree().process_frame
	
	# prepare for pop effect
	pivot_offset = size / 2
	scale = Vector2.ZERO
	
	# Random direction: -40 to 40 pixels sideways
	var random_x = randf_range(-40, 40)
	var target_pos = position + Vector2(random_x, -50)
	var target_scale = Vector2(1.5, 1.5) if is_crit else Vector2.ONE
		
	# Animate to the random diagonal position and fade out
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position", target_pos, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, 0.6).set_delay(0.3)
	
	# the pop
	var pop_tween = create_tween()
	pop_tween.tween_property(self, "scale", target_scale * 5, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	pop_tween.tween_property(self, "scale", target_scale, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	await tween.finished
	queue_free()
