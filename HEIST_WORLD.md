# The Crooked Mile

A playable 1-4 player co-op heist game built on the project's existing Godot multiplayer template.

## Start playing

Open project.godot and press F5. Choose HOST HEIST to play solo or host up to three friends. Friends select JOIN CREW with the host's address. The template uses UDP 8080. A dedicated headless server supports four connected clients.

You spawn on the road by Rat Mart and the central manhole. Rob stores, deliver loot to the loading bay beside the van, defeat their bosses, and invest in the underground hideout.

## Controls

| Input | Action |
| --- | --- |
| WASD / Shift / Space | Move / sprint / jump; jump again in the air |
| Mouse / V | Look / switch first and third person |
| G | Grab nearby physical merchandise, or drop held cargo |
| Left mouse | Slap enemies; throw cargo if holding something |
| Right mouse / Q | Use the selected tool / cycle owned tools |
| E / I | Pick merchandise into your bag / inventory and item dropping |
| F | Interact, travel, sell loot, collect income, revive, board or exit vehicles |
| B | Spend rotten cheese to distract and bribe nearby rats |
| H | Eat: cheese for speed, otherwise moonshine for strength and fuel, otherwise canned food for health |
| C | Feed the nearest teammate in front of you: canned food heals a hurt teammate, otherwise cheese speeds them up, otherwise moonshine strengthens and refuels them |
| R / X | Cycle unlocked animal forms / return to slime |
| T / Tab / Esc | Chat / crew list / pause or close the trader |

## The campaign

The road connects Rat Mart, Boar Hardware, Bird Seed & Co., and Cold Blood Electronics. Bosses are the chef rat, Foreman Tusk, Madam Magpie, and the mecha dragon with its lizard pilot. Each victory upgrades that store's guaranteed recipe, pays the crew, and opens the next store. There is a 40% chance to unlock the boss species for the crew if it has not already dropped.

Guards patrol, detect visible players, pursue, and attack. Bosses telegraph charges, can crash into walls and become stunned, and attack faster at low health. Security cameras raise the alarm; high alarm makes guards faster. Slap cameras at close range or use the water gun to disable them. Matching animal disguises fool ordinary guards while alarm is below 50%; bosses see through disguises.

Rat Mart has three stocked aisles, checkout valuables, a stockroom, a rat-form shortcut, a basement distillery and a chef arena. Sabotage each of the three distillery valves once per heist to damage and stun the chef. Burning spills are visible hazards and can be extinguished with the water gun. Cheese bait temporarily bribes nearby rats, including the chef.

Food is shared resource: press C to hand-feed the teammate in front of you. Canned food restores 30 of their health, rotten cheese grants your speed effect, and moonshine grants your strength effect and refuels their jetpack. Downed teammates need revival with F first.

The four stores contain 62 synchronized physical merchandise objects. Carry and throw them, use your bag, or load them into a cart or truck. Press F at the loading bay to sell bagged merchandise and loose cargo within the bay.

## The hideout

F at the manhole descends into the hideout. The trader sells shared equipment, additional production slots, and animal-form upgrades. The planning table restocks stores and respawns bosses when the crew has left all stores, allowing recipe upgrades and more chances at transformation drops.

You start with one machine slot. Your first boss recipe installs automatically; use the trader to replace installed recipes or add slots, up to four. Machines earn money while players are connected, including during missions. The income terminal transfers those earnings to shared funds. Higher recipe levels increase income and machine size.

Campaign funds, income, recipe levels, installed machines, purchased equipment, transformations and upgrades save on the host at user://crooked_mile_campaign_v2.json. Bags, guard state, alarm and carried objects are session state. There are no offline earnings.

## Equipment and forms

- Grappling hook: pull yourself to surfaces, pull rigid merchandise, or tug teammates. Aim and use the right mouse button.
- Water gun: heal another living player, slow enemies, disable cameras, and extinguish nearby fires. It cannot heal its user.
- Slime crystal: consume a crystal to revive a downed teammate within 12 meters. F revives a teammate at close range without a crystal.
- Jetpack: right mouse applies thrust and spends fuel. Refuel in the hideout or by drinking moonshine.
- Shopping cart, mini truck and racecar: purchase from the trader, then F beside the vehicle on the road to drive. WASD moves relative to your camera. Cart and truck sides hold physical cargo; fast vehicles damage guards on impact.
- Rat form: smaller appearance, faster movement and access to the Rat Mart tunnel.
- Boar form: stronger melee attacks.
- Bird form: hold jump while airborne to glide.
- Lizard form: melee also breathes fire. Your own breath does not hurt you, but it can hurt teammates.

Animal changes have a 120-second cooldown. Returning to slime is always allowed and does not clear the cooldown. Form upgrades improve attack strength. The whole crew may use the same unlocked form.

Players have 100 health. Downed players can be revived by teammates; a fully downed crew is rescued to the hideout after five seconds for $30. An isolated downed player is rescued after 30 seconds. The hideout gradually heals living players and refuels jetpacks.

## Presentation

The game keeps the template's movement controller but replaces the robot model with soft-edged, chunky low-poly slimes in muted pastel colors, animated in the wobbly spirit of PEAK and R.E.P.O.: bodies squash and stretch on jumps and hard landings, lean into acceleration and wobble back, lag behind fast turns like a flapping head, and flail their mittens in the air. Every character has large reactive eyes with brows: they blink, bulge and dart frantically near danger, widen when falling, and track nearby players, guards, and carried cargo. First-person players see their own mitten hands breathe, reach for grabs, curl around carried merchandise, and hold the selected tool.

Illustrated store posters hang inside each shop and on a target wall in the hideout. Inventory slots, the trader shop and the tool HUD use a generated hand-painted icon set. Surfaces are painted atlases projected in world space; see [assets/environment/heist/ASSET_NOTES.md](./assets/environment/heist/ASSET_NOTES.md).

## Project layout

- scenes/level/level.tscn: main multiplayer scene.
- scenes/level/heist_world.tscn: editable static road, stores, hideout and distillery.
- scripts/level/heist_world.gd: authoritative game loop, shop, tools, vehicles, save data and synchronization.
- scripts/heist/security_guard.gd: animal models and server-driven enemy behavior.
- scripts/heist/slime_visual.gd: expressive slime and transformation visuals with tracked eyes, keeping the template controller.
- scripts/heist/first_person_hands.gd: first-person mitten rig for grabbing, carrying and tool use.
- assets/environment/heist/: generated painted surface atlases, item icon sheet, store posters, world-space material shader and source notes.
- scripts/level/build_heist_world.py: deterministic scene generator. Running it overwrites the generated world and four merchandise scenes; keep edits in the generator or edit scenes directly without regenerating.

Characters, vehicles and encounters use original procedural models. This is a playable prototype: art, animation, vehicle handling and combat balance can be refined further. The original template arena remains in the project.

## Validation

Godot 4.6.1 automated checks cover physical carry/throw, guard detection, melee, boss telegraphs, sabotage limits, loot spawning, travel, shop validation, guaranteed boss rewards, income, extraction, revives, teammate feeding, species cooldowns, driving, persistence and walkable floors. Multiplayer validation uses a dedicated server and four concurrent clients to check late-join loot, equipment, defeated bosses, progression and client travel. Forward+ renders cover the road, store, hideout, distillery, slime and bosses.

Run the checks with Godot --headless --path . --script res://scripts/tests/verify_heist.gd. For multiplayer, add -- --server; after SERVER_READY start up to four other processes with -- --client. For screenshots, run without --headless and add -- --capture. Tests use separate save data and do not change the real campaign.
