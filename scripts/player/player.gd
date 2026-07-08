extends CharacterBody2D
class_name MC

const aceleracao        = 1500.0
const velocidade_maxima = 350.0
const atrito            = 1200.0

# ── Corrida ──────────────────────────────────────────────────────────────────
const VELOCIDADE_CORRIDA   : float = 560.0
const STAMINA_MAXIMA       : float = 100.0
const STAMINA_CONSUMO      : float = 20.0   # por segundo correndo
const STAMINA_REGEN        : float = 12.0   # por segundo parado/andando
const STAMINA_MIN_CORRIDA  : float = 10.0   # mínimo para iniciar sprint

var stamina       : float = STAMINA_MAXIMA
var esta_correndo : bool  = false

signal stamina_alterada(valor: float, maximo: float)

# ── Agachar ───────────────────────────────────────────────────────────────────
var esta_agachado : bool = false

@onready var colisao : CollisionShape2D = $CollisionShape2D

var camera: Camera2D = null

## Área2D que define os limites do mapa. Atribuir externamente pela cena.
var area_limite: Area2D = null

# ── Câmera: offset ao grudar em parede ───────────────────────────────────────
const CAM_OFFSET_PAREDE  : float = 100.0   # pixels de avanço
const CAM_TEMPO_PAREDE   : float = 1.0     # segundos pressionando parede p/ ativar
const CAM_TWEEN_DURACAO  : float = 0.3     # duração do tween

var _cam_tween            : Tween   = null
var _cam_offset_alvo      : Vector2 = Vector2.ZERO
var _tempo_na_parede      : float   = 0.0
var _direcao_parede       : Vector2 = Vector2.ZERO

# Tamanhos da cápsula: altura normal / agachado
const ALTURA_NORMAL    : float = 28.0
const ALTURA_AGACHADO  : float = 14.0

# ── Som ───────────────────────────────────────────────────────────────────────
const SOM_OCIOSO    : float = 0.0    # parado
const SOM_ANDANDO   : float = 80.0   # raio de som andando
const SOM_CORRENDO  : float = 200.0  # raio de som correndo
const SOM_AGACHADO  : float = 30.0   # raio agachado andando

var _nivel_som_acumulado : float = 0.0

## Referência ao companheiro atual. Atribuída externamente pela cena.
var companheiro: Companheiro = null

## Emitido quando o companheiro é sacrificado com sucesso.
signal companheiro_sacrificado


func _ready() -> void:
	add_to_group("player")
	_criar_camera()


func _criar_camera() -> void:
	camera = Camera2D.new()
	camera.position = Vector2.ZERO
	camera.enabled = true
	add_child(camera)


## Chama após atribuir area_limite para aplicar os limites à câmera.
func aplicar_limites_camera() -> void:
	if camera == null or area_limite == null:
		return
	var shape_node := area_limite.get_node_or_null("CollisionShape2D")
	if shape_node == null or shape_node.shape == null:
		push_warning("MC: area_limite sem CollisionShape2D válido.")
		return
	var rect := _rect_do_shape(shape_node)
	camera.limit_left   = int(rect.position.x)
	camera.limit_top    = int(rect.position.y)
	camera.limit_right  = int(rect.end.x)
	camera.limit_bottom = int(rect.end.y)


func _rect_do_shape(shape_node: CollisionShape2D) -> Rect2:
	var origin: Vector2 = area_limite.global_position + shape_node.position
	var shape := shape_node.shape
	if shape is RectangleShape2D:
		var half : Vector2 = shape.size * 0.5
		return Rect2(origin - half, shape.size)
	if shape is CircleShape2D:
		var r : float = shape.radius
		return Rect2(origin - Vector2(r, r), Vector2(r * 2.0, r * 2.0))
	# fallback genérico
	return Rect2(origin, Vector2(1920, 1080))


func _physics_process(delta: float) -> void:
	var direcao := Input.get_vector("move_left", "move_right", "move_up", "move_down")

	_processar_agachar()
	_processar_corrida(direcao, delta)

	var vel_alvo : float = _velocidade_atual()
	if direcao != Vector2.ZERO:
		velocity = velocity.move_toward(direcao * vel_alvo, aceleracao * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, atrito * delta)

	move_and_slide()
	_processar_som(direcao, delta)
	_processar_camera_parede(direcao, delta)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("abrir_inventario"):
		var inv := get_tree().root.get_node_or_null("LoreInventario")
		if inv:
			inv.alternar()
		get_viewport().set_input_as_handled()


# ════════════════════════════════════════════════════════════════════════════
#  CORRIDA
# ════════════════════════════════════════════════════════════════════════════

func _processar_corrida(direcao: Vector2, delta: float) -> void:
	var quer_correr := Input.is_action_pressed("correr") and direcao != Vector2.ZERO and not esta_agachado

	if quer_correr and stamina >= STAMINA_MIN_CORRIDA:
		esta_correndo = true
		stamina = maxf(0.0, stamina - STAMINA_CONSUMO * delta)
	else:
		esta_correndo = false
		if stamina < STAMINA_MAXIMA:
			stamina = minf(STAMINA_MAXIMA, stamina + STAMINA_REGEN * delta)

	stamina_alterada.emit(stamina, STAMINA_MAXIMA)


