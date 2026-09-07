extends Node3D
## Shared cosmetic animator for the Rat Mart dressing pass. One controller
## drives every animated prop - ceiling fan, hanging aisle signs, cable swags,
## fluorescent flicker, distillery bubbles, stock pot steam, stove flames and
## fridge fans - so the store's aliveness costs a single _process instead of
## one per prop. Everything here is local motion: no networking, no gameplay.
## Bubbles and steam run closed envelopes - spawn, drift, vanish - so the loop
## always wraps while the prop sits at zero scale and nothing teleports.

var fan: Node3D
var signs: Array = []
var sign_base: Array = []
var swags: Array = []
var swag_base: Array = []
var bubbles: Array = []
var puffs: Array = []
var flames: Array = []
var flame_base: Array = []
var fridge_fans: Array = []
# Fluorescent fixtures: each entry pairs an emissive mesh with the nearest
# real light (the rear tube rows own their ShopLights), so a dropout dims the
# actual pool of light instead of toggling mesh visibility over a steady lamp.
var fixtures: Array = []
var flicker_clock := 3.0
var flicker_active: Array = []
var flicker_time := 0.0
var flicker_duration := 0.35
var t := 0.0

func _ready() -> void:
	fan = get_node_or_null("../RatStore/Fan")
	for i in range(3):
		var pivot := get_node_or_null("../RatStore/SignPivot%d" % i)
		if pivot:
			signs.append(pivot)
			sign_base.append(pivot.rotation)
	for i in range(2):
		var swag := get_node_or_null("../RatStore/CableSwag%d" % i)
		if swag:
			swags.append(swag)
			swag_base.append(swag.rotation)
	var puddle := get_node_or_null("../Distillery/PuddleBubbles")
	if puddle:
		for child in puddle.get_children():
			bubbles.append(child)
			child.set_meta("base_pos", child.position)
			child.set_meta("base_scale", child.scale)
	var steam := get_node_or_null("../RatStore/PotSteam")
	if steam:
		for child in steam.get_children():
			puffs.append(child)
			child.set_meta("base_pos", child.position)
			child.set_meta("base_scale", child.scale)
	var stove := get_node_or_null("../RatStore/StoveFlames")
	if stove:
		for child in stove.get_children():
			flames.append(child)
			flame_base.append(child.scale)
	for i in range(2):
		var fridge := get_node_or_null("../RatStore/FridgeFan%d" % i)
		if fridge:
			fridge_fans.append(fridge)
	_build_flicker_fixtures()

func _build_flicker_fixtures() -> void:
	# The flicker set: one sign bulb gone dark-ish, the two rear tubes, one
	# blade-sign dot. The generator shares one glowing material across every
	# emissive prop, so each fixture gets a private duplicate whose emission
	# the flicker can drive, plus the closest light within a small radius.
	var lights: Array = []
	var store := get_node_or_null("../RatStore")
	if store:
		for light in store.find_children("*", "Light3D", true, false):
			lights.append(light)
	for path in ["../RatStore/BladeSignDot","../RatStore/Tube-8-55","../RatStore/Tube8-55","../RatStore/SignBulb2"]:
		var mesh := get_node_or_null(path) as MeshInstance3D
		if mesh == null:
			continue
		var entry := {"mesh": mesh, "mat": null, "mat_energy": 0.0, "light": null, "light_energy": 0.0}
		var mat := mesh.material_override
		if mat is StandardMaterial3D:
			var copy := mat.duplicate() as StandardMaterial3D
			mesh.material_override = copy
			entry.mat = copy
			entry.mat_energy = copy.emission_energy_multiplier
		var best: Light3D = null
		var best_d := 3.5
		for light in lights:
			var d: float = light.global_position.distance_to(mesh.global_position)
			if d < best_d:
				best_d = d
				best = light
		if best:
			entry.light = best
			entry.light_energy = best.light_energy
		fixtures.append(entry)

