#@tool
extends Node3D           

@export var a: float     = 100.0
@export var e: float     = 0.5
@export var i_deg: float = 45
@export var RAAN_deg: float = 45
@export var omega_deg: float = 45
@export var samples: int = 360

var mesh_instance: MeshInstance3D



func _ready() -> void:  
	# connect to the UI signal
	#_rebuild_orbit(100,0,45,0,0)
	var ui := get_parent().get_node("UI")
	ui.orbit_changed.connect(_rebuild_orbit)

	
#------------------------------------------------------------------
# Functions
#------------------------------------------------------------------

func _rebuild_orbit(a: float, e: float,
					i_deg: float, omega_deg: float, RAAN_deg: float) -> void:
	
	#---------------------------------------------
	# Create Orbit Plane
	#---------------------------------------------
	var old = get_node_or_null("OrbitMesh")
	var old_drawings = get_node_or_null("WorldBasedDrawings")
	if old:
		old.free()
		old = null
	if old_drawings:
		old_drawings.free()
		old_drawings = null
	
	var world_drawings = Node3D.new()
	add_child(world_drawings)
	world_drawings.name = "WorldBasedDrawings"
	
	var orbit_mesh = draw_orbit_thick(a,e,Color.AQUA)
	orbit_mesh.name = "OrbitMesh"
	#var reference_plane = draw_plane_from_normal(Vector3.UP,Color.BLUE)
	
	var reference_plane_normal = Vector3.UP
	
	#rotate orbit mesh
	orbit_mesh = rotate_orbit(orbit_mesh,omega_deg,RAAN_deg,i_deg)
	var orbit_normal = orbit_mesh.global_transform.basis.y.normalized()
	
	var peri_vec_local : Vector3 = Vector3(1,0,0)
	var rot_basis : Basis = orbit_mesh.global_transform.basis
	var peri_vec_world : Vector3 = Vector3.ZERO
	#if e == 0:
	#	peri_vec_world = rot_basis * peri_vec_local*a*2
	#else:
	peri_vec_world = rot_basis * peri_vec_local*a*(1-e)

	## Draw X and Z axis
	#draw_thick_line(Vector3(50,0,0),Vector3.ZERO,Color.RED) # X 
	#draw_thick_line(Vector3(0,0,50),Vector3.ZERO,Color.BLUE) # Z


	#-------------------------------------------------
	# Compute RAAN Vector
	#-------------------------------------------------
	var theta_AN = deg_to_rad(omega_deg)
	var r_AN = a * (1.0 - e * e) / (1.0 + e * cos(theta_AN))
	var theta_DN = deg_to_rad(180-omega_deg)
	var r_DN = a * (1.0 - e * e) / (1.0 + e * cos(theta_DN))
	var RAAN_vec = reference_plane_normal.cross(orbit_normal).normalized()*r_AN
	
	
	if RAAN_vec == Vector3.ZERO:
		RAAN_vec = Vector3(1,0,0)*r_AN
		

	#-------------------------------------------------	
	# Compute Tangent to Ellipse at RAAN Vector
	#-------------------------------------------------
	#var b = a * sqrt(1.0 - e * e)
