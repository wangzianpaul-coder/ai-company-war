extends Control


const CompanyStateType = preload("res://simulation/state/company_state.gd")
const ProjectStateType = preload("res://simulation/state/project_state.gd")
const ComputeStateType = preload("res://simulation/state/compute_state.gd")
const GameStateType = preload("res://simulation/state/game_state.gd")
const GameSessionType = preload("res://application/game_session.gd")
const DashboardType = preload("res://ui/screens/dashboard.gd")

const DEMO_PROJECT_ID: StringName = &"project_alpha"
const DEMO_CASH_CENTS: int = 1_000_000
const DEMO_MONTHLY_REVENUE_CENTS: int = 120_000
const DEMO_MONTHLY_OPERATING_COST_CENTS: int = 80_000
const DEMO_PROJECT_REQUIRED_MONTHS: int = 3
const DEMO_PROJECT_MONTHLY_COST_CENTS: int = 25_000
const DEMO_COMPLETION_MONTHLY_REVENUE_DELTA_CENTS: int = 30_000
const DEMO_TOTAL_COMPUTE_UNITS_PER_MONTH: int = 100
const DEMO_RESERVE_COMPUTE_UNITS_PER_MONTH: int = 10
const DEMO_INFERENCE_WORKLOAD_UNITS_PER_MONTH: int = 50
const DEMO_TRAINING_ALLOCATION_UNITS_PER_MONTH: int = 40

@onready var dashboard: DashboardType = $DashboardMargin/Dashboard as DashboardType

var _game_session: GameSessionType


func _ready() -> void:
	var demo_company: CompanyStateType = CompanyStateType.new(
		DEMO_CASH_CENTS,
		DEMO_MONTHLY_REVENUE_CENTS,
		DEMO_MONTHLY_OPERATING_COST_CENTS
	)
	var demo_project: ProjectStateType = ProjectStateType.new(
		DEMO_PROJECT_ID,
		DEMO_PROJECT_REQUIRED_MONTHS,
		DEMO_PROJECT_MONTHLY_COST_CENTS,
		DEMO_COMPLETION_MONTHLY_REVENUE_DELTA_CENTS
	)
	var demo_compute: ComputeStateType = ComputeStateType.new(
		DEMO_TOTAL_COMPUTE_UNITS_PER_MONTH,
		DEMO_RESERVE_COMPUTE_UNITS_PER_MONTH,
		DEMO_INFERENCE_WORKLOAD_UNITS_PER_MONTH,
		DEMO_TRAINING_ALLOCATION_UNITS_PER_MONTH
	)
	var demo_state: GameStateType = GameStateType.new(
		demo_company,
		demo_project,
		demo_compute
	)
	_game_session = GameSessionType.new(demo_state)
	dashboard.initialize(_game_session)
