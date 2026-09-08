extends Node3D
## Host-authoritative co-op campaign: encounters, economy, tools and world state.
const Guard = preload("res://scripts/heist/security_guard.gd")
const Materials = preload("res://scripts/visuals/character_materials.gd")
const Visual = preload("res://scripts/heist/slime_visual.gd")
const Palette = preload("res://scripts/visuals/palette.gd")
const Widgets = preload("res://scripts/visuals/hud_widgets.gd")
const WorldFx = preload("res://scripts/visuals/world_fx.gd")
const GameAudio = preload("res://scripts/audio/game_audio.gd")
const GOODS := ["rotten_cheese","moonshine","canned_food","stolen_goods"]
const SPECIES := ["rat","boar","bird","lizard"]
const PRICES := {"grapple":80,"water":90,"crystal":65,"jetpack":180,"cart":100,"truck":260,"racecar":200}
const TOOL_NAMES := {"grapple":"Grappling hook","water":"Water gun","crystal":"Slime crystal","jetpack":"Jetpack","cart":"Shopping cart","truck":"Mini truck","racecar":"Racecar"}
# Q cycles the crew's ACTIVE TOOLS only. Vehicles are parked gear you drive
# from the driver's seat - buying or owning one must never change the
# equipped tool. campaign.gear keeps storing both (old saves stay valid).
const ACTIVE_TOOLS := ["grapple","water","crystal","jetpack"]
const VEHICLE_KINDS := ["cart","truck","racecar"]
const SAVE_FILE := "user://crooked_mile_campaign_v2.json"
@export var persistence_enabled := true
@export var campaign_path := SAVE_FILE
var recipe_recovered := false
var stock_spawned := false
var session_active := false
var nearest: Marker3D
var hud: Label
var prompt: Label
var toast: Label
var shop: PanelContainer
var shop_rows: VBoxContainer
var shop_open := false
var request_times: Dictionary = {}
var action_times: Dictionary = {}
var player_state: Dictionary = {}
var enemies: Array = []
var vehicles: Dictionary = {}
var vehicle_inputs: Dictionary = {}
var audio_occlusion: AudioOcclusion
var campaign: Dictionary = {}
var alarm := 0.0
var sabotage := 0
var defeated := [false,false,false,false]
var bait: Array = []
var fires: Array = []
var nav := AStar3D.new()
var sync_clock := 0.0
var save_clock := 0.0
var toast_clock := 0.0
var vehicle_clock := 0.0
var wipe_clock := 0.0
var game_clock := 0.0
var carry_clock := 0.0
var hazard_visuals: Array[Node3D] = []
var bait_visuals: Array[Node3D] = []
var cameras: Array = []
var machine_visuals: Array[Node3D] = []
var tool_icon: TextureRect
var hud_root: Control
var task_label: Label
var alarm_frame: PanelContainer
var alarm_bar: ProgressBar
var alarm_fill: StyleBoxFlat
var boss_frame: PanelContainer
var boss_bar: ProgressBar
var boss_label: Label
var cash_label: Label
var hp_bar: ProgressBar
var hp_fill: StyleBoxFlat
var fuel_bar: ProgressBar
var fuel_fill: StyleBoxFlat
var form_label: Label
var tool_label: Label
var toast_frame: PanelContainer
var prompt_frame: PanelContainer
var controls_hint: Label
var controls_clock := 14.0
var _text_cache: Dictionary = {}
const ART_INDEX := {"grapple":4,"water":5,"crystal":6,"jetpack":7,"cart":8,"truck":9,"racecar":10}

func _ready() -> void:
	fresh_campaign()
	build_ui()
	build_encounters()
	build_vehicles()
	build_security_cameras()
	build_machine_visuals()
	# The Rat Mart soundscape: fridge hums, cellar stills, in-store jingle.
	# All placement and synthesis lives in GameAudio.
	GameAudio.build_rat_mart_ambience(self)
	# Wall occlusion runs after the ambience exists so its initial sweep
	# registers every emitter; later one-shots and rig hooks arrive via
	# tree signals.
	audio_occlusion=AudioOcclusion.new()
	audio_occlusion.name="AudioOcclusion"
	add_child(audio_occlusion)
	Network.player_connected.connect(_on_player_connected)
	Network.server_disconnected.connect(_reset)
	multiplayer.peer_disconnected.connect(_peer_left)
	call_deferred("build_navigation")

func fresh_campaign() -> void:
	campaign={"cash":160,"bank":0.0,"recipes":[0,0,0,0],"machines":[-1],"gear":["grapple","crystal"],"forms":[],"upgrades":{},"crystals":1,"wins":0}

func load_campaign() -> void:
	if not persistence_enabled or not FileAccess.file_exists(campaign_path):
		return
	var file := FileAccess.open(campaign_path,FileAccess.READ)
	if not file:
		return
	var data = JSON.parse_string(file.get_as_text())
	if data is Dictionary and data.get("recipes") is Array and data.recipes.size()==4:
		for key in campaign:
			if data.has(key) and typeof(data[key])==typeof(campaign[key]):
				campaign[key]=data[key]
		# JSON numbers decode as floats.
		for key in ["cash","crystals","wins"]:
			campaign[key]=maxi(0,int(data.get(key,campaign[key])))
		campaign.bank=maxf(0,float(data.get("bank",0)))

func save_campaign() -> void:
	if not persistence_enabled or not multiplayer.is_server() or not session_active:
		return
	var file := FileAccess.open(campaign_path,FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(campaign))

func _exit_tree() -> void:
	if session_active and multiplayer.is_server():
		save_campaign()

func _reset() -> void:
	# Economy is saved on every transaction and periodically during production.
	session_active=false
	stock_spawned=false
	player_state.clear()
	request_times.clear()
	action_times.clear()
	vehicle_inputs.clear()
	bait.clear()
	fires.clear()
	alarm=0
	sabotage=0
	defeated=[false,false,false,false]
	close_shop()
	for camera in cameras: camera.disabled=false
	for enemy in enemies:
		enemy.hp=enemy.max_hp
		enemy.position=enemy.home
		enemy.target_position=enemy.home
		enemy.state="PATROL"
	for kind in vehicles:
		vehicles[kind].rider=0
		vehicles[kind].ram_clock.clear()
		vehicles[kind].node.position=vehicles[kind].home
		vehicles[kind].node.rotation.y=0
		vehicles[kind].rig.reset_network()
	fresh_campaign()
	apply_progress(false)
	controls_clock=14.0

func _peer_left(id: int) -> void:
	release_cargo(id,Vector3.ZERO)
	player_state.erase(str(id))
	for kind in vehicles:
		if vehicles[kind].rider==id:
			vehicles[kind].rider=0

func _on_player_connected(id: int, _info: Dictionary) -> void:
	if multiplayer.is_server():
		if not session_active:
			load_campaign()
			session_active=true
			apply_progress(int(campaign.recipes[0])>0)
			controls_clock=14.0
		ensure_player(id)
		call_deferred("_stock_store")
		call_deferred("broadcast_state")
	else:
		session_active=true
		controls_clock=14.0
		request_progress.rpc_id(1)

func ensure_player(id: int) -> Dictionary:
	var key := str(id)
	if not player_state.has(key):
		player_state[key]={"hp":100.0,"form":"slime","form_cooldown":0.0,"speed_buff":0.0,"strength_buff":0.0,"hurt_cooldown":0.0,"down_time":0.0,"tool":"grapple","fuel":100.0,"vehicle":"","grapple_cd":0.0,"held":"","carry_direction":Vector3.FORWARD,"last_form":"","gesture":"idle","gesture_time":0.0}
	# Snap stale tools back to an owned active tool: old saves or snapshots
	# can carry a vehicle, and Q can never equip one.
	var data: Dictionary = player_state[key]
	if data.tool not in ACTIVE_TOOLS or data.tool not in campaign.gear:
		data.tool=normalize_tool(str(data.tool))
	return player_state[key]


## First owned active tool that isn't the given one, or the first owned at all.
## Legacy saves/snapshots can carry vehicles ("racecar" with gear=["cart","truck"])
## or nothing owned at all - the starter grapple is then (re)granted so the
## returned tool is always in ACTIVE_TOOLS AND in gear.
func normalize_tool(tool: String) -> String:
	for kind in ACTIVE_TOOLS:
		if kind in campaign.gear and kind!=tool:
			return kind
	if "grapple" not in campaign.gear:
		campaign.gear.append("grapple")
	return "grapple"

func live_players() -> Array:
	var found: Array = []
	for player in get_tree().current_scene.get_node("PlayersContainer").get_children():
		if float(player_state.get(str(player.name),{}).get("hp",100))>0:
			found.append(player)
	return found

func player_for(id: int) -> CharacterBody3D:
	return get_tree().current_scene.get_node_or_null("PlayersContainer/"+str(id)) as CharacterBody3D

func local_player() -> CharacterBody3D:
	return player_for(multiplayer.get_unique_id()) if multiplayer.has_multiplayer_peer() else null

func build_encounters() -> void:
	var group := Node3D.new()
	group.name="Security"
	add_child(group)
	var specs := [
		[Vector3(-6.5,.1,-35),false,0],[Vector3(8.5,.1,-42),false,0],
		[Vector3(10,.1,-57),false,0],[Vector3(10,-11.9,-49),false,0],
		[Vector3(0,.1,-70),true,0],
		[Vector3(40,.1,-29),false,1],[Vector3(50,.1,-39),false,1],[Vector3(45,.1,-51),true,1],
		[Vector3(56,.1,31),false,2],[Vector3(66,.1,43),false,2],[Vector3(61,.1,53),true,2],
		[Vector3(69,.1,-29),false,3],[Vector3(79,.1,-38),false,3],[Vector3(74,.1,-51),true,3]]
	for i in specs.size():
		var enemy = Guard.new()
		enemy.name="Guard%d"%i
		enemy.setup(self,specs[i][0],specs[i][1],specs[i][2])
		group.add_child(enemy)
		enemies.append(enemy)
	var dummy := get_node_or_null("RatStore/ChefRat")
	if dummy:
		dummy.hide()

