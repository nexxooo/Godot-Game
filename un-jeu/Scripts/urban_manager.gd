class_name UrbanManager
extends Node

enum Tier {
	SMALL_HOUSE = 1,
	HOUSE = 2,
	BUILDING = 3
}

const ORTHO_DIRS: Array[Vector2i] = [
	Vector2i.UP,
	Vector2i.DOWN,
	Vector2i.LEFT,
	Vector2i.RIGHT
]

@export_group("Références")
@export var sol: TileMapLayer
@export var decoration: TileMapLayer
@export var maisons: TileMapLayer
@export var buildings_container: Node2D
@export var population_manager: PopulationManager

@export_group("Tuiles (Maisons TileSet)")
@export var tile_source_id: int = 2
@export var small_house_atlas: Vector2i = Vector2i(9, 0)
@export var house_atlas: Vector2i = Vector2i(9, 1)
@export var building_atlas: Vector2i = Vector2i(9, 2)

@export_group("Rythme Visuel")
## Tous les X habitants, la ville ajoute ou améliore un bâtiment décoratif
@export_range(1, 50) var citizens_per_step: int = 4
## Seuil de petites maisons au-delà duquel elles s'améliorent en maisons depuis le centre
@export_range(1, 50) var max_small_houses: int = 6
## Seuil de maisons au-delà duquel elles s'améliorent en buildings depuis le centre
@export_range(1, 50) var max_houses: int = 5

## Dictionnaire des cases occupées : Vector2i -> Tier
var house_tiers: Dictionary = {}
var city_center: Vector2i = Vector2i.ZERO
var _steps_done: int = 0

func _ready() -> void:
	_init_starting_houses()
	if population_manager:
		population_manager.population_changed.connect(_on_population_changed)
		_on_population_changed(population_manager.get_total_population())

func _init_starting_houses() -> void:
	if not maisons:
		return
	var initial_cells: Array[Vector2i] = maisons.get_used_cells()
	if initial_cells.is_empty():
		return
	
	city_center = initial_cells[0]
	for cell: Vector2i in initial_cells:
		_set_tier(cell, Tier.SMALL_HOUSE)
		_steps_done += 1

func _on_population_changed(total_population: int) -> void:
	var target_steps: int = total_population / citizens_per_step
	while _steps_done < target_steps:
		if not _advance_visual_city():
			break
		_steps_done += 1

func _advance_visual_city() -> bool:
	if _count_tier(Tier.HOUSE) >= max_houses:
		if _upgrade_from_center(Tier.HOUSE, Tier.BUILDING):
			return true
	
	if _count_tier(Tier.SMALL_HOUSE) >= max_small_houses:
		if _upgrade_from_center(Tier.SMALL_HOUSE, Tier.HOUSE):
			return true
	
	if _spawn_small_house():
		return true
	
	# S'il n'y a plus de place libre autour, on densifie ce qui reste
	return (
		_upgrade_from_center(Tier.SMALL_HOUSE, Tier.HOUSE)
		or _upgrade_from_center(Tier.HOUSE, Tier.BUILDING)
	)

func _upgrade_from_center(from_tier: Tier, to_tier: Tier) -> bool:
	var best_cell: Vector2i = Vector2i.ZERO
	var best_dist: float = INF
	var found: bool = false
	
	for cell: Vector2i in house_tiers.keys():
		if house_tiers[cell] != from_tier:
			continue
		var dist: float = Vector2(cell - city_center).length_squared()
		if dist < best_dist:
			best_dist = dist
			best_cell = cell
			found = true
	
	if not found:
		return false
	
	_set_tier(best_cell, to_tier)
	return true

func _spawn_small_house() -> bool:
	var blocked_by_player: Dictionary = _get_player_cells()
	var candidates: Dictionary = {}
	
	# Cherche autour des habitations existantes (distance 1, ou distance 2 pour traverser une rue)
	for house_cell: Vector2i in house_tiers.keys():
		for dx: int in range(-2, 3):
			for dy: int in range(-2, 3):
				var check: Vector2i = house_cell + Vector2i(dx, dy)
				var cheb: int = maxi(absi(dx), absi(dy))
				if cheb == 0 or candidates.has(check) or not _is_buildable(check, blocked_by_player):
					continue
				if cheb == 1 or (cheb == 2 and _touches_road(check)):
					candidates[check] = true
	
	# Élargit le rayon si le pâté de maisons est saturé
	var radius: int = 3
	while candidates.is_empty() and radius <= 8:
		for house_cell: Vector2i in house_tiers.keys():
			for dx: int in range(-radius, radius + 1):
				for dy: int in range(-radius, radius + 1):
					var check: Vector2i = house_cell + Vector2i(dx, dy)
					if maxi(absi(dx), absi(dy)) == radius and _is_buildable(check, blocked_by_player):
						candidates[check] = true
		radius += 1
	
	if candidates.is_empty():
		return false
	
	var best_cell: Vector2i = Vector2i.ZERO
	var best_score: float = -INF
	for cell: Vector2i in candidates.keys():
		var score: float = _score_cell(cell)
		if score > best_score:
			best_score = score
			best_cell = cell
	
	if house_tiers.is_empty():
		city_center = best_cell
	_set_tier(best_cell, Tier.SMALL_HOUSE)
	return true

func _score_cell(cell: Vector2i) -> float:
	var score: float = randf_range(0.0, 1.5)
	if _touches_road(cell):
		score += 10.0
	for dir: Vector2i in ORTHO_DIRS:
		if house_tiers.has(cell + dir):
			score += 3.0
	score -= Vector2(cell - city_center).length() * 0.8
	return score

func _is_buildable(cell: Vector2i, blocked_by_player: Dictionary) -> bool:
	if not sol or sol.get_cell_source_id(cell) == -1:
		return false
	var td: TileData = sol.get_cell_tile_data(cell)
	if td == null or bool(td.get_custom_data("interdit")):
		return false
	if decoration and decoration.get_cell_source_id(cell) != -1:
		return false
	if house_tiers.has(cell) or blocked_by_player.has(cell):
		return false
	return true

func _touches_road(cell: Vector2i) -> bool:
	if not decoration:
		return false
	for dir: Vector2i in ORTHO_DIRS:
		var neighbor: Vector2i = cell + dir
		if decoration.get_cell_source_id(neighbor) == -1:
			continue
		var atlas: Vector2i = decoration.get_cell_atlas_coords(neighbor)
		if (atlas.x <= 3 and atlas.y >= 6 and atlas.y <= 9) or atlas == Vector2i(4, 7) or atlas == Vector2i(4, 9):
			return true
	return false

func _get_player_cells() -> Dictionary:
	var cells: Dictionary = {}
	if not buildings_container:
		return cells
	for child: Node in buildings_container.get_children():
		var bld: Building = child as Building
		if bld and is_instance_valid(bld):
			for c: Vector2i in bld.occupied_cells:
				cells[c] = true
	return cells

func _set_tier(cell: Vector2i, tier: Tier) -> void:
	house_tiers[cell] = tier
	var atlas: Vector2i = small_house_atlas
	if tier == Tier.HOUSE:
		atlas = house_atlas
	elif tier == Tier.BUILDING:
		atlas = building_atlas
	maisons.set_cell(cell, tile_source_id, atlas)

func _count_tier(tier: Tier) -> int:
	var count: int = 0
	for cell: Vector2i in house_tiers.keys():
		if house_tiers[cell] == tier:
			count += 1
	return count
