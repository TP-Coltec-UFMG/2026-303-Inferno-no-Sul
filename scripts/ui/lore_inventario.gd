extends CanvasLayer
class_name LoreInventario

# ════════════════════════════════════════════════════════════════════════════
#  LoreInventario — UI de grade para rever lores desbloqueados.
#
#  Hierarquia esperada:
#    LoreInventario (CanvasLayer, layer=11)
#    └── Painel (Control, full-rect)
#        ├── BtnFechar (Button)
#        ├── Grade (GridContainer, columns=4)
#        └── Viewer (sub-painel de detalhes)
#            ├── ImagemDetalhe (TextureRect)
#            ├── TituloDetalhe (Label)
#            └── DescricaoDetalhe (Label)
# ════════════════════════════════════════════════════════════════════════════

@onready var painel          : Control       = $Painel
@onready var grade           : GridContainer = $Painel/ScrollContainer/Grade
@onready var btn_fechar      : Button        = $Painel/BtnFechar
@onready var viewer          : Control       = $Painel/Viewer
@onready var imagem_detalhe  : TextureRect   = $Painel/Viewer/VBox/ImagemDetalhe
@onready var titulo_detalhe  : Label         = $Painel/Viewer/VBox/TituloDetalhe
@onready var descricao_detalhe: Label        = $Painel/Viewer/VBox/DescricaoDetalhe

const TAMANHO_THUMB := Vector2(128.0, 128.0)


func _ready() -> void:
	painel.visible = false
	viewer.visible = false
	btn_fechar.pressed.connect(fechar)


func _unhandled_input(event: InputEvent) -> void:
	if painel.visible and event.is_action_pressed("ui_cancel"):
		fechar()
		get_viewport().set_input_as_handled()


# ════════════════════════════════════════════════════════════════════════════
#  ABRIR / FECHAR
# ════════════════════════════════════════════════════════════════════════════

func abrir() -> void:
	_popular_grade()
	viewer.visible    = false
	painel.visible    = true
	get_tree().paused = true


func fechar() -> void:
	painel.visible    = false
	get_tree().paused = false


func alternar() -> void:
	if painel.visible:
		fechar()
	else:
		abrir()


# ════════════════════════════════════════════════════════════════════════════
#  GRADE
# ════════════════════════════════════════════════════════════════════════════

func _popular_grade() -> void:
	# Limpa filhos anteriores
	for filho in grade.get_children():
		filho.queue_free()

	var todos := LoreManager.todos()
	if todos.is_empty():
		var aviso := Label.new()
		aviso.text = "Nenhum documento encontrado."
		grade.add_child(aviso)
		return

	for dados: LoreManager.DadosLore in todos:
		var btn := _criar_thumbnail(dados)
		grade.add_child(btn)


func _criar_thumbnail(dados: LoreManager.DadosLore) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = TAMANHO_THUMB
	btn.tooltip_text        = dados.titulo

	var tex_rect := TextureRect.new()
	tex_rect.texture              = dados.textura
	tex_rect.expand_mode          = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	tex_rect.stretch_mode         = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	tex_rect.mouse_filter         = Control.MOUSE_FILTER_IGNORE
	btn.add_child(tex_rect)

	btn.pressed.connect(_ao_selecionar.bind(dados))
	return btn


# ════════════════════════════════════════════════════════════════════════════
#  DETALHE
# ════════════════════════════════════════════════════════════════════════════

func _ao_selecionar(dados: LoreManager.DadosLore) -> void:
	imagem_detalhe.texture    = dados.textura
	titulo_detalhe.text       = dados.titulo
	descricao_detalhe.text    = dados.descricao
	viewer.visible            = true
