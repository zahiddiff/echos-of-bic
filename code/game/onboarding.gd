extends RefCounted
class_name Onboarding

## Shift one, scripted beat for beat.

## Which rule each visitor teaches, in arrival order.
const LESSONS := [
	{"visitor": 1, "task": "schedule_lookup", "rule": Rulebook.Rule.NAME_MATCH},
	{"visitor": 2, "task": "id_reissue", "rule": Rulebook.Rule.ID_FORMAT},
	{"visitor": 3, "task": "enrollment_cert", "rule": Rulebook.Rule.PHOTO_MATCH},
	{"visitor": 4, "task": "transcript_print", "rule": -1},   # the walk itself
	{"visitor": 5, "task": "course_add_drop", "rule": Rulebook.Rule.COLLEGE_CODE},
	{"visitor": 6, "task": "address_change", "rule": Rulebook.Rule.VALIDITY_WINDOW},
	{"visitor": 7, "task": "work_permit", "rule": Rulebook.Rule.PRIOR_STAMP},
	{"visitor": 8, "task": "room_lookup", "rule": -1},        # flag training
]

const FLAG_TRAINING_VISITOR := 8

## Hand-picked so the teaching lines match the person standing there.
const NAMES := [
	"Nabila Hossain", "Jisoo Park", "Tasnim Ahmed", "Duc Tran",
	"Elena Petrova", "Kwame Mensah", "Priya Sharma", "Minho Choi",
]

## The eight visitors of shift one, in order.
static func build(rulebook: Rulebook, seed_value: int = 131313) -> Array[VisitorRequest]:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var maker := RequestGenerator.new(rulebook, rng)
	var writer := DialogueAuthor.new(rng)

	var queue: Array[VisitorRequest] = []
	for i in LESSONS.size():
		var lesson: Dictionary = LESSONS[i]
		var task := TaskPool.by_id(lesson["task"])
		var request := maker.clean_request(task)

		# Fixed names so Rahat's lines can refer to the person in front of you.
		var person: String = NAMES[i % NAMES.size()]
		request.visitor_name = person
		request.form_name = person
		request.id_name = person

		# Nothing is wrong on shift one, and nobody is a threat.
		request.wrongness = VisitorRequest.Wrongness.NONE
		request.is_threat = false
		request.threat_kind = ThreatType.Kind.NONE

		request.dialogue = writer.compose(request)
		queue.append(request)

	return queue

## Rules the player has been taught by the time visitor `number` walks up.
static func rules_known_at(number: int) -> Array[Rulebook.Rule]:
	var known: Array[Rulebook.Rule] = []
	for lesson: Dictionary in LESSONS:
		if int(lesson["visitor"]) > number:
			break
		var rule: int = lesson["rule"]
		if rule >= 0:
			known.append(rule as Rulebook.Rule)
	return known

## Does this visitor introduce a new rule, and which?
static func rule_taught_by(number: int) -> int:
	for lesson: Dictionary in LESSONS:
		if int(lesson["visitor"]) == number:
			return int(lesson["rule"])
	return -1

static func visitor_count() -> int:
	return LESSONS.size()

## After the last visitor, the player knows the whole rulebook and shift two runs with nothing suppressed.
static func all_rules_taught() -> bool:
	return rules_known_at(visitor_count()).size() == 6
