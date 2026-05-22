extends Node

# ════════════════════════════════════════════════════════════════════════════
#  LoreManager — Autoload Singleton
#
#  Persiste lore coletado entre cenas e sessões (via SaveManager).
#
#  API:
#    LoreManager.coletar(id, textura)  → registra e emite sinal
#    LoreManager.coletado(id)          → bool
#    LoreManager.todos()               → Array[DadosLore]
#
#  Integração com SaveManager:
#    LoreManager.salvar()   → grava ids no SaveManager
#    LoreManager.carregar() → restaura ids (texturas recarregadas por path)
# ════════════════════════════════════════════════════════════════════════════

signal lore_coletado(dados: DadosLore)

# ─── Recurso de dados ────────────────────────────────────────────────────────

class DadosLore:
	var id          : String
	var textura     : Texture2D
	var textura_path: String   ## res:// path — usado para recarregar após load
	var titulo      : String
	var descricao   : String

	func _init(
		p_id      : String,
		p_tex     : Texture2D,
		p_path    : String,
		p_titulo  : String = "",
		p_desc    : String = "",
	) -> void:
		id           = p_id
		textura      = p_tex
		textura_path = p_path
		titulo       = p_titulo
		descricao    = p_desc


# ─── Estado interno ──────────────────────────────────────────────────────────

## Chave: id  →  DadosLore
var _coletados: Dictionary = {}


# ════════════════════════════════════════════════════════════════════════════
#  API PÚBLICA
# ════════════════════════════════════════════════════════════════════════════

## Registra um lore como coletado. Ignora duplicatas.
func coletar(dados: DadosLore) -> void:
	if _coletados.has(dados.id):
		return
	_coletados[dados.id] = dados
	lore_coletado.emit(dados)


## Retorna true se o lore com este id já foi coletado.
func coletado(id: String) -> bool:
	return _coletados.has(id)


## Retorna todos os DadosLore coletados.
func todos() -> Array:
	return _coletados.values()


# ════════════════════════════════════════════════════════════════════════════
#  PERSISTÊNCIA
# ════════════════════════════════════════════════════════════════════════════

## Serializa ids e paths coletados para o SaveManager.
func salvar() -> void:
	var lista: Array = []
	for dados: DadosLore in _coletados.values():
		lista.append({
			"id"          : dados.id,
			"textura_path": dados.textura_path,
			"titulo"      : dados.titulo,
			"descricao"   : dados.descricao,
		})
	var save_data := SaveManager.load_game()
	save_data["lore"] = lista
	SaveManager.save_game(save_data)


## Restaura lore a partir do SaveManager, recarregando texturas por path.
func carregar() -> void:
	var save_data := SaveManager.load_game()
	if not save_data.has("lore"):
		return
	for entry: Dictionary in save_data["lore"]:
		var id           : String   = entry.get("id", "")
		var path         : String   = entry.get("textura_path", "")
		var titulo       : String   = entry.get("titulo", "")
		var descricao    : String   = entry.get("descricao", "")
		if id.is_empty() or path.is_empty():
			continue
		if _coletados.has(id):
			continue
		var tex := load(path) as Texture2D
		if tex == null:
			push_warning("LoreManager: textura '%s' não encontrada ao carregar." % path)
			continue
		_coletados[id] = DadosLore.new(id, tex, path, titulo, descricao)
