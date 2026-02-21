extends Control

@onready var restart_button: Button = $CenterContainer/NinePatchRect/MarginContainer/VBoxContainer/RestartButton

func _ready() -> void:
	hide()
	GameEvents.game_over.connect(_on_game_over)
	if restart_button:
		restart_button.pressed.connect(_on_restart_button_pressed)

func _on_game_over() -> void:
	show()
	if restart_button:
		restart_button.grab_focus()


func _on_restart_button_pressed() -> void:
	TurnManager.reset_manager()
	get_tree().reload_current_scene()