#
	## Point (x₀, y₀) on ellipse in the CENTERED frame
	#var x0 = r_AN * cos(theta_AN) + a * e         # shift from focus to center
	#var y0 = r_AN * sin(theta_AN)
	#var t_c = Vector3(y0 * a**2,0 ,-x0 * b**2).normalized()



	var vector_blue = reference_plane_normal.cross(RAAN_vec).normalized()
	var vector_red = orbit_normal.cross(RAAN_vec).normalized()
	
	
	#-------------------------------------------------
	# Drawing Vectors
	#-------------------------------------------------
	
	## Draw eccentricity vector
	draw_thick_line(peri_vec_world,Vector3.ZERO,Color.YELLOW_GREEN,world_drawings) # eccentricity vector
	## Draw RAAN vector
	draw_thick_line(RAAN_vec,Vector3.ZERO,Color.AQUA,world_drawings)
	##Draw X vector
	draw_thick_line(Vector3(1,0,0)*r_AN/2,Vector3.ZERO,Color.BLUE,world_drawings)
	
	## Draw RAAN arc
	draw_inclination_arc(Vector3(1,0,0),RAAN_vec/4,Vector3.ZERO,reference_plane_normal,world_drawings,Color.AQUA)
	## Draw argument of perigee arc
	draw_inclination_arc(RAAN_vec.normalized(),peri_vec_world/2,Vector3.ZERO,orbit_normal,world_drawings,Color.GREEN_YELLOW)
	## Draw inclination arc
	var inc_arc_normal = orbit_normal.cross(reference_plane_normal).normalized()
	draw_inclination_arc(vector_red,vector_blue*10,RAAN_vec,inc_arc_normal,world_drawings,Color.DARK_SALMON)

	## Draw planes
	draw_plane_from_normal(orbit_normal,world_drawings,Color.CRIMSON)
	draw_plane_from_normal(reference_plane_normal,world_drawings,Color.CADET_BLUE)

	## Add perigee and RAAN markers
	var perigee_offset = 0
	if abs(omega_deg - 0.0)   < 2.0 \
	|| abs(omega_deg - 180.0) < 2.0 \
	|| abs(omega_deg - 360.0) < 2.0:
		perigee_offset = 0.05
	add_marker(peri_vec_world,'Perigee',Color.DARK_GREEN,world_drawings,perigee_offset)
	add_marker(RAAN_vec,'AN',Color.AQUA,world_drawings)
	add_marker(-RAAN_vec.normalized()*r_DN,'DN',Color.AQUA,world_drawings)
	
	
##  Thick orbit path (tube made of cylinders)  --------------------------
func draw_orbit_thick(
		a       : float,
		e       : float,
		colour  : Color,
		radius  : float = 0.25,
		samples : int   = 360) -> Node3D:
	# 1.  Points in focus frame
	var pts := get_ellipse_points(a, e, samples)   # PackedVector3Array (size samples+1)

	# 2.  Cylinder mesh prototype
	var cyl := CylinderMesh.new()
	cyl.top_radius    = radius
	cyl.bottom_radius = radius
	cyl.height        = 1.0          # will be scaled per-instance
	cyl.radial_segments = 8

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = colour

	# 3.  MultiMesh to hold all segment cylinders
	var mmi  := MultiMeshInstance3D.new()
	var mm   := MultiMesh.new()
	mm.mesh          = cyl
	mm.transform_format = MultiMesh.TRANSFORM_3D
	#mm.color_format     = MultiMesh.COLOR_8BIT
	mm.instance_count   = samples
	mmi.multimesh       = mm
	mmi.material_override = mat
	add_child(mmi)

	# 4.  Fill each segment instance
	for i in samples:
		var p0 = pts[i]
		var p1 = pts[i+1]
		var dir = p1 - p0
		var len = dir.length()
		var mid = (p0 + p1) * 0.5
		var basis = Basis().looking_at(dir.normalized(), Vector3.UP)
		basis = basis.rotated(basis.x, deg_to_rad(90))   # align cylinder +Y to dir

		var xform = Transform3D(basis.scaled(Vector3(1, len, 1)), mid)
		mm.set_instance_transform(i, xform)
		mm.set_instance_color(i, colour)

	return mmi


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


func draw_thick_line(target: Vector3,offset: Vector3, color:  Color = Color.AQUA,parent: Node3D  = self,radius: float = 0.1) -> MeshInstance3D:

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
	mi.global_position = offset+target/2
	#mi.global_position = (Vector3.UP + target) * 0.5
	mi.transform.basis = Basis(q)            # apply rotation

	# -- 5. TRANSLATE so bottom cap is at (0,0,0)
	#mi.translation = dir_norm * (cyl.height * 0.5)
	#
	parent.add_child(mi)                            # add to the scene
	return mi

