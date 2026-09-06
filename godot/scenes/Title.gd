extends Control

@onready var panel: PanelContainer = %Panel
@onready var title_label: Label = %Title
@onready var tagline: Label = %Tagline
@onready var username_edit: LineEdit = %UsernameEdit
@onready var room_code_edit: LineEdit = %RoomCodeEdit
@onready var create_button: Button = %CreateButton
@onready var join_button: Button = %JoinButton
@onready var or_join: Label = %OrJoin
@onready var line_left: Panel = %LineLeft
@onready var line_right: Panel = %LineRight
@onready var status_label: Label = %StatusLabel


func _ready() -> void:
	_apply_style()

	create_button.pressed.connect(_on_create_pressed)
	join_button.pressed.connect(_on_join_pressed)
	username_edit.text_submitted.connect(func(_t): _on_create_pressed())
	room_code_edit.text_submitted.connect(func(_t): _on_join_pressed())
	# Uppercase on blur rather than per keystroke: rewriting `text` inside
	# `text_changed` resyncs the hidden input the web export uses for typing,
	# which swallows the next character.
	room_code_edit.focus_exited.connect(_normalise_code)

	NetworkManager.connected_to_relay.connect(_on_connected)
	NetworkManager.connection_failed.connect(_on_connection_failed)
	NetworkManager.room_created.connect(_on_room_ready)
	NetworkManager.room_joined.connect(_on_room_ready)
	NetworkManager.join_failed.connect(_on_join_failed)

	_apply_link_params()
	username_edit.grab_focus()


## Supports shareable links: ?room=AB12 prefills the code (so a host can send
## a link instead of dictating a code), ?name=alice prefills the username, and
## adding &go=1 to either acts immediately.
func _apply_link_params() -> void:
	var name_param := NetworkManager.get_query_param("name")
	if not name_param.is_empty():
		username_edit.text = name_param

	var room_param := NetworkManager.get_query_param("room").to_upper()
	if not room_param.is_empty():
		room_code_edit.text = room_param

	if NetworkManager.get_query_param("go").is_empty() or username_edit.text.strip_edges().is_empty():
		return

	if not room_param.is_empty():
		_on_join_pressed()
	else:
		_on_create_pressed()


func _apply_style() -> void:
	var card := Style.panel_box(Style.PANEL, Style.BORDER, 20)
	card.content_margin_left = 40
	card.content_margin_right = 40
	card.content_margin_top = 44
	card.content_margin_bottom = 44
	card.shadow_color = Color(0, 0, 0, 0.45)
	card.shadow_size = 24
	card.shadow_offset = Vector2(0, 12)
	panel.add_theme_stylebox_override("panel", card)

	title_label.add_theme_font_override("font", Style.archivo_800)
	title_label.add_theme_font_size_override("font_size", 58)
	title_label.add_theme_color_override("font_color", Style.INK)

	tagline.text = Style.spaced_caps("PUSH YOUR LUCK")
	tagline.add_theme_font_override("font", Style.archivo_500)
	tagline.add_theme_font_size_override("font_size", 13)
	tagline.add_theme_color_override("font_color", Style.GOLD)

	username_edit.add_theme_font_size_override("font_size", 18)

	# The room code is a figure players read aloud - mono, wide, centred.
	room_code_edit.add_theme_font_override("font", Style.mono_700)
	room_code_edit.add_theme_font_size_override("font_size", 22)

	Style.make_secondary(join_button)

	or_join.text = Style.spaced_caps("OR JOIN")
	or_join.add_theme_font_override("font", Style.archivo_500)
	or_join.add_theme_font_size_override("font_size", 12)
	or_join.add_theme_color_override("font_color", Style.INK3)

	for line in [line_left, line_right]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Style.BORDER
		line.add_theme_stylebox_override("panel", sb)

	status_label.add_theme_font_size_override("font_size", 15)
	status_label.add_theme_color_override("font_color", Style.INK3)


func _normalise_code() -> void:
	room_code_edit.text = room_code_edit.text.strip_edges().to_upper()


func _set_buttons_enabled(enabled: bool) -> void:
	create_button.disabled = not enabled
	join_button.disabled = not enabled


func _on_create_pressed() -> void:
	var username := username_edit.text.strip_edges()
	if username.is_empty():
		_show_status("Enter a username first.", Style.BUST)
		return
	_set_buttons_enabled(false)
	_show_status("Connecting...", Style.INK3)
	NetworkManager.connect_and_create_room(NetworkManager.default_relay_url, username)


func _on_join_pressed() -> void:
	var username := username_edit.text.strip_edges()
	var code := room_code_edit.text.strip_edges()
	if username.is_empty():
		_show_status("Enter a username first.", Style.BUST)
		return
	if code.is_empty():
		_show_status("Enter a room code to join.", Style.BUST)
		return
	_set_buttons_enabled(false)
	_show_status("Connecting...", Style.INK3)
	NetworkManager.connect_and_join_room(NetworkManager.default_relay_url, username, code)


func _show_status(text: String, color: Color) -> void:
	status_label.text = text
	status_label.add_theme_color_override("font_color", color)


func _on_connected() -> void:
	_show_status("Connected. Setting up room...", Style.INK3)


func _on_connection_failed() -> void:
	_set_buttons_enabled(true)
	_show_status("Couldn't reach the server. Check your connection and try again.", Style.BUST)


func _on_join_failed(message: String) -> void:
	_set_buttons_enabled(true)
	_show_status(message, Style.BUST)


func _on_room_ready(_code: String) -> void:
	get_tree().change_scene_to_file("res://scenes/Lobby.tscn")
