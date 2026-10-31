class_name SpatialShotAudio
extends RefCounted
## Одноразовый пространственный источник: не следует за оружием после выстрела.

static func play(template: AudioStreamPlayer3D, world_position: Vector3) -> void:
	if not is_instance_valid(template) or not template.stream:
		return
	var scene := template.get_tree().current_scene
	if not is_instance_valid(scene):
		return
	var sound := AudioStreamPlayer3D.new()
	sound.name = &"SpatialGunshot"
	sound.stream = template.stream
	sound.bus = template.bus
	sound.volume_db = template.volume_db
	sound.pitch_scale = template.pitch_scale
	sound.attenuation_model = template.attenuation_model
	sound.unit_size = template.unit_size
	sound.max_distance = template.max_distance
	sound.max_db = template.max_db
	sound.panning_strength = template.panning_strength
	sound.attenuation_filter_cutoff_hz = template.attenuation_filter_cutoff_hz
	sound.attenuation_filter_db = template.attenuation_filter_db
	sound.top_level = true
	scene.add_child(sound)
	sound.global_position = world_position
	sound.finished.connect(sound.queue_free)
	sound.play()
