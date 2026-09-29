extends Node
class_name ShiftRunner

## Runs one shift: the queue, the calls the player makes, and what those calls cost.

signal visitor_ready(request: VisitorRequest)
signal shift_started(shift: int, visitor_count: int)
signal shift_ended(reason: EndReason)
signal decision_judged(request: VisitorRequest, verdict: DecisionJudge.Verdict)
signal incident_occurred(request: VisitorRequest)
signal dean_arrived(lines: PackedStringArray, strike_number: int)
signal dean_warning(lines: PackedStringArray)
## Sent home over false flags.
signal sent_home(lines: PackedStringArray)
## Rahat, during the onboarding shift.
signal mentor_line(lines: PackedStringArray)
## A rulebook rule has just been explained for the first time.
signal rule_taught(rule: Rulebook.Rule, title: String)
## The fifth incident: the Dean orders a lockdown instead of just firing the player.
signal finale_started(lines: PackedStringArray)

enum EndReason {
	QUEUE_FINISHED,  ## the night ran out of visitors, which is the good case
	INCIDENT,        ## sent home early after an incident — costs a strike
	SENT_HOME,       ## sent home early over false flags — costs the night only
}

## How many further visitors are served before a missed threat surfaces.
@export var incident_delay_min: int = 2
@export var incident_delay_max: int = 4

var rulebook := Rulebook.new()
var queue: Array[VisitorRequest] = []
var index: int = 0
var shift_over: bool = false
## The lockdown is running; the queue is closed.
var in_finale: bool = false

var _pending_incidents: Array = []
var _served: int = 0
var _warned_about_false_flags: bool = false
var is_onboarding: bool = false
var _rng := RandomNumberGenerator.new()

## Off for headless balance runs, which never look at a face.
var generate_portraits: bool = true

func start(shift: int, seed_value: int = 0) -> void:
	var chosen := seed_value
	if chosen == 0:
		chosen = int(Time.get_unix_time_from_system())
	_rng.seed = chosen

	is_onboarding = ShiftSchedule.is_onboarding(shift)
	if is_onboarding:
		# Shift one is written, not generated.
		queue = Onboarding.build(rulebook, chosen)
		rulebook.enabled_rules = Onboarding.rules_known_at(1)
	else:
		var generator := QueueGenerator.new(rulebook, chosen)
		generator.generate_portraits = generate_portraits
		queue = generator.build_shift(shift)
		rulebook.enabled_rules = []
	index = 0
	_served = 0
	_pending_incidents.clear()
	shift_over = false
	in_finale = false
	_warned_about_false_flags = false

	shift_started.emit(shift, queue.size())

	if is_onboarding:
		mentor_line.emit(Rahat.cold_open(GameState.player_name))

	if not queue.is_empty():
		_announce_visitor(0)

func current() -> VisitorRequest:
	if shift_over or in_finale or index >= queue.size():
		return null
	return queue[index]

## Someone further down the queue, without advancing it.
func peek(offset: int = 1) -> VisitorRequest:
	var at := index + offset
	if shift_over or at < 0 or at >= queue.size():
		return null
	return queue[at]

func visitors_remaining() -> int:
	return maxi(queue.size() - index, 0)

## The player made a call.
func resolve(decision: int) -> void:
	var request := current()
	if request == null or shift_over:
		return

	var verdict := DecisionJudge.judge(request, decision, rulebook)
	decision_judged.emit(request, verdict)

	match verdict:
		DecisionJudge.Verdict.MISSED_THREAT:
			# Nothing happens now.
			_pending_incidents.append({
				"request": request,
				"due": _served + _rng.randi_range(incident_delay_min, incident_delay_max),
			})
		DecisionJudge.Verdict.FALSE_FLAG:
			GameState.record_false_flag()
			if GameState.false_flags_warrant_warning() and not _warned_about_false_flags:
				_warned_about_false_flags = true
				dean_warning.emit(Dean.false_flag_warning(GameState.player_name))
			elif _warned_about_false_flags:
				# A further false flag after the warning ends the shift. Costs the night, not a strike.
				_served += 1
				index += 1
				sent_home.emit(Dean.false_flag_sent_home(GameState.player_name))
				_finish(EndReason.SENT_HOME)
				return
		DecisionJudge.Verdict.CORRECT:
			if request.is_threat:
				GameState.record_correct_flag()
		_:
			pass

	_served += 1
	index += 1

	if _fire_due_incident():
		return

	if index >= queue.size():
		if is_onboarding:
			mentor_line.emit(Rahat.stakes(GameState.player_name))
			mentor_line.emit(Rahat.closing(GameState.player_name))
		_finish(EndReason.QUEUE_FINISHED)
		return

	_announce_visitor(index)

## Put the next visitor at the desk.
func _announce_visitor(at: int) -> void:
	var number := at + 1

	if is_onboarding:
		var rule := Onboarding.rule_taught_by(number)
		rulebook.enabled_rules = Onboarding.rules_known_at(number)
		if rule >= 0:
			rule_taught.emit(rule as Rulebook.Rule, Rulebook.RULE_TITLES[rule])

		var lines := Rahat.teaching_for(number, GameState.player_name)
		if not lines.is_empty():
			mentor_line.emit(lines)
		if number == Onboarding.FLAG_TRAINING_VISITOR:
			mentor_line.emit(Rahat.flag_training(GameState.player_name))

	visitor_ready.emit(queue[at])

## Has a missed threat come home to roost yet?
func _fire_due_incident() -> bool:
	for i in _pending_incidents.size():
		var pending: Dictionary = _pending_incidents[i]
		if _served >= int(pending["due"]):
			_pending_incidents.remove_at(i)
			_run_incident(pending["request"])
			return true
	return false

func _run_incident(request: VisitorRequest) -> void:
	incident_occurred.emit(request)

	GameState.record_incident(request.threat_kind)
	GameState.take_strike()
	var strike_number := GameState.strikes_taken

	# The last incident a run can have is the lockdown, when something is there to play it.
	if strike_number >= GameState.MAX_STRIKES and ThreatType.is_designed(ThreatType.Kind.FINALE) \
			and not finale_started.get_connections().is_empty():
		in_finale = true
		finale_started.emit(Finale.lockdown_lines(GameState.player_name))
		return

	dean_arrived.emit(Dean.arrival_lines(strike_number, GameState.player_name), strike_number)
	_finish(EndReason.INCIDENT)

## The lockdown has played out; the night is over.
func end_finale() -> void:
	in_finale = false
	_finish(EndReason.INCIDENT)

func _finish(reason: EndReason) -> void:
	if shift_over:
		return
	shift_over = true
	shift_ended.emit(reason)

## Called by whatever owns the night once the shift-end scene is done.
func close_out() -> void:
	if GameState.run_over:
		return
	GameState.advance_shift()

## Test / debug helper: what is still waiting to go wrong.
func pending_incident_count() -> int:
	return _pending_incidents.size()
