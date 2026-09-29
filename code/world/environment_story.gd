extends Node
class_name EnvironmentStory

## Environmental storytelling.

## A prop and the condition under which the building shows it.
class Beat extends RefCounted:
	var id: String
	var node_path: NodePath
	## Takes nothing, returns whether this should be visible now.
	var condition: Callable
	var note: String

	func _init(p_id: String, p_path: String, p_condition: Callable, p_note: String) -> void:
		id = p_id
		node_path = NodePath(p_path)
		condition = p_condition
		note = p_note

var _beats: Array[Beat] = []
var _root: Node

signal beat_appeared(id: String, note: String)
signal beat_removed(id: String, note: String)

func _init() -> void:
	_beats = [
		# Appears near the desk after a stalker gets past you.
		Beat.new("missing_person_flyer", "Props/Story/MissingPersonFlyer",
			func() -> bool: return GameState.has_incident_of(ThreatType.Kind.STALKER),
			"a flyer has gone up by the entrance"),

		# Flat bureaucratic language, posted after anything at all goes wrong.
		Beat.new("security_memo", "Props/Story/SecurityMemo",
			func() -> bool: return GameState.incident_count() >= 1,
			"a memo about increased security awareness is on the desk"),

		# Unrelated break-in at another building.
		Beat.new("news_clipping", "Props/Story/NewsClipping",
			func() -> bool: return GameState.shift >= 4,
			"a news clipping is pinned to the board"),

		# Rahat's desk, empty.
		Beat.new("rahat_absent", "Props/OtherDesk/RahatThings",
			func() -> bool: return GameState.shift < 6,
			"Rahat's things are at his desk"),
	]

func bind(root: Node) -> void:
	_root = root
	refresh()

## Show or hide every beat according to the run so far.
func refresh() -> void:
	if _root == null:
		return
	for beat in _beats:
		var node := _root.get_node_or_null(beat.node_path)
		if node == null:
			continue
		var should_show: bool = beat.condition.call()
		if node is Node3D:
			var was: bool = (node as Node3D).visible
			if was == should_show:
				continue
			(node as Node3D).visible = should_show
			if should_show:
				beat_appeared.emit(beat.id, beat.note)
			else:
				beat_removed.emit(beat.id, beat.note)

## What is on right now — for tests and for the debug print.
func active_beats() -> Array[String]:
	var on: Array[String] = []
	for beat in _beats:
		if beat.condition.call():
			on.append(beat.id)
	return on

func beat_ids() -> Array[String]:
	var ids: Array[String] = []
	for beat in _beats:
		ids.append(beat.id)
	return ids
