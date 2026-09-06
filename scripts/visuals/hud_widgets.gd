class_name HudWidgets
extends RefCounted
## Styled HUD building blocks: plum panels with warm gold edges, tilted pills
## and rounded bars - the crooked-shop UI look. Static helpers only.

const Palette = preload("res://scripts/visuals/palette.gd")


## Text with the standard ink drop shadow.
static func label(size: int, color := "text") -> Label:
	var out := Label.new()
	out.add_theme_font_size_override("font_size", size)
	out.add_theme_color_override("font_color", Palette.color(Palette.UI[color]))
	out.add_theme_color_override("font_shadow_color", Palette.color(Palette.UI.ink))
	out.add_theme_constant_override("shadow_offset_x", 2)
	out.add_theme_constant_override("shadow_offset_y", 2)
	out.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return out


## Rounded plum panel with a gold edge; tilt in radians for the crooked look.
static func frame(bg := "panel", edge := "panel_edge", radius := 12, tilt := 0.0) -> PanelContainer:
	var out := PanelContainer.new()
	out.add_theme_stylebox_override("panel", Palette.panel_style(Palette.color(Palette.UI[bg]), Palette.color(Palette.UI[edge]), radius))
	if tilt != 0.0:
		out.rotation = tilt
	out.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return out


## Vertical stack for panel contents.
static func rows(separation := 6) -> VBoxContainer:
	var out := VBoxContainer.new()
	out.add_theme_constant_override("separation", separation)
	out.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return out


## Rounded pill bar (0..1) with a dark well; fill takes a Palette.UI role name
## ("good", "warn", "bad", "info"...). Caller keeps the fill stylebox reference
## to recolor it (hp lerp, alarm pulse).
static func bar(width: float, height: float, fill_role: String) -> ProgressBar:
	var out := ProgressBar.new()
	out.custom_minimum_size = Vector2(width, height)
	out.max_value = 1.0
	out.value = 1.0
	out.show_percentage = false
	out.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var well := StyleBoxFlat.new()
	well.bg_color = Palette.color(Palette.UI.ink)
	well.set_corner_radius_all(int(height * .5))
	well.set_border_width_all(1)
	well.border_color = Palette.color("453a55")
	var fill := StyleBoxFlat.new()
	fill.bg_color = Palette.color(Palette.UI.get(fill_role, Palette.UI.text))
	fill.set_corner_radius_all(int(height * .5))
	out.add_theme_stylebox_override("background", well)
	out.add_theme_stylebox_override("fill", fill)
	return out