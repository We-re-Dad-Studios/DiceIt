extends Control
## The play screen, built to the "Felt & Brass" spec: a 250 / flexible / 300
## column layout, the current player's name in their own colour, and the live
## dice + round pot as two ledger figures rather than two sentences.

@onready var left_panel: PanelContainer = %LeftPanel
@onready var scoreboard_title: Label = %ScoreboardTitle
@onready var target_label: Label = %TargetLabel
@onready var scoreboard: VBoxContainer = %Scoreboard

@onready var center_panel: PanelContainer = %CenterPanel
@onready var center_vbox: VBoxContainer = %CenterVBox
@onready var now_playing_label: Label = %NowPlayingLabel
@onready var turn_label: Label = %TurnLabel
@onready var ledger: HBoxContainer = %Ledger
@onready var live_caption: Label = %LiveCaption
@onready var live_count_label: Label = %LiveCountLabel
@onready var ledger_rule: Panel = %LedgerRule
@onready var pot_caption: Label = %PotCaption
@onready var pot_label: Label = %PotLabel
@onready var dice_row: HBoxContainer = %DiceRow
@onready var roll_button: Button = %RollButton
@onready var lock_button: Button = %LockButton
@onready var bank_button: Button = %BankButton
@onready var message_row: HBoxContainer = %MessageRow
@onready var message_pill: PanelContainer = %MessagePill
@onready var message_label: Label = %MessageLabel
@onready var last_turn_label: Label = %LastTurnLabel
@onready var last_turn_row: HBoxContainer = %LastTurnRow

@onready var right_panel: PanelContainer = %RightPanel

@onready var game_over_overlay: ColorRect = %GameOverOverlay
@onready var game_over_panel: PanelContainer = %GameOverPanel
@onready var standings_caption: Label = %StandingsCaption
@onready var winner_label: Label = %WinnerLabel
@onready var winner_detail: Label = %WinnerDetail
@onready var standings: VBoxContainer = %Standings
@onready var play_again_button: Button = %PlayAgainButton
@onready var leave_button: Button = %LeaveButton

## The spec's dice are 88px; the greyed "last turn" row runs smaller.
const LAST_TURN_SCALE := 0.64

var state: Dictionary = {}
var selected_indices: Array = []


func _ready() -> void:
	_apply_style()

	roll_button.pressed.connect(_on_roll_pressed)
	lock_button.pressed.connect(_on_lock_pressed)
	bank_button.pressed.connect(_on_bank_pressed)
	play_again_button.pressed.connect(_on_play_again_pressed)
	leave_button.pressed.connect(_on_leave_pressed)
	NetworkManager.disconnected.connect(_on_disconnected)

	if NetworkManager.is_host:
		GameState.state_changed.connect(_on_host_state_changed)
		NetworkManager.action_received.connect(_on_action_received_as_host)
		_render(GameState.to_payload())
		# Re-broadcast in case a joiner's scene change raced the first
		# broadcast sent from the lobby and missed it.
		NetworkManager.send_game_state(GameState.to_payload())
	else:
		NetworkManager.game_state_received.connect(_on_client_state_received)
		if not NetworkManager.last_game_state.is_empty():
			_render(NetworkManager.last_game_state)
		else:
			_render(GameState.to_payload())


# --- Styling ---------------------------------------------------------------

