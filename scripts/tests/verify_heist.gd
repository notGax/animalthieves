extends SceneTree
var level: Node3D
var world: Node3D
var failed := false
const GameAudio = preload("res://scripts/audio/game_audio.gd")
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool,message: String) -> void:
	print(("PASS: " if ok else "FAIL: ")+message)
	failed=failed or not ok
func wait_until(predicate: Callable,timeout: float) -> bool:
	var clock := 0.0
	while clock < timeout:
		if predicate.call():
			return true
		await create_timer(.1).timeout
		clock+=.1
	return predicate.call()
func run() -> void:
	var args := OS.get_cmdline_user_args()
	level=load("res://scenes/level/level.tscn").instantiate()
	world=level.get_node("Environment/HeistWorld")
	world.persistence_enabled=false
	if "--client" in args: level.auto_start_headless_server=false
	root.add_child(level)
	current_scene=level
	await process_frame
	var network := root.get_node("Network")
	if "--client" in args:
		network.join_game("Validation client","green","127.0.0.1")
		level.main_menu.hide_menu()
		check(await wait_until(func(): return network.players.size()>0,6.0),"client connects")
		check(await wait_until(func(): return level.get_node("Environment/ItemContainer").get_child_count()==62,8.0),"late client receives all 62 physics merchandise objects")
		check(await wait_until(func(): return world.recipe_recovered,4.0),"late client receives boss-earned progression")
		check(await wait_until(func(): return world.campaign.gear.has("water"),4.0),"late client receives purchased equipment")
		check(await wait_until(func(): return world.enemies[4].hp<=0,4.0),"late client receives defeated boss state")
		var player: Node3D=level.get_node("PlayersContainer/"+str(root.get_multiplayer().get_unique_id()))
		var slot := 0
		for argument in args:
			if argument.begins_with("--slot="): slot=argument.trim_prefix("--slot=").to_int()
		player.global_position=Vector3((slot-1.5)*1.2,1,3)
		await create_timer(.6).timeout
		world.request_action.rpc_id(1,"interact","Manhole",Vector3.FORWARD)
		check(await wait_until(func(): return player.global_position.y < -10,4.0),"server validates client manhole travel")
		var cash: int=world.campaign.cash
		world.request_action.rpc_id(1,"shop","buy:jetpack",Vector3.FORWARD)
		await create_timer(.4).timeout
		check(int(world.campaign.cash)==cash,"server rejects purchases away from trader")
		network.leave_game()
		quit(1 if failed else 0)
		return
	if "--capture" in args:
		network.start_host("Scout","blue")
		level.main_menu.hide_menu()
		level._get_local_player().position=Vector3(0,1,6)
		level._get_local_player()._spring_arm_offset.is_first_person=false
		world.open_shop()
		await process_frame
		world.close_shop()
		world.play_sound("slap")
		world.fx(Vector3(0,2,0),Color.WHITE,.5)
		world.beam(Vector3.ZERO,Vector3.UP,Color.WHITE)
		for enemy in world.enemies:
			enemy.set_physics_process(false)
			enemy.model.rotation.y=PI
		world.set_process(false)
		world.hud.hide()
		world.prompt.hide()
		var camera: Camera3D=world.get_node("LobbyPreview")
		camera.current=true
		var views := [["road",Vector3(25,15,21),Vector3(0,2,-23)],["store",Vector3(0,3,-24),Vector3(0,1.5,-47)],["hideout",Vector3(12,-7.5,43),Vector3(-4,-10,28)],["distillery",Vector3(12,-7.5,-41),Vector3(-3,-10,-55)],["boss",Vector3(7,3,-62),Vector3(0,2,-71)],["dragon",Vector3(80,3,-42),Vector3(74,2,-51)],["slime",Vector3(1.7,1.7,3.1),Vector3(0,.9,6)]]
		for view in views:
			camera.global_position=view[1]
			camera.look_at(view[2])
			await create_timer(.6).timeout
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://screenshots/heist_"+view[0]+".png")
			root.get_texture().get_image().save_jpg("res://screenshots/heist_"+view[0]+"-review.jpg",.8)
		quit()
		return
	world.session_active=true
	var player: CharacterBody3D=load("res://scenes/level/player.tscn").instantiate()
	player.name="1"
	player.position=Vector3(0,1,6)
	level.get_node("PlayersContainer").add_child(player)
	world.ensure_player(1)
	world._stock_store()
	check(load("res://assets/characters/character_part.gdshader") is Shader,"character part shader loads")
	var mats: RefCounted=load("res://scripts/visuals/character_materials.gd")
	var shared: ShaderMaterial=mats.toon_part(Color.RED)
	check(shared==mats.toon_part(Color.RED) and shared.shader.resource_path.ends_with("character_part.gdshader"),"toon parts cache one material per color on the part shader")
	check(mats.toon_face(Color.RED)!=shared,"face parts get their own raised-floor material")
	var tail_probe := Node3D.new()
	root.add_child(tail_probe)
	var form_bits: Dictionary=load("res://scripts/heist/form_visuals.gd").build(tail_probe,{})
	check(form_bits.boar_tail.size()==4 and form_bits.lizard_tail.size()==6 and not (form_bits.boar_tail[0] is MeshInstance3D),"boar and lizard tails build as pivot chains")
	tail_probe.queue_free()
	check(player._spring_arm_offset._noise != null,"camera boots with its cached shake noise")
	player._spring_arm_offset._trauma=1.0
	player._spring_arm_offset._apply_feedback(.016)
	check(player._spring_arm_offset._trauma<1.0,"camera trauma decays instead of latching")
	# Movement model: acceleration, one jump, coyote/buffer, bounded external
	# impulses. The step helper takes explicit inputs so no engine input
	# synthesis is needed; the road at (0,1,-8) is an open corridor.
	var step := func(dt: float, move: Vector2, buffered: bool, held: bool) -> void:
		player._movement_step(dt,move,buffered,held)
	# The open road corridor at (0,2,-12); strafe along +x so the run never
	# reaches a wall. Physics frames are flushed after teleports so the
	# server's broadphase matches the new transform.
	player.global_position=Vector3(0,2,-12)
	player.velocity=Vector3.ZERO
	await physics_frame
	await physics_frame
	for i in range(90):
		step.call(1.0/60,Vector2.ZERO,false,false)
	check(player.is_on_floor(),"movement tests settle onto the road floor")
	player._locomotion=Vector2.ZERO
	step.call(1.0/60,Vector2(1,0),false,false)
	var early_speed: float=Vector2(player.velocity.x,player.velocity.z).length()
	check(early_speed>0.1 and early_speed<4.0,"ground movement accelerates instead of snapping")
	for i in range(30):
		step.call(1.0/60,Vector2(1,0),false,false)
	var ramped_speed: float=Vector2(player.velocity.x,player.velocity.z).length()
	check(ramped_speed>=5.0,"walk speed is reached within half a second")
	# Reversal: sprint forward, then demand the opposite direction. Braking
	# passes through a momentum transition before accelerating backwards.
	Input.action_press("shift")
	for i in range(40):
		step.call(1.0/60,Vector2(1,0),false,false)
	var sprint_speed: float=Vector2(player.velocity.x,player.velocity.z).length()
	check(sprint_speed>8.5,"sprint ramps to the sprint target")
	Input.action_release("shift")
	for i in range(10):
		step.call(1.0/60,Vector2(-1,0),false,false)
	var braking_speed: float=Vector2(player.velocity.x,player.velocity.z).length()
	check(braking_speed<sprint_speed*.75,"sprint reversal brakes through momentum first")
	for i in range(50):
		step.call(1.0/60,Vector2(-1,0),false,false)
	var reversed_speed: float=Vector2(player.velocity.x,player.velocity.z).length()
	check(reversed_speed>3.0 and player.velocity.x<0.0,"reversal completes into the new direction")
	step.call(1.0/60,Vector2.ZERO,false,false)
	# Single jump: buffered jump leaves the ground once; mashing jump midair
	# can never produce a second upward impulse.
	player._jump_buffer_clock=0.0
	player._coyote_clock=0.0
	step.call(1.0/60,Vector2.ZERO,true,true)
	var jump_velocity: float=player.velocity.y
	check(absf(jump_velocity-player.JUMP_VELOCITY)<.01,"jump launches with the tuned impulse")
	var rising: bool=true
	for i in range(30):
		step.call(1.0/60,Vector2.ZERO,true,true)
		if i>2 and player.velocity.y>=jump_velocity:
			rising=false
	check(rising,"mashing jump in midair never yields a second jump")
	# Coyote time: a recent floor contact still allows the jump.
	player._coyote_clock=player.COYOTE_TIME*.5
	player._jump_buffer_clock=player.JUMP_BUFFER_TIME
	player.velocity.y=-2.0
	step.call(1.0/60,Vector2.ZERO,false,false)
	check(absf(player.velocity.y-player.JUMP_VELOCITY)<.01,"coyote time allows a late jump")
	player._coyote_clock=0.0
	player._jump_buffer_clock=player.JUMP_BUFFER_TIME
	player.velocity.y=-2.0
	step.call(1.0/60,Vector2.ZERO,false,false)
	check(player.velocity.y<0.0,"a stale coyote window does not jump")
	# Jump buffer: press early, land, the jump fires on touchdown.
	player._jump_buffer_clock=player.JUMP_BUFFER_TIME
	player.velocity.y=-6.0
	player.global_position.y=.4
	var buffered_peak := 0.0
	for i in range(6):
		step.call(1.0/60,Vector2.ZERO,false,false)
		buffered_peak=maxf(buffered_peak,player.velocity.y)
	check(buffered_peak>player.JUMP_VELOCITY*.9,"a buffered jump fires on landing")
	# Variable jump: releasing early shortens the arc via heavier ascent.
	player.velocity.y=5.0
	player._apply_gravity(1.0/60,true)
	var held_gravity_drop: float=5.0-player.velocity.y
	player.velocity.y=5.0
	player._apply_gravity(1.0/60,false)
	var released_gravity_drop: float=5.0-player.velocity.y
	check(released_gravity_drop>held_gravity_drop*1.5,"releasing jump early cuts the arc")
	# External impulses: capped, decaying, and never stored in locomotion.
	for i in range(10):
		player.apply_external_impulse(Vector3(1000,50,0))
	var capped: float=Vector2(player.external_velocity.x,player.external_velocity.z).length()
	check(capped<=player.MAX_EXTERNAL_PLANAR_SPEED+.01,"repeated impulses stay under the external cap")
	check(player.velocity.y<=player.MAX_IMPULSE_VERTICAL_SPEED+.01 and player.external_velocity.y<=player.MAX_IMPULSE_VERTICAL_SPEED+.01,"vertical impulses stay under the cap")
	player._decay_external(.5)
	var decayed: float=Vector2(player.external_velocity.x,player.external_velocity.z).length()
	check(decayed<capped-5.0,"external impulses decay toward zero")
	# THE runaway regression: a stationary player, grapple-strength impulse,
	# no input. Old code re-added external velocity every frame and reached
	# runaway speeds; the split channels must coast, decay, and stop.
	player.velocity.y=0.0
	player.apply_external_impulse(Vector3(13,0,0))
	var peak_planar: float=0.0
	for i in range(150):
		step.call(1.0/60,Vector2.ZERO,false,false)
		peak_planar=maxf(peak_planar,Vector2(player.velocity.x,player.velocity.z).length())
	check(peak_planar<=player.MAX_COMBINED_PLANAR_SPEED+.01,"stationary impulse never exceeds the combined cap")
	check(Vector2(player.velocity.x,player.velocity.z).length()<.5,"stationary player comes fully to rest after an impulse")
	# Sprinting into the same impulse: allowed, but the sum stays capped.
	player._locomotion=Vector2(0,-player.SPRINT_SPEED)
	player.apply_external_impulse(Vector3(13,0,0))
	step.call(1.0/60,Vector2(0,-1),false,false)
	var boosted: float=Vector2(player.velocity.x,player.velocity.z).length()
	check(boosted>player.SPRINT_SPEED and boosted<=player.MAX_COMBINED_PLANAR_SPEED+.01,"sprint plus impulse stacks but stays capped")
	player._locomotion=Vector2.ZERO
	player.external_velocity=Vector3.ZERO
	# Grapple tool: static pull bounded, and far weaker than the old 17+9.
	player.global_position=Vector3(0,1,-12)
	player.velocity=Vector3.ZERO
	await physics_frame
	await physics_frame
	for i in range(12):
		step.call(1.0/60,Vector2.ZERO,false,false)
	world.player_state["1"].grapple_cd=0.0
	world.use_tool(player,Vector3(0,-.9,-.44).normalized())
	var pull: float=Vector2(player.external_velocity.x,player.external_velocity.z).length()
	check(pull>3.0 and pull<=13.5,"static grapple pull is bounded and readable")
	check(player.velocity.y<=6.5+.01,"grapple vertical assist is bounded")
	for i in range(60):
		step.call(1.0/60,Vector2.ZERO,false,false)
	check(Vector2(player.velocity.x,player.velocity.z).length()<1.0,"stationary grapple glide settles quickly")
	world.player_state["1"].grapple_cd=0.0
	world.use_tool(player,Vector3(0,-.9,-.44).normalized())
	world.player_state["1"].grapple_cd=0.0
	world.use_tool(player,Vector3(0,-.9,-.44).normalized())
	var re_pull: float=Vector2(player.external_velocity.x,player.external_velocity.z).length()
	check(re_pull<=player.MAX_EXTERNAL_PLANAR_SPEED+.01,"repeated grapples stay under the cap")
	player.external_velocity=Vector3.ZERO
	player._locomotion=Vector2.ZERO
	# --- Vehicle overhaul: profiles, arcade drive, curb assist, ram events ---
	for enemy in world.enemies: enemy.set_physics_process(false)
	for kind in ["cart","truck","racecar"]:
		var vprofile: Dictionary=VehicleProfiles.profile(kind)
		check(vprofile.size()>=17,"vehicle profile '%s' carries the full tuning field set"%kind)
		check(vprofile.max_forward_speed>vprofile.max_reverse_speed,"vehicle profile '%s' reverses slower than it drives"%kind)
	check(VehicleProfiles.profile("cart").max_forward_speed<VehicleProfiles.profile("truck").max_forward_speed
		and VehicleProfiles.profile("truck").max_forward_speed<VehicleProfiles.profile("racecar").max_forward_speed,
		"vehicle top speeds escalate cart < truck < racecar")
	check(VehicleProfiles.profile("truck").step_height>VehicleProfiles.profile("cart").step_height
		and VehicleProfiles.profile("cart").step_height>VehicleProfiles.profile("racecar").step_height,
		"curb ability orders truck > cart > racecar")
	# A private sky lane far from the world keeps vehicle physics deterministic.
	var lane := StaticBody3D.new()
	lane.collision_layer=2
	var lane_shape := CollisionShape3D.new()
	var lane_box := BoxShape3D.new()
	lane_box.size=Vector3(10,1,46)
	lane_shape.shape=lane_box
	lane.add_child(lane_shape)
	lane.position=Vector3(140,29.5,140)
	world.add_child(lane)
	var curb := StaticBody3D.new()
	curb.collision_layer=2
	var curb_shape := CollisionShape3D.new()
	var curb_box := BoxShape3D.new()
	curb_box.size=Vector3(8,.45,1)
	curb_shape.shape=curb_box
	curb.add_child(curb_shape)
	# Parked out of the flat-test stretch; repositioned per curb test below.
	curb.position=Vector3(140,30.225,175)
	world.add_child(curb)
	await physics_frame
	await physics_frame
	var rig: VehicleRig=world.vehicles.cart.rig
	check(rig!=null and rig.chassis!=null and rig.driver_marker!=null,"each vehicle carries an authored visual rig with a driver marker")
	check(rig._wheels.size()==4,"the vehicle rig builds four wheel pivots")
	check(world.vehicles.truck.rig.driver_marker.position.z<-0.8,"the truck seats its driver in the cab")
	check(world.vehicles.cart.rig.driver_marker.position.z>1.2,"the cart seats its driver behind the basket")
	# Spatial audio: powered rigs carry a seamless engine loop that only runs
	# while somebody is aboard, the human-powered cart carries none at all,
	# and the world carries the Rat Mart ambience emitters.
	check(world.vehicles.truck.rig.engine_audio.stream!=null and world.vehicles.truck.rig.engine_audio.stream.loop_mode==AudioStreamWAV.LOOP_FORWARD,
		"powered rigs carry a seamless looping engine stream")
	check(not world.vehicles.truck.rig.engine_audio.playing and world.vehicles.cart.rig.engine_audio==null,
		"engines hold silent until someone is aboard; the cart carries none at all")
	check(world.vehicles.truck.rig.impact_audio.stream!=null,"the rig's ImpactAudio hook carries the crash stream")
	check(GameAudio.engine_stream("truck")!=GameAudio.engine_stream("cart") and GameAudio.stream("cash")==GameAudio.stream("cash"),
		"audio streams are synthesized once and shared from the cache")
	var ambience := 0
	for child in world.get_children():
		if child is AudioStreamPlayer3D and child.stream!=null and child.stream.loop_mode==AudioStreamWAV.LOOP_FORWARD:
			ambience+=1
	check(ambience>=6,"the Rat Mart soundscape keeps looping 3D emitters at the fridges, stills and checkout")
	for owned in ["cart","truck","racecar"]:
		if not world.campaign.gear.has(owned): world.campaign.gear.append(owned)
	await physics_frame
	check(not world.vehicles.cart.node.freeze and world.vehicles.cart.node.visible,"owned vehicles unfreeze and render")
	# Arcade acceleration toward the profile top speed, no heading drift.
	world.vehicles.cart.rider=1
	await place_vehicle(world,"cart",155.0)
	await drive_vehicle(world,"cart",Vector2(0,-1),70)
	var cart_planar: float=Vector2(world.vehicles.cart.node.linear_velocity.x,world.vehicles.cart.node.linear_velocity.z).length()
	check(cart_planar>6.0 and cart_planar<=7.51,"cart accelerates toward its profile top speed (%.2f m/s)"%cart_planar)
	check(absf(world.vehicles.cart.node.rotation.y)<.05,"the cart holds a straight heading with no steering input")
	# Throttle-down brakes through momentum before reversing.
	await drive_vehicle(world,"cart",Vector2(0,1),14)
	check(world.vehicles.cart.node.linear_velocity.z<-.01 and world.vehicles.cart.node.linear_velocity.z>-3.0,
		"holding reverse brakes through momentum first")
	await drive_vehicle(world,"cart",Vector2(0,1),60)
	var reversing: float=world.vehicles.cart.node.linear_velocity.z
	check(reversing>3.0 and reversing<=4.05,"reverse speed clamps at the profile maximum (%.2f m/s)"%reversing)
	# Lateral grip scrubs sideways slide instead of ice-skating.
	await place_vehicle(world,"cart",155.0)
	world.vehicles.cart.node.linear_velocity=Vector3(5,0,0)
	await drive_vehicle(world,"cart",Vector2.ZERO,60)
	check(absf(world.vehicles.cart.node.linear_velocity.x)<.5,"lateral grip scrubs sideways slide")
	# Steering tightens with speed instead of snapping yaw.
	await place_vehicle(world,"cart",155.0)
	await drive_vehicle(world,"cart",Vector2(0,-1),30)
	var fast_yaw: float=world.vehicles.cart.node.rotation.y
	await drive_vehicle(world,"cart",Vector2(1,-1),16)
	var fast_rate: float=absf(wrapf(world.vehicles.cart.node.rotation.y-fast_yaw,-PI,PI))/.27
	await place_vehicle(world,"cart",155.0)
	world.vehicles.cart.node.linear_velocity=Vector3(0,0,-2.5)
	await drive_vehicle(world,"cart",Vector2(1,-1),16)
	var slow_rate: float=absf(wrapf(world.vehicles.cart.node.rotation.y,-PI,PI))/.27
	check(fast_rate<slow_rate*.95,"steering tightens as the vehicle speeds up")
	# Curb assist, integration: the truck drives over a .45 curb inside its
	# step height; the assist hops (a velocity), never teleports.
	curb_box.size=Vector3(8,.45,1)
	curb.position=Vector3(140,30.225,150)
	await place_vehicle(world,"truck",157.0)
	world.vehicles.truck.rider=1
	await drive_vehicle(world,"truck",Vector2(0,-1),150)
	check(world.vehicles.truck.node.position.z<149.3,"the truck climbs a curb inside its step height")
	check(float(world.vehicles.truck["hop_clock"])>=0.0,"the truck's curb assist actually fired")
	check(world.vehicles.truck.node.position.y<33.0,"the curb assist hops instead of teleporting")
	check(world.vehicles.truck.rig.engine_audio.playing and not world.vehicles.truck.rig.engine_audio.stream_paused,
		"the truck's engine loop runs while someone is aboard")
	# Racecar: step height .18 is far below the .45 curb. It grinds to a stop
	# at low speed and the assist declines the obstacle (unit-gated too).
	await place_vehicle(world,"racecar",151.9)
	world.vehicles.racecar.rider=1
	world.vehicles.racecar["hop_clock"]=500.0
	world.vehicles.racecar.node.linear_velocity=Vector3(0,0,-4)
	await drive_vehicle(world,"racecar",Vector2.ZERO,70)
	check(world.vehicles.racecar.node.position.z>150.6,"the racecar cannot climb a curb above its step height")
	check(absf(float(world.vehicles.racecar["hop_clock"])-500.0)<.01,"the racecar's curb assist never fires on tall obstacles")
	await place_vehicle(world,"racecar",151.9)
	world.vehicles.racecar["hop_clock"]=-10.0
	world.vehicles.racecar.node.linear_velocity=Vector3(0,0,-4)
	world._vehicle_curb_assist("racecar",world.vehicles.racecar,world.vehicles.racecar.node,
		VehicleProfiles.profile("racecar"),Vector3(0,0,-1),1.0/60)
	check(absf(float(world.vehicles.racecar["hop_clock"])+10.0)<.01,
		"the racecar's assist declines an obstacle above its step height at unit level")
	# Cart: a .28 curb sits inside its .30 step height; unit assist fires, and
	# the cart crests the curb and keeps driving.
	curb_box.size=Vector3(8,.28,1)
	curb.position=Vector3(140,30.14,150)
	await place_vehicle(world,"cart",152.0)
	world.vehicles.cart.node.linear_velocity=Vector3(0,0,-3)
	world._vehicle_curb_assist("cart",world.vehicles.cart,world.vehicles.cart.node,
		VehicleProfiles.profile("cart"),Vector3(0,0,-1),1.0/60)
	check(float(world.vehicles.cart["hop_clock"])>=0.0 and world.vehicles.cart.node.linear_velocity.y>2.0,
		"the cart's curb assist hops a standard curb")
	await place_vehicle(world,"cart",156.0)
	await drive_vehicle(world,"cart",Vector2(0,-1),150)
	check(world.vehicles.cart.node.position.z<149.4,"the cart crests a standard curb and keeps driving")
	# Ram impacts: discrete events with per-enemy cooldowns.
	var guard: Node3D=world.enemies[0]
	var guard_home: Vector3=guard.global_position
	var guard_state: String=guard.state
	var alarm_before: float=world.alarm
	await place_vehicle(world,"truck",155.0)
	world.vehicles.truck.node.linear_velocity=Vector3(0,0,-12)
	guard.global_position=world.vehicles.truck.node.global_position+Vector3(0,0,-2)
	var truck_record: Dictionary=world.vehicles.truck
	var truck_profile: Dictionary=VehicleProfiles.profile("truck")
	var guard_hp: float=guard.hp
	world._ram_impacts("truck",truck_record,world.vehicles.truck.node,truck_profile)
	var ram_damage: float=guard_hp-guard.hp
	check(ram_damage>4.0 and guard.state=="STUNNED","a fast truck ram damages and stuns a guard as one impact event")
	world._ram_impacts("truck",truck_record,world.vehicles.truck.node,truck_profile)
	check(absf(guard.hp-(guard_hp-ram_damage))<.01,"the ram cooldown blocks immediate repeat damage")
	world.game_clock+=2.0
	world._ram_impacts("truck",truck_record,world.vehicles.truck.node,truck_profile)
	check(absf(guard.hp-(guard_hp-ram_damage*2.0))<.01,"a ram can connect again once the cooldown elapses")
	# Cheap cargo load estimation counts basket merchandise and feeds penalties.
	# The estimate refreshes at 8 Hz, so wait past one refresh period.
	await place_vehicle(world,"cart",155.0)
	var container: Node3D=level.get_node("Environment/ItemContainer")
	var crate_homes: Array[Vector3]=[]
	for i in range(5):
		var crate: RigidBody3D=container.get_child(i)
		crate_homes.append(crate.global_position)
		crate.global_position=world.vehicles.cart.node.global_position+Vector3(0,.8,0)
		crate.linear_velocity=Vector3.ZERO
	await create_timer(.2).timeout
	check(float(world.vehicles.cart["load"])>0.2,"cargo load estimation counts merchandise in the basket (%.2f)"%float(world.vehicles.cart["load"]))
	for i in range(5):
		container.get_child(i).global_position=crate_homes[i]
		container.get_child(i).linear_velocity=Vector3.ZERO
	# Remote snapshots glide the rig instead of snapping across the map.
	await place_vehicle(world,"cart",150.0)
	var smooth_before: Vector3=world.vehicles.cart.node.global_position
	rig.net_update(smooth_before+Vector3(3,0,0),0.0)
	await physics_frame
	await physics_frame
	await physics_frame
	check(world.vehicles.cart.node.global_position.distance_to(smooth_before)>1.0,"remote vehicle snapshots glide instead of snapping")
	rig.reset_network()
	var car_snapshot: Dictionary=world.snapshot().cars
	check(car_snapshot.has("cart") and car_snapshot.cart.size()==3,"vehicle snapshots keep the [position,yaw,rider] format")
	# Park everything and restore the touched guard and gear.
	world.vehicles.cart.rider=0
	world.vehicles.truck.rider=0
	world.vehicles.racecar.rider=0
	for parked in ["cart","truck","racecar"]:
		world.vehicle_inputs.erase(parked)
		world.campaign.gear.erase(parked)
		var body: RigidBody3D=world.vehicles[parked].node
		body.position=world.vehicles[parked].home
		body.rotation.y=0
		body.linear_velocity=Vector3.ZERO
		world.vehicles[parked].rig.reset_network()
	guard.hp=100.0
	guard.state=guard_state
	guard.timer=0.0
	guard.global_position=guard_home
	world.alarm=alarm_before
	lane.queue_free()
	curb.queue_free()
	var motion: Node3D=world.get_node_or_null("StoreMotion")
	var paired: int=0
	if motion:
		for entry in motion.fixtures:
			if entry.light != null:
				paired+=1
	check(motion != null and motion.fixtures.size()==4 and paired>=3,"store flicker fixtures pair with the real lights")
	for enemy in world.enemies: enemy.set_physics_process(false)
	await create_timer(.3).timeout
	check(level.get_node("Environment/ItemContainer").get_child_count()==62,"four stores have 62 physics merchandise objects")
	world._stock_store()
	check(level.get_node("Environment/ItemContainer").get_child_count()==62,"restocking is idempotent")
	var cargo: RigidBody3D=level.get_node("Environment/ItemContainer").get_child(0)
	cargo.global_position=Vector3(0,1,-8)
	player.global_position=Vector3(0,.1,-5)
	world.toggle_cargo(player,Vector3.FORWARD)
	check(cargo.carried_by==1 and world.player_state["1"].held!="","physical merchandise can be carried")
	world.release_cargo(1,Vector3(0,1,-5))
	check(cargo.carried_by==0 and cargo.linear_velocity.z<0,"carried merchandise can be thrown")
	player.global_position=Vector3(-6.5,.2,-31)
	world.enemies[0]._physics_process(.1)
	check(world.enemies[0].state=="HUNT","guard detects and pursues a visible player")
	var before_guard: float=world.enemies[0].hp
	player.global_position=world.enemies[0].global_position+Vector3(0,0,2.7)
	world.melee(player,Vector3.FORWARD)
	check(world.enemies[0].hp<before_guard,"melee damages a nearby guard")
	player.global_position=Vector3(0,1,6)
	world.request_interaction("Recipe")
	check(not world.recipe_recovered,"recipe cannot be stolen remotely or before boss defeat")
	await create_timer(.5).timeout
	player.global_position=Vector3(0,1,3)
	world.request_interaction("Manhole")
	check(player.global_position.y < -10,"manhole reaches hideout")
	await create_timer(.5).timeout
	player.global_position=Vector3(0,-11,23)
	world.request_interaction("BaseExit")
	check(player.global_position.y>0,"ladder returns to street")
	var old_cash: int=world.campaign.cash
	world.shop_action(player,"buy:water")
	check(int(world.campaign.cash)==old_cash,"distant shopping rejected")
	player.global_position=Vector3(-10,-11,32)
	world.shop_action(player,"buy:water")
	check(world.campaign.gear.has("water") and int(world.campaign.cash)==old_cash-90,"trader charges once and unlocks shared water gun")
	world.shop_action(player,"buy:water")
	check(int(world.campaign.cash)==old_cash-90,"duplicate nonconsumable purchase rejected")
	player.global_position=Vector3(7,1,-72.5)
	world.interact(player,"Recipe")
	check(not world.recipe_recovered,"boss guards the blueprint")
	world.enemies[4]._physics_process(.1)
	check(world.enemies[4].state=="WIND UP","boss telegraphs its charge")
	var before_sabotage: float=world.enemies[4].hp
	player.global_position=Vector3(-9,-11,-51.7)
	world.interact(player,"Valve0")
	check(world.enemies[4].hp==before_sabotage-65,"distillery sabotage weakens the boss")
	world.interact(player,"Valve0")
	check(world.enemies[4].hp==before_sabotage-65,"each valve can be sabotaged only once per heist")
	world.enemies[4].take_damage(1000)
	check(world.recipe_recovered and int(world.campaign.recipes[0])==1,"boss awards guaranteed recipe and opens road")
	world.enemies[4].take_damage(1000)
	check(int(world.campaign.recipes[0])==1,"dead boss cannot award duplicate rewards")
	var before_bank: float=world.campaign.bank
	world._physics_process(1.0)
	check(world.campaign.bank>before_bank,"installed machine generates active-session income")
	world.update_machines()
	check(world.machine_visuals[0].visible,"a purchased machine shows its production visual")
	var spin: float=world.machine_visuals[0].get_node("Output").rotation.y
	world._animate_machines(.25)
	check(world.machine_visuals[0].get_node("Output").rotation.y>spin,"machine output spins per frame from local time")
	player.global_position=Vector3(5,-11,25)
	world.interact(player,"CollectIncome")
	check(world.campaign.bank<1,"income terminal transfers whole dollars to crew funds")
	player.global_position=Vector3(9,1,-12)
	var cash_before_sale: int=world.campaign.cash
	player.player_inventory.add_item(root.get_node("ItemDatabase").get_item("stolen_goods"),2)
	world.sell_loot(player)
	check(int(world.campaign.cash)>=cash_before_sale+90,"extraction sells physical inventory merchandise")
	world.player_state["1"].hurt_cooldown=0
	world.hurt_player(1,200,Vector3.ZERO)
	check(world.player_state["1"].hp==0,"damage downs a player")
	world.revive(1,45)
	check(world.player_state["1"].hp==45,"revive restores health")
	var buddy := Node3D.new()
	buddy.name="2"
	level.get_node("PlayersContainer").add_child(buddy)
	world.ensure_player(2)
	player.global_position=Vector3(0,1,6)
	buddy.global_position=Vector3(0,1,4.5)
	world.player_state["2"].hp=55
	player.player_inventory.add_item(root.get_node("ItemDatabase").get_item("canned_food"),2)
	world.action_times.clear()
	world.request_action("feed","",Vector3.FORWARD)
	check(world.player_state["2"].hp==85 and player.player_inventory.remove_item("canned_food",9999)==1,"canned food fed to a hurt teammate heals them and leaves the bag")
	world.player_state["2"].hp=100
	player.player_inventory.add_item(root.get_node("ItemDatabase").get_item("rotten_cheese"),1)
	world.action_times.clear()
	world.request_action("feed","",Vector3.FORWARD)
	check(world.player_state["2"].speed_buff==20.0,"cheese fed to a healthy teammate grants the speed effect")
	buddy.global_position=Vector3(0,1,40)
	player.player_inventory.add_item(root.get_node("ItemDatabase").get_item("moonshine"),1)
	world.action_times.clear()
	world.request_action("feed","",Vector3.FORWARD)
	check(player.player_inventory.remove_item("moonshine",9999)==1,"feeding without a teammate in range keeps the food")
	buddy.queue_free()
	world.player_state.erase("2")
	world.campaign.forms=["rat","boar"]
	world.request_action("transform","",Vector3.FORWARD)
	check(world.player_state["1"].form=="rat","unlocked animal transformation activates")
	await create_timer(.3).timeout
	world.request_action("slime","",Vector3.FORWARD)
	check(world.player_state["1"].form=="slime","returning to slime during cooldown is allowed")
	world.request_action("transform","",Vector3.FORWARD)
	check(world.player_state["1"].form=="slime","120-second species-change cooldown is enforced")
	world.campaign.cash=999
	player.global_position=Vector3(-10,-11,32)
	var tool_before: String=world.player_state["1"].tool
	world.shop_action(player,"buy:cart")
	check(world.campaign.gear.has("cart"),"shopping cart can be purchased")
	check(world.player_state["1"].tool==tool_before,"buying a vehicle leaves everyone's tool alone")
	player.global_position=world.vehicles.cart.node.global_position
	world.interact(player,"")
	check(world.vehicles.cart.rider==1,"player can board purchased cart")
	world.drive(Vector2(0,-1),Vector3.FORWARD)
	world.update_vehicles(.1)
	check(world.vehicles.cart.node.linear_velocity.z<0,"server drives the vehicle")
	world.interact(player,"")
	check(world.vehicles.cart.rider==0,"player can dismount")
	# Q cycles owned ACTIVE TOOLS only: vehicles stay parked, unknown tools
	# normalize, and the cycle wraps inside the owned set.
	world.action_times.clear()
	world.player_state["1"].tool="water"
	world.request_action("cycle","",Vector3.FORWARD)
	check(world.player_state["1"].tool=="grapple","Q wraps from the last owned tool back to the first")
	world.action_times.clear()
	world.request_action("cycle","",Vector3.FORWARD)
	check(world.player_state["1"].tool=="crystal","Q advances to the next owned active tool")
	world.action_times.clear()
	world.player_state["1"].tool="cart"
	world.request_action("cycle","",Vector3.FORWARD)
	check(world.player_state["1"].tool in world.ACTIVE_TOOLS and world.campaign.gear.has(world.player_state["1"].tool),"a stale vehicle tool normalizes into the owned active-tool cycle")
	# Malformed legacy tool state recovers: vehicles can never be tools, the
	# starter grapple is re-granted when nothing owned is active, and the
	# invariant (tool in ACTIVE_TOOLS AND in gear) always holds afterwards.
	var legacy_gear: Array=world.campaign.gear.duplicate()
	var legacy_tool: String=world.player_state["1"].tool
	world.campaign.gear=["cart","truck"]
	world.player_state["1"].tool="racecar"
	world.ensure_player(1)
	check(world.player_state["1"].tool=="grapple","a vehicle-tool legacy save recovers to the starter grapple")
	check(world.campaign.gear.has("grapple"),"the starter grapple is re-granted when the gear holds no active tool")
	world.campaign.gear=[]
	world.player_state["1"].tool="laser"
	world.ensure_player(1)
	check(world.player_state["1"].tool=="grapple" and world.campaign.gear.has("grapple"),"an unknown tool with an empty gear restores the starter grapple")
	world.campaign.gear=["water","crystal"]
	world.player_state["1"].tool="water"
	world.ensure_player(1)
	check(world.player_state["1"].tool=="water","an owned active tool is left untouched")
	check(world.player_state["1"].tool in world.ACTIVE_TOOLS and world.campaign.gear.has(world.player_state["1"].tool),"the active-tool invariant holds after recovery")
	world.campaign.gear=legacy_gear
	world.player_state["1"].tool=legacy_tool
	var packet := var_to_bytes(world.snapshot()).compress(FileAccess.COMPRESSION_DEFLATE)
	check(packet.size()<1300,"compressed state stays within one network packet")
	var restored = bytes_to_var(packet.decompress_dynamic(1048576,FileAccess.COMPRESSION_DEFLATE))
	check(restored is Dictionary and restored.players.has("1"),"network snapshot compression round-trips")
	world.campaign_path="user://crooked_mile_validation.json"
	world.persistence_enabled=true
	world.save_campaign()
	world.campaign.cash=0
	world.load_campaign()
	check(int(world.campaign.cash)==899,"campaign survives save and reload")
	DirAccess.remove_absolute(world.campaign_path)
	world.persistence_enabled=false
	for point in [Vector3(0,2,-20.5),Vector3(0,2,-24),Vector3(11,2,-50),Vector3(0,-10,25),Vector3(10,-10,-42),Vector3(45,2,-23),Vector3(61,2,23),Vector3(74,2,-25)]:
		var query := PhysicsRayQueryParameters3D.create(point,point+Vector3.DOWN*3,2)
		check(not world.get_world_3d().direct_space_state.intersect_ray(query).is_empty(),"walkable floor "+str(point))
	# Guard labels: no permanent floating readout, brief show after damage.
	world.enemies[0].title_clock=0.0
	world.enemies[0]._process(.016)
	check(not world.enemies[0].title.visible,"guards carry no permanent floating readout")
	world.enemies[0].title_clock=2.5
	var cam: Camera3D=world.get_viewport().get_camera_3d()
	if cam:
		world.enemies[0].global_position=cam.global_position+Vector3(0,0,2)
	world.enemies[0]._process(.016)
	check(world.enemies[0].title.visible,"a recently damaged guard shows its label briefly")
	if "--server" not in args:
		# The controls legend belongs to the session, not the menu, and every
		# fresh session restarts it.
		world.controls_clock=7.0
		world._process(.2)
		check(world.controls_clock==7.0,"controls legend does not tick while no session is live")
		world._reset()
		check(world.controls_clock==14.0,"a fresh session restarts the controls legend clock")
	if "--server" in args:
		player.queue_free()
		world.player_state.erase("1")
		await process_frame
		print("SERVER_READY")
		await create_timer(16).timeout
	network.leave_game()
	quit(1 if failed else 0)

## Teleport a vehicle onto the sky lane (x=140) and let it settle onto the
## floor (a full drop takes ~.35s of physics).
func place_vehicle(world: Node3D,kind: String,z: float) -> void:
	var body: RigidBody3D=world.vehicles[kind].node
	body.position=Vector3(140,30.8,z)
	body.rotation.y=0.0
	body.linear_velocity=Vector3.ZERO
	for i in range(26):
		await physics_frame

## Feed drive input for N physics frames, refreshing it well inside the .5s
## input-freshness window the server enforces.
func drive_vehicle(world: Node3D,kind: String,move: Vector2,frames: int) -> void:
	for i in range(frames):
		if i%20==0:
			world.vehicle_inputs[kind]={"movement":move,"direction":Vector3.FORWARD,"time":world.game_clock}
		await physics_frame
