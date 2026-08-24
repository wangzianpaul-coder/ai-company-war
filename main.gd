extends Control


const CompanyStateType = preload("res://simulation/state/company_state.gd")
const ProjectStateType = preload("res://simulation/state/project_state.gd")
const ComputeStateType = preload("res://simulation/state/compute_state.gd")
const MarketStateType = preload("res://simulation/state/market_state.gd")
const OpponentStateType = preload("res://simulation/state/opponent_state.gd")
const OpponentPersonalityType = preload("res://simulation/ai/opponent_personality.gd")
const NamedRngStateType = preload("res://simulation/rng/named_rng_state.gd")
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
const DEMO_CONSUMER_WORKLOAD_UNITS_PER_MONTH: int = 30
const DEMO_DEVELOPER_API_WORKLOAD_UNITS_PER_MONTH: int = 20
const DEMO_CONSUMER_SERVICE_ALLOCATION_BPS: int = 6_000
const DEMO_CONSUMER_PLAYER_SHARE_BPS: int = 3_000
const DEMO_DEVELOPER_API_PLAYER_SHARE_BPS: int = 2_000
const DEMO_CONSUMER_ADDRESSABLE_MONTHLY_REVENUE_CENTS: int = 100_000
const DEMO_DEVELOPER_API_ADDRESSABLE_MONTHLY_REVENUE_CENTS: int = 450_000
const DEMO_CONSUMER_FULL_SERVICE_GROWTH_BPS: int = 30
const DEMO_DEVELOPER_API_FULL_SERVICE_GROWTH_BPS: int = 10
const DEMO_CONSUMER_UNMET_PENALTY_BPS_PER_UNIT: int = 10
const DEMO_DEVELOPER_API_UNMET_PENALTY_BPS_PER_UNIT: int = 25
const DEMO_CONSUMER_CURRENT_SERVED_UNITS_PER_MONTH: int = 30
const DEMO_DEVELOPER_API_CURRENT_SERVED_UNITS_PER_MONTH: int = 20
const DEMO_CONSUMER_CURRENT_MARKET_REVENUE_CENTS: int = 30_000
const DEMO_DEVELOPER_API_CURRENT_MARKET_REVENUE_CENTS: int = 90_000
const DEMO_OPPONENT_ID: StringName = &"northstar_labs"
const DEMO_OPPONENT_DISPLAY_NAME: String = "Northstar Labs"
const DEMO_OPPONENT_PRESSURE_CONSUMER_BPS_PER_SERVED_UNIT: int = 2
const DEMO_OPPONENT_PRESSURE_DEVELOPER_API_BPS_PER_SERVED_UNIT: int = 5
const DEMO_AI_MASTER_SEED: int = 7

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
	var demo_market: MarketStateType = MarketStateType.new(
		DEMO_CONSUMER_WORKLOAD_UNITS_PER_MONTH,
		DEMO_DEVELOPER_API_WORKLOAD_UNITS_PER_MONTH,
		DEMO_CONSUMER_SERVICE_ALLOCATION_BPS,
		DEMO_CONSUMER_PLAYER_SHARE_BPS,
		DEMO_DEVELOPER_API_PLAYER_SHARE_BPS,
		DEMO_CONSUMER_ADDRESSABLE_MONTHLY_REVENUE_CENTS,
		DEMO_DEVELOPER_API_ADDRESSABLE_MONTHLY_REVENUE_CENTS,
		DEMO_CONSUMER_FULL_SERVICE_GROWTH_BPS,
		DEMO_DEVELOPER_API_FULL_SERVICE_GROWTH_BPS,
		DEMO_CONSUMER_UNMET_PENALTY_BPS_PER_UNIT,
		DEMO_DEVELOPER_API_UNMET_PENALTY_BPS_PER_UNIT,
		DEMO_CONSUMER_CURRENT_SERVED_UNITS_PER_MONTH,
		DEMO_DEVELOPER_API_CURRENT_SERVED_UNITS_PER_MONTH,
		DEMO_CONSUMER_CURRENT_MARKET_REVENUE_CENTS,
		DEMO_DEVELOPER_API_CURRENT_MARKET_REVENUE_CENTS,
		0,
		0,
		0,
		0,
		DEMO_OPPONENT_PRESSURE_CONSUMER_BPS_PER_SERVED_UNIT,
		DEMO_OPPONENT_PRESSURE_DEVELOPER_API_BPS_PER_SERVED_UNIT
	)
	var demo_opponent_compute: ComputeStateType = ComputeStateType.new(
		DEMO_TOTAL_COMPUTE_UNITS_PER_MONTH,
		DEMO_RESERVE_COMPUTE_UNITS_PER_MONTH,
		DEMO_INFERENCE_WORKLOAD_UNITS_PER_MONTH,
		DEMO_TRAINING_ALLOCATION_UNITS_PER_MONTH
	)
	var demo_opponent: OpponentStateType = OpponentStateType.new(
		DEMO_OPPONENT_ID,
		demo_opponent_compute
	)
	var demo_candidates: Array[OpponentPersonalityType.Candidate] = [
		OpponentPersonalityType.Candidate.new(
			OpponentPersonalityType.CANDIDATE_PLAN_40_DEFEND_MARKETS,
			40,
			OpponentPersonalityType.REASON_DEFEND_MARKET_POSITION,
			OpponentPersonalityType.UTILITY_RULE_DEFEND_MARKETS
		),
		OpponentPersonalityType.Candidate.new(
			OpponentPersonalityType.CANDIDATE_PLAN_70_CLOSE_TRAINING_GAP,
			70,
			OpponentPersonalityType.REASON_CLOSE_TRAINING_GAP,
			OpponentPersonalityType.UTILITY_RULE_CLOSE_TRAINING_GAP
		),
	]
	var demo_personality: OpponentPersonalityType = OpponentPersonalityType.new(
		DEMO_OPPONENT_ID,
		DEMO_OPPONENT_DISPLAY_NAME,
		demo_candidates,
		500,
		100,
		500,
		180
	)
	var demo_named_rng: NamedRngStateType = (
		NamedRngStateType.create_fresh_version_one(DEMO_AI_MASTER_SEED)
	)
	var demo_state: GameStateType = GameStateType.new(
		demo_company,
		demo_project,
		demo_compute,
		demo_market,
		demo_opponent,
		demo_named_rng
	)
	_game_session = GameSessionType.new(demo_state, demo_personality)
	dashboard.initialize(_game_session)
