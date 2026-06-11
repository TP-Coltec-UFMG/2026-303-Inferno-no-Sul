extends Porta
class_name PortaTransicao

# Porta que ao ser aberta troca de cena via nó "Game".
# Configurar no editor:
#   destino_path → "res://scenes/game/patio.tscn"
#   spawn_pos    → posição do player na cena destino
# Herda estado (TRANCADA/DESBLOQUEADA/ABERTA) e save de Porta.

@export var destino_path: String = ""
@export var spawn_pos: Vector2 = Vector2.ZERO


func _ready() -> void:
	super()
	prompt_texto = "Ir para próxima área"
	if _prompt:
		_prompt.text = prompt_texto


func _ao_interagir() -> void:
	match estado:
		Estado.DESBLOQUEADA:
			abrir()
			_transicionar()
		Estado.ABERTA:
			_transicionar()
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
	# Save fica a cargo do Game (esta porta é liberada junto com a fase antiga).
	game.ir_para_fase(destino_path, spawn_pos, true)
