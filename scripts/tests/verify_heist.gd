extends SceneTree
var level: Node3D
var world: Node3D
var failed := false
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
	world.shop_action(player,"buy:cart")
	check(world.campaign.gear.has("cart"),"shopping cart can be purchased")
	player.global_position=world.vehicles.cart.node.global_position
	world.interact(player,"")
	check(world.vehicles.cart.rider==1,"player can board purchased cart")
	world.drive(Vector2(0,-1),Vector3.FORWARD)
	world.update_vehicles(.1)
	check(world.vehicles.cart.node.linear_velocity.z<0,"server drives the vehicle")
	world.interact(player,"")
	check(world.vehicles.cart.rider==0,"player can dismount")
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
	if "--server" in args:
		player.queue_free()
		world.player_state.erase("1")
		await process_frame
		print("SERVER_READY")
		await create_timer(16).timeout
	network.leave_game()
	quit(1 if failed else 0)
