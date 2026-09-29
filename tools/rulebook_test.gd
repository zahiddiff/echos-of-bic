extends SceneTree

## Unit tests for the six rulebook rules.
## Run: godot --headless --path <project> --script res://tools/rulebook_test.gd

var _failures := 0
var _book: Rulebook

func _init() -> void:
	_book = Rulebook.new()
	_book.current_date = "2026-09-17"
	_book.min_enrollment_year = 19
	_book.max_enrollment_year = 26

	_test_clean()
	_test_name_match()
	_test_id_format()
	_test_college_code()
	_test_photo_match()
	_test_validity_window()
	_test_prior_stamp()
	_test_onboarding_subset()

	print("")
	if _failures == 0:
		print("RULEBOOK TEST PASSED")
	else:
		print("RULEBOOK TEST FAILED (%d problem(s))" % _failures)
	quit(1 if _failures > 0 else 0)

func _expect(condition: bool, message: String) -> void:
	if condition:
		print("  ok    %s" % message)
	else:
		_failures += 1
		print("  FAIL  %s" % message)

## A request that breaks nothing.
func _clean() -> VisitorRequest:
	var request := VisitorRequest.new()
	request.visitor_name = "Mahin Rahman"
	request.form_name = "Mahin Rahman"
	request.id_name = "Mahin Rahman"
	request.id_number = "BIC-24-018342"
	request.college_code = "ENG"
	request.task_id = "transcript_print"
	request.task_label = "Transcript printing"
	request.issue_date = "2026-08-01"
	request.validity_days = 90
	request.photo_matches = true
	return request

func _fails_only(request: VisitorRequest, rule: Rulebook.Rule, label: String) -> void:
	var broken := _book.violations(request)
	if broken.size() == 1 and broken[0].rule == rule:
		print("  ok    %s -> %s" % [label, broken[0]])
	else:
		_failures += 1
		var got := "nothing"
		if not broken.is_empty():
			var parts: Array[String] = []
			for finding in broken:
				parts.append(str(finding))
			got = ", ".join(parts)
		print("  FAIL  %s -> expected only %s, got: %s" % [label, Rulebook.RULE_TITLES[rule], got])

func _test_clean() -> void:
	print("Clean paperwork")
	var request := _clean()
	_expect(_book.passes(request), "a clean request passes all six rules")
	_expect(_book.check_all(request).size() == 6, "check_all returns six findings")

func _test_name_match() -> void:
	print("\nRule 1 — name match")
	var request := _clean()
	request.id_name = "Mahin Rahmam"
	_fails_only(request, Rulebook.Rule.NAME_MATCH, "one letter off on the ID")

	request = _clean()
	request.form_name = "  mahin   rahman "
	_expect(_book.passes(request), "casing and doubled spaces are not a mismatch")

	request = _clean()
	request.id_name = ""
	_fails_only(request, Rulebook.Rule.NAME_MATCH, "blank ID name")

func _test_id_format() -> void:
	print("\nRule 2 — ID number format")
	var request := _clean()
	request.id_number = "BIC-24-18342"
	_fails_only(request, Rulebook.Rule.ID_FORMAT, "five digits instead of six")

	request = _clean()
	request.id_number = "BIC-24-018342 "
	_expect(_book.passes(request), "trailing whitespace is tolerated")

	request = _clean()
	request.id_number = "BIC-31-018342"
	_fails_only(request, Rulebook.Rule.ID_FORMAT, "enrollment year past the valid range")

	request = _clean()
	request.id_number = "BIC-18-018342"
	_fails_only(request, Rulebook.Rule.ID_FORMAT, "enrollment year before the valid range")

	request = _clean()
	request.id_number = "BIC-19-000001"
	_expect(_book.passes(request), "the earliest valid year is accepted")
	request.id_number = "BIC-26-999999"
	_expect(_book.passes(request), "the latest valid year is accepted")

	request = _clean()
	request.id_number = "BlC-24-018342"
	_fails_only(request, Rulebook.Rule.ID_FORMAT, "lookalike letter in the prefix")

func _test_college_code() -> void:
	print("\nRule 3 — college code")
	var request := _clean()
	request.college_code = "ZZZ"
	_fails_only(request, Rulebook.Rule.COLLEGE_CODE, "code not on the reference list")

	request = _clean()
	request.college_code = "eng"
	_expect(_book.passes(request), "lowercase code still matches")

	request = _clean()
	request.college_code = ""
	_fails_only(request, Rulebook.Rule.COLLEGE_CODE, "missing code")

func _test_photo_match() -> void:
	print("\nRule 4 — photo match")
	var request := _clean()
	request.photo_matches = false
	_fails_only(request, Rulebook.Rule.PHOTO_MATCH, "photo is not the visitor")

func _test_validity_window() -> void:
	print("\nRule 5 — expiry & validity window")
	var request := _clean()
	request.issue_date = "2026-01-01"
	request.validity_days = 90
	_fails_only(request, Rulebook.Rule.VALIDITY_WINDOW, "expired months ago")

	request = _clean()
	request.issue_date = "2026-06-19"  # exactly 90 days before 2026-09-17
	request.validity_days = 90
	_expect(_book.passes(request), "the last valid day is still valid")

	request = _clean()
	request.issue_date = "2026-06-18"
	request.validity_days = 90
	_fails_only(request, Rulebook.Rule.VALIDITY_WINDOW, "one day past expiry")

	request = _clean()
	request.issue_date = "2026-10-01"
	_fails_only(request, Rulebook.Rule.VALIDITY_WINDOW, "issued in the future")

	request = _clean()
	request.issue_date = "not a date"
	_fails_only(request, Rulebook.Rule.VALIDITY_WINDOW, "unreadable issue date")

func _test_prior_stamp() -> void:
	print("\nRule 6 — required prior stamp")
	var request := _clean()
	request.requires_prior_stamp = true
	request.has_prior_stamp = false
	_fails_only(request, Rulebook.Rule.PRIOR_STAMP, "missing the other office's stamp")

	request = _clean()
	request.requires_prior_stamp = true
	request.has_prior_stamp = true
	_expect(_book.passes(request), "stamp present, everything else clean")

func _test_onboarding_subset() -> void:
	print("\nOnboarding — rules taught one at a time")
	var shift_one := Rulebook.new()
	shift_one.current_date = _book.current_date
	shift_one.enabled_rules = [Rulebook.Rule.NAME_MATCH]

	var request := _clean()
	request.college_code = "ZZZ"
	request.id_number = "garbage"
	_expect(shift_one.check_all(request).size() == 1, "only the taught rule is checked")
	_expect(shift_one.passes(request),
		"untaught rules cannot fail the player during onboarding")

	request.id_name = "Someone Else"
	_expect(not shift_one.passes(request), "the taught rule still bites")
