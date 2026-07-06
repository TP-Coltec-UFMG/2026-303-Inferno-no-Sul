extends Node

# ════════════════════════════════════════════════════════════════════════════
#  NPCManager — Autoload Singleton
#
#  Persiste estado de NPCs companheiros entre trocas de cena.
#  Gerencia recurso global de pedras (max 2).
#
#  API:
#    NPCManager.registrar(dados)
#    NPCManager.obter(id)                → DadosNPC ou null
#    NPCManager.remover(id)
#    NPCManager.instanciar_na_cena(id, pai, jogador, spawn)
#    NPCManager.consumir_pedra()         → bool
#    NPCManager.adicionar_pedra(n)
# ════════════════════════════════════════════════════════════════════════════

const MAX_PEDRAS : int = 2
var pedras_disponiveis : int = MAX_PEDRAS

signal pedras_atualizadas(restantes: int)

var _registro : Dictionary = {}


# ════════════════════════════════════════════════════════════════════════════
#  RECURSO DE DADOS
# ════════════════════════════════════════════════════════════════════════════

class DadosNPC:
	var id          : String
	var cena_path   : String
	var sacrificado : bool = false

	func _init(p_id: String, p_cena: String) -> void:
		id        = p_id
		cena_path = p_cena


# ════════════════════════════════════════════════════════════════════════════
#  REGISTRO
# ════════════════════════════════════════════════════════════════════════════

func registrar(dados: DadosNPC) -> void:
	_registro[dados.id] = dados


func obter(id: String) -> DadosNPC:
	return _registro.get(id, null)


func remover(id: String) -> void:
	_registro.erase(id)


func sincronizar(_npc: Companheiro) -> void:
	pass


# ════════════════════════════════════════════════════════════════════════════
#  INSTANCIAÇÃO
# ════════════════════════════════════════════════════════════════════════════

func instanciar_na_cena(
	id     : String,
	pai    : Node,
	jogador: Node2D,
	spawn  : Vector2 = Vector2.ZERO,
) -> Companheiro:
	var dados := obter(id)
	if dados == null:
		push_error("NPCManager: id '%s' não encontrado." % id)
		return null
	if dados.sacrificado:
		return null

	var cena := load(dados.cena_path) as PackedScene
	if cena == null:
		push_error("NPCManager: falha ao carregar '%s'." % dados.cena_path)
		return null

	var npc := cena.instantiate() as Companheiro
	if npc == null:
		push_error("NPCManager: cena '%s' não é Companheiro." % dados.cena_path)
		return null

	npc.id_npc = dados.id

	if spawn != Vector2.ZERO:
		npc.position = spawn

	pai.add_child(npc)
	npc.ativar(jogador)

	npc.sacrificado.connect(func() -> void:
		var d := obter(id)
		if d:
			d.sacrificado = true
		remover(id)
	)

	return npc


# ════════════════════════════════════════════════════════════════════════════
#  PEDRAS
# ════════════════════════════════════════════════════════════════════════════

func consumir_pedra() -> bool:
	if pedras_disponiveis <= 0:
		return false
	pedras_disponiveis -= 1
	pedras_atualizadas.emit(pedras_disponiveis)
	return true


func adicionar_pedra(quantidade: int = 1) -> void:
	pedras_disponiveis = mini(pedras_disponiveis + quantidade, MAX_PEDRAS)
	pedras_atualizadas.emit(pedras_disponiveis)
