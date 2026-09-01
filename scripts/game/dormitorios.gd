extends Node2D

const FLAG_DIALOGO_INICIAL := "dormitorio_intro_visto"

@onready var player : MC = $Player
@onready var painel_dialogo : PanelContainer = $CanvasLayer/Panel
@onready var label_texto : RichTextLabel = $CanvasLayer/Panel/RichTextLabel
@onready var label_instrucao : Label = $"CanvasLayer/Instrucao_movimentacao"
@onready var porta : PortaTransicao = $"PortaPatio"
@onready var doidinho : Companheiro = $"Doidinho"

var companheiro : Companheiro = null

var _dialogo_ativo : bool = false
var _indice_fala   : int  = 0

var _falas : Array[Dictionary] = [
	{ "quem": "", "texto": "Um estalo seco corta o silêncio do dormitório." },
	{ "quem": "", "texto": "As lâmpadas piscam. O zumbido do gerador falha, engasga e morre por alguns segundos." },
	{ "quem": "Protagonista", "texto": "Que barulho foi esse?" },
	{ "quem": "", "texto": "Do corredor vêm passos, portas batendo e vozes tentando sair antes que alguém apareça." },
	{ "quem": "", "texto": "No canto do quarto, um paciente se levanta como se já esperasse por aquilo." },
	{ "quem": "?", "texto": "Acordou também? Melhor assim." },
	{ "quem": "Protagonista", "texto": "Quem é você?" },
	{ "quem": "?", "texto": "Hoje? Depende de quem pergunta." },
	{ "quem": "?", "texto": "Pra eles, eu sou o ?. Pra você, posso ser a chance de sair daqui." },
	{ "quem": "Protagonista", "texto": "O que está acontecendo?" },
	{ "quem": "?", "texto": "A luz caiu. Quando a luz cai, as portas ficam menos obedientes." },
	{ "quem": "?", "texto": "Mas não fica parado. Daqui a pouco eles vêm contar quem ainda tá respirando nesse corredor." },
	{ "quem": "?", "texto": "Escuta... não é só a gente tentando sair." },
	{ "quem": "", "texto": "O barulho aumenta do lado de fora. Alguém força uma porta. Outra pessoa corre pelo corredor." },
	{ "quem": "?", "texto": "A cozinha fica depois do pátio. Lá tem coisa útil." },
	{ "quem": "?", "texto": "Vem comigo. Sem gritar. Sem correr à toa." },
	{ "quem": "?", "texto": "Vamos ali na cozinha." },
]


func _ready() -> void:
	player.companheiro_sacrificado.connect(_ao_sacrificio_concluido)

	# Registra o Doidinho como o companheiro do jogador e o coloca pra seguir.
	# É essa referência (player.companheiro) que o Game usa pra levar o
	# Doidinho junto quando o jogador atravessa uma porta de transição.
	companheiro = doidinho
	player.companheiro = doidinho
	doidinho.ativar(player)

	var tecla_interagir: String = _obter_nome_da_tecla("interact")
	label_instrucao.text = "Aperte " + tecla_interagir + " para ir para a próxima fala"
	
	# A porta precisa começar TRANCADA enquanto o diálogo inicial não foi
	# visto — mas o valor "estado" gravado na cena (dormitorios.tscn) estava
	# como DESBLOQUEADA por engano, deixando o player sair andando pro pátio
	# no meio da conversa. Forçamos aqui pra garantir o comportamento certo
	# independente do que estiver salvo no .tscn.
	if SaveManager.obter_flag(FLAG_DIALOGO_INICIAL):
		painel_dialogo.hide()
		label_instrucao.hide()
		porta.destrancar()
	else:
		porta.trancar()
		_iniciar_dialogo()

# Função auxiliar para encapsular a busca da tecla
func _obter_nome_da_tecla(acao: String) -> String:
	var eventos = InputMap.action_get_events(acao)
	
	if eventos.size() > 0:
		var primeiro_evento = eventos[0]
		if primeiro_evento is InputEventKey:
			return OS.get_keycode_string(primeiro_evento.physical_keycode)
		elif primeiro_evento is InputEventJoypadButton:
			return "Botão " + str(primeiro_evento.button_index)
			
	return "[Tecla não configurada]"
	
func _iniciar_dialogo() -> void:
	_dialogo_ativo = true
	_indice_fala = 0
	painel_dialogo.show()
	_mostrar_fala_atual()


func _mostrar_fala_atual() -> void:
	var fala := _falas[_indice_fala]
	var quem : String = fala["quem"]
	var texto : String = fala["texto"]

	if quem.is_empty():
		label_texto.text = "[i]%s[/i]" % texto
	else:
		label_texto.text = "[b]%s:[/b] %s" % [quem, texto]


func _unhandled_input(event: InputEvent) -> void:
	if not _dialogo_ativo:
		return
		
	if event.is_action_pressed("interact"):
		_avancar_dialogo()

func _avancar_dialogo() -> void:
	_indice_fala += 1
	if _indice_fala >= _falas.size():
		_fechar_dialogo()
		# A porta nasce TRANCADA (ver PortaTransicao._ready), então ela já
		# fica bloqueada durante todo o diálogo. Ao concluir, destrancamos.
		porta.destrancar()
	else:
		_mostrar_fala_atual()


func _fechar_dialogo() -> void:
	_dialogo_ativo = false
	painel_dialogo.hide()
	label_instrucao.hide()
	SaveManager.definir_flag(FLAG_DIALOGO_INICIAL)


func _ao_sacrificio_concluido() -> void:
	companheiro = null
	player.companheiro = null
