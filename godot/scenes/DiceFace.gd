class_name DiceFace
extends Control
## A single die, drawn to the "Felt & Brass" spec - no sprites needed.
##
## Body 88x88, radius 16, border 3, pips 12 across a 3x3 grid (5px gutters,
## 13px inset). The five states differ on two axes at once (body value AND
## border hue) so they stay readable at a glance, at small window sizes, and
## for colour-blind players.

signal toggled(index: int, pressed: bool)

const BODY := 88.0
const RADIUS := 16
const BORDER := 3
const PIP_DIAMETER := 12.0
const INSET := 13.0
const GUTTER := 5.0
const LIFT := 8.0          # selected dice rise out of the row
const CROSS_INSET := 14.0
const CROSS_WIDTH := 6.0

## Which of the 3x3 cells carry a pip, per face value.
const PIP_LAYOUT := {
	1: [4],
	2: [0, 8],
	3: [0, 4, 8],
	4: [0, 2, 6, 8],
	5: [0, 2, 4, 6, 8],
	6: [0, 2, 3, 5, 6, 8],
}

var index := -1
var value := 0
## "blank" | "normal" | "selected" | "locked" | "busted"
var face_state := "blank"
var interactive := false
var selected := false
## Scale factor - 1.0 is the spec's 88px die; the "last turn" row uses ~0.64.
var scale_factor := 1.0


func _ready() -> void:
	custom_minimum_size = Vector2(BODY, BODY + LIFT) * scale_factor
	mouse_filter = Control.MOUSE_FILTER_STOP if interactive else Control.MOUSE_FILTER_IGNORE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if interactive else Control.CURSOR_ARROW


func _gui_input(event: InputEvent) -> void:
	if not interactive:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		selected = not selected
		queue_redraw()
		toggled.emit(index, selected)


func _colors() -> Dictionary:
	match _effective_state():
		"normal":
			return {"bg": Color("F4F1E7"), "border": Color("CFC8B5"), "pip": Color("16291F")}
		"selected":
			return {"bg": Color("F4F1E7"), "border": Style.COLD, "pip": Color("16291F")}
		"locked":
			return {"bg": Style.GOLD, "border": Color("F2CE78"), "pip": Color("3B2A08")}
		"busted":
			return {"bg": Color("38130F"), "border": Style.BUST, "pip": Color(0, 0, 0, 0)}
		_:
			return {"bg": Color("14291F"), "border": Color("2C4A3D"), "pip": Color(0, 0, 0, 0)}


func _effective_state() -> String:
	if face_state == "normal" and selected:
		return "selected"
	return face_state


func _draw() -> void:
	var s := scale_factor
	var state := _effective_state()
	var c := _colors()
	var body := Vector2(BODY, BODY) * s

	# The control reserves LIFT of headroom: dice normally sit on the bottom
	# baseline, and a selected die rises into that space.
	var top := 0.0 if state == "selected" else LIFT * s
	var rect := Rect2(Vector2(0, top), body)

	if state == "selected":
		# 4px cold glow at 22%, plus a soft drop shadow.
		var glow := StyleBoxFlat.new()
		glow.bg_color = Color(Style.COLD.r, Style.COLD.g, Style.COLD.b, 0.22)
		glow.set_corner_radius_all(int((RADIUS + 4) * s))
		draw_style_box(glow, rect.grow(4.0 * s))

	var box := StyleBoxFlat.new()
	box.bg_color = c["bg"]
	box.set_corner_radius_all(int(RADIUS * s))
	box.set_border_width_all(int(BORDER * s))
	box.border_color = c["border"]
	if state == "selected":
		box.shadow_color = Color(0, 0, 0, 0.4)
		box.shadow_size = int(12 * s)
		box.shadow_offset = Vector2(0, 8 * s)
	draw_style_box(box, rect)

	if state == "blank" or state == "busted":
		if state == "busted":
			_draw_cross(rect)
		return

	_draw_pips(rect, c["pip"])


func _draw_pips(rect: Rect2, pip_color: Color) -> void:
	var cells: Array = PIP_LAYOUT.get(value, [])
	if cells.is_empty():
		return

	var s := scale_factor
	var inset := INSET * s
	var pip := PIP_DIAMETER * s
	var gutter := GUTTER * s

	# The 3x3 grid fills the inset box, so pip centres stay symmetric about the
	# die's centre regardless of pip diameter.
	var inner := BODY * s - inset * 2.0
	var cell := (inner - gutter * 2.0) / 3.0
	var first_centre := inset + cell * 0.5

	for entry in cells:
		var col := int(entry) % 3
		var row := int(entry) / 3
		var centre := rect.position + Vector2(
			first_centre + col * (cell + gutter),
			first_centre + row * (cell + gutter)
		)
		draw_circle(centre, pip * 0.5, pip_color)


func _draw_cross(rect: Rect2) -> void:
	var s := scale_factor
	var inset := CROSS_INSET * s
	var a := rect.position + Vector2(inset, inset)
	var b := rect.position + rect.size - Vector2(inset, inset)
	draw_line(a, b, Style.BUST, CROSS_WIDTH * s, true)
	draw_line(
		Vector2(b.x, a.y), Vector2(a.x, b.y), Style.BUST, CROSS_WIDTH * s, true
	)
