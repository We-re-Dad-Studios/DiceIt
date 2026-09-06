class_name DiceFace
extends Control
## A single hand-drawn die face (no external art needed). Draws real pips
## for 1-6, and supports three visual states: blank (not yet rolled),
## normal/selectable, locked (safely banked into the round), and busted.

signal toggled(index: int, pressed: bool)

const SIZE := Vector2(56, 56)
const PIP_POSITIONS := {
	1: [Vector2(0.5, 0.5)],
	2: [Vector2(0.27, 0.27), Vector2(0.73, 0.73)],
	3: [Vector2(0.27, 0.27), Vector2(0.5, 0.5), Vector2(0.73, 0.73)],
	4: [Vector2(0.27, 0.27), Vector2(0.73, 0.27), Vector2(0.27, 0.73), Vector2(0.73, 0.73)],
	5: [Vector2(0.27, 0.27), Vector2(0.73, 0.27), Vector2(0.5, 0.5), Vector2(0.27, 0.73), Vector2(0.73, 0.73)],
	6: [Vector2(0.27, 0.2), Vector2(0.73, 0.2), Vector2(0.27, 0.5), Vector2(0.73, 0.5), Vector2(0.27, 0.8), Vector2(0.73, 0.8)],
}

var index := -1
var value := 0
## "blank" (not yet rolled), "selectable" (this roll, may lock), "locked" (banked this round), "busted"
var face_state := "blank"
var interactive := false
var selected := false


func _ready() -> void:
	custom_minimum_size = SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP if interactive else Control.MOUSE_FILTER_IGNORE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if interactive else Control.CURSOR_ARROW


func _gui_input(event: InputEvent) -> void:
	if not interactive:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		selected = not selected
		queue_redraw()
		toggled.emit(index, selected)


func _draw() -> void:
	var bg_color: Color
	var border_color := Color(0, 0, 0, 0)
	var border_width := 0

	match face_state:
		"blank":
			bg_color = Color(0.22, 0.22, 0.26)
		"locked":
			bg_color = Color(0.93, 0.86, 0.55)
			border_color = Color(0.75, 0.6, 0.15)
			border_width = 3
		"busted":
			bg_color = Color(0.4, 0.16, 0.16)
		_:
			bg_color = Color(0.95, 0.94, 0.9)
			if selected:
				border_color = Color(0.35, 0.75, 0.45)
				border_width = 4

	var sb := StyleBoxFlat.new()
	sb.bg_color = bg_color
	sb.corner_radius_top_left = 10
	sb.corner_radius_top_right = 10
	sb.corner_radius_bottom_left = 10
	sb.corner_radius_bottom_right = 10
	sb.border_width_left = border_width
	sb.border_width_right = border_width
	sb.border_width_top = border_width
	sb.border_width_bottom = border_width
	sb.border_color = border_color
	draw_style_box(sb, Rect2(Vector2.ZERO, SIZE))

	if face_state == "blank":
		return

	var pip_color := Color(0.55, 0.2, 0.2) if face_state == "busted" else Color(0.15, 0.15, 0.18)
	var positions: Array = PIP_POSITIONS.get(value, [])
	for pos in positions:
		draw_circle(Vector2(pos.x * SIZE.x, pos.y * SIZE.y), 5.0, pip_color)

	if face_state == "busted":
		draw_line(Vector2(6, 6), SIZE - Vector2(6, 6), Color(0.85, 0.25, 0.25), 3.0)
		draw_line(Vector2(SIZE.x - 6, 6), Vector2(6, SIZE.y - 6), Color(0.85, 0.25, 0.25), 3.0)
