extends RefCounted
class_name PlaytestAnalysis

## Turns PlaytestLog sessions into numbers and a balance report.

## Working targets. The design gives the miss rate ("a careful player can miss roughly 1 in 4");
## the rest are starting guesses to revise once real sessions come in.
const TARGETS := {
	"miss_rate": Vector2(0.15, 0.35),
	"false_flag_rate": Vector2(0.0, 0.10),
	"processing_error_rate": Vector2(0.0, 0.15),
	"seconds_per_visitor": Vector2(25.0, 75.0),
	"shift_minutes": Vector2(6.0, 18.0),
}

## Aggregate every visitor across every session.
static func summarise(sessions: Array) -> Dictionary:
	var s := {
		"sessions": sessions.size(),
		"shifts": 0,
		"visitors": 0,
		"endings": {},
		"threats": 0, "threats_caught": 0, "threats_missed": 0,
		"innocents": 0, "false_flags": 0,
		"processing": 0, "processing_errors": 0,
		"by_threat": {},
		"by_wrongness": {},
		"by_shift": {},
		"early_ends": {},
		"seconds": [],
		"follow_up_threats": [0, 0],
		"no_follow_up_threats": [0, 0],
		"tool_use": {"follow_up": 0, "magnifier": 0, "lookup": 0},
		"notes": [],
	}
	for session: Dictionary in sessions:
		var ending := str(session.get("ending", ""))
		if not ending.is_empty():
			s["endings"][ending] = int(s["endings"].get(ending, 0)) + 1
		for shift: Dictionary in session.get("shifts", []):
			_add_shift(s, shift)
	return s

static func _add_shift(s: Dictionary, shift: Dictionary) -> void:
	s["shifts"] += 1
	var number := int(shift.get("shift", 0))
	var row: Dictionary = s["by_shift"].get(number, {
		"shifts": 0, "visitors": 0, "seconds": 0.0, "tension": [], "misses": 0, "threats": 0})
	row["shifts"] += 1
	row["seconds"] += float(shift.get("seconds", 0.0))
	var reason := str(shift.get("end_reason", ""))
	if reason != "" and reason != "QUEUE_FINISHED":
		s["early_ends"][reason] = int(s["early_ends"].get(reason, 0)) + 1
	var feedback: Dictionary = shift.get("feedback", {})
	if int(feedback.get("tension", 0)) > 0:
		row["tension"].append(int(feedback["tension"]))
	for key in ["felt_fake", "confusing"]:
		var text := str(feedback.get(key, ""))
		if not text.is_empty():
			s["notes"].append("shift %d, %s: %s" % [number, key.replace("_", " "), text])

	for v: Dictionary in shift.get("visitors", []):
		s["visitors"] += 1
		row["visitors"] += 1
		var verdict := str(v.get("verdict", ""))
		var threat := str(v.get("threat", ""))
		var wrongness := str(v.get("wrongness", "NONE"))
		if float(v.get("seconds_total", 0.0)) > 0.0:
			s["seconds"].append(float(v["seconds_total"]))
		if int(v.get("follow_ups", 0)) > 0:
			s["tool_use"]["follow_up"] += 1
		if v.get("magnified", false):
			s["tool_use"]["magnifier"] += 1
		if v.get("looked_up", false):
			s["tool_use"]["lookup"] += 1

		if not threat.is_empty():
			s["threats"] += 1
			row["threats"] += 1
			var caught := verdict == "CORRECT"
			var t: Dictionary = s["by_threat"].get(threat, {"seen": 0, "missed": 0})
			t["seen"] += 1
			if caught:
				s["threats_caught"] += 1
			else:
				s["threats_missed"] += 1
				t["missed"] += 1
				row["misses"] += 1
			s["by_threat"][threat] = t
			var bucket: Array = s["follow_up_threats"] if int(v.get("follow_ups", 0)) > 0 else s["no_follow_up_threats"]
			bucket[0] += 1
			if caught:
				bucket[1] += 1
		else:
			s["innocents"] += 1
			if verdict == "FALSE_FLAG":
				s["false_flags"] += 1
			else:
				s["processing"] += 1
				var w: Dictionary = s["by_wrongness"].get(wrongness, {"seen": 0, "errors": 0})
				w["seen"] += 1
				if verdict == "PROCESSING_ERROR":
					s["processing_errors"] += 1
					w["errors"] += 1
				s["by_wrongness"][wrongness] = w
	s["by_shift"][number] = row

static func rate(part: float, whole: float) -> float:
	return part / whole if whole > 0.0 else 0.0

