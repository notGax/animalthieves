# Create level and lobby

> i want you to create the level and the lobby in this project. it has a multiplayer template already.
>
> User context
>
> Attachments:
> - ## Current game summary We’re building a **1–4 player physics based co-op heist…: `C:/Users/Gauransh/.codex/attachments/87d4ad88-ca44-49ad-8a36-0380dc6fce20/pasted-text.txt`

<details><summary>8 previous messages</summary>

> I’ll read the game summary and inspect the multiplayer template, then build the lobby and level around the existing setup.
>
> The template is Godot, with hosting, joining, player movement, inventory, and synchronized items already in place. I’m building a connected roadside lobby, an underground hideout, and the first rat store with stocked aisles, a back room, a basement distillery, and a boss arena. Later stores will appear along the road as locked destinations.
>
> The layout will let players walk directly from the road into the rat store. Manhole and cellar interactions will connect the underground rooms, and the store will contain physical merchandise using the template’s item replication. I’m keeping the existing player controller; the trader and boss area will be staged for their future gameplay systems.
>
> <details><summary>Created 2 files</summary>
>
> - Wrote `./scripts/level/build_heist_world.py` (+348 -0)
> - Wrote `./scripts/level/heist_world.gd` (+134 -0)
>
> </details>
>
> The world layout is authored, including the shop aisles, checkout, damp utility areas, distillery tanks, hideout workshop, and chef-rat placeholder. I’m wiring the travel points and merchandise into multiplayer now. Recipe recovery will temporarily open the east-road gate so the progression route can be tested before boss combat is added.
>
> Godot imports and runs the new scene without errors. The first checks passed for travel points, merchandise spawning, recipe recovery, gate unlocking, and session reset. I’m now checking a separate client joining an active session and reviewing rendered views of the spaces.
>
> The joining client received all 26 merchandise items and the recovered-recipe/open-gate state. Visual review also revealed a gap between the sidewalk and shop entrance, which I’ve closed. I’ve added roofs and more environmental detail, and I’m finishing the client travel check and setup notes.
>
> The final multiplayer checks passed, including client travel to the hideout and late-join synchronization. The environments are editable Godot scenes. Boss combat, guard AI, trading, production, and usable vehicles remain placeholders; the lobby, store traversal, physical loot, and temporary recipe progression are working.
</details>

Built and integrated a playable environment prototype:

- Roadside lobby with storefronts and a central manhole.
- Underground hideout with trader and production areas.
- Rat Mart with stocked aisles, checkout, stockroom, distillery, and boss arena.
- 26 multiplayer loot objects, travel interactions, and shared recipe/gate progression.

Press **F5 → HOST HEIST** to explore. Use **F** at travel points.

Validated in Godot with separate server/client processes and rendered previews.

Boss combat, guard AI, trading, and production remain placeholders.

[Setup and controls](./HEIST_WORLD.md) · [Editable world scene](./scenes/level/heist_world.tscn)

> man just put in everything. find or make some goodd textures too.

<details><summary>15 previous messages</summary>

