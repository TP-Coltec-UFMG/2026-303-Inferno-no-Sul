extends Node2D

signal venceu
signal cancelado

@onready var locks: Dictionary = {"lock1": $Locks/Lock1, "lock2": $Locks/Lock2, "lock3": $Locks/Lock3, "lock4": $Locks/Lock4, "lock5": $Locks/Lock5, "lock6": $Locks/Lock6}
@onready var margem: Area2D = $Margem
@onready var linha: Area2D = $Linha
@onready var label: Label = $LabelInicial

@export var dificuldade_geral := 0.7
var ordem: Array[String] = ["lock1", "lock2", "lock3", "lock4","lock5", "lock6"]
var velocidades: Dictionary = {}
var posicoes_iniciais: Dictionary = {}
var jogo_iniciado := false
var jogo_terminado := false
var foco_atual := 0

func _ready() -> void:
	position = get_viewport_rect().size * 0.5
	for nome in ordem:
		posicoes_iniciais[nome] = locks[nome].position
		locks[nome].area_entered.connect(_on_lock_area_entered.bind(nome))
	_preparar_tentativa()

func _preparar_tentativa() -> void:
	jogo_iniciado = false
	jogo_terminado = false
	foco_atual = 0
	label.text = "Clique ou aperte ESPACO enquanto a\nbarra estiver na linha"
	label.visible = true
	for nome in ordem:
		var lock: Area2D = locks[nome]
		lock.position = posicoes_iniciais[nome]
		lock.visible = false
		lock.scale.y = randf_range(1.6, 4.3) * dificuldade_geral
	for nome in ordem:
		velocidades[nome] = randf_range(100.0 / dificuldade_geral, 250.0 / dificuldade_geral)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		cancelado.emit()
		return
	var interagiu: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	interagiu = interagiu or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE)
	if not interagiu:
		return
	get_viewport().set_input_as_handled()
	if jogo_terminado:
		_preparar_tentativa()
		_iniciar_jogo()
	elif not jogo_iniciado:
		_iniciar_jogo()
	else:
		_tentar_acertar()

func _iniciar_jogo() -> void:
	jogo_iniciado = true
	label.visible = false
	locks[ordem[foco_atual]].visible = true

func _tentar_acertar() -> void:
	var lock_atual: Area2D = locks[ordem[foco_atual]]
	if lock_atual.get_overlapping_areas().has(linha):
		lock_atual.visible = false
		foco_atual += 1
		if foco_atual >= ordem.size():
			_vencer()
		else:
			locks[ordem[foco_atual]].visible = true
	else:
		jogo_terminado = true
		label.text = "Voce perdeu!\nClique ou aperte ESPACO para tentar novamente"
		label.visible = true

func _vencer() -> void:
	jogo_terminado = true
	label.text = "Fechadura aberta!"
	label.visible = true
	await get_tree().create_timer(0.6).timeout
	if is_inside_tree():
		venceu.emit()

func _process(delta: float) -> void:
	if jogo_iniciado and not jogo_terminado:
		var nome: String = ordem[foco_atual]
		locks[nome].position.y += float(velocidades[nome]) * delta

func _on_lock_area_entered(area: Area2D, nome: String) -> void:
	if area == margem:
		velocidades[nome] = -float(velocidades[nome])
