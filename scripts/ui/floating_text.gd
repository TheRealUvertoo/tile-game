class_name FloatingText
extends Label

## Floating text popup that drifts up and fades out, then self-destructs.

const RISE_PX := 80.0
const DURATION := 1.5


static func spawn(p_text: String, screen_pos: Vector2, parent: Control) -> void:
	var label := FloatingText.new()
	label.text = p_text
	label.position = screen_pos - Vector2(0, 20)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Style
	label.add_theme_font_size_override("font_size", 26)
	label.add_theme_color_override("font_color", Color(1, 0.95, 0.7))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	label.add_theme_constant_override("outline_size", 5)

	parent.add_child(label)

	# Center horizontally on spawn point
	label.pivot_offset = label.size * 0.5

	# Animate: rise + fade
	var tween := label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", screen_pos.y - RISE_PX - 20, DURATION) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(label, "modulate:a", 0.0, DURATION) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tween.chain().tween_callback(label.queue_free)
