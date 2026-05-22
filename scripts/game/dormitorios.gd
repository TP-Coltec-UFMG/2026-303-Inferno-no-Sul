extends Node2D

@onready var player : MC = $Player

var _ui_pronta      : bool   = false
var _btn_skill_arr  : Button = null
var _btn_skill_lck  : Button = null
var _btn_skill_dis  : Button = null
var _btn_pedra      : Button = null
var _btn_sacrificio : Button = null
var _label_status   : Label  = null

var companheiro : Companheiro = null


func _ready() -> void:
	_resolver_ui()
	_inicializar_doidinho()
	player.companheiro_sacrificado.connect(_ao_sacrificio_concluido)
	if _ui_pronta:
		_conectar_botoes()
	_atualizar_ui()


func _resolver_ui() -> void:
	var ui := get_node_or_null("UIComandos")
	if ui == null:
		return
	_label_status   = ui.get_node_or_null("PainelStatus/LabelStatus")
	_btn_skill_arr  = ui.get_node_or_null("PainelSkills/BtnArremesso")
	_btn_skill_lck  = ui.get_node_or_null("PainelSkills/BtnLockpicking")
	_btn_skill_dis  = ui.get_node_or_null("PainelSkills/BtnDistracao")
	_btn_pedra      = ui.get_node_or_null("PainelSkills/BtnAtiraPedra")
	_btn_sacrificio = ui.get_node_or_null("PainelSkills/BtnSacrificicio")
	_ui_pronta = true


func _inicializar_doidinho() -> void:
	const ID   := "doidinho"
	const CENA := "res://scenes/companheiros/doidinho.tscn"
	const SPAWN := Vector2(120.0, 200.0)

	if NPCManager.obter(ID) == null:
		var dados := NPCManager.DadosNPC.new(ID, CENA)
		NPCManager.registrar(dados)

	var npc := NPCManager.instanciar_na_cena(ID, self, player, SPAWN)
	if npc == null:
		return

	companheiro = npc
	player.registrar_companheiro(npc)
	npc.skill_executada.connect(_ao_skill_executada)
	NPCManager.pedras_atualizadas.connect(_ao_pedras_atualizadas)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("cmd_arremesso"):
		_on_btn_arremesso()
	elif event.is_action_pressed("cmd_lockpicking"):
		_on_btn_lockpicking()
	elif event.is_action_pressed("cmd_distracao"):
		_on_btn_distracao()
	elif event.is_action_pressed("cmd_sacrificio"):
		_on_btn_sacrificio()


# ════════════════════════════════════════════════════════════════════════════
#  UI
# ════════════════════════════════════════════════════════════════════════════

func _conectar_botoes() -> void:
	if _btn_skill_arr:  _btn_skill_arr.pressed.connect(_on_btn_arremesso)
	if _btn_skill_lck:  _btn_skill_lck.pressed.connect(_on_btn_lockpicking)
	if _btn_skill_dis:  _btn_skill_dis.pressed.connect(_on_btn_distracao)
	if _btn_pedra:      _btn_pedra.pressed.connect(_on_btn_pedra)
	if _btn_sacrificio: _btn_sacrificio.pressed.connect(_on_btn_sacrificio)


func _atualizar_ui() -> void:
	if not _ui_pronta:
		return
	if player.companheiro == null:
		_desabilitar_todos_botoes()
		_set_status("Sem companheiro.")
		return

	var c := player.companheiro
	if _btn_skill_arr:  _btn_skill_arr.disabled  = not c.pode_usar_skill("arremesso")
	if _btn_skill_lck:  _btn_skill_lck.disabled  = not c.pode_usar_skill("lockpicking")
	if _btn_skill_dis:  _btn_skill_dis.disabled  = not c.pode_usar_skill("distracao")
	if _btn_sacrificio: _btn_sacrificio.disabled = not c.pode_sacrificar()

	if _btn_pedra:
		var tem_pedra := NPCManager.pedras_disponiveis > 0
		_btn_pedra.disabled = not tem_pedra
		_btn_pedra.text = "Atirar Pedra [%d]" % NPCManager.pedras_disponiveis

	_set_status("Companheiro pronto.")


func _desabilitar_todos_botoes() -> void:
	if _btn_skill_arr:  _btn_skill_arr.disabled  = true
	if _btn_skill_lck:  _btn_skill_lck.disabled  = true
	if _btn_skill_dis:  _btn_skill_dis.disabled  = true
	if _btn_pedra:      _btn_pedra.disabled      = true
	if _btn_sacrificio: _btn_sacrificio.disabled = true


func _set_status(texto: String) -> void:
	if _label_status:
		_label_status.text = texto


# ════════════════════════════════════════════════════════════════════════════
#  HANDLERS
# ════════════════════════════════════════════════════════════════════════════

func _on_btn_arremesso() -> void:
	player.ordenar_skill("arremesso", _achar_alvo_proximo(128.0))
	_atualizar_ui()


func _on_btn_lockpicking() -> void:
	player.ordenar_skill("lockpicking", _achar_porta_proxima(80.0))
	_atualizar_ui()


func _on_btn_distracao() -> void:
	player.ordenar_skill("distracao")
	_atualizar_ui()


func _on_btn_pedra() -> void:
	if companheiro == null or not companheiro is Doidinho:
		_set_status("Requer Doidinho.")
		return
	(companheiro as Doidinho).atirar_pedra()
	_atualizar_ui()


func _on_btn_sacrificio() -> void:
	var ok := player.sacrificar_companheiro()
	if ok:
		_set_status("Companheiro se sacrificou!")
		_desabilitar_todos_botoes()


func _ao_skill_executada(skill: String) -> void:
	_set_status("Skill: %s" % skill)
	_atualizar_ui()


func _ao_sacrificio_concluido() -> void:
	companheiro = null
	_desabilitar_todos_botoes()
	_set_status("Companheiro perdido.")


func _ao_pedras_atualizadas(_restantes: int) -> void:
	_atualizar_ui()


# ════════════════════════════════════════════════════════════════════════════
#  UTILITÁRIOS
# ════════════════════════════════════════════════════════════════════════════

func _achar_alvo_proximo(raio: float) -> Node:
	if player.companheiro == null:
		return null
	var origem := player.companheiro.global_position
	for node: Node in get_tree().get_nodes_in_group("arremessavel"):
		if (node as Node2D).global_position.distance_to(origem) <= raio:
			return node
	return null


func _achar_porta_proxima(raio: float) -> Node:
	if player.companheiro == null:
		return null
	var origem := player.companheiro.global_position
	for node: Node in get_tree().get_nodes_in_group("porta_trancada"):
		if (node as Node2D).global_position.distance_to(origem) <= raio:
			return node
	return null
