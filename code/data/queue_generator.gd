extends RefCounted
class_name QueueGenerator

## Builds one shift's visitor queue.

## Fraction of non-threat visitors that carry ordinary (non-threat) wrongness.
const MUNDANE_WRONGNESS_SHARE := 0.30

var rulebook: Rulebook
var rng := RandomNumberGenerator.new()

## Off for headless balance runs; see RequestGenerator.generate_portraits.
var generate_portraits: bool = true:
	set(value):
		generate_portraits = value
		if _requests:
			_requests.generate_portraits = value
		if _wrongness:
			_wrongness.generate_portraits = value

var _requests: RequestGenerator
var _wrongness: WrongnessAuthor
var _dialogue: DialogueAuthor

func _init(p_rulebook: Rulebook, seed_value: int = 0) -> void:
	rulebook = p_rulebook
	rng.seed = seed_value
	_requests = RequestGenerator.new(rulebook, rng)
	_wrongness = WrongnessAuthor.new(rulebook, rng)
	_dialogue = DialogueAuthor.new(rng)

## The queue for one shift, in the order visitors arrive.
func build_shift(shift: int) -> Array[VisitorRequest]:
	var visitor_count := ShiftSchedule.visitors_for(shift)
	var threat_count := ShiftSchedule.threats_for(shift)
	var difficulty := ShiftSchedule.difficulty_for(shift)

	var tasks := _draw_tasks(visitor_count)
	var queue: Array[VisitorRequest] = []
	for task in tasks:
		queue.append(_requests.clean_request(task))

	# Onboarding teaches systems in isolation; nothing is wrong on shift one.
	if not ShiftSchedule.is_onboarding(shift):
		for index in _pick_slots(queue.size(), threat_count):
			queue[index] = _make_threat(queue[index])
		_author_wrongness(queue, difficulty)

	# Dialogue last: what someone says depends on whether they have something to hide, so it can only be written once the queue is settled.
	for request in queue:
		request.dialogue = _dialogue.compose(request)

	return queue

## Turn a queue slot into a threat.
func _make_threat(original: VisitorRequest) -> VisitorRequest:
	var kind := ThreatType.pick_random(rng)
	var covers := ThreatType.cover_task_ids(kind)

	var request := original
	if not covers.is_empty() and not covers.has(original.task_id):
		var cover_id: String = covers[rng.randi() % covers.size()]
		var task := TaskPool.by_id(cover_id)
		if task:
			request = _requests.clean_request(task)

	request.is_threat = true
	request.threat_kind = kind
	return request

## Task draw: no repeats until the pool is exhausted, then it wraps.
func _draw_tasks(count: int) -> Array[TaskPool.TaskType]:
	var pool := TaskPool.all()
	var drawn: Array[TaskPool.TaskType] = []
	var remaining := pool.duplicate()
	while drawn.size() < count:
		if remaining.is_empty():
			remaining = pool.duplicate()
		var index := rng.randi() % remaining.size()
		drawn.append(remaining[index])
		remaining.remove_at(index)
	return drawn

## `count` distinct indices in 0..size-1, spread rather than clustered.
func _pick_slots(size: int, count: int) -> Array[int]:
	var chosen: Array[int] = []
	if size <= 0 or count <= 0:
		return chosen

	var wanted := mini(count, size)
	# Deal one slot per equal-sized band so threats never all land together.
	var band := float(size) / float(wanted)
	for i in wanted:
		var low := int(floor(i * band))
		var high := int(floor((i + 1) * band)) - 1
		high = maxi(high, low)
		high = mini(high, size - 1)
		var pick := rng.randi_range(low, high)
		while chosen.has(pick):
			pick = (pick + 1) % size
		chosen.append(pick)
	chosen.sort()
	return chosen

func _author_wrongness(queue: Array[VisitorRequest], difficulty: float) -> void:
	var repetition_done := false

	for request in queue:
		if request.is_threat:
			# A threat's paperwork is nearly always the thing that betrays them — but not always, which is why behaviour matters too.
			if rng.randf() < 0.8:
				_wrongness.apply(request, _pick_threat_wrongness(), difficulty)
			continue

		if rng.randf() < MUNDANE_WRONGNESS_SHARE:
			_wrongness.apply(request, _pick_mundane_wrongness(), difficulty)

	# Repetition needs two visitors, so it is authored across the queue.
	if queue.size() >= 4 and rng.randf() < 0.5:
		repetition_done = _author_repetition(queue)
	var _unused := repetition_done

## The same ID number turning up under two different names in one shift.
func _author_repetition(queue: Array[VisitorRequest]) -> bool:
	var first := rng.randi_range(0, queue.size() - 3)
	var second := rng.randi_range(first + 2, queue.size() - 1)

	var earlier := queue[first]
	var later := queue[second]
	if later.wrongness != VisitorRequest.Wrongness.NONE:
		return false

	later.id_number = earlier.id_number
	later.wrongness = VisitorRequest.Wrongness.REPETITION
	return true

func _pick_threat_wrongness() -> VisitorRequest.Wrongness:
	# Threats are people pretending to be someone entitled to something, so identity problems dominate.
	var roll := rng.randf()
	if roll < 0.55:
		return VisitorRequest.Wrongness.IDENTITY
	if roll < 0.85:
		return VisitorRequest.Wrongness.DATA
	return VisitorRequest.Wrongness.PHYSICAL

func _pick_mundane_wrongness() -> VisitorRequest.Wrongness:
	# Ordinary people mostly get dates and codes wrong, not their own faces.
	var roll := rng.randf()
	if roll < 0.6:
		return VisitorRequest.Wrongness.DATA
	if roll < 0.85:
		return VisitorRequest.Wrongness.PHYSICAL
	return VisitorRequest.Wrongness.IDENTITY
