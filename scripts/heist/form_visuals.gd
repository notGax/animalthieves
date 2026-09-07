extends RefCounted
## Per-form costume props built on the SAME round slime body - whiskers and
## buck teeth for the rat, snout disc, tusks, small ears and a short curled
## tail for the boar, beak and flapping wing nubs (and nothing else) for the
## bird, dorsal spikes, a forked tongue and a long reptile tail for the lizard.
## Purely cosmetic: the caller toggles visibility locally from the synced
## form field. Returns refs for the animated bits; no cross-species leakage:
## the slime's own big round ears and pink tail show ONLY on the rat.
const Materials = preload("res://scripts/visuals/character_materials.gd")


static func sphere(parent: Node3D, pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = Materials.sphere_mesh(12, 7)
	instance.position = pos
	instance.scale = size
	instance.material_override = Materials.toon_part(color)
	parent.add_child(instance)
	return instance


static func build(blob: Node3D, skin: Dictionary) -> Dictionary:
	var root := Node3D.new()
	root.name = "FormProps"
	blob.add_child(root)
	var rat := Node3D.new()
	rat.name = "rat"
	root.add_child(rat)
	var nose := _rat(rat)
	var boar := Node3D.new()
	boar.name = "boar"
	root.add_child(boar)
	var boar_bits: Dictionary = _boar(boar)
	var bird := Node3D.new()
	bird.name = "bird"
	root.add_child(bird)
	var wings: Array = _bird(bird, skin)
	var lizard := Node3D.new()
	lizard.name = "lizard"
	root.add_child(lizard)
	var lizard_bits: Dictionary = _lizard(lizard)
	return {
		"root": root,
		"wings": wings,
		"tongue": lizard_bits.tongue,
		"nose": nose,
		"boar_ears": boar_bits.ears,
		"boar_tail": boar_bits.tail,
		"lizard_tail": lizard_bits.tail,
	}


static func _rat(parent: Node3D) -> MeshInstance3D:
	var cream := Color("fdf3d0")
	var pink := Color("ff8fa8")
	# Wet nose bump on the snout tip plus two buck teeth under the mouth.
	var nose := sphere(parent, Vector3(0, .78, -.72), Vector3(.16, .13, .12), pink)
	for x in [-.06, .06]:
		sphere(parent, Vector3(x, .58, -.63), Vector3(.07, .17, .05), cream)
	# Three whiskers sweeping out of each cheek.
	for side in [-1.0, 1.0]:
		for i in range(3):
			var whisker := sphere(parent, Vector3.ZERO, Vector3(.4, .018, .018), cream)
			whisker.position = Vector3(side * .48, .72 - i * .06, -.5)
			whisker.rotation = Vector3(0, side * .35, side * (-.3 + i * .3))
	return nose


static func _boar(parent: Node3D) -> Dictionary:
	var cream := Color("fdf3d0")
	var dark := Color("3a2f1c")
	var brown := Color("8a5a33")
	# Snout disc, heavy brow ridge, curling tusks and a bristle crest.
	sphere(parent, Vector3(0, .72, -.68), Vector3(.42, .3, .14), Color("e09a68"))
	sphere(parent, Vector3(0, 1.44, -.5), Vector3(.98, .17, .12), dark)
	for x in [-.44, .44]:
		var tusk := sphere(parent, Vector3(x, .5, -.64), Vector3(.075, .075, .32), cream)
		tusk.rotation.x = -.25
	for i in range(4):
		sphere(parent, Vector3(0, 1.38 - i * .15, .12 + i * .3), Vector3(.09, .3, .09), dark)
	# Small rounded boar ears - distinctly NOT the rat's big dish ears.
	var ears: Array = []
	for side in [-1.0, 1.0]:
		var ear := sphere(parent, Vector3(side * .52, 1.4, -.06), Vector3(.2, .15, .08), brown)
		ear.rotation.z = side * -.5
		ears.append(ear)
	# Short curled pig tail sitting high on the rump: four segments on a pivot
	# chain, so the animation code whips the whole curl from the root and the
	# deeper links swing a beat later - a tail that actually has follow-through.
	var tail: Array = []
	var curl := [Vector3.ZERO, Vector3(0, .1, .04), Vector3(0, .05, -.1), Vector3(0, -.08, -.04)]
	var widths := [.07, .06, .05, .045]
	var anchor := Node3D.new()
	anchor.position = Vector3(0, .95, .58)
	parent.add_child(anchor)
	var link := anchor
	for i in range(4):
		tail.append(link)
		sphere(link, Vector3.ZERO, Vector3(widths[i], widths[i], widths[i]), brown)
		if i < 3:
			var next := Node3D.new()
			next.position = curl[i + 1]
			link.add_child(next)
			link = next
	return {"ears": ears, "tail": tail}


static func _bird(parent: Node3D, skin: Dictionary) -> Array:
	var amber := Color("ffb347")
	# Conical beak where the mouth sits, plus a three-feather crest.
	var beak_mesh := MeshInstance3D.new()
	beak_mesh.mesh = Materials.cyl_mesh(.02, .18, .5, 8)
	beak_mesh.rotation.x = PI * .5
	beak_mesh.position = Vector3(0, .78, -.74)
	beak_mesh.material_override = Materials.part(amber)
	parent.add_child(beak_mesh)
	for i in range(3):
		sphere(parent, Vector3(-.14 + i * .14, 1.52, .12), Vector3(.1, .26, .1), amber)
	# Wing nubs that flap; colored from the wearer's skin. No mammal ears,
	# no rat tail - the bird reads by beak, crest and wings alone.
	var wings: Array = []
	var wing_color: Color = Color("d8b04a")
	if skin.has("deep"):
		wing_color = Color(skin.deep)
	for side in [-1.0, 1.0]:
		var wing := sphere(parent, Vector3(side * 1.28, .85, -.08), Vector3(.52, .28, .64), wing_color)
		wings.append(wing)
	return wings


static func _lizard(parent: Node3D) -> Dictionary:
	var green := Color("4c7a3f")
	# Dorsal spikes down the back and a flicking forked tongue.
	for i in range(4):
		sphere(parent, Vector3(0, 1.34 - i * .14, .14 + i * .3), Vector3(.08, .26, .08), green)
	var tongue := Node3D.new()
	tongue.position = Vector3(0, .64, -.6)
	parent.add_child(tongue)
	for x in [-.04, .04]:
		var fork := sphere(tongue, Vector3(x, -.02, -.16), Vector3(.04, .04, .3), Color("ff6b8f"))
		fork.rotation.x = .25
	# Long tapering reptile tail dragging behind: six segments on a pivot
	# chain running back and slightly down, so lateral swings ripple from the
	# root out to the tip instead of every ring twitching in place.
	var tail: Array = []
	var anchor := Node3D.new()
	anchor.position = Vector3(0, .5, .62)
	parent.add_child(anchor)
	var link := anchor
	for i in range(6):
		var width := .15 - i * .018
		tail.append(link)
		sphere(link, Vector3.ZERO, Vector3(width, width, width * 1.4), green)
		if i < 5:
			var next := Node3D.new()
			next.position = Vector3(0, -.03, .26)
			link.add_child(next)
			link = next
	return {"tongue": tongue, "tail": tail}