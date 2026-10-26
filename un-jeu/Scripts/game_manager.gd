extends Node2D

## Références aux nœuds de la scène
@onready var sol: TileMapLayer = $Sol
@onready var decoration: TileMapLayer = $Decoration
@onready var buildings_container: Node2D = $Buildings
@onready var preview_sprite: Sprite2D = $PreviewSprite
@onready var batiment_1_btn: TextureButton = $CanvasLayer/BarreBatiment/HBoxContainer/Batiment1
@onready var delete_btn: TextureButton = $CanvasLayer/BarreBatiment/HBoxContainer/delete
@onready var farm_btn: TextureButton = $CanvasLayer/BarreBatiment/HBoxContainer/Batiment3
# Bouton pour afficher la route des innovations
@onready var zoomin_route_btn: TextureButton = $CanvasLayer/PanelScience/ContainerScience/ZoominRoute

## Ressources : argent, science et population
@onready var money: Label = $CanvasLayer/PanelArgent/HBoxContainer/BoxArgent/Argent
@onready var progress_bar_science: ProgressBar = $CanvasLayer/PanelScience/ContainerScience/BoxScience/ProgressBarScience
@onready var science: Label = $CanvasLayer/PanelScience/ContainerScience/BoxScience/ProgressBarScience/Science
@onready var panel_population: PanelContainer = $CanvasLayer/PanelPopulation
@onready var population_label: Label = $CanvasLayer/PanelPopulation/PopulationLabel
@onready var population_manager: PopulationManager = $PopulationManager

## Timer
# Label du timer qui affiche le temps à chaque fois
@onready var timer_live: Label = $CanvasLayer/PanneauTimer/TimerLive
# WorldTimer
@onready var world_timer: GameTimer = $WorldTimer

## Autres
# Route des innovations
@onready var popup = $InnovationsZoom

# Bouton pour afficher les stats supplémentaires
@onready var extra_stats_toggle_btn: TextureButton = $CanvasLayer/ExtraStatsToggle
@onready var panneau_gauche: PanelContainer = $CanvasLayer/PanneauGauche

## Scène de bâtiment par défaut
@export var building_scene: PackedScene = preload("res://Scenes/Building.tscn")
@export var farm_scene: PackedScene = preload("res://Scenes/farm.tscn")

## Fenêtre Quitter
@onready var fenetre_exit: ConfirmationDialog = $FenetreExit


## Textures
# Boutons pour les extra stats
var text_plus: Texture2D = preload("res://Assets/Boutons/plus.png")
var text_moins: Texture2D = preload("res://Assets/Boutons/moins.png")
var text_science: Texture2D = preload("res://Assets/Ressources/science.png")

## Coût de placement d'un bâtiment
var current_building_cost: int = 100

## Variables d'état du placement
var is_placing: bool = false
var current_scene_to_place: PackedScene = null
var current_footprint: Vector2i = Vector2i(1, 1)

## Variables d'état de la suppression
var is_deleting: bool = false
var current_hovered_building: Building = null

# Variables de score
var score_money: int = 0
var score_science: int = 0
# Nombre max de points de science pour atteindre la prochaine innovation
var max_science: int = 100;

## Registre des cases occupées : clé = Vector2i, valeur = Building
var occupied_cells: Dictionary = {}

func _ready() -> void:
	# Cache l'aperçu au démarrage
	preview_sprite.visible = false
	preview_sprite.z_index = 10
	
	# Connexion du bouton de bâtiment
	batiment_1_btn.pressed.connect(_on_batiment_1_pressed)

	delete_btn.pressed.connect(_on_delete_pressed)
	farm_btn.pressed.connect(_on_batiment_3_pressed)
	
	# Affichage du score d'argent possédé
	# TESTS
	show_money()
	
	show_science()
	
	# Prépare le bouton pour l'affichage de la fenêtre et cache cette dernière comme elle n'est pas encore appelée
	zoomin_route_btn.pressed.connect(_on_zoomin_route_pressed)
	popup.hide()
	
	# Affichage initial et connexion de la population
	population_manager.population_changed.connect(_on_population_changed)
	show_population()
	
	# Affichage de la date initiale (1900/01/01) et lancement du Timer
	timer_live.text = world_timer.get_formatted_date()
	world_timer.second_tick.connect(_on_timer_tick)

