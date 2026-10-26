class_name Citizen
extends RefCounted

## Niveaux de diplôme d'un habitant (0 à 3 selon le CDC)
enum EducationLevel {
	NONE = 0,     
	BREVET = 1,    
	BAC = 2,      
	SUPERIEUR = 3  
}

## Statut d'activité actuel de l'habitant
enum Status {
	SEEKING, 
	STUDYING,
	WORKING   
}

var education_level: EducationLevel = EducationLevel.NONE
var status: Status = Status.SEEKING

## Référence vers le bâtiment fréquenté (école si STUDYING, entreprise si WORKING)
var assigned_building: Building = null

## Jours d'études restants avant l'obtention du diplôme visé
var study_days_remaining: int = 0

func _init(
	initial_level: EducationLevel = EducationLevel.NONE,
	initial_status: Status = Status.SEEKING
) -> void:
	education_level = initial_level
	status = initial_status

## Indique si l'habitant possède au moins un diplôme (niveau >= 1)
func is_graduated() -> bool:
	return education_level > EducationLevel.NONE

## Inscrit l'habitant dans une école pour une durée donnée (en jours)
func start_studying(school: Building, duration_days: int) -> void:
	status = Status.STUDYING
	assigned_building = school
	study_days_remaining = maxi(duration_days, 1)

## Valide le diplôme supérieur à la fin de la formation et remet l'habitant en recherche
func graduate() -> void:
	if education_level < EducationLevel.SUPERIEUR:
		education_level = (education_level + 1) as EducationLevel
	leave_activity()

## Affecte l'habitant à un poste de travail dans un bâtiment
func assign_job(workplace: Building) -> void:
	status = Status.WORKING
	assigned_building = workplace
	study_days_remaining = 0

## Libère l'habitant de son école ou de son travail (retour au statut SEEKING)
func leave_activity() -> void:
	status = Status.SEEKING
	assigned_building = null
	study_days_remaining = 0
