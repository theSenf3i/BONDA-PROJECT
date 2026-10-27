extends CanvasLayer

var game: Node
var tags: Dictionary = {}

func _ready() -> void:
	layer = 1
	process_priority = 20

func _process(_dt: float) -> void:
	for id in tags.keys():
		if not is_instance_valid(tags[id].source) or not tags[id].source.is_inside_tree():
			tags[id].label.queue_free()
			tags.erase(id)
	for source in get_tree().get_nodes_in_group("street_text"):
		var id = source.get_instance_id()
		if not tags.has(id):
			var label = Label.new()
			label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			label.add_theme_font_size_override("font_size", 20)
			label.add_theme_color_override("font_color", Color("fff1d4"))
			label.add_theme_color_override("font_outline_color", Color("101719"))
			label.add_theme_constant_override("outline_size", 5)
			var background = StyleBoxFlat.new()
			background.bg_color = Color(.035, .055, .06, .85)
			background.content_margin_left = 8
			background.content_margin_right = 8
			background.content_margin_top = 3
			background.content_margin_bottom = 3
			label.add_theme_stylebox_override("normal", background)
			add_child(label)
			tags[id] = {"source": source, "label": label}
	var camera = get_viewport().get_camera_3d()
	var occupied: Array[Rect2] = []
	var sorted = tags.values()
	if is_instance_valid(camera):
		sorted.sort_custom(func(a, b): return camera.global_position.distance_squared_to(a.source.global_position) < camera.global_position.distance_squared_to(b.source.global_position))
	for entry in sorted:
		var source: Label3D = entry.source
		var label: Label = entry.label
		label.hide()
		if not is_instance_valid(camera) or not game.street_filter.visible or game.paused or game.state != "play":
			continue
		if not source.is_visible_in_tree() or source.text.is_empty():
			continue
		var anchor = source.global_position
		var maximum = 13.0 if source.get_parent().has_meta("npc_id") else 20.0
		if camera.is_position_behind(anchor) or camera.global_position.distance_to(anchor) > maximum:
			continue
		var query = PhysicsRayQueryParameters3D.create(camera.global_position, anchor, 1)
		if is_instance_valid(game.player):
			query.exclude = [game.player.get_rid()]
		var hit = source.get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty() and hit.position.distance_to(anchor) > .35:
			continue
		label.text = source.text.replace(" • ", "\n")
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.size = label.get_minimum_size()
		var point = camera.unproject_position(anchor)
		var rect = Rect2(point - Vector2(label.size.x / 2, label.size.y), label.size)
		var viewport_size = get_viewport().get_visible_rect().size
		if rect.position.x < 8 or rect.end.x > viewport_size.x - 8 or rect.position.y < 132 or rect.end.y > viewport_size.y - 128:
			continue
		var overlap = false
		for other in occupied:
			if rect.grow(5).intersects(other):
				overlap = true
				break
		if overlap:
			continue
		label.position = rect.position.round()
		label.show()
		occupied.append(rect)