func _process(_delta: float) -> void:
	if is_placing:
		_process_placement()
	elif is_deleting:
		_process_deletion()
		
	# TESTS
	## DEBUG : Ajouter/Perdre des ressources
	a_add_money()
	z_lose_money()
	s_add_science()
	d_lose_science()

func _process_placement() -> void:
	# 1. Récupérer la position de la souris sur la grille
	var mouse_pos: Vector2 = sol.get_local_mouse_position()
	var cell: Vector2i = sol.local_to_map(mouse_pos)
	
	# 2. Centrer l'aperçu sur la zone occupée par le bâtiment (footprint)
	var bottom_right_cell = cell + current_footprint - Vector2i(1, 1)
	var center_pos = (sol.map_to_local(cell) + sol.map_to_local(bottom_right_cell)) / 2.0
	preview_sprite.position = center_pos
	
	# 3. Vérifier si l'emplacement est valide pour colorer l'aperçu
	if can_place(cell, current_footprint):
		preview_sprite.modulate = Color(0.3, 1.0, 0.3, 0.7) # Vert : constructible
	else:
		preview_sprite.modulate = Color(1.0, 0.25, 0.25, 0.7) # Rouge : impossible
		
	

func _process_deletion() -> void:
	var mouse_pos: Vector2 = sol.get_local_mouse_position()
	var cell: Vector2i = sol.local_to_map(mouse_pos)
	var building: Building = occupied_cells.get(cell, null)
	
	# Met en surbrillance rouge le bâtiment sous le curseur
	if building != current_hovered_building:
		if is_instance_valid(current_hovered_building):
			current_hovered_building.modulate = Color.WHITE
		current_hovered_building = building
		if is_instance_valid(current_hovered_building):
			current_hovered_building.modulate = Color(1.0, 0.35, 0.35, 0.8)

func _unhandled_input(event: InputEvent) -> void:
	if is_placing:
		# Clics de souris pour le placement
		if event is InputEventMouseButton and event.pressed:
			if event.button_index == MOUSE_BUTTON_LEFT:
				var mouse_pos: Vector2 = sol.get_local_mouse_position()
				var cell: Vector2i = sol.local_to_map(mouse_pos)
				if can_place(cell, current_footprint):
					place_building(cell, current_footprint)
			elif event.button_index == MOUSE_BUTTON_RIGHT:
				cancel_placement()
		
		# Touche Échap pour annuler
		elif event.is_action_pressed("ui_cancel"):
			cancel_placement()
			
	elif is_deleting:
		# Clics de souris pour la suppression
		if event is InputEventMouseButton and event.pressed:
			if event.button_index == MOUSE_BUTTON_LEFT:
				var mouse_pos: Vector2 = sol.get_local_mouse_position()
				var cell: Vector2i = sol.local_to_map(mouse_pos)
				delete_building_at(cell)
			elif event.button_index == MOUSE_BUTTON_RIGHT:
				cancel_deletion()
		
		# Touche Échap pour annuler
		elif event.is_action_pressed("ui_cancel"):
			cancel_deletion()

## Vérifie si toutes les cases requises sont sur le sol et non occupées
func can_place(top_left: Vector2i, footprint: Vector2i) -> bool:
	# Vérification de l'argent disponible : on ne peut pas placer le batiment si on n'a pas assez de sous :
	if score_money < current_building_cost:
		return false
	
	for x in range(footprint.x):
		for y in range(footprint.y):
			var check_cell = top_left + Vector2i(x, y)
			
			# 1. La case doit exister sur le sol (pas dans le vide)
			if sol.get_cell_source_id(check_cell) == -1:
				return false
			
			var tiledata = sol.get_cell_tile_data(check_cell)
			if tiledata == null or tiledata.get_custom_data("interdit"):
				return false
			
			if decoration and decoration.get_cell_source_id(check_cell) != -1:
				var tiledata_route = decoration.get_cell_tile_data(check_cell)
				if tiledata_route and tiledata_route.get_custom_data("interdit"):
					return false
			
			# 2. La case ne doit pas être déjà occupée par un bâtiment
			if occupied_cells.has(check_cell):
				return false
				
	return true

