extends Node

## Caminho do arquivo de save principal.
const SAVE_PATH := "user://savegame.sav"

## Emitido sempre que um save é criado ou deletado.
signal save_state_changed(exists: bool)


# ─── Verificação ────────────────────────────────────────────────────────────

## Retorna true se um arquivo de save existir no disco.
func has_save_file() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


# ─── Escrita (Mockup) ────────────────────────────────────────────────────────

## Salva um dicionário de dados no disco.
func save_game(data: Dictionary) -> Error:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: Falha ao abrir arquivo para escrita. Erro: %s" \
				% error_string(FileAccess.get_open_error()))
		return FileAccess.get_open_error()

	file.store_var(data)
	file.close()
	save_state_changed.emit(true)
	return OK


# ─── Leitura ─────────────────────────────────────────────────────────────────

## Carrega e retorna os dados do save. Retorna {} se não existir.
func load_game() -> Dictionary:
	if not has_save_file():
		push_warning("SaveManager: Tentativa de load sem arquivo de save.")
		return {}

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_error("SaveManager: Falha ao abrir arquivo para leitura.")
		return {}

	var data: Variant = file.get_var()
	file.close()

	if data is Dictionary:
		return data

	push_error("SaveManager: Dados corrompidos ou formato inválido.")
	return {}


# ─── Deleção ─────────────────────────────────────────────────────────────────

## Deleta o arquivo de save do disco (útil para "Novo Jogo" com confirmação).
func delete_save() -> void:
	if has_save_file():
		DirAccess.remove_absolute(SAVE_PATH)
		save_state_changed.emit(false)
