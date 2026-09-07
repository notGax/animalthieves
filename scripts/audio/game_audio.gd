extends RefCounted

## GameAudio: procedural audio presentation for the heist.
##
## Every stream here is synthesized at runtime in GDScript - original work,
## no licensed assets and no audio files in the repo. One-shots are shaped
## sine partials plus noise bursts; ambience loops use only whole-Hz partials
## and note envelopes fully contained inside the buffer, so LOOP_FORWARD wraps
## without a seam. Streams are cached and shared: take them, never mutate.
##
## Layers:
##   - UI sounds (menu clicks) use a plain AudioStreamPlayer  (play_ui)
##   - world events use AudioStreamPlayer3D with inverse-distance
##     attenuation (play_at); play() routes by whether a position is known
##   - vehicles get looped engines from engine_stream() and fire their
##     one-shot crash through the rig's own ImpactAudio hook
##   - the Rat Mart soundscape is built once by build_rat_mart_ambience()

const RATE := 22050

const VOLUME_DB := {
	"crash": -2.0, "win": -5.0, "slap": -6.0, "heal": -7.0,
	"cash": -8.0, "tool": -9.0, "click": -9.0,
	"grapple": -7.0, "grapple_hit": -6.0, "water": -8.0, "transform": -6.0,
	"crystal": -6.0, "alert": -5.0, "windup": -4.0, "charge": -3.0,
	"stun": -5.0, "grab": -10.0, "drop": -9.0, "throw": -8.0,
}

## Ambient emitters and their anchors. Positions mirror the generator's hero
## scenes (scripts/level/build_heist_world.py): the fridge wall, the cellar
## stills and the checkout counter. [kind, position, volume_db, unit_size]
const AMBIENCE := [
	["fridge_hum", Vector3(14.7, 2.2, -40), -8.0, 5.0],
	["fridge_hum", Vector3(14.7, 2.2, -45), -8.0, 5.0],
	["still_bubble", Vector3(-9.0, -9.2, -55.0), -6.0, 6.0],
	["still_bubble", Vector3(-2.0, -9.2, -55.0), -6.0, 6.0],
	["still_bubble", Vector3(5.0, -9.2, -55.0), -6.0, 6.0],
	["store_jingle", Vector3(11.0, 3.4, -33.0), -16.0, 14.0],
]

static var _streams: Dictionary = {}
static var _noise := RandomNumberGenerator.new()


static func stream(kind: String) -> AudioStreamWAV:
	if not _streams.has(kind):
		var samples: PackedFloat32Array
		var loop := false
		match kind:
			"slap":
				samples = _synth_slap()
			"cash":
				samples = _synth_cash()
			"win":
				samples = _synth_win()
			"heal":
				samples = _synth_heal()
			"tool":
				samples = _synth_tool()
			"crash":
				samples = _synth_crash()
			"click":
				samples = _synth_click()
			"grapple":
				samples = _synth_grapple()
			"grapple_hit":
				samples = _synth_grapple_hit()
			"water":
				samples = _synth_water()
			"transform":
				samples = _synth_transform()
			"crystal":
				samples = _synth_crystal()
			"alert":
				samples = _synth_alert()
			"windup":
				samples = _synth_windup()
			"charge":
				samples = _synth_charge()
			"stun":
				samples = _synth_stun()
			"grab":
				samples = _synth_grab()
			"drop":
				samples = _synth_drop()
			"throw":
				samples = _synth_throw()
			"fridge_hum":
				samples = _loop_tone(1.0, [[100.0, .10], [200.0, .05], [300.0, .02]], 1.0, .15)
				loop = true
			"still_bubble":
				samples = _synth_still_bubble()
				loop = true
			"store_jingle":
				samples = _synth_store_jingle()
				loop = true
			"engine_cart":
				samples = _loop_tone(1.0, [[160.0, .15], [320.0, .06], [480.0, .028]], 8.0, .22)
				loop = true
			"engine_truck":
				samples = _loop_tone(1.0, [[52.0, .20], [104.0, .12], [156.0, .05]], 12.0, .30)
				loop = true
			"engine_racecar":
				samples = _loop_tone(1.0, [[128.0, .14], [256.0, .10], [384.0, .06], [512.0, .035]], 20.0, .18)
				loop = true
			_:
				samples = _synth_tool()
		_streams[kind] = _wav(samples, loop)
	return _streams[kind]


