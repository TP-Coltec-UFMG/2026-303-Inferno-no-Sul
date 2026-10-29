extends Node

const _TIPOS_TEXTO := [
	"Label", "Button", "CheckButton", "CheckBox", "OptionButton",
	"LineEdit", "TextEdit", "RichTextLabel", "LinkButton",
	"SpinBox", "MenuButton", "Tree", "ItemList",
]

const _TIPOS_SLIDER := ["HSlider", "VSlider"]

const MIN_FONT_SIZE     : int = 40
const DEFAULT_FONT_SIZE : int = 48
const MAX_FONT_SIZE     : int = 72

## Tamanho de fonte "base" usado como referência de escala 1.0 para sliders.
const _FONTE_BASE : int = DEFAULT_FONT_SIZE
const _SLIDER_MIN_SIZE_BASE : float = 20.0

var _tamanho_atual : int = DEFAULT_FONT_SIZE


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	var salvo := int(SettingsManager.get_setting("accessibility.font_size"))
	_tamanho_atual = clampi(salvo if salvo > 0 else DEFAULT_FONT_SIZE, MIN_FONT_SIZE, MAX_FONT_SIZE)

	SettingsManager.font_size_changed.connect(_on_font_size_changed)
	get_tree().node_added.connect(_on_node_added)

	_aplicar_tema_global(_tamanho_atual)
	aplicar_em_tudo()


func aplicar_em_tudo() -> void:
	_aplicar_recursivo(get_tree().root, _tamanho_atual)


## Sempre clampa antes de aplicar/persistir — garante que nada abaixo de 40
## ou acima de 140 chegue a ser salvo, não importa a origem da chamada.
func definir_tamanho(size: int) -> void:
	var clamped := clampi(size, MIN_FONT_SIZE, MAX_FONT_SIZE)
	SettingsManager.set_setting("accessibility.font_size", clamped)


func _on_font_size_changed(new_size: int) -> void:
	_tamanho_atual = clampi(new_size, MIN_FONT_SIZE, MAX_FONT_SIZE)
	_aplicar_tema_global(_tamanho_atual)
	aplicar_em_tudo()


func _on_node_added(node: Node) -> void:
	if _e_texto(node) or _e_slider(node):
		_aplicar_no_no(node, _tamanho_atual)


func _aplicar_recursivo(node: Node, size: int) -> void:
	if _e_texto(node) or _e_slider(node):
		_aplicar_no_no(node, size)
	for filho in node.get_children():
		_aplicar_recursivo(filho, size)


func _e_texto(node: Node) -> bool:
	for tipo in _TIPOS_TEXTO:
		if node.is_class(tipo):
			return true
	return false


func _e_slider(node: Node) -> bool:
	for tipo in _TIPOS_SLIDER:
		if node.is_class(tipo):
			return true
	return false


func _aplicar_no_no(node: Node, size: int) -> void:
	if _e_texto(node):
		node.add_theme_font_size_override("font_size", size)
		if node is RichTextLabel:
			node.add_theme_font_size_override("normal_font_size", size)
			node.add_theme_font_size_override("bold_font_size", size)
			node.add_theme_font_size_override("italics_font_size", size)

	if _e_slider(node):
		_escalar_slider(node as Range, size)


func _escalar_slider(slider: Range, size: int) -> void:
	var escala : float = float(size) / float(_FONTE_BASE)
	var nova_dimensao : float = _SLIDER_MIN_SIZE_BASE * escala

	if slider is HSlider:
		slider.custom_minimum_size.y = nova_dimensao
	elif slider is VSlider:
		slider.custom_minimum_size.x = nova_dimensao


func _aplicar_tema_global(size: int) -> void:
	var tema := ThemeDB.get_project_theme()
	if tema:
		tema.default_font_size = size
