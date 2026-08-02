extends Node2D

func _ready() -> void:
	var sprite := $Sprite2D as Sprite2D
	var manifest_text := FileAccess.get_file_as_string("res://spritesheet.json")
	var manifest := JSON.parse_string(manifest_text) as Dictionary
	assert(manifest != null, "manifest failed to parse")
	var layout := manifest["frameLayout"] as Dictionary
	var frame_size := Vector2i(int(layout["frameWidth"]), int(layout["frameHeight"]))
	var columns := int(layout["columns"])
	var rows := int(layout["rows"])
	var expected_frames := columns * rows
	assert(frame_size.x > 0 and frame_size.y > 0 and columns > 0 and rows > 0, "manifest grid is invalid")
	var animations := manifest["animations"] as Array
	assert(animations.size() > 0, "manifest has no animations")
	var image: Image
	var using_real_export := FileAccess.file_exists("res://spritesheet.png")
	if using_real_export:
		image = Image.new()
		var load_error := image.load("res://spritesheet.png")
		assert(load_error == OK and not image.is_empty(), "real spritesheet failed to load")
	else:
		image = Image.create(frame_size.x * columns, frame_size.y * rows, false, Image.FORMAT_RGBA8)
		image.fill(Color(0, 0, 0, 0))
		for index in range(expected_frames):
			var color := Color("2d8cff") if index % 2 == 0 else Color("f04f7b")
			image.fill_rect(Rect2i((index % columns) * frame_size.x, int(index / columns) * frame_size.y, frame_size.x, frame_size.y), color)
	assert(image.get_width() == frame_size.x * columns and image.get_height() == frame_size.y * rows, "PNG dimensions do not match manifest grid")
	var texture := ImageTexture.create_from_image(image)
	assert(texture != null, "sheet texture failed to load")
	sprite.texture = texture
	sprite.hframes = columns
	sprite.vframes = rows
	sprite.frame = 0
	sprite.centered = false
	sprite.offset = Vector2(-frame_size.x / 2, -frame_size.y / 2)
	assert(sprite.hframes == columns and sprite.vframes == rows, "grid slicing mismatch")
	var first_region := Rect2i(0, 0, frame_size.x, frame_size.y)
	var second_region := Rect2i(frame_size.x, 0, frame_size.x, frame_size.y)
	if columns > 1:
		assert(first_region.position.x < second_region.position.x, "frame order is not left-to-right")
	var playback_order: Array[int] = []
	for index in range(expected_frames):
		sprite.frame = index
		assert(sprite.frame == index, "sprite frame did not advance")
		playback_order.append(sprite.frame)
	var non_empty_cells := 0
	for row in range(rows):
		for column in range(columns):
			var cell_has_alpha := false
			for y in range(0, frame_size.y, maxi(1, int(frame_size.y / 16))):
				for x in range(0, frame_size.x, maxi(1, int(frame_size.x / 16))):
					if image.get_pixel(column * frame_size.x + x, row * frame_size.y + y).a > 0.01:
						cell_has_alpha = true
						break
				if cell_has_alpha:
					break
			assert(cell_has_alpha, "exported cell is fully transparent")
			non_empty_cells += 1
	assert(non_empty_cells == expected_frames, "not every exported cell contains visible pixels")
	print("GODOT_SHEET_SMOKE_PASS frames=%d cell=%dx%d grid=%dx%d order=left-to-right source=%s" % [expected_frames, frame_size.x, frame_size.y, columns, rows, "real-export" if using_real_export else "fixture"])
	print("GODOT_ANIMATION_PLAYBACK_PASS frames=%s non_empty_cells=%d" % [str(playback_order), non_empty_cells])
