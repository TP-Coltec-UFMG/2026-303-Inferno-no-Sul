## SaveManager — responsabilidade exclusiva: arquivos user://slot_N.save
##
## NÃO toca em settings.cfg — isso é domínio do SettingsManager.
##
## Slots: 1, 2, 3.  Slot 0 é reservado para autosave futuro.
## API principal:
##   salvar(slot, tree)   → Error
##   carregar(slot, tree) → bool
##   tem_save(slot)       → bool
##   deletar_save(slot)   → void
##   info_slots()         → Array[Dictionary]  (metadados de todos os slots)
##   salvar_atual(tree) / carregar_atual(tree) → operam no slot_ativo
##   slot_mais_recente() / primeiro_slot_vazio() → seleção automática de slot

extends Node

const TOTAL_SLOTS  : int    = 3
const SLOT_PATH    : String = "user://slot_%d.save"

## Emitido quando qualquer slot é criado ou deletado.
## slot = 1..3, exists = true/false
signal save_state_changed(slot: int, exists: bool)

## Slot ativo da sessão atual. Definido pelo menu principal
## (Continuar → slot mais recente; Novo Jogo → primeiro slot vazio).
var slot_ativo: int = 1

## True quando o jogador escolheu "Continuar" — Game carrega o slot ao iniciar.
var carregar_pendente: bool = false

## Usado para salvar fatores como a execução de um evento unico
var _flags: Dictionary = {}


# ════════════════════════════════════════════════════════════════════════════
#  API PÚBLICA
# ════════════════════════════════════════════════════════════════════════════

## Salva no slot ativo da sessão.
func salvar_atual(tree: SceneTree) -> Error:
	return salvar(slot_ativo, tree)


## Carrega o slot ativo da sessão.
func carregar_atual(tree: SceneTree) -> bool:
	return carregar(slot_ativo, tree)


## Slot com timestamp mais recente, ou 0 se não há saves.
func slot_mais_recente() -> int:
	var melhor_slot := 0
	var melhor_ts := -1.0
	for s in range(1, TOTAL_SLOTS + 1):
		if not tem_save(s):
			continue
		var ts: float = _ler(s).get("meta", {}).get("timestamp", 0.0)
		if ts > melhor_ts:
			melhor_ts = ts
			melhor_slot = s
	return melhor_slot


## Primeiro slot sem save; se todos ocupados, retorna o mais antigo.
func primeiro_slot_vazio() -> int:
	for s in range(1, TOTAL_SLOTS + 1):
		if not tem_save(s):
			return s
	var mais_antigo := 1
	var menor_ts := INF
	for s in range(1, TOTAL_SLOTS + 1):
		var ts: float = _ler(s).get("meta", {}).get("timestamp", 0.0)
		if ts < menor_ts:
			menor_ts = ts
			mais_antigo = s
	return mais_antigo


## Conteúdo bruto do slot ({} se vazio/inválido). Leitura pública.
func dados_slot(slot: int) -> Dictionary:
	if not _slot_valido(slot):
		return {}
	return _ler(slot)


func tem_save(slot: int) -> bool:
	return FileAccess.file_exists(_path(slot))


## Coleta estado da cena e grava no slot.
func salvar(slot: int, tree: SceneTree) -> Error:
	if not _slot_valido(slot):
		return ERR_PARAMETER_RANGE_ERROR
	var data := _coletar_dados(tree)
	data["meta"] = {
		"slot": slot,
		"timestamp": Time.get_unix_time_from_system(),
		"cena": tree.current_scene.scene_file_path if tree.current_scene else "",
	}
	var err := _escrever(slot, data)
	if err == OK:
		save_state_changed.emit(slot, true)
	return err


## Lê slot e distribui dados para os nós da cena.
func carregar(slot: int, tree: SceneTree) -> bool:
	if not _slot_valido(slot):
		return false
	var data := _ler(slot)
	if data.is_empty():
		return false
	_distribuir_dados(tree, data)
	return true


func deletar_save(slot: int) -> void:
	if _slot_valido(slot) and tem_save(slot):
		DirAccess.remove_absolute(_path(slot))
		save_state_changed.emit(slot, false)


## Retorna array com metadados de cada slot (ou {} se vazio).
func info_slots() -> Array:
	var resultado: Array = []
	for s in range(1, TOTAL_SLOTS + 1):
		if tem_save(s):
			var data := _ler(s)
			resultado.append(data.get("meta", { "slot": s }))
		else:
			resultado.append({})
	return resultado


# ── Compatibilidade com código antigo (main_menu.gd usa has_save_file) ───────

func has_save_file() -> bool:
	for s in range(1, TOTAL_SLOTS + 1):
		if tem_save(s):
			return true
	return false


# ════════════════════════════════════════════════════════════════════════════
#  COLETA DE DADOS
# ════════════════════════════════════════════════════════════════════════════

