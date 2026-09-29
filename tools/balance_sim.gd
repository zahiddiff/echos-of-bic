extends Node

## Plays whole runs with scripted players and reports what happens, to check the numbers in the design actually hold up.
## Run: godot --headless --path <project> res://tools/balance_sim.tscn

const RUNS := 40

var _failures := 0
var _book: Rulebook

func _ready() -> void:
	_book = Rulebook.new()
	_book.current_date = "2026-09-17"
	_run()

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("  ok    %s" % message)
	else:
		_failures += 1
		print("  FAIL  %s" % message)

## How a scripted player behaves.
class Player extends RefCounted:
	var label: String
	var threat_catch: float
	var false_flag_rate: float
	var follows_rulebook: bool

	func _init(p_label: String, p_catch: float, p_false: float, p_rules: bool = true) -> void:
		label = p_label
		threat_catch = p_catch
		false_flag_rate = p_false
		follows_rulebook = p_rules

func _decide(player: Player, request: VisitorRequest, rng: RandomNumberGenerator) -> int:
	if request.is_threat:
		if rng.randf() < player.threat_catch:
			return DecisionJudge.FLAG
		# Missed it — they process the paperwork like anyone else.
		return DecisionJudge.REJECT if (player.follows_rulebook and DecisionJudge.was_catchable_at_desk(request, _book)) \
			else DecisionJudge.APPROVE

	if rng.randf() < player.false_flag_rate:
		return DecisionJudge.FLAG
	if player.follows_rulebook and DecisionJudge.was_catchable_at_desk(request, _book):
		return DecisionJudge.REJECT
	return DecisionJudge.APPROVE

## One full 8-shift run.
func _play_run(player: Player, seed_value: int) -> Dictionary:
	GameState.reset()
	GameState.set_player_name("Sim")

	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value

	var runner := ShiftRunner.new()
	runner.rulebook = _book
	runner.generate_portraits = false
	add_child(runner)

	var threats_seen := 0
	var threats_missed := 0
	var shifts_played := 0

	while not GameState.run_over and shifts_played < ShiftSchedule.TOTAL_SHIFTS:
		runner.start(GameState.shift, rng.randi())
		shifts_played += 1

		var guard := 0
		while not runner.shift_over and runner.current() != null and guard < 40:
			var visitor := runner.current()
			if visitor.is_threat:
				threats_seen += 1
			var decision := _decide(player, visitor, rng)
			if visitor.is_threat and decision != DecisionJudge.FLAG:
				threats_missed += 1
			runner.resolve(decision)
			guard += 1

		if GameState.run_over:
			break
		GameState.advance_shift()

	var summary := {
		"ending": GameState.ending,
		"strikes": GameState.strikes_taken,
		"false_flags": GameState.false_flags,
		"threats_seen": threats_seen,
		"threats_missed": threats_missed,
		"shifts": shifts_played,
	}
	runner.queue_free()
	return summary

func _report(player: Player) -> Dictionary:
	var endings := {GameState.Ending.FIRED: 0, GameState.Ending.STANDARD: 0, GameState.Ending.TRUE_END: 0}
	var total_threats := 0
	var total_missed := 0
	var total_strikes := 0

	for i in RUNS:
		var summary := _play_run(player, 7000 + i * 13)
		endings[summary["ending"]] = endings[summary["ending"]] + 1
		total_threats += summary["threats_seen"]
		total_missed += summary["threats_missed"]
		total_strikes += summary["strikes"]

	var avg_threats := float(total_threats) / RUNS
	print("  %-22s fired %2d | standard %2d | true %2d   (threats/run %.1f, missed %.1f, strikes %.1f)"
		% [player.label, endings[GameState.Ending.FIRED], endings[GameState.Ending.STANDARD],
			endings[GameState.Ending.TRUE_END], avg_threats,
			float(total_missed) / RUNS, float(total_strikes) / RUNS])

	return {"endings": endings, "avg_threats": avg_threats}

func _run() -> void:
	print("Balance simulation — %d runs per player\n" % RUNS)

	print(" Endings by play style")
	var perfect := _report(Player.new("Reads everyone", 1.0, 0.0))
	var careful := _report(Player.new("Catches 3 in 4", 0.75, 0.02))
	var sloppy := _report(Player.new("Catches 1 in 2", 0.5, 0.05))
	var rules_only := _report(Player.new("Rulebook, never flags", 0.0, 0.0))
	var paranoid := _report(Player.new("Flags everyone", 1.0, 1.0))

	print("\n What the design claims")

	_expect(perfect["endings"][GameState.Ending.TRUE_END] == RUNS,
		"a player who flags every threat always gets the True ending")

	_expect(rules_only["endings"][GameState.Ending.FIRED] == RUNS,
		"following the rulebook alone is never enough — you always get fired")

	_expect(paranoid["endings"][GameState.Ending.FIRED] == 0,
		"flagging everyone survives — false flags cost standing and the night, not strikes")

	_expect(paranoid["endings"][GameState.Ending.TRUE_END] == 0,
		"flagging everyone can no longer reach the True ending")

	var careful_standard: int = careful["endings"][GameState.Ending.STANDARD]
	var careful_true: int = careful["endings"][GameState.Ending.TRUE_END]
	var careful_survives := careful_standard + careful_true
	_expect(careful_survives >= int(RUNS * 0.6),
		"catching 3 in 4 usually finishes the run (%d of %d)" % [careful_survives, RUNS])

	var sloppy_fired: int = sloppy["endings"][GameState.Ending.FIRED]
	_expect(sloppy_fired >= int(RUNS * 0.5),
		"catching only half is usually not enough (%d of %d fired)" % [sloppy_fired, RUNS])

	_expect(perfect["avg_threats"] >= 17.0 and perfect["avg_threats"] <= 21.0,
		"a full run really does contain ~20 threat encounters (%.1f)" % perfect["avg_threats"])

	print("")
	if _failures == 0:
		print("BALANCE SIM PASSED")
	else:
		print("BALANCE SIM FAILED (%d problem(s))" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)
