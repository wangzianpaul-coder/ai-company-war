class_name GameState
extends RefCounted


const SimulationClockType = preload("res://simulation/engine/simulation_clock.gd")
const CompanyStateType = preload("res://simulation/state/company_state.gd")
const ProjectStateType = preload("res://simulation/state/project_state.gd")
const ComputeStateType = preload("res://simulation/state/compute_state.gd")
const MarketStateType = preload("res://simulation/state/market_state.gd")
const OpponentStateType = preload("res://simulation/state/opponent_state.gd")
const NamedRngStateType = preload("res://simulation/rng/named_rng_state.gd")

var _clock: SimulationClockType
var _company: CompanyStateType
var _project: ProjectStateType
var _compute: ComputeStateType
var _market: MarketStateType
var _opponent: OpponentStateType
var _named_rng: NamedRngStateType


## Owns independent typed state. Optional inputs are copied, never shared.
func _init(
	p_company: CompanyStateType = null,
	p_project: ProjectStateType = null,
	p_compute: ComputeStateType = null,
	p_market: MarketStateType = null,
	p_opponent: OpponentStateType = null,
	p_named_rng: NamedRngStateType = null
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
	if p_compute == null:
		_compute = ComputeStateType.new()
	else:
		_compute = p_compute.copy()
	if p_market == null:
		_market = MarketStateType.new()
	else:
		_market = p_market.copy()
	if p_opponent == null:
		_opponent = OpponentStateType.new()
	else:
		_opponent = p_opponent.copy()
	if p_named_rng == null:
		_named_rng = NamedRngStateType.new()
	else:
		_named_rng = NamedRngStateType.new(
			p_named_rng.get_master_seed(),
			p_named_rng.get_algorithm_version(),
			p_named_rng.get_ai_stream_state(),
			p_named_rng.get_events_stream_state(),
			p_named_rng.get_market_stream_state()
		)


## Returns a fully independent copy preserving the complete owned state graph.
func copy() -> GameState:
	var copied_state: GameState = GameState.new(
		_company,
		_project,
		_compute,
		_market,
		_opponent,
		_named_rng
	)
	var clock_copied: bool = copied_state.get_clock().advance_months(
		_clock.get_elapsed_months()
	)
	if not clock_copied:
		return null
	return copied_state


## Returns the typed clock owned by this runtime state.
func get_clock() -> SimulationClockType:
	return _clock


## Returns the typed company state owned by this runtime state.
func get_company() -> CompanyStateType:
	return _company


## Returns the single typed project slot owned by this runtime state.
func get_project() -> ProjectStateType:
	return _project


## Returns the typed shared monthly capacity state owned by this runtime state.
func get_compute() -> ComputeStateType:
	return _compute


## Returns the two fixed markets owned by this runtime state.
func get_market() -> MarketStateType:
	return _market


## Returns the independently owned opponent state.
func get_opponent() -> OpponentStateType:
	return _opponent


## Returns the independently owned named stream state.
func get_named_rng() -> NamedRngStateType:
	return _named_rng


## Replaces only this isolated state's named streams with a complete valid copy.
func _commit_named_rng(p_named_rng: NamedRngStateType) -> bool:
	if p_named_rng == null:
		return false
	var copied_rng: NamedRngStateType = p_named_rng.copy()
	if copied_rng == null:
		return false
	_named_rng = copied_rng
	return true
