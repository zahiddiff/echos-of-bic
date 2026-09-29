extends Resource
class_name VisitorRequest

const PHOTO_SIZE := Vector2i(240, 300)

## One visitor's paperwork, as it arrives at the desk.

## The four generic wrongness types.
enum Wrongness {
	NONE,
	IDENTITY,    ## name / photo / ID number doesn't hold up
	DATA,        ## records internally inconsistent or impossible
	PHYSICAL,    ## something changed in the environment while away from the desk
	REPETITION,  ## the same visitor or request resurfaces impossibly
}

@export_group("Visitor")
## Who is actually standing at the desk.
@export var visitor_name: String = ""
@export var visitor_portrait: Texture2D:
	get:
		if visitor_portrait == null and visitor_face != null:
			visitor_portrait = PortraitFactory.render(visitor_face, PHOTO_SIZE)
		return visitor_portrait
## The face behind `visitor_portrait`, so the 3D figure can match it. Photos render on first use.
var visitor_face: PortraitFactory.FaceTraits

@export_group("Request form")
@export var task_id: String = ""
@export var task_label: String = ""
## The name written on the request form.
@export var form_name: String = ""
@export var college_code: String = ""
## ISO "YYYY-MM-DD".
@export var issue_date: String = ""
## Days the document stays valid from its issue date.
@export var validity_days: int = 90
## Some request types cannot be processed without an approval stamp from another office, regardless of everything else being correct (rule 6).
@export var requires_prior_stamp: bool = false
@export var has_prior_stamp: bool = false

@export_group("ID card")
## The name printed on the ID card.
@export var id_name: String = ""
## Format BIC-YY-NNNNNN (rule 2).
@export var id_number: String = ""
@export var id_photo: Texture2D:
	get:
		if id_photo == null and id_face != null:
			id_photo = visitor_portrait if id_face == visitor_face else PortraitFactory.render(id_face, PHOTO_SIZE)
		return id_photo
var id_face: PortraitFactory.FaceTraits
## Whether the ID photo is actually this visitor (rule 4).
@export var photo_matches: bool = true

@export_group("Dialogue")
## What they say at the desk, plus the one or two follow-ups worth asking.
@export var dialogue: VisitorDialogue

@export_group("Authoring")
@export var wrongness: Wrongness = Wrongness.NONE
## True for the three threat types.
@export var is_threat: bool = false
## Which threat this is, when `is_threat`.
@export var threat_kind: ThreatType.Kind = ThreatType.Kind.NONE

func is_clean() -> bool:
	return wrongness == Wrongness.NONE and not is_threat

func describe() -> String:
	return "%s — %s (%s)" % [form_name, task_label, id_number]
