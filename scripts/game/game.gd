extends Node

# ════════════════════════════════════════════════════════════════════════════
#  Game — controlador de sessão + level streaming
#
#  Grafo de adjacência (pré-carregamento bidirecional):
#    dormitorios  ↔ patio
#    dormitorios  ↔ ala_psiquiatrica
#    patio        ↔ cozinha
#    cozinha      ↔ administracao
#    administracao ↔ patio
#
#  API pública:
#    Game.ir_para_fase("res://scenes/game/patio.tscn")
#    Game.ir_para_fase("res://scenes/game/patio.tscn", Vector2(300, 200))
# ════════════════════════════════════════════════════════════════════════════

const FASE_INICIAL := "res://scenes/game/dormitorios.tscn"
const FASE_PATIO   := "res://scenes/game/patio.tscn"
const CENA_MENU    := "res://scenes/ui/main_menu.tscn"

const ADJACENCIA: Dictionary = {
	"res://scenes/game/dormitorios.tscn"    : [
		"res://scenes/game/patio.tscn",
		"res://scenes/game/ala_psiquiatrica.tscn",
	],
	"res://scenes/game/patio.tscn"          : [
		"res://scenes/game/dormitorios.tscn",
		"res://scenes/game/cozinha.tscn",
	],
	"res://scenes/game/cozinha.tscn"        : [
		"res://scenes/game/patio.tscn",
		"res://scenes/game/administracao.tscn",
	],
	"res://scenes/game/ala_psiquiatrica.tscn": [
		"res://scenes/game/dormitorios.tscn",
	],
	"res://scenes/game/administracao.tscn"  : [
		"res://scenes/game/cozinha.tscn",
		"res://scenes/game/patio.tscn",
	],
}

const SCENE_PAUSE   := preload("res://scenes/ui/pause_menu.tscn")
const SCENE_OPTIONS := preload("res://scenes/ui/options_menu.tscn")

@onready var world             : Node2D      = $World
@onready var lore_viewer       : CanvasLayer = $LoreViewer
@onready var lore_inventario   : CanvasLayer = $LoreInventario
@onready var pause_container   : CanvasLayer = $PauseContainer

var _path_atual  : String = ""
var _fase_atual  : Node   = null
var _cache       : Dictionary = {}
var _carregando  : Dictionary = {}

var _pause_menu  : Control = null
var _opcoes_menu : Control = null
var _pausado     : bool    = false


# ════════════════════════════════════════════════════════════════════════════
#  CICLO DE VIDA
# ════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	LoreManager.carregar()
	ir_para_fase(FASE_INICIAL)


func _process(_delta: float) -> void:
	_verificar_carregamentos()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if _pausado:
			_fechar_pause()
		else:
			_abrir_pause()
		get_viewport().set_input_as_handled()


# ════════════════════════════════════════════════════════════════════════════
#  PAUSE
# ════════════════════════════════════════════════════════════════════════════

func _abrir_pause() -> void:
	if _pausado:
		return
	_pausado = true
	get_tree().paused = true

	_pause_menu = SCENE_PAUSE.instantiate()
	_pause_menu.pode_salvar = (_path_atual == FASE_PATIO)
	pause_container.add_child(_pause_menu)
	pause_container.visible = true

	_pause_menu.menu_fechado.connect(_fechar_pause)
	_pause_menu.opcoes_abertas.connect(_abrir_opcoes_no_pause)
	_pause_menu.salvar_pedido.connect(_salvar_no_patio)
	_pause_menu.sair_para_menu_pedido.connect(_sair_para_menu)


func _fechar_pause() -> void:
	if not _pausado:
		return
	_fechar_opcoes_pause()
	if is_instance_valid(_pause_menu):
		_pause_menu.queue_free()
		_pause_menu = null
	pause_container.visible = false
	get_tree().paused = false
	_pausado = false


