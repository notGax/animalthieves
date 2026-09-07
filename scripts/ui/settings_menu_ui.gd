class_name SettingsMenuUI
extends Control

## The settings overlay: three volume sliders (Master/Music/SFX) on the audio
## page and a full rebind list on the controls page. All state lives in the
## Prefs autoload, which owns the buses, the InputMap and user://settings.cfg.
##
## Rebind capture: clicking a bind button enters capture mode; the next key
## press (Esc cancels) or mouse click becomes that action's binding. This
## script consumes those events in _input - as the last child of Level it
## receives them before the level root, so Esc can cancel a capture without
## also toggling the pause menu.

signal closed

const GameAudio = preload("res://scripts/audio/game_audio.gd")

@onready var panel: PanelContainer = $Overlay/Panel
@onready var tab_audio: Button = $Overlay/Panel/Margin/Root/Tabs/TabAudio
@onready var tab_controls: Button = $Overlay/Panel/Margin/Root/Tabs/TabControls
@onready var audio_page: VBoxContainer = $Overlay/Panel/Margin/Root/AudioPage
@onready var controls_page: VBoxContainer = $Overlay/Panel/Margin/Root/ControlsPage
@onready var bind_list: VBoxContainer = $Overlay/Panel/Margin/Root/ControlsPage/Scroll/BindList
@onready var back_button: Button = $Overlay/Panel/Margin/Root/Back

var _capturing_action := ""
var _bind_buttons: Dictionary = {}


func _ready() -> void:
	resized.connect(_update_responsive_layout)
	hide()
	_setup_audio_page()
	_build_bind_rows()
	tab_audio.pressed.connect(_show_audio_page)
	tab_controls.pressed.connect(_show_controls_page)
	_show_audio_page()


func _setup_audio_page() -> void:
	for slot in Prefs.SLOTS:
		var row := audio_page.get_node("Row" + slot.capitalize())
		var slider: HSlider = row.get_node("Slider")
		var pct: Label = row.get_node("Pct")
		var value := Prefs.get_volume(slot)
		slider.value = value
		pct.text = "%d%%" % roundi(value * 100.0)
		slider.value_changed.connect(_on_volume_changed.bind(slot, pct))


func _build_bind_rows() -> void:
	for entry in Prefs.ACTIONS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var label := Label.new()
		label.text = str(entry[1])
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		var bind := Button.new()
		bind.custom_minimum_size = Vector2(110, 30)
		bind.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		bind.text = Prefs.action_label(str(entry[0]))
		bind.pressed.connect(_start_capture.bind(str(entry[0]), bind))
		row.add_child(label)
		row.add_child(bind)
		bind_list.add_child(row)
		_bind_buttons[str(entry[0])] = bind


func _input(event: InputEvent) -> void:
	if not visible or _capturing_action == "":
		return
	if event is InputEventKey and event.pressed and not event.echo:
		get_viewport().set_input_as_handled()
		if event.physical_keycode == KEY_ESCAPE:
			_finish_capture()
			return
		var key := InputEventKey.new()
		key.physical_keycode = event.physical_keycode
		_apply_capture(key)
	elif event is InputEventMouseButton and event.pressed:
		get_viewport().set_input_as_handled()
		var mouse := InputEventMouseButton.new()
		mouse.button_index = event.button_index
		_apply_capture(mouse)


# --- pages -------------------------------------------------------------------

func _show_audio_page() -> void:
	tab_audio.button_pressed = true
	tab_controls.button_pressed = false
	audio_page.visible = true
	controls_page.visible = false


func _show_controls_page() -> void:
	tab_audio.button_pressed = false
	tab_controls.button_pressed = true
	audio_page.visible = false
	controls_page.visible = true


# --- audio -------------------------------------------------------------------

func _on_volume_changed(value: float, slot: String, pct: Label) -> void:
	Prefs.apply_volume(slot, value)
	pct.text = "%d%%" % roundi(value * 100.0)


# --- keybinds ----------------------------------------------------------------

func _start_capture(action: String, button: Button) -> void:
	_finish_capture()
	_capturing_action = action
	button.text = "> press <"
	button.grab_focus()


func _apply_capture(event: InputEvent) -> void:
	var action := _capturing_action
	if Prefs.rebind(action, event):
		GameAudio.play_ui(self, "click")
	_finish_capture()


func _finish_capture() -> void:
	if _capturing_action == "":
		return
	var action := _capturing_action
	_capturing_action = ""
	_refresh_bind_labels(action)


func _refresh_bind_labels(action := "") -> void:
	if action == "":
		for entry in Prefs.ACTIONS:
			var action_name: String = entry[0]
			if _bind_buttons.has(action_name):
				_bind_buttons[action_name].text = Prefs.action_label(action_name)
	else:
		if _bind_buttons.has(action):
			_bind_buttons[action].text = Prefs.action_label(action)


func _on_reset_pressed() -> void:
	Prefs.reset_all()
	GameAudio.play_ui(self, "click")
	for slot in Prefs.SLOTS:
		var row := audio_page.get_node("Row" + slot.capitalize())
		var slider: HSlider = row.get_node("Slider")
		var pct: Label = row.get_node("Pct")
		slider.set_value_no_signal(Prefs.get_volume(slot))
		pct.text = "%d%%" % roundi(Prefs.get_volume(slot) * 100.0)
	_refresh_bind_labels()


# --- menu plumbing -----------------------------------------------------------

func show_menu() -> void:
	show()
	call_deferred("_update_responsive_layout")
	back_button.grab_focus()


func hide_menu() -> void:
	_finish_capture()
	hide()


func is_menu_visible() -> bool:
	return visible


func _on_back_pressed() -> void:
	GameAudio.play_ui(self, "click")
	closed.emit()


func _update_responsive_layout() -> void:
	if not panel:
		return
	var available_size := Vector2(maxf(1.0, size.x - 32.0), maxf(1.0, size.y - 32.0))
	var panel_size := panel.size
	if panel_size.x <= 0.0 or panel_size.y <= 0.0:
		return
	var scale_factor := minf(1.0, minf(available_size.x / panel_size.x, available_size.y / panel_size.y))
	panel.pivot_offset = panel_size * 0.5
	panel.scale = Vector2.ONE * scale_factor