static func rates(s: Dictionary) -> Dictionary:
	var seconds: Array = s["seconds"]
	var total_seconds := 0.0
	for x in seconds:
		total_seconds += float(x)
	var shift_seconds := 0.0
	var shift_count := 0
	for row: Dictionary in s["by_shift"].values():
		shift_seconds += float(row["seconds"])
		shift_count += int(row["shifts"])
	return {
		"miss_rate": rate(s["threats_missed"], s["threats"]),
		"false_flag_rate": rate(s["false_flags"], s["innocents"]),
		"processing_error_rate": rate(s["processing_errors"], s["processing"]),
		"seconds_per_visitor": rate(total_seconds, seconds.size()),
		"shift_minutes": rate(shift_seconds, shift_count) / 60.0,
	}

## Plain suggestions, each naming the constant to change.
static func recommendations(s: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	var r := rates(s)
	if s["threats"] < 10:
		out.append("Fewer than 10 threat encounters logged; treat every rate below as noise until more sessions come in.")

	var miss: float = r["miss_rate"]
	if s["threats"] > 0 and miss > TARGETS["miss_rate"].y:
		out.append("Threats get through %d%% of the time (target %d-%d%%). Make tells easier to read: raise DialogueAuthor.THREAT_TELL_CHANCE (now %.2f) or start ShiftSchedule.difficulty_for() higher." %
			[roundi(miss * 100), roundi(TARGETS["miss_rate"].x * 100), roundi(TARGETS["miss_rate"].y * 100), DialogueAuthor.THREAT_TELL_CHANCE])
	elif s["threats"] > 0 and miss < TARGETS["miss_rate"].x:
		out.append("Threats are caught %d%% of the time, above the design's intent. Lower DialogueAuthor.THREAT_TELL_CHANCE (now %.2f) or tighten ShiftSchedule.difficulty_for() sooner." %
			[roundi((1.0 - miss) * 100), DialogueAuthor.THREAT_TELL_CHANCE])

	var false_rate: float = r["false_flag_rate"]
	if s["innocents"] > 0 and false_rate > TARGETS["false_flag_rate"].y:
		out.append("Security is called on %d%% of innocent visitors. If testers say innocents looked suspicious, lower DialogueAuthor.INNOCENT_TELL_CHANCE (now %.2f)." %
			[roundi(false_rate * 100), DialogueAuthor.INNOCENT_TELL_CHANCE])

	for kind: String in s["by_threat"]:
		var t: Dictionary = s["by_threat"][kind]
		var kind_miss := rate(t["missed"], t["seen"])
		if t["seen"] >= 4 and kind_miss > miss + 0.2:
			out.append("%s is missed %d%% of the time against %d%% overall; its tells or probing follow-up in ThreatType may be too quiet." %
				[kind.capitalize(), roundi(kind_miss * 100), roundi(miss * 100)])

	for kind: String in s["by_wrongness"]:
		var w: Dictionary = s["by_wrongness"][kind]
		var err := rate(w["errors"], w["seen"])
		if w["seen"] >= 5 and err > TARGETS["processing_error_rate"].y + 0.1:
			out.append("Paperwork with %s wrongness is misjudged %d%% of the time; WrongnessAuthor may be making it too subtle." %
				[kind.capitalize(), roundi(err * 100)])

	var per_visitor: float = r["seconds_per_visitor"]
	if per_visitor > TARGETS["seconds_per_visitor"].y:
		out.append("A visitor takes %d s on average; shifts will drag. Consider fewer visitors in ShiftSchedule.visitors_for()." % per_visitor)
	elif per_visitor > 0.0 and per_visitor < TARGETS["seconds_per_visitor"].x:
		out.append("A visitor takes only %d s on average; players may be skimming. Check the magnifier and follow-up use below." % per_visitor)

	var fu: Array = s["follow_up_threats"]
	var nfu: Array = s["no_follow_up_threats"]
	if fu[0] >= 4 and nfu[0] >= 4 and rate(fu[1], fu[0]) <= rate(nfu[1], nfu[0]):
		out.append("Asking a follow-up does not improve the catch rate; the probing questions may not be revealing enough.")

	var early: Array = []
	var late: Array = []
	for number: int in s["by_shift"]:
		var tension: Array = s["by_shift"][number]["tension"]
		if number <= 3:
			early.append_array(tension)
		elif number >= 6:
			late.append_array(tension)
	if early.size() >= 3 and late.size() >= 3 and _mean(late) <= _mean(early):
		out.append("Reported tension does not rise from early to late shifts (%.1f -> %.1f); the late-game beats are not landing." % [_mean(early), _mean(late)])

	if out.is_empty():
		out.append("Everything measured is inside the working targets.")
	return out

static func _mean(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var total := 0.0
	for v in values:
		total += float(v)
	return total / values.size()

static func _pct(value: float) -> String:
	return "%d%%" % roundi(value * 100.0)

static func to_markdown(s: Dictionary, title: String = "Playtest report") -> String:
	var r := rates(s)
	var md := PackedStringArray()
	md.append("# %s" % title)
	md.append("")
	md.append("%d sessions, %d shifts, %d visitors, %d threat encounters." % [s["sessions"], s["shifts"], s["visitors"], s["threats"]])
	if not (s["endings"] as Dictionary).is_empty():
		md.append("Endings: %s." % ", ".join(PackedStringArray((s["endings"] as Dictionary).keys().map(
			func(k: String) -> String: return "%s %d" % [k, s["endings"][k]]))))
	md.append("")
	md.append("## Against the targets")
	md.append("")
	md.append("| Measure | Result | Target |")
	md.append("|---|---|---|")
	md.append("| Threats missed | %s | %s-%s |" % [_pct(r["miss_rate"]), _pct(TARGETS["miss_rate"].x), _pct(TARGETS["miss_rate"].y)])
	md.append("| Innocents flagged | %s | under %s |" % [_pct(r["false_flag_rate"]), _pct(TARGETS["false_flag_rate"].y)])
	md.append("| Paperwork misjudged | %s | under %s |" % [_pct(r["processing_error_rate"]), _pct(TARGETS["processing_error_rate"].y)])
	md.append("| Seconds per visitor | %d | %d-%d |" % [r["seconds_per_visitor"], TARGETS["seconds_per_visitor"].x, TARGETS["seconds_per_visitor"].y])
	md.append("| Minutes per shift | %.1f | %d-%d |" % [r["shift_minutes"], TARGETS["shift_minutes"].x, TARGETS["shift_minutes"].y])
	md.append("")
	md.append("## Suggestions")
	md.append("")
	for line in recommendations(s):
		md.append("- %s" % line)
	md.append("")
	md.append("## By shift")
	md.append("")
	md.append("| Shift | Played | Visitors | Threats | Missed | Avg minutes | Tension |")
	md.append("|---|---|---|---|---|---|---|")
	var numbers: Array = (s["by_shift"] as Dictionary).keys()
	numbers.sort()
	for number in numbers:
		var row: Dictionary = s["by_shift"][number]
		var tension: Array = row["tension"]
		md.append("| %d | %d | %d | %d | %d | %.1f | %s |" % [number, row["shifts"], row["visitors"], row["threats"],
			row["misses"], rate(row["seconds"], row["shifts"]) / 60.0, "%.1f" % _mean(tension) if not tension.is_empty() else "-"])
	md.append("")
	md.append("## Threat types")
	md.append("")
	for kind: String in s["by_threat"]:
		var t: Dictionary = s["by_threat"][kind]
		md.append("- %s: missed %d of %d (%s)" % [kind.capitalize(), t["missed"], t["seen"], _pct(rate(t["missed"], t["seen"]))])
	md.append("- With a follow-up asked: caught %d of %d. Without: caught %d of %d." %
		[s["follow_up_threats"][1], s["follow_up_threats"][0], s["no_follow_up_threats"][1], s["no_follow_up_threats"][0]])
	md.append("")
	md.append("## Paperwork")
	md.append("")
	for kind: String in s["by_wrongness"]:
		var w: Dictionary = s["by_wrongness"][kind]
		md.append("- %s: misjudged %d of %d" % [kind.capitalize(), w["errors"], w["seen"]])
	var tools: Dictionary = s["tool_use"]
	md.append("- Tools used per visitor: follow-up %s, magnifier %s, records lookup %s." % [
		_pct(rate(tools["follow_up"], s["visitors"])), _pct(rate(tools["magnifier"], s["visitors"])),
		_pct(rate(tools["lookup"], s["visitors"]))])
	if not (s["early_ends"] as Dictionary).is_empty():
		md.append("- Shifts ended early: %s" % str(s["early_ends"]))
	if not (s["notes"] as Array).is_empty():
		md.append("")
		md.append("## What testers wrote")
		md.append("")
		for note in s["notes"]:
			md.append("- %s" % note)
	return "\n".join(md) + "\n"
