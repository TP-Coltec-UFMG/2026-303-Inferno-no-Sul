extends CharacterBody2D
class_name Companheiro

signal sacrificado
signal skill_executada(skill: String)

enum Estado { OCIOSO, SEGUINDO, EXECUTANDO_SKILL, ISCA, MORTO }

# ─── Movimento ───────────────────────────────────────────────────────────────

@export_group("Movimento")
@export var velocidade       : float = 120.0
## Distância em que o companheiro para de andar. Precisa ser maior que a
## soma dos raios de colisão do companheiro + jogador, senão os dois ficam
## fisicamente sobrepostos mesmo "parados", travando ações do jogador
## (colisão empurrando um no outro).
@export var distancia_seguir : float = 90.0
@export var distancia_maxima : float = 400.0
@export var acelerecao : float = 20.0

## Distância mínima que o jogador precisa se afastar para o companheiro
## COMEÇAR a persegui-lo. Enquanto a distância estiver abaixo disso, ele
## fica parado (mesmo em Estado.SEGUINDO) — evita que ele fique "colado"
## reagindo a cada micro-movimento do jogador. Precisa ser maior que
## `distancia_seguir` para não ficar oscilando entre andar/parar.
@export var distancia_ativacao : float = 220.0

# ─── Skills disponíveis (sempre usáveis, sem limiar) ─────────────────────────

var SKILLS_VALIDAS : Array[String] = ["arremesso", "lockpicking", "distracao"]

# ─── Raio fixo de distração ───────────────────────────────────────────────────

const RAIO_DISTRACAO : float = 300.0
const IMPULSO_ARREMESSO : float = 600.0

@onready var agente_navegacao : NavigationAgent2D = $NavigationAgent2D
var animacao : AnimatedSprite2D = null

var id_npc : String = ""
var estado : Estado = Estado.OCIOSO
var jogador : Node2D = null

var _skill_ativa     : String = ""
var _skill_alvo      : Node   = null
var _skill_concluida : bool   = false

## Controla a histerese de ativação da perseguição (ver distancia_ativacao).
var _perseguindo_ativo : bool = false


func _ready() -> void:
	add_to_group("companheiros")
	animacao = get_node_or_null("AnimatedSprite2D")
	set_physics_process(false)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and estado != Estado.MORTO:
		if id_npc != "":
			NPCManager.sincronizar(self)


func _physics_process(delta: float) -> void:
	match estado:
		Estado.SEGUINDO:         _estado_seguindo(delta)
		Estado.EXECUTANDO_SKILL: _estado_executando_skill()
		Estado.ISCA:             _estado_isca()


# ════════════════════════════════════════════════════════════════════════════
#  API PÚBLICA
# ════════════════════════════════════════════════════════════════════════════

func ativar(j: Node2D) -> void:
	jogador = j
	_mudar_estado(Estado.SEGUINDO)


func pausar() -> void:
	_mudar_estado(Estado.OCIOSO)


func executar_skill(skill: String, alvo: Node = null) -> bool:
	if estado == Estado.MORTO or estado == Estado.ISCA:
		return false
	if skill not in SKILLS_VALIDAS:
		push_warning("Companheiro: skill '%s' desconhecida." % skill)
		return false
	_skill_ativa     = skill
	_skill_alvo      = alvo
	_skill_concluida = false
	_mudar_estado(Estado.EXECUTANDO_SKILL)
	return true


func sacrificar() -> bool:
	if estado == Estado.MORTO or estado == Estado.ISCA:
		return false
	_mudar_estado(Estado.ISCA)
	return true


func pode_usar_skill(_skill: String) -> bool:
	return estado != Estado.MORTO and estado != Estado.ISCA


func pode_sacrificar() -> bool:
	return estado != Estado.MORTO and estado != Estado.ISCA


# ════════════════════════════════════════════════════════════════════════════
#  ESTADOS
# ════════════════════════════════════════════════════════════════════════════

