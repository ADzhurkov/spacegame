#@tool
extends Node3D           

@export var a: float     = 100.0
@export var e: float     = 0.5
@export var i_deg: float = 10
@export var RAAN_deg: float = 10
@export var omega_deg: float = 30
@export var samples: int = 360

var mesh_instance: MeshInstance3D

func _ready() -> void:                 # <-- leading underscore
	#---------------------------------------------
	# Create Orbit Plane
	#---------------------------------------------
	var orbit_mesh = draw_orbit(a,e,Color.AQUA)
	var reference_plane = draw_plane_from_normal(orbit_mesh.global_transform.basis.y.normalized(),Color.BLUE)
	
	var reference_plane_normal = orbit_mesh.global_transform.basis.y.normalized()
	
	#Rotate to get omega first
	var Omega_axis = Vector3(0,1,0)
	orbit_mesh.transform.basis = Basis(Omega_axis, deg_to_rad(omega_deg)) * orbit_mesh.transform.basis

	#Rotate to get inclination
	var axis = Vector3(1, 0, 0) # Or Vector3.RIGHT
	orbit_mesh.global_transform.basis = Basis(axis, deg_to_rad(i_deg)) * orbit_mesh.global_transform.basis
	
	#Rotate to get RAAN next
	var RAAN_axis = Vector3(0,1,0)
	orbit_mesh.global_transform.basis = Basis(RAAN_axis, deg_to_rad(RAAN_deg)) * orbit_mesh.global_transform.basis

	var orbit_normal = orbit_mesh.global_transform.basis.y.normalized()
	var plane1 = draw_plane_from_normal(orbit_mesh.global_transform.basis.y.normalized(),Color.RED)
	
	# (Mesh must already be in the scene and fully rotated)
	var peri_vec_local : Vector3 = Vector3(1,0,0)
	var rot_basis : Basis = orbit_mesh.global_transform.basis
	var peri_vec_world : Vector3 = rot_basis * peri_vec_local

	#-------------------------------------------------
	# Drawing Vectors
	#-------------------------------------------------
	
	draw_thick_line(peri_vec_world*50,Vector3.ZERO,Color.YELLOW_GREEN) # eccentricity vector

	draw_thick_line(Vector3(50,0,0),Vector3.ZERO,Color.RED) # X 
	#draw_thick_line(Vector3(0,0,50),Vector3.ZERO,Color.BLUE) # Z
	
	
	
	var theta_AN = deg_to_rad(-omega_deg)
	var r_AN = a * (1.0 - e * e) / (1.0 + e * cos(theta_AN))
	var RAAN_vec = reference_plane_normal.cross(orbit_normal).normalized()*r_AN*2

	draw_thick_line(RAAN_vec,Vector3.ZERO,Color.AQUA)
	var Along_vec = RAAN_vec.cross(-orbit_normal).normalized()
	var Tan_vec = RAAN_vec.cross(-reference_plane_normal).normalized()
	
	
	var b = a * sqrt(1.0 - e * e)

	var theta = deg_to_rad(360-omega_deg)     # true anomaly at ascending node
	var r = a * (1.0 - e * e) / (1.0 + e * cos(theta))

	# Point (x₀, y₀) on ellipse in the CENTERED frame
	var x0 = r * cos(theta) + a * e         # shift from focus to center
	var y0 = r * sin(theta)

	var t_c = Vector3(y0 * a * a,0 ,-x0 * b * b)
	
	var t_world = orbit_mesh.global_transform.basis * t_c.normalized()
	var along_world = t_world.cross(orbit_normal).normalized()
	
	var v_proj = (t_world - reference_plane_normal * t_world.dot(reference_plane_normal))
	v_proj = v_proj.normalized()
	#var Along_vec =  rot_basis * t_local
	draw_thick_line(t_world*10,RAAN_vec/2,Color.ALICE_BLUE)
	draw_thick_line(v_proj*10,RAAN_vec/2,Color.CORAL)
	
	
	var angle_rad = acos(t_world.dot(v_proj))
	var angle_deg = rad_to_deg(angle_rad)
	print("Inclination angle: ", angle_deg)
	
	var inc2_rad = acos(Along_vec.dot(Tan_vec))
	print("Inclination angle test: ", rad_to_deg(inc2_rad))
	#draw_thick_line(Along_vec*10,RAAN_vec/2,Color.ALICE_BLUE)
	#draw_thick_line(Tan_vec*10,RAAN_vec/2,Color.CORAL)
	
	
	#draw_inclination_arc(v_proj,along_world,RAAN_vec/2)
	
	var RAAN_vec_norm = RAAN_vec.normalized()
	var angle2_rad = acos(RAAN_vec_norm.dot(Vector3(1,0,0)))
	print("Right Ascenscion of Ascending Nodes: ", rad_to_deg(angle2_rad))
	draw_inclination_arc(Vector3(1,0,0),RAAN_vec/4,Vector3.ZERO)
	
	var angle3_rad = acos(RAAN_vec_norm.dot(peri_vec_world.normalized()))
	print("Argument of perigee: ", rad_to_deg(angle3_rad))
	draw_inclination_arc(peri_vec_world,RAAN_vec/4,Vector3.ZERO)
	
	
	

