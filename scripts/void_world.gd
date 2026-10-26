extends "res://scripts/world.gd"

const STEP_COUNT = 80
const STEP_RISE = 0.22
const STEP_DEPTH = 1.05
const FLIGHT_STEPS = 20
const FLIGHT_LENGTH = FLIGHT_STEPS * STEP_DEPTH
const LANDING_LENGTH = 5.0
const PORTAL_POSITION = Vector3(0, 17.6, -110)
const SPAWN_POSITION = Vector3(0, 0.12, 12)

var route: Array[Vector3] = []
var rest_points: Array[Vector3] = []
var drifters: Array = []
var portal_surface: MeshInstance3D
var water_material: ShaderMaterial
var rng = RandomNumberGenerator.new()
var michael: Node3D
var michael_head: Node3D
var michael_arm: Node3D
var michael_talking = false
var michael_lift = 0.0
var michael_reaction = 0.0

func build(kind: String) -> void:
	scene_kind = kind
	rng.seed = 19890911
	water_material = ShaderMaterial.new()
	water_material.shader = load("res://shaders/void_water.gdshader")
	stairway()
	broken_home()
	mountain_lake(Vector3(-25, -4, -25), Vector3(25, 1, 18), 12.0)
	mountain_lake(Vector3(29, 10, -76), Vector3(24, 1, 16), 15.0)
	mountain_lake(Vector3(-35, 19, -103), Vector3(18, 1, 12), 9.0)
	impossible_city(Vector3(31, 8, -40), false)
	impossible_city(Vector3(-30, 30, -79), true)
	water_cord(Vector3(-21, 4, -44), Vector3(36, 14, -87), false)
	water_cord(Vector3(25, -4, -57), Vector3(-21, 11, -108), true)
	water_cord(Vector3(-45, 27, -115), Vector3(40, 37, -145), false)
	dead_nature(Vector3(-16, -1, -14), 1.25)
	dead_nature(Vector3(17, 11, -66), 1.6)
	dead_nature(Vector3(-13, 16, -93), 1.1)
	sky_objects()
	doorway()
	build_michael()

func stairway() -> void:
	box(self, Vector3(0, -0.55, 8), Vector3(12, 1.1, 22), Color("383e42"), true)
	box(self, Vector3(0, 0.01, 6), Vector3(0.035, 0.02, 20), Color("beb58f"))
	rest_points.append(SPAWN_POSITION)
	route.append(Vector3(0, 0.2, -2.3))
	var start_z = -3.0
	var base_y = 0.0
	var ends = [Vector2(0, -6), Vector2(-6, -6), Vector2(-6, 0), Vector2(0, 0)]
	for flight in range(4):
		var x0: float = ends[flight].x
		var x1: float = ends[flight].y
		var length = FLIGHT_LENGTH
		for step in range(FLIGHT_STEPS):
			var t = (step + 0.5) / FLIGHT_STEPS
			var center = Vector3(lerpf(x0, x1, t), base_y + (step + 1) * STEP_RISE - 0.24, start_z - (step + 0.5) * STEP_DEPTH)
			var tint = Color("5d6263") if step % 4 == 0 else Color("485256")
			box(self, center, Vector3(6.0, 0.48, STEP_DEPTH + 0.025), tint)
			var lip = box(self, center + Vector3(0, 0.245, STEP_DEPTH * 0.46), Vector3(5.9, 0.028, 0.055), Color("b7b5a1"))
			lip.material_override = material(Color("939d91"), "", 0.25)
			if step % 5 == 0:
				for side in [-1, 1]:
					var pin = box(self, center + Vector3(side * 2.85, 0.35, 0), Vector3(0.06, 0.2, 0.14), Color("e8ca99"))
					pin.material_override = material(Color("d6c498"), "", 1.4)
		ramp_collision(x0, x1, start_z, base_y)
		base_y += FLIGHT_STEPS * STEP_RISE
		start_z -= length
		var landing = Vector3(x1, base_y - 0.6, start_z - LANDING_LENGTH * 0.5)
		box(self, landing, Vector3(8.2, 1.2, LANDING_LENGTH), Color("454f54"), true)
		rest_points.append(landing + Vector3(0, 0.72, 0))
		route.append(landing + Vector3(0, 0.72, 0))
		for side in [-1, 1]:
			var post = Vector3(x1 + side * 3.65, base_y + 1.0, start_z - 2.5)
			box(self, post, Vector3(0.16, 2.0, 0.16), Color("7a8580"))
			box(self, post + Vector3(0, 1.05, 0), Vector3(0.32, 0.1, 0.32), Color("e1ca99")).material_override = material(Color("e1ca99"), "", 1.2)
		start_z -= LANDING_LENGTH
	box(self, Vector3(0, 17.0, -111), Vector3(12, 1.2, 12), Color("454e50"), true)
	route.append(Vector3(0, 17.72, -108))
	for i in range(17):
		var p = Vector3(rng.randf_range(-9, 9), rng.randf_range(-10, -3), rng.randf_range(-115, 15))
		var rock = box(self, p, Vector3(rng.randf_range(1, 3), rng.randf_range(0.8, 2.8), rng.randf_range(1, 3)), Color("29373d"))
		rock.rotation = Vector3(rng.randf(), rng.randf(), rng.randf())
		add_drifter(rock, 0.7, 0.13)

