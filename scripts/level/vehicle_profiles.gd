class_name VehicleProfiles
extends RefCounted

## Centralised per-vehicle tuning. Every driving number the server physics
## (heist_world.update_vehicles) and the visual rig (scripts/vehicles/vehicle_rig.gd)
## use lives here, so a vehicle can be retuned in one place.
##
## Field guide:
##  max_forward_speed / max_reverse_speed - terminal speeds, m/s (throttle target)
##  acceleration          - m/s^2 while throttling forward
##  braking_deceleration  - m/s^2 when throttle is held against motion (brake phase)
##  coast_deceleration    - m/s^2 with no throttle input
##  steering_rate         - rad/s of yaw at full lock at low speed
##  high_speed_steering_multiplier - steering_rate multiplier at top speed (arcade:
##                                    cars steer less the faster they go; never snaps yaw)
##  lateral_grip          - m/s^2 of sideways velocity scrubbed per second
##  mass                  - RigidBody mass (ram feel + pushing merchandise)
##  step_height           - tallest curb the curb-assist will hop (probed server-side;
##                           walls and gates are always taller and never climbed)
##  suspension_visual_amount - how far the visual chassis springs travel (pure visuals)
##  body_lean_amount      - visual pitch/roll multiplier under accel/steering
##  cargo_speed_penalty / cargo_acceleration_penalty - multiplied in at full load
##  ram_strength          - damage of one ram impact event (impacts are discrete,
##                           per-enemy cooldown, not continuous overlap damage)
##  ram_min_speed         - planar speed below which bumping an enemy does nothing
##  ram_cooldown          - seconds before the same enemy can be ram-damaged again
##  visual_wheel_radius   - rig wheel size; spin is derived from real velocity
##  fov_gain / fov_max    - local camera speed-stretch while driving
##  camera_distance       - local third-person arm length while driving
const PROFILES: Dictionary = {
	"cart": {
		"max_forward_speed": 7.5,
		"max_reverse_speed": 4.0,
		"acceleration": 18.0,
		"braking_deceleration": 22.0,
		"coast_deceleration": 10.0,
		"steering_rate": 5.5,
		"high_speed_steering_multiplier": 0.75,
		"lateral_grip": 5.0,
		"mass": 8.0,
		"step_height": 0.30,
		"suspension_visual_amount": 1.0,
		"body_lean_amount": 1.0,
		"cargo_speed_penalty": 0.72,
		"cargo_acceleration_penalty": 0.62,
		"ram_strength": 12.0,
		"ram_min_speed": 5.0,
		"ram_cooldown": 1.2,
		"visual_wheel_radius": 0.22,
		"fov_gain": 0.45,
		"fov_max": 5.0,
		"camera_distance": 6.5,
	},
	"truck": {
		"max_forward_speed": 13.0,
		"max_reverse_speed": 5.0,
		"acceleration": 10.0,
		"braking_deceleration": 13.0,
		"coast_deceleration": 6.0,
		"steering_rate": 2.5,
		"high_speed_steering_multiplier": 0.65,
		"lateral_grip": 9.0,
		"mass": 60.0,
		"step_height": 0.45,
		"suspension_visual_amount": 0.55,
		"body_lean_amount": 0.6,
		"cargo_speed_penalty": 0.95,
		"cargo_acceleration_penalty": 0.88,
		"ram_strength": 34.0,
		"ram_min_speed": 6.0,
		"ram_cooldown": 1.5,
		"visual_wheel_radius": 0.42,
		"fov_gain": 0.35,
		"fov_max": 7.0,
		"camera_distance": 7.5,
	},
	"racecar": {
		"max_forward_speed": 22.0,
		"max_reverse_speed": 6.0,
		"acceleration": 18.0,
		"braking_deceleration": 18.0,
		"coast_deceleration": 8.0,
		"steering_rate": 3.8,
		"high_speed_steering_multiplier": 0.45,
		"lateral_grip": 10.0,
		"mass": 15.0,
		"step_height": 0.18,
		"suspension_visual_amount": 0.3,
		"body_lean_amount": 0.9,
		"cargo_speed_penalty": 1.0,
		"cargo_acceleration_penalty": 1.0,
		"ram_strength": 22.0,
		"ram_min_speed": 7.0,
		"ram_cooldown": 0.9,
		"visual_wheel_radius": 0.40,
		"fov_gain": 0.55,
		"fov_max": 10.0,
		"camera_distance": 7.0,
	},
}


static func profile(kind: String) -> Dictionary:
	return PROFILES.get(kind, PROFILES["cart"])