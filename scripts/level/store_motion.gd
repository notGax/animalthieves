extends Node3D
## Shared cosmetic animator for the Rat Mart dressing pass. One controller
## drives every animated prop - ceiling fan, hanging aisle signs, cable swags,
## fluorescent flicker, distillery bubbles, stock pot steam, stove flames and
## fridge fans - so the store's aliveness costs a single _process instead of
## one per prop. Everything here is local motion: no networking, no gameplay.

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
var flickers: Array = []
var flicker_clock := 3.0
var flicker_active := 0.0
var flicker_toggle := 0.0
var t := 0.0

func _ready() -> void:
	fan = get_node_or_null("../RatStore/Fan")
	for i in range(3):
		var pivot := get_node_or_null("../RatStore/SignPivot%d" % i)
		if pivot:
			signs.append(pivot)
			sign_base.append(pivot.rotation.z)
	for i in range(2):
		var swag := get_node_or_null("../RatStore/CableSwag%d" % i)
		if swag:
			swags.append(swag)
			swag_base.append(swag.rotation.z)
	var puddle := get_node_or_null("../Distillery/PuddleBubbles")
	if puddle:
		for child in puddle.get_children():
			bubbles.append(child)
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
	# The flicker set: one sign bulb gone dark-ish, the two rear tubes, one
	# blade-sign dot. Rare short dropouts keep the store from feeling dead.
	for path in ["../RatStore/BladeSignDot","../RatStore/Tube-8-55","../RatStore/Tube8-55","../RatStore/SignBulb2"]:
		var flicker := get_node_or_null(path)
		if flicker:
			flickers.append(flicker)

func _process(delta: float) -> void:
	t += delta
	# Ceiling fan with an imperfect, wandering speed.
	if fan:
		fan.rotation.y += delta*(6.5+sin(t*.7)*1.4+sin(t*.23)*.9)
	# Pendulum sway on the hanging boards, deliberately non-identical.
	for i in range(signs.size()):
		var pivot: Node3D = signs[i]
		pivot.rotation.z = sign_base[i]+sin(t*(.5+i*.13)+i*2.1)*.03
		pivot.rotation.x = sin(t*(.37+i*.09)+i*1.3)*.018
	for i in range(swags.size()):
		swags[i].rotation.z = swag_base[i]+sin(t*(.8+i*.21)+i*2.9)*.02
	# Rare short fluorescent dropouts across the flicker set.
	flicker_clock -= delta
	if flicker_active > 0.0:
		flicker_active -= delta
		flicker_toggle -= delta
		if flicker_toggle <= 0.0:
			flicker_toggle = .06
			for flicker in flickers:
				flicker.visible = not flicker.visible
		if flicker_active <= 0.0:
			for flicker in flickers:
				flicker.visible = true
	elif flicker_clock <= 0.0:
		flicker_clock = randf_range(4.0,10.0)
		flicker_active = .22
		flicker_toggle = 0.0
	# Moonshine bubbles rise out of the puddle and pop.
	for i in range(bubbles.size()):
		var bubble: Node3D = bubbles[i]
		var phase := fmod(t*.5+i*.37,1.0)
		bubble.position.y = phase*.55
		bubble.scale = bubble.get_meta("base_scale")*(1.0-phase*.5)
	# Stock pot steam cycles upward with a sideways drift.
	for i in range(puffs.size()):
		var puff: Node3D = puffs[i]
		var phase := fmod(t*.4+i*.31,1.0)
		puff.position = puff.get_meta("base_pos")+Vector3(sin(t*1.3+i*2.0)*.08,phase*1.15,0.0)
		puff.scale = puff.get_meta("base_scale")*(.55+phase*1.1)
	# Stove flames flicker at slightly different rates.
	for i in range(flames.size()):
		flames[i].scale = flame_base[i]*Vector3(
			1.0+sin(t*13.0+i*2.1)*.12,
			1.0+sin(t*17.0+i*1.7)*.18,
			1.0+cos(t*15.0+i*2.6)*.12)
	for fridge in fridge_fans:
		fridge.rotation.x += delta*9.0