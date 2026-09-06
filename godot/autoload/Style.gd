extends Node
## "Felt & Brass" design system.
##
## A dark green felt table lit by brass: the background is the table, panels are
## cards laid on it, and the only saturated warm colour is money - room code,
## round pot, primary buttons and locked dice all share one gold. Everything a
## player can lose is red; everything they are about to choose is a cold blue.
##
## Tokens live here and the Theme is built in code, so there is exactly one
## place to change a colour or a size.

# --- Palette ---------------------------------------------------------------
const TABLE := Color("0F221A")        # window background
const PANEL := Color("172E25")
const PANEL_RAISED := Color("1C352B")
const BORDER := Color("2A463A")
const BORDER_STRONG := Color("3A5C4B")
const BORDER_IDLE := Color("223B31")
const INPUT_WELL := Color("0E1D18")

const INK := Color("F2EFE6")           # primary text
const INK2 := Color("C9D6CD")          # secondary text
const INK3 := Color("8FA69A")          # muted text / section labels

const GOLD := Color("D8A23A")          # CTA + money
const GOLD_HOVER := Color("EBB752")
const GOLD_PRESSED := Color("BE8A28")

const BUST := Color("B3372F")          # danger
const COLD := Color("52C7E8")          # selection

const DISABLED_FILL := Color("1B322A")
const DISABLED_INK := Color("5C7466")

const OUTLINE_HOVER := Color("45705C")
const OUTLINE_HOVER_FILL := Color("1D362C")
const OUTLINE := Color("2C4A3D")

const PLAYER_COLORS: Array[Color] = [
	Color("EF7264"), Color("F0A02E"), Color("EFD34B"), Color("63C97A"),
	Color("4FC3E8"), Color("7A8CF0"), Color("B983F0"), Color("F07FB4"),
]

# --- Type ------------------------------------------------------------------
const FONT_DIR := "res://assets/fonts/"

var archivo_400: FontFile
var archivo_500: FontFile
var archivo_700: FontFile
var archivo_800: FontFile
var mono_400: FontFile
var mono_700: FontFile

var theme: Theme


func _ready() -> void:
	archivo_400 = _load_font("Archivo-400.ttf")
	archivo_500 = _load_font("Archivo-500.ttf")
	archivo_700 = _load_font("Archivo-700.ttf")
	archivo_800 = _load_font("Archivo-800.ttf")
	mono_400 = _load_font("JetBrainsMono-400.ttf")
	mono_700 = _load_font("JetBrainsMono-700.ttf")

	theme = _build_theme()
	get_tree().root.theme = theme
	RenderingServer.set_default_clear_color(TABLE)


func _load_font(file_name: String) -> FontFile:
	var font := load(FONT_DIR + file_name)
	return font if font is FontFile else null


func player_color(idx: int) -> Color:
	return PLAYER_COLORS[idx % PLAYER_COLORS.size()]


# --- Style helpers ---------------------------------------------------------

func panel_box(bg: Color = PANEL, border_color: Color = BORDER, radius: int = 18, border_width: int = 1) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.set_border_width_all(border_width)
	sb.border_color = border_color
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 22
	sb.content_margin_bottom = 22
	return sb


