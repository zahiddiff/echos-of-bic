extends Resource
class_name Rulebook

## The six document-validation rules.

enum Rule {
	NAME_MATCH,       ## 1 — form name must match the ID card exactly
	ID_FORMAT,        ## 2 — BIC-YY-NNNNNN, YY inside the valid enrollment range
	COLLEGE_CODE,     ## 3 — code must be on the desk reference list
	PHOTO_MATCH,      ## 4 — ID photo must be the person standing there
	VALIDITY_WINDOW,  ## 5 — issue date + validity window vs today's date
	PRIOR_STAMP,      ## 6 — some requests need another office's stamp first
}

const RULE_TITLES := {
	Rule.NAME_MATCH: "Name match",
	Rule.ID_FORMAT: "ID number format",
	Rule.COLLEGE_CODE: "College code",
	Rule.PHOTO_MATCH: "Photo match",
	Rule.VALIDITY_WINDOW: "Expiry & validity window",
	Rule.PRIOR_STAMP: "Required prior stamp",
}

const ID_PATTERN := "^BIC-([0-9]{2})-([0-9]{6})$"

@export_group("Desk reference")
## The short department list printed on the desk (rule 3).
@export var valid_college_codes: PackedStringArray = PackedStringArray([
	"ENG", "BUS", "SCI", "LAW", "MED", "ART", "EDU",
])
## Two-digit enrollment years currently considered in range (rule 2).
@export var min_enrollment_year: int = 19
@export var max_enrollment_year: int = 26
## In-game today, ISO "YYYY-MM-DD".
@export var current_date: String = "2026-09-17"

@export_group("Onboarding")
## Rules the player has been taught so far.
@export var enabled_rules: Array[Rule] = []

var _id_regex: RegEx

## One rule's verdict on one request.
class Finding extends RefCounted:
	var rule: Rule
	var passed: bool
	var detail: String

	func _init(p_rule: Rule, p_passed: bool, p_detail: String = "") -> void:
		rule = p_rule
		passed = p_passed
		detail = p_detail

	func title() -> String:
		return RULE_TITLES[rule]

	func _to_string() -> String:
		return "%s: %s%s" % [title(), "pass" if passed else "FAIL",
			"" if detail.is_empty() else " — " + detail]

func is_rule_enabled(rule: Rule) -> bool:
	return enabled_rules.is_empty() or enabled_rules.has(rule)

## Every enabled rule's verdict, in rule order.
func check_all(request: VisitorRequest) -> Array[Finding]:
	var findings: Array[Finding] = []
	for rule: Rule in [Rule.NAME_MATCH, Rule.ID_FORMAT, Rule.COLLEGE_CODE,
			Rule.PHOTO_MATCH, Rule.VALIDITY_WINDOW, Rule.PRIOR_STAMP]:
		if is_rule_enabled(rule):
			findings.append(check(rule, request))
	return findings

func violations(request: VisitorRequest) -> Array[Finding]:
	var failed: Array[Finding] = []
	for finding in check_all(request):
		if not finding.passed:
			failed.append(finding)
	return failed

## True when nothing the rulebook can see is wrong.
func passes(request: VisitorRequest) -> bool:
	return violations(request).is_empty()

func check(rule: Rule, request: VisitorRequest) -> Finding:
	match rule:
		Rule.NAME_MATCH: return _check_name_match(request)
		Rule.ID_FORMAT: return _check_id_format(request)
		Rule.COLLEGE_CODE: return _check_college_code(request)
		Rule.PHOTO_MATCH: return _check_photo_match(request)
		Rule.VALIDITY_WINDOW: return _check_validity_window(request)
		Rule.PRIOR_STAMP: return _check_prior_stamp(request)
	return Finding.new(rule, true)

# --- Rule 1 -----------------------------------------------------------------

