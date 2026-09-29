extends RefCounted
class_name NameBank

## Names for generated visitors.

const RESERVED := ["Rahat", "Sang-Woo Joo"]

const GIVEN_NAMES := [
	"Mahin", "Sadia", "Aarav", "Nabila", "Rohan", "Tasnim", "Ishaan",
	"Farida", "Jisoo", "Minho", "Haruka", "Kenji", "Linh", "Duc",
	"Amara", "Kwame", "Zainab", "Omar", "Elena", "Mateo", "Sofia",
	"Yusuf", "Priya", "Arjun", "Mei", "Wei", "Nadia", "Karim",
	"Thandiwe", "Lucas", "Ana", "Dmitri", "Aisha", "Hassan",
]

const FAMILY_NAMES := [
	"Rahman", "Karim", "Chowdhury", "Hossain", "Islam", "Ahmed",
	"Park", "Kim", "Lee", "Choi", "Tanaka", "Sato", "Nguyen", "Tran",
	"Okafor", "Mensah", "Al-Amin", "Haddad", "Petrova", "Novak",
	"Silva", "Rossi", "Fernandez", "Mwangi", "Sharma", "Patel",
	"Zhang", "Chen", "Adeyemi", "Kovacs", "Iqbal", "Bashir",
]

static func random_name(rng: RandomNumberGenerator) -> String:
	var given: String = GIVEN_NAMES[rng.randi() % GIVEN_NAMES.size()]
	var family: String = FAMILY_NAMES[rng.randi() % FAMILY_NAMES.size()]
	return "%s %s" % [given, family]

## A name that is one small step from `source` — a different family name, or the same family name with a different given name.
static func near_miss(source: String, rng: RandomNumberGenerator) -> String:
	var parts := source.split(" ", false)
	if parts.size() < 2:
		return random_name(rng)

	if rng.randf() < 0.5:
		# Same first name, different family name.
		var family: String = FAMILY_NAMES[rng.randi() % FAMILY_NAMES.size()]
		var attempts := 0
		while family == parts[1] and attempts < 8:
			family = FAMILY_NAMES[rng.randi() % FAMILY_NAMES.size()]
			attempts += 1
		return "%s %s" % [parts[0], family]

	# Or a one-letter slip in the family name, which is the nastier version.
	return "%s %s" % [parts[0], _misspell(parts[1], rng)]

## Change exactly one letter, keeping the shape of the word.
static func _misspell(word: String, rng: RandomNumberGenerator) -> String:
	if word.length() < 3:
		return word
	const SWAPS := {
		"a": "e", "e": "a", "i": "e", "o": "a", "u": "a",
		"m": "n", "n": "m", "s": "z", "z": "s", "d": "t", "t": "d",
		"y": "i", "h": "n", "r": "n", "l": "i",
	}
	# Avoid the first letter: a wrong initial is too easy to spot.
	var span := word.length() - 1
	var start := rng.randi() % span
	for step in span:
		var index := 1 + ((start + step) % span)
		var lower := word[index].to_lower()
		if SWAPS.has(lower):
			var replacement: String = SWAPS[lower]
			if word[index] == word[index].to_upper():
				replacement = replacement.to_upper()
			return word.substr(0, index) + replacement + word.substr(index + 1)
	return word
