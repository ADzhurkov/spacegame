extends MeshInstance3D

#@onready var body = $OrbitBody


@export var a: float = 1000.0  
@export var i: float = 0 
@export var e: float = 0.001 
@export var omega: float = 0 
@export var RAAN: float = 0 
@export var mu: float = 3.98600*10**5 #km^3 / s^2 

var t: float
var n: float
var M: float
var E: float

var theta: float

var r_mag: float
var v_mag: float

var r_pqw: Vector3
var v_pqw: Vector3

var r: Vector3
var v: Vector3


var Rot_Matrix_PQW_ECI: Basis
var Rot_Matrix_ECI_PQW: Basis

# visual settings ----------------------------------------------------
@export var samples: int   = 360                  # points around the ellipse
@export var line_color: Color = Color.AQUA
@export var line_unshaded: bool = true            # keep it bright


func _ready():
	n = sqrt(mu / pow(a, 3))
	Rot_Matrix_PQW_ECI = get_rotation_matrix_to_eci(RAAN,i,omega)
	Rot_Matrix_ECI_PQW = Rot_Matrix_PQW_ECI.transposed()

#
	#var orbit_mesh := _build_orbit_mesh(Rot_Matrix_PQW_ECI)
	#var mesh_instance := MeshInstance3D.new()
	#mesh_instance.mesh = orbit_mesh
#
	#var mat := StandardMaterial3D.new()
	#mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED if line_unshaded else BaseMaterial3D.SHADING_MODE_PER_PIXEL
	#mat.albedo_color = line_color
	#mesh_instance.material_override = mat
#
	#add_child(mesh_instance)      # orbit now visible in the scene

func _physics_process(delta):
	#translate(Vector3(speed * delta, 0, 0))
	t += delta
	M = n*t #assuming at 0 we are at pericenter
	E = Newton_Raphson(M,e)
	theta = eccentric_to_true_anomaly(E,e)
	r_mag = radius_from_true_anomaly(theta,a,e)
	v_mag = speed_from_radius(r_mag,a,mu)
	
	r_pqw = Vector3(r_mag * cos(theta), r_mag * sin(theta), 0)
	v_pqw = Vector3(-v_mag * sin(theta), v_mag * (e + cos(theta)), 0) #no clue how this is derived tbh
	
	r = Rot_Matrix_PQW_ECI*r_pqw
	v = Rot_Matrix_PQW_ECI*v_pqw
	
	translate(v*delta)
	
	
	
# ------------------------------------------------------------------  helpers
func _build_orbit_mesh(rot: Basis) -> Mesh:
	# Uses SurfaceTool to create one line‑strip that follows the ellipse
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_LINE_STRIP)

	for step in samples + 1:                      # +1 to close the loop
		var θ := TAU * step / samples             # true anomaly
		var r := a * (1.0 - e * e) / (1.0 + e * cos(θ))
		var p_pqw := Vector3(r * cos(θ), r * sin(θ), 0)   # perifocal point

		st.add_vertex(p_pqw)
	return st.commit()

	
	
func Newton_Raphson(M: float, e: float, tolerance := 1e-6, max_iter := 10) -> float:
	var E = M  # Initial guess
	for i in range(max_iter):
		var f = E - e * sin(E) - M
		var f_prime = 1 - e * cos(E)
		var delta_E = f / f_prime
		E -= delta_E
		if abs(delta_E) < tolerance:
			break
	return E
	
	
func eccentric_to_true_anomaly(E: float, e: float) -> float:
	var tan_half_theta = sqrt((1 + e) / (1 - e)) * tan(E / 2)
	var theta = 2 * atan(tan_half_theta)
	return theta

func radius_from_true_anomaly(theta: float, a: float, e: float) -> float:
	return a * (1 - e * e) / (1 + e * cos(theta))

func speed_from_radius(r: float, a: float, mu: float) -> float:
	return sqrt(mu * (2.0 / r - 1.0 / a))

func get_rotation_matrix_to_eci(RAAN: float, inc: float, omega: float) -> Basis:
	'''
	This function computes the rotation matrix from orbit plane (pqw) to inertial (eci)
	'''
	var cosO = cos(RAAN)
	var sinO = sin(RAAN)
	var cosi = cos(inc)
	var sini = sin(inc)
	var cosw = cos(omega)
	var sinw = sin(omega)

	#Check if these are correct? 
	var x_axis = Vector3(
		cosO * cosw - sinO * sinw * cosi,
		sinO * cosw + cosO * sinw * cosi,
		sinw * sini
	)

	var y_axis = Vector3(
		- cosO * sinw - sinO * cosw * cosi,
		- sinO * sinw + cosO * cosw * cosi,
		cosw * sini
	)

	var z_axis = Vector3(
		- sinO * sini,
		cosO * sini,
		cosi
	)

	return Basis(x_axis, y_axis, z_axis)
