extends Control

signal menu_fechado
signal opcoes_abertas
signal salvar_pedido
signal sair_para_menu_pedido

@onready var btn_continuar   : Button = %BtnContinuar
@onready var btn_opcoes      : Button = %BtnOpcoes
@onready var btn_salvar      : Button = %BtnSalvar
@onready var btn_menu        : Button = %BtnMenu

## Controlado externamente: false quando player não está no pátio.
var pode_salvar : bool = false : set = _set_pode_salvar


func _ready() -> void:
	btn_continuar.pressed.connect(_on_continuar)
	btn_opcoes.pressed.connect(_on_opcoes)
	btn_salvar.pressed.connect(_on_salvar)
	btn_menu.pressed.connect(_on_menu)

	_set_pode_salvar(pode_salvar)

	# Slide-in de baixo
	position.y = get_viewport_rect().size.y
	var tw := create_tween().set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "position:y", 0.0, 0.4)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		_on_continuar()
		get_viewport().set_input_as_handled()


func _set_pode_salvar(valor: bool) -> void:
	pode_salvar = valor
	if btn_salvar:
		btn_salvar.disabled = not valor
		btn_salvar.tooltip_text = "" if valor else "Salvar só disponível no Pátio"


func _on_continuar() -> void:
	var tw := create_tween().set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	tw.tween_property(self, "position:y", get_viewport_rect().size.y, 0.3)
	await tw.finished
	menu_fechado.emit()


func _on_opcoes() -> void:
	opcoes_abertas.emit()


func _on_salvar() -> void:
	if pode_salvar:
		salvar_pedido.emit()


func _on_menu() -> void:
	sair_para_menu_pedido.emit()