func ramp_collision(x0: float, x1: float, z: float, y: float) -> void:
	var body = StaticBody3D.new()
	var collision = CollisionShape3D.new()
	var shape = ConvexPolygonShape3D.new()
	var points = PackedVector3Array()
	for side in [-3.0, 3.0]:
		points.append(Vector3(x0 + side, y + 0.08, z + 0.04))
		points.append(Vector3(x1 + side, y + FLIGHT_STEPS * STEP_RISE + 0.02, z - FLIGHT_LENGTH - 0.04))
		points.append(Vector3(x0 + side, y - 0.8, z + 0.04))
		points.append(Vector3(x1 + side, y + FLIGHT_STEPS * STEP_RISE - 0.8, z - FLIGHT_LENGTH - 0.04))
	shape.points = points
	collision.shape = shape
	body.add_child(collision)
	add_child(body)

func broken_home() -> void:
	for side in [-1, 1]:
		for i in range(4):
			var p = Vector3(side * (6.1 + i * 0.8), 1.7 + i * 1.2, 16 - i * 4)
			var wall = box(self, p, Vector3(0.25, 3.8, 2.4), Color("6d6865"))
			wall.rotation = Vector3(0.15 * i, side * 0.2, side * -0.12 * i)
			add_drifter(wall, 0.5, 0.04)
	var door_frame = Node3D.new()
	add_child(door_frame)
	door_frame.position = Vector3(0, 0, 18.4)
	for x in [-1.6, 1.6]:
		box(door_frame, Vector3(x, 2.2, 0), Vector3(0.24, 4.4, 0.35), Color("979080"))
	box(door_frame, Vector3(0, 4.5, 0), Vector3(3.5, 0.25, 0.35), Color("979080"))
	box(door_frame, Vector3(0, 2.1, 0), Vector3(2.95, 4.2, 0.08), Color("050d12"), true)
	for i in range(13):
		var p = Vector3(rng.randf_range(-12, 12), rng.randf_range(2, 7), rng.randf_range(7, 22))
		var shard = box(self, p, Vector3(0.6, 0.12, 1.4), Color("7e746b"))
		shard.rotation = Vector3(rng.randf(), rng.randf(), rng.randf())
		add_drifter(shard, 0.85, 0.16)

func mountain_lake(pos: Vector3, size: Vector3, height: float) -> void:
	var island = Node3D.new()
	add_child(island)
	island.position = pos
	var lake = cylinder(island, Vector3.ZERO, 1, 0.12, Color("265452"))
	lake.scale = Vector3(size.x * 0.5, 1, size.z * 0.5)
	lake.mesh.radial_segments = 64
	lake.material_override = water_material
	var inverted = cylinder(island, Vector3(0, -3, 0), 0.3, 6, Color("172b32"), size.x * 0.4)
	inverted.scale.z = size.z / size.x
	for i in range(5):
		var x = rng.randf_range(-size.x * 0.26, size.x * 0.26)
		var z = rng.randf_range(-size.z * 0.24, size.z * 0.24)
		var h = height * rng.randf_range(0.45, 1)
		mountain(island, Vector3(x, 0.06, z), h * 0.42, h)
	add_drifter(island, 0.85, 0.025)

