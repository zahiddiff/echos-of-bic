extends Interactable
class_name RecordsComputer

## The desk records terminal.

signal opened()
signal closed()
signal looked_up(query: String, found: bool)

@export var terminal_prompt: String = "Use the records terminal"

var is_open: bool = false

## Student number -> record lines, as the terminal prints them.
var _records: Dictionary = {}

func _ready() -> void:
	prompt_text = terminal_prompt

func interact(player: Node) -> void:
	if locked:
		return
	open()
	super.interact(player)

func open() -> void:
	if is_open:
		return
	is_open = true
	opened.emit()

func close() -> void:
	if not is_open:
		return
	is_open = false
	closed.emit()

## Load the shift's records.
func load_records(records: Dictionary) -> void:
	_records = records

func has_record(query: String) -> bool:
	return _records.has(_normalise(query))

## The lines the terminal prints for a query, exactly as displayed.
func lookup(query: String) -> PackedStringArray:
	var key := _normalise(query)
	var found := _records.has(key)
	looked_up.emit(key, found)
	if not found:
		return PackedStringArray([
			"QUERY: %s" % key,
			"",
			"NO MATCHING RECORD.",
			"CHECK NUMBER AND RETRY.",
		])
	return _records[key]

func _normalise(query: String) -> String:
	return query.strip_edges().to_upper()

## Build the printed record for one visitor.
static func record_for(request: VisitorRequest, extra_lines: PackedStringArray = PackedStringArray()) -> PackedStringArray:
	var lines := PackedStringArray([
		"RECORD: %s" % request.id_number.to_upper(),
		"",
		"NAME . . . . . %s" % request.id_name.to_upper(),
		"COLLEGE  . . . %s" % request.college_code.to_upper(),
		"STATUS . . . . ENROLLED",
	])
	for line in extra_lines:
		lines.append(line)
	return lines
