extends Porta
class_name PortaTransicao



@export_file("*.tscn") var destino_path: String = "" # Mudado para abrir o seletor de arquivos no editor
@export var spawn_pos: Vector2 = Vector2.ZERO


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
			# Usamos call_deferred para garantir que a animação de abrir comece
			# antes da cena ser limpa da memória
			_transicionar.call_deferred()
		Estado.ABERTA:
			_transicionar.call_deferred()
		Estado.TRANCADA:
			push_warning("PortaTransicao '%s' está trancada." % id)


func _transicionar() -> void:
	if destino_path.is_empty():
		push_error("PortaTransicao '%s': destino_path não configurado." % id)
		return
		
	var game := get_tree().root.get_node_or_null("Game")
	if game == null:
		push_error("PortaTransicao: nó 'Game' não encontrado no root.")
		return
		
	# O Game assume o controle daqui e descarrega a fase atual com segurança
	game.ir_para_fase(destino_path, spawn_pos, true)
