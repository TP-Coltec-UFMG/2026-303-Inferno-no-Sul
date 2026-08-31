extends Node2D

signal venceu
signal cancelado

@onready var locks: Dictionary = {
	"lock1": $Locks/Lock1,
	"lock2": $Locks/Lock2,
	"lock3": $Locks/Lock3,
	"lock4": $Locks/Lock4,
}

@onready var margem: Area2D = $Margem
@onready var linha: Area2D = $Linha
@onready var label: Label = $LabelInicial

# 1.0 = padrão / > 1 = mais fácil / < 1 = mais difícil
@export var dificuldade_geral: float = 0.7

var ordem: Array[String] = ["lock1", "lock2", "lock3", "lock4"]
var velocidades: Dictionary = {}
var posicoes_iniciais: Dictionary = {}

var jogo_iniciado := false
var jogo_terminado := false
var foco_atual := 0


func _ready() -> void:
	# O minigame veio de um projeto separado com posição fixa.
	# Aqui ele sempre fica centralizado, independentemente da câmera do jogo.
	position = get_viewport_rect().size * 0.5

	for nome in ordem:
		posicoes_iniciais[nome] = locks[nome].position

	_conectar_colisoes()
	_preparar_tentativa()


func _preparar_tentativa() -> void:
	jogo_iniciado = false
	jogo_terminado = false
	foco_atual = 0

	label.text = "Clique ou aperte ESPAÇO enquanto a\nbarra estiver na linha"
	label.visible = true

	for nome in ordem:
		var lock: Area2D = locks[nome]
		lock.position = posicoes_iniciais[nome]
		lock.visible = false

	# Mantém a lógica de dificuldade do protótipo original.
	locks["lock1"].scale.y = ((randi() % 10) / 10.0 + 4.3) * dificuldade_geral
	locks["lock2"].scale.y = ((randi() % 10) / 10.0 + 3.6) * dificuldade_geral
	locks["lock3"].scale.y = ((randi() % 10) / 10.0 + 2.1) * dificuldade_geral
	locks["lock4"].scale.y = ((randi() % 10) / 10.0 + 1.6) * dificuldade_geral

	_definir_velocidade()


func _definir_velocidade() -> void:
	var maxima_velocidade := 250.0 / dificuldade_geral
	var minima_velocidade := 100.0 / dificuldade_geral

	for nome in ordem:
		velocidades[nome] = randf_range(minima_velocidade, maxima_velocidade)


func _conectar_colisoes() -> void:
	for nome in ordem:
		locks[nome].area_entered.connect(_on_lock_area_entered.bind(nome))


func _input(event: InputEvent) -> void:
	# Permite abandonar o minigame sem pausar o jogo por baixo dele.
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		cancelado.emit()
		return

	var interagiu := false
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		interagiu = true
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE:
		interagiu = true

	if not interagiu:
		return

	get_viewport().set_input_as_handled()

	# No protótipo original, depois de perder não era possível tentar de novo.
	# Agora o próximo clique/espaço reinicia imediatamente a tentativa.
	if jogo_terminado:
		_preparar_tentativa()
		_iniciar_jogo()
		return

	if not jogo_iniciado:
		_iniciar_jogo()
	else:
		_tentar_acertar()


func _iniciar_jogo() -> void:
	jogo_iniciado = true
	label.visible = false
	foco_atual = 0
	locks[ordem[foco_atual]].visible = true


func _tentar_acertar() -> void:
	var lock_atual: Area2D = locks[ordem[foco_atual]]

	var sobrepoe_linha := false
	for area in lock_atual.get_overlapping_areas():
		if area == linha:
			sobrepoe_linha = true
			break

	if sobrepoe_linha:
		lock_atual.visible = false
		foco_atual += 1

		if foco_atual >= ordem.size():
			_vencer()
		else:
			locks[ordem[foco_atual]].visible = true
	else:
		_perder()


func _vencer() -> void:
	jogo_terminado = true
	label.text = "Fechadura aberta!"
	label.visible = true

	# Dá tempo de o jogador enxergar a mensagem antes da transição.
	await get_tree().create_timer(0.6).timeout
	if is_inside_tree():
		venceu.emit()


func _perder() -> void:
	jogo_terminado = true
	label.text = "Você perdeu!\nClique ou aperte ESPAÇO para tentar novamente"
	label.visible = true


func _process(delta: float) -> void:
	if not jogo_iniciado or jogo_terminado:
		return

	var nome: String = ordem[foco_atual]
	locks[nome].position.y += float(velocidades[nome]) * delta


func _on_lock_area_entered(area: Area2D, nome: String) -> void:
	if area == margem:
		velocidades[nome] = -float(velocidades[nome])
