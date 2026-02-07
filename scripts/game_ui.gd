extends CanvasLayer

@onready var log_text: Label = $LogWindow/MarginContainer/VBoxContainer/ScrollContainer/LogText
@onready var scroll_container: ScrollContainer = $LogWindow/MarginContainer/VBoxContainer/ScrollContainer


func _ready():
	# Listen for any log requests from anywhere in the game
	GameEvents.log_requested.connect(add_message)


## Add a new message to the log
func add_message(text: String):
	log_text.text += "\n" + text
	# Autoscroll to buttom
	await get_tree().process_frame
	scroll_container.scroll_vertical = scroll_container.get_v_scroll_bar().max_value


## handle the "End Turn" button
func _on_end_turn_button_pressed():
	if TurnManager.current_state == TurnManager.State.COMBAT:
		TurnManager.next_combat_turn()
	else:
		TurnManager.end_exploration_turn()
