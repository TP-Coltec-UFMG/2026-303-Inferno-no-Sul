extends PortaTransicao
class_name PortaLockpick

const CENA_LOCKPICK := preload("res://scenes/game/jogo_lockpick.tscn")

var _overlay: CanvasLayer = null
var _lockpick: Node = null
var _player_physics_ativo := true
var _player_unhandled_input_ativo := true


func _ready() -> void:
	super()
	prompt_texto = "Abrir fechadura  [E]"
	if _prompt:
		_prompt.text = prompt_texto

	# Esta porta deve obrigatoriamente usar o minigame. Isso impede que a
	# habilidade automática de lockpicking do companheiro pule o desafio.
	remove_from_group("porta_trancada")


func _ao_interagir() -> void:
	match estado:
		Estado.TRANCADA:
			_abrir_lockpick()
		Estado.DESBLOQUEADA, Estado.ABERTA:
			super()


func _abrir_lockpick() -> void:
	if is_instance_valid(_overlay):
		return

	if _prompt:
		_prompt.visible = false

	_congelar_player()

	var game := get_tree().root.get_node_or_null("Game")
	var pai_overlay: Node = game if game != null else get_tree().root

	_overlay = CanvasLayer.new()
	_overlay.name = "LockpickOverlay"
	_overlay.layer = 50
	_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	pai_overlay.add_child(_overlay)

	# Escurece o jogo atrás do minigame e captura cliques.
	var fundo := ColorRect.new()
	fundo.position = Vector2.ZERO
	fundo.size = get_viewport_rect().size
	fundo.color = Color(0.0, 0.0, 0.0, 0.72)
	fundo.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.add_child(fundo)

	_lockpick = CENA_LOCKPICK.instantiate()
	_lockpick.process_mode = Node.PROCESS_MODE_ALWAYS
	_overlay.add_child(_lockpick)
	_lockpick.venceu.connect(_ao_lockpick_vencido)
	_lockpick.cancelado.connect(_ao_lockpick_cancelado)


func _ao_lockpick_vencido() -> void:
	_fechar_lockpick()
	destrancar()
	abrir()
	_transicionar.call_deferred()


func _ao_lockpick_cancelado() -> void:
	_fechar_lockpick()
	if _prompt and _player_dentro:
		_prompt.visible = true


func _congelar_player() -> void:
	if not is_instance_valid(_player_ref):
		return

	_player_physics_ativo = _player_ref.is_physics_processing()
	_player_unhandled_input_ativo = _player_ref.is_processing_unhandled_input()
	_player_ref.velocity = Vector2.ZERO
	_player_ref.set_physics_process(false)
	_player_ref.set_process_unhandled_input(false)


func _restaurar_player() -> void:
	if not is_instance_valid(_player_ref):
		return

	_player_ref.set_physics_process(_player_physics_ativo)
	_player_ref.set_process_unhandled_input(_player_unhandled_input_ativo)


func _fechar_lockpick() -> void:
	_restaurar_player()

	if is_instance_valid(_overlay):
		_overlay.queue_free()
	_overlay = null
	_lockpick = null
