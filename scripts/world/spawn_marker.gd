@tool
extends Marker2D
class_name SpawnMarker

## Toggle to define if this marker should spawn a Player or an Enemy.
## Changing this in the inspector will update the gizmo color immediately.
@export var is_player_spawn: bool = false:
	set(value):
		is_player_spawn = value
		queue_redraw() # Force redraw in editor to update color

## The base scene to be instantiated (e.g., Player.tscn or Enemy.tscn).
@export var unit_scene: PackedScene
## The specific data resource for this unit (e.g., Goblin.tres or Warrior.tres).
@export var unit_data: UnitData


func _draw() -> void:
	# Only draw custom gizmos while working in the Godot Editor
	if Engine.is_editor_hint():
		# Blue for players, Red for enemies
		var draw_color = Color.CORNFLOWER_BLUE if is_player_spawn else Color.INDIAN_RED
		
		# Draw a circular crosshair for easy placement on the grid
		draw_circle(Vector2.ZERO, 15, draw_color, false, 2.0)
		draw_line(Vector2(-20, 0), Vector2(20, 0), draw_color, 2.0)
		draw_line(Vector2(0, -20), Vector2(0, 20), draw_color, 2.0)


func _ready() -> void:
	# Ensure the gizmo is cleaned up or properly handled when the game starts
	if not Engine.is_editor_hint():
		queue_redraw()