func mountain(parent: Node3D, pos: Vector3, radius: float, height: float) -> void:
	var tool = SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count = 7
	var peak = Vector3(radius * 0.12, height, -radius * 0.15)
	for i in range(count):
		var a = Vector3(cos(i * TAU / count) * radius, 0, sin(i * TAU / count) * radius)
		var b = Vector3(cos((i + 1) * TAU / count) * radius, 0, sin((i + 1) * TAU / count) * radius)
		var color = Color("557170").lerp(Color("bca994"), float(i % 3) / 3.0)
		for v in [a, peak, b]:
			tool.set_color(color)
			tool.add_vertex(v)
	tool.generate_normals()
	var mesh = MeshInstance3D.new()
	mesh.mesh = tool.commit()
	var mat = StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.roughness = 1
	mesh.material_override = mat
	parent.add_child(mesh)
	mesh.position = pos

func impossible_city(pos: Vector3, upside_down: bool) -> void:
	var city = Node3D.new()
	add_child(city)
	city.position = pos
	city.rotation.z = PI if upside_down else -0.16
	box(city, Vector3.ZERO, Vector3(19, 0.6, 11), Color("2c3a44"))
	for i in range(18):
		var x = (i % 6 - 2.5) * 3.2
		var z = (i / 6 - 1) * 3.6
		var h = rng.randf_range(3.0, 13.0)
		var building_node = box(city, Vector3(x, h * 0.5, z), Vector3(2.0, h, 2.6), Color("3f4b58"))
		building_node.rotation.z = rng.randf_range(-0.08, 0.08)
		for floor_index in range(int(h / 1.15)):
			for wx in [-0.5, 0.5]:
				if rng.randf() > 0.42:
					var window = box(city, Vector3(x + wx, 0.8 + floor_index * 1.1, z + 1.32), Vector3(0.25, 0.4, 0.04), Color("b39979"))
					window.material_override = material(Color("c2a488"), "", 0.7)
	add_drifter(city, 1.1, 0.035)

func water_cord(a: Vector3, b: Vector3, organic: bool) -> void:
	var points: Array[Vector3] = []
	var n = 60
	for i in range(n):
		var t = float(i) / (n - 1)
		var p = a.lerp(b, t)
		p += Vector3(sin(t * TAU * 2.0) * 4.5, sin(t * TAU * 1.5) * 6.0, cos(t * TAU * 2.0) * 3.0)
		points.append(p)
	var current = tube(points, 0.48 if organic else 0.8, Color("774e5a") if organic else Color("407e7f"), not organic)
	add_drifter(current, 0.8, 0.018)

func tube(points: Array[Vector3], radius: float, color: Color, is_water: bool = false) -> MeshInstance3D:
	var tool = SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sides = 7
	for i in range(points.size() - 1):
		var tangent = (points[i + 1] - points[i]).normalized()
		var normal = tangent.cross(Vector3.UP).normalized()
		if normal.length_squared() < 0.1:
			normal = Vector3.RIGHT
		var binormal = tangent.cross(normal).normalized()
		for side in range(sides):
			var a = float(side) * TAU / sides
			var b = float(side + 1) * TAU / sides
			var p0 = points[i] + radius * (normal * cos(a) + binormal * sin(a))
			var p1 = points[i] + radius * (normal * cos(b) + binormal * sin(b))
			var p2 = points[i + 1] + radius * (normal * cos(a) + binormal * sin(a))
			var p3 = points[i + 1] + radius * (normal * cos(b) + binormal * sin(b))
			var vertices = [p0, p2, p1, p1, p2, p3]
			var u0 = float(i) / (points.size() - 1)
			var u1 = float(i + 1) / (points.size() - 1)
			var v0 = float(side) / sides
			var v1 = float(side + 1) / sides
			var uvs = [Vector2(u0, v0), Vector2(u1, v0), Vector2(u0, v1), Vector2(u0, v1), Vector2(u1, v0), Vector2(u1, v1)]
			for vertex_index in range(6):
				tool.set_uv(uvs[vertex_index])
				tool.add_vertex(vertices[vertex_index] - points[0])
	tool.generate_normals()
	var mesh = MeshInstance3D.new()
	mesh.mesh = tool.commit()
	if is_water:
		var stream_material = ShaderMaterial.new()
		stream_material.shader = load("res://shaders/void_current.gdshader")
		mesh.material_override = stream_material
	else:
		mesh.material_override = material(color)
		mesh.material_override.cull_mode = BaseMaterial3D.CULL_DISABLED
	add_child(mesh)
	mesh.position = points[0]
	return mesh

