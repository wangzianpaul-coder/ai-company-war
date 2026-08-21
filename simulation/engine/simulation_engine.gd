class_name SimulationEngine
extends RefCounted


const GameStateType = preload("res://simulation/state/game_state.gd")
const ProjectSystemType = preload("res://simulation/systems/project_system.gd")
const FinanceSystemType = preload("res://simulation/systems/finance_system.gd")
const EffectContributionType = preload("res://simulation/events/effect_contribution.gd")
const EffectBatchResultType = preload("res://simulation/events/effect_batch_result.gd")
const TickResultType = preload("res://simulation/engine/tick_result.gd")


## Starts the project on an independent working copy.
func start_project(input_state: GameStateType) -> TickResultType:
	if input_state == null:
		return _failed_result()
	var working_state: GameStateType = input_state.copy()
	if working_state == null:
		return _failed_result()

	var project_result: EffectBatchResultType = ProjectSystemType.new().start_project(
		working_state.get_project()
	)
	if not project_result.is_successful():
		return _failed_result()
	return TickResultType.new(working_state, project_result.get_contributions())


## Runs exactly three Project, Finance, Clock months on an independent working copy.
func advance_quarter(input_state: GameStateType) -> TickResultType:
	if input_state == null:
		return _failed_result()
	var working_state: GameStateType = input_state.copy()
	if working_state == null:
		return _failed_result()

	var project_system: ProjectSystemType = ProjectSystemType.new()
	var finance_system: FinanceSystemType = FinanceSystemType.new()
	var contributions: Array[EffectContributionType] = []
	for _month_index in 3:
		var project_result: EffectBatchResultType = project_system.advance_month(
			working_state.get_company(),
			working_state.get_project()
		)
		if not project_result.is_successful():
			return _failed_result()
		_append_contributions(contributions, project_result.get_contributions())

		var finance_result: EffectBatchResultType = finance_system.settle_month(
			working_state.get_company()
		)
		if not finance_result.is_successful():
			return _failed_result()
		_append_contributions(contributions, finance_result.get_contributions())

		if not working_state.get_clock().advance_month():
			return _failed_result()

	return TickResultType.new(working_state, contributions)


func _failed_result() -> TickResultType:
	var no_contributions: Array[EffectContributionType] = []
	return TickResultType.new(null, no_contributions)


func _append_contributions(
	target: Array[EffectContributionType],
	source: Array[EffectContributionType]
) -> void:
	for contribution in source:
		target.append(contribution)
