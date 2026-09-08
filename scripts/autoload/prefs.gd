extends Node

## Prefs: persistent player preferences - the audio mix and the keybinds.
##
## Owns two things:
##   - the audio bus layout: Master parents Music (ambience/atmosphere) and
##     SFX (world + UI one-shots); each also has a low-passed "Muffled"
##     variant that the wall-occlusion controller swaps in for sounds that
##     are sealed behind geometry
##   - the InputMap rebinding registry: every remappable action with its
##     default binding, applied over project.godot at startup, edited by the
##     controls screen, persisted to user://settings.cfg
##
## Bindings serialize as "key:<physical_keycode>" or "mouse:<button_index>",
## so saves survive engine restarts and stay layout-independent (physical).

const SAVE_PATH := "user://settings.cfg"
const LOWPASS_HZ := 720.0

## The controls screen, in display order: [action, label, default binding].
## Defaults mirror project.godot's [input] section; saved overrides win.
const ACTIONS: Array = [
	["move_forward", "Move forward", "key:87"],
	["move_backward", "Move backward", "key:83"],
	["move_left", "Move left", "key:65"],
	["move_right", "Move right", "key:68"],
	["jump", "Jump", "key:32"],
	["shift", "Sprint", "key:4194325"],
	["pickup", "Pick up / interact", "key:69"],
	["use_tool", "Interact / shop", "key:70"],
	["attack", "Slap / throw", "mouse:1"],
	["tool_use", "Use tool", "mouse:2"],
	["cycle_tool", "Cycle tools", "key:81"],
	["carry", "Grab / drop", "key:71"],
	["bait", "Bait", "key:66"],
	["eat", "Eat", "key:72"],
	["feed", "Feed crew", "key:67"],
	["transform", "Transform", "key:82"],
	["slime", "Back to slime", "key:88"],
	["toggle_camera", "Toggle camera", "key:86"],
	["inventory", "Inventory", "key:73"],
	["toggle_chat", "Chat", "key:84"],
	["player_list", "Player list", "key:4194306"],
]

const SLOTS: Array = ["master", "music", "sfx"]

const KEY_LABELS: Dictionary = {
	4194305: "Esc", 4194306: "Tab", 4194308: "Backspace", 4194309: "Enter",
	4194325: "Shift", 4194326: "Ctrl", 4194327: "Alt", 4194328: "Caps",
	4194332: "F1", 4194333: "F2", 32: "Space",
}

var _config := ConfigFile.new()


func _ready() -> void:
	_ensure_buses()
	_config.load(SAVE_PATH)
	for slot in SLOTS:
		apply_volume(slot, float(_config.get_value("audio", slot, 1.0)))
	for entry in ACTIONS:
		var saved: String = _config.get_value("keybinds", entry[0], "")
		if saved != "":
			_apply_binding(entry[0], saved)


# --- audio mix ---------------------------------------------------------------

func _ensure_buses() -> void:
	_ensure_bus("Music", "Master", 0.0)
	_ensure_bus("SFX", "Master", 0.0)
	_ensure_bus("Muffled Music", "Music", LOWPASS_HZ)
	_ensure_bus("Muffled SFX", "SFX", LOWPASS_HZ)


func _ensure_bus(bus_name: String, send: String, lowpass_hz: float) -> void:
	if AudioServer.get_bus_index(bus_name) != -1:
		return
	var index := AudioServer.bus_count
	AudioServer.add_bus(index)
	AudioServer.set_bus_name(index, bus_name)
	AudioServer.set_bus_send(index, send)
	if lowpass_hz > 0.0:
		var low_pass := AudioEffectLowPassFilter.new()
		low_pass.cutoff_hz = lowpass_hz
		AudioServer.add_bus_effect(index, low_pass)


## The occlusion controller routes blocked sources to the muffled twin of
## whatever mix bus they normally sit on.
func muffled_variant(bus_name: String) -> String:
	match bus_name:
		"Music":
			return "Muffled Music"
		_:
			return "Muffled SFX"


func apply_volume(slot: String, linear: float) -> void:
	var bus_name := slot.capitalize()
	if slot == "sfx":
		bus_name = "SFX"
	var index := AudioServer.get_bus_index(bus_name)
	if index == -1:
		return
	AudioServer.set_bus_volume_db(index, linear_to_db(clampf(linear, 0.0, 1.0)))
	AudioServer.set_bus_mute(index, linear <= 0.001)
	_config.set_value("audio", slot, clampf(linear, 0.0, 1.0))
	_save()


func get_volume(slot: String) -> float:
	var bus_name := slot.capitalize()
	if slot == "sfx":
		bus_name = "SFX"
	var index := AudioServer.get_bus_index(bus_name)
	if index == -1:
		return 1.0
	return db_to_linear(AudioServer.get_bus_volume_db(index))


# --- keybinds ----------------------------------------------------------------

## Swap an action's primary binding. Returns false if the event is not a
## key or mouse button.
func rebind(action: String, event: InputEvent) -> bool:
	var code := event_to_code(event)
	if code == "" or not InputMap.has_action(action):
		return false
	InputMap.action_erase_events(action)
	InputMap.action_add_event(action, code_to_event(code))
	_config.set_value("keybinds", action, code)
	_save()
	return true


## Restore one action's project.godot binding.
func reset_action(action: String) -> void:
	for entry in ACTIONS:
		if entry[0] != action:
			continue
		_config.set_value("keybinds", action, null)
		_apply_binding(action, entry[2])
		_save()
		return


## Restore every action to its project.godot binding.
func reset_all() -> void:
	for entry in ACTIONS:
		_config.set_value("keybinds", entry[0], null)
		_apply_binding(entry[0], entry[2])
	_save()


func _apply_binding(action: String, code: String) -> void:
	var event := code_to_event(code)
	if event == null:
		return
	InputMap.action_erase_events(action)
	InputMap.action_add_event(action, event)


## "key:<physical_keycode>" / "mouse:<button_index>" or "" if unmappable.
func event_to_code(event: InputEvent) -> String:
	if event is InputEventKey:
		return "key:%d" % event.physical_keycode
	if event is InputEventMouseButton:
		return "mouse:%d" % event.button_index
	return ""


func code_to_event(code: String) -> InputEvent:
	if code.begins_with("key:"):
		var key := InputEventKey.new()
		key.physical_keycode = int(code.trim_prefix("key:"))
		return key
	if code.begins_with("mouse:"):
		var mouse := InputEventMouseButton.new()
		mouse.button_index = int(code.trim_prefix("mouse:"))
		return mouse
	return null


## Compact binding text for the HUD legend and the controls screen.
func action_label(action: String) -> String:
	var events := InputMap.action_get_events(action)
	if events.is_empty():
		return "?"
	var event: InputEvent = events[0]
	if event is InputEventMouseButton:
		match int(event.button_index):
			MOUSE_BUTTON_LEFT:
				return "LMB"
			MOUSE_BUTTON_RIGHT:
				return "RMB"
			MOUSE_BUTTON_MIDDLE:
				return "MMB"
			_:
				return "M%d" % event.button_index
	if event is InputEventKey:
		var code: int = event.physical_keycode
		if KEY_LABELS.has(code):
			return KEY_LABELS[code]
		var text := OS.get_keycode_string(code)
		return text.capitalize() if text.length() > 1 else text
	return "?"


func _save() -> void:
	_config.save(SAVE_PATH)