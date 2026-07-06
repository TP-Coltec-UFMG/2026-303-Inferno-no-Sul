# GameManager.gd  
extends Node

@export var cena_medico : PackedScene = preload("res://scenes/characters/medico.tscn")

var medico_instancia : Node2D = null

func _ready() -> void:
	EventBus.medico_chamado.connect(_on_medico_chamado)

func _on_medico_chamado(posicao_irma: Vector2) -> void:
	# evita dois médicos simultâneos
	if medico_instancia != null and is_instance_valid(medico_instancia):
		return

	medico_instancia = cena_medico.instantiate()

	# aparece perto da irmã, com offset para não sobrepor
	medico_instancia.global_position = posicao_irma + Vector2(60, 0)

	# adiciona no nível do hospital, não como filho da irmã
	get_tree().current_scene.add_child(medico_instancia)
