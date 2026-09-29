extends RefCounted
class_name TaskPool

## The 20 visitor request types.

enum Category {
	DOCUMENTS_AND_ID,
	ACADEMIC,
	IMMIGRATION_AND_LEGAL,
	HOUSING_AND_LOGISTICS,
	GENERAL_ADMIN,
}

const CATEGORY_NAMES := {
	Category.DOCUMENTS_AND_ID: "Documents & ID",
	Category.ACADEMIC: "Academic",
	Category.IMMIGRATION_AND_LEGAL: "Immigration & Legal",
	Category.HOUSING_AND_LOGISTICS: "Housing & Logistics",
	Category.GENERAL_ADMIN: "General Admin & Services",
}

class TaskType extends RefCounted:
	var id: String
	var label: String
	var category: Category
	## True if completing it means leaving the desk (print room / mailroom).
	var physical: bool
	## True if the request cannot be processed without another office's approval stamp first — rule 6.
	var needs_prior_stamp: bool

	func _init(p_id: String, p_label: String, p_category: Category,
			p_physical: bool = false, p_needs_prior_stamp: bool = false) -> void:
		id = p_id
		label = p_label
		category = p_category
		physical = p_physical
		needs_prior_stamp = p_needs_prior_stamp

	func category_name() -> String:
		return CATEGORY_NAMES[category]

	func _to_string() -> String:
		return "%s (%s%s)" % [label, "physical" if physical else "desk",
			", prior stamp" if needs_prior_stamp else ""]

static func all() -> Array[TaskType]:
	var C := Category
	var tasks: Array[TaskType] = [
		# --- Documents & ID ---------------------------------------------
		TaskType.new("id_reissue", "ID card reissue", C.DOCUMENTS_AND_ID, true),
		TaskType.new("transcript_print", "Transcript printing", C.DOCUMENTS_AND_ID, true),
		TaskType.new("enrollment_cert", "Certificate of enrollment", C.DOCUMENTS_AND_ID, true),
		TaskType.new("graduation_cert", "Graduation certificate request", C.DOCUMENTS_AND_ID, false, true),
		TaskType.new("notarization", "Document notarization", C.DOCUMENTS_AND_ID, false, true),

		# --- Academic ----------------------------------------------------
		TaskType.new("schedule_lookup", "Class schedule lookup", C.ACADEMIC),
		TaskType.new("course_add_drop", "Course add/drop form", C.ACADEMIC),
		TaskType.new("room_lookup", "Building and room lookup", C.ACADEMIC),
		TaskType.new("exam_schedule", "Makeup exam request", C.ACADEMIC, false, true),
		TaskType.new("scholarship_check", "Scholarship submission check", C.ACADEMIC),

		# --- Immigration & Legal ------------------------------------------
		TaskType.new("visa_extension", "Visa extension paperwork", C.IMMIGRATION_AND_LEGAL, false, true),
		TaskType.new("residency_card", "Residency card renewal", C.IMMIGRATION_AND_LEGAL, false, true),
		TaskType.new("work_permit", "Part-time work permit", C.IMMIGRATION_AND_LEGAL, false, true),
		TaskType.new("address_change", "Address change registration", C.IMMIGRATION_AND_LEGAL),

		# --- Housing & Logistics ------------------------------------------
		TaskType.new("dorm_assignment", "Dorm assignment / transfer request", C.HOUSING_AND_LOGISTICS),
		TaskType.new("dorm_key", "Dorm key / access card issue", C.HOUSING_AND_LOGISTICS, true),
		TaskType.new("mail_pickup", "Package pickup from the mailroom", C.HOUSING_AND_LOGISTICS, true),

		# --- General Admin & Services -------------------------------------
		TaskType.new("bank_letter", "Bank account confirmation letter", C.GENERAL_ADMIN, true),
		TaskType.new("sim_letter", "Phone registration letter", C.GENERAL_ADMIN, true),
		TaskType.new("lost_and_found", "Lost and found inquiry", C.GENERAL_ADMIN),
	]
	return tasks

static func by_id(task_id: String) -> TaskType:
	for task in all():
		if task.id == task_id:
			return task
	return null

static func physical_tasks() -> Array[TaskType]:
	var found: Array[TaskType] = []
	for task in all():
		if task.physical:
			found.append(task)
	return found

static func desk_tasks() -> Array[TaskType]:
	var found: Array[TaskType] = []
	for task in all():
		if not task.physical:
			found.append(task)
	return found
