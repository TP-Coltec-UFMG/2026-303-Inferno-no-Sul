extends Node
class_name Salvavel

## Retorna dicionário com estado atual deste nó.
func get_save_data() -> Dictionary:
	push_warning("Salvavel: get_save_data() não implementado em %s" % name)
	return {}

## Recebe dicionário e restaura estado.
func load_save_data(d: Dictionary) -> void:
	push_warning("Salvavel: load_save_data() não implementado em %s" % name)