func _abrir_opcoes_no_pause() -> void:
	if is_instance_valid(_opcoes_menu):
		return
	_opcoes_menu = SCENE_OPTIONS.instantiate()
	pause_container.add_child(_opcoes_menu)
	if _opcoes_menu.has_signal("menu_closed"):
		_opcoes_menu.menu_closed.connect(_fechar_opcoes_pause)


func _fechar_opcoes_pause() -> void:
	if is_instance_valid(_opcoes_menu):
		_opcoes_menu.queue_free()
		_opcoes_menu = null


func _salvar_no_patio() -> void:
	if _path_atual != FASE_PATIO:
		push_warning("Game: tentativa de salvar fora do pátio bloqueada.")
		return
	var player := _fase_atual.get_node_or_null("Player") as Node2D
	var dados : Dictionary = {
		"fase"        : _path_atual,
		"player_pos"  : var_to_str(player.global_position) if player else "0,0",
	}
	SaveManager.save_game(dados)


func _sair_para_menu() -> void:
	get_tree().paused = false
	_pausado = false
	get_tree().change_scene_to_file(CENA_MENU)


# ════════════════════════════════════════════════════════════════════════════
#  API PÚBLICA
# ════════════════════════════════════════════════════════════════════════════

func ir_para_fase(path: String, spawn_pos: Vector2 = Vector2.ZERO) -> void:
	if path == _path_atual:
		return

	_sincronizar_npcs()

	if _fase_atual != null:
		_fase_atual.queue_free()
		_fase_atual = null
		await get_tree().process_frame

	var packed := _obter_packed(path)
	if packed == null:
		push_error("Game: falha ao carregar '%s'." % path)
		return

	_path_atual = path
	_fase_atual = packed.instantiate()
	world.add_child(_fase_atual)

	if spawn_pos != Vector2.ZERO:
		var player := _fase_atual.get_node_or_null("Player") as Node2D
		if player:
			player.global_position = spawn_pos

	# Atualiza botão salvar se pause estiver aberto
	if is_instance_valid(_pause_menu):
		_pause_menu.pode_salvar = (_path_atual == FASE_PATIO)

	_atualizar_cache(path)


# ════════════════════════════════════════════════════════════════════════════
#  CACHE E STREAMING
# ════════════════════════════════════════════════════════════════════════════

func _obter_packed(path: String) -> PackedScene:
	if _cache.has(path):
		return _cache[path]
	var packed := load(path) as PackedScene
	if packed:
		_cache[path] = packed
	return packed


func _atualizar_cache(path_atual: String) -> void:
	var vizinhos: Array = ADJACENCIA.get(path_atual, [])
	for v in vizinhos:
		if not _cache.has(v) and not _carregando.has(v):
			_iniciar_carregamento_async(v)
	var manter := vizinhos.duplicate()
	manter.append(path_atual)
	for key in _cache.keys():
		if key not in manter:
			_cache.erase(key)


func _iniciar_carregamento_async(path: String) -> void:
	var err := ResourceLoader.load_threaded_request(path)
	if err == OK:
		_carregando[path] = true
	else:
		push_warning("Game: não foi possível iniciar carregamento async de '%s'." % path)


func _verificar_carregamentos() -> void:
	for path in _carregando.keys():
		var status := ResourceLoader.load_threaded_get_status(path)
		match status:
			ResourceLoader.THREAD_LOAD_LOADED:
				var packed := ResourceLoader.load_threaded_get(path) as PackedScene
				if packed:
					_cache[path] = packed
				_carregando.erase(path)
			ResourceLoader.THREAD_LOAD_FAILED:
				push_error("Game: carregamento async falhou para '%s'." % path)
				_carregando.erase(path)


# ════════════════════════════════════════════════════════════════════════════
#  INTERNAL
# ════════════════════════════════════════════════════════════════════════════

func _sincronizar_npcs() -> void:
	for npc in get_tree().get_nodes_in_group("companheiros"):
		if npc is Companheiro and npc.id_npc != "":
			NPCManager.sincronizar(npc)
