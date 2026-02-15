extends MarginContainer


@onready var str_val = find_child("STRValue", true, false)
# etc



func update_ui(data: UnitData, current_hp: int) -> void:
	# Level & xp
	var level_label = find_child("LevelLabel")
	if level_label: level_label.text = "Level: " + str(data.level)
	var xp_label = find_child("XPLabel")
	if xp_label: xp_label.text = "XP: " + str(data.current_xp)
	
	# Attributes
	_update_attribute("STR", data.strength, data.get_modifier(data.strength))
	_update_attribute("DEX", data.dexterity, data.get_modifier(data.dexterity))
	_update_attribute("CON", data.constitution, data.get_modifier(data.constitution))
	_update_attribute("INT", data.intelligence, data.get_modifier(data.intelligence))
	_update_attribute("WIS", data.wisdom, data.get_modifier(data.wisdom))
	_update_attribute("CHA", data.charisma, data.get_modifier(data.charisma))
	
	# Speed & Size
	var speed_label = find_child("SpeedLabel", true, false)
	if speed_label: speed_label.text = "Speed: " + str(data.get_current_movement_range() * 5) + " ft"
	var size_label = find_child("SizeLabel", true, false)
	if size_label: size_label.text = "Size: " + data.Size.keys()[data.size].capitalize()
	
	# Defense (Health & AC)
	var ac_label = find_child("ACValue", true, false)
	if ac_label: ac_label.text = str(data.get_armor_class())
	var touch_label = find_child("TouchValue", true, false)
	if touch_label: touch_label.text = str(data.get_touch_ac())
	var flat_label = find_child("FlatValue", true, false)
	if flat_label: flat_label.text = str(data.get_flat_ac())
	
	# HP
	var hp_bar = find_child("HPBar", true, false)
	var hp_label = find_child("HPValue", true, false)
	var max_hp = data.get_max_hp()
	if hp_bar:
		hp_bar.max_value = max_hp
		hp_bar.value = current_hp
	if hp_label:
		hp_label.text = str(current_hp) + " / " + str(max_hp)
	
	
	# Saves
	_update_single_label("FortValue", data.get_fort_save())
	_update_single_label("RefValue", data.get_reflex_save())
	_update_single_label("WillValue", data.get_will_save())
	
	# Alignment
	var alignment_lavel = find_child("AlignmentLabel")
	if alignment_lavel: alignment_lavel.text = "Alignment: " + data.get_alignment_name()
	
	# Offense
	_update_single_label("BABValue", data.base_attack_bonus)
	_update_single_label("MeleeValue", data.get_attack_bonus())
	_update_single_label("RangedValue", data.get_ranged_bonus())
	_update_single_label("CMBValue", data.get_cmb())
	var cmd_label = find_child("CMDValue", true, false)
	if cmd_label: cmd_label.text = str(data.get_cmd())
	_update_single_label("InitValue", data.get_initiative_bonus())
	
	var weapon_name_label = find_child("WeaponName", true, false)
	var weapon_stats = find_child("WeaponStats", true, false)
	var weapon = data.main_hand
	var dmg_bonus = data.get_modifier(data.strength)
	var bonus_str = ""
	if dmg_bonus > 0:
		bonus_str = "+" + str(dmg_bonus)
	elif dmg_bonus < 0:
		bonus_str = str(dmg_bonus)
	if weapon and weapon is WeaponData:
		if weapon_name_label: weapon_name_label.text = weapon.item_name
		if weapon_stats:
			var range_str = ""
			if weapon.critical_range >= 20:
				range_str = "20"
			else:
				range_str = str(weapon.critical_range) + "-20"
			var crit_info = range_str + " x" + str(weapon.critical_multiplier)
			weapon_stats.text = data.get_weapon_damage_dice() + " " + bonus_str + " / " + crit_info
	else:
		if weapon_name_label: weapon_name_label.text = "Unarmed"
		if weapon_stats:
			weapon_stats.text = data.get_weapon_damage_dice() + " " + bonus_str + " / 20 x2"
			
	

func _update_attribute(stat_name: String, value: int, mod: int) -> void:
	var val_label = find_child(stat_name + "Value", true, false)
	var mod_label = find_child(stat_name + "Bonus", true, false)
	if val_label:
		val_label.text = str(value)
	if mod_label:
		mod_label.text = "(" + ("+" if mod >= 0 else "") + str(mod) + ")"


func _update_single_label(node_name: String, value: int) -> void:
	var label = find_child(node_name, true, false)
	if label:
		label.text = ("+" if value >= 0 else "") + str(value)
