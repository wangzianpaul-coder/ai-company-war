extends Control


const CompanyStateType = preload("res://simulation/state/company_state.gd")
const ProjectStateType = preload("res://simulation/state/project_state.gd")
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
	var demo_state: GameStateType = GameStateType.new(demo_company, demo_project)
	_game_session = GameSessionType.new(demo_state)
	dashboard.initialize(_game_session)
