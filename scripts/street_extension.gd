extends Node3D

const LIMIT_X = 52.0
const LIMIT_Z = 25.0

func barrier(label: String, pos: Vector3, size: Vector3) -> void:
	var body = StaticBody3D.new()
	body.name = label
	add_child(body)
	body.position = pos
	var collider = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	body.add_child(collider)

func build(w: Node3D) -> void:
	barrier("EastLimit", Vector3(LIMIT_X, 15, 0), Vector3(.4, 40, 60))
	barrier("WestLimit", Vector3(-LIMIT_X, 15, 0), Vector3(.4, 40, 60))
	barrier("NorthLimit", Vector3(0, 15, -LIMIT_Z), Vector3(680, 40, .4))
	barrier("SouthLimit", Vector3(0, 15, LIMIT_Z), Vector3(680, 40, .4))
	var rng = RandomNumberGenerator.new()
	rng.seed = 6002
	for x in range(-324, 325, 14):
		if abs(x) < 57:
			continue
		for side in [-1, 1]:
			var height = rng.randf_range(4, 11)
			var base = Color("535b57") if side > 0 else Color("635d58")
			w.box(self, Vector3(x, height / 2, side * 13), Vector3(10, height, 8), base, abs(x) < 185, "plaster")
			w.box(self, Vector3(x, height + .1, side * 13), Vector3(10.5, .25, 8.5), Color("363f40"))
			w.box(self, Vector3(x, 1.3, side * 8.94), Vector3(1.4, 2.6, .12), Color("272e2d"))
			for window_x in [-2.8, 2.8]:
				w.box(self, Vector3(x + window_x, 2.9, side * 8.9), Vector3(1.6, 1.8, .15), Color("777a64"))
		if abs(x) < 210 and x % 28 == 0:
			w.lamp(Vector3(x + 3, 0, -5.8))
