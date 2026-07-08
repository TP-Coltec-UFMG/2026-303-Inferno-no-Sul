extends Node

# ════════════════════════════════════════════════════════════════════════════
#  Game — controlador de sessão + cache de fases
#
#  API pública:
#    Game.ir_para_fase("res://scenes/game/patio.tscn")
#    Game.ir_para_fase("res://scenes/game/patio.tscn", Vector2(300, 200))
# ════════════════════════════════════════════════════════════════════════════

const FASE_INICIAL := "res://scenes/game/dormitorios.tscn"
const FASE_PATIO   := "res://scenes/game/patio.tscn"
const CENA_MENU    := "res://scenes/ui/main_menu.tscn"

const FASES: Array[String] = [
	"res://scenes/game/dormitorios.tscn",
	"res://scenes/game/patio.tscn",
	"res://scenes/game/cozinha.tscn",
	"res://scenes/game/ala_psiquiatrica.tscn",
	"res://scenes/game/administracao.tscn",
]

const SCENE_PAUSE   := preload("res://scenes/ui/pause_menu.tscn")
const SCENE_OPTIONS := preload("res://scenes/ui/options_menu.tscn")

@onready var world             : Node2D      = $World
@onready var lore_viewer       : CanvasLayer = $LoreViewer
@onready var lore_inventario   : CanvasLayer = $LoreInventario
@onready var pause_container   : CanvasLayer = $PauseContainer

var _path_atual  : String     = ""
var _fase_atual  : Node       = null
var _fases       : Dictionary = {}   # path -> Node já instanciado (vive na árvore a sessão toda)
var _carregando  : Dictionary = {}   # path -> bool (ainda em ResourceLoader threaded)

var _pause_menu  : Control = null
var _opcoes_menu : Control = null
var _pausado     : bool    = false

# Progresso reportado no console (evita spam: só loga quando o % sobe)
var _ultimo_progresso : Dictionary = {}   # path -> int (último % logado)


# ════════════════════════════════════════════════════════════════════════════
#  CICLO DE VIDA
# ════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	pause_container.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	# Ignoramos completamente qualquer save pendente
	SaveManager.carregar_pendente = false

	# Forçamos a fase inicial como os dormitórios
	var fase := FASE_INICIAL

	# A fase de entrada precisa existir já no primeiro frame: ir_para_fase
	# vai instanciá-la e ativá-la de forma síncrona (_fases e _carregando
	# ainda estão vazios nesse ponto, então cai direto no load síncrono).
	ir_para_fase(fase)

	# As demais fases são carregadas E instanciadas em segundo plano,
	# ocultas/desativadas, prontas pra quando o jogador chegar até elas.
	print("Game: jogador liberado em '%s' — carregando as demais fases em segundo plano..." % fase)
	_precachear_fases()


## Dispara carregamento (e instanciação, ao terminar) de todas as fases
## que ainda não existem na árvore nem estão sendo carregadas.
func _precachear_fases() -> void:
	for path in FASES:
		if not _fases.has(path) and not _carregando.has(path):
			_iniciar_carregamento_async(path)


func _process(_delta: float) -> void:
	_verificar_carregamentos()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		print("Game: pause pressionado, _pausado=", _pausado)
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
	SaveManager.salvar_atual(get_tree())


# ─── Persistência (grupo "salvavel") ─────────────────────────────────────────

func get_save_data() -> Dictionary:
	return { "id": "game", "fase": _path_atual }


func load_save_data(_d: Dictionary) -> void:
	# Fase é restaurada em _ready antes da distribuição — nada a fazer aqui.
	pass


func _sair_para_menu() -> void:
	get_tree().paused = false
	_pausado = false
	get_tree().change_scene_to_file(CENA_MENU)


# ════════════════════════════════════════════════════════════════════════════
#  API PÚBLICA
# ════════════════════════════════════════════════════════════════════════════

## Transiciona para `path`. A fase de destino já existe na árvore
## (pré-instanciada); a troca é só esconder a atual e mostrar a nova —
## sem instantiate()/queue_free() a cada transição.
func ir_para_fase(path: String, spawn_pos: Vector2 = Vector2.ZERO, salvar_apos: bool = false) -> void:
	if path == _path_atual:
		return

	_sincronizar_npcs()

	var nova_fase := _obter_instancia(path)
	if nova_fase == null:
		push_error("Game: falha ao carregar '%s'." % path)
		return

	if spawn_pos != Vector2.ZERO:
		var player := nova_fase.get_node_or_null("Player") as Node2D
		if player:
			player.global_position = spawn_pos

	if _fase_atual != null:
		_definir_ativa(_fase_atual, false)

	_path_atual = path
	_fase_atual = nova_fase
	_definir_ativa(_fase_atual, true)

	# Atualiza botão salvar se pause estiver aberto
	if is_instance_valid(_pause_menu):
		_pause_menu.pode_salvar = (_path_atual == FASE_PATIO)

	if salvar_apos:
		SaveManager.salvar_atual(get_tree())