func _velocidade_atual() -> float:
	if esta_correndo:
		return VELOCIDADE_CORRIDA
	if esta_agachado:
		return velocidade_maxima * 0.5
	return velocidade_maxima


# ════════════════════════════════════════════════════════════════════════════
#  AGACHAR
# ════════════════════════════════════════════════════════════════════════════

func _processar_agachar() -> void:
	if Input.is_action_just_pressed("agachar"):
		esta_agachado = not esta_agachado
		if esta_agachado:
			esta_correndo = false
		_redimensionar_colisao(esta_agachado)


func _redimensionar_colisao(agachado: bool) -> void:
	if colisao == null:
		return
	var shape := colisao.shape
	if shape is CapsuleShape2D:
		shape.height = ALTURA_AGACHADO if agachado else ALTURA_NORMAL
	elif shape is RectangleShape2D:
		shape.size.y = ALTURA_AGACHADO if agachado else ALTURA_NORMAL


# ════════════════════════════════════════════════════════════════════════════
#  SOM
# ════════════════════════════════════════════════════════════════════════════

func _processar_som(direcao: Vector2, delta: float) -> void:
	var nivel_alvo := _calcular_nivel_som(direcao)

	# Suaviza variações bruscas de nível de som
	_nivel_som_acumulado = lerpf(_nivel_som_acumulado, nivel_alvo, 4.0 * delta)

	if _nivel_som_acumulado > 5.0:
		get_tree().call_group("inimigos", "ouvir_barulho", global_position, _nivel_som_acumulado)


func _calcular_nivel_som(direcao: Vector2) -> float:
	if direcao == Vector2.ZERO:
		return SOM_OCIOSO
	if esta_correndo:
		return SOM_CORRENDO
	if esta_agachado:
		return SOM_AGACHADO
	return SOM_ANDANDO



# ════════════════════════════════════════════════════════════════════════════
#  API DE COMPANHEIRO
# ════════════════════════════════════════════════════════════════════════════

## Registra o companheiro e o ativa para seguir este player.
func registrar_companheiro(npc: Companheiro) -> void:
	if companheiro != null:
		_desconectar_companheiro()
	companheiro = npc
	companheiro.ativar(self)
	companheiro.sacrificado.connect(_ao_companheiro_sacrificado)
	companheiro.tree_exited.connect(_ao_companheiro_removido)


## Ordena o companheiro a executar uma skill em um alvo opcional.
## Retorna false se não houver companheiro ou atributo insuficiente.
func ordenar_skill(skill: String, alvo: Node = null) -> bool:
	if companheiro == null:
		return false
	return companheiro.executar_skill(skill, alvo)


## Sacrifica o companheiro como isca para distrair inimigos.
## Retorna false se o companheiro não puder ser sacrificado.
func sacrificar_companheiro() -> bool:
	if companheiro == null:
		return false
	return companheiro.sacrificar()


# ─── Handlers internos ────────────────────────────────────────────────────────

func _ao_companheiro_sacrificado() -> void:
	companheiro_sacrificado.emit()
	companheiro = null


func _ao_companheiro_removido() -> void:
	companheiro = null


func _desconectar_companheiro() -> void:
	if companheiro.sacrificado.is_connected(_ao_companheiro_sacrificado):
		companheiro.sacrificado.disconnect(_ao_companheiro_sacrificado)
	if companheiro.tree_exited.is_connected(_ao_companheiro_removido):
		companheiro.tree_exited.disconnect(_ao_companheiro_removido)


# ════════════════════════════════════════════════════════════════════════════
#  CÂMERA — OFFSET DE PAREDE
# ════════════════════════════════════════════════════════════════════════════

func _processar_camera_parede(direcao: Vector2, delta: float) -> void:
	if camera == null:
		return

	# Player pressionando direção mas velocity nessa direção é ~0 → parede
	var preso := direcao != Vector2.ZERO and velocity.length() < 10.0

	if preso:
		_tempo_na_parede += delta
		_direcao_parede = direcao.normalized()

		if _tempo_na_parede >= CAM_TEMPO_PAREDE:
			var offset_desejado := _direcao_parede * CAM_OFFSET_PAREDE
			if _cam_offset_alvo != offset_desejado:
				_cam_offset_alvo = offset_desejado
				_animar_offset_camera(_cam_offset_alvo)
	else:
		_tempo_na_parede = 0.0
		_direcao_parede = Vector2.ZERO

		# Volta ao centro quando para ou muda direção
		if _cam_offset_alvo != Vector2.ZERO:
			_cam_offset_alvo = Vector2.ZERO
			_animar_offset_camera(Vector2.ZERO)


func _animar_offset_camera(alvo: Vector2) -> void:
	if _cam_tween:
		_cam_tween.kill()
	_cam_tween = create_tween()
	_cam_tween.tween_property(camera, "offset", alvo, CAM_TWEEN_DURACAO) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