static func engine_stream(kind: String) -> AudioStreamWAV:
	return stream("engine_" + kind)


## Route by what the caller knows: a position means the world, no position
## means the UI layer.
static func play(host: Node, kind: String, at := Vector3.INF) -> void:
	if at.is_finite() and host is Node3D:
		play_at(host, kind, at)
	else:
		play_ui(host, kind)


static func play_ui(host: Node, kind: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var player := AudioStreamPlayer.new()
	player.stream = stream(kind)
	player.volume_db = VOLUME_DB.get(kind, -8.0)
	player.bus = "SFX"
	host.add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


static func play_at(host: Node3D, kind: String, at: Vector3) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var player := AudioStreamPlayer3D.new()
	player.stream = stream(kind)
	player.volume_db = VOLUME_DB.get(kind, -8.0)
	player.bus = "SFX"
	player.unit_size = 8.0
	player.max_db = -3.0
	host.add_child(player)
	player.global_position = at
	player.finished.connect(player.queue_free)
	player.play()


## A persistent looping emitter for ambience. Returns the node so callers
## could pause it; the world never does.
static func loop_at(host: Node3D, kind: String, at: Vector3, volume_db: float, unit_size: float) -> AudioStreamPlayer3D:
	var player := AudioStreamPlayer3D.new()
	player.name = "Audio_" + kind
	player.stream = stream(kind)
	player.position = at
	player.volume_db = volume_db
	player.bus = "Music"
	player.unit_size = unit_size
	player.max_db = -4.0
	host.add_child(player)
	player.play()
	return player


static func build_rat_mart_ambience(world: Node3D) -> void:
	for entry in AMBIENCE:
		loop_at(world, entry[0], entry[1], entry[2], entry[3])


# --- synthesis ---------------------------------------------------------------

static func _wav(samples: PackedFloat32Array, loop: bool) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.data = bytes
	if loop:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = samples.size()
	return wav


## Summed sine partials over a whole number of seconds with a slow amplitude
## flutter. Whole-Hz partials and whole-Hz flutter complete integer cycles
## across the buffer, so the result loops seamlessly.
static func _loop_tone(seconds: float, partials: Array, flutter_hz: float, flutter_depth: float) -> PackedFloat32Array:
	var count := int(seconds * RATE)
	var out := PackedFloat32Array()
	out.resize(count)
	for i in count:
		var t := float(i) / RATE
		var sample := 0.0
		for p in partials:
			sample += p[1] * sin(TAU * p[0] * t)
		out[i] = sample * (1.0 + flutter_depth * sin(TAU * flutter_hz * t))
	return out


## A short pitch-dropping blup, windowed to zero at both ends so it never
## crosses the loop seam.
static func _blip(out: PackedFloat32Array, start: int, dur: float, from_hz: float, to_hz: float, amp: float) -> void:
	var n := int(dur * RATE)
	for j in n:
		var idx := start + j
		if idx >= out.size():
			return
		var u := float(j) / n
		out[idx] += amp * sin(PI * u) * sin(TAU * lerpf(from_hz, to_hz, u) * j / RATE)


## One enveloped muzak note with a soft attack and release.
static func _note(out: PackedFloat32Array, start: float, dur: float, hz: float, amp: float) -> void:
	var n := int(dur * RATE)
	var begin := int(start * RATE)
	for j in n:
		var idx := begin + j
		if idx >= out.size():
			return
		var t := float(j) / RATE
		var env := 1.0
		if t < .02:
			env = t / .02
		elif t > dur - .12:
			env = maxf(0.0, (dur - t) / .12)
		var sample := sin(TAU * hz * t) + .35 * sin(TAU * hz * 2.0 * t) + .12 * sin(TAU * hz * 3.0 * t)
		out[idx] += amp * env * sample / 1.47


static func _synth_slap() -> PackedFloat32Array:
	var count := int(.12 * RATE)
	var out := PackedFloat32Array()
	out.resize(count)
	_noise.seed = 11
	for i in count:
		var t := float(i) / RATE
		out[i] = _noise.randf_range(-1.0, 1.0) * exp(-t * 70.0) * .55 + sin(TAU * 95.0 * t) * exp(-t * 32.0) * .6
	return out


static func _synth_cash() -> PackedFloat32Array:
	var count := int(.4 * RATE)
	var out := PackedFloat32Array()
	out.resize(count)
	for i in count:
		var t := float(i) / RATE
		var sample := sin(TAU * 920.0 * t) * exp(-t * 16.0) * .34
		if t > .09:
			sample += sin(TAU * 1380.0 * (t - .09)) * exp(-(t - .09) * 18.0) * .34
		if t > .05:
			sample += sin(TAU * 1840.0 * (t - .05)) * exp(-(t - .05) * 30.0) * .1
		out[i] = sample
	return out


static func _synth_win() -> PackedFloat32Array:
	var count := int(.7 * RATE)
	var out := PackedFloat32Array()
	out.resize(count)
	var notes := [[0.0, 523.25], [.14, 659.26], [.28, 783.99], [.42, 1046.5]]
	for i in count:
		var t := float(i) / RATE
		var sample := 0.0
		for n in notes:
			var local: float = t - n[0]
			if local > 0.0:
				sample += (sin(TAU * n[1] * local) + .3 * sin(TAU * n[1] * 2.0 * local)) * exp(-local * 9.0) * .3
		out[i] = sample
	return out


static func _synth_heal() -> PackedFloat32Array:
	var count := int(.38 * RATE)
	var out := PackedFloat32Array()
	out.resize(count)
	var phase := 0.0
	for i in count:
		var t := float(i) / RATE
		phase += TAU * lerpf(420.0, 780.0, t / .38) / RATE
		var env := minf(t / .03, 1.0) * exp(-t * 5.0)
		out[i] = (sin(phase + sin(TAU * 6.0 * t) * .03) * .8 + sin(phase * 2.0) * .15) * env * .4
	return out


static func _synth_tool() -> PackedFloat32Array:
	var count := int(.1 * RATE)
	var out := PackedFloat32Array()
	out.resize(count)
	_noise.seed = 13
	for i in count:
		var t := float(i) / RATE
		out[i] = _noise.randf_range(-1.0, 1.0) * exp(-t * 90.0) * .4 + sin(TAU * 180.0 * t) * exp(-t * 45.0) * .5
	return out


static func _synth_crash() -> PackedFloat32Array:
	var count := int(.45 * RATE)
	var out := PackedFloat32Array()
	out.resize(count)
	_noise.seed = 23
	for i in count:
		var t := float(i) / RATE
		var sample := _noise.randf_range(-1.0, 1.0) * exp(-t * 16.0) * .5
		sample += sin(TAU * 58.0 * t) * exp(-t * 12.0) * .6
		# Inharmonic metal ring over the thud.
		sample += sin(TAU * 173.0 * t) * exp(-t * 9.0) * .18
		sample += sin(TAU * 259.0 * t) * exp(-t * 11.0) * .14
		sample += sin(TAU * 347.0 * t) * exp(-t * 13.0) * .10
		out[i] = sample
	return out


static func _synth_click() -> PackedFloat32Array:
	var count := int(.04 * RATE)
	var out := PackedFloat32Array()
	out.resize(count)
	_noise.seed = 17
	for i in count:
		var t := float(i) / RATE
		out[i] = _noise.randf_range(-1.0, 1.0) * exp(-t * 160.0) * .45 + sin(TAU * 1150.0 * t) * exp(-t * 200.0) * .3
	return out


static func _synth_still_bubble() -> PackedFloat32Array:
	# Warm boil: slow low partials under a 3 Hz surge, with three blups fully
	# contained inside the second so the loop stays seamless.
	var out := _loop_tone(1.0, [[62.0, .12], [93.0, .08], [124.0, .05]], 3.0, .30)
	for k in 3:
		_blip(out, int(k * 7350.0) + 900, .06, 320.0, 160.0, .5)
	return out


static func _synth_store_jingle() -> PackedFloat32Array:
	# Two bars of shop muzak at 100 BPM - C, F, G, C - a soft two-note arpeggio
	# over a root-and-fifth bass. Cheesy on purpose; the world plays it far
	# below conversation volume. Every note is enveloped inside the buffer.
	var count := int(4.8 * RATE)
	var out := PackedFloat32Array()
	out.resize(count)
	var chords := [
		[130.81, [523.25, 659.26, 783.99]],
		[174.61, [698.46, 880.0, 1046.5]],
		[196.0, [783.99, 987.77, 1174.66]],
		[130.81, [523.25, 659.26, 783.99]],
	]
	for c in chords.size():
		var slot := c * 1.2
		_note(out, slot, 1.2, chords[c][0], .11)
		_note(out, slot + .6, 1.2, chords[c][0] * 1.5, .07)
		_note(out, slot, .6, chords[c][1][1], .085)
		_note(out, slot + .6, .6, chords[c][1][2], .085)
	return out


static func _synth_grapple() -> PackedFloat32Array:
	# Hook launch: a short rising zip with a ratchet of three fast clicks.
	var count := int(.16 * RATE)
	var out := PackedFloat32Array()
	out.resize(count)
	for i in count:
		var t := float(i) / RATE
		var u := t / .16
		var env := sin(PI * minf(u * 2.2, 1.0)) * exp(-t * 14.0)
		out[i] = env * (.5 * sin(TAU * lerpf(240.0, 900.0, u) * t) + .22 * sin(TAU * 1800.0 * t) * exp(-t * 30.0))
	for k in 3:
		_blip(out, int(k * .035 * RATE), .03, 1500.0 - k * 220.0, 900.0 - k * 180.0, .3)
	return out


static func _synth_grapple_hit() -> PackedFloat32Array:
	# Connection: a metallic clink into a taut cable twang.
	var count := int(.26 * RATE)
	var out := PackedFloat32Array()
	out.resize(count)
	for i in count:
		var t := float(i) / RATE
		var sample := sin(TAU * 620.0 * t) * exp(-t * 34.0) * .4
		sample += sin(TAU * 233.0 * t) * exp(-t * 16.0) * .3
		# The twang: slight downward pitch sag reads as cable tension.
		var u := t / .26
		sample += sin(TAU * lerpf(196.0, 165.0, u) * t) * exp(-t * 11.0) * .3
		out[i] = sample
	_noise.seed = 31
	for i in int(.02 * RATE):
		out[i] += _noise.randf_range(-1.0, 1.0) * exp(-float(i) / RATE * 190.0) * .5
	return out


static func _synth_water() -> PackedFloat32Array:
	# Spray: bright hiss shaped by a fluttering envelope, over a low gurgle.
	var count := int(.42 * RATE)
	var out := PackedFloat32Array()
	out.resize(count)
	_noise.seed = 29
	for i in count:
		var t := float(i) / RATE
		var u := t / .42
		var env := sin(PI * u)
		env *= 1.0 + .3 * sin(TAU * 37.0 * t)
		var hiss := _noise.randf_range(-1.0, 1.0) * .38
		var gurgle := sin(TAU * (128.0 + 46.0 * sin(TAU * 5.0 * t)) * t) * .22
		out[i] = (hiss + gurgle) * env
	return out


static func _synth_transform() -> PackedFloat32Array:
	# Morph whoosh: a warbling glide upward wrapped in soft noise.
	var count := int(.45 * RATE)
	var out := PackedFloat32Array()
	out.resize(count)
	_noise.seed = 31
	var phase := 0.0
	for i in count:
		var t := float(i) / RATE
		var u := t / .45
		phase += TAU * lerpf(190.0, 660.0, u * u) / RATE
		var wobble := sin(TAU * 9.0 * t) * .12
		var env := sin(PI * u)
		var body := sin(phase + wobble) * .42 + sin(phase * 1.5) * .16
		out[i] = (body + _noise.randf_range(-1.0, 1.0) * .14) * env
	return out


static func _synth_crystal() -> PackedFloat32Array:
	# Revival chime: two glassy partials with a delayed sparkle above them.
	var count := int(.55 * RATE)
	var out := PackedFloat32Array()
	out.resize(count)
	for i in count:
		var t := float(i) / RATE
		var sample := sin(TAU * 1318.5 * t) * exp(-t * 7.0) * .34
		sample += sin(TAU * 1975.5 * t) * exp(-t * 9.0) * .18
		if t > .12:
			var local: float = t - .12
			sample += sin(TAU * 2637.0 * local) * exp(-local * 10.0) * .16
		out[i] = sample
	return out


static func _synth_alert() -> PackedFloat32Array:
	# Spotted! Two sharp ascending chirps - the guard's whistle.
	var count := int(.24 * RATE)
	var out := PackedFloat32Array()
	out.resize(count)
	for chirp in 2:
		var begin := int((.02 + chirp * .11) * RATE)
		for j in int(.07 * RATE):
			var idx := begin + j
			var t := float(j) / RATE
			var u := float(j) / (.07 * RATE)
			if idx < count:
				out[idx] += sin(TAU * (1560.0 + 260.0 * chirp) * t) * sin(PI * u) * .42
	return out


static func _synth_windup() -> PackedFloat32Array:
	# The boss coils: a low rumble climbing in pitch and volume.
	var count := int(.95 * RATE)
	var out := PackedFloat32Array()
	out.resize(count)
	var phase := 0.0
	for i in count:
		var t := float(i) / RATE
		var u := t / .95
		phase += TAU * lerpf(44.0, 118.0, u * u) / RATE
		var saw := fmod(phase / TAU, 1.0) * 2.0 - 1.0
		out[i] = (saw * .4 + sin(phase * 2.0) * .22 + sin(phase * 3.0) * .1) * (u * .8 + .1)
	return out


static func _synth_charge() -> PackedFloat32Array:
	# Charge roar: layered low saws with a bright top partial and noise push.
	var count := int(.55 * RATE)
	var out := PackedFloat32Array()
	out.resize(count)
	_noise.seed = 37
	var phase := 0.0
	for i in count:
		var t := float(i) / RATE
		var u := t / .55
		phase += TAU * lerpf(66.0, 96.0, u) / RATE
		var saw := fmod(phase / TAU, 1.0) * 2.0 - 1.0
		var env := sin(PI * minf(u * 1.6, 1.0))
		out[i] = (saw * .45 + sin(phase * 2.0) * .25 + _noise.randf_range(-1.0, 1.0) * .18) * env
	return out


static func _synth_stun() -> PackedFloat32Array:
	# Dizzy descending wobble - the charge that ended in a wall.
	var count := int(.7 * RATE)
	var out := PackedFloat32Array()
	out.resize(count)
	var phase := 0.0
	for i in count:
		var t := float(i) / RATE
		var u := t / .7
		phase += TAU * lerpf(520.0, 190.0, u) / RATE
		var vibrato := sin(TAU * (7.0 - 3.0 * u) * t) * .3
		out[i] = (sin(phase + vibrato) * .4 + sin(phase * .5) * .2) * (1.0 - u * .7)
	return out


static func _synth_grab() -> PackedFloat32Array:
	# Mitts close: a soft quick pop.
	var count := int(.08 * RATE)
	var out := PackedFloat32Array()
	out.resize(count)
	for i in count:
		var t := float(i) / RATE
		var u := t / .08
		out[i] = sin(TAU * lerpf(340.0, 170.0, u) * t) * sin(PI * u) * .5
	return out


static func _synth_drop() -> PackedFloat32Array:
	# Set down: a soft box thud.
	var count := int(.13 * RATE)
	var out := PackedFloat32Array()
	out.resize(count)
	_noise.seed = 41
	for i in count:
		var t := float(i) / RATE
		out[i] = sin(TAU * 92.0 * t) * exp(-t * 26.0) * .55 + _noise.randf_range(-1.0, 1.0) * exp(-t * 80.0) * .2
	return out


static func _synth_throw() -> PackedFloat32Array:
	# Released with force: a whistling whoosh.
	var count := int(.2 * RATE)
	var out := PackedFloat32Array()
	out.resize(count)
	_noise.seed = 41
	for i in count:
		var t := float(i) / RATE
		var u := t / .2
		var flutter := 1.0 + .4 * sin(TAU * 23.0 * t)
		out[i] = _noise.randf_range(-1.0, 1.0) * .3 * sin(PI * u) * flutter + sin(TAU * lerpf(300.0, 760.0, u) * t) * sin(PI * u) * .14
	return out