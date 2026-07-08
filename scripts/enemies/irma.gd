extends CharacterBody2D

enum Estado {
	OCIOSO,
	PATRULHA,
	PROCURA,
	CHAMAR_MEDICO
}

@export var velocidade_patrulha : float = 60.0
@export var velocidade_procura  : float = 80.0
@export var velocidade_fuga     : float = 140.0
@export var raio_deteccao       : float = 200.0
@export var taxa_esquecimento   : int   = 2

## Marker2D no corredor — destino de fuga ao chamar médico.
@export var ponto_chamar_medico : Marker2D = null

@onready var agente_navegacao : NavigationAgent2D = $NavigationAgent2D
@onready var sprite           : AnimatedSprite2D  = $AnimatedSprite2D
@onready var raio_visao       : RayCast2D         = $VisionRay

var estado            : Estado  = Estado.OCIOSO
var jogador           : Node2D  = null
var pontos_rota       : Array[Vector2] = []
var indice_ponto_rota : int     = 0

var tempo_visto          : int     = 0
var ultima_pos_jogador   : Vector2 = Vector2.ZERO
var temporizador_procura : float   = 0.0
var medico_ja_chamado    : bool    = false
var temporizador_chamar  : float   = 0.0

const DURACAO_CHAMAR  : float = 10.0
const DURACAO_PROCURA : float = 10.0


func _ready() -> void:
	add_to_group("inimigos")
	for wp in $WaypointMarkers.get_children():
		pontos_rota.append(wp.global_position)
	set_physics_process(false)


func _physics_process(delta: float) -> void:
	_atualizar_visao()

	match estado:
		Estado.PATRULHA:      _estado_patrulha(delta)
		Estado.PROCURA:       _estado_procura(delta)
		Estado.CHAMAR_MEDICO: _estado_chamar_medico(delta)


# ════════════════════════════════════════════════════════════════════════════
#  VISÃO — detecção direta dispara CHAMAR_MEDICO imediatamente
# ════════════════════════════════════════════════════════════════════════════

func _atualizar_visao() -> void:
	if estado == Estado.CHAMAR_MEDICO:
		return
	if jogador == null:
		tempo_visto = max(0, tempo_visto - taxa_esquecimento)
		return

	if _pode_ver_jogador():
		ultima_pos_jogador = jogador.global_position
		# Avistou diretamente → chama médico sem acúmulo de timer
		if not medico_ja_chamado:
			_mudar_estado(Estado.CHAMAR_MEDICO)
	else:
		tempo_visto = max(0, tempo_visto - taxa_esquecimento)
		if estado == Estado.PATRULHA and ultima_pos_jogador != Vector2.ZERO:
			_mudar_estado(Estado.PROCURA)


# ════════════════════════════════════════════════════════════════════════════
#  ESTADOS
# ════════════════════════════════════════════════════════════════════════════

func _estado_patrulha(_delta: float) -> void:
	if pontos_rota.is_empty():
		return
	agente_navegacao.target_position = pontos_rota[indice_ponto_rota]
	var dir := agente_navegacao.get_next_path_position() - global_position
	velocity = dir.normalized() * velocidade_patrulha
	move_and_slide()
	_virar_para_direcao(dir)
	if global_position.distance_to(pontos_rota[indice_ponto_rota]) < 12.0:
		indice_ponto_rota = (indice_ponto_rota + 1) % pontos_rota.size()


func _estado_procura(delta: float) -> void:
	temporizador_procura -= delta

	if _pode_ver_jogador():
		if not medico_ja_chamado:
			_mudar_estado(Estado.CHAMAR_MEDICO)
		return

	if ultima_pos_jogador != Vector2.ZERO:
		agente_navegacao.target_position = ultima_pos_jogador
		var dir := agente_navegacao.get_next_path_position() - global_position
		velocity = dir.normalized() * velocidade_procura
		move_and_slide()
		_virar_para_direcao(dir)
		if global_position.distance_to(ultima_pos_jogador) < 20.0:
			ultima_pos_jogador = Vector2.ZERO
			velocity = Vector2.ZERO
			sprite.play("idle")

	if temporizador_procura <= 0.0:
		tempo_visto = 0
		medico_ja_chamado = false
		_mudar_estado(Estado.PATRULHA)


func _estado_chamar_medico(delta: float) -> void:
	temporizador_chamar -= delta

	var destino := _obter_destino_fuga()
	agente_navegacao.target_position = destino
	var dir := agente_navegacao.get_next_path_position() - global_position
	velocity = dir.normalized() * velocidade_fuga
	move_and_slide()
	_virar_para_direcao(dir)

	var chegou := global_position.distance_to(destino) < 24.0
	if chegou or temporizador_chamar <= 0.0:
		if not medico_ja_chamado:
			medico_ja_chamado = true
			EventBus.medico_chamado.emit(global_position)
		tempo_visto = 0
		_mudar_estado(Estado.PATRULHA)


# ════════════════════════════════════════════════════════════════════════════
#  HELPERS
# ════════════════════════════════════════════════════════════════════════════

func _obter_destino_fuga() -> Vector2:
	if ponto_chamar_medico != null:
		return ponto_chamar_medico.global_position
	if jogador != null:
		return global_position + (global_position - jogador.global_position).normalized() * 300.0
	return global_position


func _mudar_estado(novo_estado: Estado) -> void:
	estado = novo_estado
	match novo_estado:
		Estado.OCIOSO:
			velocity = Vector2.ZERO
			sprite.play("idle")
			set_physics_process(false)
		Estado.PATRULHA:
			sprite.play("walk")
			set_physics_process(true)
		Estado.PROCURA:
			temporizador_procura = randf_range(6.0, DURACAO_PROCURA)
			sprite.play("idle")
			set_physics_process(true)
		Estado.CHAMAR_MEDICO:
			temporizador_chamar = DURACAO_CHAMAR
			medico_ja_chamado = false
			sprite.play("run")
			set_physics_process(true)


func ativar_ia(j: Node2D) -> void:
	jogador = j
	_mudar_estado(Estado.PATRULHA)


func desativar_ia() -> void:
	jogador = null
	tempo_visto = 0
	medico_ja_chamado = false
	_mudar_estado(Estado.OCIOSO)


func ouvir_barulho(origem: Vector2, raio: float) -> void:
	if estado == Estado.CHAMAR_MEDICO:
		return
	if global_position.distance_to(origem) > raio:
		return
	ultima_pos_jogador = origem
	if estado == Estado.PATRULHA or estado == Estado.OCIOSO:
		_mudar_estado(Estado.PROCURA)


func _pode_ver_jogador() -> bool:
	if jogador == null or global_position.distance_to(jogador.global_position) > raio_deteccao:
		return false
	raio_visao.target_position = raio_visao.to_local(jogador.global_position)
	raio_visao.force_raycast_update()
	if raio_visao.is_colliding():
		return raio_visao.get_collider() == jogador
	return false


func _virar_para_direcao(dir: Vector2) -> void:
	if dir.x != 0:
		sprite.flip_h = dir.x < 0
