class_name Palette
extends RefCounted
## Central art-direction palette. Static data only; consumed via preload.
## Must mirror the PALETTE dict in scripts/level/build_heist_world.py.
## Direction: strong color separation, saturated accents, warm/cool contrast.
## Dirty means colorful (mustard, mold, rose, plum, teal) - never grey-brown.

## Per-player skin, indexed by Character.SkinColor (BLUE, YELLOW, GREEN, RED).
const PLAYER_SKINS := [
	{"body":"5ec8e8","deep":"2f8fb0","light":"9ce6f7","cheek":"ff9db1","pupil":"1b2b33","brow":"23323a","ear":"ffb0be"},
	{"body":"ffcb45","deep":"c98f22","light":"ffe89a","cheek":"ff9d8f","pupil":"2b2416","brow":"3a2f18","ear":"ffc2a0"},
	{"body":"8fd45f","deep":"5f9c37","light":"c6f19a","cheek":"ff9db1","pupil":"1b2b1a","brow":"243a18","ear":"ffb0be"},
	{"body":"f2705f","deep":"b8463a","light":"ffa795","cheek":"ffb0a0","pupil":"2b1a18","brow":"3a211c","ear":"ffc0b0"},
]

## Guard species palettes, indexed by guard tier (rat, boar, magpie, lizard).
const GUARD := [
	{"body":"8f9aa3","belly":"cfd6dc","vest":"3fa8a0","cap":"2b2138","badge":"ffd24a","ear":"e8a0ac","snout":"b9c0c6","pupil":"1b2b33"},
	{"body":"c2743f","belly":"e8b98a","vest":"f2a03d","cap":"ffd24a","tusk":"fdf3d0","snout":"e09a68","pupil":"2b1a18"},
	{"body":"2f3138","belly":"f2ede0","vest":"3fa8a0","cap":"2b2138","beak":"ffb347","wing":"1d1526","pupil":"1b2b33"},
	{"body":"7fae3d","belly":"cfe6a0","visor":"9ef0e4","spike":"4c7a3f","claw":"fdf3d0","pupil":"1b2b1a"},
]

## The chef boss ("THE BIG CHEESE") - fat, flour-dusted, mustachioed.
const BOSS := {"hat":"fdf6e4","hat_band":"e05a5a","apron":"e8dcc0","strap":"b5472f",
	"mustache":"5a4632","ladle":"9aa3ab","body":"a8b0b8","belly":"d8dee2","ear":"e8a0ac","snout":"c3cad0"}

## HUD and interface colors.
const UI := {"ink":"1d1526","panel":"2b2138","panel_edge":"f2b64c","text":"fdf3d0","text_dim":"cfc3a8",
	"good":"8fd45f","warn":"ffd24a","bad":"ff5f5f","info":"7acde8","gold":"ffd24a","boss":"ff5fa8"}

## Cosmetic effect accents, keyed by use.
const VFX := {"hit":"ffd24a","hurt":"ff6b6b","heal":"8fd45f","cash":"ffd24a","transform":"9ef0e4",
	"grapple":"ffe6a3","water":"7acde8","jetpack":"ffb66e","fire":"ff7d31",
	"crystal":"b6a3da","pickup":"fff3c4","dust":"e8e2d0","alarm":"ff4d4d","boss":"ff5fa8"}


static func color(hex: String) -> Color:
	return Color(hex)


static func skin(index: int) -> Dictionary:
	return PLAYER_SKINS[clampi(index, 0, PLAYER_SKINS.size() - 1)]


## Rounded dark panel with a warm gold edge - the crooked-shop UI look.
static func panel_style(bg: Color, edge: Color, radius := 12) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = edge
	style.set_border_width_all(2)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style


static func pill_style(bg: Color) -> StyleBoxFlat:
	var style := panel_style(bg, bg, 18)
	return style