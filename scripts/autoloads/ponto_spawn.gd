extends Marker2D
class_name PontoSpawn

@export var spawn_id: String = ""

func _ready() -> void:
	if spawn_id.is_empty():
		push_warning("PontoSpawn em '%s' sem spawn_id definido." % get_path())
