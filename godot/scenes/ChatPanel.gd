extends VBoxContainer
## Room chat. Attached to a ChatBox node in both Lobby.tscn and Game.tscn -
## history lives in NetworkManager so it survives the scene change between them.
##
## Per the spec a line is the sender's name in their own colour with the
## message beneath it, not a single run-on row.

@onready var chat_title: Label = %ChatTitle
@onready var chat_log_box: VBoxContainer = %ChatLog
@onready var chat_scroll: ScrollContainer = %ChatScroll
@onready var chat_input: LineEdit = %ChatInput
@onready var chat_send_button: Button = %ChatSendButton


func _ready() -> void:
	_apply_style()

	chat_send_button.pressed.connect(_send_current_text)
	chat_input.text_submitted.connect(func(_t: String): _send_current_text())
	NetworkManager.chat_received.connect(_on_chat_received)

	for entry in NetworkManager.chat_log:
		_append_entry(entry)


func _apply_style() -> void:
	chat_title.text = Style.spaced_caps("CHAT")
	chat_title.add_theme_font_override("font", Style.archivo_500)
	chat_title.add_theme_font_size_override("font_size", 13)
	chat_title.add_theme_color_override("font_color", Style.INK3)

	chat_input.add_theme_font_size_override("font_size", 15)
	var well := StyleBoxFlat.new()
	well.bg_color = Style.INPUT_WELL
	well.set_corner_radius_all(10)
	well.set_border_width_all(2)
	well.border_color = Style.OUTLINE
	well.content_margin_top = 12
	well.content_margin_bottom = 12
	well.content_margin_left = 14
	well.content_margin_right = 14
	chat_input.add_theme_stylebox_override("normal", well)
	var focused := well.duplicate()
	focused.border_color = Style.GOLD
	chat_input.add_theme_stylebox_override("focus", focused)

	Style.make_secondary(chat_send_button)
	chat_send_button.add_theme_font_size_override("font_size", 14)


func _send_current_text() -> void:
	NetworkManager.send_chat(chat_input.text)
	chat_input.text = ""


func _on_chat_received(entry: Dictionary) -> void:
	_append_entry(entry)


func _append_entry(entry: Dictionary) -> void:
	var block := VBoxContainer.new()
	block.add_theme_constant_override("separation", 3)

	var name_label := Label.new()
	name_label.text = entry.get("username", "Player")
	name_label.add_theme_font_override("font", Style.archivo_500)
	name_label.add_theme_font_size_override("font_size", 13)
	name_label.add_theme_color_override(
		"font_color", Style.player_color(entry.get("color_index", 0))
	)
	block.add_child(name_label)

	var text_label := Label.new()
	text_label.text = entry.get("text", "")
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_label.add_theme_font_override("font", Style.archivo_400)
	text_label.add_theme_font_size_override("font_size", 15)
	text_label.add_theme_color_override("font_color", Style.INK2)
	text_label.add_theme_constant_override("line_spacing", 4)
	block.add_child(text_label)

	chat_log_box.add_child(block)
	await get_tree().process_frame
	chat_scroll.scroll_vertical = int(chat_scroll.get_v_scroll_bar().max_value)
