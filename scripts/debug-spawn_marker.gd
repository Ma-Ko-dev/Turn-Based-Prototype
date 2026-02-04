@tool
extends Marker2D


func _draw():
	if Engine.is_editor_hint():
		draw_circle(Vector2.ZERO, 15, Color.YELLOW, false, 2.0)
		draw_line(Vector2(-20, 0), Vector2(20, 0), Color.YELLOW, 2.0)
		draw_line(Vector2(0, -20), Vector2(0, 20), Color.YELLOW, 2.0)


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if not Engine.is_editor_hint():
		queue_redraw()
