class_name PopulationManager
extends Node

## Émis dès que l'effectif ou la répartition de la population évolue
signal population_changed(total_population: int)
## Émis lorsqu'un nouvel habitant rejoint la ville
signal citizen_added(citizen: Citizen)

@export_group("Références")
@export var world_timer: GameTimer

@export_group("Croissance Linéaire (Palier 1)")
## Nombre d'habitants présents dès le lancement (en 1900/01/01, dans la 1ère maison)
@export var initial_population: int = 4
## Nombre de jours (secondes) entre chaque arrivée d'habitants
@export_range(1, 365) var days_per_growth: int = 3
## Nombre d'habitants ajoutés à chaque arrivée
@export_range(1, 100) var citizens_per_growth: int = 1

## Liste complète des habitants de la ville
var citizens: Array[Citizen] = []
var _days_since_last_growth: int = 0

func _ready() -> void:
	if initial_population > 0:
		add_citizens(initial_population)
	else:
		population_changed.emit(0)
	
	if not world_timer and get_parent():
		world_timer = get_parent().get_node_or_null("WorldTimer") as GameTimer
	
	if world_timer and not world_timer.day_passed.is_connected(_on_day_passed):
		world_timer.day_passed.connect(_on_day_passed)

func _on_day_passed(_year: int, _month: int, _day: int) -> void:
	_days_since_last_growth += 1
	if _days_since_last_growth >= days_per_growth:
		_days_since_last_growth = 0
		add_citizens(citizens_per_growth)

## Ajoute un habitant unique et notifie les observateurs
func add_citizen(
	level: Citizen.EducationLevel = Citizen.EducationLevel.NONE,
	initial_status: Citizen.Status = Citizen.Status.SEEKING
) -> Citizen:
	var citizen: Citizen = Citizen.new(level, initial_status)
	citizens.append(citizen)
	citizen_added.emit(citizen)
	population_changed.emit(citizens.size())
	return citizen

## Ajoute plusieurs habitants d'un coup (un seul signal population_changed émis à la fin)
func add_citizens(
	amount: int,
	level: Citizen.EducationLevel = Citizen.EducationLevel.NONE,
	initial_status: Citizen.Status = Citizen.Status.SEEKING
) -> void:
	if amount <= 0:
		return
	for i: int in range(amount):
		var citizen: Citizen = Citizen.new(level, initial_status)
		citizens.append(citizen)
		citizen_added.emit(citizen)
	population_changed.emit(citizens.size())

## Retourne la population totale actuelle
func get_total_population() -> int:
	return citizens.size()

## Compte le nombre d'habitants ayant un statut donné (SEEKING, STUDYING, WORKING)
func get_count_by_status(target_status: Citizen.Status) -> int:
	var count: int = 0
	for citizen: Citizen in citizens:
		if citizen.status == target_status:
			count += 1
	return count

## Compte le nombre d'habitants ayant un niveau de diplôme donné (0 à 3)
func get_count_by_education(level: Citizen.EducationLevel) -> int:
	var count: int = 0
	for citizen: Citizen in citizens:
		if citizen.education_level == level:
			count += 1
	return count

## Récupère les habitants en recherche (SEEKING) d'un niveau de diplôme précis
func get_seeking_citizens(level: Citizen.EducationLevel) -> Array[Citizen]:
	var result: Array[Citizen] = []
	for citizen: Citizen in citizens:
		if citizen.status == Citizen.Status.SEEKING and citizen.education_level == level:
			result.append(citizen)
	return result
