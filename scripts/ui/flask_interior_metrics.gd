class_name FlaskInteriorMetrics
extends RefCounted

## Cavity mask from user-marked guides on score_flask.png (576x1024).
## Constant vertical walls at guide width; semicircular floor on the same center axis.

const GUIDE_TEXTURE_HEIGHT := 1024
const GUIDE_TEXTURE_WIDTH := 576
const GUIDE_TOP_Y := 133
const GUIDE_BOTTOM_Y := 898
const GUIDE_CENTER_X := 287.5
const GUIDE_BODY_HALF_WIDTH := 56.0


static func build_cavity_mask(_image: Image) -> Image:
	var width := _image.get_width()
	var height := _image.get_height()
	var top_y := _scale_guide_y(GUIDE_TOP_Y, height)
	var bottom_y := _scale_guide_y(GUIDE_BOTTOM_Y, height)
	var center_x := _scale_guide_x(GUIDE_CENTER_X, width)
	var body_half_w := _scale_guide_x(GUIDE_BODY_HALF_WIDTH, width)
	var flat_y := maxi(top_y, bottom_y - int(round(body_half_w)))
	var wall_half_w := float(body_half_w)
	var sagitta := maxf(1.0, float(bottom_y - flat_y))
	var arc_radius := (wall_half_w * wall_half_w + sagitta * sagitta) / (2.0 * sagitta)
	var arc_center_y := float(flat_y) - arc_radius + sagitta
	var arc_radius_sq := arc_radius * arc_radius
	var body_left := maxi(0, int(floor(center_x - wall_half_w)))
	var body_right := mini(width - 1, int(ceil(center_x + wall_half_w)))

	var mask := Image.create(width, height, false, Image.FORMAT_L8)
	mask.fill(Color.BLACK)

	for y in range(top_y, bottom_y + 1):
		for x in range(body_left, body_right + 1):
			var dx := float(x) - center_x
			if y <= flat_y:
				if absf(dx) <= wall_half_w:
					mask.set_pixel(x, y, Color.WHITE)
				continue

			var dy := float(y) - arc_center_y
			if dx * dx + dy * dy <= arc_radius_sq:
				mask.set_pixel(x, y, Color.WHITE)

	return mask


static func measure_from_mask(mask: Image) -> Dictionary:
	var width := mask.get_width()
	var height := mask.get_height()
	var rows: Array[Dictionary] = []

	for y in height:
		var left := -1
		var right := -1
		for x in width:
			if mask.get_pixel(x, y).r > 0.5:
				if left == -1:
					left = x
				right = x
		if left != -1:
			rows.append({"y": y, "left": left, "right": right, "width": right - left})

	if rows.is_empty():
		return defaults()

	var mid_index := rows.size() / 2
	var mid_row: Dictionary = rows[mid_index]
	var top_row: Dictionary = rows[0]
	var bottom_row: Dictionary = rows[rows.size() - 1]
	var flat_row: Dictionary = top_row
	for row in rows:
		if row["width"] >= mid_row["width"] - 1:
			flat_row = row
		else:
			break

	return {
		"center_x": (float(mid_row["left"]) + float(mid_row["right"])) * 0.5 / float(width),
		"half_width": float(mid_row["width"]) * 0.5 / float(width),
		"interior_top": float(top_row["y"]) / float(height),
		"interior_flat_bottom": float(flat_row["y"]) / float(height),
		"interior_bottom": float(bottom_row["y"]) / float(height),
	}


static func measure_from_image(image: Image) -> Dictionary:
	return measure_from_mask(build_cavity_mask(image))


static func apply_to_material(
	material: ShaderMaterial,
	metrics: Dictionary,
	uv_aspect: float,
	texture_size: Vector2 = Vector2(576.0, 1024.0)
) -> void:
	material.set_shader_parameter("uv_aspect", uv_aspect)
	material.set_shader_parameter(
		"texture_uv_aspect",
		texture_size.x / maxf(texture_size.y, 1.0)
	)
	material.set_shader_parameter("interior_center_x", metrics.get("center_x", 0.498))
	material.set_shader_parameter("interior_half_width", metrics.get("half_width", 0.086))
	material.set_shader_parameter("interior_top", metrics.get("interior_top", 0.130))
	material.set_shader_parameter(
		"interior_flat_bottom",
		metrics.get("interior_flat_bottom", 0.830)
	)
	material.set_shader_parameter("interior_bottom", metrics.get("interior_bottom", 0.877))


static func texture_fit_rect(texture_size: Vector2, rect_size: Vector2) -> Dictionary:
	var texture_aspect := texture_size.x / maxf(texture_size.y, 1.0)
	var rect_aspect := rect_size.x / maxf(rect_size.y, 1.0)
	var uv_scale := Vector2.ONE
	var uv_offset := Vector2.ZERO

	if texture_aspect > rect_aspect:
		uv_scale = Vector2(1.0, rect_aspect / texture_aspect)
		uv_offset = Vector2(0.0, (1.0 - uv_scale.y) * 0.5)
	else:
		uv_scale = Vector2(texture_aspect / rect_aspect, 1.0)
		uv_offset = Vector2((1.0 - uv_scale.x) * 0.5, 0.0)

	return {"uv_scale": uv_scale, "uv_offset": uv_offset}


static func _scale_guide_y(guide_y: int, texture_height: int) -> int:
	return clampi(
		int(round(float(guide_y) * float(texture_height) / float(GUIDE_TEXTURE_HEIGHT))),
		0,
		texture_height - 1
	)


static func _scale_guide_x(guide_x: float, texture_width: int) -> int:
	return clampi(
		int(round(guide_x * float(texture_width) / float(GUIDE_TEXTURE_WIDTH))),
		0,
		texture_width - 1
	)


static func defaults() -> Dictionary:
	return {
		"center_x": 0.500,
		"half_width": 0.097,
		"interior_top": 0.130,
		"interior_flat_bottom": 0.822,
		"interior_bottom": 0.877,
	}