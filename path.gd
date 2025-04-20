#@tool
extends Node3D           

@export var a: float     = 1000.0
@export var e: float     = 0.0
@export var samples: int = 360

var mesh_instance: MeshInstance3D

func _ready() -> void:                 # <-- leading underscore
	if mesh_instance == null:
		mesh_instance = MeshInstance3D.new()
		add_child(mesh_instance)
	mesh_instance.mesh = _build_orbit_mesh()

func _build_orbit_mesh() -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_LINE_STRIP)
	
	for k in range(samples + 1):       # <-- use range()
		var θ = TAU * k / samples
		var r = a * (1.0 - e * e) / (1.0 + e * cos(θ))
		st.add_vertex(Vector3(r * cos(θ), r * sin(θ), 0))
		
	return st.commit()
