extends Node
## Authoritative push-your-luck rules. Only the host's copy of this node is
## ever actually driving the game - joiners just render the state_changed
## payloads the host broadcasts over the network. See Game.gd for the glue.

signal state_changed(payload: Dictionary)

const STARTING_DICE := 5
const TARGET_SCORE := 4000

var players: Array = []       # [{id, username, color_index, score}]
var turn_order: Array = []    # [player_id, ...]
var current_turn_index := 0

var live_count := STARTING_DICE
var last_roll: Array = []     # [{value:int, busted:bool}]
var locked_dice: Array = []   # [int, ...] values locked in so far this round
var round_pot := 0
var phase := "lobby"          # lobby | await_roll | await_choice | round_lost | game_over
var winner_id := ""
var message := ""

## Dice from the turn that just ended, kept so the next state still shows what
## happened (busted or banked) without needing a timed pause between turns.
var last_turn_dice: Array = []


func start_game(player_list: Array) -> void:
	players = []
	for p in player_list:
		players.append({
			"id": p.get("id", ""),
			"username": p.get("username", "Player"),
			"color_index": p.get("color_index", 0),
			"score": 0,
		})
	turn_order = players.map(func(p): return p["id"])
	current_turn_index = 0
	winner_id = ""
	_reset_turn()
	_emit_state()


func apply_action(from_id: String, action: String, payload: Dictionary) -> void:
	if phase == "game_over":
		return
	if from_id != current_player_id():
		return # not this player's turn

	match action:
		"roll":
			if phase == "await_roll":
				_do_roll()
		"lock":
			if phase == "await_choice":
				_do_lock(payload.get("indices", []))
		"bank":
			if phase == "await_roll" or phase == "await_choice":
				_do_bank()


func current_player_id() -> String:
	if turn_order.is_empty():
		return ""
	return turn_order[current_turn_index]


func _find_player(pid: String) -> Dictionary:
	for p in players:
		if p["id"] == pid:
			return p
	return {}


func _reset_turn() -> void:
	live_count = STARTING_DICE
	last_roll = []
	locked_dice = []
	last_turn_dice = []
	round_pot = 0
	phase = "await_roll"
	message = ""


func _do_roll() -> void:
	var results: Array = []
	var busted_count := 0
	for i in range(live_count):
		var value := randi_range(1, 6)
		var busted := value == 1
		if busted:
			busted_count += 1
		results.append({"value": value, "busted": busted})

	last_roll = results

	if busted_count == live_count:
		# Every die still in play busted before anything from this roll locked in.
		var lost := round_pot
		round_pot = 0
		_advance_turn("%s busted and lost %d points." % [_current_username(), lost], results)
		return

	live_count -= busted_count
	phase = "await_choice"
	_emit_state()


func _do_lock(indices: Array) -> void:
	var locked_value := 0
	var locked_count := 0
	for i in indices:
		var idx := int(i)
		if idx < 0 or idx >= last_roll.size():
			continue
		var entry: Dictionary = last_roll[idx]
		if entry.get("busted", true):
			continue
		locked_value += int(entry.get("value", 0))
		locked_count += 1
		locked_dice.append(int(entry.get("value", 0)))

	round_pot += locked_value
	live_count -= locked_count
	last_roll = []

	if live_count <= 0:
		_do_bank()
		return

	phase = "await_roll"
	message = ""
	_emit_state()


func _do_bank() -> void:
	var player := _find_player(current_player_id())
	var banked := round_pot
	if not player.is_empty():
		player["score"] += banked

	if player.get("score", 0) >= TARGET_SCORE:
		phase = "game_over"
		winner_id = player.get("id", "")
		message = "%s banked %d points." % [player.get("username", "Player"), banked]
		_emit_state()
		return

	var banked_faces: Array = locked_dice.map(func(v): return {"value": v, "busted": false})
	_advance_turn("%s banked %d points." % [player.get("username", "Player"), banked], banked_faces)


func _current_username() -> String:
	return _find_player(current_player_id()).get("username", "Player")


func _advance_turn(summary: String, closing_dice: Array) -> void:
	current_turn_index = (current_turn_index + 1) % turn_order.size()
	_reset_turn()
	message = summary
	last_turn_dice = closing_dice
	_emit_state()


func _emit_state() -> void:
	state_changed.emit(to_payload())


func to_payload() -> Dictionary:
	return {
		"players": players.duplicate(true),
		"turn_order": turn_order.duplicate(true),
		"current_turn_index": current_turn_index,
		"current_player_id": current_player_id(),
		"live_count": live_count,
		"last_roll": last_roll.duplicate(true),
		"locked_dice": locked_dice.duplicate(true),
		"last_turn_dice": last_turn_dice.duplicate(true),
		"round_pot": round_pot,
		"phase": phase,
		"winner_id": winner_id,
		"message": message,
		"target_score": TARGET_SCORE,
	}