## Dropout envelope over the event progress: dark, sputter, dark, recover.
## Two dips across a few tenths of a second reads as a dying tube, not a strobe.
func _flicker_supply(p: float) -> float:
	if p < .25: return .08
	if p < .34: return .7
	if p < .58: return .05
	if p < .7: return .45
	return 1.0

func _apply_flicker(entry: Dictionary, supply: float) -> void:
	var mat: StandardMaterial3D = entry.mat
	if mat:
		mat.emission_energy_multiplier = entry.mat_energy*supply
	var light: Light3D = entry.light
	if light:
		light.light_energy = entry.light_energy*supply

func _process(delta: float) -> void:
	t += delta
	# Ceiling fan with an imperfect, wandering speed.
	if fan:
		fan.rotation.y += delta*(6.5+sin(t*.7)*1.4+sin(t*.23)*.9)
	# Pendulum sway on the hanging boards, deliberately non-identical.
	for i in range(signs.size()):
		var pivot: Node3D = signs[i]
		pivot.rotation.z = sign_base[i].z+sin(t*(.5+i*.13)+i*2.1)*.03
		pivot.rotation.x = sign_base[i].x+sin(t*(.37+i*.09)+i*1.3)*.018
	for i in range(swags.size()):
		swags[i].rotation.z = swag_base[i].z+sin(t*(.8+i*.21)+i*2.9)*.02
	# Rare short fluorescent dropouts: one fixture per event, occasionally two.
	flicker_clock -= delta
	if not flicker_active.is_empty():
		flicker_time -= delta
		var supply := _flicker_supply(clampf(1.0-flicker_time/flicker_duration,0.0,1.0))
		for entry in flicker_active:
			_apply_flicker(entry,supply)
		if flicker_time <= 0.0:
			for entry in flicker_active:
				_apply_flicker(entry,1.0)
			flicker_active.clear()
	elif flicker_clock <= 0.0:
		flicker_clock = randf_range(4.0,10.0)
		if not fixtures.is_empty():
			var first := randi()%fixtures.size()
			flicker_active=[fixtures[first]]
			if fixtures.size()>1 and randf()<.25:
				var second := randi()%fixtures.size()
				if second != first:
					flicker_active.append(fixtures[second])
			flicker_duration=randf_range(.3,.5)
			flicker_time=flicker_duration
	# Moonshine bubbles: swell out of the puddle, rise, then pop - the scale
	# envelope closes at both ends so the wrap is invisible.
	for i in range(bubbles.size()):
		var bubble: Node3D = bubbles[i]
		var p := fmod(t*.5+i*.37,1.0)
		var grow := smoothstep(0.0,.14,p)
		var pop := 1.0-smoothstep(.8,1.0,p)
		var rise := clampf((p-.1)/.85,0.0,1.0)
		bubble.position = bubble.get_meta("base_pos")+Vector3(0.0,rise*.55,0.0)
		bubble.scale = bubble.get_meta("base_scale")*maxf(grow*pop,.001)
	# Stock pot steam: spawns small, climbs with a sideways drift, expands,
	# then evaporates - the reset happens while the puff cannot be seen.
	for i in range(puffs.size()):
		var puff: Node3D = puffs[i]
		var p := fmod(t*.4+i*.31,1.0)
		var fade := smoothstep(0.0,.1,p)*(1.0-smoothstep(.8,1.0,p))
		var drift := sin(t*1.3+i*2.0)*.08*p
		puff.position = puff.get_meta("base_pos")+Vector3(drift,p*1.15,0.0)
		puff.scale = puff.get_meta("base_scale")*maxf(fade*(.7+p*1.0),.001)
	# Stove flames flicker at slightly different rates.
	for i in range(flames.size()):
		flames[i].scale = flame_base[i]*Vector3(
			1.0+sin(t*13.0+i*2.1)*.12,
			1.0+sin(t*17.0+i*1.7)*.18,
			1.0+cos(t*15.0+i*2.6)*.12)
	for fridge in fridge_fans:
		fridge.rotation.x += delta*9.0