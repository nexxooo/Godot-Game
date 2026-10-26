class_name GameTimer
extends Timer

## Signal émis à chaque seconde (1 jour en jeu) avec la date formatée (AAAA/MM/JJ)
signal second_tick(formatted_time: String)
## Signal émis à chaque nouveau jour avec le détail de la date
signal day_passed(year: int, month: int, day: int)

const DAYS_IN_MONTH: Array[int] = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]

@export var start_year: int = 1900
@export_range(1, 12) var start_month: int = 1
@export_range(1, 31) var start_day: int = 1

var game_seconds: int = 0
var year: int = 1900
var month: int = 1
var day: int = 1

func _ready() -> void:
	year = start_year
	month = start_month
	day = clampi(start_day, 1, _get_days_in_month(year, month))
	
	wait_time = 1.0
	autostart = true
	
	if not timeout.is_connected(_on_timeout):
		timeout.connect(_on_timeout)

func _on_timeout() -> void:
	game_seconds += 1
	_advance_one_day()
	
	var formatted_date: String = get_formatted_date()
	second_tick.emit(formatted_date)
	day_passed.emit(year, month, day)

## Retourne la date courante au format AAAA/MM/JJ
func get_formatted_date() -> String:
	return "%04d/%02d/%02d" % [year, month, day]

func _advance_one_day() -> void:
	day += 1
	if day > _get_days_in_month(year, month):
		day = 1
		month += 1
		if month > 12:
			month = 1
			year += 1

func _get_days_in_month(y: int, m: int) -> int:
	if m == 2 and _is_leap_year(y):
		return 29
	return DAYS_IN_MONTH[m - 1]

func _is_leap_year(y: int) -> bool:
	return (y % 4 == 0 and y % 100 != 0) or (y % 400 == 0)
