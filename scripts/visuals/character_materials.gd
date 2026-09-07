class_name CharacterMaterials
extends RefCounted
## Material factory for characters, props and VFX. Shared materials are cached
## by color so a hundred spheres cost a handful of materials; bodies that need
## their own flash/wobble channels call unique() and get a fresh ShaderMaterial.

const SlimeShader := preload("res://assets/characters/slime.gdshader")
const PartShader := preload("res://assets/characters/character_part.gdshader")
const PopShader := preload("res://assets/effects/pop.gdshader")

static var _parts: Dictionary = {}
static var _toon_parts: Dictionary = {}
static var _toon_faces: Dictionary = {}
static var _metals: Dictionary = {}
static var _pops: Dictionary = {}
static var _lits: Dictionary = {}
static var _glass: StandardMaterial3D


## Chunky matte toy part - the default for vehicles and world props.
static func part(color: Color) -> StandardMaterial3D:
	if not _parts.has(color):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.roughness = .82
		mat.metallic = 0.0
		mat.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
		mat.metallic_specular = .3
		_parts[color] = mat
	return _parts[color]


## Fresh slime-shader material for one body - flash/wobble stay per-character.
static func unique(color: Color, wobble := 0.0) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = SlimeShader
	mat.set_shader_parameter("albedo", color)
	mat.set_shader_parameter("wobble", wobble)
	return mat


## Banded toon material for character bits - mittens, ears, snouts, hats,
## uniform pieces. Same shading family as the slime body shader, cached by
## color so a hundred parts still cost a handful of materials. Vehicles and
## world props stay on the plain part() PBR look.
static func toon_part(color: Color) -> ShaderMaterial:
	if not _toon_parts.has(color):
		var mat := ShaderMaterial.new()
		mat.shader = PartShader
		mat.set_shader_parameter("albedo", color)
		_toon_parts[color] = mat
	return _toon_parts[color]


## Face variant with a raised light floor: pupils, brows and mouths keep their
## contrast when the head sits in a shadow pool instead of dissolving into it.
static func toon_face(color: Color) -> ShaderMaterial:
	if not _toon_faces.has(color):
		var mat := ShaderMaterial.new()
		mat.shader = PartShader
		mat.set_shader_parameter("albedo", color)
		mat.set_shader_parameter("light_floor", 0.5)
		_toon_faces[color] = mat
	return _toon_faces[color]


## Polished metal for tools, ladles, pipes and the dragon.
static func metal(color: Color) -> StandardMaterial3D:
	if not _metals.has(color):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.roughness = .32
		mat.metallic = .8
		_metals[color] = mat
	return _metals[color]


## Shared glassy material for camera domes and bottles.
static func glass() -> StandardMaterial3D:
	if _glass == null:
		_glass = StandardMaterial3D.new()
		_glass.albedo_color = Color(.75, .88, .92, .55)
		_glass.roughness = .08
		_glass.metallic = .2
		_glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_glass.cull_mode = BaseMaterial3D.CULL_BACK
	return _glass


## Glowing part - fire blobs, bait halos, neon accents, lamp bulbs.
static func lit(color: Color, energy := 1.0) -> StandardMaterial3D:
	var key := str(color) + "_" + str(energy)
	if not _lits.has(key):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.roughness = .8
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = energy
		_lits[key] = mat
	return _lits[key]


## Additive fresnel burst material for VFX spheres and rings.
static func pop(color: Color) -> ShaderMaterial:
	if not _pops.has(color):
		var mat := ShaderMaterial.new()
		mat.shader = PopShader
		mat.set_shader_parameter("color", color)
		_pops[color] = mat
	return _pops[color]