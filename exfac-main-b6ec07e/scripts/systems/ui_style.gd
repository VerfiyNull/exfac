class_name UiStyle
extends RefCounted
## Quiet HUD/menu styling — soft washes by default; borders only for emphasis.

static func wash(bg: Color = Color(0.05, 0.07, 0.1, 0.72), radius: int = 6, pad: int = 10) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_border_width_all(0)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = pad
	sb.content_margin_right = pad
	sb.content_margin_top = pad
	sb.content_margin_bottom = pad
	return sb


static func panel(bg: Color = Color(0.06, 0.08, 0.11, 0.92), border: Color = Color(0.35, 0.45, 0.52, 0.55), radius: int = 8, pad: int = 12) -> StyleBoxFlat:
	var sb := wash(bg, radius, pad)
	sb.set_border_width_all(1)
	sb.border_color = border
	return sb


static func apply_wash(node: PanelContainer, bg: Color = Color(0.05, 0.07, 0.1, 0.72)) -> void:
	node.add_theme_stylebox_override("panel", wash(bg))


static func apply_panel(node: PanelContainer, bg: Color = Color(0.06, 0.08, 0.11, 0.92), border: Color = Color(0.35, 0.45, 0.52, 0.55)) -> void:
	node.add_theme_stylebox_override("panel", panel(bg, border))


static func apply_danger_panel(node: PanelContainer) -> void:
	# Contested / KIA — one place a border earns its keep.
	apply_panel(node, Color(0.16, 0.07, 0.08, 0.9), Color(0.91, 0.33, 0.33, 0.55))


static func apply_ok_panel(node: PanelContainer) -> void:
	apply_wash(node, Color(0.05, 0.12, 0.09, 0.82))


static func apply_warn_panel(node: PanelContainer) -> void:
	apply_wash(node, Color(0.12, 0.1, 0.05, 0.82))


static func progress_fill(color: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(3)
	return sb


static func progress_bg() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.15, 0.19, 0.85)
	sb.set_corner_radius_all(3)
	return sb


static func style_progress(bar: ProgressBar, fill: Color) -> void:
	bar.add_theme_stylebox_override("fill", progress_fill(fill))
	bar.add_theme_stylebox_override("background", progress_bg())


static func button_normal() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.15, 0.19, 1)
	sb.set_border_width_all(0)
	sb.set_corner_radius_all(5)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	return sb


static func button_hover() -> StyleBoxFlat:
	var sb := button_normal()
	sb.bg_color = Color(0.16, 0.22, 0.26, 1)
	return sb


static func button_pressed() -> StyleBoxFlat:
	var sb := button_normal()
	sb.bg_color = Color(0.09, 0.2, 0.16, 1)
	return sb


static func button_primary() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.14, 0.32, 0.24, 1)
	sb.set_border_width_all(0)
	sb.set_corner_radius_all(5)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	return sb


static func style_button(btn: Button, primary: bool = false) -> void:
	if primary:
		btn.add_theme_stylebox_override("normal", button_primary())
	else:
		btn.add_theme_stylebox_override("normal", button_normal())
	btn.add_theme_stylebox_override("hover", button_hover())
	btn.add_theme_stylebox_override("pressed", button_pressed())
	btn.add_theme_stylebox_override("focus", button_hover())
	btn.add_theme_color_override("font_color", Color(0.92, 0.95, 0.97, 1))
	btn.add_theme_color_override("font_hover_color", Color(0.95, 0.98, 1.0, 1))
	btn.add_theme_color_override("font_pressed_color", Color(0.7, 0.95, 0.85, 1))


static func hp_color(ratio: float) -> Color:
	if ratio > 0.55:
		return Color(0.24, 0.81, 0.56, 1)
	if ratio > 0.25:
		return Color(0.9, 0.7, 0.35, 1)
	return Color(0.91, 0.33, 0.33, 1)
