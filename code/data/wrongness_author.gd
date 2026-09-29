extends RefCounted
class_name WrongnessAuthor

## Breaks exactly one thing in a clean request.

const PHOTO_SIZE := Vector2i(240, 300)

var rulebook: Rulebook
var rng: RandomNumberGenerator
var generate_portraits: bool = true

func _init(p_rulebook: Rulebook, p_rng: RandomNumberGenerator) -> void:
	rulebook = p_rulebook
	rng = p_rng

## Apply a wrongness type in place.
func apply(request: VisitorRequest, kind: VisitorRequest.Wrongness,
		difficulty: float = 0.5) -> void:
	request.wrongness = kind
	match kind:
		VisitorRequest.Wrongness.IDENTITY:
			_identity(request, difficulty)
		VisitorRequest.Wrongness.DATA:
			_data(request)
		VisitorRequest.Wrongness.PHYSICAL:
			_physical(request)
		VisitorRequest.Wrongness.REPETITION:
			# Repetition only means anything across a queue, so the queue generator authors it.
			pass
		_:
			request.wrongness = VisitorRequest.Wrongness.NONE

# --- Identity ----------------------------------------------------------------
# The visitor doesn't hold up: the name, the number or the face is wrong.

func _identity(request: VisitorRequest, difficulty: float) -> void:
	match rng.randi() % 3:
		0:
			# The name on the card doesn't match the form (rule 1).
			request.id_name = NameBank.near_miss(request.form_name, rng)
		1:
			# The ID number is malformed or out of the enrollment window (rule 2).
			if rng.randf() < 0.5:
				var bad_year := rulebook.max_enrollment_year + rng.randi_range(1, 4)
				request.id_number = "BIC-%02d-%06d" % [bad_year % 100, rng.randi_range(0, 999999)]
			else:
				# Five digits instead of six — the kind of thing you skim past.
				request.id_number = "BIC-%02d-%05d" % [
					rng.randi_range(rulebook.min_enrollment_year, rulebook.max_enrollment_year),
					rng.randi_range(0, 99999)]
		_:
			# The photo isn't them (rule 4).
			request.photo_matches = false
			if generate_portraits:
				var face := PortraitFactory.traits_for(rng.randi())
				request.visitor_portrait = PortraitFactory.render(face, PHOTO_SIZE)
				request.id_photo = PortraitFactory.render(
					PortraitFactory.variant_of(face, rng.randi(), difficulty), PHOTO_SIZE)

# --- Data --------------------------------------------------------------------
# The paperwork is internally impossible, or contradicts the record on file.

func _data(request: VisitorRequest) -> void:
	match rng.randi() % 3:
		0:
			# Expired (rule 5) — the window closed while they sat on it.
			var overdue := rng.randi_range(1, 60)
			request.issue_date = RequestGenerator.shift_date(
				rulebook.current_date, -(request.validity_days + overdue))
		1:
			# Issued tomorrow.
			request.issue_date = RequestGenerator.shift_date(
				rulebook.current_date, rng.randi_range(1, 14))
		_:
			# A college code that isn't on the desk list (rule 3).
			request.college_code = ["ZZ", "QRS", "N/A", "—", "GEN"][rng.randi() % 5]

# --- Physical ----------------------------------------------------------------
# Something about the request changes while the player is away from the desk.

func _physical(request: VisitorRequest) -> void:
	var task := TaskPool.by_id(request.task_id)
	if task == null or not task.physical:
		_data(request)
		request.wrongness = VisitorRequest.Wrongness.DATA
		return

	# The prior stamp that was on the form when they handed it over is not on the form that comes back (rule 6).
	request.requires_prior_stamp = true
	request.has_prior_stamp = false

## Was this request's wrongness one the Rulebook can actually see?
static func is_rulebook_visible(kind: VisitorRequest.Wrongness) -> bool:
	return kind == VisitorRequest.Wrongness.IDENTITY \
		or kind == VisitorRequest.Wrongness.DATA \
		or kind == VisitorRequest.Wrongness.PHYSICAL
