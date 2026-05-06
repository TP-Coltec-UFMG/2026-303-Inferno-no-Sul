extends CharacterBody2D

enum Estado { OCIOSO, PATRULHA, PROCURA, CACA, ENCONTRO }

@export var velocidade_patrulha : float = 60.0
@export var velocidade_caca     : float = 120.0
@export var velocidade_procura  : float = 80.0
@export var raio_deteccao       : float = 200.0
@export var raio_perda          : float = 300.0
@export var limiar_caca         : int   = 240
@export var taxa_esquecimento   : int   = 1

@onready var agente_navegacao : NavigationAgent2D = $NavigationAgent2D
@onready var animacao         : AnimationPlayer   = $AnimationPlayer
@onready var raio_visao       : RayCast2D         = $VisionRay

var estado            : Estado = Estado.OCIOSO
var jogador           : Node2D = null
var indice_ponto_rota : int    = 0
var pontos_rota       : Array[Vector2] = []

var tempo_visto          : int = 0
var ultima_pos_jogador   : Vector2 = Vector2.ZERO
var temporizador_procura : float = 0.0

const DURACAO_PROCURA : float = 12.0

func _ready() -> void:
	for wp in $WaypointMarkers.get_children():
		pontos_rota.append(wp.global_position)
	set_process(false)

func _physics_process(delta: float) -> void:
	_atualizar_suspeita()

	match estado:
		Estado.PATRULHA: _estado_patrulha(delta)
		Estado.PROCURA:  _estado_procura(delta)
		Estado.CACA:     _estado_caca(delta)
		Estado.ENCONTRO: _estado_encontro()

func _atualizar_suspeita() -> void:
	if jogador == null:
		tempo_visto = max(0, tempo_visto - taxa_esquecimento)
		return

	var jogador_visivel = _pode_ver_jogador()

	if jogador_visivel:
		ultima_pos_jogador = jogador.global_position
		tempo_visto = min(tempo_visto + 1, limiar_caca + 60)
	else:
		tempo_visto = max(0, tempo_visto - taxa_esquecimento)

	if estado == Estado.PATRULHA and jogador_visivel:
		if tempo_visto >= limiar_caca:
			_mudar_estado(Estado.CACA)

func _pode_ver_jogador() -> bool:
	if jogador == null or _distancia_ate_jogador() > raio_deteccao:
		return false

	raio_visao.target_position = raio_visao.to_local(jogador.global_position)
	raio_visao.force_raycast_update()

	if raio_visao.is_colliding():
		return raio_visao.get_collider() == jogador
	return false

func _estado_patrulha(_delta: float) -> void:
	if pontos_rota.is_empty():
		return

	agente_navegacao.target_position = pontos_rota[indice_ponto_rota]
	var dir = agente_navegacao.get_next_path_position() - global_position
	velocity = dir.normalized() * velocidade_patrulha
	move_and_slide()

	if global_position.distance_to(pontos_rota[indice_ponto_rota]) < 12.0:
		indice_ponto_rota = (indice_ponto_rota + 1) % pontos_rota.size()

func _estado_procura(delta: float) -> void:
	temporizador_procura -= delta

	if _pode_ver_jogador() and tempo_visto >= limiar_caca:
		_mudar_estado(Estado.CACA)
		return

	if ultima_pos_jogador != Vector2.ZERO:
		agente_navegacao.target_position = ultima_pos_jogador
		var dir = agente_navegacao.get_next_path_position() - global_position
		velocity = dir.normalized() * velocidade_procura
		move_and_slide()

		if global_position.distance_to(ultima_pos_jogador) < 20.0:
			ultima_pos_jogador = Vector2.ZERO
			velocity = Vector2.ZERO
			animacao.play("look_around")

	if temporizador_procura <= 0.0:
		tempo_visto = 0
		_mudar_estado(Estado.PATRULHA)

func _estado_caca(_delta: float) -> void:
	if not _pode_ver_jogador():
		_mudar_estado(Estado.PROCURA)
		return

	if _distancia_ate_jogador() < 24.0:
		_mudar_estado(Estado.ENCONTRO)
		return

	agente_navegacao.target_position = jogador.global_position
	var dir = agente_navegacao.get_next_path_position() - global_position
	velocity = dir.normalized() * velocidade_caca
	move_and_slide()

func _estado_encontro() -> void:
	velocity = Vector2.ZERO
	animacao.play("grab")
	get_tree().call_group("game_manager", "trigger_game_over")

func _mudar_estado(novo_estado: Estado) -> void:
	estado = novo_estado
	match novo_estado:
		Estado.OCIOSO:
			animacao.play("idle")
			set_process(false)
		Estado.PATRULHA:
			animacao.play("walk")
		Estado.PROCURA:
			temporizador_procura = randf_range(6.0, DURACAO_PROCURA)
			animacao.play("look_around")
		Estado.CACA:
			animacao.play("run")
		Estado.ENCONTRO:
			pass

func ativar_ia(j: Node2D) -> void:
	jogador = j
	_mudar_estado(Estado.PATRULHA)

func desativar_ia() -> void:
	jogador = null
	tempo_visto = 0
	_mudar_estado(Estado.OCIOSO)

func _distancia_ate_jogador() -> float:
	if jogador == null:
		return INF
	return global_position.distance_to(jogador.global_position)