func _estado_seguindo(delta: float) -> void:
	if jogador == null:
		return
		
	var dist := global_position.distance_to(jogador.global_position)

	# ─── Zona de conforto pessoal (sempre ativa) ────────────────────────────
	# Sempre que estiver mais perto do jogador do que distancia_seguir, o
	# Doidinho se afasta — independente de já estar "perseguindo" ou não.
	# Antes essa checagem só rodava depois que a perseguição era ativada,
	# então se ele nascesse perto do jogador (ex: início do dormitório) e o
	# jogador não se afastasse o suficiente pra disparar a perseguição, ele
	# ficava parado exatamente onde nasceu — colado, sem nunca se afastar.
	# Agora a distância mínima vale sempre, não só durante perseguição ativa.
	if dist < distancia_seguir:
		_perseguindo_ativo = false
		if dist > 0.001:
			var afastar := (global_position - jogador.global_position).normalized()
			# Quanto mais perto (sobrepondo de verdade), mais rápido se afasta;
			# perto do limite, o movimento é bem suave.
			var urgencia := clampf(1.0 - (dist / distancia_seguir), 0.0, 1.0)
			var velocidade_alvo := afastar * velocidade * lerpf(0.15, 0.8, urgencia)
			velocity = velocity.move_toward(velocidade_alvo, 800.0 * delta)
		else:
			velocity = velocity.move_toward(Vector2.ZERO, 600.0 * delta)
		move_and_slide()
		return

	# ─── Histerese de ativação ─────────────────────────────────────────────
	# Só passa a perseguir de fato quando o jogador se afasta além de
	# distancia_ativacao; enquanto isso não acontecer (mas já estando fora
	# da zona de conforto acima), fica parado — evita ficar oscilando
	# andando/parando toda hora perto do jogador.
	if not _perseguindo_ativo:
		if dist > distancia_ativacao:
			_perseguindo_ativo = true
		else:
			velocity = velocity.move_toward(Vector2.ZERO, 600.0 * delta)
			move_and_slide()
			return

	# ─────────────────────────────────────────────────────────────────────
	# NOTA: nenhuma das fases do jogo possui um NavigationRegion2D (navmesh)
	# criado, então o NavigationAgent2D nunca consegue calcular uma rota de
	# verdade — get_next_path_position()/is_navigation_finished() ficam com
	# retorno inconsistente, e é isso que causava o "teleporte". Enquanto
	# não houver navmesh nas cenas, perseguimos o jogador diretamente
	# (linha reta) usando física normal. Como o Doidinho é um
	# CharacterBody2D com a mesma collision_layer/mask das paredes da
	# TileMap, o move_and_slide() abaixo já impede que ele atravesse
	# paredes e o mantém dentro da área jogável — sem precisar de navmesh.
	# Se um NavigationRegion2D for adicionado nas fases no futuro, dá pra
	# voltar a usar agente_navegacao.get_next_path_position() aqui.
	# ─────────────────────────────────────────────────────────────────────
	var dir := (jogador.global_position - global_position).normalized()

	# Se o jogador estiver muito longe, dá um bônus de velocidade em vez de teleportar
	var velocidade_atual = velocidade
	if dist > distancia_maxima:
		velocidade_atual = velocidade * 1.8 

	# Em vez de aplicar a velocidade instantaneamente (velocity = dir * velocidade),
	# usamos move_toward com delta para uma aceleração fluida e sem travamentos
	var velocidade_alvo = dir * velocidade_atual
	velocity = velocity.move_toward(velocidade_alvo, 800.0 * delta)
	
	move_and_slide()


func _estado_executando_skill() -> void:
	if _skill_concluida:
		_mudar_estado(Estado.SEGUINDO)
		return
	match _skill_ativa:
		"arremesso":   _skill_arremesso()
		"lockpicking": _skill_lockpicking()
		"distracao":   _skill_distracao()


func _estado_isca() -> void:
	velocity = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized() * velocidade * 1.5
	move_and_slide()


# ════════════════════════════════════════════════════════════════════════════
#  SKILLS
# ════════════════════════════════════════════════════════════════════════════

func _skill_arremesso() -> void:
	if _skill_alvo == null:
		_skill_concluida = true
		return
	if _skill_alvo is RigidBody2D:
		var dir : Vector2 = (_skill_alvo.global_position - global_position).normalized()
		(_skill_alvo as RigidBody2D).apply_central_impulse(dir * IMPULSO_ARREMESSO)
	if _skill_alvo.has_method("receber_impacto"):
		_skill_alvo.receber_impacto()
	if animacao: animacao.play("throw")
	skill_executada.emit("arremesso")
	_skill_concluida = true


func _skill_lockpicking() -> void:
	if _skill_alvo == null:
		_skill_concluida = true
		return
	if _skill_alvo.has_method("destrancar"):
		_skill_alvo.destrancar()
		skill_executada.emit("lockpicking")
	if animacao: animacao.play("interact")
	_skill_concluida = true


func _skill_distracao() -> void:
	get_tree().call_group("inimigos", "ouvir_barulho", global_position, RAIO_DISTRACAO)
	if animacao: animacao.play("yell")
	skill_executada.emit("distracao")
	_skill_concluida = true


# ════════════════════════════════════════════════════════════════════════════
#  SACRIFÍCIO
# ════════════════════════════════════════════════════════════════════════════

func _iniciar_sequencia_sacrificio() -> void:
	if animacao: animacao.play("sacrifice")
	get_tree().call_group("inimigos", "ouvir_barulho", global_position, 9999.0)
	await get_tree().create_timer(3.0).timeout
	sacrificado.emit()
	_mudar_estado(Estado.MORTO)


# ════════════════════════════════════════════════════════════════════════════
#  MÁQUINA DE ESTADOS
# ════════════════════════════════════════════════════════════════════════════

func _mudar_estado(novo: Estado) -> void:
	estado = novo
	match novo:
		Estado.OCIOSO:
			velocity = Vector2.ZERO
			set_physics_process(false)
			if animacao and animacao.sprite_frames.has_animation("idle"):
				animacao.play("idle")
		Estado.SEGUINDO:
			set_physics_process(true)
			if animacao and animacao.sprite_frames.has_animation("walk"):
				animacao.play("walk")
		Estado.EXECUTANDO_SKILL:
			set_physics_process(true)
		Estado.ISCA:
			set_physics_process(true)
			_iniciar_sequencia_sacrificio()
		Estado.MORTO:
			set_physics_process(false)
			velocity = Vector2.ZERO
			_morrer()


func _morrer() -> void:
	if animacao and animacao.sprite_frames.has_animation("death"):
		animacao.play("death")
	await get_tree().create_timer(1.5).timeout
	queue_free()