func _apply_style() -> void:
	for panel in [left_panel, center_panel, right_panel]:
		panel.add_theme_stylebox_override("panel", Style.panel_box(Style.PANEL, Style.BORDER, 18))

	var center_box := Style.panel_box(Style.PANEL, Style.BORDER, 18)
	center_box.content_margin_left = 32
	center_box.content_margin_right = 32
	center_box.content_margin_top = 40
	center_box.content_margin_bottom = 40
	center_panel.add_theme_stylebox_override("panel", center_box)

	_caption(scoreboard_title, "SCOREBOARD")
	target_label.add_theme_font_override("font", Style.mono_400)
	target_label.add_theme_font_size_override("font_size", 12)
	target_label.add_theme_color_override("font_color", Style.INK3)

	_caption(now_playing_label, "NOW PLAYING")
	turn_label.add_theme_font_override("font", Style.archivo_800)
	turn_label.add_theme_font_size_override("font_size", 44)

	_caption(live_caption, "LIVE DICE")
	live_count_label.add_theme_font_override("font", Style.mono_700)
	live_count_label.add_theme_font_size_override("font_size", 34)
	live_count_label.add_theme_color_override("font_color", Style.INK)

	var rule := StyleBoxFlat.new()
	rule.bg_color = Style.BORDER
	ledger_rule.add_theme_stylebox_override("panel", rule)

	# The pot is the number the decision hangs on, so it gets the largest figure.
	_caption(pot_caption, "ROUND POT")
	pot_label.add_theme_font_override("font", Style.mono_700)
	pot_label.add_theme_font_size_override("font_size", 56)

	Style.make_secondary(bank_button)

	var pill := StyleBoxFlat.new()
	pill.bg_color = Style.PANEL_RAISED
	pill.set_corner_radius_all(999)
	pill.set_border_width_all(1)
	pill.border_color = Color("264035")
	pill.content_margin_top = 11
	pill.content_margin_bottom = 11
	pill.content_margin_left = 22
	pill.content_margin_right = 22
	message_pill.add_theme_stylebox_override("panel", pill)
	message_label.add_theme_font_override("font", Style.archivo_500)
	message_label.add_theme_font_size_override("font_size", 17)
	message_label.add_theme_color_override("font_color", Style.INK2)

	_caption(last_turn_label, "LAST TURN")
	last_turn_row.modulate = Color(1, 1, 1, 0.45)

	dice_row.custom_minimum_size = Vector2(0, 104)

	# Gaps from the spec, applied as spacers because a VBox has one uniform
	# separation and the design's rhythm is deliberately uneven.
	_gap_before(turn_label, 10)
	_gap_before(ledger, 34)
	_gap_before(dice_row, 40)
	_gap_before(message_row, 34)
	_gap_before(last_turn_label, 18)
	_gap_before(last_turn_row, 10)

	_style_game_over()


func _style_game_over() -> void:
	var card := Style.panel_box(Style.PANEL, Style.BORDER, 20)
	card.content_margin_left = 40
	card.content_margin_right = 40
	card.content_margin_top = 44
	card.content_margin_bottom = 44
	card.shadow_color = Color(0, 0, 0, 0.45)
	card.shadow_size = 24
	card.shadow_offset = Vector2(0, 12)
	game_over_panel.add_theme_stylebox_override("panel", card)

	_caption(standings_caption, "FINAL STANDINGS")
	winner_label.add_theme_font_override("font", Style.archivo_800)
	winner_label.add_theme_font_size_override("font_size", 46)
	winner_detail.add_theme_font_size_override("font_size", 17)
	winner_detail.add_theme_color_override("font_color", Style.INK2)
	Style.make_secondary(leave_button)


func _caption(label: Label, text: String) -> void:
	label.text = Style.spaced_caps(text)
	label.add_theme_font_override("font", Style.archivo_500)
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Style.INK3)


## Inserts a fixed vertical gap directly above `before`.
func _gap_before(before: Control, height: int) -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, height)
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center_vbox.add_child(spacer)
	center_vbox.move_child(spacer, before.get_index())


# --- Networking glue -------------------------------------------------------

func _on_host_state_changed(payload: Dictionary) -> void:
	_render(payload)
	NetworkManager.send_game_state(payload)


func _on_client_state_received(payload: Dictionary) -> void:
	_render(payload)


func _on_action_received_as_host(payload: Dictionary, from_id: String) -> void:
	GameState.apply_action(from_id, payload.get("action", ""), payload)


func _is_my_turn() -> bool:
	return state.get("current_player_id", "") == NetworkManager.player_id


