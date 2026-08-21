extends Control


@onready var date_label: Label = $DateLabel
@onready var start_button: Button = $StartButton

var year: int = 2026
var quarter: int = 1
var game_started: bool = false


func _ready() -> void:
	start_button.pressed.connect(_on_start_button_pressed)
	update_date()


func _on_start_button_pressed() -> void:
	if not game_started:
		game_started = true
		start_button.text = "NEXT QUARTER"
	else:
		advance_quarter()


func advance_quarter() -> void:
	quarter += 1

	if quarter > 4:
		quarter = 1
		year += 1

	update_date()


func update_date() -> void:
	date_label.text = "%d Q%d" % [year, quarter]
