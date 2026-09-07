class_name MainMenuUI
extends Control

signal host_pressed(nickname: String, skin: String)
signal join_pressed(nickname: String, skin: String, address: String)
signal settings_pressed
signal quit_pressed

const SKIN_OPTIONS: Array[String] = ["Blue", "Yellow", "Green", "Red"]
const SAFE_AREA_MARGIN := 24.0

@onready var skin_input: OptionButton = $MainContainer/MainMenu/Option2/SkinInput
@onready var nick_input: LineEdit = $MainContainer/MainMenu/Option1/NickInput
@onready var address_input: LineEdit = $MainContainer/MainMenu/Option3/AddressInput
@onready var main_container: VBoxContainer = $MainContainer


func _ready() -> void:
	$ColorRect.color = Color(0.035, 0.08, 0.085, 0.82)
	$MainContainer/Label.text = "THE CROOKED MILE"
	$MainContainer/Label.add_theme_color_override("font_color", Color("d9dfad"))
	$MainContainer/Label.add_theme_font_size_override("font_size", 56)
	main_container.add_theme_constant_override("separation", 24)
	$MainContainer/MainMenu/Buttons/Host.text = "HOST HEIST"
	$MainContainer/MainMenu/Buttons/Join.text = "JOIN CREW"
	var subtitle := Label.new()
	subtitle.text = "1-4 PLAYER CO-OP  /  RAT MART\nRob the shop. Recover the recipe. Build your hideout."
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 22)
	main_container.add_child(subtitle)
	main_container.move_child(subtitle, 1)
	skin_input.clear()
	for skin_name in SKIN_OPTIONS:
		skin_input.add_item(skin_name)
	skin_input.select(0)
	resized.connect(_update_responsive_layout)
	call_deferred("_update_responsive_layout")


func _on_host_pressed() -> void:
	var nickname = nick_input.text.strip_edges()
	var skin = get_skin()
	host_pressed.emit(nickname, skin)


func _on_join_pressed() -> void:
	var nickname = nick_input.text.strip_edges()
	var skin = get_skin()
	var address = address_input.text.strip_edges()
	join_pressed.emit(nickname, skin, address)


func _on_settings_pressed() -> void:
	settings_pressed.emit()


func _on_quit_pressed():
	quit_pressed.emit()


func show_menu():
	show()
	call_deferred("_update_responsive_layout")


func hide_menu():
	hide()


func is_menu_visible() -> bool:
	return visible


func _update_responsive_layout() -> void:
	if not main_container:
		return
	var available_size := Vector2(
		maxf(1.0, size.x - SAFE_AREA_MARGIN * 2.0), maxf(1.0, size.y - SAFE_AREA_MARGIN * 2.0)
	)
	var content_size := main_container.get_combined_minimum_size()
	if content_size.x <= 0.0 or content_size.y <= 0.0:
		return
	var scale_factor := minf(1.0, minf(available_size.x / content_size.x, available_size.y / content_size.y))
	main_container.pivot_offset = main_container.size * 0.5
	main_container.scale = Vector2.ONE * scale_factor


func get_skin() -> String:
	return skin_input.get_item_text(skin_input.selected).to_lower()