func _send_or_apply_action(action: String, extra: Dictionary = {}) -> void:
	var payload := extra.duplicate()
	payload["action"] = action
	if NetworkManager.is_host:
		GameState.apply_action(NetworkManager.player_id, action, payload)
	else:
		NetworkManager.send_action(payload)


func _on_roll_pressed() -> void:
	selected_indices = []
	_send_or_apply_action("roll")


func _on_lock_pressed() -> void:
	_send_or_apply_action("lock", {"indices": selected_indices})
	selected_indices = []


func _on_bank_pressed() -> void:
	_send_or_apply_action("bank")


func _on_play_again_pressed() -> void:
	_send_or_apply_action("restart")


func _on_leave_pressed() -> void:
	NetworkManager.leave_room()
	get_tree().change_scene_to_file("res://scenes/Title.tscn")


func _on_disconnected() -> void:
	get_tree().change_scene_to_file("res://scenes/Title.tscn")


# --- Rendering -------------------------------------------------------------

func _render(payload: Dictionary) -> void:
	state = payload
	if state.is_empty():
		return

	_render_scoreboard()
	_render_turn_info()
	_render_dice()
	_render_controls()
	_render_game_over()


func _player_by_id(pid: String) -> Dictionary:
	for p in state.get("players", []):
		if p.get("id", "") == pid:
			return p
	return {}


## Active row is filled and gold-ruled; idle rows are transparent. The player
## colour rides the left edge in both cases.
func _render_scoreboard() -> void:
	for child in scoreboard.get_children():
		child.queue_free()

	target_label.text = "/%d" % state.get("target_score", GameState.TARGET_SCORE)

	var current_id: String = state.get("current_player_id", "")
	for p in state.get("players", []):
		var is_current: bool = p.get("id", "") == current_id
		var row := Style.row_with_edge(
			Style.PANEL_RAISED if is_current else Color(0, 0, 0, 0),
			Style.BORDER_STRONG if is_current else Style.BORDER_IDLE,
			Style.player_color(p.get("color_index", 0))
		)
		var content: HBoxContainer = row["content"]

		var name_label := Label.new()
		name_label.text = p.get("username", "Player")
		name_label.add_theme_font_override("font", Style.archivo_500)
		name_label.add_theme_font_size_override("font_size", 17)
		name_label.add_theme_color_override("font_color", Style.INK if is_current else Style.INK2)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		content.add_child(name_label)

		var score_label := Label.new()
		score_label.text = str(p.get("score", 0))
		score_label.add_theme_font_override("font", Style.mono_700)
		score_label.add_theme_font_size_override("font_size", 20)
		score_label.add_theme_color_override("font_color", Style.GOLD if is_current else Style.INK2)
		content.add_child(score_label)

		scoreboard.add_child(row["root"])


func _render_turn_info() -> void:
	var current := _player_by_id(state.get("current_player_id", ""))
	turn_label.text = current.get("username", "...")
	turn_label.add_theme_color_override(
		"font_color", Style.player_color(current.get("color_index", 0))
	)

	live_count_label.text = str(state.get("live_count", 0))

	# Gold the moment there's something to lose, grey when there isn't.
	var pot: int = state.get("round_pot", 0)
	pot_label.text = str(pot)
	pot_label.add_theme_color_override("font_color", Style.GOLD if pot > 0 else Style.INK3)

	var message: String = state.get("message", "")
	message_row.visible = not message.is_empty()
	message_label.text = message

	var last_turn: Array = state.get("last_turn_dice", [])
	last_turn_label.visible = not last_turn.is_empty()
	last_turn_row.visible = not last_turn.is_empty()
	for child in last_turn_row.get_children():
		child.queue_free()
	for entry in last_turn:
		var die := DiceFace.new()
		die.value = int(entry.get("value", 0))
		die.face_state = "busted" if entry.get("busted", false) else "locked"
		die.scale_factor = LAST_TURN_SCALE
		last_turn_row.add_child(die)


