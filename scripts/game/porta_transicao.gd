extends Porta
class_name PortaTransicao

@export_file("*.tscn") var destino_path: String = ""
@export var destino_spawn_id: String = ""


func _ready() -> void:
	super()
	prompt_texto = "Ir para proxima area  [E]"
	if _prompt:
		_prompt.text = prompt_texto


func _ao_interagir() -> void:
	match estado:
		Estado.DESBLOQUEADA:
			abrir()
			_transicionar.call_deferred()
		Estado.ABERTA:
			_transicionar.call_deferred()
		Estado.TRANCADA:
			push_warning("PortaTransicao '%s' esta trancada." % id)


func _deve_exibir_prompt() -> bool:
	return true


func _transicionar() -> void:
	if destino_path.is_empty() or destino_spawn_id.is_empty():
		push_error("PortaTransicao '%s': destino ou spawn nao configurado." % id)
		return
	var game := get_tree().root.get_node_or_null("Game")
	if game == null:
		push_error("PortaTransicao: no 'Game' nao encontrado no root.")
		return
	game.ir_para_fase(destino_path, destino_spawn_id, true)
