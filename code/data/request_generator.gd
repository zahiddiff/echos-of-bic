extends RefCounted
class_name RequestGenerator

## Builds one visitor's paperwork.

const PHOTO_SIZE := Vector2i(240, 300)

var rulebook: Rulebook
var rng: RandomNumberGenerator

## Rendering a face is ~72,000 GDScript pixel writes.
var generate_portraits: bool = true

func _init(p_rulebook: Rulebook, p_rng: RandomNumberGenerator) -> void:
	rulebook = p_rulebook
	rng = p_rng

## A visitor with flawless paperwork for the given task.
func clean_request(task: TaskPool.TaskType) -> VisitorRequest:
	var request := VisitorRequest.new()
	var person := NameBank.random_name(rng)

	request.visitor_name = person
	request.form_name = person
	request.id_name = person

	request.task_id = task.id
	request.task_label = task.label
	request.id_number = _valid_id_number()
	request.college_code = _valid_college_code()

	request.validity_days = [30, 60, 90, 180][rng.randi() % 4]
	request.issue_date = _valid_issue_date(request.validity_days)

	request.requires_prior_stamp = task.needs_prior_stamp
	request.has_prior_stamp = task.needs_prior_stamp

	request.photo_matches = true
	if generate_portraits:
		var face := PortraitFactory.traits_for(rng.randi())
		request.visitor_face = face
		request.id_face = face

	return request

## An ID number that satisfies rule 2 for the current enrollment window.
func _valid_id_number() -> String:
	var year := rng.randi_range(rulebook.min_enrollment_year, rulebook.max_enrollment_year)
	var serial := rng.randi_range(0, 999999)
	return "BIC-%02d-%06d" % [year, serial]

func _valid_college_code() -> String:
	var codes := rulebook.valid_college_codes
	return codes[rng.randi() % codes.size()]

## An issue date in the past whose validity window has not closed yet.
func _valid_issue_date(validity_days: int) -> String:
	var days_ago := rng.randi_range(0, maxi(validity_days - 1, 0))
	return shift_date(rulebook.current_date, -days_ago)

## ISO date arithmetic.
static func shift_date(iso_date: String, days: int) -> String:
	var unix := Time.get_unix_time_from_datetime_string(iso_date)
	var moved := unix + days * 86400
	return Time.get_datetime_string_from_unix_time(int(moved)).split("T")[0]
