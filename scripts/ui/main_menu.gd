extends Control

# ─── Referências a Nós ───────────────────────────────────────────────────────

@onready var btn_new_game:  Button = %BtnNewGame
@onready var btn_continue:  Button = %BtnContinue
@onready var btn_options:   Button = %BtnOptions
@onready var btn_credits:   Button = %BtnCredits
@onready var btn_quit:      Button = %BtnQuit
@onready var version_label: Label  = %VersionLabel

@onready var submenu_container: CanvasLayer = %SubMenuContainer

# ─── Cenas dos Submenus ──────────────────────────────────────────────────────

const SCENE_OPTIONS := preload("res://scenes/ui/options_menu.tscn")
const SCENE_CREDITS := preload("res://scenes/ui/credits_menu.tscn")

const SCENE_GAME    := "res://scenes/game/dormitorios.tscn"

# ─── Instâncias Ativas ───────────────────────────────────────────────────────

var _active_submenu: Control = null


# ════════════════════════════════════════════════════════════════════════════
#  CICLO DE VIDA
# ════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	_setup_version_label()
	_setup_continue_button()
	_connect_buttons()

	# Escuta mudanças de save em tempo real (ex: após criar um novo save).
	SaveManager.save_state_changed.connect(_on_save_state_changed)


# ─── Setup Inicial ───────────────────────────────────────────────────────────

func _setup_version_label() -> void:
	var version: String = ProjectSettings.get_setting("application/config/version", "0.1.0")
	version_label.text = "v%s" % version


func _setup_continue_button() -> void:
	# O botão só é interativo se houver um save.
	var save_exists := SaveManager.has_save_file()
	btn_continue.visible  = save_exists   # Ou use .disabled = !save_exists
	btn_continue.focus_mode = Control.FOCUS_ALL if save_exists else Control.FOCUS_NONE


# ─── Conexão de Sinais ───────────────────────────────────────────────────────

func _connect_buttons() -> void:
	btn_new_game.pressed.connect(_on_new_game_pressed)
	btn_continue.pressed.connect(_on_continue_pressed)
	btn_options.pressed.connect(_on_options_pressed)
	btn_credits.pressed.connect(_on_credits_pressed)
	btn_quit.pressed.connect(_on_quit_pressed)


# ════════════════════════════════════════════════════════════════════════════
#  HANDLERS DOS BOTÕES
# ════════════════════════════════════════════════════════════════════════════

func _on_new_game_pressed() -> void:
	_transition_to_scene(SCENE_GAME)


func _on_continue_pressed() -> void:
	# O SaveManager carrega os dados; a cena do jogo os consome.
	_transition_to_scene(SCENE_GAME)


func _on_options_pressed() -> void:
	_open_submenu(SCENE_OPTIONS)


func _on_credits_pressed() -> void:
	_open_submenu(SCENE_CREDITS)


func _on_quit_pressed() -> void:
	get_tree().quit()


# ─── Callback do SaveManager ─────────────────────────────────────────────────

func _on_save_state_changed(exists: bool) -> void:
	btn_continue.visible   = exists
	btn_continue.focus_mode = Control.FOCUS_ALL if exists else Control.FOCUS_NONE


# ════════════════════════════════════════════════════════════════════════════
#  GERENCIAMENTO DE SUBMENUS
# ════════════════════════════════════════════════════════════════════════════

## Instancia e exibe um submenu. Fecha o anterior se houver um aberto.
func _open_submenu(scene: PackedScene) -> void:
	_close_active_submenu()

	var instance: Control = scene.instantiate()
	submenu_container.add_child(instance)
	_active_submenu = instance

	# Escuta o sinal de fechamento do submenu (contrato de interface).
	if instance.has_signal("menu_closed"):
		instance.menu_closed.connect(_close_active_submenu)

	submenu_container.visible = true


## Remove e libera o submenu ativo.
func _close_active_submenu() -> void:
	if is_instance_valid(_active_submenu):
		_active_submenu.queue_free()
		_active_submenu = null

	submenu_container.visible = false


# ─── Transição de Cena ───────────────────────────────────────────────────────

## Transição suave (fade) para a próxima cena.
## Expanda com um AnimationPlayer ou SceneTransition autoload para efeitos reais.
func _transition_to_scene(path: String) -> void:
	# Desabilita botões durante a transição para evitar double-click.
	_set_buttons_interactable(false)

	# Aqui você pode chamar um Tween de fade-out antes de trocar.
	# Exemplo básico sem animação:
	get_tree().change_scene_to_file(path)


func _set_buttons_interactable(value: bool) -> void:
	for btn in [btn_new_game, btn_continue, btn_options, btn_credits, btn_quit]:
		btn.disabled = not value