func add_marker(pos      : Vector3,
				text     : String,
				colour   : Color = Color.WHITE,
				parent: Node3D  = self,
				offset: float = 0,
				radius   : float = 0.6,) -> void:
	# ----- small sphere
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2
	var mi := MeshInstance3D.new()
	mi.mesh = sphere

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = colour
	mi.material_override = mat
	mi.global_position  = pos
	parent.add_child(mi)

	# ----- label
	var lbl := Label3D.new()
	lbl.text       = text
	lbl.position   = pos*(1.05+offset) #+ Vector3.UP * (radius * 2.5)   # float above the dot
	lbl.billboard  = BaseMaterial3D.BILLBOARD_ENABLED     # faces the camera
	lbl.font_size   = 256
	parent.add_child(lbl)


# ---------------------------------------------------------------------------
#  Draw a curved arc that visualises the angle between 2 vectors
# ---------------------------------------------------------------------------
func draw_inclination_arc(ref_n         : Vector3,   
							orb_n       : Vector3,   
							offset      : Vector3,
							normal      : Vector3, #normal vector depending on what is drawn
							parent: Node3D = self,
							arc_color   : Color = Color.YELLOW,
							arc_steps   : int   = 32,
							) -> Node3D:

	# -- 1.  axis of rotation  (line of nodes)
	var axis = ref_n.cross(orb_n.normalized())
	var inc_rad = orb_n.angle_to(ref_n)
	
	if axis.length_squared() < 1e-8:
		if ref_n.is_equal_approx(orb_n.normalized()):
			push_warning("Planes are parallel – nothing to draw.")
			return null
		else:
			axis = normal
			inc_rad = deg_to_rad(180)
	
	axis = axis.normalized()
	var sign = sign( (ref_n.cross(orb_n)).dot(normal))
	print(sign)
	if sign <0:
		axis = normal.normalized()
		inc_rad = deg_to_rad((360-rad_to_deg(inc_rad)))

	
	#print("Vector orb_n: ",orb_n_norm)
	#print("Vector ref_n: ",ref_n_norm)
	
	print("angle: ", rad_to_deg(inc_rad))
	
	var arc_radius = orb_n.length() #*inc_rad
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
	parent.add_child(mi)          # attach so it shows
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
	parent.add_child(lbl)

	return mi             # return the arc node (optional)


# ------------------------------------------------------------
#  Draw a transparent plane whose normal == `normal_vec`
#  Returns the MeshInstance3D so you can move / hide it later
# ------------------------------------------------------------
func draw_plane_from_normal(
	normal_vec : Vector3,                 # desired plane-normal (world)
	parent     : Node3D  = self,
	colour     : Color   = Color.BLUE,
	size       : float   = 150.0,         # width / height
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
	parent.add_child(plane)

	# --- 4.  Rotate so local +Y aligns with the supplied normal
	var n_unit  = normal_vec.normalized()
	var q       = Quaternion(Vector3.UP, n_unit)     # shortest-arc rotation
	plane.transform.basis = Basis(q)                 # apply rotation
	# plane.position = Vector3.ZERO                  # keep at origin (change if needed)
	return plane


func rotate_orbit(orbit_mesh: Node3D,omega_deg: float,RAAN_deg: float,i_deg: float)-> MeshInstance3D:
	#Rotate to get omega first
	var Omega_axis = Vector3(0,1,0)
	orbit_mesh.transform.basis = Basis(Omega_axis, deg_to_rad(omega_deg)) * orbit_mesh.transform.basis

	#Rotate to get inclination
	var axis = Vector3(1, 0, 0) # Or Vector3.RIGHT
	orbit_mesh.global_transform.basis = Basis(axis, deg_to_rad(i_deg)) * orbit_mesh.global_transform.basis

	#Rotate to get RAAN next
	var RAAN_axis = Vector3(0,1,0)
	orbit_mesh.global_transform.basis = Basis(RAAN_axis, deg_to_rad(RAAN_deg)) * orbit_mesh.global_transform.basis

	#var plane1 = draw_plane_from_normal(orbit_mesh.global_transform.basis.y.normalized(),Color.RED)
	return orbit_mesh

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
