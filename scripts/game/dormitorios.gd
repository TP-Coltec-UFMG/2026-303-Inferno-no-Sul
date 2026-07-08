extends Node2D

const FLAG_DIALOGO_INICIAL := "dormitorio_intro_visto"

@onready var player : MC = $Player
@onready var painel_dialogo : PanelContainer = $CanvasLayer/Panel

var companheiro : Companheiro = null


func _ready() -> void:
	player.companheiro_sacrificado.connect(_ao_sacrificio_concluido)

	if SaveManager.obter_flag(FLAG_DIALOGO_INICIAL):
		painel_dialogo.hide()
	# senão, o Panel já está visível por padrão na cena (como configuramos no editor)


func _unhandled_input(event: InputEvent) -> void:
	if painel_dialogo.visible and event is InputEventKey and event.pressed:
		_fechar_dialogo()


func _fechar_dialogo() -> void:
	painel_dialogo.hide()
	SaveManager.definir_flag(FLAG_DIALOGO_INICIAL)


func _ao_sacrificio_concluido() -> void:
	companheiro = null
