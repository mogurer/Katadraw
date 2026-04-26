class_name BGMSequencer
extends RefCounted

# BGMSequencer 再実装

## Emitted whenever the BGM transitions to PHASE_JOIN.
## BGMManager uses this to set _ingame_active = true.
signal join_started

const PATHS: Dictionary = {
	"00":        "res://assets/sounds/KATADRAW_00.ogg",
	"join":      "res://assets/sounds/KATADRAW_Join.ogg",
	"join_long": "res://assets/sounds/KATADRAW_JoinLong.ogg",
	"t_aaaa":    "res://assets/sounds/KATADRAW_TitleAAAA.ogg",
	"t_aaaabb":  "res://assets/sounds/KATADRAW_TitleAAAABB.ogg",
	"t_ab":      "res://assets/sounds/KATADRAW_TitleAB.ogg",
	"t_bbbb":    "res://assets/sounds/KATADRAW_TitleBBBB.ogg",
	"t_end":     "res://assets/sounds/KATADRAW_TitleEnd.ogg",
}

enum Phase {
	PHASE_00,
	PHASE_JOIN,
	PHASE_JOIN_LONG,
	PHASE_TITLE_AAAA,
	PHASE_TITLE_AAAABB,
	PHASE_TITLE_AB,
	PHASE_TITLE_BBBB,
	PHASE_TITLE_END,
}

var _phase: Phase = Phase.PHASE_00


## Reset to the title flow start (KATADRAW_00).
func start_title() -> String:
	_phase = Phase.PHASE_00
	return PATHS["00"]


## Jump directly to PHASE_JOIN and emit join_started.
func start_ingame() -> String:
	return _transition(Phase.PHASE_JOIN)


## Determine next segment from the current phase and game state.
## Conditions within each phase are evaluated top to bottom.
func advance(
		match_rate: float,
		demo_reached: bool,
		all_cleared: bool,
		no_input_time: float) -> String:

	match _phase:
		Phase.PHASE_00:
			if no_input_time >= 10.0:
				return _transition(Phase.PHASE_TITLE_AAAA)
			elif not demo_reached:
				return _transition(Phase.PHASE_TITLE_AAAABB)
			else:
				return _transition(Phase.PHASE_TITLE_AB)

		Phase.PHASE_TITLE_END:
			if not all_cleared:
				return _transition(Phase.PHASE_JOIN)
			else:
				return _transition(Phase.PHASE_JOIN_LONG)

		Phase.PHASE_TITLE_AB:
			if not all_cleared:
				return _transition(Phase.PHASE_JOIN)
			else:
				return _transition(Phase.PHASE_JOIN_LONG)

		Phase.PHASE_JOIN:
			if match_rate > 0.9:
				return _transition(Phase.PHASE_TITLE_AB)
			elif match_rate > 0.5:
				return _transition(Phase.PHASE_TITLE_AAAABB)
			else:
				return _transition(Phase.PHASE_TITLE_AAAA)

		Phase.PHASE_JOIN_LONG:
			if no_input_time >= 10.0:
				return _transition(Phase.PHASE_TITLE_AAAA)
			elif not demo_reached:
				return _transition(Phase.PHASE_TITLE_AAAABB)
			else:
				return _transition(Phase.PHASE_TITLE_AB)

		Phase.PHASE_TITLE_AAAA:
			if match_rate > 0.9:
				return _transition(Phase.PHASE_TITLE_AB)
			elif match_rate > 0.5:
				return _transition(Phase.PHASE_TITLE_AAAABB)
			else:
				return _transition(Phase.PHASE_TITLE_AAAA)   # loop

		Phase.PHASE_TITLE_AAAABB:
			if match_rate > 0.9:
				return _transition(Phase.PHASE_TITLE_END)
			else:
				return _transition(Phase.PHASE_TITLE_BBBB)

		Phase.PHASE_TITLE_BBBB:
			if match_rate > 0.9:
				return _transition(Phase.PHASE_TITLE_END)
			else:
				return _transition(Phase.PHASE_TITLE_BBBB)   # loop

	push_error("BGMSequencer: unhandled phase %d" % _phase)
	return ""


# --- Private helpers ---

func _transition(new_phase: Phase) -> String:
	_phase = new_phase
	if new_phase == Phase.PHASE_JOIN:
		join_started.emit()
	return _phase_to_path(new_phase)


func _phase_to_path(phase: Phase) -> String:
	match phase:
		Phase.PHASE_00:           return PATHS["00"]
		Phase.PHASE_JOIN:         return PATHS["join"]
		Phase.PHASE_JOIN_LONG:    return PATHS["join_long"]
		Phase.PHASE_TITLE_AAAA:   return PATHS["t_aaaa"]
		Phase.PHASE_TITLE_AAAABB: return PATHS["t_aaaabb"]
		Phase.PHASE_TITLE_AB:     return PATHS["t_ab"]
		Phase.PHASE_TITLE_BBBB:   return PATHS["t_bbbb"]
		Phase.PHASE_TITLE_END:    return PATHS["t_end"]
	push_error("BGMSequencer: unknown phase %d" % phase)
	return ""
