extends Node

var g: Node
var results: Array = []

func check(label: String, ok: bool) -> void:
	results.append({"test": label, "passed": ok})
	print("PASS " if ok else "FAIL ", label)

func shot(label: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://tests/" + label + ".png")

func run(game: Node) -> void:
	g = game
	g.ui.show_menu(false)
	g.home_arrival_seen = true
	g.start_neighborhood()
	g.player.enabled = false
	g.ui.toast_time = 0
	g.cinema.current = true
	g.cinema.position = Vector3(-22, 3.6, 7.2)
	g.cinema.look_at(Vector3(-20, 1.7, 4))
	await get_tree().create_timer(.5).timeout
	var visible_names = 0
	for entry in g.street_labels.tags.values():
		if entry.label.visible and "Jean" in entry.label.text:
			visible_names += 1
	check("Nearby name is visible at native resolution", visible_names == 1)
	check("Names render above pixels and below HUD", g.street_labels.layer > g.street_filter.get_parent().layer and g.ui.layer > g.street_labels.layer)
	check("Original street labels do not duplicate pixelated text", get_tree().get_nodes_in_group("street_text").all(func(n): return n.layers == 0))
	await shot("v07_names")
	g.cinema.look_at(Vector3(-22, 3, 25))
	await get_tree().process_frame
	await get_tree().process_frame
	check("Names behind camera are hidden", g.street_labels.tags.values().all(func(e): return not g.cinema.is_position_behind(e.source.global_position) or not e.label.visible))
	g.pause_game(true)
	check("Pause menu is above names", g.ui.layer > g.street_labels.layer)
	g.pause_game(false)
	g.start_home()
	await get_tree().process_frame
	await get_tree().process_frame
	check("House transition clears street name overlays", g.street_labels.tags.is_empty())
	if "--labels-only" not in OS.get_cmdline_user_args():
		await test_limits()
		if "--limits-only" not in OS.get_cmdline_user_args():
			await test_traffic()
	var failed = results.filter(func(r): return not r.passed)
	var file = FileAccess.open("res://tests/street_fix_results.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(results, "\t"))
	print("FIX CHECKS: ", results.size() - failed.size(), "/", results.size())
	get_tree().quit(0 if failed.is_empty() else 1)

func test_limits() -> void:
	g.start_neighborhood()
	check("Playable street reduced to 104 meters", g.player.bounds.x == 52)
	check("Every NPC remains inside new limits", g.world.actors.all(func(a): return absf(a.position.x) + float(a.get_meta("span")) < 51))
	for side in [-1, 1]:
		g.player.position = Vector3(side * 50.8, .25, 5.6)
		g.player.orbit = -side * PI / 2
		g.player.camera_fixed = true
		Input.action_press("forward")
		Input.action_press("sprint")
		await get_tree().create_timer(.7).timeout
		Input.action_release("forward")
		Input.action_release("sprint")
		check("Physical invisible boundary blocks side " + str(side), absf(g.player.position.x) < 51.8 and absf(g.player.position.x) > 50.8)
	g.player.camera_fixed = false
	g.cinema.current = true
	g.cinema.position = Vector3(49, 2.4, 5.8)
	g.cinema.look_at(Vector3(130, 2.4, 2))
	await shot("v07_boundary")
	check("Distant street geometry and fog remain", g.world.has_node("StreetExtension") and g.street_fog.visible)


func test_traffic() -> void:
	g.start_neighborhood()
	g.player.enabled = false
	g.player.position = Vector3(-22, .22, 6)
	g.world.traffic_enabled = false
	g.world.set_physics_process(true)
	Engine.time_scale = 8.0
	var w = g.world
	check("Twelve cars circulate through the compact street", w.cars.size() == 12 and w.traffic_extent == 78)
	check("Cars and taxi have physical vehicle collision", w.cars.all(func(e): return e.node is CharacterBody3D and e.node.collision_layer == 2 and e.node.collision_mask == 2) and w.taxi is CharacterBody3D)
	var minimum_near_house = 100
	var no_overlap = true
	var wraps = 0
	for tick in range(675):
		var before: float = w.cars[0].node.position.x
		await get_tree().physics_frame
		if absf(before - w.cars[0].node.position.x) > 100:
			wraps += 1
		var nearby = 0
		for i in range(w.cars.size()):
			var a = w.cars[i].node
			if absf(a.position.x + 22) < 18:
				nearby += 1
			for j in range(i + 1, w.cars.size()):
				var b = w.cars[j].node
				if absf(a.position.z - b.position.z) < 1.86 and absf(a.position.x - b.position.x) < 3.99:
					no_overlap = false
		minimum_near_house = mini(minimum_near_house, nearby)
	check("Cars remain near home throughout ninety seconds", minimum_near_house >= 1)
	check("Traffic never overlaps during ninety seconds", no_overlap)
	print("DENSITY minimum=", minimum_near_house, " wraps=", wraps)
	check("Cars recirculate beyond the fog", wraps >= 2)
	var lead = w.cars[0]
	var follow = w.cars[2]
	for i in range(w.cars.size()):
		w.cars[i].node.position = Vector3(-60 + i * 10, 0, -18)
		w.cars[i].speed = 0.0
		w.cars[i].current_speed = 0.0
	lead.node.position = Vector3(0, 0, 1.3)
	follow.node.position = Vector3(-12, 0, 1.3)
	follow.speed = 10.0
	for tick in range(100):
		await get_tree().physics_frame
	check("Fast car brakes behind stopped car", follow.node.position.x < -4.7 and follow.node.position.x > -8)
	var stopped_phase: float = follow.node.get_meta("wheel_phase")
	for tick in range(30):
		await get_tree().physics_frame
	check("Stopped car wheels stop instead of spinning", absf(follow.node.get_meta("wheel_phase") - stopped_phase) < .03)
	lead.speed = 5.0
	var stopped_x: float = follow.node.position.x
	for tick in range(30):
		await get_tree().physics_frame
	print("QUEUE lead=", lead.node.position, " follow=", follow.node.position, " previous=", stopped_x)
	check("Queue moves again when leader leaves", follow.node.position.x > stopped_x + 3 and lead.node.position.x - follow.node.position.x >= 4.7)
	lead.node.position = Vector3(0, 0, 1.3)
	follow.node.position = Vector3(-10, 0, 1.3)
	w.set_physics_process(false)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var impact = follow.node.move_and_collide(Vector3(20, 0, 0))
	check("Physical sweep blocks a large movement through another car", impact != null and follow.node.position.x < -3.99)
	w.taxi.position = Vector3(0, 0, 3.35)
	follow.node.position = Vector3(-10, 0, 3.35)
	await get_tree().physics_frame
	await get_tree().physics_frame
	impact = follow.node.move_and_collide(Vector3(20, 0, 0))
	check("Physical sweep blocks traffic against taxi", impact != null and follow.node.position.x < -3.99)
	follow.node.position = Vector3(10, 0, 3.35)
	await get_tree().physics_frame
	await get_tree().physics_frame
	impact = w.taxi.move_and_collide(Vector3(20, 0, 0))
	check("Taxi cannot pass through another vehicle", impact != null and w.taxi.position.x < 6.01)
	w.taxi.position = Vector3(-8, 0, 3.35)
	g.player.position = Vector3(-8, .22, 5.5)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var pedestrian_hit = g.player.move_and_collide(Vector3(0, 0, -4))
	print("PLAYER collision=", pedestrian_hit, " position=", g.player.position)
	check("Player cannot walk through parked taxi", pedestrian_hit != null and g.player.position.z > 4.5)
	Engine.time_scale = 1.0
	g.start_neighborhood()
	g.player.position = Vector3(-22, .22, 6)
	g.ui.toast_time = 0
	g.player.orbit = 0
	g.player.pitch = -.22
	await get_tree().create_timer(.4).timeout
	await shot("v07_street")
	g.cinema.current = true
	g.cinema.position = Vector3(-28, 3.5, 5.5)
	g.cinema.look_at(Vector3(-10, 1.0, -2))
	await shot("v07_traffic")

