extends Node

func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)
	_connect_existing_buttons(get_tree().root)

func _on_node_added(node: Node) -> void:
	if node is BaseButton:
		_connect_button(node)

func _connect_existing_buttons(node: Node) -> void:
	if node is BaseButton:
		_connect_button(node)
	for child in node.get_children():
		_connect_existing_buttons(child)

func _connect_button(button: BaseButton) -> void:
	if not button.pressed.is_connected(button.release_focus):
		button.pressed.connect(button.release_focus)