## Démarre le mode placement en copiant automatiquement le visuel et la taille de la scène
func start_placement(scene: PackedScene) -> void:
	cancel_deletion()
	current_scene_to_place = scene
	is_placing = true
	
	# Récupération automatique du sprite et du footprint depuis la scène du bâtiment
	var temp_bld = scene.instantiate() as Building
	if temp_bld:
		current_footprint = temp_bld.footprint
		current_building_cost = temp_bld.building_cost # Récupère le coût depuis le bâtiment
		var bld_sprite = temp_bld.get_node_or_null("Sprite2D")
		if bld_sprite:
			preview_sprite.texture = bld_sprite.texture
			preview_sprite.region_enabled = bld_sprite.region_enabled
			preview_sprite.region_rect = bld_sprite.region_rect
			preview_sprite.scale = bld_sprite.scale
		temp_bld.queue_free()
	
	preview_sprite.visible = true

## Pose définitivement le bâtiment dans le monde
func place_building(top_left: Vector2i, footprint: Vector2i) -> void:
	if not current_scene_to_place:
		return
		
	# Déduire l'argent et mettre à jour l'affichage
	lose_money(current_building_cost)
	show_money()
		
	var building: Building = current_scene_to_place.instantiate() as Building
	buildings_container.add_child(building)
	
	# Positionnement au centre des cases
	var bottom_right_cell = top_left + footprint - Vector2i(1, 1)
	var center_pos = (sol.map_to_local(top_left) + sol.map_to_local(bottom_right_cell)) / 2.0
	building.position = center_pos
	
	# Enregistrement des cases occupées
	var cells: Array[Vector2i] = []
	for x in range(footprint.x):
		for y in range(footprint.y):
			var c = top_left + Vector2i(x, y)
			occupied_cells[c] = building
			cells.append(c)
			
	building.setup(cells)
	
	# Si Shift n'est pas enfoncé, on quitte le mode placement
	if not Input.is_key_pressed(KEY_SHIFT):
		cancel_placement()

## Annule le mode placement
func cancel_placement() -> void:
	is_placing = false
	current_scene_to_place = null
	preview_sprite.visible = false

## Active le mode suppression
func start_deletion() -> void:
	cancel_placement()
	is_deleting = true
	delete_btn.modulate = Color(1.0, 0.4, 0.4) # Indication visuelle que le mode suppression est activé

## Désactive le mode suppression
func cancel_deletion() -> void:
	is_deleting = false
	delete_btn.modulate = Color.WHITE
	if is_instance_valid(current_hovered_building):
		current_hovered_building.modulate = Color.WHITE
	current_hovered_building = null

## Supprime le bâtiment présent à la case donnée
func delete_building_at(cell: Vector2i) -> void:
	if occupied_cells.has(cell):
		delete_building(occupied_cells[cell])

## Supprime un bâtiment du monde et libère ses cases
func delete_building(building: Building) -> void:
	if not is_instance_valid(building):
		return
		
	if current_hovered_building == building:
		current_hovered_building = null
		
	# Libération de toutes les cases occupées par le bâtiment
	for cell in building.occupied_cells:
		occupied_cells.erase(cell)
		
	# Sécurité supplémentaire au cas où des cases feraient encore référence à ce bâtiment
	for cell in occupied_cells.keys():
		if occupied_cells[cell] == building:
			occupied_cells.erase(cell)
			
	building.queue_free()

## Clic sur le bouton de la ferme dans l'interface
func _on_batiment_1_pressed() -> void:
	start_placement(building_scene)
	
func _on_batiment_3_pressed()->void:
	start_placement(farm_scene)
	
func _on_delete_pressed() -> void:
	if is_deleting:
		cancel_deletion()
	else:
		start_deletion()



### Gestion/Affichage de l'argent gagné

