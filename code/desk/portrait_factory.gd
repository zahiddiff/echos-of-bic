extends RefCounted
class_name PortraitFactory

## Placeholder ID photos and visitor faces.

const HAIR_COLOURS := [
	Color(0.13, 0.11, 0.10), Color(0.22, 0.16, 0.12),
	Color(0.35, 0.26, 0.17), Color(0.09, 0.09, 0.11),
]
const SKIN_TONES := [
	Color(0.85, 0.70, 0.58), Color(0.72, 0.55, 0.42),
	Color(0.56, 0.40, 0.29), Color(0.40, 0.28, 0.21),
	Color(0.93, 0.80, 0.70),
]

## Every knob a face has.
class FaceTraits extends RefCounted:
	var skin: Color
	var hair: Color
	var face_width: float
	var face_height: float
	var eye_spacing: float
	var eye_height: float
	var brow_thickness: float
	var hair_height: float
	var has_mole: bool
	var mole_side: int

	func duplicate_traits() -> FaceTraits:
		var copy := FaceTraits.new()
		copy.skin = skin
		copy.hair = hair
		copy.face_width = face_width
		copy.face_height = face_height
		copy.eye_spacing = eye_spacing
		copy.eye_height = eye_height
		copy.brow_thickness = brow_thickness
		copy.hair_height = hair_height
		copy.has_mole = has_mole
		copy.mole_side = mole_side
		return copy

static func traits_for(seed_value: int) -> FaceTraits:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value

	var traits := FaceTraits.new()
	traits.skin = SKIN_TONES[rng.randi() % SKIN_TONES.size()]
	traits.hair = HAIR_COLOURS[rng.randi() % HAIR_COLOURS.size()]
	traits.face_width = rng.randf_range(0.30, 0.38)
	traits.face_height = rng.randf_range(0.36, 0.44)
	traits.eye_spacing = rng.randf_range(0.14, 0.19)
	traits.eye_height = rng.randf_range(-0.03, 0.03)
	traits.brow_thickness = rng.randf_range(0.012, 0.024)
	traits.hair_height = rng.randf_range(0.10, 0.18)
	traits.has_mole = rng.randf() < 0.35
	traits.mole_side = 1 if rng.randf() < 0.5 else -1
	return traits

## A face that is *nearly* this one.
static func variant_of(traits: FaceTraits, seed_value: int, strength: float = 0.5) -> FaceTraits:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var changed := traits.duplicate_traits()

	match rng.randi() % 5:
		0:
			changed.eye_spacing += lerpf(0.012, 0.035, strength) * (1 if rng.randf() < 0.5 else -1)
		1:
			changed.face_width += lerpf(0.015, 0.045, strength) * (1 if rng.randf() < 0.5 else -1)
		2:
			changed.brow_thickness += lerpf(0.006, 0.014, strength)
		3:
			changed.hair_height += lerpf(0.018, 0.05, strength) * (1 if rng.randf() < 0.5 else -1)
		4:
			changed.has_mole = not traits.has_mole
	return changed

## Backdrops are identical for a given size, so each is rendered once.
static var _backdrops: Dictionary = {}

static func _backdrop(size: Vector2i) -> Image:
	if _backdrops.has(size):
		return _backdrops[size]
	var image := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	var backdrop := Color(0.62, 0.65, 0.69)
	for y in size.y:
		for x in size.x:
			var dx := (float(x) / size.x) - 0.5
			var dy := (float(y) / size.y) - 0.5
			var falloff := 1.0 - clampf(sqrt(dx * dx + dy * dy) * 0.9, 0.0, 0.45)
			image.set_pixel(x, y, backdrop * falloff)
	_backdrops[size] = image
	return image

static func render(traits: FaceTraits, size: Vector2i) -> ImageTexture:
	var image := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	image.copy_from(_backdrop(size))

	var cx := size.x * 0.5
	var head_cy := size.y * 0.46
	var rx := size.x * traits.face_width
	var ry := size.y * traits.face_height

	# Shoulders.
	var shoulder_cy := size.y * 1.12
	_ellipse(image, cx, shoulder_cy, size.x * 0.58, size.y * 0.46, Color(0.24, 0.26, 0.30))

	# Neck.
	_ellipse(image, cx, head_cy + ry * 0.82, rx * 0.34, ry * 0.36, traits.skin.darkened(0.2))

	# Hair mass behind the head.
	_ellipse(image, cx, head_cy - ry * traits.hair_height, rx * 1.06, ry * 1.02, traits.hair)

	# Face.
	_ellipse(image, cx, head_cy, rx, ry, traits.skin)

	# Fringe.
	_ellipse(image, cx, head_cy - ry * (0.55 + traits.hair_height), rx * 1.0, ry * 0.52, traits.hair)

	# Eyes.
	var eye_dx := size.x * traits.eye_spacing
	var eye_y := head_cy + size.y * traits.eye_height
	var eye_rx := size.x * 0.045
	var eye_ry := size.y * 0.028
	for side in [-1.0, 1.0]:
		_ellipse(image, cx + eye_dx * side, eye_y, eye_rx, eye_ry, Color(0.97, 0.97, 0.96))
		_ellipse(image, cx + eye_dx * side, eye_y, eye_rx * 0.45, eye_ry * 0.8, Color(0.16, 0.12, 0.10))
		# Brow.
		_ellipse(image, cx + eye_dx * side, eye_y - size.y * 0.055,
			eye_rx * 1.35, size.y * traits.brow_thickness, traits.hair)

	# Nose and mouth — fixed, so they never distract from the real tells.
	_ellipse(image, cx, head_cy + ry * 0.26, rx * 0.12, ry * 0.10, traits.skin.darkened(0.18))
	_ellipse(image, cx, head_cy + ry * 0.54, rx * 0.30, ry * 0.07, traits.skin.darkened(0.35))

	if traits.has_mole:
		_ellipse(image, cx + rx * 0.52 * traits.mole_side, head_cy + ry * 0.34,
			size.x * 0.012, size.y * 0.012, Color(0.30, 0.20, 0.16))

	return ImageTexture.create_from_image(image)

static func _ellipse(image: Image, cx: float, cy: float, rx: float, ry: float, colour: Color) -> void:
	if rx <= 0.0 or ry <= 0.0:
		return
	var x0 := maxi(int(floor(cx - rx)), 0)
	var x1 := mini(int(ceil(cx + rx)), image.get_width() - 1)
	var y0 := maxi(int(floor(cy - ry)), 0)
	var y1 := mini(int(ceil(cy + ry)), image.get_height() - 1)
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var nx := (x + 0.5 - cx) / rx
			var ny := (y + 0.5 - cy) / ry
			if nx * nx + ny * ny <= 1.0:
				image.set_pixel(x, y, colour)
