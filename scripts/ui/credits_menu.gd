extends Control

@onready var btn_back: Button = %BtnBack

func _ready() -> void:
	btn_back.pressed.connect(_on_back_pressed)

func _on_back_pressed() -> void:
	queue_free() 
