extends Area2D
class_name Porta

enum Estado { TRANCADA, DESBLOQUEADA, ABERTA }

@export var id: String = ""
@export var prompt_texto: String = "Abrir"
@export var estado: Estado = Estado.TRANCADA
@export var raio_interacao: float = 80.0

@onready var _prompt: Label = get_node_or_null("PromptLayer/Prompt")

var _player_dentro := false
var _player_ref: Node2D = null

signal estado_alterado(novo: Estado)


func _ready() -> void:
	add_to_group("salvavel")
	add_to_group("porta_trancada")

	if id.is_empty():
		id = name

	if _prompt:
		_atualizar_texto_prompt()
		_prompt.visible = false

func _process(_delta: float) -> void:
	_atualizar_interacao()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and _jogador_no_raio():
		_ao_interagir()
		get_viewport().set_input_as_handled()


func _ao_interagir() -> void:
	match estado:
		Estado.DESBLOQUEADA:
			abrir()
		Estado.TRANCADA:
			push_warning("Porta '%s' esta trancada." % id)


func destrancar() -> void:
	if estado == Estado.TRANCADA:
		_set_estado(Estado.DESBLOQUEADA)


func trancar() -> void:
	if estado != Estado.TRANCADA:
		_set_estado(Estado.TRANCADA)


func abrir() -> void:
	if estado == Estado.DESBLOQUEADA:
		_set_estado(Estado.ABERTA)


func _set_estado(novo: Estado) -> void:
	estado = novo
	estado_alterado.emit(estado)
	_aplicar_estado()


func _aplicar_estado() -> void:
	_atualizar_interacao()


func _deve_exibir_prompt() -> bool:
	return estado != Estado.ABERTA
	
func _atualizar_texto_prompt() -> void:
	if not _prompt:
		return

	var tecla := InputManager.tecla_da_acao("interact")
	var nome_tecla := "E"

	if tecla != KEY_NONE:
		nome_tecla = OS.get_keycode_string(tecla)

	var texto_base := prompt_texto

	# Remove uma tecla escrita manualmente, como [E].
	var pos_colchete := texto_base.rfind("[")
	if pos_colchete != -1 and texto_base.ends_with("]"):
		texto_base = texto_base.substr(0, pos_colchete).strip_edges()

	_prompt.text = "%s  [%s]" % [texto_base, nome_tecla]

func _atualizar_interacao() -> void:
	_player_ref = _obter_player_ativo()
	_player_dentro = _jogador_no_raio()

	if _prompt:
		_prompt.visible = _player_dentro and _deve_exibir_prompt()

		if _prompt.visible:
			_atualizar_texto_prompt()


func _jogador_no_raio() -> bool:
	return is_instance_valid(_player_ref) and global_position.distance_to(_player_ref.global_position) <= raio_interacao


func _obter_player_ativo() -> Node2D:
	for node in get_tree().get_nodes_in_group("player"):
		if node is Node2D and node.is_visible_in_tree() and node.is_physics_processing():
			return node as Node2D
	return null


func get_save_data() -> Dictionary:
	return { "id": id, "estado": estado }


func load_save_data(d: Dictionary) -> void:
	estado = d.get("estado", Estado.TRANCADA) as Estado
	_aplicar_estado()
