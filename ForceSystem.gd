extends Node3D

@export var GravityBody_scene: PackedScene
@export var number_of_spheres: int = 3
@export var spawn_range: float = 5.0
@export var velocity_range: float = 5.0

@export var gravitational_constant: float = 10

var bodies: Array[RigidBody3D] = []

func _ready():
	spawn_spheres()

func spawn_spheres():
	for i in number_of_spheres:
		var GravityBody = GravityBody_scene.instantiate()
		var body := GravityBody as RigidBody3D
		

		
		
		body.global_position = Vector3(
			randf_range(-spawn_range, spawn_range),
			randf_range(-spawn_range, spawn_range),
			randf_range(-spawn_range, spawn_range)
		)
		body.linear_velocity = Vector3(
			randf_range(-velocity_range, velocity_range),
			randf_range(-velocity_range, velocity_range),
			randf_range(-velocity_range, velocity_range)
		)
		

		body.gravity_scale = 0.0

		add_child(GravityBody)
		bodies.append(body)

func _physics_process(delta):
	apply_gravity()

func apply_gravity():
	for i in range(bodies.size()):
		var a = bodies[i]
		for j in range(i + 1, bodies.size()):
			var b = bodies[j]

			var dir = b.global_position - a.global_position
			var dist_sq = max(dir.length_squared(), 0.01)
			var force_dir = dir.normalized()

			var force_mag = gravitational_constant * a.mass * b.mass / dist_sq
			var force = force_dir * force_mag

			a.apply_central_force(force)
			b.apply_central_force(-force)
