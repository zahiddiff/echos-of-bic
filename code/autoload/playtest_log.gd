extends Node

## Playtest record (autoload: PlaytestLog). What each visitor was, what the player did, how long it took.
## Stays on the machine; nothing is sent anywhere. Players export it themselves from the pause menu.

const FORMAT := 1
const LOG_DIR := "user://playtest"

## Playtest mode: post-shift questions and the export button. `?playtest` on the web, `--playtest` on desktop.
var questionnaire: bool = false
## Written to disk after every shift. Off headless, so test runs leave nothing behind.
var persist: bool = true

var session: Dictionary = {}
var _shift: Dictionary = {}
var _visitor: Dictionary = {}
var _visitor_request: VisitorRequest
var _seated_since: int = -1
var _pending_decision: int = -1

func _ready() -> void:
	persist = DisplayServer.get_name() != "headless"
	questionnaire = _playtest_requested()
	if questionnaire:
		print("[playtest] mode on, logging to %s" % ProjectSettings.globalize_path(LOG_DIR))
	start_session()

func _playtest_requested() -> bool:
	if OS.get_cmdline_user_args().has("--playtest") or OS.get_cmdline_args().has("--playtest"):
		return true
	if OS.has_feature("web"):
		var search: Variant = JavaScriptBridge.eval("window.location.search", true)
		return search is String and (search as String).contains("playtest")
	return false

func start_session() -> void:
	session = {
		"format": FORMAT,
		"id": "%08x%04x" % [randi(), randi() % 0x10000],
		"started": Time.get_datetime_string_from_system(true),
		"platform": OS.get_name(),
		"playtest_mode": questionnaire,
		"shifts": [],
		"ending": "",
	}
	_shift = {}
	_visitor = {}

# --- Shifts ------------------------------------------------------------------------

func begin_shift(shift: int, onboarding: bool, queue_size: int, strikes_left: int) -> void:
	_close_visitor()
	_shift = {
		"shift": shift,
		"onboarding": onboarding,
		"queue_size": queue_size,
		"strikes_left_at_start": strikes_left,
		"started_ms": Time.get_ticks_msec(),
		"seconds": 0.0,
		"visitors": [],
		"events": [],
		"end_reason": "",
		"feedback": {},
	}
	(session["shifts"] as Array).append(_shift)

func end_shift(reason: String, strikes_left: int) -> void:
	if _shift.is_empty():
		return
	_close_visitor()
	_shift["end_reason"] = reason
	_shift["strikes_left_at_end"] = strikes_left
	_shift["seconds"] = _seconds_since(int(_shift["started_ms"]))
	save()

## Answers to the post-shift questions, attached to the shift just finished.
func shift_feedback(answers: Dictionary) -> void:
	if _shift.is_empty():
		return
	_shift["feedback"] = answers
	save()

func end_run(ending: String) -> void:
	session["ending"] = ending
	save()

func event(kind: String, detail: Dictionary = {}) -> void:
	if _shift.is_empty():
		return
	var entry := {"kind": kind, "at": _seconds_since(int(_shift["started_ms"]))}
	entry.merge(detail)
	(_shift["events"] as Array).append(entry)

# --- Visitors ----------------------------------------------------------------------

## Their papers are on the desk. Called again if the player stands and sits back down.
func visitor_shown(request: VisitorRequest, index: int) -> void:
	if request != _visitor_request:
		_close_visitor()
		_visitor_request = request
		_visitor = {
			"index": index,
			"task": request.task_id,
			"wrongness": VisitorRequest.Wrongness.keys()[request.wrongness],
			"threat": ThreatType.Kind.keys()[request.threat_kind] if request.is_threat else "",
			"shown_ms": Time.get_ticks_msec(),
			"seconds_at_desk": 0.0,
			"follow_ups": 0,
			"magnified": false,
			"looked_up": false,
			"decision": "",
			"verdict": "",
			"broken_rules": [],
		}
	seated()

func seated() -> void:
	if not _visitor.is_empty() and _seated_since < 0:
		_seated_since = Time.get_ticks_msec()

func stood_up() -> void:
	if _seated_since >= 0 and not _visitor.is_empty():
		_visitor["seconds_at_desk"] = float(_visitor["seconds_at_desk"]) + _seconds_since(_seated_since)
	_seated_since = -1

## Something the player did while looking at this visitor: "follow_up", "magnifier", "lookup".
func note(what: String) -> void:
	if _visitor.is_empty():
		return
	match what:
		"follow_up":
			_visitor["follow_ups"] = int(_visitor["follow_ups"]) + 1
		"magnifier":
			_visitor["magnified"] = true
		"lookup":
			_visitor["looked_up"] = true

func decision_made(decision: int) -> void:
	_pending_decision = decision

func decision_judged(request: VisitorRequest, verdict: int, broken: PackedStringArray) -> void:
	if request != _visitor_request or _visitor.is_empty():
		# Decided without the papers ever being opened (tests, bots).
		visitor_shown(request, -1)
	stood_up()
	_visitor["decision"] = ["APPROVE", "REJECT", "FLAG"][_pending_decision] if _pending_decision >= 0 else ""
	_visitor["verdict"] = DecisionJudge.Verdict.keys()[verdict]
	_visitor["broken_rules"] = Array(broken)
	_visitor["seconds_total"] = _seconds_since(int(_visitor["shown_ms"]))
	_pending_decision = -1
	_close_visitor()
	# A tester who closes the tab mid-shift still leaves everything up to here.
	save()

func _close_visitor() -> void:
	if _visitor.is_empty():
		return
	stood_up()
	if not _shift.is_empty() and not str(_visitor.get("verdict", "")).is_empty():
		var record := _visitor.duplicate()
		record.erase("shown_ms")
		(_shift["visitors"] as Array).append(record)
	_visitor = {}
	_visitor_request = null

# --- Output --------------------------------------------------------------------------

func to_json() -> String:
	var copy := session.duplicate(true)
	for shift in copy["shifts"]:
		shift.erase("started_ms")
	return JSON.stringify(copy, "  ")

func file_path() -> String:
	return "%s/session-%s.json" % [LOG_DIR, session.get("id", "unknown")]

func save() -> void:
	if not persist:
		return
	DirAccess.make_dir_recursive_absolute(LOG_DIR)
	var file := FileAccess.open(file_path(), FileAccess.WRITE)
	if file:
		file.store_string(to_json())

## Hand the log to the player: a download in the browser, the folder on desktop.
func export_log() -> String:
	save()
	if OS.has_feature("web"):
		JavaScriptBridge.download_buffer(to_json().to_utf8_buffer(),
			"echoes-of-bic-playtest-%s.json" % session.get("id", ""), "application/json")
		return "downloaded"
	var folder := ProjectSettings.globalize_path(LOG_DIR)
	OS.shell_open(folder)
	return folder

func _seconds_since(ms: int) -> float:
	return snappedf((Time.get_ticks_msec() - ms) / 1000.0, 0.1)
