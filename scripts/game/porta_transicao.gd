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

func _ao_interagir() -> void:
	if estado == Estado.TRANCADA:
		push_warning(
			"PortaTransicao '%s' está trancada." % id
		)
		return

	_transicionar()


func _transicionar() -> void:
	if destino_path.is_empty():
		push_error(
			"PortaTransicao '%s': destino não configurado." % id
		)
		return

	var game := get_tree().current_scene

	if game == null or not game.has_method("ir_para_fase"):
		push_error(
			"PortaTransicao: execute o jogo usando F5. " +
			"O controlador Game não foi encontrado."
		)
		return

	print(
		"Porta '%s': indo para '%s'." %
		[id, destino_path]
	)

	game.ir_para_fase(
		destino_path,
		spawn_pos,
		true
	)