# ════════════════════════════════════════════════════════════════════════════
#  CACHE E STREAMING (agora de instâncias vivas, não só de PackedScene)
# ════════════════════════════════════════════════════════════════════════════

## Retorna a instância viva de `path` (já filha de world, oculta ou visível),
## instanciando na hora (síncrono) se o pré-carregamento em segundo plano
## ainda não tiver terminado.
func _obter_instancia(path: String) -> Node:
	if _fases.has(path):
		return _fases[path]

	var packed: PackedScene = null
	if _carregando.has(path):
		_carregando.erase(path)
		_ultimo_progresso.erase(path)
		if ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_LOADED:
			packed = ResourceLoader.load_threaded_get(path) as PackedScene
		else:
			# Async falhou ou ainda em andamento — fallback síncrono.
			print("Game: '%s' foi requisitada antes de terminar o carregamento async — forçando load síncrono." % path)
			packed = load(path) as PackedScene
	else:
		packed = load(path) as PackedScene

	if packed == null:
		return null

	return _registrar_instancia(path, packed)


## Instancia `packed`, adiciona como filha (oculta/desativada) de `world`
## e registra em _fases. Dali em diante a fase existe pra sempre na árvore.
func _registrar_instancia(path: String, packed: PackedScene) -> Node:
	var instancia := packed.instantiate()
	world.add_child(instancia)
	_definir_ativa(instancia, false)
	_fases[path] = instancia
	print("Game: [100%%] '%s' carregada e pronta em segundo plano." % path)
	return instancia


func _iniciar_carregamento_async(path: String) -> void:
	var err := ResourceLoader.load_threaded_request(path)
	if err == OK:
		_carregando[path] = true
		_ultimo_progresso[path] = -1
		print("Game: [  0%%] iniciando carregamento em segundo plano de '%s'..." % path)
	else:
		push_warning("Game: não foi possível iniciar carregamento async de '%s'." % path)


func _verificar_carregamentos() -> void:
	for path in _carregando.keys():
		var progresso_arr : Array = []
		var status := ResourceLoader.load_threaded_get_status(path, progresso_arr)

		match status:
			ResourceLoader.THREAD_LOAD_IN_PROGRESS:
				if not progresso_arr.is_empty():
					var pct := int(round(float(progresso_arr[0]) * 100.0))
					var ultimo : int = _ultimo_progresso.get(path, -1)
					# Só loga a cada 10% pra não spammar o console
					if pct >= ultimo + 10:
						_ultimo_progresso[path] = pct
						print("Game: [%3d%%] carregando '%s' em segundo plano..." % [pct, path])

			ResourceLoader.THREAD_LOAD_LOADED:
				var packed := ResourceLoader.load_threaded_get(path) as PackedScene
				if packed:
					_registrar_instancia(path, packed)
				_carregando.erase(path)
				_ultimo_progresso.erase(path)

			ResourceLoader.THREAD_LOAD_FAILED:
				push_error("Game: carregamento async falhou para '%s'." % path)
				_carregando.erase(path)
				_ultimo_progresso.erase(path)


## Liga/desliga uma fase inteira (visibilidade + processamento) sem nunca
## removê-la da árvore — por isso o estado interno de cada fase sobrevive
## entre visitas.
func _definir_ativa(fase: Node, ativa: bool) -> void:
	var item := fase as CanvasItem
	if item:
		item.visible = ativa
	fase.process_mode = Node.PROCESS_MODE_INHERIT if ativa else Node.PROCESS_MODE_DISABLED

	# Hooks opcionais: como _ready() de cada fase só roda uma vez (na
	# primeira instanciação), o script da fase pode implementar estes
	# métodos pra rodar lógica a cada entrada/saída. Ignore se não precisar.
	if ativa and fase.has_method("ao_entrar_na_fase"):
		fase.ao_entrar_na_fase()
	elif not ativa and fase.has_method("ao_sair_da_fase"):
		fase.ao_sair_da_fase()


# ════════════════════════════════════════════════════════════════════════════
#  INTERNAL
# ════════════════════════════════════════════════════════════════════════════

func _sincronizar_npcs() -> void:
	for npc in get_tree().get_nodes_in_group("companheiros"):
		if npc is Companheiro and npc.id_npc != "":
			NPCManager.sincronizar(npc)