func draw_orbit(a: float, e: float, color: Color, samples := 360)-> MeshInstance3D:
	var points = get_ellipse_points(a, e, samples)

	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = points
	var colors = PackedColorArray()
	for i in points.size():
		colors.append(color)

	arrays[Mesh.ARRAY_VERTEX] = points
	arrays[Mesh.ARRAY_COLOR] = colors

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINE_STRIP, arrays)

	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	add_child(mi)
	return mi

func get_ellipse_points(a: float, e: float, samples: int) -> PackedVector3Array:
	var points = PackedVector3Array()
	var b = a * sqrt(1 - e * e)              # semi-minor axis (optional, for info)
	var p = a * (1 - e * e)                   # semi-latus rectum

	for i in range(samples + 1):
		var theta = TAU * i / samples
		var r = p / (1 + e * cos(theta))
		var x = r * cos(theta)
		var z = r * sin(theta)
		points.append(Vector3(x, 0, z))       # flat in XY plane
	return points


func draw_thick_line(target: Vector3,offset: Vector3, color:  Color = Color.AQUA, radius: float = 0.1) -> MeshInstance3D:

	# -- 0. Guard against zero‑length vectors
	if target.length_squared() == 0.0:
		push_warning("Target vector is zero; nothing drawn.")
		return null

	# -- 1. Build a cylinder mesh of the needed length
	var cyl := CylinderMesh.new()
	cyl.top_radius    = radius
	cyl.bottom_radius = radius
	cyl.height        = target.length()      # full length
	cyl.radial_segments = 16                 # smoothness

	# -- 2. Create a material so the colour shows even without lights
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color

	# -- 3. Instance and assign mesh & material
	var mi := MeshInstance3D.new()
	mi.mesh = cyl
	mi.material_override = mat

	# -- 4. ORIENT with a quaternion  (+Y  →  target direction)
	var dir_norm = target.normalized()
	var q = Quaternion(Vector3.UP, dir_norm)       # shortest‑arc rotation
	mi.global_position = offset
	#mi.global_position = (Vector3.UP + target) * 0.5
	mi.transform.basis = Basis(q)            # apply rotation

	# -- 5. TRANSLATE so bottom cap is at (0,0,0)
	#mi.translation = dir_norm * (cyl.height * 0.5)
	#
	add_child(mi)                            # add to the scene
	return mi

#Redunant function to get a plane normal
#func get_mesh_plane_normal(mi: MeshInstance3D) -> Vector3:
	#var mesh := mi.mesh
	#if mesh == null or mesh.get_surface_count() == 0:
		#return Vector3.ZERO
#
	## Grab vertices from the first surface
	#var arrays := mesh.surface_get_arrays(0)
	#var verts  := arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
	#if verts.size() < 3:
		#return Vector3.ZERO                 # not enough points
#
	## Local normal from any three non‑collinear points
	#var n_local := (verts[1] - verts[0]).cross(verts[2] - verts[0]).normalized()
#
	## Rotate into world space
	#return (mi.global_transform.basis * n_local).normalized()