func _check_name_match(request: VisitorRequest) -> Finding:
	var form := request.form_name.strip_edges()
	var card := request.id_name.strip_edges()
	if form.is_empty() or card.is_empty():
		return Finding.new(Rule.NAME_MATCH, false, "a name is missing")
	# "Exactly match" per the rulebook, but casing and doubled spaces are handwriting artefacts, not discrepancies — don't fail the player on those.
	if _normalise_name(form) == _normalise_name(card):
		return Finding.new(Rule.NAME_MATCH, true)
	return Finding.new(Rule.NAME_MATCH, false,
		"form reads \"%s\", ID reads \"%s\"" % [form, card])

func _normalise_name(value: String) -> String:
	var collapsed := value.strip_edges().to_lower()
	while collapsed.contains("  "):
		collapsed = collapsed.replace("  ", " ")
	return collapsed

# --- Rule 2 -----------------------------------------------------------------

func _check_id_format(request: VisitorRequest) -> Finding:
	if _id_regex == null:
		_id_regex = RegEx.new()
		_id_regex.compile(ID_PATTERN)

	var raw := request.id_number.strip_edges()
	var found := _id_regex.search(raw)
	if found == null:
		return Finding.new(Rule.ID_FORMAT, false,
			"\"%s\" is not BIC-YY-NNNNNN" % raw)

	var year := int(found.get_string(1))
	if year < min_enrollment_year or year > max_enrollment_year:
		return Finding.new(Rule.ID_FORMAT, false,
			"enrollment year %02d is outside %02d-%02d" % [year, min_enrollment_year, max_enrollment_year])
	return Finding.new(Rule.ID_FORMAT, true)

# --- Rule 3 -----------------------------------------------------------------

func _check_college_code(request: VisitorRequest) -> Finding:
	var code := request.college_code.strip_edges().to_upper()
	if code.is_empty():
		return Finding.new(Rule.COLLEGE_CODE, false, "no college code on the form")
	if valid_college_codes.has(code):
		return Finding.new(Rule.COLLEGE_CODE, true)
	return Finding.new(Rule.COLLEGE_CODE, false,
		"\"%s\" is not on the reference list" % code)

# --- Rule 4 -----------------------------------------------------------------

func _check_photo_match(request: VisitorRequest) -> Finding:
	if request.photo_matches:
		return Finding.new(Rule.PHOTO_MATCH, true)
	return Finding.new(Rule.PHOTO_MATCH, false, "the ID photo is not this visitor")

# --- Rule 5 -----------------------------------------------------------------

func _check_validity_window(request: VisitorRequest) -> Finding:
	var issued := _to_days(request.issue_date)
	var today := _to_days(current_date)
	if issued < 0:
		return Finding.new(Rule.VALIDITY_WINDOW, false,
			"issue date \"%s\" is unreadable" % request.issue_date)
	if today < 0:
		return Finding.new(Rule.VALIDITY_WINDOW, false, "the desk date is unset")
	if issued > today:
		return Finding.new(Rule.VALIDITY_WINDOW, false,
			"issued %s, which is in the future" % request.issue_date)

	var expires := issued + request.validity_days
	if today > expires:
		return Finding.new(Rule.VALIDITY_WINDOW, false,
			"expired %d day(s) ago" % (today - expires))
	return Finding.new(Rule.VALIDITY_WINDOW, true)

## ISO "YYYY-MM-DD" to a day count, or -1 if unparseable.
func _to_days(iso_date: String) -> int:
	var parts := iso_date.strip_edges().split("-")
	if parts.size() != 3:
		return -1
	for part in parts:
		if not part.is_valid_int():
			return -1
	var unix := Time.get_unix_time_from_datetime_string(iso_date.strip_edges())
	if unix == 0 and iso_date.strip_edges() != "1970-01-01":
		return -1
	return int(floor(unix / 86400.0))

# --- Rule 6 -----------------------------------------------------------------

func _check_prior_stamp(request: VisitorRequest) -> Finding:
	if not request.requires_prior_stamp:
		return Finding.new(Rule.PRIOR_STAMP, true)
	if request.has_prior_stamp:
		return Finding.new(Rule.PRIOR_STAMP, true)
	return Finding.new(Rule.PRIOR_STAMP, false,
		"this request needs a prior approval stamp")
