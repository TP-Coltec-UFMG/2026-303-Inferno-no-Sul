extends Node2D

@onready var player : MC = $Player

var companheiro : Companheiro = null


func _ready() -> void:
	player.companheiro_sacrificado.connect(_ao_sacrificio_concluido)


func _ao_sacrificio_concluido() -> void:
	companheiro = null