## The row reads left to right as history: locked gold first, then whatever is
## still in play.
func _render_dice() -> void:
	for child in dice_row.get_children():
		child.queue_free()
	selected_indices = []

	var phase: String = state.get("phase", "")
	var my_turn := _is_my_turn()

	for value in state.get("locked_dice", []):
		var die := DiceFace.new()
		die.value = int(value)
		die.face_state = "locked"
		dice_row.add_child(die)

	if phase == "await_choice":
		var last_roll: Array = state.get("last_roll", [])
		for i in range(last_roll.size()):
			var entry: Dictionary = last_roll[i]
			var die := DiceFace.new()
			die.index = i
			die.value = int(entry.get("value", 0))
			if entry.get("busted", false):
				die.face_state = "busted"
			else:
				die.face_state = "normal"
				die.interactive = my_turn
				die.toggled.connect(_on_die_toggled)
			dice_row.add_child(die)
	elif phase == "await_roll":
		for i in range(state.get("live_count", 0)):
			var die := DiceFace.new()
			die.face_state = "blank"
			dice_row.add_child(die)


func _on_die_toggled(idx: int, pressed: bool) -> void:
	if pressed:
		if not selected_indices.has(idx):
			selected_indices.append(idx)
	else:
		selected_indices.erase(idx)


func _render_controls() -> void:
	var phase: String = state.get("phase", "")
	var my_turn := _is_my_turn()

	roll_button.visible = phase == "await_roll"
	roll_button.disabled = not my_turn

	lock_button.visible = phase == "await_choice"
	lock_button.disabled = not my_turn

	bank_button.visible = phase == "await_roll"
	bank_button.disabled = not my_turn


func _render_game_over() -> void:
	var is_over: bool = state.get("phase", "") == "game_over"
	game_over_overlay.visible = is_over
	if not is_over:
		return

	var winner := _player_by_id(state.get("winner_id", ""))
	winner_label.text = "%s wins" % winner.get("username", "Someone")
	winner_label.add_theme_color_override(
		"font_color", Style.player_color(winner.get("color_index", 0))
	)
	var turns: int = winner.get("turns", 0)
	winner_detail.text = "%d points · %d %s · banked %d of %d" % [
		winner.get("score", 0), turns, "turn" if turns == 1 else "turns",
		winner.get("banks", 0), turns,
	]

	for child in standings.get_children():
		child.queue_free()

	var ranked: Array = state.get("players", []).duplicate()
	ranked.sort_custom(func(a, b): return int(a.get("score", 0)) > int(b.get("score", 0)))

	for i in range(ranked.size()):
		var p: Dictionary = ranked[i]
		var is_winner: bool = p.get("id", "") == state.get("winner_id", "")
		var row := Style.row_with_edge(
			Style.PANEL_RAISED if is_winner else Color(0, 0, 0, 0),
			Style.BORDER_STRONG if is_winner else Style.BORDER_IDLE,
			Style.player_color(p.get("color_index", 0)),
			15, 18
		)
		var content: HBoxContainer = row["content"]
		content.add_theme_constant_override("separation", 16)

		var place := Label.new()
		place.text = str(i + 1)
		place.custom_minimum_size = Vector2(22, 0)
		place.add_theme_font_override("font", Style.mono_700)
		place.add_theme_font_size_override("font_size", 16)
		place.add_theme_color_override("font_color", Style.INK3)
		content.add_child(place)

		var name_label := Label.new()
		name_label.text = p.get("username", "Player")
		name_label.add_theme_font_override("font", Style.archivo_500)
		name_label.add_theme_font_size_override("font_size", 19)
		name_label.add_theme_color_override("font_color", Style.INK if is_winner else Style.INK2)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		content.add_child(name_label)

		var score_label := Label.new()
		score_label.text = str(p.get("score", 0))
		score_label.add_theme_font_override("font", Style.mono_700)
		score_label.add_theme_font_size_override("font_size", 24)
		score_label.add_theme_color_override("font_color", Style.GOLD if is_winner else Style.INK2)
		content.add_child(score_label)

		standings.add_child(row["root"])