func dead_nature(pos: Vector3, size: float) -> void:
	var previous_children = get_children()
	var pad = cylinder(self, pos - Vector3(0, 1.4, 0), 0.1, 3, Color("2c3039"), 3.2 * size)
	pad.rotation.z = 0.13
	var trunk: Array[Vector3] = [pos, pos + Vector3(0.3, 2, 0), pos + Vector3(-0.2, 5, 0), pos + Vector3(0.9, 8, 0)]
	for i in range(trunk.size()):
		trunk[i] = pos + (trunk[i] - pos) * size
	tube(trunk, 0.2 * size, Color("665760"))
	for side in [-1, 1]:
		for branch in range(3):
			var start = pos + Vector3(0, (2 + branch * 1.3) * size, 0)
			var pts: Array[Vector3] = [start, start + Vector3(side * 1.8, 1.3, 0.4) * size, start + Vector3(side * 2.2, 3.0, -0.2) * size]
			tube(pts, 0.08 * size, Color("77616a"))

	var grove = Node3D.new()
	add_child(grove)
	grove.position = pos
	for child in get_children():
		if child != grove and child not in previous_children:
			child.reparent(grove, true)
	add_drifter(grove, 0.55, 0.045)

func sky_objects() -> void:
	var moon = cylinder(self, Vector3(22, 45, -160), 16, 0.15, Color("b6aaa2"))
	moon.rotation.x = PI / 2
	moon.material_override = material(Color("b6aaa2"), "", 0.7)
	var eclipse = cylinder(self, Vector3(24, 46, -159.8), 14.5, 0.2, Color("08151d"))
	eclipse.rotation.x = PI / 2
	eclipse.material_override.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var sky_pair = Node3D.new()
	add_child(sky_pair)
	sky_pair.position = moon.position
	moon.reparent(sky_pair, true)
	eclipse.reparent(sky_pair, true)
	add_drifter(sky_pair, 0.65, 0.012)
	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var dot_mesh = SphereMesh.new()
	dot_mesh.radius = 0.035
	dot_mesh.height = 0.07
	dot_mesh.radial_segments = 4
	dot_mesh.rings = 2
	dot_mesh.material = material(Color("9cb6ad"), "", 0.9)
	mm.mesh = dot_mesh
	mm.instance_count = 160
	for i in range(mm.instance_count):
		var p = Vector3(rng.randf_range(-70, 70), rng.randf_range(-9, 65), rng.randf_range(-170, 25))
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, p))
	var stars = MultiMeshInstance3D.new()
	stars.multimesh = mm
	add_child(stars)
	add_drifter(stars, 0.3, 0.002)
	for i in range(10):
		var slab = box(self, Vector3(-55 + i * 12, 25 + sin(i * 2.1) * 7, -145 - i * 2), Vector3(7, 1, 4), Color("35424a"))
		slab.rotation = Vector3(0.2 * i, 0.4 * i, 0.7)
		add_drifter(slab, 1.3, 0.07)

func doorway() -> void:
	portal = Node3D.new()
	add_child(portal)
	portal.position = PORTAL_POSITION
	for x in [-2.5, 2.5]:
		box(portal, Vector3(x, 4.5, 0), Vector3(0.35, 9, 0.6), Color("d1c9b2"))
	box(portal, Vector3(0, 9, 0), Vector3(5.35, 0.35, 0.6), Color("d1c9b2"))
	portal_surface = box(portal, Vector3(0, 4.4, -0.08), Vector3(4.7, 8.8, 0.05), Color("f5eace"))
	portal_surface.material_override = material(Color("fff5d6"), "", 2.5)
	portal_surface.material_override.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for i in range(5):
		box(self, PORTAL_POSITION + Vector3(0, 0.025 + i * 0.001, 2 + i * 1.3), Vector3(4.5 + i * 0.7, 0.015, 0.24), Color("978b74"))
	var glow = OmniLight3D.new()
	add_child(glow)
	glow.position = PORTAL_POSITION + Vector3(0, 4, 3)
	glow.omni_range = 24
	glow.light_color = Color("ffddae")
	glow.light_energy = 3.3

func add_drifter(node: Node3D, amount: float, spin: float) -> void:
	drifters.append({"node": node, "base": node.position, "rotation": node.rotation, "phase": rng.randf_range(0, TAU), "amount": amount, "spin": spin})