# Affichage du score
func show_money():
	money.text = str(score_money) + " €"
	
# Ajout d'une somme 'score' choisi par le jeu d'argent
func add_money(score):
	score_money += score
	
func lose_money(score):
	# Empêcher d'entrer en dette (pour l'instant)
	if score_money <= 0:
		score_money = 0
	else:
		score_money -= score

### Gestion/Affichage des points de science gagnés
func show_science():
	progress_bar_science.max_value = max_science
	progress_bar_science.value = score_science
	science.text = "%d / %d" % [score_science, max_science]
	
func add_science(score):
	score_science += score

func lose_science(score):
	# Empêcher d'entrer en dette (pour l'instant)
	if score_science <= 0:
		score_science = 0
	else:
		score_science -= score

### Gestion/Affichage de la population
func _on_population_changed(_total: int) -> void:
	show_population()

func show_population() -> void:
	var total: int = population_manager.get_total_population()
	population_label.text = "Habitants : %d" % total
	panel_population.tooltip_text = (
		"Cherchent : %d | Étudiants : %d | Travail : %d\n" % [
			population_manager.get_count_by_status(Citizen.Status.SEEKING),
			population_manager.get_count_by_status(Citizen.Status.STUDYING),
			population_manager.get_count_by_status(Citizen.Status.WORKING)
		] +
		"Niv 0 : %d | Niv 1 : %d | Niv 2 : %d | Niv 3 : %d" % [
			population_manager.get_count_by_education(Citizen.EducationLevel.NONE),
			population_manager.get_count_by_education(Citizen.EducationLevel.BREVET),
			population_manager.get_count_by_education(Citizen.EducationLevel.BAC),
			population_manager.get_count_by_education(Citizen.EducationLevel.SUPERIEUR)
		]
	)

## Gestion du WorldTimer

func _on_timer_tick(formatted_time: String) -> void:
	# 1. Met à jour l'affichage du timer reçu du script séparé
	timer_live.text = formatted_time

	# 2. Calcule la science en interrogeant chaque bâtiment unique
	var unique_buildings = []
	var science_gain = 0
	
	for cell in occupied_cells:
		var bld = occupied_cells[cell]
		if is_instance_valid(bld) and not unique_buildings.has(bld):
			unique_buildings.append(bld)
			science_gain += bld.science_production # Utilise la production propre du bâtiment

	if science_gain > 0:
		add_science(science_gain)
		show_science()


## Boutons d'affichage
# Fermeture de la fenêtre des routes des innovations quand on clique sur la croix
func _on_innovations_zoom_close_requested():
	popup.hide()
	zoomin_route_btn.texture_normal = text_science

# Afficher/Cacher la route des innovations en appuyant sur le bouton
func _on_zoomin_route_pressed() -> void:
	if popup.visible:
		popup.hide()
		zoomin_route_btn.texture_normal = text_science
	else:
		popup.show()
		zoomin_route_btn.texture_normal = text_moins

func _on_extra_stats_toggle_pressed() -> void:
	if panneau_gauche.visible:
		panneau_gauche.hide()
		extra_stats_toggle_btn.texture_normal = text_plus
	else:
		panneau_gauche.show()
		extra_stats_toggle_btn.texture_normal = text_moins

# Bouton Quitter
func _on_quitter_btn_pressed():
	# Ouvre la fenêtre de confirmation pour quitter le jeu
	fenetre_exit.popup_centered()
# Si on confirme...
func _on_fenetre_exit_confirmed():
	get_tree().quit()
	
## DEBUG TOOLS
# Augmente l'argent gagné de 1 en appuyant sur la touche espace et l'affiche
# TESTS
func a_add_money():
	if Input.is_key_pressed(KEY_A):
		add_money(200)
		show_money()
		
func z_lose_money():
	if Input.is_key_pressed(KEY_Z):
		lose_money(200)
		show_money()
		
func s_add_science():
	if Input.is_key_pressed(KEY_S):
		add_science(1)
		show_science()
		
func d_lose_science():
	if Input.is_key_pressed(KEY_D):
		lose_science(1)
		show_science()
