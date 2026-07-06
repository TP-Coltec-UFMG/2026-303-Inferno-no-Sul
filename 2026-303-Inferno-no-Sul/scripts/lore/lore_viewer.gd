extends CanvasLayer
class_name LoreViewer

# ════════════════════════════════════════════════════════════════════════════
#  LoreViewer — exibe uma Texture2D ao coletar um lore.
#  Adicionado ao root via autoload ou pela cena raiz do jogo.
#
#  Hierarquia esperada:
#    LoreViewer (CanvasLayer, layer=10)
#    └── Fundo (ColorRect, full-rect, semitransparente)
#        ├── Imagem (TextureRect, expand, full-rect centrado)
#        ├── Titulo (Label)
#        ├── Descricao (Label, wrap)
#        └── BtnFechar (Button)
# ════════════════════════════════════════════════════════════════════════════

@onready var fundo     : ColorRect   = $Fundo
@onready var imagem    : TextureRect = $Fundo/Imagem
@onready var titulo    : Label       = $Fundo/Titulo
@onready var descricao : Label       = $Fundo/Descricao
@onready var btn_fechar: Button      = $Fundo/BtnFechar


func _ready() -> void:
	fundo.visible = false
	btn_fechar.pressed.connect(fechar)


func _unhandled_input(event: InputEvent) -> void:
	if fundo.visible and (event.is_action_pressed("interact") or event.is_action_pressed("ui_cancel")):
		fechar()
		get_viewport().set_input_as_handled()


## Exibe a Texture2D do lore coletado e pausa o jogo.
func exibir(dados: LoreManager.DadosLore) -> void:
	imagem.texture    = dados.textura
	titulo.text       = dados.titulo
	descricao.text    = dados.descricao
	fundo.visible     = true
	get_tree().paused = true


## Fecha o visualizador e despausa.
func fechar() -> void:
	fundo.visible     = false
	get_tree().paused = false
