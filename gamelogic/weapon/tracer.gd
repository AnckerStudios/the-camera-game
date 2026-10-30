class_name Tracer
extends MeshInstance3D

## Короткая вспышка-линия от дула до точки попадания.

const LIFETIME := 0.08
const COLOR := Color(1.0, 0.85, 0.5, 0.9)


static func spawn(parent: Node, from: Vector3, to: Vector3) -> void:
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	mesh.surface_add_vertex(from)
	mesh.surface_add_vertex(to)
	mesh.surface_end()

	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = COLOR

	var tracer := Tracer.new()
	tracer.mesh = mesh
	tracer.material_override = material
	tracer.top_level = true
	tracer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(tracer)
	tracer.global_transform = Transform3D.IDENTITY

	var tween := tracer.create_tween()
	tween.tween_property(material, "albedo_color:a", 0.0, LIFETIME)
	tween.tween_callback(tracer.queue_free)
