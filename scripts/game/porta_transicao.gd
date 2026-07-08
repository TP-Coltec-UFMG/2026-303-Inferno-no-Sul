extends Porta
class_name PortaTransicao

@export_file("*.tscn") var destino_path: String = ""
@export var destino_spawn_id: String = ""  # id do PontoSpawn NA CENA DE DESTINO


func _ready() -> void:
	super()
	prompt_texto = "Ir para próxima área"
	if _prompt:
		_prompt.text = prompt_texto


func _ao_interagir() -> void:
	print("PortaTransicao '%s': interagir chamado, estado=%s" % [id, estado])
	match estado:
		Estado.DESBLOQUEADA:
			abrir()
			_transicionar.call_deferred()
		Estado.ABERTA:
			_transicionar.call_deferred()
		Estado.TRANCADA:
			push_warning("PortaTransicao '%s' está trancada." % id)


func _transicionar() -> void:
	if destino_path.is_empty():
		push_error("PortaTransicao '%s': destino_path não configurado." % id)
		return
	if destino_spawn_id.is_empty():
		push_error("PortaTransicao '%s': destino_spawn_id não configurado." % id)
		return

	var game := get_tree().root.get_node_or_null("Game")
	if game == null:
		push_error("PortaTransicao: nó 'Game' não encontrado no root.")
		return

	game.ir_para_fase(destino_path, destino_spawn_id, true)