func build_michael() -> void:
	michael = Node3D.new()
	add_child(michael)
	michael.position = Vector3(2.5, 0.1, 5.5)
	var black = Color("171820")
	var white = Color("dedfd9")
	var skin = Color("bca393")
	box(michael, Vector3(-0.17, 0.47, 0), Vector3(0.24, 0.8, 0.27), black)
	box(michael, Vector3(0.17, 0.47, 0), Vector3(0.24, 0.8, 0.27), black)
	for side in [-1, 1]:
		box(michael, Vector3(side * 0.17, 0.14, 0.015), Vector3(0.25, 0.16, 0.28), white)
		box(michael, Vector3(side * 0.17, 0.055, 0.10), Vector3(0.29, 0.11, 0.46), black)
	box(michael, Vector3(0, 1.19, 0), Vector3(0.68, 0.78, 0.35), black)
	box(michael, Vector3(0, 1.25, 0.184), Vector3(0.27, 0.64, 0.035), white)
	box(michael, Vector3(0, 0.91, 0.205), Vector3(0.10, 0.07, 0.04), Color("b4a282"))
	for side in [-1, 1]:
		var lapel = box(michael, Vector3(side * 0.18, 1.43, 0.205), Vector3(0.13, 0.38, 0.06), black)
		lapel.rotation.z = side * 0.22
		box(michael, Vector3(side * 0.43, 1.15, 0), Vector3(0.22, 0.65, 0.26), black)
		for i in range(4):
			box(michael, Vector3(side * 0.27, 1.44 - i * 0.12, 0.19), Vector3(0.035, 0.035, 0.035), Color("a8b8bc"))
	box(michael, Vector3(-0.43, 0.77, 0.04), Vector3(0.16, 0.22, 0.18), skin)
	michael_arm = Node3D.new()
	michael.add_child(michael_arm)
	michael_arm.position = Vector3(0.43, 1.2, 0)
	box(michael_arm, Vector3(0, -0.42, 0.06), Vector3(0.19, 0.25, 0.2), white)
	michael_head = Node3D.new()
	michael.add_child(michael_head)
	michael_head.position.y = 1.66
	orb(michael_head, Vector3(0, 0.15, 0), Vector3(0.48, 0.56, 0.4), skin)
	orb(michael_head, Vector3(0, 0.20, -0.075), Vector3(0.53, 0.60, 0.37), black)
	box(michael_head, Vector3(0, 0.10, 0.205), Vector3(0.36, 0.075, 0.045), black)
	for side in [-1, 1]:
		orb(michael_head, Vector3(side * 0.23, -0.01, -0.05), Vector3(0.13, 0.35, 0.20), black)
	var brim = cylinder(michael_head, Vector3(0, 0.42, 0.025), 0.39, 0.045, black)
	brim.scale.z = 0.85
	var crown = cylinder(michael_head, Vector3(0, 0.53, 0), 0.24, 0.23, black, 0.21)
	crown.scale.z = 0.85
	var band = cylinder(michael_head, Vector3(0, 0.46, 0), 0.245, 0.055, Color("9b9b92"))
	band.scale.z = 0.85
	var light = OmniLight3D.new()
	michael.add_child(light)
	light.position = Vector3(0, 2.6, 0.9)
	light.light_color = Color("cedbd2")
	light.light_energy = 1.2
	light.omni_range = 6.0
	var body = StaticBody3D.new()
	michael.add_child(body)
	var collision = CollisionShape3D.new()
	body.add_child(collision)
	var capsule = CapsuleShape3D.new()
	capsule.radius = 0.38
	capsule.height = 1.9
	collision.shape = capsule
	collision.position.y = 0.95

func _process(dt: float) -> void:
	clock += dt
	for item in drifters:
		var phase: float = item.phase
		var amount: float = item.amount
		item.node.position = item.base + Vector3(sin(clock * 0.29 + phase) * amount * 0.55, sin(clock * 0.62 + phase) * amount, cos(clock * 0.23 + phase) * amount * 0.42)
		item.node.rotation = item.rotation + Vector3(sin(clock * 0.23 + phase), sin(clock * 0.17 + phase * 0.7), cos(clock * 0.31 + phase)) * float(item.spin)
	if is_instance_valid(michael):
		michael.position.y = 0.1 + michael_lift + sin(clock * 1.25) * 0.09
		michael_reaction = maxf(0, michael_reaction - dt)
		michael_head.rotation.z = sin(clock * 0.8) * 0.035 - sin(michael_reaction * PI) * 0.22
		michael_arm.rotation.x = -0.18 - (sin(clock * 2.2) * 0.13 if michael_talking else 0.0) - sin(michael_reaction * PI) * 0.7
		if is_instance_valid(pedestrian):
			var direction = pedestrian.position - michael.position
			michael.rotation.y = lerp_angle(michael.rotation.y, atan2(direction.x, direction.z), dt * 2.0)
