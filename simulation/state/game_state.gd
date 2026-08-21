class_name GameState
extends RefCounted


const SimulationClockType = preload("res://simulation/engine/simulation_clock.gd")
const CompanyStateType = preload("res://simulation/state/company_state.gd")
const ProjectStateType = preload("res://simulation/state/project_state.gd")

var _clock: SimulationClockType
var _company: CompanyStateType
var _project: ProjectStateType


## Owns independent typed state. Optional inputs are copied, never shared.
func _init(
	p_company: CompanyStateType = null,
	p_project: ProjectStateType = null
) -> void:
	_clock = SimulationClockType.new()
	if p_company == null:
		_company = CompanyStateType.new()
	else:
		_company = CompanyStateType.new(
			p_company.get_cash_cents(),
			p_company.get_monthly_revenue_cents(),
			p_company.get_monthly_operating_cost_cents()
		)
	if p_project == null:
		_project = ProjectStateType.new()
	else:
		_project = ProjectStateType.new(
			p_project.get_project_id(),
			p_project.get_required_months(),
			p_project.get_monthly_cost_cents(),
			p_project.get_completion_monthly_revenue_delta_cents(),
			p_project.get_lifecycle(),
			p_project.get_progress_months()
		)


## Returns the typed clock owned by this runtime state.
func get_clock() -> SimulationClockType:
	return _clock


## Returns the typed company state owned by this runtime state.
func get_company() -> CompanyStateType:
	return _company


## Returns the single typed project slot owned by this runtime state.
func get_project() -> ProjectStateType:
	return _project
