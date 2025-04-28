extends CanvasLayer

signal orbit_changed(a, e, i_deg, omega_deg, raan_deg)

#/* paths to the sliders in your scene  ─────────────────────────────── */
@onready var sliders := {
	"a"     : $VBoxContainer/HBoxContainer/a,         #  HSlider
	"e"     : $VBoxContainer/HBoxContainer2/e,
	"i"     : $VBoxContainer/HBoxContainer3/i,
	"omega" : $VBoxContainer/HBoxContainer4/omega,
	"RAAN"  : $VBoxContainer/HBoxContainer5/RAAN
}

func _ready() -> void:
	for name in sliders.keys():
		sliders[name].value_changed.connect(
			_on_any_slider_changed.bind(name))
	_emit_values()              # send once at start

func _on_any_slider_changed(_v: float, _name: String) -> void:
	_emit_values()              # emit after any slider moves

func _emit_values() -> void:
	emit_signal(
		"orbit_changed",
		sliders["a"].value,
		sliders["e"].value,
		sliders["i"].value,
		sliders["omega"].value,
		sliders["RAAN"].value
	)

#func _ready() -> void:
#
	## connect after creation
	#for s in [a_slider, e_slider, i_slider, omega_slider, raan_slider]:
		#s.value_changed.connect(_sliders_updated)
#
	#_sliders_updated()                # emit once with defaults
#

### ------------------------------------------------------------------ helpers
#func _add_slider_row(parent      : VBoxContainer,
					 #label_text  : String,
					 #min         : float,
					 #max         : float,
					 #val         : float,
					 #step        : float = 1.0) -> HSlider:
#
	#var row  := HBoxContainer.new()
	#parent.add_child(row)
#
	#var lbl := Label.new()
	#lbl.text = label_text
	#lbl.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	#row.add_child(lbl)
#
	#var s := HSlider.new()
	#s.min_value = min
	#s.max_value = max
	#s.value     = val
	#s.step      = step
	#s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	#row.add_child(s)
#
	#return s
#
#
#func _sliders_updated(_v: float = 0.0) -> void:
	#emit_signal("orbit_changed",
		#a_slider.value,
		#e_slider.value,
		#i_slider.value,
		#omega_slider.value,
		#raan_slider.value)
