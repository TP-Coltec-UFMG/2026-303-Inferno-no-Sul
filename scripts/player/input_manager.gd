extends Node

## ════════════════════════════════════════════════════════════════════════════
##  InputManager — helper de remap de teclas de movimento/ação.
##
##  Fonte única de persistência: SettingsManager (save_remap / load_remaps).
##  Este nó apenas expõe uma API curta para a UI e o jogo:
##
##    InputManager.mudar_tecla("move_left", KEY_A)   → grava + aplica + salva
##    InputManager.tecla_da_acao("move_left")        → physical_keycode atual
##    InputManager.resetar("move_left")              → volta ao padrão do projeto
##
##  As ações em si vivem no InputMap (definidas em project.godot [input]).
## ════════════════════════════════════════════════════════════════════════════

## Ações remapeáveis. Mantém em sincronia com options_menu.REMAPPABLE_ACTIONS.
const ACOES: Array[String] = [
	"move_left", "move_right", "move_up", "move_down",
	"jump", "attack", "interact", "pause",
	"correr", "agachar",
]


## Troca a tecla de uma ação por um InputEventKey (physical_keycode),
## aplica ao InputMap e persiste via SettingsManager.
func mudar_tecla(acao: String, nova_tecla: Key) -> void:
	if not InputMap.has_action(acao):
		push_warning("InputManager: ação '%s' não existe no InputMap." % acao)
		return

	var evento := InputEventKey.new()
	evento.physical_keycode = nova_tecla

	definir_evento(acao, evento)


## Aplica um InputEvent qualquer (tecla, botão de joypad, mouse) a uma ação,
## substituindo os anteriores, e persiste.
func definir_evento(acao: String, evento: InputEvent) -> void:
	if not InputMap.has_action(acao):
		push_warning("InputManager: ação '%s' não existe no InputMap." % acao)
		return

	InputMap.action_erase_events(acao)
	InputMap.action_add_event(acao, evento)

	var eventos: Array[InputEvent] = []
	for ev in InputMap.action_get_events(acao):
		eventos.append(ev)

	SettingsManager.save_remap(acao, eventos)
	SettingsManager.save()


## Devolve o physical_keycode do primeiro InputEventKey da ação, ou KEY_NONE.
func tecla_da_acao(acao: String) -> Key:
	for ev in InputMap.action_get_events(acao):
		if ev is InputEventKey:
			return (ev as InputEventKey).physical_keycode
	return KEY_NONE


## Restaura o padrão definido em project.godot para a ação e remove o remap salvo.
func resetar(acao: String) -> void:
	SettingsManager.reset_remap(acao)
	SettingsManager.save()
