extends Node3D

var gesture = 1.0
var model: Node3D
var arm_l: Node3D
var arm_r: Node3D
var leg_l: Node3D
var leg_r: Node3D
var head: Node3D
var walk_speed = 0.0
var phase = 0.0
var punch = 0.0
var hit = 0.0
var pose = "idle"

func tint_clothes(color: Color) -> void:
	for mesh in model.find_children("*", "MeshInstance3D", true, false):
		if mesh.name.begins_with("Torso") or mesh.name.begins_with("Sleeve") or mesh.name.begins_with("Barra"):
			var source = mesh.get_active_material(0)
			if source:
				var copy = source.duplicate()
				copy.albedo_color = color
				mesh.material_override = copy

func setup(kind: String) -> void:
	model = load("res://assets/models/" + kind + ".glb").instantiate()
	add_child(model)
	model.rotation.y = PI
	arm_l = model.find_child("ArmL", true, false)
	arm_r = model.find_child("ArmR", true, false)
	leg_l = model.find_child("LegL", true, false)
	leg_r = model.find_child("LegR", true, false)
	head = model.find_child("Head", true, false)

func _process(dt: float) -> void:
	if not is_instance_valid(model):
		return
	phase += dt * (8.0 if walk_speed > 0.1 else 1.8)
	punch = maxf(0, punch - dt * 3.8)
	hit = maxf(0, hit - dt * 3)
	var swing = sin(phase) * minf(walk_speed / 4, 1) * .65
	leg_l.rotation.x = swing
	leg_r.rotation.x = -swing
	arm_l.rotation.x = -swing * .7
	arm_r.rotation.x = swing * .7 - sin(punch * PI) * 1.9
	arm_l.rotation.z = .08
	arm_r.rotation.z = -.08
	model.position.y = absf(cos(phase)) * minf(walk_speed / 4, 1) * .035
	model.rotation.z = sin(hit * PI) * .15
	if pose == "block":
		arm_l.rotation.x = -1.2
		arm_r.rotation.x = -1.2
		arm_l.rotation.z = -.3
		arm_r.rotation.z = .3
	if pose == "talk":
		arm_l.rotation.x = -.4 + sin(phase * 1.7) * .16 * gesture
		head.rotation.y = sin(phase * .7) * .09
	if pose == "carry":
		arm_l.rotation.x = -1.05
		arm_r.rotation.x = -.75
	if pose == "hug":
		arm_l.rotation.x = -1.2
		arm_r.rotation.x = -1.2