func build_navigation() -> void:
	await get_tree().physics_frame
	var id := 0
	for x in [-14.0,-6.5,.5,8.5,11.0]:
		for z in [-26.0,-36.5,-47.5,-54.0,-62.0,-68.0,-75.0]:
			nav.add_point(id,Vector3(x,.2,z))
			id+=1
	for a in nav.get_point_ids():
		for b in nav.get_point_ids():
			if b<=a:
				continue
			var from := nav.get_point_position(a)
			var to := nav.get_point_position(b)
			if from.distance_to(to)<13 and clear_line(from+Vector3.UP,to+Vector3.UP):
				nav.connect_points(a,b)

func clear_line(from: Vector3,to: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(from,to,2)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func route(from: Vector3,to: Vector3) -> PackedVector3Array:
	if clear_line(from+Vector3.UP,to+Vector3.UP) or from.y < -5 or absf(from.x)>17:
		return PackedVector3Array([to])
	if nav.get_point_count()==0:
		return PackedVector3Array([to])
	var start := nav.get_closest_point(from)
	var end := nav.get_closest_point(to)
	return nav.get_point_path(start,end)

func find_target(origin: Vector3,radius: float,species: int,ignore_disguise: bool=false) -> Node3D:
	var closest: Node3D = null
	for player in live_players():
		if absf(player.global_position.y-origin.y)>4 or store_tier(player.global_position)!=species:
			continue
		if not ignore_disguise and player_state.get(str(player.name),{}).get("form", "slime")==SPECIES[species] and alarm<50:
			continue
		var distance: float = player.global_position.distance_to(origin)
		if distance<radius and clear_line(origin+Vector3.UP,player.global_position+Vector3.UP):
			radius=distance
			closest=player
	return closest

func store_tier(point: Vector3) -> int:
	if point.z < -23 and absf(point.x)<17:
		return 0
	if point.z < -19 and point.x>33 and point.x<57:
		return 1
	if point.z>20 and point.x>49 and point.x<73 and point.y>-5:
		return 2
	if point.z < -19 and point.x>62:
		return 3
	return -1

func nearby_bait(point: Vector3) -> Vector3:
	for food in bait:
		if point.distance_to(food.position)<14:
			return food.position
	return Vector3.INF

func _stock_store() -> void:
	if stock_spawned:
		return
	stock_spawned=true
	var container := get_node("../ItemContainer")
	for marker in $LootSpawns.get_children():
		var item: Node3D=load(marker.get_meta("scene")).instantiate()
		item.position=container.to_local(marker.global_position)
		container.add_child(item,true)

func _physics_process(delta: float) -> void:
	if not multiplayer.has_multiplayer_peer() or not multiplayer.is_server() or not session_active:
		return
	game_clock+=delta
	sync_clock+=delta
	save_clock+=delta
	alarm=maxf(0,alarm-delta*1.1)
	for key in player_state:
		var data: Dictionary=player_state[key]
		for timer in ["form_cooldown","speed_buff","strength_buff","hurt_cooldown","grapple_cd","gesture_time"]:
			data[timer]=maxf(0,float(data[timer])-delta)
		var player := player_for(int(key))
		if not player:
			continue
		if player.global_position.y < -5 and player.global_position.z>0:
			data.fuel=minf(100,float(data.fuel)+delta*15)
			data.hp=minf(100,float(data.hp)+delta*5)
		if float(data.hp)<=0:
			data.down_time+=delta
			if float(data.down_time)>30:
				revive(int(key),50)
				send_travel(int(key),Vector3(0,-10.9,25))
		else:
			data.down_time=0
		if store_tier(player.global_position)>=0:
			alarm=minf(100,alarm+delta*.3)
		if data.get("held", "") != "":
			var held := get_node("../ItemContainer").get_node_or_null(NodePath(str(data.held))) as RigidBody3D
			if held:
				held.global_position=player.global_position+Vector3.UP*1.3+data.get("carry_direction",Vector3.FORWARD)*1.6
				held.linear_velocity=Vector3.ZERO
			else:
				data.held=""
		var active_form: String=data.form
		if active_form!="slime" and active_form not in campaign.forms:
			data.form="slime"
	for machine in campaign.machines if not player_state.is_empty() else []:
		var recipe_index := int(machine)
		if recipe_index>=0 and recipe_index<4:
			campaign.bank+=delta*(1.0+recipe_index*1.5)*int(campaign.recipes[recipe_index])
	for i in range(bait.size()-1,-1,-1):
		bait[i].time-=delta
		if bait[i].time<=0:
			bait.remove_at(i)
	for i in range(fires.size()-1,-1,-1):
		fires[i].time-=delta
		if fires[i].time<=0:
			fires.remove_at(i)
			continue
		for player in live_players():
			if player.global_position.distance_to(fires[i].position)<2.6 and fires[i].get("source","")!=str(player.name):
				hurt_player(int(str(player.name)),5,Vector3.ZERO)
		for enemy in enemies:
			if enemy.hp>0 and enemy.global_position.distance_to(fires[i].position)<3 and fires[i].get("source","")!=str(enemy.name):
				enemy.take_damage(delta*15)
	update_vehicles(delta)
	security_scan(delta)
	update_machines()
	if not player_state.is_empty() and live_players().is_empty():
		wipe_clock+=delta
		if wipe_clock>5:
			for key in player_state:
				revive(int(key),75)
				send_travel(int(key),Vector3(0,-10.9,25))
			campaign.cash=maxi(0,int(campaign.cash)-30)
			alarm=0
			notice.rpc("Crew rescued. $30 recovery fee. Your loot is still in your bags.")
			wipe_clock=0
	else:
		wipe_clock=0
	if sync_clock>=.1:
		sync_clock=0
		broadcast_state()
	if save_clock>=10:
		save_clock=0
		save_campaign()

func hurt_player(id: int,amount: float,knockback: Vector3) -> void:
	var data := ensure_player(id)
	if float(data.hp)<=0 or float(data.hurt_cooldown)>0:
		return
	data.hp=maxf(0,float(data.hp)-amount)
	data.hurt_cooldown=.8
	var victim := player_for(id)
	if victim:
		# Short readable slap pop - no giant explosion, the squash reads first.
		fx.rpc(victim.global_position+Vector3.UP,Color("ff9db1"),.6)
	if data.hp<=0:
		release_cargo(id,Vector3.ZERO)
		data.vehicle=""
		for kind in vehicles:
			if vehicles[kind].rider==id:
				vehicles[kind].rider=0
		notice.rpc("A slime is down! F nearby to revive, or use a slime crystal.")
	else:
		impulse_player.rpc(id,knockback+Vector3.UP*2)

func revive(id: int,health: float) -> void:
	var data := ensure_player(id)
	data.hp=health
	data.down_time=0
	data.hurt_cooldown=3.0

func enemy_defeated(enemy: Node3D) -> void:
	if enemy.boss:
		var tier: int=enemy.tier
		if defeated[tier]:
			return
		defeated[tier]=true
		campaign.recipes[tier]=int(campaign.recipes[tier])+1
		campaign.cash+=150+tier*120
		campaign.wins+=1
		if int(campaign.machines[0])<0:
			campaign.machines[0]=tier
		if randf()<.4 and SPECIES[tier] not in campaign.forms:
			campaign.forms.append(SPECIES[tier])
			notice.rpc("RARE DROP! %s transformation unlocked for the whole crew."%SPECIES[tier].to_upper())
		else:
			notice.rpc("BOSS DEFEATED! Recipe upgraded to level %d. $%d recovered."%[campaign.recipes[tier],150+tier*120])
		apply_progress.rpc(int(campaign.recipes[0])>0)
		fx.rpc(enemy.global_position+Vector3.UP*2,Color("d9ed84"),3.0)
		play_sound.rpc("win",enemy.global_position+Vector3.UP*2)
		save_campaign()
	else:
		campaign.cash+=12+enemy.tier*5
		fx.rpc(enemy.global_position+Vector3.UP,Color("c0d39b"),.5)

func fire_breath(origin: Vector3,direction: Vector3,source: String="") -> void:
	for i in range(1,5):
		var pos := origin+direction*i*2
		fires.append({"position":pos,"time":4.0,"source":source})
		fx.rpc(pos+Vector3.UP*.4,Color("ff7d31"),2.0)

func _process(delta: float) -> void:
	var level := get_tree().current_scene
	var active: bool=multiplayer.has_multiplayer_peer() and not level.main_menu.is_menu_visible()
	hud.visible=active
	tool_icon.visible=active and not shop_open
	prompt.visible=active and not level.is_camera_input_blocked()
	# Toast frame follows the message clock exactly - an empty pill would just
	# be a dead panel covering the store signage.
	toast_frame.visible=active and toast_clock>0
	toast_clock-=delta
	_animate_machines(delta)
	if not active:
		return
	# The controls legend belongs to the heist, not the menu: the clock only
	# runs while a session is live, and every fresh session restarts it.
	controls_clock=maxf(0.0,controls_clock-delta)
	var player := local_player()
	if not player:
		return
	var data: Dictionary=player_state.get(str(player.name),{})
	var location := "THE CROOKED MILE"
	var tier := store_tier(player.global_position)
	if tier>=0:
		location=["RAT MART","BOAR HARDWARE","BIRD SEED & CO.","COLD BLOOD ELECTRONICS"][tier]
	if player.global_position.y < -5:
		location="THE UNDERCUT" if player.global_position.z>0 else "BASEMENT DISTILLERY"
	var task := "Rob Rat Mart. Defeat the chef. Bring your loot to the van."
	if int(campaign.recipes[0])>0:
		task="East road open. Raid the next store or replay an earlier heist."
	if int(campaign.recipes[3])>0:
		task="The mecha dragon is down. The Crooked Mile belongs to your crew."
	_set_text(hud,"hud","%s   |   CREW %d/4"%[location,Network.players.size()])
	_update_widgets(data,task)
	nearest=null
	var distance := 3.3
	for marker in $Interactions.get_children():
		var d: float=player.global_position.distance_to(marker.global_position)
		if d<distance:
			distance=d
			nearest=marker
	# Controls legend: shown for the first moments of a session, then only the
	# tiny dim hint stays - context prompts take priority over both.
	var show_controls := controls_clock>0
	# Legend labels come from the live InputMap so a rebound key reads correctly.
	var prompt_text := "%s Grab/drop   %s Slap/throw   %s Tool   %s Tools   %s Bait   %s Eat   %s Feed   %s Form   %s Slime"%[
		Prefs.action_label("carry"),Prefs.action_label("attack"),Prefs.action_label("tool_use"),
		Prefs.action_label("cycle_tool"),Prefs.action_label("bait"),Prefs.action_label("eat"),
		Prefs.action_label("feed"),Prefs.action_label("transform"),Prefs.action_label("slime")] if show_controls else ""
	if nearest:
		prompt_text="["+Prefs.action_label("use_tool")+"] "+str(nearest.get_meta("hint"))
	var near_teammate := false
	for other in level.players_container.get_children():
		if other==player:
			continue
		if other.global_position.distance_to(player.global_position)>=3:
			continue
		if float(player_state.get(str(other.name),{}).get("hp",100))<=0:
			prompt_text="["+Prefs.action_label("use_tool")+"] Revive teammate"
		else:
			near_teammate=true
	if near_teammate:
		if prompt_text!="":
			prompt_text+="  |  "
		prompt_text+="["+Prefs.action_label("feed")+"] Feed"
	if data.get("held", "")!="":
		prompt_text="CARRYING MERCHANDISE  |  %s Drop  |  %s Throw  |  %s Sell at the loading bay"%[
			Prefs.action_label("carry"),Prefs.action_label("attack"),Prefs.action_label("use_tool")]
	carry_clock+=delta
	if carry_clock>.1:
		carry_clock=0
		if multiplayer.is_server(): carry_aim(aim_direction())
		else: carry_aim.rpc_id(1,aim_direction())
	tool_icon.texture=ItemDatabase.art_icon(ART_INDEX.get(data.get("tool","grapple"),4))
	tool_icon.visible=not shop_open
	render_hazards()
	render_cameras()
	var riding: String=data.get("vehicle","")
	if riding!="" and vehicles.has(riding):
		# Seat the rider on the rig's DriverMarker (cart pushes from behind,
		# truck cab, racecar cockpit) instead of a fixed +1m offset.
		player.global_position=vehicles[riding].rig.driver_marker.global_position
		player.velocity=Vector3.ZERO
		prompt_text="%s%s%s%s Drive   |   %s Dismount   |   Drive to the loading bay to unload"%[
			Prefs.action_label("move_forward"),Prefs.action_label("move_backward"),
			Prefs.action_label("move_left"),Prefs.action_label("move_right"),
			Prefs.action_label("use_tool")]
		vehicle_clock+=delta
		if vehicle_clock>.1 and not level.is_camera_input_blocked():
			vehicle_clock=0
			var direction := aim_direction()
			var movement := Input.get_vector("move_left","move_right","move_forward","move_backward")
			if multiplayer.is_server():
				drive(movement,direction)
			else:
				drive.rpc_id(1,movement,direction)
	else:
		for kind in vehicles:
			if kind in campaign.gear and vehicles[kind].node.global_position.distance_to(player.global_position)<3:
				prompt_text="["+Prefs.action_label("use_tool")+"] Drive "+TOOL_NAMES[kind]
	if float(data.get("hp",100))<=0:
		prompt_text="DOWNED - teammates can revive you. Rescue in %ds."%maxi(0,30-int(data.get("down_time",0)))
	# Diff-guarded assignment: the prompt label only rebuilds when its
	# content actually changed.
	_set_text(prompt,"prompt",prompt_text)
	# The pill only exists while it says something; otherwise a tiny dim hint.
	var has_message := prompt_text!=""
	controls_hint.visible=prompt.visible and not has_message
	prompt_frame.visible=prompt.visible and (has_message or controls_hint.visible)
	if shop_open:
		update_shop_header()

## Diff-guarded text assign: labels only rebuild when their content changes.
func _set_text(label: Label,key: String,value: String) -> void:
	if _text_cache.get(key,"")!=value:
		_text_cache[key]=value
		label.text=value

## Local HUD widget refresh - every input comes from already-synced state.
func _update_widgets(data: Dictionary,task: String) -> void:
	var hp := clampf(float(data.get("hp",100.0))/100.0,0.0,1.0)
	hp_bar.value=hp
	hp_fill.bg_color=Palette.color(Palette.UI.good).lerp(Palette.color(Palette.UI.bad),1.0-hp)
	var fuel := clampf(float(data.get("fuel",100.0))/100.0,0.0,1.0)
	fuel_bar.value=fuel
	fuel_fill.bg_color=Palette.color(Palette.UI.info).lerp(Palette.color(Palette.UI.bad),.6 if fuel<.35 else 0.0)
	var alarm_ratio := clampf(alarm/100.0,0.0,1.0)
	alarm_bar.value=alarm_ratio
	alarm_fill.bg_color=Palette.color(Palette.UI.warn).lerp(Palette.color(Palette.UI.bad),alarm_ratio)
	alarm_frame.modulate=Color(1,1,1,.78+.22*sin(Time.get_ticks_msec()*.012)) if alarm>65 else Color.WHITE
	_set_text(task_label,"task",task)
	_set_text(cash_label,"cash","$%d   BANK $%d"%[int(campaign.cash),int(campaign.bank)])
	var form_text := str(data.get("form","slime")).to_upper()
	var cooldown := ceili(float(data.get("form_cooldown",0)))
	if cooldown>0:
		form_text+="  ·  %ds"%cooldown
	_set_text(form_label,"form",form_text)
	_set_text(tool_label,"tool",TOOL_NAMES.get(data.get("tool","grapple"),""))
	var boss: Node3D=active_boss()
	boss_frame.visible=boss!=null
	if boss:
		boss_bar.value=clampf(boss.hp/boss.max_hp,0.0,1.0)
		_set_text(boss_label,"boss_name",["THE BIG CHEESE","FOREMAN TUSK","MADAM MAGPIE","MECHA DRAGON"][boss.tier])

## The nearest aggro boss within display range, scanned from cached enemies.
func active_boss() -> Node3D:
	var player := local_player()
	if not player:
		return null
	for enemy in enemies:
		if enemy.boss and enemy.hp>0.0 and enemy.state!="PATROL" \
				and enemy.global_position.distance_to(player.global_position)<32.0:
			return enemy
	return null

func aim_direction() -> Vector3:
	var player := local_player()
	if not player:
		return Vector3.FORWARD
	return -player.get_node("SpringArmOffset/SpringArm3D/Camera3D").global_basis.z

func submit(action: String, argument: String="") -> void:
	if multiplayer.is_server():
		request_action(action,argument,aim_direction())
	else:
		request_action.rpc_id(1,action,argument,aim_direction())

func _unhandled_input(event: InputEvent) -> void:
	if not local_player() or get_tree().current_scene.main_menu.is_menu_visible():
		return
	if event.is_action_pressed("pause") and shop_open:
		close_shop()
		get_viewport().set_input_as_handled()
		return
	if get_tree().current_scene.is_camera_input_blocked():
		return
	if event is InputEventMouseButton and event.pressed:
		if event.is_action_pressed("attack"):
			submit("attack")
		elif event.is_action_pressed("tool_use"):
			submit("tool")
	if event is InputEventKey and event.pressed and not event.echo:
		if event.is_action_pressed("use_tool"):
			if nearest and str(nearest.name)=="Trader":
				open_shop()
			else:
				submit("interact",str(nearest.name) if nearest else "")
		elif event.is_action_pressed("cycle_tool"): submit("cycle")
		elif event.is_action_pressed("carry"): submit("carry")
		elif event.is_action_pressed("bait"): submit("bait")
		elif event.is_action_pressed("eat"): submit("eat")
		elif event.is_action_pressed("feed"): submit("feed")
		elif event.is_action_pressed("transform"): submit("transform")
		elif event.is_action_pressed("slime"): submit("slime")

@rpc("any_peer","call_local","reliable")
func request_action(action: String,argument: String,direction: Vector3) -> void:
	if not multiplayer.is_server() or not session_active:
		return
	var id := multiplayer.get_remote_sender_id()
	if id==0: id=1
	var player := player_for(id)
	if not player or not direction.is_finite() or direction.length_squared()<.5 or direction.length_squared()>1.5:
		return
	direction=direction.normalized()
	var data := ensure_player(id)
	if float(data.hp)<=0:
		return
	var now := Time.get_ticks_msec()
	var key := str(id)+action
	var cooldown := 550 if action=="attack" else (350 if action=="tool" else 250)
	if now-int(action_times.get(key,-10000))<cooldown:
		return
	action_times[key]=now
	if action in ["attack","tool","carry","interact","feed"]:
		data.gesture=action
		data.gesture_time=.45
	match action:
		"attack": melee(player,direction)
		"carry": toggle_cargo(player,direction)
		"tool": use_tool(player,direction)
		"interact": interact(player,argument)
		"shop": shop_action(player,argument)
		"cycle":
			# Q only ever lands on an owned ACTIVE TOOL. Vehicles stay parked
			# until someone sits down, and an unknown tool falls back to the
			# first owned one.
			var owned: Array=campaign.gear.filter(func(kind): return kind in ACTIVE_TOOLS)
			if owned.is_empty():
				owned=["grapple"]
			if data.tool in owned:
				data.tool=owned[(owned.find(data.tool)+1)%owned.size()]
			else:
				data.tool=owned[0]
		"bait":
			if consume(player,"rotten_cheese"):
				var pos := player.global_position+Vector3(direction.x,0,direction.z)*3
				bait.append({"position":pos,"time":18.0})
				fx.rpc(pos+Vector3.UP*.3,Color("b7d85b"),.5)
				for enemy in enemies:
					if enemy.tier==0 and enemy.global_position.distance_to(pos)<8:
						enemy.bribe_time=8
				alarm=maxf(0,alarm-15)
		"eat":
			if consume(player,"rotten_cheese"):
				data.speed_buff=20.0
				notice.rpc("Rotten cheese: speed and scent for 20 seconds.")
			elif consume(player,"moonshine"):
				data.strength_buff=20.0
				data.fuel=minf(100,float(data.fuel)+40)
				notice.rpc("Moonshine: stronger slaps, unsteady aim, jetpack refueled.")
			elif consume(player,"canned_food"):
				data.hp=minf(100,float(data.hp)+30)
		"feed": feed_player(player,direction)
		"transform":
			if campaign.forms.is_empty():
				notice.rpc("Bosses can drop rare transformations. Revisit their stores.")
			elif float(data.form_cooldown)<=0:
				var index: int=campaign.forms.find(data.get("last_form", ""))
				data.form=campaign.forms[(index+1)%campaign.forms.size()]
				data.last_form=data.form
				data.form_cooldown=120.0
				fx.rpc(player.global_position,Color("a9df9f"),1.0)
				play_sound.rpc("transform",player.global_position+Vector3.UP)
		"slime": data.form="slime"
	broadcast_state()

func consume(player: CharacterBody3D,item_id: String) -> bool:
	if player.player_inventory and player.player_inventory.remove_item(item_id,1)>0:
		player._sync_inventory_to_owner()
		return true
	return false

func feed_player(player: CharacterBody3D,direction: Vector3) -> void:
	# Hand the best food for a teammate's state to the nearest one in front of you.
	var target: Node3D=null
	var best := 3.5
	for other in live_players():
		if other==player:
			continue
		var offset: Vector3=other.global_position-player.global_position
		if offset.length()<best and offset.normalized().dot(direction)>0:
			target=other
			best=offset.length()
	if not target:
		return
	var target_state := ensure_player(int(str(target.name)))
	var order: Array=["rotten_cheese","moonshine"]
	if float(target_state.hp)<100.0:
		order.push_front("canned_food")
	for item_id in order:
		if not consume(player,item_id):
			continue
		match item_id:
			"canned_food":
				target_state.hp=minf(100.0,float(target_state.hp)+30)
			"rotten_cheese":
				target_state.speed_buff=20.0
			"moonshine":
				target_state.strength_buff=20.0
				target_state.fuel=minf(100.0,float(target_state.fuel)+40)
		var feeder: String=Network.players.get(int(str(player.name)),{}).get("nick","A slime")
		var fed: String=Network.players.get(int(str(target.name)),{}).get("nick","a teammate")
		notice.rpc("%s fed %s the %s."%[feeder,fed,ItemDatabase.get_item(item_id).name])
		fx.rpc(target.global_position+Vector3.UP,Color("b9e597"),.8)
		play_sound.rpc("heal",target.global_position+Vector3.UP)
		return

func melee(player: CharacterBody3D,direction: Vector3) -> void:
	if player_state[str(player.name)].get("held", "")!="":
		release_cargo(int(str(player.name)),direction*15+Vector3.UP*2)
		return
	var data: Dictionary=player_state[str(player.name)]
	for camera in cameras:
		if not camera.disabled and player.global_position.distance_to(camera.position)<5 and (camera.position-player.global_position).normalized().dot(direction)>.1:
			camera.disabled=true
			fx.rpc(camera.position,Color("b7dfed"),.7)
			notice.rpc("Security camera disabled.")
	var damage := 25.0 * (1.8 if float(data.strength_buff)>0 else 1.0)
	if data.form=="boar": damage*=1.5
	damage*=1+int(campaign.upgrades.get(data.form,0))*.15
	for enemy in enemies:
		var offset: Vector3=enemy.global_position-player.global_position
		if enemy.hp>0 and offset.length()<4.3 and offset.normalized().dot(direction)>.05 and clear_line(player.global_position+Vector3.UP,enemy.global_position+Vector3.UP):
			enemy.take_damage(damage)
			# Boss hits read heavier than guard hits; wall impacts stay the
			# strongest pop in the game.
			fx.rpc(enemy.global_position+Vector3.UP,Color("f2d9a1"),1.1 if enemy.boss else .4)
	play_sound.rpc("slap",player.global_position+Vector3.UP)
	# Fire-breathing lizard form and ignitable spilled spirits.
	if data.form=="lizard":
		fire_breath(player.global_position,Vector3(direction.x,0,direction.z).normalized(),str(player.name))

func interact(player: CharacterBody3D,marker_name: String) -> void:
	var id := int(str(player.name))
	var data: Dictionary=player_state[str(id)]
	if data.vehicle!="":
		var kind: String=data.vehicle
		vehicles[kind].rider=0
		data.vehicle=""
		send_travel(id,vehicles[kind].node.global_position+Vector3(2,1,0))
		return
	for other_key in player_state:
		var other := player_for(int(other_key))
		if other and other!=player and float(player_state[other_key].hp)<=0 and player.global_position.distance_to(other.global_position)<3:
			revive(int(other_key),40)
			play_sound.rpc("heal",other.global_position)
			return
	for kind in vehicles:
		if kind in campaign.gear and vehicles[kind].rider==0 and vehicles[kind].node.global_position.distance_to(player.global_position)<3:
			vehicles[kind].rider=id
			data.vehicle=kind
			return
	var marker: Marker3D=null
	for candidate in $Interactions.get_children():
		if str(candidate.name)==marker_name:
			marker=candidate
	if not marker or player.global_position.distance_to(marker.global_position)>4:
		return
	if marker.has_meta("destination"):
		if marker_name.begins_with("RatTunnel") and data.form!="rat":
			notice.rpc("Only rat form fits through this shortcut.")
			return
		send_travel(id,marker.get_meta("destination"))
	elif marker_name=="Extract":
		sell_loot(player)
	elif marker_name=="CollectIncome":
		campaign.cash+=int(campaign.bank)
		campaign.bank-=int(campaign.bank)
		play_sound.rpc("cash",marker.global_position+Vector3.UP)
		fx.rpc(marker.global_position+Vector3.UP,Color("ffd27a"),1.0)
		save_campaign()
	elif marker_name.begins_with("Valve"):
		var index := marker_name.trim_prefix("Valve").to_int()
		if index>=0 and index<3 and (sabotage & (1<<index))==0:
			sabotage|=1<<index
			for enemy in enemies:
				if enemy.boss and enemy.tier==0:
					enemy.take_damage(65)
					enemy.state="STUNNED"
					enemy.timer=4.0
			fire_breath(marker.global_position,Vector3.FORWARD)
			notice.rpc("Distillery sabotaged! The chef loses 65 health. Watch the burning spill.")
	elif marker_name=="Replay":
		for other in live_players():
			if store_tier(other.global_position)>=0:
				notice.rpc("Gather the entire crew outside the stores before restocking.")
				return
		reset_heists()
	elif marker_name=="Recipe":
		notice.rpc("Defeat the chef to recover and upgrade this recipe.")

func sell_loot(player: CharacterBody3D) -> void:
	release_cargo(int(str(player.name)),Vector3.ZERO)
	var earned := 0
	for item_id in GOODS:
		var quantity: int=player.player_inventory.remove_item(item_id,9999)
		earned+=quantity*ItemDatabase.get_item(item_id).value
	for item in get_node("../ItemContainer").get_children():
		if item.item_id in GOODS and item.global_position.distance_to(Vector3(9,1,-12))<7:
			earned+=ItemDatabase.get_item(item.item_id).value
			item.queue_free()
	campaign.cash+=earned
	player._sync_inventory_to_owner()
	notice.rpc("Loot delivered: $%d added to crew funds."%earned)
	play_sound.rpc("cash",player.global_position+Vector3.UP*1.5)
	fx.rpc(player.global_position+Vector3.UP*1.5,Color("ffd27a"),1.4)
	save_campaign()

func reset_heists() -> void:
	for enemy in enemies:
		enemy.hp=enemy.max_hp
		enemy.position=enemy.home
		enemy.target_position=enemy.home
		enemy.state="PATROL"
		enemy.bribe_time=0
	for item in get_node("../ItemContainer").get_children():
		if item.item_id in GOODS:
			item.queue_free()
	stock_spawned=false
	defeated=[false,false,false,false]
	sabotage=0
	alarm=0
	bait.clear()
	fires.clear()
	call_deferred("_stock_store")
	notice.rpc("Stores restocked. Bosses return with fresh blueprint upgrades and rare drops.")

# Compatibility entry points for scene interactions and test tooling.
@rpc("any_peer","call_local","reliable")
func request_interaction(marker_name: String) -> void:
	if not multiplayer.is_server(): return
	var id := multiplayer.get_remote_sender_id()
	if id==0: id=1
	var player := player_for(id)
	if player and float(ensure_player(id).hp)>0:
		var now := Time.get_ticks_msec()
		if now-int(request_times.get(id,-1000))<400: return
		request_times[id]=now
		interact(player,marker_name)

@rpc("authority","call_local","reliable")
func travel(id: int,destination: Vector3) -> void:
	var player := player_for(id)
	if player:
		player.global_position=destination
		player.velocity=Vector3.ZERO

@rpc("authority","call_local","reliable")
func impulse_player(id: int,impulse: Vector3) -> void:
	var player := player_for(id)
	if player and player.is_multiplayer_authority():
		player.apply_external_impulse(impulse)

@rpc("authority","call_local","reliable")
func apply_progress(recovered: bool) -> void:
	recipe_recovered=recovered
	$Road/Gate.visible=not recovered
	for shape in $Road/Gate.find_children("*","CollisionShape3D",true,false):
		shape.set_deferred("disabled",recovered)
	$Hideout/Blueprint.visible=recovered
	$RatStore/RecipeDisplay.visible=not recovered
	for tier in range(1,4):
		var door := get_node_or_null("Expansion/Store%d/Lock"%tier)
		if door:
			var locked := int(campaign.recipes[tier-1])==0
			door.visible=locked
			for shape in door.find_children("*","CollisionShape3D",true,false):
				shape.set_deferred("disabled",not locked)

func use_tool(player: CharacterBody3D,direction: Vector3) -> void:
	var id := int(str(player.name))
	var data: Dictionary=player_state[str(id)]
	var tool: String=data.tool
	if tool not in campaign.gear:
		return
	if float(data.strength_buff)>0:
		direction=(direction+Vector3(randf_range(-.16,.16),0,randf_range(-.16,.16))).normalized()
	match tool:
		"grapple":
			if float(data.grapple_cd)>0: return
			data.grapple_cd=1.2
			var origin := player.global_position+Vector3.UP*1.3
			# The launch and the connection are two distinct events: the zip
			# fires from the hook, the clink lands where the hook lands.
			play_sound.rpc("grapple",origin)
			var query := PhysicsRayQueryParameters3D.create(origin,origin+direction*28,31,[player.get_rid()])
			var hit := get_world_3d().direct_space_state.intersect_ray(query)
			if hit.is_empty(): return
			beam.rpc(origin,hit.position,Color("d3c493"))
			play_sound.rpc("grapple_hit",hit.position)
			var object = hit.collider
			if object is RigidBody3D:
				object.apply_central_impulse((origin-object.global_position).normalized()*object.mass*12)
			elif object is CharacterBody3D and object.get_parent()==player.get_parent():
				impulse_player.rpc(int(str(object.name)),(origin-object.global_position).normalized()*12+Vector3.UP*3)
			else:
				# Static pull scales with distance and target height: level
				# shots are mostly planar, high shots add vertical assist,
				# low shots barely hop. Bounded by the player-side external
				# cap either way, held keys or not.
				var to_target: Vector3=hit.position-player.global_position
				var flat := Vector2(to_target.x,to_target.z)
				var planar := flat.normalized()*clampf(flat.length()*.85,6.0,13.0)
				var vertical := clampf(to_target.y*.55,1.2,6.5)
				impulse_player.rpc(id,Vector3(planar.x,vertical,planar.y))
		"water":
			play_sound.rpc("water",player.global_position+Vector3.UP+direction*2)
			for camera in cameras:
				if camera.position.distance_to(player.global_position+direction*8)<5:
					camera.disabled=true
			beam.rpc(player.global_position+Vector3.UP,player.global_position+Vector3.UP+direction*15,Color("7acde8"))
			fx.rpc(player.global_position+Vector3.UP+direction*7,Color("7acde8"),.8)
			for other in live_players():
				if other==player: continue
				var offset: Vector3=other.global_position-player.global_position
				if offset.length()<15 and offset.normalized().dot(direction)>.88 and clear_line(player.global_position+Vector3.UP,other.global_position+Vector3.UP):
					var target: Dictionary=player_state[str(other.name)]
					target.hp=minf(100,float(target.hp)+14)
			for i in range(fires.size()-1,-1,-1):
				if fires[i].position.distance_to(player.global_position+direction*5)<9:
					fires.remove_at(i)
			for enemy in enemies:
				var offset: Vector3=enemy.global_position-player.global_position
				if offset.length()<12 and offset.normalized().dot(direction)>.9:
					enemy.state="STUNNED"
					enemy.timer=.6
		"crystal":
			if int(campaign.crystals)<=0:
				notice.rpc("No slime crystals left. Buy one from the trader.")
				return
			for key in player_state:
				var other := player_for(int(key))
				if other and other!=player and float(player_state[key].hp)<=0 and other.global_position.distance_to(player.global_position)<12:
					campaign.crystals-=1
					revive(int(key),100)
					fx.rpc(other.global_position,Color("acd9ff"),1.5)
					play_sound.rpc("crystal",other.global_position)
					save_campaign()
					return
		"jetpack":
			if float(data.fuel)>=12:
				data.fuel-=12
				impulse_player.rpc(id,Vector3(direction.x*5,10,direction.z*5))
				fx.rpc(player.global_position,Color("ffb66e"),.4)
		_:
			notice.rpc("Your vehicle is parked on the road. Press F beside it to drive.")

func build_vehicles() -> void:
	for i in range(3):
		var kind: String=["cart","truck","racecar"][i]
		var profile: Dictionary=VehicleProfiles.profile(kind)
		var body := RigidBody3D.new()
		body.name=kind.capitalize()
		body.mass=profile.mass
		body.collision_layer=16
		body.collision_mask=6
		body.lock_rotation=true
		body.linear_damp=.5
		# Arcade grip: acceleration/braking/coast/lateral-grip all live in the
		# profile, so the contact solver must not fight the drive with default
		# friction (mu=1 would cancel most of the truck's 10 m/s^2).
		var slick := PhysicsMaterial.new()
		slick.friction=.05
		slick.bounce=0.0
		body.physics_material_override=slick
		body.position=Vector3(-8+i*6,1,12)
		add_child(body)
		var size: Vector3=[Vector3(1.6,.5,2.3),Vector3(2.5,1.1,4),Vector3(1.5,.6,2.5)][i]
		var shape := BoxShape3D.new()
		shape.size=size
		var collision := CollisionShape3D.new()
		collision.shape=shape
		body.add_child(collision)
		# Chamfered nose: a rotated box across the front lower edge turns sharp
		# wall/curb catches into slides. Vehicle-only - never touches the world.
		var chamfer := CollisionShape3D.new()
		var chamfer_shape := BoxShape3D.new()
		chamfer_shape.size=Vector3(size.x*.85,maxf(.3,size.y*.8),.55)
		chamfer.shape=chamfer_shape
		chamfer.position=Vector3(0,size.y*.1,-size.z*.48)
		chamfer.rotation.x=-PI*.25
		body.add_child(chamfer)
		# Cargo walls make carts/trucks carry actual rigid merchandise.
		if kind!="racecar":
			for x in [-size.x*.5,size.x*.5]:
				var side := CollisionShape3D.new()
				var side_shape := BoxShape3D.new()
				side_shape.size=Vector3(.12,.7,size.z)
				side.shape=side_shape
				side.position=Vector3(x,.5,0)
				body.add_child(side)
		# Authored visual rig: chunky body, sprung wheels, driver marker.
		# The gameplay root above stays the single authoritative body.
		var rig: VehicleRig=VehicleRig.create(kind)
		body.add_child(rig)
		vehicles[kind]={"node":body,"home":body.position,"rider":0,"rig":rig,
			"half":size*.5,"ram_clock":{},"load":0.0,"hop_clock":-10.0}
		body.hide()
		body.freeze=true

@rpc("any_peer","call_local","unreliable_ordered")
func drive(movement: Vector2,direction: Vector3) -> void:
	if not multiplayer.is_server() or not movement.is_finite() or not direction.is_finite(): return
	var id := multiplayer.get_remote_sender_id()
	if id==0: id=1
	if not player_state.has(str(id)): return
	var kind: String=player_state[str(id)].vehicle
	if not vehicles.has(kind) or vehicles[kind].rider!=id: return
	vehicle_inputs[kind]={"movement":movement.limit_length(),"direction":direction.normalized(),"time":game_clock}

## Arcade driving: decompose velocity into forward/lateral against the body's
## own yaw, throttle drives forward speed (accel/brake-then-reverse/coast),
## lateral grip scrubs sideways slide, and steering yaws at a rate that falls
## off with speed. Yaw is integrated, never snapped.
func update_vehicles(delta: float) -> void:
	for kind in vehicles:
		var record: Dictionary=vehicles[kind]
		var body: RigidBody3D=record.node
		var profile: Dictionary=VehicleProfiles.profile(kind)
		var enabled: bool=kind in campaign.gear
		body.visible=enabled
		body.freeze=not enabled
		if not enabled: continue
		var input: Dictionary=vehicle_inputs.get(kind,{})
		var movement := Vector2.ZERO
		if record.rider>0 and game_clock-float(input.get("time",-10))<.5:
			movement=input.get("movement",Vector2.ZERO)
		var yaw: float=body.rotation.y
		var forward := Vector3(-sin(yaw),0,-cos(yaw))
		var right := Vector3(cos(yaw),0,-sin(yaw))
		var v_fwd: float=body.linear_velocity.dot(forward)
		var v_lat: float=body.linear_velocity.dot(right)
		var throttle: float=-movement.y
		# Cheap cargo load estimate feeds the profile's penalties. Refreshed at
		# 8 Hz instead of every physics frame: a slow scan is indistinguishable
		# from a per-frame one for a box that changes when items are dropped in.
		if game_clock-float(record.get("load_clock",-10.0))>=.125:
			record.load_clock=game_clock
			record.load=_vehicle_load(kind,body,record.half)
		var accel: float=profile.acceleration*lerpf(1.0,profile.cargo_acceleration_penalty,record.load)
		var top_speed: float=profile.max_forward_speed*lerpf(1.0,profile.cargo_speed_penalty,record.load)
		if throttle>.05:
			v_fwd=move_toward(v_fwd,top_speed,accel*delta)
		elif throttle<-.05:
			if v_fwd>.4:
				v_fwd=move_toward(v_fwd,0.0,profile.braking_deceleration*delta)
			else:
				v_fwd=move_toward(v_fwd,-profile.max_reverse_speed,accel*.7*delta)
		else:
			v_fwd=move_toward(v_fwd,0.0,profile.coast_deceleration*delta)
		v_lat=move_toward(v_lat,0.0,profile.lateral_grip*delta)
		# Speed-dependent steering: full rate at low speed, tapered at the top.
		var speed01: float=clampf(absf(v_fwd)/maxf(1.0,profile.max_forward_speed),0.0,1.0)
		var rate: float=profile.steering_rate*lerpf(1.0,profile.high_speed_steering_multiplier,speed01*speed01)
		# No steering authority at a standstill; reversing flips the turn.
		var authority: float=clampf(v_fwd/2.5,-1.0,1.0)
		body.rotation.y=yaw-movement.x*rate*delta*authority
		body.linear_velocity=forward*v_fwd+right*v_lat+Vector3(0,body.linear_velocity.y,0)
		if record.rider>0 and throttle>.1 and v_fwd>0.0:
			_vehicle_curb_assist(kind,record,body,profile,forward,delta)
		if body.position.y < -5:
			body.position=record.home
			body.linear_velocity=Vector3.ZERO
		_ram_impacts(kind,record,body,profile)

## Curb assist, server-authoritative. Two forward probes at the vehicle's nose:
## the low probe finds an obstacle, the high probe (just above the profile's
## step_height) must stay clear - walls, gates and shelves block it and are
## never climbed. Grounded vehicles only; the hop is a velocity, never a
## teleport, and it re-triggers on a short clock so it crests in one bounce.
func _vehicle_curb_assist(kind: String,record: Dictionary,body: RigidBody3D,profile: Dictionary,forward: Vector3,_delta: float) -> void:
	if game_clock-float(record.get("hop_clock",-10.0))<.35: return
	var half: Vector3=record.half
	var space: PhysicsDirectSpaceState3D=body.get_world_3d().direct_space_state
	var origin: Vector3=body.global_position
	var ground_y: float=origin.y-half.y
	# Grounded gate: no airborne assist. The ray must clear the body's own
	# half-height to actually reach the ground beneath it.
	var down := PhysicsRayQueryParameters3D.create(origin,origin+Vector3(0,-(half.y+.35),0),6,[body.get_rid()])
	if space.intersect_ray(down).is_empty(): return
	var nose := origin+forward*(half.z*.7)
	var low := PhysicsRayQueryParameters3D.create(
		Vector3(nose.x,ground_y+.15,nose.z),Vector3(nose.x,ground_y+.15,nose.z)+forward*.85,6,[body.get_rid()])
	if space.intersect_ray(low).is_empty(): return
	var high_y: float=ground_y+profile.step_height+.06
	var high := PhysicsRayQueryParameters3D.create(
		Vector3(nose.x,high_y,nose.z),Vector3(nose.x,high_y,nose.z)+forward*.95,6,[body.get_rid()])
	if not space.intersect_ray(high).is_empty(): return
	record.hop_clock=game_clock
	var hop: float=clampf(sqrt(2.0*9.8*(profile.step_height+.18))*1.05,2.2,5.2)
	body.linear_velocity.y=maxf(body.linear_velocity.y,hop)
	body.linear_velocity+=forward*.8

## Ram impacts are discrete events with per-enemy cooldowns, replacing the old
## continuous while-overlapping damage that let a parked car grind a boss down.
## A hit is geometry plus closing speed: the enemy must sit inside the
## vehicle's forward box (from just behind the nose to a bumper-reach ahead,
## laterally inside the body width) AND the vehicle must actually be moving
## toward it along its own forward axis. Sideways scrapes, reverse nudges and
## a long nose merely approaching someone never count.
func _ram_impacts(kind: String,record: Dictionary,body: RigidBody3D,profile: Dictionary) -> void:
	if record.rider<=0: return
	var yaw: float=body.rotation.y
	var forward := Vector3(-sin(yaw),0,-cos(yaw))
	# Closing speed along the vehicle's own forward axis, not planar magnitude.
	var closing: float=body.linear_velocity.dot(forward)
	if closing<float(profile.ram_min_speed): return
	var half: Vector3=record.half
	var to_local: Transform3D=body.global_transform.affine_inverse()
	for enemy in enemies:
		if enemy.hp<=0: continue
		var local: Vector3=to_local*(enemy.global_position)
		if local.z>-(half.z-.3) or local.z<-(half.z+1.1): continue
		if absf(local.x)>half.x+.45: continue
		if local.y<-half.y or local.y>half.y+1.6: continue
		var key: int=enemy.get_instance_id()
		if game_clock-float(record.ram_clock.get(key,-10.0))<profile.ram_cooldown: continue
		record.ram_clock[key]=game_clock
		enemy.take_damage(profile.ram_strength*clampf(closing/(profile.max_forward_speed*2.0),.4,1.0))
		enemy.state="STUNNED"
		enemy.timer=1.0
		fx.rpc(body.global_position+Vector3(0,.5,0),Color("ffd27a"),.7)
		vehicle_impact.rpc(kind)

## Cheap cargo load: 0..1 from how much rigid merchandise sits in the cargo
## box. A handful of local bounds checks; no physics queries.
func _vehicle_load(kind: String,body: RigidBody3D,half: Vector3) -> float:
	if kind=="racecar": return 0.0
	var container := get_node_or_null("../ItemContainer")
	if container==null: return 0.0
	var to_local := body.global_transform.affine_inverse()
	var count := 0
	for item in container.get_children():
		if item is not RigidBody3D: continue
		var local: Vector3=to_local*(item.global_position)
		if absf(local.x)<half.x and absf(local.z)<half.z and local.y>-half.y and local.y<half.y+1.2:
			count+=1
	return clampf(count/6.0,0.0,1.0)

func shop_action(player: CharacterBody3D,action: String) -> void:
	if player.global_position.distance_to(Vector3(-10,-11,32))>7:
		return
	if action.begins_with("buy:"):
		var kind := action.trim_prefix("buy:")
		if not PRICES.has(kind): return
		if kind in campaign.gear and kind!="crystal": return
		if int(campaign.cash)<int(PRICES[kind]):
			notice.rpc("Not enough crew cash. Deliver loot or collect machine income.")
			return
		campaign.cash-=int(PRICES[kind])
		if kind not in campaign.gear: campaign.gear.append(kind)
		if kind=="crystal": campaign.crystals+=1
		# Buying an active tool equips it for the buyer alone. Vehicles change
		# nobody's tool - they sit in the fleet until someone drives them.
		if kind in ACTIVE_TOOLS:
			var key := str(player.name)
			if player_state.has(key):
				player_state[key].tool=kind
		play_sound.rpc("cash",player.global_position)
	elif action=="machine":
		var price: int=150*campaign.machines.size()
		if campaign.machines.size()<4 and int(campaign.cash)>=price:
			campaign.cash-=price
			campaign.machines.append(-1)
	elif action.begins_with("install:"):
		var parts := action.split(":")
		if parts.size()!=3: return
		var slot := parts[1].to_int()
		var recipe := parts[2].to_int()
		if slot>=0 and slot<campaign.machines.size() and recipe>=0 and recipe<4 and int(campaign.recipes[recipe])>0:
			campaign.machines[slot]=recipe
	elif action.begins_with("upgrade:"):
		var form := action.trim_prefix("upgrade:")
		if form not in campaign.forms: return
		var current := int(campaign.upgrades.get(form,0))
		var price := (current+1)*120
		if current<3 and int(campaign.cash)>=price:
			campaign.cash-=price
			campaign.upgrades[form]=current+1
	save_campaign()
	broadcast_state()

func build_ui() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer=4
	add_child(canvas)
	hud_root=Control.new()
	hud_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud_root.mouse_filter=Control.MOUSE_FILTER_IGNORE
	canvas.add_child(hud_root)
	# Tilted plum sign, top left: location line and the crooked task line.
	var sign := Widgets.frame("panel","panel_edge",12,-.03)
	sign.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	sign.offset_left=16
	sign.offset_top=12
	var sign_rows := Widgets.rows(2)
	hud=Widgets.label(17,"text")
	sign_rows.add_child(hud)
	task_label=Widgets.label(12,"warn")
	sign_rows.add_child(task_label)
	sign.add_child(sign_rows)
	hud_root.add_child(sign)
	# Alarm meter, top center - pulses when the crew draws heat.
	alarm_frame=Widgets.frame("panel","panel_edge",10)
	alarm_frame.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	alarm_frame.offset_left=-105
	alarm_frame.offset_right=105
	alarm_frame.offset_top=12
	alarm_frame.offset_bottom=48
	var alarm_rows := Widgets.rows(2)
	var alarm_title := Widgets.label(11,"text_dim")
	alarm_title.text="ALARM"
	alarm_title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	alarm_rows.add_child(alarm_title)
	alarm_bar=Widgets.bar(176,9,"warn")
	alarm_fill=alarm_bar.get_theme_stylebox("fill") as StyleBoxFlat
	alarm_rows.add_child(alarm_bar)
	alarm_frame.add_child(alarm_rows)
	hud_root.add_child(alarm_frame)
	# Boss bar under the alarm meter; only visible while a boss fights.
	boss_frame=Widgets.frame("panel","boss",12)
	boss_frame.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	boss_frame.offset_left=-140
	boss_frame.offset_right=140
	boss_frame.offset_top=56
	boss_frame.offset_bottom=112
	var boss_rows := Widgets.rows(2)
	boss_label=Widgets.label(13,"boss")
	boss_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	boss_rows.add_child(boss_label)
	boss_bar=Widgets.bar(236,12,"bad")
	boss_rows.add_child(boss_bar)
	boss_frame.add_child(boss_rows)
	boss_frame.hide()
	hud_root.add_child(boss_frame)
	# Cash badge, top right, with the shared wallet and bank.
	var cash_frame := Widgets.frame("panel","panel_edge",12,.025)
	cash_frame.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	cash_frame.offset_left=-176
	cash_frame.offset_right=-16
	cash_frame.offset_top=12
	cash_frame.offset_bottom=50
	cash_label=Widgets.label(15,"gold")
	cash_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	cash_frame.add_child(cash_label)
	hud_root.add_child(cash_frame)
	# Tool icon in its own small frame under the cash badge.
	var tool_frame := Widgets.frame("panel","panel_edge",12,-.02)
	tool_frame.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	tool_frame.offset_left=-90
	tool_frame.offset_right=-24
	tool_frame.offset_top=58
	tool_frame.offset_bottom=124
	tool_icon=TextureRect.new()
	tool_icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	tool_icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tool_icon.mouse_filter=Control.MOUSE_FILTER_IGNORE
	tool_frame.add_child(tool_icon)
	hud_root.add_child(tool_frame)
	# Vitals, bottom left: hp, fuel, form and tool rows.
	var vitals := Widgets.frame("panel","panel_edge",12)
	vitals.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	vitals.offset_left=14
	vitals.offset_top=-112
	vitals.offset_right=196
	vitals.offset_bottom=-14
	var vitals_rows := Widgets.rows(3)
	var hp_title := Widgets.label(10,"text_dim")
	hp_title.text="HP"
	vitals_rows.add_child(hp_title)
	hp_bar=Widgets.bar(150,10,"good")
	hp_fill=hp_bar.get_theme_stylebox("fill") as StyleBoxFlat
	vitals_rows.add_child(hp_bar)
	var fuel_title := Widgets.label(10,"text_dim")
	fuel_title.text="FUEL"
	vitals_rows.add_child(fuel_title)
	fuel_bar=Widgets.bar(150,10,"info")
	fuel_fill=fuel_bar.get_theme_stylebox("fill") as StyleBoxFlat
	vitals_rows.add_child(fuel_bar)
	form_label=Widgets.label(12,"info")
	vitals_rows.add_child(form_label)
	tool_label=Widgets.label(11,"text_dim")
	vitals_rows.add_child(tool_label)
	vitals.add_child(vitals_rows)
	hud_root.add_child(vitals)
	# Prompt pill, bottom center, hugging its text; toast pill hugs its message.
	# Both live in wide CenterContainers so the panels never stretch to a fixed
	# size when there is nothing to say.
	var prompt_slot := CenterContainer.new()
	prompt_slot.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	prompt_slot.offset_top=-44
	prompt_slot.mouse_filter=Control.MOUSE_FILTER_IGNORE
	prompt_frame=Widgets.frame("panel","panel_edge",16,.012)
	var prompt_rows := Widgets.rows(0)
	prompt=Widgets.label(15,"text")
	prompt.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	prompt_rows.add_child(prompt)
	controls_hint=Widgets.label(11,"text_dim")
	controls_hint.text="Esc Menu"
	controls_hint.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	controls_hint.hide()
	prompt_rows.add_child(controls_hint)
	prompt_frame.add_child(prompt_rows)
	prompt_slot.add_child(prompt_frame)
	hud_root.add_child(prompt_slot)
	var toast_slot := CenterContainer.new()
	toast_slot.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	toast_slot.offset_top=122
	toast_slot.offset_bottom=172
	toast_slot.mouse_filter=Control.MOUSE_FILTER_IGNORE
	toast_frame=Widgets.frame("panel","panel_edge",16,-.012)
	toast=Widgets.label(16,"warn")
	toast.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	toast_frame.add_child(toast)
	toast_slot.add_child(toast_frame)
	hud_root.add_child(toast_slot)
	# The capture flow hides hud to screenshot clean scenes; hide the rest too.
	hud.visibility_changed.connect(func(): hud_root.visible=hud.visible)
	shop=PanelContainer.new()
	shop.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	shop.offset_left=-420
	shop.offset_right=420
	shop.offset_top=-290
	shop.offset_bottom=290
	var panel := StyleBoxFlat.new()
	panel.bg_color=Palette.color(Palette.UI.panel)
	panel.border_color=Palette.color(Palette.UI.panel_edge)
	panel.set_border_width_all(2)
	panel.set_corner_radius_all(12)
	panel.content_margin_left=18
	panel.content_margin_right=18
	panel.content_margin_top=14
	panel.content_margin_bottom=14
	shop.add_theme_stylebox_override("panel",panel)
	canvas.add_child(shop)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	shop.add_child(scroll)
	shop_rows=VBoxContainer.new()
	shop_rows.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	shop_rows.add_theme_constant_override("separation",10)
	scroll.add_child(shop_rows)
	shop.hide()

func open_shop() -> void:
	shop_open=true
	shop.show()
	for child in shop_rows.get_children():
		child.queue_free()
	var heading := Label.new()
	heading.name="Balance"
	heading.text="THE PARTNER  /  Crew outfitter"
	heading.add_theme_font_size_override("font_size",20)
	heading.add_theme_color_override("font_color",Palette.color(Palette.UI.gold))
	shop_rows.add_child(heading)
	for kind in PRICES:
		var button := Button.new()
		button.text="%s  /  $%d%s"%[TOOL_NAMES[kind],PRICES[kind],"  [OWNED]" if kind in campaign.gear and kind!="crystal" else ""]
		button.icon=ItemDatabase.art_icon(ART_INDEX[kind])
		button.add_theme_constant_override("icon_max_width",30)
		button.expand_icon=true
		button.custom_minimum_size.y=38
		button.disabled=kind in campaign.gear and kind!="crystal"
		_style_button(button)
		button.pressed.connect(func(): submit("shop","buy:"+kind); close_shop())
		shop_rows.add_child(button)
	var expansion := Button.new()
	expansion.text="Buy production slot  /  $%d  (%d/4)"%[150*campaign.machines.size(),campaign.machines.size()]
	expansion.disabled=campaign.machines.size()>=4
	_style_button(expansion)
	expansion.pressed.connect(func(): submit("shop","machine"); close_shop())
	shop_rows.add_child(expansion)
	for slot in campaign.machines.size():
		for tier in range(4):
			if int(campaign.recipes[tier])<=0: continue
			var button := Button.new()
			button.text="Slot %d: install %s recipe Lv.%d%s"%[slot+1,SPECIES[tier],campaign.recipes[tier]," [INSTALLED]" if int(campaign.machines[slot])==tier else ""]
			_style_button(button)
			button.pressed.connect(func(): submit("shop","install:%d:%d"%[slot,tier]); close_shop())
			shop_rows.add_child(button)
	for form in campaign.forms:
		var button := Button.new()
		var upgrade := int(campaign.upgrades.get(form,0))
		button.text="Upgrade %s form  /  Lv.%d  /  $%d"%[form,upgrade,(upgrade+1)*120]
		button.disabled=upgrade>=3
		_style_button(button)
		button.pressed.connect(func(): submit("shop","upgrade:"+form); close_shop())
		shop_rows.add_child(button)
	var close := Button.new()
	close.text="BACK TO THE CREW"
	_style_button(close)
	close.pressed.connect(close_shop)
	shop_rows.add_child(close)
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE

## Shop buttons wear the same plum-and-gold language as the HUD instead of the
## raw Godot theme.
func _style_button(button: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color=Color("342848")
	normal.border_color=Palette.color(Palette.UI.panel_edge)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(10)
	normal.content_margin_left=12
	normal.content_margin_right=12
	normal.content_margin_top=6
	normal.content_margin_bottom=7
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color=Color("43335c")
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color=Palette.color(Palette.UI.panel)
	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color=Color("241b30")
	disabled.border_color=Color("453a55")
	button.add_theme_stylebox_override("normal",normal)
	button.add_theme_stylebox_override("hover",hover)
	button.add_theme_stylebox_override("pressed",pressed)
	button.add_theme_stylebox_override("disabled",disabled)
	button.add_theme_stylebox_override("focus",StyleBoxEmpty.new())
	button.add_theme_color_override("font_color",Palette.color(Palette.UI.text))
	button.add_theme_color_override("font_hover_color",Palette.color(Palette.UI.gold))
	button.add_theme_color_override("font_pressed_color",Palette.color(Palette.UI.gold))
	button.add_theme_color_override("font_disabled_color",Color("8a7f95"))
	button.add_theme_font_size_override("font_size",15)
	button.alignment=HORIZONTAL_ALIGNMENT_LEFT

func update_shop_header() -> void:
	var heading := shop_rows.get_node_or_null("Balance") as Label
	if heading:
		heading.text="THE PARTNER  /  $%d crew funds\nCrystals: %d  |  Ready to collect: $%d"%[campaign.cash,campaign.crystals,int(campaign.bank)]

func close_shop() -> void:
	shop_open=false
	if shop: shop.hide()
	var level := get_tree().current_scene
	if level and level.has_method("_update_mouse_mode"):
		level._update_mouse_mode()

@rpc("any_peer","reliable")
func request_progress() -> void:
	if multiplayer.is_server():
		sync_full_state.rpc_id(multiplayer.get_remote_sender_id(),snapshot())

func snapshot() -> Dictionary:
	var guards: Array=[]
	for enemy in enemies:
		guards.append([enemy.position,enemy.hp,enemy.state,enemy.model.rotation.y])
	var cars: Dictionary={}
	for kind in vehicles:
		cars[kind]=[vehicles[kind].node.position,vehicles[kind].node.rotation.y,vehicles[kind].rider]
	return {"campaign":campaign,"players":player_state,"alarm":alarm,"guards":guards,"cars":cars,"sabotage":sabotage,"defeated":defeated,"fires":fires,"bait":bait,"cameras":cameras.map(func(c): return c.disabled)}

func broadcast_state() -> void:
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		sync_state.rpc(var_to_bytes(snapshot()).compress(FileAccess.COMPRESSION_DEFLATE))

@rpc("authority","unreliable_ordered")
func sync_state(data: PackedByteArray) -> void:
	var decoded = bytes_to_var(data.decompress_dynamic(1048576,FileAccess.COMPRESSION_DEFLATE))
	if decoded is Dictionary:
		apply_snapshot(decoded)

@rpc("authority","reliable")
func sync_full_state(data: Dictionary) -> void:
	apply_snapshot(data)

func apply_snapshot(data: Dictionary) -> void:
	campaign=data.campaign
	player_state=data.players
	alarm=data.alarm
	sabotage=data.sabotage
	defeated=data.defeated
	fires=data.get("fires",[])
	bait=data.get("bait",[])
	for i in mini(cameras.size(),data.get("cameras",[]).size()):
		cameras[i].disabled=data.cameras[i]
	for i in mini(enemies.size(),data.guards.size()):
		enemies[i].target_position=data.guards[i][0]
		enemies[i].hp=data.guards[i][1]
		enemies[i].state=data.guards[i][2]
		enemies[i].model.rotation.y=data.guards[i][3]
	for kind in data.cars:
		var body: RigidBody3D=vehicles[kind].node
		body.freeze=true
		body.visible=kind in campaign.gear
		vehicles[kind].rider=data.cars[kind][2]
		vehicles[kind].rig.net_update(data.cars[kind][0],data.cars[kind][1])
	apply_progress(int(campaign.recipes[0])>0)
	update_machines()

func update_machines() -> void:
	for i in range(3):
		var label := get_node_or_null("Hideout/MachineLabel%d"%i) as Label3D
		if label:
			if i<campaign.machines.size():
				var tier := int(campaign.machines[i])
				label.text="SLOT %d / %s"%[i+1,("%s Lv.%d"%[SPECIES[tier].to_upper(),campaign.recipes[tier]]) if tier>=0 else "EMPTY"]
			else:
				label.text="SLOT %d / BUY FROM TRADER"%(i+1)
	for i in machine_visuals.size():
		var installed: bool=i<campaign.machines.size() and int(campaign.machines[i])>=0
		machine_visuals[i].visible=installed
		if installed:
			var recipe := int(campaign.machines[i])
			var level := int(campaign.recipes[recipe])
			machine_visuals[i].scale=Vector3.ONE*(1.0+minf(.8,level*.12))
	var machine := get_node_or_null("Hideout/StarterMachine") as Node3D
	if machine:
		machine.scale=Vector3.ONE*(1.0+minf(1.0,int(campaign.recipes[0])*.12))


## Local spin for the production machines, run every frame from each peer's
## own clock: the networked state only carries installed/recipe/level, so the
## output wheel glides between snapshots instead of freezing and jumping.
func _animate_machines(delta: float) -> void:
	for i in machine_visuals.size():
		if i>=campaign.machines.size() or int(campaign.machines[i])<0:
			continue
		var recipe := int(campaign.machines[i])
		var level := int(campaign.recipes[recipe]) if recipe<campaign.recipes.size() else 0
		machine_visuals[i].get_node("Output").rotation.y+=delta*(1.0+level)

@rpc("authority","call_local","reliable")
func notice(message: String) -> void:
	toast.text=message
	toast_clock=5.0

var fx_live: Array[Node]=[]

@rpc("authority","call_local","unreliable")
func fx(point: Vector3,color: Color,size: float) -> void:
	if DisplayServer.get_name()=="headless": return
	# Elastic pop presentation (geometry caches, cap, tween) lives in WorldFx.
	WorldFx.pop(self,fx_live,point,color,size)

@rpc("authority","call_local","unreliable")
func beam(from: Vector3,to: Vector3,color: Color) -> void:
	if DisplayServer.get_name()=="headless": return
	WorldFx.beam(self,fx_live,from,to,color)
@rpc("authority","call_local","unreliable")
func play_sound(kind: String, at := Vector3.INF) -> void:
	## UI/global one-shots stay 2D; events that know where they happened pass
	## `at` and play spatially. Synthesis and node classes live in GameAudio.
	GameAudio.play(self,kind,at)

@rpc("authority","call_local","unreliable")
func vehicle_impact(kind: String) -> void:
	## Ram crash, fired through each peer's own rig ImpactAudio hook so the
	## sound sits at the vehicle as it keeps moving.
	if vehicles.has(kind):
		vehicles[kind].rig.play_impact()

@rpc("any_peer","call_local","unreliable_ordered")
func carry_aim(direction: Vector3) -> void:
	if not multiplayer.is_server() or not direction.is_finite() or direction.length_squared()<.5 or direction.length_squared()>1.5: return
	var id := multiplayer.get_remote_sender_id()
	if id==0: id=1
	if player_state.has(str(id)):
		player_state[str(id)].carry_direction=direction.normalized()

func toggle_cargo(player: CharacterBody3D,direction: Vector3) -> void:
	var id := int(str(player.name))
	var data: Dictionary=player_state[str(id)]
	if data.get("held", "")!="":
		release_cargo(id,Vector3.ZERO)
		return
	var nearest_item: RigidBody3D=null
	var best := 4.0
	for item in get_node("../ItemContainer").get_children():
		var offset: Vector3=item.global_position-player.global_position
		if item.carried_by==0 and offset.length()<best and offset.normalized().dot(direction)>0 and clear_line(player.global_position+Vector3.UP,item.global_position+Vector3.UP*.2):
			nearest_item=item
			best=offset.length()
	if nearest_item:
		nearest_item.carried_by=id
		nearest_item.freeze=true
		data.held=str(nearest_item.name)
		data.carry_direction=direction
		play_sound.rpc("grab",player.global_position+Vector3.UP)

func release_cargo(id: int,velocity: Vector3) -> void:
	if not player_state.has(str(id)): return
	var data: Dictionary=player_state[str(id)]
	var held_name: String=data.get("held", "")
	if held_name.is_empty(): return
	var held := get_node("../ItemContainer").get_node_or_null(NodePath(held_name)) as RigidBody3D
	if held:
		held.carried_by=0
		held.freeze=false
		held.collision_layer=4
		held.linear_velocity=velocity
		# Thrown goods leave a small pop where they leave the mitts; a gentle
		# release is a set-down, a fast one is a whooshed throw.
		fx.rpc(held.global_position,Color("e8e2d0"),.45)
		play_sound.rpc("throw" if velocity.length()>4.0 else "drop",held.global_position)
	data.held=""

func render_hazards() -> void:
	for collection in [fires,bait]:
		var visuals: Array[Node3D]=hazard_visuals if collection==fires else bait_visuals
		while visuals.size()>collection.size():
			visuals.pop_back().queue_free()
		while visuals.size()<collection.size():
			var visual := Node3D.new()
			add_child(visual)
			var color := Color("ff7d31") if collection==fires else Color("7fae3d")
			var blob := preload("res://scripts/heist/slime_visual.gd").sphere(visual,Vector3(0,.25,0),Vector3(3,.25,3) if collection==fires else Vector3(.6,.4,.5),color)
			blob.material_override=Materials.lit(color,.8 if collection==fires else .55)
			if collection==fires:
				for i in range(3):
					var flame := Visual.sphere(visual,Vector3(sin(i*2.1),.5,cos(i*2.1)),Vector3(.5,1,.5),Color("ffd27a"))
					flame.material_override=Materials.lit(Color("ffd27a"),1.4)
				# Only the first four fires get a real light: shadowless and
				# capped, everything else glows by emission alone.
				if visuals.size()<4:
					var glow := OmniLight3D.new()
					glow.light_color=Color("ff7d31")
					glow.light_energy=1.3
					glow.omni_range=7
					glow.omni_attenuation=1.4
					glow.shadow_enabled=false
					glow.position.y=.8
					visual.add_child(glow)
			else:
				# Mold-green halo marking the bribable bait pile.
				var halo := Visual.sphere(visual,Vector3(0,.4,0),Vector3(1.15,.8,1.0),Color("a2d95a"))
				var halo_mat: StandardMaterial3D=(halo.material_override as StandardMaterial3D).duplicate()
				halo.material_override=halo_mat
				halo_mat.albedo_color=Color("a2d95a38")
				halo_mat.emission_enabled=true
				halo_mat.emission=Color("7fae3d")
				halo_mat.emission_energy_multiplier=.7
			visuals.append(visual)
		for i in collection.size():
			visuals[i].position=collection[i].position
			visuals[i].scale.y=1+sin(Time.get_ticks_msec()*.008+i)*.25

func build_security_cameras() -> void:
	for spec in [[Vector3(15,4.3,-29),Vector3(-1,-.2,0)],[Vector3(-15,4.3,-44),Vector3(1,-.2,0)],[Vector3(55,4.3,-29),Vector3(-1,-.2,0)],[Vector3(51,4.3,35),Vector3(1,-.2,0)],[Vector3(84,4.3,-32),Vector3(-1,-.2,0)]]:
		var holder := Node3D.new()
		holder.position=spec[0]
		add_child(holder)
		holder.look_at(spec[0]+spec[1])
		var camera := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size=Vector3(.55,.35,.85)
		camera.mesh=box
		var mat := Materials.part(Color("2b2138"))
		camera.material_override=mat
		holder.add_child(camera)
		var lamp := SpotLight3D.new()
		lamp.light_color=Color("ffb347")
		lamp.light_energy=.8
		lamp.spot_range=12
		lamp.spot_angle=22
		holder.add_child(lamp)
		preload("res://scripts/heist/slime_visual.gd").sphere(holder,Vector3(.19,0,-.44),Vector3(.07,.07,.04),Color("ff4d4d"))
		var cone := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius=0
		mesh.bottom_radius=4
		mesh.height=11
		cone.mesh=mesh
		cone.rotation.x=PI*.5
		cone.position.z=-5.5
		var glass := StandardMaterial3D.new()
		glass.albedo_color=Color(.9,.65,.25,.025)
		glass.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
		glass.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
		glass.cull_mode=BaseMaterial3D.CULL_DISABLED
		cone.material_override=glass
		holder.add_child(cone)
		cameras.append({"position":spec[0],"direction":spec[1].normalized(),"disabled":false,"holder":holder,"cone":cone})

func security_scan(delta: float) -> void:
	for camera in cameras:
		if camera.disabled: continue
		for player in live_players():
			var offset: Vector3=player.global_position+Vector3.UP-camera.position
			if offset.length()<12 and offset.normalized().dot(camera.direction)>.92 and clear_line(camera.position,player.global_position+Vector3.UP):
				alarm=minf(100,alarm+delta*18)

func render_cameras() -> void:
	for camera in cameras:
		camera.cone.visible=not camera.disabled and alarm>35

func build_machine_visuals() -> void:
	var visual_script := preload("res://scripts/heist/slime_visual.gd")
	for i in range(4):
		var machine := Node3D.new()
		machine.name="ProductionMachine%d"%i
		machine.position=Vector3(8,-12,26+i*7) if i<3 else Vector3(-10,-12,40)
		add_child(machine)
		var shell := MeshInstance3D.new()
		var cylinder := CylinderMesh.new()
		cylinder.top_radius=.9
		cylinder.bottom_radius=.9
		cylinder.height=2.2
		shell.mesh=cylinder
		shell.position.y=1.1
		shell.material_override=get_node("Hideout/StarterMachine").material_override
		machine.add_child(shell)
		visual_script.sphere(machine,Vector3(0,2.3,0),Vector3(1.7,.4,1.7),Color("abb879"))
		visual_script.sphere(machine,Vector3(.85,2.5,.3),Vector3(.3,1.5,.3),Color("b68e5d"))
		var output := visual_script.sphere(machine,Vector3(-1,1,0),Vector3(.6,.6,.6),Color("c5d875"))
		output.name="Output"
		machine_visuals.append(machine)
	for child in $Hideout.get_children():
		if str(child.name).begins_with("StarterMachine") or str(child.name) in ["MachinePipe","ControlBox"]:
			child.hide()


func send_travel(id: int,destination: Vector3) -> void:
	# Give simultaneous arrivals separate capsule-sized landing positions.
	var ids: Array=Network.players.keys()
	ids.sort()
	var index := maxi(0,ids.find(id))
	var offset := Vector3((index % 2)*1.8-.9,0,(index / 2)*1.8-.9) if ids.size()>1 else Vector3.ZERO
	travel.rpc(id,destination+offset)
