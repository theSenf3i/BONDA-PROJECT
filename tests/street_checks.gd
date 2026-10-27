extends Node

var results: Array = []
var g: Node

func check(label: String, ok: bool) -> void:
	results.append({"test": label, "passed": ok})
	print("PASS " if ok else "FAIL ", label)

func run(game: Node) -> void:
	g = game
	g.ui.show_menu(false)
	g.home_arrival_seen = true
	g.start_home()
	g.player.position = g.world.home.tasks[0].node.position
	g.interact()
	check("Cleanup remains instant and playable", g.state == "play" and g.player.enabled and g.home_cleaned.size() == 1)
	check("Context remark lasts at most two seconds", g.ui.toast_time <= 2.0 and "Robson" in g.ui.toast.text)
	await get_tree().create_timer(2.15).timeout
	check("Cleanup text fully disappears after two seconds", g.ui.toast.modulate.a == 0)
	g.player.position = g.world.home.tasks[5].node.position
	g.interact()
	check("Basic cleanup feedback lasts one second", g.ui.toast_time <= 1.0 and g.ui.toast.text == "Pronto.")
	g.player.position = Vector3(0, .1, 4.5)
	g.interact()
	check("Leaving home remains immediate", g.stage == "neighborhood")
	await test_extended_street()
	await test_street_style()
	await test_vehicle_motion()
	await finish()

func finish() -> void:
	var failed = results.filter(func(r): return not r.passed)
	var f = FileAccess.open("res://tests/street_results.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(results, "\t"))
	f.close()
	print("STREET CHECKS: ", results.size() - failed.size(), "/", results.size())
	get_tree().quit(0 if failed.is_empty() else 1)

func test_extended_street() -> void:
	check("Street is 360 meters wide and has geometry beyond limits", g.player.bounds.x == 180 and g.world.extended_street and g.world.traffic_extent > 180)
	var edge = g.world.get_node("StreetExtension/EastLimit")
	check("Boundary uses only invisible collision", edge is StaticBody3D and edge.get_child_count() == 1 and edge.get_child(0) is CollisionShape3D)
	check("Fog conceals distant continuation", g.void_environment.environment.fog_enabled and g.void_environment.environment.fog_density >= .02)
	g.world.traffic_enabled = false
	g.player.position = Vector3(178.8, .25, 5.6)
	g.player.orbit = -PI / 2
	g.player.camera_fixed = true
	Input.action_press("forward")
	Input.action_press("sprint")
	await get_tree().create_timer(.7).timeout
	Input.action_release("forward")
	Input.action_release("sprint")
	check("East boundary stops physical movement", g.player.position.x < 179.8 and g.player.position.x > 178.8)
	g.player.position = Vector3(-178.8, .25, 5.6)
	g.player.orbit = PI / 2
	Input.action_press("forward")
	await get_tree().create_timer(.7).timeout
	Input.action_release("forward")
	check("West boundary stops physical movement", g.player.position.x > -179.8 and g.player.position.x < -178.8)
	g.player.camera_fixed = false
	g.player.position = Vector3(-8, .2, 5.5)
	check("Taxi stays close to house route", g.world.taxi.position.distance_to(Vector3(-22, 0, 7.6)) < 18)

func snapshot(label: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://tests/" + label + ".png")

func test_street_style() -> void:
	g.player.position = Vector3(-22, .22, 6)
	g.player.orbit = -1.1
	g.player.pitch = -.12
	g.ui.toast_time = 0
	await get_tree().create_timer(.2).timeout
	check("Pixel shader enabled only over street", g.street_filter.visible and not g.void_filter.visible)
	check("HUD remains above pixel effect", g.ui.layer > g.street_filter.get_parent().layer)
	check("Street has worn buildings and dark lighting", g.world.has_node("StreetDressing") and g.void_sun.light_energy < .5)
	await snapshot("street_gameplay")
	g.cinema.current = true
	g.cinema.position = Vector3(-31, 3.5, 6.5)
	g.cinema.look_at(Vector3(35, 2, -1))
	await snapshot("street_long_view")
	g.cinema.position = Vector3(176, 2.4, 5.8)
	g.cinema.look_at(Vector3(260, 2.4, 2))
	await snapshot("street_fog_boundary")
	g.start_home()
	check("House restores original visuals", not g.street_filter.visible and g.void_environment.environment.background_mode == Environment.BG_SKY)
	g.void_intro_seen = true
	g.start_void()
	check("Void retains VHS instead of street shader", g.void_filter.visible and not g.street_filter.visible)
	g.to_menu()
	check("Main menu does not inherit street shader", not g.street_filter.visible)

func test_vehicle_motion() -> void:
	g.ui.show_menu(false)
	g.start_neighborhood()
	g.world.traffic_enabled = false
	var car: Node3D = g.world.cars[0].node
	var reverse: Node3D = g.world.cars[1].node
	var wheels: Array = car.get_meta("wheels")
	check("Cars have four independent wheel pivots", wheels.size() == 4)
	var angle: float = wheels[0].rotation.z
	var reverse_x: float = reverse.position.x
	var body: Node3D = car.get_meta("body")
	var body_position: Vector3 = body.position
	await get_tree().create_timer(.23).timeout
	check("Moving cars rotate their wheels", not is_equal_approx(wheels[0].rotation.z, angle))
	check("Moving car body has suspension motion", not body.position.is_equal_approx(body_position))
	check("Opposite lane moves in its own direction", reverse.position.x < reverse_x)
	var taxi: Node3D = g.world.taxi
	var taxi_wheels: Array = taxi.get_meta("wheels")
	angle = taxi_wheels[0].rotation.z
	await get_tree().create_timer(.15).timeout
	check("Parked taxi does not spin wheels", is_equal_approx(taxi_wheels[0].rotation.z, angle))
	g.start_taxi()
	var taxi_x: float = taxi.position.x
	await get_tree().create_timer(.3).timeout
	check("Taxi moves and spins wheels during ride", taxi.position.x > taxi_x and not is_equal_approx(taxi_wheels[0].rotation.z, angle))
	var taxi_body: Node3D = taxi.get_meta("body")
	check("Taxi body uses suspension", not is_zero_approx(taxi_body.rotation.z))
	g.cinema.position = taxi.position + Vector3(4.5, 2.1, 5.2)
	g.cinema.look_at(taxi.position + Vector3(0, .8, 0))
	await snapshot("street_taxi_motion")
	g.pause_game(true)
	var paused_angle: float = taxi_wheels[0].rotation.z
	var paused_position: Vector3 = taxi.position
	await get_tree().create_timer(.15, true).timeout
	check("Pause freezes car translation and animation", taxi.position.is_equal_approx(paused_position) and is_equal_approx(taxi_wheels[0].rotation.z, paused_angle))
	g.pause_game(false)
	g.world.taxi_progress = 28
	g.world.taxi.position.x = 20
	angle = taxi_wheels[0].rotation.z
	await get_tree().create_timer(.15).timeout
	check("Taxi wheels stop at end of route", is_equal_approx(taxi_wheels[0].rotation.z, angle))
