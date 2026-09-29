extends Node

## Run state (autoload: GameState): player name, strikes, standing, shift and ending.

signal player_name_changed(new_name: String)
signal strike_taken(strikes_remaining: int)
signal standing_changed(standing: int)
signal shift_changed(shift: int)
signal run_ended(ending: Ending)

enum Ending {
	FIRED,     ## all five strikes spent before finishing shift 8
	STANDARD,  ## finished with at least one strike left
	TRUE_END,  ## finished with no strikes, having flagged precisely
}

const MAX_STRIKES := 5
## False flags allowed before the Dean says something about it.
const FALSE_FLAG_WARNING_AT := 3

## The True ending asks for no strikes AND precise flagging.
const TRUE_ENDING_FALSE_FLAG_ALLOWANCE := 2

## The public demo: training plus the first two real shifts. Set by the "demo" export feature or `--demo`.
const DEMO_LAST_SHIFT := 3
var demo: bool = false

var player_name: String = ""

var strikes_taken: int = 0
var shift: int = ShiftSchedule.FIRST_SHIFT
var standing: int = 0
var false_flags: int = 0
## Which kinds of threat have actually got past the desk.
var incidents: Array[ThreatType.Kind] = []
var run_over: bool = false
var ending: Ending = Ending.STANDARD

func _ready() -> void:
	demo = OS.has_feature("demo") or OS.get_cmdline_user_args().has("--demo")

## True once a demo run has played every shift it has.
func demo_finished() -> bool:
	return demo and not run_over and shift > DEMO_LAST_SHIFT

func set_player_name(value: String) -> void:
	var cleaned := value.strip_edges()
	if cleaned == player_name:
		return
	player_name = cleaned
	player_name_changed.emit(player_name)

func has_player_name() -> bool:
	return not player_name.is_empty()

func strikes_remaining() -> int:
	return maxi(MAX_STRIKES - strikes_taken, 0)

func is_flawless() -> bool:
	return strikes_taken == 0

## No strikes, and security was only ever called when it was warranted — give or take a couple of honest mistakes.
func earns_true_ending() -> bool:
	return is_flawless() and false_flags <= TRUE_ENDING_FALSE_FLAG_ALLOWANCE

# --- Strikes ------------------------------------------------------------------

## Record what got past the desk, before the strike lands.
func record_incident(kind: ThreatType.Kind) -> void:
	incidents.append(kind)

func has_incident_of(kind: ThreatType.Kind) -> bool:
	return incidents.has(kind)

func incident_count() -> int:
	return incidents.size()

## A missed threat caused an incident.
func take_strike() -> void:
	if run_over:
		return
	strikes_taken = mini(strikes_taken + 1, MAX_STRIKES)
	strike_taken.emit(strikes_remaining())
	if strikes_remaining() == 0:
		_end_run(Ending.FIRED)

# --- Standing -----------------------------------------------------------------

func record_false_flag() -> void:
	false_flags += 1
	_adjust_standing(-2)

func record_correct_flag() -> void:
	_adjust_standing(1)

## True once the player has called security on enough innocent people that it is worth someone mentioning.
func false_flags_warrant_warning() -> bool:
	return false_flags >= FALSE_FLAG_WARNING_AT

func _adjust_standing(delta: int) -> void:
	standing = clampi(standing + delta, -20, 20)
	standing_changed.emit(standing)

# --- Shifts -------------------------------------------------------------------

## Move to the next shift.
func advance_shift() -> void:
	if run_over:
		return
	if shift >= ShiftSchedule.TOTAL_SHIFTS:
		_end_run(Ending.TRUE_END if earns_true_ending() else Ending.STANDARD)
		return
	shift += 1
	shift_changed.emit(shift)

func is_final_shift() -> bool:
	return shift >= ShiftSchedule.TOTAL_SHIFTS

func _end_run(which: Ending) -> void:
	if run_over:
		return
	run_over = true
	ending = which
	run_ended.emit(ending)

static func ending_name(which: Ending) -> String:
	match which:
		Ending.FIRED: return "Fired"
		Ending.STANDARD: return "Standard"
		Ending.TRUE_END: return "True"
	return "?"

# --- New run ------------------------------------------------------------------

func reset() -> void:
	set_player_name("")
	strikes_taken = 0
	shift = ShiftSchedule.FIRST_SHIFT
	standing = 0
	false_flags = 0
	incidents.clear()
	run_over = false
	ending = Ending.STANDARD
