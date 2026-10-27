extends CharacterBody3D

var actor: Node3D
var enabled = false
var orbit = 0.0
var pitch = -.25
var distance = 5.5
var camera: Camera3D
var yaw_pivot: Node3D
var pitch_pivot: Node3D
var arm: SpringArm3D
var sprint = false
var block = false
var bounds = Vector2(55, 25)
var camera_fixed = false
var dash_time = 0.0
var dash_cooldown = 0.0
var step_clock = 0.0
var manual_walk_speed = 0.0
var walk_speed = 4.3
var run_speed = 6.3
var reset_on_fall = true
signal step

func _ready() -> void:
	collision_mask = 3
	var collision = CollisionShape3D.new()
	var capsule = CapsuleShape3D.new()
	capsule.radius = .32
	capsule.height = 1.82
	collision.shape = capsule
	collision.position.y = .92
	add_child(collision)
	actor = load("res://scripts/actor.gd").new()
	add_child(actor)
	actor.setup("vito")
	yaw_pivot = Node3D.new()
	add_child(yaw_pivot)
	yaw_pivot.position.y = 1.35
	pitch_pivot = Node3D.new()
	yaw_pivot.add_child(pitch_pivot)
	arm = SpringArm3D.new()
	arm.spring_length = distance
	arm.margin = .22
	arm.add_excluded_object(get_rid())
	pitch_pivot.add_child(arm)
	camera = Camera3D.new()
	camera.fov = 62
	camera.near = .08
	arm.add_child(camera)
	camera.current = true
	floor_snap_length = .35
	floor_max_angle = deg_to_rad(50)

func _unhandled_input(event: InputEvent) -> void:
	if enabled and not camera_fixed:
		if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			orbit -= event.relative.x * .003
			pitch = clampf(pitch - event.relative.y * .0025, -.95, .2)
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				distance = maxf(2.6, distance - .35)
			if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				distance = minf(9, distance + .35)

func _physics_process(dt: float) -> void:
	dash_cooldown = maxf(0, dash_cooldown - dt)
	dash_time = maxf(0, dash_time - dt)
	if enabled and not camera_fixed:
		orbit += Input.get_axis("cam_right", "cam_left") * dt * 1.7
	yaw_pivot.rotation.y = orbit
	pitch_pivot.rotation.x = pitch
	arm.spring_length = lerpf(arm.spring_length, distance, dt * 8)
	if not is_on_floor():
		velocity.y -= 19 * dt
	if not enabled:
		velocity.x = move_toward(velocity.x, 0, 25 * dt)
		velocity.z = move_toward(velocity.z, 0, 25 * dt)
		actor.walk_speed = manual_walk_speed
		move_and_slide()
		return
	var input = Input.get_vector("left", "right", "forward", "back")
	var dir = Vector3(input.x, 0, input.y).rotated(Vector3.UP, orbit)
	block = Input.is_action_pressed("block")
	var speed = 2.3 if block else (run_speed if Input.is_action_pressed("sprint") else walk_speed)
	if Input.is_action_just_pressed("dash") and dash_cooldown <= 0 and dir.length() > .2:
		dash_time = .19
		dash_cooldown = .95
	if dash_time > 0:
		speed = 13
	velocity.x = move_toward(velocity.x, dir.x * speed, dt * 30)
	velocity.z = move_toward(velocity.z, dir.z * speed, dt * 30)
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = 7.2
	if dir.length() > .15:
		actor.rotation.y = lerp_angle(actor.rotation.y, atan2(-dir.x, -dir.z), dt * 13)
	var grounded = is_on_floor()
	move_and_slide()
	if grounded and dir.length() > .1 and get_slide_collision_count() > 0:
		for i in range(get_slide_collision_count()):
			var collision_info = get_slide_collision(i)
			if absf(collision_info.get_normal().y) < .2:
				var raised = global_transform
				raised.origin.y += .22
				if not test_move(raised, dir * .25):
					position.y += .22
					break
	position.x = clampf(position.x, -bounds.x, bounds.x)
	position.z = clampf(position.z, -bounds.y, bounds.y)
	if reset_on_fall and position.y < -5:
		position.y = 1
		velocity = Vector3.ZERO
	actor.walk_speed = Vector2(velocity.x, velocity.z).length()
	actor.pose = "block" if block else "idle"
	if actor.walk_speed > .5 and is_on_floor():
		step_clock += dt
		if step_clock > .42 * (4.3 / maxf(actor.walk_speed, 1)):
			step_clock = 0
			step.emit()

func face(pos: Vector3) -> void:
	var d = pos - global_position
	actor.rotation.y = atan2(-d.x, -d.z)