func _button_box(bg: Color, border_color: Color, border_width: int, pad_v: int, pad_h: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(10)
	sb.set_border_width_all(border_width)
	sb.border_color = border_color
	sb.content_margin_top = pad_v
	sb.content_margin_bottom = pad_v
	sb.content_margin_left = pad_h
	sb.content_margin_right = pad_h
	return sb


func _input_box(border_color: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = INPUT_WELL
	sb.set_corner_radius_all(10)
	sb.set_border_width_all(2)
	sb.border_color = border_color
	sb.content_margin_top = 14
	sb.content_margin_bottom = 14
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	return sb


func _build_theme() -> Theme:
	var t := Theme.new()
	t.default_font = archivo_400
	t.default_font_size = 17

	# Primary (brass) button is the default Button look.
	t.set_stylebox("normal", "Button", _button_box(GOLD, GOLD, 0, 16, 34))
	t.set_stylebox("hover", "Button", _button_box(GOLD_HOVER, GOLD_HOVER, 0, 16, 34))
	t.set_stylebox("pressed", "Button", _button_box(GOLD_PRESSED, GOLD_PRESSED, 0, 16, 34))
	t.set_stylebox("disabled", "Button", _button_box(DISABLED_FILL, DISABLED_FILL, 0, 16, 34))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_font("font", "Button", archivo_700)
	t.set_font_size("font_size", "Button", 19)
	t.set_color("font_color", "Button", TABLE)
	t.set_color("font_hover_color", "Button", TABLE)
	t.set_color("font_pressed_color", "Button", TABLE)
	t.set_color("font_disabled_color", "Button", DISABLED_INK)

	# Text inputs.
	t.set_stylebox("normal", "LineEdit", _input_box(OUTLINE))
	t.set_stylebox("focus", "LineEdit", _input_box(GOLD))
	t.set_font("font", "LineEdit", archivo_400)
	t.set_font_size("font_size", "LineEdit", 17)
	t.set_color("font_color", "LineEdit", INK)
	t.set_color("font_placeholder_color", "LineEdit", INK3)
	t.set_color("caret_color", "LineEdit", GOLD)
	t.set_color("selection_color", "LineEdit", Color(GOLD.r, GOLD.g, GOLD.b, 0.35))

	t.set_stylebox("panel", "PanelContainer", panel_box())

	t.set_font("font", "Label", archivo_400)
	t.set_font_size("font_size", "Label", 17)
	t.set_color("font_color", "Label", INK2)

	t.set_color("default_color", "RichTextLabel", INK2)
	t.set_font("normal_font", "RichTextLabel", archivo_400)
	t.set_font_size("normal_font_size", "RichTextLabel", 15)

	t.set_stylebox("panel", "ScrollContainer", StyleBoxEmpty.new())
	return t


## Restyles a Button as the secondary (outlined) variant from the spec.
func make_secondary(button: Button) -> void:
	button.add_theme_stylebox_override("normal", _button_box(Color(0, 0, 0, 0), OUTLINE, 2, 14, 28))
	button.add_theme_stylebox_override("hover", _button_box(OUTLINE_HOVER_FILL, OUTLINE_HOVER, 2, 14, 28))
	button.add_theme_stylebox_override("pressed", _button_box(OUTLINE_HOVER_FILL, OUTLINE_HOVER, 2, 14, 28))
	button.add_theme_stylebox_override("disabled", _button_box(DISABLED_FILL, DISABLED_FILL, 2, 14, 28))
	button.add_theme_color_override("font_color", INK2)
	button.add_theme_color_override("font_hover_color", INK)
	button.add_theme_color_override("font_pressed_color", INK)
	button.add_theme_color_override("font_disabled_color", DISABLED_INK)


## A list row carrying the player's colour as a 4px left edge.
##
## StyleBoxFlat supports per-side border widths but only one border colour, so
## the edge is drawn as its own rounded bar inside the row rather than as a
## thick left border. Returns {"root": PanelContainer, "content": HBoxContainer}.
func row_with_edge(bg: Color, border_color: Color, edge_color: Color, pad_v := 13, pad_h := 14) -> Dictionary:
	var root := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(10)
	sb.set_border_width_all(1)
	sb.border_color = border_color
	root.add_theme_stylebox_override("panel", sb)
	root.clip_contents = true

	var lane := HBoxContainer.new()
	lane.add_theme_constant_override("separation", 0)
	root.add_child(lane)

	var edge := Panel.new()
	edge.custom_minimum_size = Vector2(4, 0)
	var edge_sb := StyleBoxFlat.new()
	edge_sb.bg_color = edge_color
	edge_sb.corner_radius_top_left = 10
	edge_sb.corner_radius_bottom_left = 10
	edge.add_theme_stylebox_override("panel", edge_sb)
	lane.add_child(edge)

	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left", pad_h)
	pad.add_theme_constant_override("margin_right", pad_h)
	pad.add_theme_constant_override("margin_top", pad_v)
	pad.add_theme_constant_override("margin_bottom", pad_v)
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lane.add_child(pad)

	var content := HBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	pad.add_child(content)

	return {"root": root, "content": content}


## Section label: Archivo 500, caps, wide tracking, muted.
func make_section_label(label: Label, tracking := 2.1) -> void:
	label.add_theme_font_override("font", archivo_500)
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", INK3)
	label.add_theme_constant_override("line_spacing", 0)
	label.text = label.text.to_upper()
	# Godot has no letter-spacing constant, so tracking is faked with spaces
	# only where the design leans on it hardest (see spaced_caps).
	if tracking > 0.0:
		label.text = spaced_caps(label.text)


## Godot's Label has no letter-spacing property; the spec's wide caps tracking
## is approximated by inserting thin spaces between characters.
func spaced_caps(text: String) -> String:
	var out := ""
	for i in text.length():
		out += text[i]
		if i < text.length() - 1:
			out += " "
	return out
