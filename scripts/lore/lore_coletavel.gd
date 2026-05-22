extends Area2D
class_name LoreColetavel

# ════════════════════════════════════════════════════════════════════════════
#  LoreColetavel — Area2D colocado no cenário
#
#  Configurar no editor:
#    id          → identificador único (ex: "carta_01")
#    textura     → Texture2D do documento/imagem
#    textura_path → "res://assets/lore/carta_01.png" (mesmo recurso, como String)
#    titulo      → nome exibido no inventário
#    descricao   → texto exibido no visualizador
#
#  Requer filho: CollisionShape2D
#  Requer autoloads: LoreManager, LoreViewer (cena injetada no root)
# ════════════════════════════════════════════════════════════════════════════

@export_group("Lore")
@export var id           : String   = ""
@export var textura      : Texture2D
@export var textura_path : String   = ""  ## res:// path da mesma textura (para serialização)
@export var titulo       : String   = ""
@export var descricao    : String   = ""

@export_group("Interação")
@export var raio_prompt  : float    = 80.0  ## Distância para mostrar prompt "Pressione E"

## Referência ao nó de prompt (Label/Sprite filho opcional — nome "Prompt")
@onready var _prompt : Node = get_node_or_null("Prompt")

var _player_dentro : bool = false


func _ready() -> void:
	if LoreManager.coletado(id):
		queue_free()
		return

	body_entered.connect(_ao_entrar)
	body_exited.connect(_ao_sair)
	if _prompt:
		_prompt.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if _player_dentro and event.is_action_pressed("interact"):
		_coletar()
		get_viewport().set_input_as_handled()


func _ao_entrar(body: Node2D) -> void:
	if body is MC:
		_player_dentro = true
		if _prompt:
			_prompt.visible = true


func _ao_sair(body: Node2D) -> void:
	if body is MC:
		_player_dentro = false
		if _prompt:
			_prompt.visible = false


func _coletar() -> void:
	if textura == null:
		push_error("LoreColetavel '%s': textura não configurada." % id)
		return

	var dados := LoreManager.DadosLore.new(id, textura, textura_path, titulo, descricao)
	LoreManager.coletar(dados)
	LoreManager.salvar()

	# Abre visualizador injetado no root
	var viewer := get_tree().root.get_node_or_null("LoreViewer")
	if viewer:
		viewer.exibir(dados)

	queue_free()