# ---------------------------------------------------------------------------
#  Draw a curved arc that visualises the inclination angle
# ---------------------------------------------------------------------------
func draw_inclination_arc(ref_n       : Vector3,   # e.g. Vector3.UP
							orb_n       : Vector3,   # your orbit normal (world space)
							offset      : Vector3,
							arc_steps   : int   = 32,
							arc_color   : Color = Color.YELLOW) -> Node3D:

	# -- 1.  axis of rotation  (line of nodes)
	var axis = ref_n.cross(orb_n.normalized())
	if axis.length_squared() < 1e-8:
		push_warning("Planes are parallel – nothing to draw.")
		return null
	axis = axis.normalized()
	
	var orb_n_norm = orb_n.normalized()
	var ref_n_norm = ref_n.normalized()
	#var inc_rad = acos(orb_n_norm.dot(ref_n_norm))
	var dot_val = clamp(orb_n_norm.dot(ref_n_norm), -1.0, 1.0)
	var inc_rad = acos(dot_val)
	
	#print("Vector orb_n: ",orb_n_norm)
	#print("Vector ref_n: ",ref_n_norm)
	
	print("angle: ", rad_to_deg(inc_rad))
	
	var arc_radius = orb_n.length()*inc_rad
	# -- 2.  build points along the arc by slerping ref_n → orb_n
	var pts := PackedVector3Array()
	for i in range(arc_steps + 1):
		var t      = i / float(arc_steps)          # 0 … 1
		var q      = Quaternion(axis, inc_rad * t)       # shortest‑arc quaternion
		var dir    = q * ref_n                     # rotate ref_n
		pts.append(dir * arc_radius)               # point on the arc

	# -- 3.  create a coloured line‑strip mesh
	var colors = PackedColorArray()
	for i in pts.size():
		colors.append(arc_color)

	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = pts
	arrays[Mesh.ARRAY_COLOR]  = colors

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINE_STRIP, arrays)

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = arc_color

	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	add_child(mi)          # attach so it shows
	mi.global_position = offset
	# -- 4.  label at mid‑arc
	var mid_q   = Quaternion(axis, inc_rad * 0.5)
	var mid_pos = (mid_q * ref_n) * (arc_radius + 1.5)   # rotate by multiplying

	var lbl := Label3D.new()
	lbl.text        = str(round(rad_to_deg(inc_rad))) + "°"
	lbl.billboard   = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.global_position = offset+mid_pos
	#lbl.position    = mid_pos
	lbl.font_size   = 256
	add_child(lbl)

	return mi             # return the arc node (optional)


# ------------------------------------------------------------
#  Draw a transparent plane whose normal == `normal_vec`
#  Returns the MeshInstance3D so you can move / hide it later
# ------------------------------------------------------------
func draw_plane_from_normal(
	normal_vec : Vector3,                 # desired plane-normal (world)
	colour     : Color   = Color.BLUE,
	size       : float   = 120.0,         # width / height
	alpha      : float   = 0.05,          # 0 = invisible, 1 = opaque
	) -> MeshInstance3D:

	if normal_vec.length_squared() == 0.0:
		push_error("Normal vector is zero; cannot orient plane.")
		return null

	# --- 1.  Build the plane mesh (local +Y is its normal)
	var plane_mesh := PlaneMesh.new()
	plane_mesh.size = Vector2(size, size)

	# --- 2.  Un-shaded transparent material
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(colour.r, colour.g, colour.b, alpha)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	# --- 3.  Instance
	var plane := MeshInstance3D.new()
	plane.mesh              = plane_mesh
	plane.material_override = mat
	add_child(plane)

	# --- 4.  Rotate so local +Y aligns with the supplied normal
	var n_unit  = normal_vec.normalized()
	var q       = Quaternion(Vector3.UP, n_unit)     # shortest-arc rotation
	plane.transform.basis = Basis(q)                 # apply rotation
	# plane.position = Vector3.ZERO                  # keep at origin (change if needed)
	return plane



# ------------------------------------------------------------
#  Compute RAAN (ascending‑node) unit vector in world space
#  ref_n = reference‑plane normal (world +Y for Earth‑centric)
#  orb_n = orbit‑plane normal (world)
# ------------------------------------------------------------
func get_raan_vector(ref_n: Vector3, orb_n: Vector3) -> Vector3:
	var raan = ref_n.cross(orb_n)
	if raan.length_squared() == 0.0:
		return Vector3.ZERO
	return raan.normalized()


# ------------------------------------------------------------
# Get the rotation matrix from PQW to ECI
# ------------------------------------------------------------
func get_rotation_matrix_to_eci(RAAN: float, inc: float, omega: float) -> Basis:
	'''
	This function computes the rotation matrix from orbit plane (pqw) to inertial (eci)
	'''
	RAAN = deg_to_rad(RAAN)
	inc = deg_to_rad(inc)
	omega = deg_to_rad(omega)
	
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



	#var reference_plane := MeshInstance3D.new()
	#reference_plane.mesh  = PlaneMesh.new()
	#reference_plane.scale = Vector3(100, 1, 100)      # enlarge
	#add_child(reference_plane)
#
	## ---  make it semi‑transparent  ---
	#var mat := StandardMaterial3D.new()
	#mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED     # keep colour flat
	#mat.albedo_color = Color(0.2, 0.6, 1.0, 0.5)               #   RGBA (A = 0.25)
	#mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA        # enable blending
	#mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_ALWAYS      # avoid sorting glitches (optional)
#
	#reference_plane.material_override = mat
#
	#add_child(reference_plane)
