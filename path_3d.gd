##  OrbitVisualizer.gd  – attach to a Node3D in Godot 4.4.1
##  The script draws the orbit once in _ready()

extends Node3D

# ------------------------------------------------------------------  orbital elements
@export var a:      float = 10_000.0              # semi–major axis   (scene units)
@export var e:      float = 0.02                  # eccentricity
@export var i_deg:  float = 30.0                  # inclination       (deg)
@export var omega_deg: float = 40.0               # argument of periapsis (deg)
@export var RAAN_deg:  float = 15.0               # right ascension of AN (deg)

# visual settings ----------------------------------------------------
@export var samples: int   = 360                  # points around the ellipse
@export var line_color: Color = Color.AQUA
@export var line_unshaded: bool = true            # keep it bright

# ------------------------------------------------------------------  lifecycle
func _ready() -> void:
	var R_pqw_to_eci: Basis = _get_rotation_matrix_to_eci(
		deg_to_rad(RAAN_deg),
		deg_to_rad(i_deg),
		deg_to_rad(omega_deg)
	)

	var orbit_mesh := _build_orbit_mesh(R_pqw_to_eci)
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = orbit_mesh

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED if line_unshaded else BaseMaterial3D.SHADING_MODE_PER_PIXEL
	mat.albedo_color = line_color
	mesh_instance.material_override = mat

	add_child(mesh_instance)      # orbit now visible in the scene

# ------------------------------------------------------------------  helpers
func _build_orbit_mesh(rot: Basis) -> Mesh:
	# Uses SurfaceTool to create one line‑strip that follows the ellipse
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_LINE_STRIP)

	for step in samples + 1:                      # +1 to close the loop
		var θ := TAU * step / samples             # true anomaly
		var r := a * (1.0 - e * e) / (1.0 + e * cos(θ))
		var p_pqw := Vector3(r * cos(θ), r * sin(θ), 0)   # perifocal point
		var p_eci := rot * p_pqw                             # rotate into world frame
		st.add_vertex(p_eci)
	return st.commit()

func _get_rotation_matrix_to_eci(Ω: float, inc: float, ω: float) -> Basis:
	# Returns the PQW → ECI rotation (columns are the rotated basis vectors)
	var cosO = cos(Ω); var sinO = sin(Ω)
	var cosi = cos(inc); var sini = sin(inc)
	var cosw = cos(ω); var sinw = sin(ω)

	var x_axis = Vector3(
		cosO * cosw - sinO * sinw * cosi,
		sinO * cosw + cosO * sinw * cosi,
		sinw * sini
	)

	var y_axis = Vector3(
		-cosO * sinw - sinO * cosw * cosi,
		-sinO * sinw + cosO * cosw * cosi,
		cosw * sini
	)

	var z_axis = Vector3(
		sinO * sini,
		-cosO * sini,
		cosi
	)

	return Basis(x_axis, y_axis, z_axis)