> I’ll expand this into a complete first-store gameplay loop: slime players, rat guards, a boss fight, loot extraction, and a working hideout economy. I’ll also replace the plain materials with textured surfaces and improve the lighting and props.
>
> <details><summary>Ran a command</summary>
>
> - Ran `Get-Content scripts/level/heist_world.gd; Get-Content scripts/player/player.gd | Select-Object -Skip 235 -First 160; Get-Content scripts/inventory/player_inventory.gd -TotalCount 170; Get-Content 'C:\Users\Gauransh\.codex\skills\.system\imagegen\SKILL.md' -TotalCount 240; rg --files -g AGENTS.md -g '*heist*' -g '*slime*'; Get-Content scripts/player/spring_arm_offset.gd -TotalCount 160`
>
> </details>
>
> I’m using the imagegen skill to make a texture atlas for brick, tile, wood, and metal. I’m also replacing the recipe pickup shortcut with a boss reward and adding ways to spend the loot you bring home.
>
> Generated image
>
> ![Generated image](/C:/Users/Gauransh/.codex/generated_images/01a07637-8f82-7003-a9c7-7fb2d1743fbd/exec-7b8aad27-4cd5-4ce6-99f6-fb9339646e5a.png)
>
> <details><summary>Ran 2 commands</summary>
>
> - Ran `New-Item -ItemType Directory -Force assets/environment/heist,scripts/heist | Out-Null
> Copy-Item -LiteralPath 'C:\Users\Gauransh\.codex\generated_images\01a07637-8f82-7003-a9c7-7fb2d1743fbd\exec-7b8aad27-4cd5-4ce6-99f6-fb9339646e5a.png' -Destination assets/environment/heist/surface_atlas.png
> Get-Content scripts/inventory/inventory_slot.gd -TotalCount 70; rg -n 'func _get_local_player|func _update_mouse_mode|func is_gameplay_input_blocked|F1|func _debug' scripts/level/level.gd; Get-Content scripts/level/level.gd -Tail 100; Get-Content scenes/level/player.tscn | Select-Object -Skip 4534 -First 70; Get-Content scripts/player/3d_godot_robot.gd -TotalCount 90`
> - Ran `@'
> shader_type spatial;
> render_mode diffuse_burley;
> uniform sampler2D atlas : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
> uniform int surface_kind = 0;
> uniform float tile_size = 4.0;
> uniform vec4 tint : source_color = vec4(1.0);
> varying vec3 world_pos;
> varying vec3 world_normal;
> float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1,311.7))) * 43758.5453); }
> vec3 sample_surface(vec2 p) {
>  vec2 offset = vec2(float(surface_kind % 2), float(surface_kind / 2)) * 0.5;
>  return texture(atlas, offset + clamp(fract(p / tile_size), vec2(0.003), vec2(0.997)) * 0.5).rgb;
> }
> void vertex() {
>  world_pos = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz;
>  world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
> }
> void fragment() {
>  vec3 weights = pow(abs(world_normal), vec3(8.0));
>  weights /= max(dot(weights, vec3(1.0)), 0.001);
>  vec3 c = sample_surface(world_pos.zy) * weights.x + sample_surface(world_pos.xz) * weights.y + sample_surface(world_pos.xy) * weights.z;
>  if (surface_kind == 4) {
>   float n = hash(floor(world_pos.xz * 100.0));
>   c = vec3(0.09,0.115,0.12) + n * 0.07;
>  }
>  ALBEDO = c * tint.rgb;
>  ROUGHNESS = clamp(0.75 + (1.0 - c.r) * 0.2,0.0,1.0);
>  METALLIC = surface_kind == 3 ? 0.25 : 0.0;
> }
> '@ | Set-Content assets/environment/heist/surfaces.gdshader
> @'
> extends Node3D
> ## Procedural expressive avatars share the template's movement and replication.
> var blob: Node3D
> var eyes: Array[MeshInstance3D] = []
> var mouth: MeshInstance3D
> var ears: Node3D
> var material: StandardMaterial3D
> var clock := 0.0
> var character: CharacterBody3D
>
> static func sphere(parent: Node3D, pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
> 	var mesh := SphereMesh.new()
> 	mesh.radial_segments = 24
> 	mesh.rings = 12
> 	var instance := MeshInstance3D.new()
> 	instance.mesh = mesh
> 	instance.position = pos
> 	instance.scale = size
> 	var mat := StandardMaterial3D.new()
> 	mat.albedo_color = color
> 	mat.roughness = .3
> 	instance.material_override = mat
> 	parent.add_child(instance)
> 	return instance
>
> func _ready() -> void:
> 	character = get_parent()
> 	blob = Node3D.new()
> 	add_child(blob)
> 	var colors := [Color("75c6ed"),Color("edcf70"),Color("9edb75"),Color("ed8993")]
> 	var body := sphere(blob, Vector3(0,.7,0), Vector3(1.45,1.4,1.25), colors[character.skin_color])
> 	material = body.material_override
> 	material.roughness = .2
> 	material.metallic = .12
> 	for x in [-.24,.24]:
> 		sphere(blob, Vector3(x,1.03,-.52),Vector3(.38,.45,.18),Color("fffae9"))
> 		eyes.append(sphere(blob,Vector3(x,1.03,-.62),Vector3(.15,.22,.08),Color("152c36")))
> 	mouth = sphere(blob,Vector3(0,.72,-.625),Vector3(.27,.09,.06),Color("25424b"))
> 	sphere(blob,Vector3(-.45,.85,-.45),Vector3(.21,.08,.04),Color("dd9999"))
> 	sphere(blob,Vector3(.45,.85,-.45),Vector3(.21,.08,.04),Color("dd9999"))
> 	ears = Node3D.new()
> 	blob.add_child(ears)
> 	for x in [-.5,.5]:
> 		sphere(ears,Vector3(x,1.5,.05),Vector3(.65,.7,.22),Color("bcaaa0"))
> 		sphere(ears,Vector3(x,1.5,-.08),Vector3(.43,.48,.12),Color("e6a6ac"))
> 	sphere(ears,Vector3(0,.28,.72),Vector3(.2,.18,1.3),Color("daa4aa"))
>
> func _process(delta: float) -> void:
> 	clock += delta
> 	var world := get_node_or_null("/root/Level/Environment/HeistWorld")
> 	var data: Dictionary = world.player_state.get(str(character.name), {}) if world else {}
> 	var form: String = data.get("form", "slime")
> 	ears.visible = form != "slime"
> 	var down: bool = float(data.get("hp",100)) <= 0
> 	var first: bool = character.is_multiplayer_authority() and character._spring_arm_offset.is_first_person
> 	visible = not first
> 	character.get_node("GodotRobot3D/RobotArmature").visible = false
> 	rotation.y = character._body.rotation.y
> 	var moving := Vector2(character.velocity.x,character.velocity.z).length()
> 	var bounce := sin(clock * (12 if moving > .3 else 3)) * (.06 if moving > .3 else .025)
> 	blob.scale = Vector3(1.0-bounce,1.0+bounce,1.0-bounce)
> 	if down:
> 		blob.scale = Vector3(1.3,.25,1.3)
> 	elif form == "rat":
> 		blob.scale *= .7
> 	elif form == "boar":
> 		blob.scale *= 1.22
> 	elif form == "bird":
> 		ears.scale = Vector3(2.0,.5,1)
> 	else:
> 		ears.scale = Vector3.ONE
> 	var target := Vector3.ZERO
> 	var best := 10.0
> 	if world:
> 		for other in character.get_parent().get_children():
> 			if other == character:
> 				continue
> 			var distance: float = other.global_position.distance_to(character.global_position)
> 			if distance < best:
> 				best = distance
> 				target = (other.global_position-character.global_position).normalized()
> 	for eye in eyes:
> 		eye.position.x = (-.24 if eye == eyes[0] else .24) + clampf(target.x * .06,-.06,.06)
> 		eye.scale.y = .025 if fmod(clock,4.1) < .12 else .22
> 	mouth.scale.y = .3 if character.velocity.y < -3 else (.18 if character.is_attacking else .09)
> 	if down:
> 		mouth.scale.y = .035
> '@ | Set-Content scripts/heist/slime_visual.gd
> @'
> extends CharacterBody3D
> ## Server-driven patrol, pursuit, wind-up, charge, stun and boss phases.
> const Visual = preload("res://scripts/heist/slime_visual.gd")
> var world: Node3D
> var home := Vector3.ZERO
> var patrol: Array[Vector3] = []
> var patrol_index := 0
> var hp := 70.0
> var max_hp := 70.0
> var boss := false
> var tier := 0
> var state := "PATROL"
> var timer := 0.0
> var attack_timer := 0.0
> var bribe_time := 0.0
> var path_timer := 0.0
> var path: PackedVector3Array = []
> var charge_dir := Vector3.ZERO
> var model: Node3D
> var title: Label3D
> var tell: MeshInstance3D
> var target_position := Vector3.ZERO
>
> func setup(owner_world: Node3D, origin: Vector3, is_boss: bool, species: int) -> void:
> 	world = owner_world
> 	home = origin
> 	position = origin
> 	boss = is_boss
> 	tier = species
> 	max_hp = (380.0 + tier*150) if boss else (60.0+tier*20)
> 	hp = max_hp
> 	patrol = [origin, origin+Vector3(0,0,5),origin+Vector3(0,0,-3)]
> 	collision_layer = 8
> 	collision_mask = 2
> 	var collision := CollisionShape3D.new()
> 	var capsule := CapsuleShape3D.new()
> 	capsule.radius = 1.0 if boss else .45
> 	capsule.height = 3.0 if boss else 1.8
> 	collision.shape = capsule
> 	collision.position.y = capsule.height*.5
> 	add_child(collision)
> 	model = Node3D.new()
> 	add_child(model)
> 	var skin: Color = [Color("817d70"),Color("a2826c"),Color("bcc5a4"),Color("72987a")][tier]
> 	var scale_factor := 1.7 if boss else 1.0
> 	model.scale = Vector3.ONE*scale_factor
> 	Visual.sphere(model,Vector3(0,.8,0),Vector3(1.25,1.55,.95),skin)
> 	Visual.sphere(model,Vector3(0,1.7,.1),Vector3(1.1,.9,.9),skin)
> 	Visual.sphere(model,Vector3(0,1.5,-.48),Vector3(.65,.4,.75),skin.lightened(.15))
> 	Visual.sphere(model,Vector3(0,1.53,-.83),Vector3(.27,.2,.16),Color("cf9997"))
> 	for x in [-.44,.44]:
> 		Visual.sphere(model,Vector3(x,2.05,.03),Vector3(.56,.6,.22),Color("d3a7a3"))
> 		Visual.sphere(model,Vector3(x*.6,1.8,-.39),Vector3(.27,.29,.14),Color("fff1c8"))
> 		Visual.sphere(model,Vector3(x*.6,1.8,-.47),Vector3(.12,.17,.08),Color("302b25"))
> 		Visual.sphere(model,Vector3(x*1.4,.95,0),Vector3(.25,.75,.3),skin)
> 		Visual.sphere(model,Vector3(x*.6,.15,-.12),Vector3(.43,.3,.65),skin.darkened(.2))
> 	if tier==0:
> 		Visual.sphere(model,Vector3(.3,.25,.65),Vector3(.18,.2,1.3),Color("c4948b"))
> 	if tier==1:
> 		for x in [-.3,.3]:
> 			Visual.sphere(model,Vector3(x,1.4,-.8),Vector3(.14,.5,.15),Color("f4e5bc"))
> 	if tier>=2:
> 		for x in [-.9,.9]:
> 			Visual.sphere(model,Vector3(x,1.1,.1),Vector3(1.5,.24,1.1),skin.darkened(.15))
> 	if boss and tier==0:
> 		Visual.sphere(model,Vector3(0,2.35,0),Vector3(1.2,.75,1.0),Color("ece3c5"))
> 		Visual.sphere(model,Vector3(0,1,-.45),Vector3(.85,1.0,.15),Color("e3dcc5"))
> 	if tier==3:
> 		Visual.sphere(model,Vector3(0,1.2,0),Vector3(1.8,1.9,1.4),Color("425e67"))
> 		Visual.sphere(model,Vector3(0,1.55,-.73),Vector3(.9,.8,.15),Color("99d8c3"))
> 		Visual.sphere(model,Vector3(0,1.58,-.86),Vector3(.34,.4,.2),Color("75a564"))
> 		for x in [-.55,.55]:
> 			Visual.sphere(model,Vector3(x,2.4,0),Vector3(.25,.9,.25),Color("e3be77"))
> 	title = Label3D.new()
> 	title.position.y = 4.5 if boss else 2.6
> 	title.font_size = 28
> 	title.pixel_size = .008
> 	title.billboard = BaseMaterial3D.BILLBOARD_ENABLED
> 	add_child(title)
> 	var ring := CylinderMesh.new()
> 	ring.top_radius = 2.6 if boss else 1.2
> 	ring.bottom_radius = ring.top_radius
> 	ring.height = .025
> 	tell = MeshInstance3D.new()
> 	tell.mesh = ring
> 	tell.position.y = .03
> 	var mat := StandardMaterial3D.new()
> 	mat.albedo_color = Color(1,.25,.08,.38)
> 	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
> 	mat.emission_enabled = true
> 	mat.emission = Color(1,.12,.015)
> 	tell.material_override = mat
> 	add_child(tell)
>
> func _process(delta: float) -> void:
> 	visible = hp > 0
> 	if not visible:
> 		return
> 	var names := ["THE BIG CHEESE","FOREMAN TUSK","MADAM MAGPIE","MECHA DRAGON"]
> 	title.text = (names[tier] if boss else ["Rat security","Boar security","Magpie security","Lizard security"][tier]) + "  %d/%d\n%s" % [ceili(hp),int(max_hp),state]
> 	title.modulate = Color("ffbb81") if boss else Color("d8dda9")
> 	tell.visible = state in ["WIND UP","CHARGE","FIRE BREATH"]
> 	model.position.y = sin(Time.get_ticks_msec()*.009)*.035 if state!="STUNNED" else 0
> 	if not multiplayer.is_server():
> 		position = position.lerp(target_position, minf(1,delta*15))
>
> func _physics_process(delta: float) -> void:
> 	if not multiplayer.has_multiplayer_peer() or not multiplayer.is_server() or hp<=0:
> 		return
> 	if not world.session_active:
> 		return
> 	attack_timer -= delta
> 	bribe_time -= delta
> 	timer -= delta
> 	path_timer -= delta
> 	velocity.y -= 20*delta
> 	var target: Node3D = world.find_target(global_position, 24 if boss else 13,tier)
> 	if state == "STUNNED":
> 		velocity.x = 0
> 		velocity.z = 0
> 		if timer<=0:
> 			state="HUNT"
> 	elif bribe_time>0:
> 		state="BRIBED"
> 		velocity.x=0
> 		velocity.z=0
> 	elif state=="WIND UP":
> 		velocity.x=0
> 		velocity.z=0
> 		if timer<=0:
> 			state="CHARGE"
> 			timer=1.1
> 	elif state=="CHARGE":
> 		velocity.x=charge_dir.x*(19 if boss else 10)
> 		velocity.z=charge_dir.z*(19 if boss else 10)
> 		for player in world.live_players():
> 			if player.global_position.distance_to(global_position)<(3 if boss else 1.8):
> 				world.hurt_player(int(str(player.name)),28+tier*5,charge_dir*10)
> 		if timer<=0 or is_on_wall():
> 			state="STUNNED"
> 			timer=2.2
> 			if is_on_wall() and boss:
> 				take_damage(15)
> 	elif target:
> 		state="HUNT"
> 		var offset: Vector3 = target.global_position-global_position
> 		offset.y=0
> 		if boss and attack_timer<=0 and offset.length()<17:
> 			charge_dir=offset.normalized()
> 			state="WIND UP"
> 			timer=1.15 if hp>max_hp*.45 else .7
> 			attack_timer=4.8 if hp>max_hp*.45 else 3.2
> 			if tier==3 and randf()<.5:
> 				world.fire_breath(global_position,charge_dir)
> 		elif offset.length()<1.7 and attack_timer<=0:
> 			world.hurt_player(int(str(target.name)),10+tier*3,offset.normalized()*3)
> 			attack_timer=1.3
> 		elif path_timer<=0:
> 			path=world.route(global_position,target.global_position)
> 			path_timer=.6
> 		steer(delta,offset,3.6+tier*.35+(1.3 if world.alarm>65 else 0))
> 	else:
> 		state="PATROL"
> 		var destination: Vector3 = patrol[patrol_index]
> 		var bait: Vector3 = world.nearby_bait(global_position)
> 		if bait != Vector3.INF:
> 			destination=bait
> 		var offset := destination-global_position
> 		offset.y=0
> 		if offset.length()<.6:
> 			patrol_index=(patrol_index+1)%patrol.size()
> 			if bait!=Vector3.INF:
> 				bribe_time=6
> 		steer(delta,offset,1.6)
> 	move_and_slide()
> 	if Vector2(velocity.x,velocity.z).length()>.2:
> 		model.rotation.y=lerp_angle(model.rotation.y,atan2(-velocity.x,-velocity.z),delta*8)
> 	if global_position.y < -20:
> 		global_position=home
>
> func steer(_delta: float, direction: Vector3, speed: float) -> void:
> 	if path.size()>0 and state=="HUNT":
> 		while path.size()>0 and global_position.distance_to(path[0])<1.1:
> 			path.remove_at(0)
> 		if path.size()>0:
> 			direction=path[0]-global_position
> 	direction.y=0
> 	direction=direction.normalized()
> 	velocity.x=direction.x*speed
> 	velocity.z=direction.z*speed
>
> func take_damage(amount: float) -> void:
> 	if hp<=0:
> 		return
> 	hp=maxf(0,hp-amount)
> 	world.alarm=minf(100,world.alarm+8)
> 	if hp<=0:
> 		world.enemy_defeated(self)
> '@ | Set-Content scripts/heist/security_guard.gd`
>
> </details>
>
> The texture atlas is generated and saved in the project. Slime visuals and the guard behavior code are in place. Next I’m wiring combat into the shared session state: patrols, cheese distractions, boss charge attacks, player health, revives, and security escalation.
>
> <details><summary>Ran 2 commands</summary>
>
> - Ran `@'
> extends Node3D
> ## Host-authoritative co-op campaign: encounters, economy, tools and world state.
> const Guard = preload("res://scripts/heist/security_guard.gd")
> const GOODS := ["rotten_cheese","moonshine","canned_food","stolen_goods"]
> const SPECIES := ["rat","boar","bird","lizard"]
> const PRICES := {"grapple":80,"water":90,"crystal":65,"jetpack":180,"cart":100,"truck":260,"racecar":200}
> const TOOL_NAMES := {"grapple":"Grappling hook","water":"Water gun","crystal":"Slime crystal","jetpack":"Jetpack","cart":"Shopping cart","truck":"Mini truck","racecar":"Racecar"}
> const SAVE_FILE := "user://crooked_mile_campaign_v2.json"
> @export var persistence_enabled := true
> var recipe_recovered := false
> var stock_spawned := false
> var session_active := false
> var nearest: Marker3D
> var hud: Label
> var prompt: Label
> var toast: Label
> var shop: PanelContainer
> var shop_rows: VBoxContainer
> var shop_open := false
> var request_times: Dictionary = {}
> var action_times: Dictionary = {}
> var player_state: Dictionary = {}
> var enemies: Array = []
> var vehicles: Dictionary = {}
> var vehicle_inputs: Dictionary = {}
> var campaign: Dictionary = {}
> var alarm := 0.0
> var sabotage := 0
> var defeated := [false,false,false,false]
> var bait: Array = []
> var fires: Array = []
> var nav := AStar3D.new()
> var sync_clock := 0.0
> var save_clock := 0.0
> var toast_clock := 0.0
> var vehicle_clock := 0.0
> var wipe_clock := 0.0
> var game_clock := 0.0
> var sound_cache: Dictionary = {}
>
> func _ready() -> void:
> 	fresh_campaign()
> 	build_ui()
> 	build_encounters()
> 	build_vehicles()
> 	Network.player_connected.connect(_on_player_connected)
> 	Network.server_disconnected.connect(_reset)
> 	multiplayer.peer_disconnected.connect(_peer_left)
> 	call_deferred("build_navigation")
>
> func fresh_campaign() -> void:
> 	campaign={"cash":160,"bank":0.0,"recipes":[0,0,0,0],"machines":[-1],"gear":["grapple"],"forms":[],"upgrades":{},"crystals":1,"wins":0}
>
> func load_campaign() -> void:
> 	if not persistence_enabled or not FileAccess.file_exists(SAVE_FILE):
> 		return
> 	var file := FileAccess.open(SAVE_FILE,FileAccess.READ)
> 	if not file:
> 		return
> 	var data = JSON.parse_string(file.get_as_text())
> 	if data is Dictionary and data.get("recipes") is Array and data.recipes.size()==4:
> 		for key in campaign:
> 			if data.has(key) and typeof(data[key])==typeof(campaign[key]):
> 				campaign[key]=data[key]
> 		# JSON numbers decode as floats.
> 		for key in ["cash","crystals","wins"]:
> 			campaign[key]=maxi(0,int(data.get(key,campaign[key])))
> 		campaign.bank=maxf(0,float(data.get("bank",0)))
>
> func save_campaign() -> void:
> 	if not persistence_enabled or not multiplayer.is_server() or not session_active:
> 		return
> 	var file := FileAccess.open(SAVE_FILE,FileAccess.WRITE)
> 	if file:
> 		file.store_string(JSON.stringify(campaign))
>
> func _exit_tree() -> void:
> 	if session_active and multiplayer.is_server():
> 		save_campaign()
>
> func _reset() -> void:
> 	# Economy is saved on every transaction and periodically during production.
> 	session_active=false
> 	stock_spawned=false
> 	player_state.clear()
> 	request_times.clear()
> 	action_times.clear()
> 	vehicle_inputs.clear()
> 	bait.clear()
> 	fires.clear()
> 	alarm=0
> 	sabotage=0
> 	defeated=[false,false,false,false]
> 	close_shop()
> 	for enemy in enemies:
> 		enemy.hp=enemy.max_hp
> 		enemy.position=enemy.home
> 		enemy.target_position=enemy.home
> 		enemy.state="PATROL"
> 	for kind in vehicles:
> 		vehicles[kind].rider=0
> 		vehicles[kind].node.position=vehicles[kind].home
> 	fresh_campaign()
> 	apply_progress(false)
>
> func _peer_left(id: int) -> void:
> 	player_state.erase(str(id))
> 	for kind in vehicles:
> 		if vehicles[kind].rider==id:
> 			vehicles[kind].rider=0
>
> func _on_player_connected(id: int, _info: Dictionary) -> void:
> 	if multiplayer.is_server():
> 		if not session_active:
> 			load_campaign()
> 			session_active=true
> 			apply_progress(int(campaign.recipes[0])>0)
> 		ensure_player(id)
> 		call_deferred("_stock_store")
> 		call_deferred("broadcast_state")
> 	else:
> 		session_active=true
> 		request_progress.rpc_id(1)
>
> func ensure_player(id: int) -> Dictionary:
> 	var key := str(id)
> 	if not player_state.has(key):
> 		player_state[key]={"hp":100.0,"form":"slime","form_cooldown":0.0,"speed_buff":0.0,"strength_buff":0.0,"hurt_cooldown":0.0,"down_time":0.0,"tool":"grapple","fuel":100.0,"vehicle":"","grapple_cd":0.0}
> 	return player_state[key]
>
> func live_players() -> Array:
> 	var found: Array = []
> 	for player in get_tree().current_scene.get_node("PlayersContainer").get_children():
> 		if float(player_state.get(str(player.name),{}).get("hp",100))>0:
> 			found.append(player)
> 	return found
>
> func player_for(id: int) -> CharacterBody3D:
> 	return get_tree().current_scene.get_node_or_null("PlayersContainer/"+str(id)) as CharacterBody3D
>
> func local_player() -> CharacterBody3D:
> 	return player_for(multiplayer.get_unique_id()) if multiplayer.has_multiplayer_peer() else null
>
> func build_encounters() -> void:
> 	var group := Node3D.new()
> 	group.name="Security"
> 	add_child(group)
> 	var specs := [
> 		[Vector3(-6.5,.1,-35),false,0],[Vector3(8.5,.1,-42),false,0],
> 		[Vector3(10,.1,-57),false,0],[Vector3(10,-11.9,-49),false,0],
> 		[Vector3(0,.1,-70),true,0],
> 		[Vector3(40,.1,-29),false,1],[Vector3(50,.1,-39),false,1],[Vector3(45,.1,-51),true,1],
> 		[Vector3(56,.1,31),false,2],[Vector3(66,.1,43),false,2],[Vector3(61,.1,53),true,2],
> 		[Vector3(69,.1,-29),false,3],[Vector3(79,.1,-38),false,3],[Vector3(74,.1,-51),true,3]]
> 	for i in specs.size():
> 		var enemy = Guard.new()
> 		enemy.name="Guard%d"%i
> 		enemy.setup(self,specs[i][0],specs[i][1],specs[i][2])
> 		group.add_child(enemy)
> 		enemies.append(enemy)
> 	var dummy := get_node_or_null("RatStore/ChefRat")
> 	if dummy:
> 		dummy.hide()
>
> func build_navigation() -> void:
> 	await get_tree().physics_frame
> 	var id := 0
> 	for x in [-14.0,-6.5,.5,8.5,11.0]:
> 		for z in [-26.0,-36.5,-47.5,-54.0,-62.0,-68.0,-75.0]:
> 			nav.add_point(id,Vector3(x,.2,z))
> 			id+=1
> 	for a in nav.get_point_ids():
> 		for b in nav.get_point_ids():
> 			if b<=a:
> 				continue
> 			var from := nav.get_point_position(a)
> 			var to := nav.get_point_position(b)
> 			if from.distance_to(to)<13 and clear_line(from+Vector3.UP,to+Vector3.UP):
> 				nav.connect_points(a,b)
>
> func clear_line(from: Vector3,to: Vector3) -> bool:
> 	var query := PhysicsRayQueryParameters3D.create(from,to,2)
> 	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()
>
> func route(from: Vector3,to: Vector3) -> PackedVector3Array:
> 	if clear_line(from+Vector3.UP,to+Vector3.UP) or from.y < -5 or absf(from.x)>17:
> 		return PackedVector3Array([to])
> 	if nav.get_point_count()==0:
> 		return PackedVector3Array([to])
> 	var start := nav.get_closest_point(from)
> 	var end := nav.get_closest_point(to)
> 	return nav.get_point_path(start,end)
>
> func find_target(origin: Vector3,radius: float,species: int) -> Node3D:
> 	var closest: Node3D = null
> 	for player in live_players():
> 		if absf(player.global_position.y-origin.y)>4 or store_tier(player.global_position)!=species:
> 			continue
> 		if player_state.get(str(player.name),{}).get("form", "slime")==SPECIES[species] and alarm<50:
> 			continue
> 		var distance: float = player.global_position.distance_to(origin)
> 		if distance<radius and clear_line(origin+Vector3.UP,player.global_position+Vector3.UP):
> 			radius=distance
> 			closest=player
> 	return closest
>
> func store_tier(point: Vector3) -> int:
> 	if point.z < -23 and absf(point.x)<17:
> 		return 0
> 	if point.z < -19 and point.x>33 and point.x<57:
> 		return 1
> 	if point.z>20 and point.x>49 and point.x<73 and point.y>-5:
> 		return 2
> 	if point.z < -19 and point.x>62:
> 		return 3
> 	return -1
>
> func nearby_bait(point: Vector3) -> Vector3:
> 	for food in bait:
> 		if point.distance_to(food.position)<14:
> 			return food.position
> 	return Vector3.INF
>
> func _stock_store() -> void:
> 	if stock_spawned:
> 		return
> 	stock_spawned=true
> 	var container := get_node("../ItemContainer")
> 	for marker in $LootSpawns.get_children():
> 		var item: Node3D=load(marker.get_meta("scene")).instantiate()
> 		item.position=container.to_local(marker.global_position)
> 		container.add_child(item,true)
>
> func _physics_process(delta: float) -> void:
> 	if not multiplayer.has_multiplayer_peer() or not multiplayer.is_server() or not session_active:
> 		return
> 	game_clock+=delta
> 	sync_clock+=delta
> 	save_clock+=delta
> 	alarm=maxf(0,alarm-delta*1.1)
> 	for key in player_state:
> 		var data: Dictionary=player_state[key]
> 		for timer in ["form_cooldown","speed_buff","strength_buff","hurt_cooldown","grapple_cd"]:
> 			data[timer]=maxf(0,float(data[timer])-delta)
> 		var player := player_for(int(key))
> 		if not player:
> 			continue
> 		if player.global_position.y < -5 and player.global_position.z>0:
> 			data.fuel=minf(100,float(data.fuel)+delta*15)
> 			data.hp=minf(100,float(data.hp)+delta*5)
> 		if float(data.hp)<=0:
> 			data.down_time+=delta
> 			if float(data.down_time)>30:
> 				revive(int(key),50)
> 				travel.rpc(int(key),Vector3(0,-10.9,25))
> 		else:
> 			data.down_time=0
> 		if store_tier(player.global_position)>=0:
> 			alarm=minf(100,alarm+delta*.3)
> 		var active_form: String=data.form
> 		if active_form!="slime" and active_form not in campaign.forms:
> 			data.form="slime"
> 	for machine in campaign.machines:
> 		var recipe_index := int(machine)
> 		if recipe_index>=0 and recipe_index<4:
> 			campaign.bank+=delta*(1.0+recipe_index*1.5)*int(campaign.recipes[recipe_index])
> 	for i in range(bait.size()-1,-1,-1):
> 		bait[i].time-=delta
> 		if bait[i].time<=0:
> 			bait.remove_at(i)
> 	for i in range(fires.size()-1,-1,-1):
> 		fires[i].time-=delta
> 		if fires[i].time<=0:
> 			fires.remove_at(i)
> 			continue
> 		for player in live_players():
> 			if player.global_position.distance_to(fires[i].position)<2.6:
> 				hurt_player(int(str(player.name)),5,Vector3.ZERO)
> 		for enemy in enemies:
> 			if enemy.hp>0 and enemy.global_position.distance_to(fires[i].position)<3:
> 				enemy.take_damage(delta*15)
> 	update_vehicles(delta)
> 	if not player_state.is_empty() and live_players().is_empty():
> 		wipe_clock+=delta
> 		if wipe_clock>5:
> 			for key in player_state:
> 				revive(int(key),75)
> 				travel.rpc(int(key),Vector3(0,-10.9,25))
> 			campaign.cash=maxi(0,int(campaign.cash)-30)
> 			alarm=0
> 			notice.rpc("Crew rescued. $30 recovery fee. Your loot is still in your bags.")
> 			wipe_clock=0
> 	else:
> 		wipe_clock=0
> 	if sync_clock>=.1:
> 		sync_clock=0
> 		broadcast_state()
> 	if save_clock>=10:
> 		save_clock=0
> 		save_campaign()
>
> func hurt_player(id: int,amount: float,knockback: Vector3) -> void:
> 	var data := ensure_player(id)
> 	if float(data.hp)<=0 or float(data.hurt_cooldown)>0:
> 		return
> 	data.hp=maxf(0,float(data.hp)-amount)
> 	data.hurt_cooldown=.8
> 	if data.hp<=0:
> 		data.vehicle=""
> 		for kind in vehicles:
> 			if vehicles[kind].rider==id:
> 				vehicles[kind].rider=0
> 		notice.rpc("A slime is down! F nearby to revive, or use a slime crystal.")
> 	else:
> 		impulse_player.rpc(id,knockback+Vector3.UP*2)
>
> func revive(id: int,health: float) -> void:
> 	var data := ensure_player(id)
> 	data.hp=health
> 	data.down_time=0
> 	data.hurt_cooldown=3.0
>
> func enemy_defeated(enemy: Node3D) -> void:
> 	if enemy.boss:
> 		var tier: int=enemy.tier
> 		if defeated[tier]:
> 			return
> 		defeated[tier]=true
> 		campaign.recipes[tier]=int(campaign.recipes[tier])+1
> 		campaign.cash+=150+tier*120
> 		campaign.wins+=1
> 		if int(campaign.machines[0])<0:
> 			campaign.machines[0]=tier
> 		if randf()<.4 and SPECIES[tier] not in campaign.forms:
> 			campaign.forms.append(SPECIES[tier])
> 			notice.rpc("RARE DROP! %s transformation unlocked for the whole crew."%SPECIES[tier].to_upper())
> 		else:
> 			notice.rpc("BOSS DEFEATED! Recipe upgraded to level %d. $%d recovered."%[campaign.recipes[tier],150+tier*120])
> 		apply_progress.rpc(int(campaign.recipes[0])>0)
> 		fx.rpc(enemy.global_position+Vector3.UP*2,Color("d9ed84"),3.0)
> 		play_sound.rpc("win")
> 		save_campaign()
> 	else:
> 		campaign.cash+=12+enemy.tier*5
> 		fx.rpc(enemy.global_position+Vector3.UP,Color("c0d39b"),.5)
>
> func fire_breath(origin: Vector3,direction: Vector3) -> void:
> 	for i in range(1,5):
> 		var pos := origin+direction*i*2
> 		fires.append({"position":pos,"time":4.0})
> 		fx.rpc(pos+Vector3.UP*.4,Color("ff7d31"),2.0)
>
> func _process(delta: float) -> void:
> 	var level := get_tree().current_scene
> 	var active: bool=multiplayer.has_multiplayer_peer() and not level.main_menu.is_menu_visible()
> 	hud.visible=active
> 	prompt.visible=active and not level.is_camera_input_blocked()
> 	toast.visible=active and toast_clock>0
> 	toast_clock-=delta
> 	if not active:
> 		return
> 	var player := local_player()
> 	if not player:
> 		return
> 	var data: Dictionary=player_state.get(str(player.name),{})
> 	var location := "THE CROOKED MILE"
> 	var tier := store_tier(player.global_position)
> 	if tier>=0:
> 		location=["RAT MART","BOAR HARDWARE","BIRD SEED & CO.","COLD BLOOD ELECTRONICS"][tier]
> 	if player.global_position.y < -5:
> 		location="THE UNDERCUT" if player.global_position.z>0 else "BASEMENT DISTILLERY"
> 	var task := "Rob Rat Mart. Defeat the chef. Bring your loot to the van."
> 	if int(campaign.recipes[0])>0:
> 		task="East road open. Raid the next store or replay an earlier heist."
> 	if int(campaign.recipes[3])>0:
> 		task="The mecha dragon is down. The Crooked Mile belongs to your crew."
> 	hud.text="%s   |   CREW %d/4\nHP %d   $%d shared   Income $%d   Alarm %d%%\n%s\n%s  |  %s  |  Form cooldown %ds"%[location,Network.players.size(),int(data.get("hp",100)),int(campaign.cash),int(campaign.bank),int(alarm),task,TOOL_NAMES.get(data.get("tool","grapple"),""),str(data.get("form","slime")).to_upper(),ceili(float(data.get("form_cooldown",0)))]
> 	nearest=null
> 	var distance := 3.3
> 	for marker in $Interactions.get_children():
> 		var d: float=player.global_position.distance_to(marker.global_position)
> 		if d<distance:
> 			distance=d
> 			nearest=marker
> 	prompt.text="LMB Slap  |  RMB Tool  |  Q Switch tool  |  B Cheese bait  |  H Eat  |  R Transform  |  X Slime"
> 	if nearest:
> 		prompt.text="[F] "+str(nearest.get_meta("hint"))
> 	for other in level.players_container.get_children():
> 		if other!=player and other.global_position.distance_to(player.global_position)<3 and float(player_state.get(str(other.name),{}).get("hp",100))<=0:
> 			prompt.text="[F] Revive teammate"
> 	var riding: String=data.get("vehicle","")
> 	if riding!="" and vehicles.has(riding):
> 		player.global_position=vehicles[riding].node.global_position+Vector3(0,1.0,0)
> 		player.velocity=Vector3.ZERO
> 		prompt.text="WASD Drive   |   F Dismount   |   Drive to the loading bay to unload"
> 		vehicle_clock+=delta
> 		if vehicle_clock>.1 and not level.is_camera_input_blocked():
> 			vehicle_clock=0
> 			var direction := aim_direction()
> 			var movement := Input.get_vector("move_left","move_right","move_forward","move_backward")
> 			if multiplayer.is_server():
> 				drive(movement,direction)
> 			else:
> 				drive.rpc_id(1,movement,direction)
> 	else:
> 		for kind in vehicles:
> 			if kind in campaign.gear and vehicles[kind].node.global_position.distance_to(player.global_position)<3:
> 				prompt.text="[F] Drive "+TOOL_NAMES[kind]
> 	if float(data.get("hp",100))<=0:
> 		prompt.text="DOWNED - teammates can revive you. Rescue in %ds."%maxi(0,30-int(data.get("down_time",0)))
> 	if shop_open:
> 		update_shop_header()
>
> func aim_direction() -> Vector3:
> 	var player := local_player()
> 	if not player:
> 		return Vector3.FORWARD
> 	return -player.get_node("SpringArmOffset/SpringArm3D/Camera3D").global_basis.z
>
> func submit(action: String, argument: String="") -> void:
> 	if multiplayer.is_server():
> 		request_action(action,argument,aim_direction())
> 	else:
> 		request_action.rpc_id(1,action,argument,aim_direction())
>
> func _unhandled_input(event: InputEvent) -> void:
> 	if not local_player() or get_tree().current_scene.main_menu.is_menu_visible():
> 		return
> 	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode==KEY_ESCAPE and shop_open:
> 		close_shop()
> 		get_viewport().set_input_as_handled()
> 		return
> 	if get_tree().current_scene.is_camera_input_blocked():
> 		return
> 	if event is InputEventMouseButton and event.pressed:
> 		if event.button_index==MOUSE_BUTTON_LEFT:
> 			submit("attack")
> 		elif event.button_index==MOUSE_BUTTON_RIGHT:
> 			submit("tool")
> 	if event is InputEventKey and event.pressed and not event.echo:
> 		match event.physical_keycode:
> 			KEY_F:
> 				if nearest and str(nearest.name)=="Trader":
> 					open_shop()
> 				else:
> 					submit("interact",str(nearest.name) if nearest else "")
> 			KEY_Q: submit("cycle")
> 			KEY_B: submit("bait")
> 			KEY_H: submit("eat")
> 			KEY_R: submit("transform")
> 			KEY_X: submit("slime")
>
> @rpc("any_peer","call_local","reliable")
> func request_action(action: String,argument: String,direction: Vector3) -> void:
> 	if not multiplayer.is_server() or not session_active:
> 		return
> 	var id := multiplayer.get_remote_sender_id()
> 	if id==0: id=1
> 	var player := player_for(id)
> 	if not player or not direction.is_finite() or direction.length_squared()<.5 or direction.length_squared()>1.5:
> 		return
> 	direction=direction.normalized()
> 	var data := ensure_player(id)
> 	if float(data.hp)<=0:
> 		return
> 	var now := Time.get_ticks_msec()
> 	var key := str(id)+action
> 	var cooldown := 550 if action=="attack" else (350 if action=="tool" else 250)
> 	if now-int(action_times.get(key,-10000))<cooldown:
> 		return
> 	action_times[key]=now
> 	match action:
> 		"attack": melee(player,direction)
> 		"tool": use_tool(player,direction)
> 		"interact": interact(player,argument)
> 		"shop": shop_action(player,argument)
> 		"cycle":
> 			var index: int=campaign.gear.find(data.tool)
> 			data.tool=campaign.gear[(index+1)%campaign.gear.size()]
> 		"bait":
> 			if consume(player,"rotten_cheese"):
> 				var pos := player.global_position+Vector3(direction.x,0,direction.z)*3
> 				bait.append({"position":pos,"time":18.0})
> 				fx.rpc(pos+Vector3.UP*.3,Color("b7d85b"),.5)
> 				for enemy in enemies:
> 					if enemy.tier==0 and enemy.global_position.distance_to(pos)<8:
> 						enemy.bribe_time=8
> 				alarm=maxf(0,alarm-15)
> 		"eat":
> 			if consume(player,"rotten_cheese"):
> 				data.speed_buff=20.0
> 				notice.rpc("Rotten cheese: speed and scent for 20 seconds.")
> 			elif consume(player,"moonshine"):
> 				data.strength_buff=20.0
> 				data.fuel=minf(100,float(data.fuel)+40)
> 				notice.rpc("Moonshine: stronger slaps, unsteady aim, jetpack refueled.")
> 			elif consume(player,"canned_food"):
> 				data.hp=minf(100,float(data.hp)+30)
> 		"transform":
> 			if campaign.forms.is_empty():
> 				notice.rpc("Bosses can drop rare transformations. Revisit their stores.")
> 			elif float(data.form_cooldown)<=0:
> 				var index: int=campaign.forms.find(data.form)
> 				data.form=campaign.forms[(index+1)%campaign.forms.size()]
> 				data.form_cooldown=120.0
> 				fx.rpc(player.global_position,Color("a9df9f"),1.0)
> 		"slime": data.form="slime"
> 	broadcast_state()
>
> func consume(player: CharacterBody3D,item_id: String) -> bool:
> 	if player.player_inventory and player.player_inventory.remove_item(item_id,1)>0:
> 		player._sync_inventory_to_owner()
> 		return true
> 	return false
>
> func melee(player: CharacterBody3D,direction: Vector3) -> void:
> 	var data: Dictionary=player_state[str(player.name)]
> 	var damage := 25.0 * (1.8 if float(data.strength_buff)>0 else 1.0)
> 	if data.form=="boar": damage*=1.5
> 	damage*=1+int(campaign.upgrades.get(data.form,0))*.15
> 	for enemy in enemies:
> 		var offset: Vector3=enemy.global_position-player.global_position
> 		if enemy.hp>0 and offset.length()<4.3 and offset.normalized().dot(direction)>.05 and clear_line(player.global_position+Vector3.UP,enemy.global_position+Vector3.UP):
> 			enemy.take_damage(damage)
> 			fx.rpc(enemy.global_position+Vector3.UP,Color("f2d9a1"),.4)
> 	play_sound.rpc("slap")
> 	# Fire-breathing lizard form and ignitable spilled spirits.
> 	if data.form=="lizard":
> 		fire_breath(player.global_position,Vector3(direction.x,0,direction.z).normalized())
>
> func interact(player: CharacterBody3D,marker_name: String) -> void:
> 	var id := int(str(player.name))
> 	var data: Dictionary=player_state[str(id)]
> 	if data.vehicle!="":
> 		var kind: String=data.vehicle
> 		vehicles[kind].rider=0
> 		data.vehicle=""
> 		travel.rpc(id,vehicles[kind].node.global_position+Vector3(2,1,0))
> 		return
> 	for other_key in player_state:
> 		var other := player_for(int(other_key))
> 		if other and other!=player and float(player_state[other_key].hp)<=0 and player.global_position.distance_to(other.global_position)<3:
> 			revive(int(other_key),40)
> 			play_sound.rpc("heal")
> 			return
> 	for kind in vehicles:
> 		if kind in campaign.gear and vehicles[kind].rider==0 and vehicles[kind].node.global_position.distance_to(player.global_position)<3:
> 			vehicles[kind].rider=id
> 			data.vehicle=kind
> 			return
> 	var marker: Marker3D=null
> 	for candidate in $Interactions.get_children():
> 		if str(candidate.name)==marker_name:
> 			marker=candidate
> 	if not marker or player.global_position.distance_to(marker.global_position)>4:
> 		return
> 	if marker.has_meta("destination"):
> 		if marker_name.begins_with("RatTunnel") and data.form!="rat":
> 			notice.rpc("Only rat form fits through this shortcut.")
> 			return
> 		travel.rpc(id,marker.get_meta("destination"))
> 	elif marker_name=="Extract":
> 		sell_loot(player)
> 	elif marker_name=="CollectIncome":
> 		campaign.cash+=int(campaign.bank)
> 		campaign.bank-=int(campaign.bank)
> 		play_sound.rpc("cash")
> 		save_campaign()
> 	elif marker_name.begins_with("Valve"):
> 		var index := marker_name.trim_prefix("Valve").to_int()
> 		if index>=0 and index<3 and (sabotage & (1<<index))==0:
> 			sabotage|=1<<index
> 			for enemy in enemies:
> 				if enemy.boss and enemy.tier==0:
> 					enemy.take_damage(65)
> 					enemy.state="STUNNED"
> 					enemy.timer=4.0
> 			fire_breath(marker.global_position,Vector3.FORWARD)
> 			notice.rpc("Distillery sabotaged! The chef loses 65 health. Watch the burning spill.")
> 	elif marker_name=="Replay":
> 		for other in live_players():
> 			if store_tier(other.global_position)>=0:
> 				notice.rpc("Gather the entire crew outside the stores before restocking.")
> 				return
> 		reset_heists()
> 	elif marker_name=="Recipe":
> 		notice.rpc("Defeat the chef to recover and upgrade this recipe.")
>
> func sell_loot(player: CharacterBody3D) -> void:
> 	var earned := 0
> 	for item_id in GOODS:
> 		var quantity: int=player.player_inventory.remove_item(item_id,9999)
> 		earned+=quantity*ItemDatabase.get_item(item_id).value
> 	for item in get_node("../ItemContainer").get_children():
> 		if item.item_id in GOODS and item.global_position.distance_to(Vector3(9,1,-12))<7:
> 			earned+=ItemDatabase.get_item(item.item_id).value
> 			item.queue_free()
> 	campaign.cash+=earned
> 	player._sync_inventory_to_owner()
> 	notice.rpc("Loot delivered: $%d added to crew funds."%earned)
> 	play_sound.rpc("cash")
> 	save_campaign()
>
> func reset_heists() -> void:
> 	for enemy in enemies:
> 		enemy.hp=enemy.max_hp
> 		enemy.position=enemy.home
> 		enemy.target_position=enemy.home
> 		enemy.state="PATROL"
> 		enemy.bribe_time=0
> 	for item in get_node("../ItemContainer").get_children():
> 		if item.item_id in GOODS:
> 			item.queue_free()
> 	stock_spawned=false
> 	defeated=[false,false,false,false]
> 	sabotage=0
> 	alarm=0
> 	bait.clear()
> 	fires.clear()
> 	call_deferred("_stock_store")
> 	notice.rpc("Stores restocked. Bosses return with fresh blueprint upgrades and rare drops.")
>
> # Compatibility entry points for scene interactions and test tooling.
> @rpc("any_peer","call_local","reliable")
> func request_interaction(marker_name: String) -> void:
> 	if not multiplayer.is_server(): return
> 	var id := multiplayer.get_remote_sender_id()
> 	if id==0: id=1
> 	var player := player_for(id)
> 	if player and float(ensure_player(id).hp)>0:
> 		var now := Time.get_ticks_msec()
> 		if now-int(request_times.get(id,-1000))<400: return
> 		request_times[id]=now
> 		interact(player,marker_name)
>
> @rpc("authority","call_local","reliable")
> func travel(id: int,destination: Vector3) -> void:
> 	var player := player_for(id)
> 	if player:
> 		player.global_position=destination
> 		player.velocity=Vector3.ZERO
>
> @rpc("authority","call_local","reliable")
> func impulse_player(id: int,impulse: Vector3) -> void:
> 	var player := player_for(id)
> 	if player and player.is_multiplayer_authority():
> 		player.velocity+=impulse
>
> @rpc("authority","call_local","reliable")
> func apply_progress(recovered: bool) -> void:
> 	recipe_recovered=recovered
> 	$Road/Gate.visible=not recovered
> 	for shape in $Road/Gate.find_children("*","CollisionShape3D",true,false):
> 		shape.set_deferred("disabled",recovered)
> 	$Hideout/Blueprint.visible=recovered
> 	$RatStore/RecipeDisplay.visible=not recovered
> 	for tier in range(1,4):
> 		var door := get_node_or_null("Expansion/Store%d/Lock"%tier)
> 		if door:
> 			var locked := int(campaign.recipes[tier-1])==0
> 			door.visible=locked
> 			for shape in door.find_children("*","CollisionShape3D",true,false):
> 				shape.set_deferred("disabled",not locked)
> '@ | Set-Content scripts/level/heist_world.gd`
> - Ran `@'
>
> func use_tool(player: CharacterBody3D,direction: Vector3) -> void:
> 	var id := int(str(player.name))
> 	var data: Dictionary=player_state[str(id)]
> 	var tool: String=data.tool
> 	if tool not in campaign.gear:
> 		return
> 	if float(data.strength_buff)>0:
> 		direction=(direction+Vector3(randf_range(-.16,.16),0,randf_range(-.16,.16))).normalized()
> 	match tool:
> 		"grapple":
> 			if float(data.grapple_cd)>0: return
> 			data.grapple_cd=1.2
> 			var origin := player.global_position+Vector3.UP*1.3
> 			var query := PhysicsRayQueryParameters3D.create(origin,origin+direction*28,31,[player.get_rid()])
> 			var hit := get_world_3d().direct_space_state.intersect_ray(query)
> 			if hit.is_empty(): return
> 			beam.rpc(origin,hit.position,Color("d3c493"))
> 			var object = hit.collider
> 			if object is RigidBody3D:
> 				object.apply_central_impulse((origin-object.global_position).normalized()*object.mass*12)
> 			elif object is CharacterBody3D and object.get_parent()==player.get_parent():
> 				impulse_player.rpc(int(str(object.name)),(origin-object.global_position).normalized()*12+Vector3.UP*3)
> 			else:
> 				impulse_player.rpc(id,direction*17+Vector3.UP*9)
> 			play_sound.rpc("tool")
> 		"water":
> 			beam.rpc(player.global_position+Vector3.UP,player.global_position+Vector3.UP+direction*15,Color("7acde8"))
> 			for other in live_players():
> 				if other==player: continue
> 				var offset: Vector3=other.global_position-player.global_position
> 				if offset.length()<15 and offset.normalized().dot(direction)>.88 and clear_line(player.global_position+Vector3.UP,other.global_position+Vector3.UP):
> 					var target: Dictionary=player_state[str(other.name)]
> 					target.hp=minf(100,float(target.hp)+14)
> 			for i in range(fires.size()-1,-1,-1):
> 				if fires[i].position.distance_to(player.global_position+direction*5)<9:
> 					fires.remove_at(i)
> 			for enemy in enemies:
> 				var offset: Vector3=enemy.global_position-player.global_position
> 				if offset.length()<12 and offset.normalized().dot(direction)>.9:
> 					enemy.state="STUNNED"
> 					enemy.timer=.6
> 		"crystal":
> 			if int(campaign.crystals)<=0:
> 				notice.rpc("No slime crystals left. Buy one from the trader.")
> 				return
> 			for key in player_state:
> 				var other := player_for(int(key))
> 				if other and other!=player and float(player_state[key].hp)<=0 and other.global_position.distance_to(player.global_position)<12:
> 					campaign.crystals-=1
> 					revive(int(key),100)
> 					fx.rpc(other.global_position,Color("acd9ff"),1.5)
> 					play_sound.rpc("heal")
> 					save_campaign()
> 					return
> 		"jetpack":
> 			if float(data.fuel)>=12:
> 				data.fuel-=12
> 				impulse_player.rpc(id,Vector3(direction.x*5,10,direction.z*5))
> 				fx.rpc(player.global_position,Color("ffb66e"),.4)
> 		_:
> 			notice.rpc("Your vehicle is parked on the road. Press F beside it to drive.")
>
> func build_vehicles() -> void:
> 	for i in range(3):
> 		var kind: String=["cart","truck","racecar"][i]
> 		var body := RigidBody3D.new()
> 		body.name=kind.capitalize()
> 		body.mass=[8.0,60.0,15.0][i]
> 		body.collision_layer=16
> 		body.collision_mask=6
> 		body.lock_rotation=true
> 		body.linear_damp=.5
> 		body.position=Vector3(-8+i*6,1,12)
> 		add_child(body)
> 		var shape := BoxShape3D.new()
> 		shape.size=[Vector3(1.6,.5,2.3),Vector3(2.5,1.1,4),Vector3(1.5,.6,2.5)][i]
> 		var collision := CollisionShape3D.new()
> 		collision.shape=shape
> 		body.add_child(collision)
> 		var mesh := MeshInstance3D.new()
> 		var box := BoxMesh.new()
> 		box.size=shape.size
> 		mesh.mesh=box
> 		var material := StandardMaterial3D.new()
> 		material.albedo_color=[Color("829e89"),Color("cbab63"),Color("ad5652")][i]
> 		material.metallic=.35
> 		mesh.material_override=material
> 		body.add_child(mesh)
> 		for x in [-shape.size.x*.5,shape.size.x*.5]:
> 			for z in [-shape.size.z*.33,shape.size.z*.33]:
> 				var wheel := MeshInstance3D.new()
> 				var cylinder := CylinderMesh.new()
> 				cylinder.top_radius=.35
> 				cylinder.bottom_radius=.35
> 				cylinder.height=.18
> 				wheel.mesh=cylinder
> 				wheel.rotation.z=PI*.5
> 				wheel.position=Vector3(x,-.3,z)
> 				var rubber := StandardMaterial3D.new()
> 				rubber.albedo_color=Color("182929")
> 				wheel.material_override=rubber
> 				body.add_child(wheel)
> 		# Cargo walls make carts/trucks carry actual rigid merchandise.
> 		if kind!="racecar":
> 			for x in [-shape.size.x*.5,shape.size.x*.5]:
> 				var side := CollisionShape3D.new()
> 				var side_shape := BoxShape3D.new()
> 				side_shape.size=Vector3(.12,.7,shape.size.z)
> 				side.shape=side_shape
> 				side.position=Vector3(x,.5,0)
> 				body.add_child(side)
> 				var rail := MeshInstance3D.new()
> 				var rail_mesh := BoxMesh.new()
> 				rail_mesh.size=side_shape.size
> 				rail.mesh=rail_mesh
> 				rail.position=side.position
> 				rail.material_override=material
> 				body.add_child(rail)
> 		vehicles[kind]={"node":body,"home":body.position,"rider":0,"speed":[6.0,12.0,20.0][i]}
> 		body.hide()
> 		body.freeze=true
>
> @rpc("any_peer","call_local","unreliable_ordered")
> func drive(movement: Vector2,direction: Vector3) -> void:
> 	if not multiplayer.is_server() or not movement.is_finite() or not direction.is_finite(): return
> 	var id := multiplayer.get_remote_sender_id()
> 	if id==0: id=1
> 	if not player_state.has(str(id)): return
> 	var kind: String=player_state[str(id)].vehicle
> 	if not vehicles.has(kind) or vehicles[kind].rider!=id: return
> 	vehicle_inputs[kind]={"movement":movement.limit_length(),"direction":direction.normalized(),"time":game_clock}
>
> func update_vehicles(delta: float) -> void:
> 	for kind in vehicles:
> 		var record: Dictionary=vehicles[kind]
> 		var body: RigidBody3D=record.node
> 		var enabled: bool=kind in campaign.gear
> 		body.visible=enabled
> 		body.freeze=not enabled
> 		if not enabled: continue
> 		var input: Dictionary=vehicle_inputs.get(kind,{})
> 		var movement := Vector2.ZERO
> 		var forward := Vector3.FORWARD
> 		if record.rider>0 and game_clock-float(input.get("time",-10))<.5:
> 			movement=input.get("movement",Vector2.ZERO)
> 			forward=input.get("direction",Vector3.FORWARD)
> 		forward.y=0
> 		forward=forward.normalized()
> 		var direction := forward*-movement.y+forward.cross(Vector3.UP)*movement.x
> 		var wanted: Vector3=direction*float(record.speed)
> 		body.linear_velocity.x=move_toward(body.linear_velocity.x,wanted.x,delta*15)
> 		body.linear_velocity.z=move_toward(body.linear_velocity.z,wanted.z,delta*15)
> 		if direction.length()>.1:
> 			body.rotation.y=lerp_angle(body.rotation.y,atan2(-direction.x,-direction.z),delta*4)
> 		if body.position.y < -5:
> 			body.position=record.home
> 			body.linear_velocity=Vector3.ZERO
> 		if record.rider>0 and Vector2(body.linear_velocity.x,body.linear_velocity.z).length()>7:
> 			for enemy in enemies:
> 				if enemy.hp>0 and enemy.global_position.distance_to(body.global_position)<3:
> 					enemy.take_damage(delta*40)
> 					enemy.state="STUNNED"
> 					enemy.timer=1
>
> func shop_action(player: CharacterBody3D,action: String) -> void:
> 	if player.global_position.distance_to(Vector3(-10,-11,32))>7:
> 		return
> 	if action.begins_with("buy:"):
> 		var kind := action.trim_prefix("buy:")
> 		if not PRICES.has(kind): return
> 		if kind in campaign.gear and kind!="crystal": return
> 		if int(campaign.cash)<int(PRICES[kind]):
> 			notice.rpc("Not enough crew cash. Deliver loot or collect machine income.")
> 			return
> 		campaign.cash-=int(PRICES[kind])
> 		if kind not in campaign.gear: campaign.gear.append(kind)
> 		if kind=="crystal": campaign.crystals+=1
> 		for key in player_state:
> 			player_state[key].tool=kind
> 		play_sound.rpc("cash")
> 	elif action=="machine":
> 		var price: int=150*campaign.machines.size()
> 		if campaign.machines.size()<4 and int(campaign.cash)>=price:
> 			campaign.cash-=price
> 			campaign.machines.append(-1)
> 	elif action.begins_with("install:"):
> 		var parts := action.split(":")
> 		if parts.size()!=3: return
> 		var slot := parts[1].to_int()
> 		var recipe := parts[2].to_int()
> 		if slot>=0 and slot<campaign.machines.size() and recipe>=0 and recipe<4 and int(campaign.recipes[recipe])>0:
> 			campaign.machines[slot]=recipe
> 	elif action.begins_with("upgrade:"):
> 		var form := action.trim_prefix("upgrade:")
> 		if form not in campaign.forms: return
> 		var current := int(campaign.upgrades.get(form,0))
> 		var price := (current+1)*120
> 		if current<3 and int(campaign.cash)>=price:
> 			campaign.cash-=price
> 			campaign.upgrades[form]=current+1
> 	save_campaign()
> 	broadcast_state()
>
> func build_ui() -> void:
> 	var canvas := CanvasLayer.new()
> 	canvas.layer=4
> 	add_child(canvas)
> 	hud=Label.new()
> 	hud.position=Vector2(24,18)
> 	hud.add_theme_font_size_override("font_size",18)
> 	hud.add_theme_color_override("font_color",Color("e3eac7"))
> 	hud.add_theme_color_override("font_shadow_color",Color("152728"))
> 	hud.add_theme_constant_override("shadow_offset_x",2)
> 	hud.add_theme_constant_override("shadow_offset_y",2)
> 	canvas.add_child(hud)
> 	prompt=Label.new()
> 	prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
> 	prompt.offset_left=-600
> 	prompt.offset_right=600
> 	prompt.offset_top=-64
> 	prompt.offset_bottom=-18
> 	prompt.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
> 	prompt.add_theme_font_size_override("font_size",18)
> 	canvas.add_child(prompt)
> 	toast=Label.new()
> 	toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
> 	toast.offset_left=-550
> 	toast.offset_right=550
> 	toast.offset_top=150
> 	toast.offset_bottom=220
> 	toast.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
> 	toast.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
> 	toast.add_theme_font_size_override("font_size",23)
> 	toast.add_theme_color_override("font_color",Color("e4c285"))
> 	canvas.add_child(toast)
> 	shop=PanelContainer.new()
> 	shop.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
> 	shop.offset_left=-420
> 	shop.offset_right=420
> 	shop.offset_top=-290
> 	shop.offset_bottom=290
> 	var panel := StyleBoxFlat.new()
> 	panel.bg_color=Color("182d30")
> 	panel.border_color=Color("9fac7b")
> 	panel.set_border_width_all(2)
> 	panel.content_margin_left=22
> 	panel.content_margin_right=22
> 	panel.content_margin_top=18
> 	panel.content_margin_bottom=18
> 	shop.add_theme_stylebox_override("panel",panel)
> 	canvas.add_child(shop)
> 	var scroll := ScrollContainer.new()
> 	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
> 	shop.add_child(scroll)
> 	shop_rows=VBoxContainer.new()
> 	shop_rows.size_flags_horizontal=Control.SIZE_EXPAND_FILL
> 	shop_rows.add_theme_constant_override("separation",10)
> 	scroll.add_child(shop_rows)
> 	shop.hide()
>
> func open_shop() -> void:
> 	shop_open=true
> 	shop.show()
> 	for child in shop_rows.get_children():
> 		child.queue_free()
> 	var heading := Label.new()
> 	heading.name="Balance"
> 	heading.text="THE PARTNER  /  Crew outfitter"
> 	heading.add_theme_font_size_override("font_size",25)
> 	shop_rows.add_child(heading)
> 	for kind in PRICES:
> 		var button := Button.new()
> 		button.text="%s  /  $%d%s"%[TOOL_NAMES[kind],PRICES[kind],"  [OWNED]" if kind in campaign.gear and kind!="crystal" else ""]
> 		button.disabled=kind in campaign.gear and kind!="crystal"
> 		button.pressed.connect(func(): submit("shop","buy:"+kind); close_shop())
> 		shop_rows.add_child(button)
> 	var expansion := Button.new()
> 	expansion.text="Buy production slot  /  $%d  (%d/4)"%[150*campaign.machines.size(),campaign.machines.size()]
> 	expansion.disabled=campaign.machines.size()>=4
> 	expansion.pressed.connect(func(): submit("shop","machine"); close_shop())
> 	shop_rows.add_child(expansion)
> 	for slot in campaign.machines.size():
> 		for tier in range(4):
> 			if int(campaign.recipes[tier])<=0: continue
> 			var button := Button.new()
> 			button.text="Slot %d: install %s recipe Lv.%d%s"%[slot+1,SPECIES[tier],campaign.recipes[tier]," [INSTALLED]" if int(campaign.machines[slot])==tier else ""]
> 			button.pressed.connect(func(): submit("shop","install:%d:%d"%[slot,tier]); close_shop())
> 			shop_rows.add_child(button)
> 	for form in campaign.forms:
> 		var button := Button.new()
> 		var upgrade := int(campaign.upgrades.get(form,0))
> 		button.text="Upgrade %s form  /  Lv.%d  /  $%d"%[form,upgrade,(upgrade+1)*120]
> 		button.disabled=upgrade>=3
> 		button.pressed.connect(func(): submit("shop","upgrade:"+form); close_shop())
> 		shop_rows.add_child(button)
> 	var close := Button.new()
> 	close.text="BACK TO THE CREW"
> 	close.pressed.connect(close_shop)
> 	shop_rows.add_child(close)
> 	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
>
> func update_shop_header() -> void:
> 	var heading := shop_rows.get_node_or_null("Balance") as Label
> 	if heading:
> 		heading.text="THE PARTNER  /  $%d crew funds\nCrystals: %d  |  Ready to collect: $%d"%[campaign.cash,campaign.crystals,int(campaign.bank)]
>
> func close_shop() -> void:
> 	shop_open=false
> 	if shop: shop.hide()
> 	var level := get_tree().current_scene
> 	if level and level.has_method("_update_mouse_mode"):
> 		level._update_mouse_mode()
>
> @rpc("any_peer","reliable")
> func request_progress() -> void:
> 	if multiplayer.is_server():
> 		sync_full_state.rpc_id(multiplayer.get_remote_sender_id(),snapshot())
>
> func snapshot() -> Dictionary:
> 	var guards: Array=[]
> 	for enemy in enemies:
> 		guards.append([enemy.position,enemy.hp,enemy.state,enemy.model.rotation.y])
> 	var cars: Dictionary={}
> 	for kind in vehicles:
> 		cars[kind]=[vehicles[kind].node.position,vehicles[kind].node.rotation.y,vehicles[kind].rider]
> 	return {"campaign":campaign,"players":player_state,"alarm":alarm,"guards":guards,"cars":cars,"sabotage":sabotage,"defeated":defeated}
>
> func broadcast_state() -> void:
> 	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
> 		sync_state.rpc(snapshot())
>
> @rpc("authority","unreliable_ordered")
> func sync_state(data: Dictionary) -> void:
> 	apply_snapshot(data)
>
> @rpc("authority","reliable")
> func sync_full_state(data: Dictionary) -> void:
> 	apply_snapshot(data)
>
> func apply_snapshot(data: Dictionary) -> void:
> 	campaign=data.campaign
> 	player_state=data.players
> 	alarm=data.alarm
> 	sabotage=data.sabotage
> 	defeated=data.defeated
> 	for i in mini(enemies.size(),data.guards.size()):
> 		enemies[i].target_position=data.guards[i][0]
> 		enemies[i].hp=data.guards[i][1]
> 		enemies[i].state=data.guards[i][2]
> 		enemies[i].model.rotation.y=data.guards[i][3]
> 	for kind in data.cars:
> 		var body: RigidBody3D=vehicles[kind].node
> 		body.freeze=true
> 		body.visible=kind in campaign.gear
> 		body.position=data.cars[kind][0]
> 		body.rotation.y=data.cars[kind][1]
> 		vehicles[kind].rider=data.cars[kind][2]
> 	apply_progress(int(campaign.recipes[0])>0)
> 	update_machines()
>
> func update_machines() -> void:
> 	for i in range(3):
> 		var label := get_node_or_null("Hideout/MachineLabel%d"%i) as Label3D
> 		if label:
> 			if i<campaign.machines.size():
> 				var tier := int(campaign.machines[i])
> 				label.text="SLOT %d / %s"%[i+1,("%s Lv.%d"%[SPECIES[tier].to_upper(),campaign.recipes[tier]]) if tier>=0 else "EMPTY"]
> 			else:
> 				label.text="SLOT %d / BUY FROM TRADER"%(i+1)
> 	var machine := get_node_or_null("Hideout/StarterMachine") as Node3D
> 	if machine:
> 		machine.scale=Vector3.ONE*(1.0+minf(1.0,int(campaign.recipes[0])*.12))
>
> @rpc("authority","call_local","reliable")
> func notice(message: String) -> void:
> 	toast.text=message
> 	toast_clock=5.0
>
> @rpc("authority","call_local","unreliable")
> func fx(point: Vector3,color: Color,size: float) -> void:
> 	if DisplayServer.get_name()=="headless": return
> 	var sphere := preload("res://scripts/heist/slime_visual.gd").sphere(self,point,Vector3.ONE*size,color)
> 	var material: StandardMaterial3D=sphere.material_override
> 	material.emission_enabled=true
> 	material.emission=color
> 	material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
> 	var tween := create_tween()
> 	tween.set_parallel(true)
> 	tween.tween_property(sphere,"scale",Vector3.ONE*size*2,.4)
> 	tween.tween_property(material,"albedo_color:a",0.0,.4)
> 	tween.chain().tween_callback(sphere.queue_free)
>
> @rpc("authority","call_local","unreliable")
> func beam(from: Vector3,to: Vector3,color: Color) -> void:
> 	if DisplayServer.get_name()=="headless": return
> 	var mesh := ImmediateMesh.new()
> 	var material := StandardMaterial3D.new()
> 	material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
> 	material.albedo_color=color
> 	mesh.surface_begin(Mesh.PRIMITIVE_LINES,material)
> 	mesh.surface_add_vertex(from)
> 	mesh.surface_add_vertex(to)
> 	mesh.surface_end()
> 	var line := MeshInstance3D.new()
> 	line.mesh=mesh
> 	add_child(line)
> 	get_tree().create_timer(.18).timeout.connect(line.queue_free)
>
> @rpc("authority","call_local","unreliable")
> func play_sound(kind: String) -> void:
> 	if DisplayServer.get_name()=="headless": return
> 	if not sound_cache.has(kind):
> 		var bytes := PackedByteArray()
> 		var count := 6000
> 		bytes.resize(count*2)
> 		var frequency: float={"slap":95.0,"cash":660.0,"win":440.0,"heal":520.0,"tool":180.0}.get(kind,220.0)
> 		for i in count:
> 			var sample := sin(float(i)/22050.0*TAU*(frequency+float(i)*.025))*pow(1.0-float(i)/count,2)*.25
> 			bytes.encode_s16(i*2,int(sample*32767))
> 		var wav := AudioStreamWAV.new()
> 		wav.format=AudioStreamWAV.FORMAT_16_BITS
> 		wav.mix_rate=22050
> 		wav.data=bytes
> 		sound_cache[kind]=wav
> 	var sound := AudioStreamPlayer.new()
> 	sound.stream=sound_cache[kind]
> 	sound.volume_db=-10
> 	add_child(sound)
> 	sound.finished.connect(sound.queue_free)
> 	sound.play()
> '@ | Add-Content scripts/level/heist_world.gd
> @'
> from pathlib import Path
> p=Path('scripts/player/player.gd');t=p.read_text();t=t.replace('func _ready():\n','func _ready():\n\tvar slime := preload("res://scripts/heist/slime_visual.gd").new()\n\tslime.name = "SlimeVisual"\n\tadd_child(slime)\n\tcollision_mask = 31\n',1)
> t=t.replace('\tvar current_scene = get_tree().get_current_scene()\n\tvar should_freeze = false','''\tvar world := get_node_or_null("/root/Level/Environment/HeistWorld")
> 	if world:
> 		var state: Dictionary = world.player_state.get(str(name), {})
> 		if float(state.get("hp", 100)) <= 0 or state.get("vehicle", "") != "":
> 			velocity = Vector3.ZERO
> 			return
> 	var current_scene = get_tree().get_current_scene()
> 	var should_freeze = false''',1)
> t=t.replace('\t_is_running()\n\tdirection', '''\t_is_running()
> 	var world := get_node_or_null("/root/Level/Environment/HeistWorld")
> 	if world:
> 		var state: Dictionary = world.player_state.get(str(name), {})
> 		if float(state.get("speed_buff", 0)) > 0:
> 			_current_speed *= 1.45
> 		if state.get("form", "") == "rat":
> 			_current_speed *= 1.15
> 		if state.get("form", "") == "bird" and not is_on_floor() and Input.is_action_pressed("jump"):
> 			velocity.y = maxf(velocity.y, -1.5)
> 	direction''')
> # Retain a small loadout; loot should be earned in shops.
> a=t.index('\tvar starting_item_ids: Array[String] = [');b=t.index('\n\tfor item_id in starting_item_ids:',a)
> t=t[:a]+'\tvar starting_item_ids: Array[String] = ["rotten_cheese", "canned_food"]\n'+t[b:]
> p.write_text(t)
> p=Path('scripts/level/level.gd');t=p.read_text().replace('return pause_menu.is_menu_visible()','var world := get_node_or_null("Environment/HeistWorld")\n\treturn pause_menu.is_menu_visible() or (world != null and world.shop_open)',1)
> t=t.replace('func _handle_pause_action() -> void:\n','func _handle_pause_action() -> void:\n\tvar world := get_node_or_null("Environment/HeistWorld")\n\tif world and world.shop_open:\n\t\tworld.close_shop()\n\t\treturn\n',1)
> t=t.replace('\t\tor inventory_visible','\t\tor (get_node_or_null("Environment/HeistWorld") != null and $Environment/HeistWorld.shop_open)\n\t\tor inventory_visible')
> t=t.replace('\tNetwork.leave_game()','\t$Environment/HeistWorld.save_campaign()\n\tNetwork.leave_game()')
> p.write_text(t)
> '@ | python -`
>
> </details>
>
> The gameplay code now covers loot sales, machine income, equipment purchases, food effects, revives, and the seven trader tools. I’m turning the later storefronts into playable interiors too, with tougher animal guards and a final mecha-dragon encounter. After that I’ll test the full loop and fix what breaks.
>
> <details><summary>Ran 3 commands</summary>
>
> - Ran `@'
> from pathlib import Path
> p=Path('scripts/level/build_heist_world.py');t=p.read_text()
> t=t.replace("        key = (color, glow)\n",'''        key = (color, glow)
>         kinds = {
>             '66735f':0,'738264':0,'56634f':0,'4c5e53':0,'334c4d':0,'4f5b4d':0,'465659':0,'344548':0,'737b66':0,
>             '74755e':1,'636a56':1,'5d6555':1,'3d5352':1,'514d40':1,
>             '785540':2,'69523e':2,'75634b':2,'876445':2,'857354':2,'867350':2,'8a785a':2,
>             '445954':3,'243b40':3,'42564b':3,'a0aaa0':3,'a49c76':3,'3e6154':3,'657673':3,'273c41':3,
>             '263036':4
>         }
>         if not glow and color in kinds:
>             if key not in self.materials:
>                 self.materials[key] = self.resource('ShaderMaterial', 'shader = ExtResource("surface")\\nshader_parameter/atlas = ExtResource("atlas")\\nshader_parameter/surface_kind = %d\\nshader_parameter/tile_size = 4.0' % kinds[color])
>             return self.materials[key]
> ''')
> # Each generated scene declares the same reusable material resources.
> t=t.replace("        (ROOT/path).write_text('[gd_scene format=3]\\n\\n' + ext",'''        ext += '[ext_resource type="Shader" path="res://assets/environment/heist/surfaces.gdshader" id="surface"]\\n[ext_resource type="Texture2D" path="res://assets/environment/heist/surface_atlas.png" id="atlas"]\\n'
>         (ROOT/path).write_text('[gd_scene format=3]\\n\\n' + ext''')
> # Frontage boundary walls would obstruct the new shop entrances.
> t=t.replace("for z in (-19,19):", "for z in ():")
> t=t.replace("    face=s.node('Storefront'+str(i)", "    if i in (1,2,5):\n        continue\n    face=s.node('Storefront'+str(i)")
> t=t.replace("rat(store,'ChefRat',(0,0,-73),2.0,True)","# Live chef rat is created by the host-authoritative encounter system.")
> t=t.replace('BOSS ENCOUNTER STAGING AREA','RECIPE VAULT / DEFEAT THE CHEF').replace('[F] Recover / open east road','DEFEAT THE CHEF TO CLAIM').replace("'Recover recipe (prototype progression)'","'Inspect the chef recipe vault'")
> t=t.replace('Trading system coming later','Tools for the whole crew').replace('STARTER MACHINE / DISPLAY','PASSIVE INCOME / COLLECT AT TERMINAL').replace('Production system coming later','Install recipes at the trader').replace('DISTILLERY SABOTAGE / FUTURE ENCOUNTER HOOK','TURN THE THREE VALVES TO WEAKEN THE CHEF').replace('Requires rat form (future)','Requires rat form')
> t=t.replace('FOX TERRITORY / COMING LATER','CLOSED / UNDER INVESTIGATION').replace('BLACK MARKET / COMING LATER','CLOSED / POLICE SEIZURE')
> extra='''# Interactive stations and shortcut markers.
> interact('Trader',(-10,-11,32),'Trade equipment, install recipes and upgrade forms')
> interact('Extract',(9,1,-12),'Sell bagged loot and nearby cargo')
> interact('CollectIncome',(5,-11,25),'Collect production income')
> interact('Replay',(-4,-11,38),'Restock all stores for another heist')
> interact('RatTunnelIn',(-15.5,1,-39),'Slip through the rat tunnel',(-12,1,-63))
> interact('RatTunnelOut',(-12,1,-63),'Return through the rat tunnel',(-14.5,1,-39))
> for i,x in enumerate((-9,-2,5)):
>     interact('Valve'+str(i),(x,-11,-51.7),'Sabotage distillery valve %d'%(i+1))
> s.text(base,'IncomeLabel',(5,-9,25),'[F] COLLECT INCOME',23,'c7df8e')
> s.text(base,'ReplayLabel',(-4,-9.8,39.7),'[F] RESTOCK STORES',20,'c7df8e')
> # Three additional stores use the same physical loot and combat systems.
> expansion=s.node('Expansion','Node3D','.')
> for tier,x,z,orientation,title,color in [
>     (1,45,-18,0,'BOAR HARDWARE','e7bb79'),
>     (2,61,18,180,'BIRD SEED & CO.','bed3ab'),
>     (3,74,-18,0,'COLD BLOOD ELECTRONICS','a1cfe2')]:
>     room=s.node('Store%d'%tier,'Node3D',expansion,'position = %s\\nrotation_degrees = Vector3(0,%s,0)'%(vec((x,0,z)),orientation))
>     s.box(room,'Floor',(0,-.3,-21),(24,.6,42),'74755e')
>     s.box(room,'Roof',(0,7,-21),(24,.4,42),'42564b')
>     s.box(room,'BackWall',(0,3.5,-42),(24,7,.5),'66735f')
>     for side in (-12,12):
>         s.box(room,'SideWall'+str(side),(side,3.5,-21),(.5,7,42),'66735f')
>     for side in (-7.5,7.5):
>         s.box(room,'FrontWall'+str(side),(side,3.5,0),(9,7,.5),'738264')
>         s.box(room,'FrontWindow'+str(side),(side,2.8,.27),(6,2.7,.1),'637b70',False)
>     s.box(room,'DoorHeader',(0,5.8,0),(6,2.4,.5),'738264')
>     lock=s.node('Lock','Node3D',room)
>     s.box(lock,'SecurityDoor',(0,2.5,0),(6,5,.6),'243b40')
>     s.text(lock,'LockedText',(0,2.5,.4),'DEFEAT THE PREVIOUS BOSS\\nTO UNLOCK THIS STORE',24,color)
>     sign(room,'ShopSign',(0,7.8,.2),24,title,color,48)
>     s.text(room,'BossBanner',(0,5,-41.6),['','FOREMAN TUSK','MADAM MAGPIE','MECHA DRAGON'][tier],45,color)
>     for aisle,ax in enumerate((-7,0,7)):
>         s.box(room,'Shelf'+str(aisle),(ax,.8,-12),(2,1.6,9),'857354')
>         for j in range(4):
>             local=(ax,1.75,-15+j*2)
>             actual=(x+local[0],local[1],z+local[2]) if orientation==0 else (x-local[0],local[1],z-local[2])
>             stock(actual, 'canned_food' if tier==2 else 'stolen_goods')
>             s.box(room,'Display%s%s'%(aisle,j),(ax,2,-15+j*2),(.9,.5,.7),['','a0aaa0','a49c76','243b40'][tier],False)
>     for dz in (-7,-24,-35):
>         for ax in (-7,7):
>             s.box(room,'Tube%s%s'%(ax,dz),(ax,6.65,dz),(3,.12,.35),color,False,True)
>             s.light(room,'Light%s%s'%(ax,dz),(ax,6.1,dz),color,2.5,16)
>     for side in (-9,9):
>         barrel(room,'BossCover'+str(side),(side,.8,-34))
>     s.box(room,'ArenaStripe',(0,.025,-25),(22,.025,.2),color,False)
> # Skyline and broad yard give the road a grounded silhouette.
> for i in range(12):
>     sx=-65+i*15
>     s.box(road,'Skyline'+str(i),(sx,8+(i%3)*3,-96),(11,16+(i%3)*6,12),'344548')
> s.box(road,'OuterGround',(20,-1.3,-4),(185,1,180),'293a39')
>
> '''
> t=t.replace('# Preview camera is replaced automatically when a local player spawns.',extra+'# Preview camera is replaced automatically when a local player spawns.')
> p.write_text(t)
> '@ | python -
> python scripts/level/build_heist_world.py
> & 'D:\Downloads\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe' --headless --path . --editor --import --quit *> validation-expansion-import.log
> rg -n -C 2 'ERROR|Error' validation-expansion-import.log`
> - Ran `@'
> from pathlib import Path
> p=Path('scripts/level/level.gd');t=p.read_text().replace('var ui_requires_cursor := (','var ui_requires_cursor: bool = (');p.write_text(t)
> p=Path('scripts/level/build_heist_world.py');t=p.read_text();t='\n'.join(line for line in t.splitlines() if "s.box(room,'Display%s%s'" not in line)+'\n';p.write_text(t)
> '@ | python -
> python scripts/level/build_heist_world.py
> & 'D:\Downloads\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe' --headless --path . --quit-after 90 *> validation-expansion-run.log
> Get-Content validation-expansion-run.log -TotalCount 100`
> - Ran `@'
> from pathlib import Path
> p=Path('scripts/level/heist_world.gd');t=p.read_text().replace('@export var persistence_enabled := true','@export var persistence_enabled := true\n@export var campaign_path := SAVE_FILE').replace('FileAccess.file_exists(SAVE_FILE)','FileAccess.file_exists(campaign_path)').replace('FileAccess.open(SAVE_FILE,','FileAccess.open(campaign_path,')
> t=t.replace('player.velocity+=impulse','player.external_velocity+=Vector3(impulse.x,0,impulse.z)\n\t\tplayer.velocity.y+=impulse.y')
> t=t.replace('\tupdate_vehicles(delta)','\tupdate_vehicles(delta)\n\tupdate_machines()')
> p.write_text(t)
> p=Path('scripts/player/player.gd');t=p.read_text().replace('var is_collecting := false','var is_collecting := false\nvar external_velocity := Vector3.ZERO')
> t=t.replace('\t_move()\n\tvar collided', '\t_move()\n\tvelocity.x += external_velocity.x\n\tvelocity.z += external_velocity.z\n\texternal_velocity = external_velocity.move_toward(Vector3.ZERO, delta * 14.0)\n\tvar collided')
> t=t.replace('func apply_force_to_server_object(object_name: String, normal: Vector3) -> void:\n', 'func apply_force_to_server_object(object_name: String, normal: Vector3) -> void:\n\tif not multiplayer.is_server() or not _is_owner_request() or not normal.is_finite() or normal.length() > 1.1:\n\t\treturn\n')
> t=t.replace('if n.name == object_name and n is RigidBody3D:', 'if n.name == object_name and n is RigidBody3D and n.global_position.distance_to(global_position) < 4.0:')
> p.write_text(t)
> p=Path('scripts/items/item_rigid_body_3d.gd');t=p.read_text();t+='\n\nfunc _ready() -> void:\n\t# The host simulates merchandise; clients render replicated transforms.\n\tif multiplayer.has_multiplayer_peer() and not multiplayer.is_server():\n\t\tfreeze = true\n';p.write_text(t)
> p=Path('scripts/level/build_heist_world.py');t=p.read_text().replace('collision_mask = 7\\nlinear_damp', 'collision_mask = 31\\nlinear_damp');p.write_text(t)
> '@ | python -
> python scripts/level/build_heist_world.py
> @'
> extends SceneTree
> var level: Node3D
> var world: Node3D
> var failed := false
> func _initialize() -> void:
> 	call_deferred("run")
> func check(ok: bool,message: String) -> void:
> 	print(("PASS: " if ok else "FAIL: ")+message)
> 	failed=failed or not ok
> func run() -> void:
> 	var args := OS.get_cmdline_user_args()
> 	level=load("res://scenes/level/level.tscn").instantiate()
> 	world=level.get_node("Environment/HeistWorld")
> 	world.persistence_enabled=false
> 	if "--client" in args: level.auto_start_headless_server=false
> 	root.add_child(level)
> 	current_scene=level
> 	await process_frame
> 	var network := root.get_node("Network")
> 	if "--client" in args:
> 		network.join_game("Validation client","green","127.0.0.1")
> 		await create_timer(3).timeout
> 		check(network.players.size()>0,"client connects")
> 		check(level.get_node("Environment/ItemContainer").get_child_count()==62,"late client receives all 62 physics merchandise objects")
> 		check(world.recipe_recovered,"late client receives boss-earned progression")
> 		check(world.campaign.gear.has("water"),"late client receives purchased equipment")
> 		check(world.enemies[4].hp<=0,"late client receives defeated boss state")
> 		var player: Node3D=level.get_node("PlayersContainer/"+str(root.get_multiplayer().get_unique_id()))
> 		player.global_position=Vector3(0,1,3)
> 		await create_timer(.6).timeout
> 		world.request_action.rpc_id(1,"interact","Manhole",Vector3.FORWARD)
> 		await create_timer(.6).timeout
> 		check(player.global_position.y < -10,"server validates client manhole travel")
> 		var cash: int=world.campaign.cash
> 		world.request_action.rpc_id(1,"shop","buy:jetpack",Vector3.FORWARD)
> 		await create_timer(.4).timeout
> 		check(int(world.campaign.cash)==cash,"server rejects purchases away from trader")
> 		network.leave_game()
> 		quit(1 if failed else 0)
> 		return
> 	if "--capture" in args:
> 		network.start_host("Scout","blue")
> 		level.main_menu.hide_menu()
> 		world.set_process(false)
> 		world.hud.hide()
> 		world.prompt.hide()
> 		var camera: Camera3D=world.get_node("LobbyPreview")
> 		camera.current=true
> 		var views := [["road",Vector3(25,15,21),Vector3(0,2,-23)],["store",Vector3(0,3,-24),Vector3(0,1.5,-47)],["hideout",Vector3(12,-7.5,43),Vector3(-4,-10,28)],["distillery",Vector3(12,-7.5,-41),Vector3(-3,-10,-55)],["boss",Vector3(7,3,-62),Vector3(0,2,-71)],["dragon",Vector3(80,3,-42),Vector3(74,2,-51)],["slime",Vector3(1,2,2),Vector3(0,1,6)]]
> 		for view in views:
> 			camera.global_position=view[1]
> 			camera.look_at(view[2])
> 			await create_timer(.6).timeout
> 			await RenderingServer.frame_post_draw
> 			root.get_texture().get_image().save_png("res://screenshots/heist_"+view[0]+".png")
> 		quit()
> 		return
> 	world.session_active=true
> 	var player: CharacterBody3D=load("res://scenes/level/player.tscn").instantiate()
> 	player.name="1"
> 	player.position=Vector3(0,1,6)
> 	level.get_node("PlayersContainer").add_child(player)
> 	world.ensure_player(1)
> 	world._stock_store()
> 	for enemy in world.enemies: enemy.set_physics_process(false)
> 	await create_timer(.3).timeout
> 	check(level.get_node("Environment/ItemContainer").get_child_count()==62,"four stores have 62 physics merchandise objects")
> 	world._stock_store()
> 	check(level.get_node("Environment/ItemContainer").get_child_count()==62,"restocking is idempotent")
> 	world.request_interaction("Recipe")
> 	check(not world.recipe_recovered,"recipe cannot be stolen remotely or before boss defeat")
> 	await create_timer(.5).timeout
> 	player.global_position=Vector3(0,1,3)
> 	world.request_interaction("Manhole")
> 	check(player.global_position.y < -10,"manhole reaches hideout")
> 	await create_timer(.5).timeout
> 	player.global_position=Vector3(0,-11,23)
> 	world.request_interaction("BaseExit")
> 	check(player.global_position.y>0,"ladder returns to street")
> 	var old_cash: int=world.campaign.cash
> 	world.shop_action(player,"buy:water")
> 	check(int(world.campaign.cash)==old_cash,"distant shopping rejected")
> 	player.global_position=Vector3(-10,-11,32)
> 	world.shop_action(player,"buy:water")
> 	check(world.campaign.gear.has("water") and int(world.campaign.cash)==old_cash-90,"trader charges once and unlocks shared water gun")
> 	world.shop_action(player,"buy:water")
> 	check(int(world.campaign.cash)==old_cash-90,"duplicate nonconsumable purchase rejected")
> 	player.global_position=Vector3(7,1,-72.5)
> 	world.interact(player,"Recipe")
> 	check(not world.recipe_recovered,"boss guards the blueprint")
> 	world.enemies[4].take_damage(1000)
> 	check(world.recipe_recovered and int(world.campaign.recipes[0])==1,"boss awards guaranteed recipe and opens road")
> 	world.enemies[4].take_damage(1000)
> 	check(int(world.campaign.recipes[0])==1,"dead boss cannot award duplicate rewards")
> 	var before_bank: float=world.campaign.bank
> 	world._physics_process(1.0)
> 	check(world.campaign.bank>before_bank,"installed machine generates active-session income")
> 	player.global_position=Vector3(5,-11,25)
> 	world.interact(player,"CollectIncome")
> 	check(world.campaign.bank<1,"income terminal transfers whole dollars to crew funds")
> 	player.global_position=Vector3(9,1,-12)
> 	var cash_before_sale: int=world.campaign.cash
> 	player.player_inventory.add_item(root.get_node("ItemDatabase").get_item("stolen_goods"),2)
> 	world.sell_loot(player)
> 	check(int(world.campaign.cash)>=cash_before_sale+90,"extraction sells physical inventory merchandise")
> 	world.hurt_player(1,200,Vector3.ZERO)
> 	check(world.player_state["1"].hp==0,"damage downs a player")
> 	world.revive(1,45)
> 	check(world.player_state["1"].hp==45,"revive restores health")
> 	world.campaign.forms=["rat","boar"]
> 	world.request_action("transform","",Vector3.FORWARD)
> 	check(world.player_state["1"].form=="rat","unlocked animal transformation activates")
> 	await create_timer(.3).timeout
> 	world.request_action("slime","",Vector3.FORWARD)
> 	check(world.player_state["1"].form=="slime","returning to slime during cooldown is allowed")
> 	world.request_action("transform","",Vector3.FORWARD)
> 	check(world.player_state["1"].form=="slime","120-second species-change cooldown is enforced")
> 	world.campaign.cash=999
> 	player.global_position=Vector3(-10,-11,32)
> 	world.shop_action(player,"buy:cart")
> 	check(world.campaign.gear.has("cart"),"shopping cart can be purchased")
> 	player.global_position=world.vehicles.cart.node.global_position
> 	world.interact(player,"")
> 	check(world.vehicles.cart.rider==1,"player can board purchased cart")
> 	world.drive(Vector2(0,-1),Vector3.FORWARD)
> 	world.update_vehicles(.1)
> 	check(world.vehicles.cart.node.linear_velocity.z<0,"server drives the vehicle")
> 	world.interact(player,"")
> 	check(world.vehicles.cart.rider==0,"player can dismount")
> 	world.campaign_path="user://crooked_mile_validation.json"
> 	world.persistence_enabled=true
> 	world.save_campaign()
> 	world.campaign.cash=0
> 	world.load_campaign()
> 	check(int(world.campaign.cash)==899,"campaign survives save and reload")
> 	DirAccess.remove_absolute(world.campaign_path)
> 	world.persistence_enabled=false
> 	for point in [Vector3(0,2,-20.5),Vector3(0,2,-24),Vector3(11,2,-50),Vector3(0,-10,25),Vector3(10,-10,-42),Vector3(45,2,-23),Vector3(61,2,23),Vector3(74,2,-25)]:
> 		var query := PhysicsRayQueryParameters3D.create(point,point+Vector3.DOWN*3,2)
> 		check(not world.get_world_3d().direct_space_state.intersect_ray(query).is_empty(),"walkable floor "+str(point))
> 	if "--server" in args:
> 		player.queue_free()
> 		world.player_state.erase("1")
> 		await process_frame
> 		print("SERVER_READY")
> 		await create_timer(16).timeout
> 	network.leave_game()
> 	quit(1 if failed else 0)
> '@ | Set-Content scripts/tests/verify_heist.gd
> & 'D:\Downloads\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe' --headless --path . --script res://scripts/tests/verify_heist.gd *> validation-full-loop.log
> Get-Content validation-full-loop.log -TotalCount 120`
>
> </details>
>
> The first full-loop tests passed: boss rewards, loot sales, production income, purchases, downs and revives, transformation cooldowns, vehicle driving, and save/load. There are now four store interiors with 62 physical merchandise objects. I’m checking multiplayer synchronization and rendered views next.
>
> <details><summary>Ran 4 commands</summary>
>
> - Ran `$enginePath = 'D:\Downloads\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe'
> $serverProcess = Start-Process -FilePath $enginePath -ArgumentList '--headless --path . --script res://scripts/tests/verify_heist.gd -- --server' -WindowStyle Hidden -PassThru -RedirectStandardOutput validation-full-server.log -RedirectStandardError validation-full-server-errors.log
> Start-Sleep -Seconds 5
> & $enginePath --headless --path . --script res://scripts/tests/verify_heist.gd -- --client *> validation-full-client.log
> $serverProcess.WaitForExit()
> $renderProcess = Start-Process -FilePath $enginePath -ArgumentList '--path . --script res://scripts/tests/verify_heist.gd -- --capture' -WindowStyle Hidden -PassThru -RedirectStandardOutput validation-full-render.log -RedirectStandardError validation-full-render-errors.log
> $renderProcess.WaitForExit(40000)
> Get-Content validation-full-client.log,validation-full-server-errors.log,validation-full-render-errors.log -TotalCount 100`
> - Ran `[Convert]::ToBase64String([IO.File]::ReadAllBytes((Join-Path (Get-Location) 'screenshots/heist_slime.png')))`
> - Ran `[Convert]::ToBase64String([IO.File]::ReadAllBytes((Join-Path (Get-Location) 'screenshots/heist_dragon.png')))`
> - Ran `[Convert]::ToBase64String([IO.File]::ReadAllBytes((Join-Path (Get-Location) 'screenshots/heist_store.png')))`
>
> </details>
>
> The multiplayer checks passed. The server did flag an oversized state packet, so I’m compressing those updates. I’m also adding direct physical carrying and throwing so players can haul merchandise by hand or load it into a cart.
>
> <details><summary>Ran 5 commands</summary>
>
> - Ran `@'
> from pathlib import Path
> p=Path('scripts/level/heist_world.gd');t=p.read_text()
> t=t.replace('var sound_cache: Dictionary = {}','var sound_cache: Dictionary = {}\nvar carry_clock := 0.0\nvar hazard_visuals: Array[Node3D] = []\nvar bait_visuals: Array[Node3D] = []')
> t=t.replace('"grapple_cd":0.0}', '"grapple_cd":0.0,"held":"","carry_direction":Vector3.FORWARD,"last_form":""}')
> t=t.replace('\t\tvar active_form: String=data.form', '''\t\tif data.get("held", "") != "":
> 			var held := get_node("../ItemContainer").get_node_or_null(NodePath(str(data.held))) as RigidBody3D
> 			if held:
> 				held.global_position=player.global_position+Vector3.UP*1.3+data.get("carry_direction",Vector3.FORWARD)*1.6
> 				held.linear_velocity=Vector3.ZERO
> 			else:
> 				data.held=""
> 		var active_form: String=data.form''')
> t=t.replace('func _peer_left(id: int) -> void:\n', 'func _peer_left(id: int) -> void:\n\trelease_cargo(id,Vector3.ZERO)\n')
> t=t.replace('\tif data.hp<=0:\n\t\tdata.vehicle', '\tif data.hp<=0:\n\t\trelease_cargo(id,Vector3.ZERO)\n\t\tdata.vehicle')
> t=t.replace('func melee(player: CharacterBody3D,direction: Vector3) -> void:\n', '''func melee(player: CharacterBody3D,direction: Vector3) -> void:
> 	if player_state[str(player.name)].get("held", "")!="":
> 		release_cargo(int(str(player.name)),direction*15+Vector3.UP*2)
> 		return
> ''')
> t=t.replace('\t\t"attack": melee(player,direction)','\t\t"attack": melee(player,direction)\n\t\t"carry": toggle_cargo(player,direction)')
> t=t.replace('KEY_Q: submit("cycle")','KEY_Q: submit("cycle")\n\t\t\tKEY_G: submit("carry")')
> t=t.replace('"LMB Slap  |  RMB Tool  |  Q Switch tool  |  B Cheese bait  |  H Eat  |  R Transform  |  X Slime"','"G Grab/drop  |  LMB Slap/throw  |  RMB Tool  |  Q Tools  |  B Bait  |  H Eat  |  R Form  |  X Slime"')
> t=t.replace('\tvar riding: String=data.get("vehicle","")','''\tif data.get("held", "")!="":
> 		prompt.text="CARRYING MERCHANDISE  |  G Drop  |  LMB Throw  |  F Sell at the loading bay"
> 		carry_clock+=delta
> 		if carry_clock>.1:
> 			carry_clock=0
> 			if multiplayer.is_server(): carry_aim(aim_direction())
> 			else: carry_aim.rpc_id(1,aim_direction())
> 	render_hazards()
> 	var riding: String=data.get("vehicle","")''')
> t=t.replace('campaign.forms.find(data.form)','campaign.forms.find(data.get("last_form", ""))')
> t=t.replace('\t\t\t\tdata.form_cooldown=120.0','\t\t\t\tdata.last_form=data.form\n\t\t\t\tdata.form_cooldown=120.0')
> t=t.replace('\tvar earned := 0\n\tfor item_id', '\trelease_cargo(int(str(player.name)),Vector3.ZERO)\n\tvar earned := 0\n\tfor item_id')
> t=t.replace('"defeated":defeated}', '"defeated":defeated,"fires":fires,"bait":bait}')
> t=t.replace('\t\tsync_state.rpc(snapshot())','\t\tsync_state.rpc(var_to_bytes(snapshot()).compress(FileAccess.COMPRESSION_ZSTD))')
> t=t.replace('func sync_state(data: Dictionary) -> void:\n\tapply_snapshot(data)', 'func sync_state(data: PackedByteArray) -> void:\n\tvar decoded = bytes_to_var(data.decompress_dynamic(1048576,FileAccess.COMPRESSION_ZSTD))\n\tif decoded is Dictionary:\n\t\tapply_snapshot(decoded)')
> t=t.replace('\tdefeated=data.defeated','\tdefeated=data.defeated\n\tfires=data.get("fires",[])\n\tbait=data.get("bait",[])')
> p.write_text(t)
> p=Path('scripts/items/item_rigid_body_3d.gd');t=p.read_text().replace('@export var item_id: String = ""','@export var item_id: String = ""\n@export var carried_by := 0')
> t=t.replace('func _ready() -> void:\n','func _ready() -> void:\n\tcontact_monitor = true\n\tmax_contacts_reported = 6\n\tbody_entered.connect(_on_impact)\n',1)
> t+='''
>
> func _physics_process(_delta: float) -> void:
> 	collision_layer = 0 if carried_by > 0 else 4
> 	if multiplayer.is_server():
> 		freeze = carried_by > 0
>
> func _on_impact(body: Node) -> void:
> 	if multiplayer.is_server() and body.has_method("take_damage") and linear_velocity.length() > 4:
> 		body.take_damage(clampf(linear_velocity.length() * 5, 15, 65))
> ''';p.write_text(t)
> p=Path('scripts/player/player.gd');t=p.read_text().replace('if item and not item.item_id.is_empty() and ItemDatabase.get_item(item.item_id):','if item and item.carried_by == 0 and not item.item_id.is_empty() and ItemDatabase.get_item(item.item_id):');p.write_text(t)
> p=Path('scripts/level/build_heist_world.py');t=p.read_text().replace('properties/1/replication_mode = 2\'','properties/1/replication_mode = 2\\nproperties/2/path = NodePath(".:carried_by")\\nproperties/2/spawn = true\\nproperties/2/replication_mode = 2\'');p.write_text(t)
> '@ | python -
> @'
>
> @rpc("any_peer","call_local","unreliable_ordered")
> func carry_aim(direction: Vector3) -> void:
> 	if not multiplayer.is_server() or not direction.is_finite() or direction.length_squared()<.5 or direction.length_squared()>1.5: return
> 	var id := multiplayer.get_remote_sender_id()
> 	if id==0: id=1
> 	if player_state.has(str(id)):
> 		player_state[str(id)].carry_direction=direction.normalized()
>
> func toggle_cargo(player: CharacterBody3D,direction: Vector3) -> void:
> 	var id := int(str(player.name))
> 	var data: Dictionary=player_state[str(id)]
> 	if data.get("held", "")!="":
> 		release_cargo(id,Vector3.ZERO)
> 		return
> 	var nearest_item: RigidBody3D=null
> 	var best := 4.0
> 	for item in get_node("../ItemContainer").get_children():
> 		var offset: Vector3=item.global_position-player.global_position
> 		if item.carried_by==0 and offset.length()<best and offset.normalized().dot(direction)>0 and clear_line(player.global_position+Vector3.UP,item.global_position+Vector3.UP*.2):
> 			nearest_item=item
> 			best=offset.length()
> 	if nearest_item:
> 		nearest_item.carried_by=id
> 		nearest_item.freeze=true
> 		data.held=str(nearest_item.name)
> 		data.carry_direction=direction
>
> func release_cargo(id: int,velocity: Vector3) -> void:
> 	if not player_state.has(str(id)): return
> 	var data: Dictionary=player_state[str(id)]
> 	var held_name: String=data.get("held", "")
> 	if held_name.is_empty(): return
> 	var held := get_node("../ItemContainer").get_node_or_null(NodePath(held_name)) as RigidBody3D
> 	if held:
> 		held.carried_by=0
> 		held.freeze=false
> 		held.collision_layer=4
> 		held.linear_velocity=velocity
> 	data.held=""
>
> func render_hazards() -> void:
> 	for collection in [fires,bait]:
> 		var visuals: Array[Node3D]=hazard_visuals if collection==fires else bait_visuals
> 		while visuals.size()>collection.size():
> 			visuals.pop_back().queue_free()
> 		while visuals.size()<collection.size():
> 			var visual := Node3D.new()
> 			add_child(visual)
> 			var color := Color("ed8439") if collection==fires else Color("c9df7c")
> 			var blob := preload("res://scripts/heist/slime_visual.gd").sphere(visual,Vector3(0,.25,0),Vector3(3,.25,3) if collection==fires else Vector3(.6,.4,.5),color)
> 			blob.material_override.emission_enabled=true
> 			blob.material_override.emission=color*.5
> 			if collection==fires:
> 				for i in range(3):
> 					preload("res://scripts/heist/slime_visual.gd").sphere(visual,Vector3(sin(i*2.1),.5,cos(i*2.1)),Vector3(.5,1,.5),Color("efc15d"))
> 			visuals.append(visual)
> 		for i in collection.size():
> 			visuals[i].position=collection[i].position
> 			visuals[i].scale.y=1+sin(Time.get_ticks_msec()*.008+i)*.25
> '@ | Add-Content scripts/level/heist_world.gd
> python scripts/level/build_heist_world.py
> & 'D:\Downloads\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe' --headless --path . --script res://scripts/tests/verify_heist.gd *> validation-full-loop.log
> Get-Content validation-full-loop.log -Tail 40`
> - Ran `Get-Item screenshots/heist_store.png | Select-Object Length; Get-Content validation-full-render-errors.log -TotalCount 30`
> - Ran `@'
> from pathlib import Path
> p=Path('scripts/level/heist_world.gd');t=p.read_text().replace('var bait_visuals: Array[Node3D] = []','var bait_visuals: Array[Node3D] = []\nvar cameras: Array = []\nvar machine_visuals: Array[Node3D] = []')
> t=t.replace('\tbuild_vehicles()','\tbuild_vehicles()\n\tbuild_security_cameras()\n\tbuild_machine_visuals()',1)
> t=t.replace('"gear":["grapple"]','"gear":["grapple","crystal"]')
> t=t.replace('\tfor machine in campaign.machines:\n','\tfor machine in campaign.machines if not player_state.is_empty() else []:\n',1)
> t=t.replace('\tupdate_vehicles(delta)\n','\tupdate_vehicles(delta)\n\tsecurity_scan(delta)\n',1)
> t=t.replace('\tvar damage := 25.0', '''\tfor camera in cameras:
> 		if not camera.disabled and player.global_position.distance_to(camera.position)<5 and (camera.position-player.global_position).normalized().dot(direction)>.1:
> 			camera.disabled=true
> 			fx.rpc(camera.position,Color("b7dfed"),.7)
> 			notice.rpc("Security camera disabled.")
> 	var damage := 25.0''')
> t=t.replace('"bait":bait}', '"bait":bait,"cameras":cameras.map(func(c): return c.disabled)}')
> t=t.replace('\tbait=data.get("bait",[])','\tbait=data.get("bait",[])\n\tfor i in mini(cameras.size(),data.get("cameras",[]).size()):\n\t\tcameras[i].disabled=data.cameras[i]')
> t=t.replace('\trender_hazards()','\trender_hazards()\n\trender_cameras()',1)
> t=t.replace('\t\t"water":\n', '\t\t"water":\n\t\t\tfor camera in cameras:\n\t\t\t\tif camera.position.distance_to(player.global_position+direction*8)<5:\n\t\t\t\t\tcamera.disabled=true\n',1)
> t=t.replace('\tfor enemy in enemies:\n\t\tenemy.hp=enemy.max_hp','\tfor camera in cameras: camera.disabled=false\n\tfor enemy in enemies:\n\t\tenemy.hp=enemy.max_hp',1)
> t=t.replace('\tvar machine := get_node_or_null("Hideout/StarterMachine") as Node3D','''\tfor i in machine_visuals.size():
> 		var installed: bool=i<campaign.machines.size() and int(campaign.machines[i])>=0
> 		machine_visuals[i].visible=installed
> 		if installed:
> 			var recipe := int(campaign.machines[i])
> 			var level := int(campaign.recipes[recipe])
> 			machine_visuals[i].scale=Vector3.ONE*(1.0+minf(.8,level*.12))
> 			machine_visuals[i].get_node("Output").rotation.y=Time.get_ticks_msec()*.001*(1+level)
> 	var machine := get_node_or_null("Hideout/StarterMachine") as Node3D''')
> p.write_text(t)
> p=Path('scripts/tests/verify_heist.gd');t=p.read_text().replace('root.get_texture().get_image().save_png("res://screenshots/heist_"+view[0]+".png")','root.get_texture().get_image().save_png("res://screenshots/heist_"+view[0]+".png")\n\t\t\troot.get_texture().get_image().save_jpg("res://screenshots/heist_"+view[0]+"-review.jpg",.8)');p.write_text(t)
> '@ | python -
> @'
>
> func build_security_cameras() -> void:
> 	for spec in [[Vector3(15,4.3,-29),Vector3(-1,-.2,0)],[Vector3(-15,4.3,-44),Vector3(1,-.2,0)],[Vector3(55,4.3,-29),Vector3(-1,-.2,0)],[Vector3(51,4.3,35),Vector3(1,-.2,0)],[Vector3(84,4.3,-32),Vector3(-1,-.2,0)]]:
> 		var holder := Node3D.new()
> 		holder.position=spec[0]
> 		add_child(holder)
> 		holder.look_at(spec[0]+spec[1])
> 		var camera := MeshInstance3D.new()
> 		var box := BoxMesh.new()
> 		box.size=Vector3(.55,.35,.85)
> 		camera.mesh=box
> 		var mat := StandardMaterial3D.new()
> 		mat.albedo_color=Color("ddd3ae")
> 		camera.material_override=mat
> 		holder.add_child(camera)
> 		var cone := MeshInstance3D.new()
> 		var mesh := CylinderMesh.new()
> 		mesh.top_radius=0
> 		mesh.bottom_radius=4
> 		mesh.height=11
> 		cone.mesh=mesh
> 		cone.rotation.x=PI*.5
> 		cone.position.z=-5.5
> 		var glass := StandardMaterial3D.new()
> 		glass.albedo_color=Color(.9,.65,.25,.055)
> 		glass.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
> 		glass.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
> 		glass.cull_mode=BaseMaterial3D.CULL_DISABLED
> 		cone.material_override=glass
> 		holder.add_child(cone)
> 		cameras.append({"position":spec[0],"direction":spec[1].normalized(),"disabled":false,"holder":holder,"cone":cone})
>
> func security_scan(delta: float) -> void:
> 	for camera in cameras:
> 		if camera.disabled: continue
> 		for player in live_players():
> 			var offset: Vector3=player.global_position+Vector3.UP-camera.position
> 			if offset.length()<12 and offset.normalized().dot(camera.direction)>.92 and clear_line(camera.position,player.global_position+Vector3.UP):
> 				alarm=minf(100,alarm+delta*18)
>
> func render_cameras() -> void:
> 	for camera in cameras:
> 		camera.cone.visible=not camera.disabled
>
> func build_machine_visuals() -> void:
> 	var visual_script := preload("res://scripts/heist/slime_visual.gd")
> 	for i in range(4):
> 		var machine := Node3D.new()
> 		machine.name="ProductionMachine%d"%i
> 		machine.position=Vector3(8,-12,26+i*7) if i<3 else Vector3(-10,-12,40)
> 		add_child(machine)
> 		var shell := MeshInstance3D.new()
> 		var cylinder := CylinderMesh.new()
> 		cylinder.top_radius=.9
> 		cylinder.bottom_radius=.9
> 		cylinder.height=2.2
> 		shell.mesh=cylinder
> 		shell.position.y=1.1
> 		shell.material_override=get_node("Hideout/StarterMachine").material_override
> 		machine.add_child(shell)
> 		visual_script.sphere(machine,Vector3(0,2.3,0),Vector3(1.7,.4,1.7),Color("abb879"))
> 		visual_script.sphere(machine,Vector3(.85,2.5,.3),Vector3(.3,1.5,.3),Color("b68e5d"))
> 		var output := visual_script.sphere(machine,Vector3(-1,1,0),Vector3(.6,.6,.6),Color("c5d875"))
> 		output.name="Output"
> 		machine_visuals.append(machine)
> 	for child in $Hideout.get_children():
> 		if str(child.name).begins_with("StarterMachine") or str(child.name) in ["MachinePipe","ControlBox"]:
> 			child.hide()
> '@ | Add-Content scripts/level/heist_world.gd
> & 'D:\Downloads\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe' --headless --path . --script res://scripts/tests/verify_heist.gd *> validation-full-loop.log
> Get-Content validation-full-loop.log -Tail 45`
> - Ran `@'
> from pathlib import Path
> p=Path('scripts/tests/verify_heist.gd');t=p.read_text().replace('\t\tlevel.main_menu.hide_menu()','\t\tlevel.main_menu.hide_menu()\n\t\tlevel._get_local_player().position=Vector3(0,1,6)',1).replace('["slime",Vector3(1,2,2),Vector3(0,1,6)]','["slime",Vector3(1,1.8,9),Vector3(0,.8,6)]')
> t=t.replace('\tworld.request_interaction("Recipe")\n', '''\tvar cargo: RigidBody3D=level.get_node("Environment/ItemContainer").get_child(0)
> 	cargo.global_position=Vector3(0,1,-8)
> 	player.global_position=Vector3(0,.1,-5)
> 	world.toggle_cargo(player,Vector3.FORWARD)
> 	check(cargo.carried_by==1 and world.player_state["1"].held!="","physical merchandise can be carried")
> 	world.release_cargo(1,Vector3(0,1,-5))
> 	check(cargo.carried_by==0 and cargo.linear_velocity.z<0,"carried merchandise can be thrown")
> 	player.global_position=Vector3(-6.5,.2,-31)
> 	world.enemies[0]._physics_process(.1)
> 	check(world.enemies[0].state=="HUNT","guard detects and pursues a visible player")
> 	var before_guard: float=world.enemies[0].hp
> 	player.global_position=world.enemies[0].global_position+Vector3(0,0,2.7)
> 	world.melee(player,Vector3.FORWARD)
> 	check(world.enemies[0].hp<before_guard,"melee damages a nearby guard")
> 	player.global_position=Vector3(0,1,6)
> 	world.request_interaction("Recipe")
> ''',1)
> t=t.replace('\tworld.enemies[4].take_damage(1000)\n', '''\tworld.enemies[4]._physics_process(.1)
> 	check(world.enemies[4].state=="WIND UP","boss telegraphs its charge")
> 	var before_sabotage: float=world.enemies[4].hp
> 	player.global_position=Vector3(-9,-11,-51.7)
> 	world.interact(player,"Valve0")
> 	check(world.enemies[4].hp==before_sabotage-65,"distillery sabotage weakens the boss")
> 	world.interact(player,"Valve0")
> 	check(world.enemies[4].hp==before_sabotage-65,"each valve can be sabotaged only once per heist")
> 	world.enemies[4].take_damage(1000)
> ''',1)
> t=t.replace('\tworld.campaign_path="user://crooked_mile_validation.json"','''\tvar packet := var_to_bytes(world.snapshot()).compress(FileAccess.COMPRESSION_ZSTD)
> 	check(packet.size()<1300,"compressed state stays within one network packet")
> 	world.campaign_path="user://crooked_mile_validation.json"''')
> p.write_text(t)
> '@ | python -
> & 'D:\Downloads\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe' --headless --path . --script res://scripts/tests/verify_heist.gd *> validation-full-loop.log
> Get-Content validation-full-loop.log -Tail 55`
> - Ran `@'
> from pathlib import Path
> p=Path('scripts/tests/verify_heist.gd');t=p.read_text().replace('\tworld.hurt_player(1,200,Vector3.ZERO)','\tworld.player_state["1"].hurt_cooldown=0\n\tworld.hurt_player(1,200,Vector3.ZERO)')
> t=t.replace('\t\tnetwork.join_game("Validation client","green","127.0.0.1")','\t\tnetwork.join_game("Validation client","green","127.0.0.1")\n\t\tlevel.main_menu.hide_menu()')
> t=t.replace('\t\tworld.set_process(false)','\t\tworld.open_shop()\n\t\tawait process_frame\n\t\tworld.close_shop()\n\t\tworld.play_sound("slap")\n\t\tworld.fx(Vector3(0,2,0),Color.WHITE,.5)\n\t\tworld.beam(Vector3.ZERO,Vector3.UP,Color.WHITE)\n\t\tworld.set_process(false)')
> p.write_text(t)
> for p in Path('scenes/items').rglob('*.tscn'):
>  t=p.read_text()
>  if 'SceneReplicationConfig' in t and 'properties/2/path' not in t:
>   t=t.replace('properties/1/replication_mode = 2','properties/1/replication_mode = 2\nproperties/2/path = NodePath(".:carried_by")\nproperties/2/spawn = true\nproperties/2/replication_mode = 2')
>   p.write_text(t)
> '@ | python -
> $enginePath = 'D:\Downloads\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64_console.exe'
> $serverProcess = Start-Process -FilePath $enginePath -ArgumentList '--headless --path . --script res://scripts/tests/verify_heist.gd -- --server' -WindowStyle Hidden -PassThru -RedirectStandardOutput validation-full-server.log -RedirectStandardError validation-full-server-errors.log
> Start-Sleep -Seconds 5
> $clientProcesses = @()
> foreach ($clientIndex in 1..4) {
>  $clientProcesses += Start-Process -FilePath $enginePath -ArgumentList '--headless --path . --script res://scripts/tests/verify_heist.gd -- --client' -WindowStyle Hidden -PassThru -RedirectStandardOutput ('validation-client-' + $clientIndex + '.log') -RedirectStandardError ('validation-client-' + $clientIndex + '-errors.log')
> }
> foreach ($clientProcess in $clientProcesses) { $clientProcess.WaitForExit() }
> $serverProcess.WaitForExit()
> $renderProcess = Start-Process -FilePath $enginePath -ArgumentList '--path . --script res://scripts/tests/verify_heist.gd -- --capture' -WindowStyle Hidden -PassThru -RedirectStandardOutput validation-full-render.log -RedirectStandardError validation-full-render-errors.log
> $renderProcess.WaitForExit(40000)
> Get-Content validation-full-server-errors.log,validation-full-render-errors.log
> foreach ($clientIndex in 1..4) { Get-Content ('validation-client-' + $clientIndex + '.log'),('validation-client-' + $clientIndex + '-errors.log') }
> Select-String -Path validation-full-server.log -Pattern 'FAIL|ERROR'`
>
> </details>
>
> Physical carrying and throwing are implemented, along with visible fire hazards and security cameras that can be disabled. Production machines now change size as their recipes improve. The four-client test is running, and I’m updating the controls and gameplay notes to match the expanded game.
>
> <details><summary>Ran 5 commands</summary>
>
> - Ran `@'
> from pathlib import Path
> p=Path('scripts/level/heist_world.gd');t=p.read_text().replace('func find_target(origin: Vector3,radius: float,species: int) -> Node3D:', 'func find_target(origin: Vector3,radius: float,species: int,ignore_disguise: bool=false) -> Node3D:').replace('if player_state.get(str(player.name),{}).get("form", "slime")==SPECIES[species] and alarm<50:', 'if not ignore_disguise and player_state.get(str(player.name),{}).get("form", "slime")==SPECIES[species] and alarm<50:')
> t=t.replace('func fire_breath(origin: Vector3,direction: Vector3) -> void:', 'func fire_breath(origin: Vector3,direction: Vector3,source: String="") -> void:').replace('fires.append({"position":pos,"time":4.0})','fires.append({"position":pos,"time":4.0,"source":source})')
> t=t.replace('if player.global_position.distance_to(fires[i].position)<2.6:', 'if player.global_position.distance_to(fires[i].position)<2.6 and fires[i].get("source","")!=str(player.name):')
> t=t.replace('if enemy.hp>0 and enemy.global_position.distance_to(fires[i].position)<3:', 'if enemy.hp>0 and enemy.global_position.distance_to(fires[i].position)<3 and fires[i].get("source","")!=str(enemy.name):')
> t=t.replace('fire_breath(player.global_position,Vector3(direction.x,0,direction.z).normalized())','fire_breath(player.global_position,Vector3(direction.x,0,direction.z).normalized(),str(player.name))')
> p.write_text(t)
> p=Path('scripts/heist/security_guard.gd');t=p.read_text().replace('world.find_target(global_position, 24 if boss else 13,tier)','world.find_target(global_position, 24 if boss else 13,tier,boss)').replace('world.fire_breath(global_position,charge_dir)','world.fire_breath(global_position,charge_dir,str(name))').replace('\t\t\tcharge_dir=offset.normalized()','\t\t\tcharge_dir=offset.normalized()\n\t\t\tmodel.rotation.y=atan2(-charge_dir.x,-charge_dir.z)');p.write_text(t)
> '@ | python -
> @'
> # The Crooked Mile
>
> A playable 1-4 player co-op heist game built on the project's existing Godot multiplayer template.
>
> ## Start playing
>
> Open project.godot and press F5. Choose HOST HEIST to play solo or host up to three friends. Friends select JOIN CREW with the host's address. The template uses UDP 8080. A dedicated headless server supports four connected clients.
>
> You spawn on the road by Rat Mart and the central manhole. Rob stores, deliver loot to the loading bay beside the van, defeat their bosses, and invest in the underground hideout.
>
> ## Controls
>
> | Input | Action |
> | --- | --- |
> | WASD / Shift / Space | Move / sprint / jump; jump again in the air |
> | Mouse / V | Look / switch first and third person |
> | G | Grab nearby physical merchandise, or drop held cargo |
> | Left mouse | Slap enemies; throw cargo if holding something |
> | Right mouse / Q | Use the selected tool / cycle owned tools |
> | E / I | Pick merchandise into your bag / inventory and item dropping |
> | F | Interact, travel, sell loot, collect income, revive, board or exit vehicles |
> | B | Spend rotten cheese to distract and bribe nearby rats |
> | H | Eat: cheese for speed, otherwise moonshine for strength and fuel, otherwise canned food for health |
> | R / X | Cycle unlocked animal forms / return to slime |
> | T / Tab / Esc | Chat / crew list / pause or close the trader |
>
> ## The campaign
>
> The road connects Rat Mart, Boar Hardware, Bird Seed & Co., and Cold Blood Electronics. Bosses are the chef rat, Foreman Tusk, Madam Magpie, and the mecha dragon with its lizard pilot. Each victory upgrades that store's guaranteed recipe, pays the crew, and opens the next store. There is a 40% chance to unlock the boss species for the crew if it has not already dropped.
>
> Guards patrol, detect visible players, pursue, and attack. Bosses telegraph charges, can crash into walls and become stunned, and attack faster at low health. Security cameras raise the alarm; high alarm makes guards faster. Slap cameras at close range or use the water gun to disable them. Matching animal disguises fool ordinary guards while alarm is below 50%; bosses see through disguises.
>
> Rat Mart has three stocked aisles, checkout valuables, a stockroom, a rat-form shortcut, a basement distillery and a chef arena. Sabotage each of the three distillery valves once per heist to damage and stun the chef. Burning spills are visible hazards and can be extinguished with the water gun. Cheese bait temporarily bribes nearby rats, including the chef.
>
> The four stores contain 62 synchronized physical merchandise objects. Carry and throw them, use your bag, or load them into a cart or truck. Press F at the loading bay to sell bagged merchandise and loose cargo within the bay.
>
> ## The hideout
>
> F at the manhole descends into the hideout. The trader sells shared equipment, additional production slots, and animal-form upgrades. The planning table restocks stores and respawns bosses when the crew has left all stores, allowing recipe upgrades and more chances at transformation drops.
>
> You start with one machine slot. Your first boss recipe installs automatically; use the trader to replace installed recipes or add slots, up to four. Machines earn money while players are connected, including during missions. The income terminal transfers those earnings to shared funds. Higher recipe levels increase income and machine size.
>
> Campaign funds, income, recipe levels, installed machines, purchased equipment, transformations and upgrades save on the host at user://crooked_mile_campaign_v2.json. Bags, guard state, alarm and carried objects are session state. There are no offline earnings.
>
> ## Equipment and forms
>
> - Grappling hook: pull yourself to surfaces, pull rigid merchandise, or tug teammates. Aim and use the right mouse button.
> - Water gun: heal another living player, slow enemies, disable cameras, and extinguish nearby fires. It cannot heal its user.
> - Slime crystal: consume a crystal to revive a downed teammate within 12 meters. F revives a teammate at close range without a crystal.
> - Jetpack: right mouse applies thrust and spends fuel. Refuel in the hideout or by drinking moonshine.
> - Shopping cart, mini truck and racecar: purchase from the trader, then F beside the vehicle on the road to drive. WASD moves relative to your camera. Cart and truck sides hold physical cargo; fast vehicles damage guards on impact.
> - Rat form: smaller appearance, faster movement and access to the Rat Mart tunnel.
> - Boar form: stronger melee attacks.
> - Bird form: hold jump while airborne to glide.
> - Lizard form: melee also breathes fire. Your own breath does not hurt you, but it can hurt teammates.
>
> Animal changes have a 120-second cooldown. Returning to slime is always allowed and does not clear the cooldown. Form upgrades improve attack strength. The whole crew may use the same unlocked form.
>
> Players have 100 health. Downed players can be revived by teammates; a fully downed crew is rescued to the hideout after five seconds for $30. An isolated downed player is rescued after 30 seconds. The hideout gradually heals living players and refuels jetpacks.
>
> ## Project layout
>
> - scenes/level/level.tscn: main multiplayer scene.
> - scenes/level/heist_world.tscn: editable static road, stores, hideout and distillery.
> - scripts/level/heist_world.gd: authoritative game loop, shop, tools, vehicles, save data and synchronization.
> - scripts/heist/security_guard.gd: animal models and server-driven enemy behavior.
> - scripts/heist/slime_visual.gd: expressive slime and transformation visuals, keeping the template controller.
> - assets/environment/heist/: generated material atlas, world-space material shader and source notes.
> - scripts/level/build_heist_world.py: deterministic scene generator. Running it overwrites the generated world and four merchandise scenes; keep edits in the generator or edit scenes directly without regenerating.
>
> Characters, vehicles and encounters use original procedural models. This is a playable prototype: art, animation, vehicle handling and combat balance can be refined further. The original template arena remains in the project.
>
> ## Validation
>
> Godot 4.6.1 automated checks cover physical carry/throw, guard detection, melee, boss telegraphs, sabotage limits, loot spawning, travel, shop validation, guaranteed boss rewards, income, extraction, revives, species cooldowns, driving, persistence and walkable floors. Multiplayer validation uses a dedicated server and four concurrent clients to check late-join loot, equipment, defeated bosses, progression and client travel. Forward+ renders cover the road, store, hideout, distillery, slime and bosses.
>
> Run the checks with Godot --headless --path . --script res://scripts/tests/verify_heist.gd. For multiplayer, add -- --server; after SERVER_READY start up to four other processes with -- --client. For screenshots, run without --headless and add -- --capture. Tests use separate save data and do not change the real campaign.
> '@ | Set-Content HEIST_WORLD.md
> @'
> # Heist environment materials
>
> surface_atlas.png was generated for this project with the built-in image generation tool. It is an original 2x2 albedo atlas: aged mossy brick, damaged checkerboard ceramic tiles, weathered wood, and oxidized painted metal. The output was copied into this directory unchanged. No external texture pack is required.
>
> surfaces.gdshader projects each quadrant in world space so large walls and floors keep a consistent material scale. Asphalt uses shader grain. Roughness and metalness are shader parameters rather than separate photographed PBR maps.
>
> Generation prompt:
>
> Create a production-ready square 2048x2048 game material texture atlas for a grimy stylized co-op heist game, high quality hand-painted PBR-like albedo surface detail, not a screenshot. Exact layout four equally sized 1024x1024 square material panels in a tight 2x2 grid. TOP LEFT: aged mossy olive-green and warm gray brick masonry, small staggered bricks, cracked mortar, subtle grime. TOP RIGHT: dirty worn cream and desaturated sage checkerboard ceramic floor tiles, fine hairline cracks, chipped edges and thin dark grout, each check about one eighth panel width. BOTTOM LEFT: weathered brown wood planks with realistic grain, knots and scuffed varnish, parallel vertical boards, no nails sticking out. BOTTOM RIGHT: worn oxidized dark teal painted steel, broad metal sheet with subtle scratches and scattered orange-brown rust, no objects. Each individual quadrant is a seamless repeating tile, flat orthographic face-on, uniform neutral diffuse lighting, no cast shadows, no perspective, no bevel framing, no gaps or borders between quadrants, no words, labels, watermarks or graphic icons. Detailed but readable slightly painterly surfaces in the same cohesive art style, moderate contrast so gameplay objects stand out.
>
> The delivered image is 1254 x 1254 pixels. The requested resolution above is retained as part of the exact prompt, not a claim about the output resolution. The atlas remains editable as a project asset.
> '@ | Set-Content assets/environment/heist/ASSET_NOTES.md`
> - Ran `@'
> from pathlib import Path
> for name in ['scripts/level/heist_world.gd','scripts/tests/verify_heist.gd']:
>  p=Path(name);t=p.read_text().replace('FileAccess.COMPRESSION_ZSTD','FileAccess.COMPRESSION_DEFLATE');p.write_text(t)
> p=Path('scripts/tests/verify_heist.gd');t=p.read_text().replace('player.global_position=Vector3(0,1,3)\n\t\tawait', 'var slot := 0\n\t\tfor argument in args:\n\t\t\tif argument.begins_with("--slot="): slot=argument.trim_prefix("--slot=").to_int()\n\t\tplayer.global_position=Vector3((slot-1.5)*1.2,1,3)\n\t\tawait',1)
> t=t.replace('\tcheck(packet.size()<1300,"compressed state stays within one network packet")','\tcheck(packet.size()<1300,"compressed state stays within one network packet")\n\tvar restored = bytes_to_var(packet.decompress_dynamic(1048576,FileAccess.COMPRESSION_DEFLATE))\n\tcheck(restored is Dictionary and restored.players.has("1"),"network snapshot compression round-trips")')
> p.write_text(t)
> '@ | python -
> Get-Item screenshots/heist_store-review.jpg,screenshots/heist_slime-review.jpg,screenshots/heist_dragon-review.jpg | Select-Object Name,Length
> Get-Content validation-full-render-errors.log -TotalCount 30`
> - Ran `[Convert]::ToBase64String([IO.File]::ReadAllBytes((Join-Path (Get-Location) 'screenshots/heist_store-review.jpg')))`
> - Ran `[Convert]::ToBase64String([IO.File]::ReadAllBytes((Join-Path (Get-Location) 'screenshots/heist_slime-review.jpg')))`
> - Ran `[Convert]::ToBase64String([IO.File]::ReadAllBytes((Join-Path (Get-Location) 'screenshots/heist_dragon-review.jpg')))`
>
> </details>
</details>