func _coletar_dados(tree: SceneTree) -> Dictionary:
	var data: Dictionary = {
		"cena_atual": tree.current_scene.scene_file_path if tree.current_scene else "",
		"objetos":    {},
		"player":     {},
		"companheiro":{},
		"inventario": [],
		"flags":      _flags.duplicate(),
	}

	for no in tree.get_nodes_in_group("salvavel"):
		if no.has_method("get_save_data"):
			var d: Dictionary = no.get_save_data()
			var chave: String = d.get("id", no.name)
			data["objetos"][chave] = d

	var players := tree.get_nodes_in_group("player")
	if players.size() > 0:
		data["player"] = _dados_player(players[0])

	var companheiros := tree.get_nodes_in_group("companheiros")
	if companheiros.size() > 0:
		data["companheiro"] = _dados_companheiro(companheiros[0])

	var lore_nodes := tree.get_nodes_in_group("lore_inventario")
	if lore_nodes.size() > 0 and lore_nodes[0].has_method("get_save_data"):
		data["inventario"] = lore_nodes[0].get_save_data()

	return data


func _dados_player(p: Node) -> Dictionary:
	if p.has_method("get_save_data"):
		return p.get_save_data()
	var d: Dictionary = {}
	if "global_position" in p:
		d["posicao"] = p.global_position
	if "stamina" in p:
		d["stamina"] = p.stamina
	return d


func _dados_companheiro(c: Node) -> Dictionary:
	if c.has_method("get_save_data"):
		return c.get_save_data()
	var d: Dictionary = {}
	for campo in ["forca", "agilidade", "coragem", "estado", "id_npc"]:
		if campo in c:
			d[campo] = c.get(campo)
	return d


# ════════════════════════════════════════════════════════════════════════════
#  DISTRIBUIÇÃO DE DADOS
# ════════════════════════════════════════════════════════════════════════════

func _distribuir_dados(tree: SceneTree, data: Dictionary) -> void:
	_flags = data.get("flags", {}).duplicate()
	var objetos: Dictionary = data.get("objetos", {})
	for no in tree.get_nodes_in_group("salvavel"):
		if not no.has_method("load_save_data"):
			continue
		var chave: String = no.get("id") if "id" in no else ""
		if chave == "" or not objetos.has(chave):
			chave = no.name
		if objetos.has(chave):
			no.load_save_data(objetos[chave])

	var d_player: Dictionary = data.get("player", {})
	if not d_player.is_empty():
		var players := tree.get_nodes_in_group("player")
		if players.size() > 0:
			var p := players[0]
			if p.has_method("load_save_data"):
				p.load_save_data(d_player)
			else:
				_aplicar_player(p, d_player)

	var d_comp: Dictionary = data.get("companheiro", {})
	if not d_comp.is_empty():
		var companheiros := tree.get_nodes_in_group("companheiros")
		if companheiros.size() > 0:
			var c := companheiros[0]
			if c.has_method("load_save_data"):
				c.load_save_data(d_comp)
			else:
				_aplicar_companheiro(c, d_comp)

	var inv: Array = data.get("inventario", [])
	if not inv.is_empty():
		var lore_nodes := tree.get_nodes_in_group("lore_inventario")
		if lore_nodes.size() > 0 and lore_nodes[0].has_method("load_save_data"):
			lore_nodes[0].load_save_data(inv)


func _aplicar_player(p: Node, d: Dictionary) -> void:
	if d.has("posicao") and "global_position" in p:
		p.global_position = d["posicao"]
	if d.has("stamina") and "stamina" in p:
		p.stamina = d["stamina"]


func _aplicar_companheiro(c: Node, d: Dictionary) -> void:
	for campo in ["forca", "agilidade", "coragem", "estado", "id_npc"]:
		if d.has(campo) and campo in c:
			c.set(campo, d[campo])


# ════════════════════════════════════════════════════════════════════════════
#  I/O BRUTO
# ════════════════════════════════════════════════════════════════════════════

func _escrever(slot: int, data: Dictionary) -> Error:
	var file := FileAccess.open(_path(slot), FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: falha ao escrever slot %d — %s" \
			% [slot, error_string(FileAccess.get_open_error())])
		return FileAccess.get_open_error()
	file.store_var(data)
	file.close()
	return OK


func _ler(slot: int) -> Dictionary:
	if not tem_save(slot):
		return {}
	var file := FileAccess.open(_path(slot), FileAccess.READ)
	if file == null:
		push_error("SaveManager: falha ao ler slot %d." % slot)
		return {}
	var data: Variant = file.get_var()
	file.close()
	if data is Dictionary:
		return data
	push_error("SaveManager: slot %d corrompido ou formato inválido." % slot)
	return {}


func _path(slot: int) -> String:
	return SLOT_PATH % slot


func _slot_valido(slot: int) -> bool:
	if slot < 1 or slot > TOTAL_SLOTS:
		push_error("SaveManager: slot %d inválido (1–%d)." % [slot, TOTAL_SLOTS])
		return false
	return true

# ════════════════════════════════════════════════════════════════════════════
#  FLAGS (booleanos simples de progresso: diálogos vistos, eventos únicos etc.)
# ════════════════════════════════════════════════════════════════════════════

func definir_flag(id: String, valor: bool = true) -> void:
	_flags[id] = valor


func obter_flag(id: String) -> bool:
	return _flags.get(id, false)


## Limpa todo o progresso de sessão (flags de diálogo/eventos vistos).
## SaveManager é um autoload e sobrevive a change_scene_to_file — sem isso,
## começar um "Novo Jogo" depois de já ter jogado uma vez na mesma sessão do
## app mantinha flags antigas (ex: diálogo inicial "já visto"), fazendo
## diálogos e prompts de porta sumirem indevidamente.
func nova_sessao() -> void:
	_flags.clear()
