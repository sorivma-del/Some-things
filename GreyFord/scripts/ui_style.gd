class_name UiStyle
extends RefCounted
## Shared look for on-screen text: Cormorant Garamond, no backing panels, readability
## from a soft outline and shadow instead.

const REGULAR: FontFile = preload("res://resources/fonts/CormorantGaramond.ttf")
const ITALIC: FontFile = preload("res://resources/fonts/CormorantGaramond-Italic.ttf")

const COLOR_TEXT := Color(0.93, 0.89, 0.8)
const COLOR_DIM := Color(0.66, 0.62, 0.55)
const COLOR_ACCENT := Color(0.86, 0.64, 0.38)
const COLOR_HERO := Color(0.66, 0.78, 0.6)
const COLOR_OUTLINE := Color(0.02, 0.02, 0.03, 0.75)
const COLOR_SHADOW := Color(0.0, 0.0, 0.0, 0.6)

static var _fonts: Dictionary[String, FontVariation] = {}


## Variable-font instance with the given weight (300-700) and extra letter spacing.
static func font(weight: int = 500, italic: bool = false, letter_spacing: int = 0) -> FontVariation:
	var key := "%d|%s|%d" % [weight, italic, letter_spacing]
	if _fonts.has(key):
		return _fonts[key]
	var variation := FontVariation.new()
	variation.base_font = ITALIC if italic else REGULAR
	variation.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
	variation.spacing_glyph = letter_spacing
	_fonts[key] = variation
	return variation


## Outline + drop shadow so text reads over any background without a panel.
static func apply_label(label: Control, size: int, weight: int = 500, italic: bool = false,
		color: Color = COLOR_TEXT, letter_spacing: int = 0) -> void:
	var is_rich := label is RichTextLabel
	label.add_theme_font_override(&"normal_font" if is_rich else &"font", font(weight, italic, letter_spacing))
	label.add_theme_font_size_override(&"normal_font_size" if is_rich else &"font_size", size)
	label.add_theme_color_override(&"default_color" if is_rich else &"font_color", color)
	label.add_theme_color_override(&"font_outline_color", COLOR_OUTLINE)
	label.add_theme_constant_override(&"outline_size", maxi(4, size / 5))
	label.add_theme_color_override(&"font_shadow_color", COLOR_SHADOW)
	label.add_theme_constant_override(&"shadow_offset_x", 0)
	label.add_theme_constant_override(&"shadow_offset_y", 2)
	label.add_theme_constant_override(&"shadow_outline_size", maxi(6, size / 3))
