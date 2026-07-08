extends Companheiro
class_name Doidinho

const RAIO_PEDRA    : float = 250.0
const IMPULSO_PEDRA : float = 800.0


func _ready() -> void:
	super._ready()
	id_npc = "doidinho"
	SKILLS_VALIDAS = ["arremesso", "lockpicking", "distracao", "atirar_pedra"]


# ─── Override sacrifício — sem delay dramático ────────────────────────────────

func sacrificar() -> bool:
	if estado == Estado.MORTO or estado == Estado.ISCA:
		return false
	estado = Estado.MORTO
	set_physics_process(false)
	velocity = Vector2.ZERO
	get_tree().call_group("inimigos", "ouvir_barulho", global_position, 9999.0)
	if animacao and animacao.sprite_frames.has_animation("sacrifice"):
		animacao.play("sacrifice")
	sacrificado.emit()
	queue_free()
	return true


# ─── Skill: atirar pedra ──────────────────────────────────────────────────────

func atirar_pedra(alvo_pos: Vector2 = Vector2.ZERO) -> bool:
	if estado == Estado.MORTO or estado == Estado.ISCA:
		return false
	if not NPCManager.consumir_pedra():
		push_warning("Doidinho: sem pedras disponíveis.")
		return false
	var destino := alvo_pos if alvo_pos != Vector2.ZERO \
		else global_position + Vector2(randf_range(-200, 200), randf_range(-200, 200))
	get_tree().call_group("inimigos", "ouvir_barulho", destino, RAIO_PEDRA)
	if animacao and animacao.sprite_frames.has_animation("throw"):
		animacao.play("throw")
	skill_executada.emit("atirar_pedra")
	return true


# ─── Override executando skill para interceptar atirar_pedra ─────────────────

func _estado_executando_skill() -> void:
	if _skill_concluida:
		_mudar_estado(Estado.SEGUINDO)
		return
	if _skill_ativa == "atirar_pedra":
		var pos := (_skill_alvo as Node2D).global_position if _skill_alvo is Node2D else Vector2.ZERO
		atirar_pedra(pos)
		_skill_concluida = true
	else:
		super._estado_executando_skill()
