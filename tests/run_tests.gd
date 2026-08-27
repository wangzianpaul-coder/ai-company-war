extends SceneTree


const MAIN_SCENE: PackedScene = preload("res://main.tscn")
const GAME_COMMAND_SCRIPT = preload("res://simulation/commands/game_command.gd")
const COMMAND_RESULT_SCRIPT = preload("res://simulation/commands/command_result.gd")
const START_PROJECT_COMMAND_SCRIPT = preload("res://simulation/commands/start_project_command.gd")
const ADVANCE_QUARTER_COMMAND_SCRIPT = preload("res://simulation/commands/advance_quarter_command.gd")
const SET_COMPUTE_ALLOCATION_COMMAND_SCRIPT = preload(
	"res://simulation/commands/set_compute_allocation_command.gd"
)
const SIMULATION_CLOCK_SCRIPT = preload("res://simulation/engine/simulation_clock.gd")
const TICK_RESULT_SCRIPT = preload("res://simulation/engine/tick_result.gd")
const SIMULATION_ENGINE_SCRIPT = preload("res://simulation/engine/simulation_engine.gd")
const GAME_STATE_SCRIPT = preload("res://simulation/state/game_state.gd")
const COMPANY_STATE_SCRIPT = preload("res://simulation/state/company_state.gd")
const PROJECT_STATE_SCRIPT = preload("res://simulation/state/project_state.gd")
const COMPUTE_STATE_SCRIPT = preload("res://simulation/state/compute_state.gd")
const MARKET_STATE_SCRIPT = preload("res://simulation/state/market_state.gd")
const OPPONENT_STATE_SCRIPT = preload("res://simulation/state/opponent_state.gd")
const OPPONENT_PERSONALITY_SCRIPT = preload("res://simulation/ai/opponent_personality.gd")
const OPPONENT_PLANNING_SNAPSHOT_SCRIPT = preload(
	"res://simulation/ai/opponent_planning_snapshot.gd"
)
const OPPONENT_DECISION_SCRIPT = preload("res://simulation/ai/opponent_decision.gd")
const NAMED_RNG_STATE_SCRIPT = preload("res://simulation/rng/named_rng_state.gd")
const VERSIONED_RNG_SCRIPT = preload("res://simulation/rng/versioned_rng.gd")
const FINANCE_SYSTEM_SCRIPT = preload("res://simulation/systems/finance_system.gd")
const PROJECT_SYSTEM_SCRIPT = preload("res://simulation/systems/project_system.gd")
const COMPUTE_SYSTEM_SCRIPT = preload("res://simulation/systems/compute_system.gd")
const MARKET_SYSTEM_SCRIPT = preload("res://simulation/systems/market_system.gd")
const AI_SYSTEM_SCRIPT = preload("res://simulation/systems/ai_system.gd")
const EFFECT_CONTRIBUTION_SCRIPT = preload("res://simulation/events/effect_contribution.gd")
const EFFECT_BATCH_RESULT_SCRIPT = preload("res://simulation/events/effect_batch_result.gd")
const QUARTER_REPORT_SCRIPT = preload("res://simulation/reports/quarter_report.gd")
const QUARTER_REPORT_BUILDER_SCRIPT = preload(
	"res://simulation/reports/quarter_report_builder.gd"
)
const GAME_SESSION_SCRIPT = preload("res://application/game_session.gd")
const DASHBOARD_VIEW_MODEL_SCRIPT = preload("res://application/view_models/dashboard_view_model.gd")
const QUARTER_REPORT_VIEW_MODEL_SCRIPT = preload(
	"res://application/view_models/quarter_report_view_model.gd"
)
const DASHBOARD_SCRIPT = preload("res://ui/screens/dashboard.gd")
const SIX_QUARTER_BATCH_RESULT_SCRIPT = preload(
	"res://debug/six_quarter_batch_result.gd"
)
const SIX_QUARTER_BATCH_SIMULATOR_SCRIPT = preload(
	"res://debug/six_quarter_batch_simulator.gd"
)
const TEST_SIMULATION_CLOCK_SCRIPT = preload("res://tests/unit/test_simulation_clock.gd")
const TEST_FINANCE_PROJECT_EFFECTS_SCRIPT = preload("res://tests/unit/test_finance_project_effects.gd")
const TEST_QUARTER_SESSION_DASHBOARD_SCRIPT = preload(
	"res://tests/integration/test_quarter_session_dashboard.gd"
)
const TEST_COMPUTE_CAPACITY_SCRIPT = preload("res://tests/unit/test_compute_capacity.gd")
const TEST_COMPUTE_SESSION_DASHBOARD_SCRIPT = preload(
	"res://tests/integration/test_compute_session_dashboard.gd"
)
const TEST_TWO_MARKET_ECONOMY_SCRIPT = preload("res://tests/unit/test_two_market_economy.gd")
const TEST_MARKET_SESSION_DASHBOARD_SCRIPT = preload(
	"res://tests/integration/test_market_session_dashboard.gd"
)
const TEST_EXPLAINABLE_OPPONENT_SCRIPT = preload(
	"res://tests/unit/test_explainable_opponent.gd"
)
const TEST_OPPONENT_SESSION_DASHBOARD_SCRIPT = preload(
	"res://tests/integration/test_opponent_session_dashboard.gd"
)
const TEST_QUARTER_REPORT_SCRIPT = preload("res://tests/unit/test_quarter_report.gd")
const TEST_SIX_QUARTER_PROTOTYPE_SCRIPT = preload(
	"res://tests/integration/test_six_quarter_prototype.gd"
)
const TEST_SIX_QUARTER_BATCH_SCRIPT = preload(
	"res://tests/batch/test_six_quarter_batch.gd"
)

var _pass_count: int = 0
var _fail_count: int = 0


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var user_args: PackedStringArray = OS.get_cmdline_user_args()
	if user_args.has("--self-test-failure"):
		_check(false, "Runner failure self-test")
		_finish()
		return
	if user_args.has("--tp023-batch-only"):
		var batch_success: bool = TEST_SIX_QUARTER_BATCH_SCRIPT.run_batch_only(
			user_args.has("--tp023-inject-batch-failure")
		)
		quit(0 if batch_success else 1)
		return

	_check(GAME_COMMAND_SCRIPT != null, "GameCommand script is explicitly preloaded")
	_check(COMMAND_RESULT_SCRIPT != null, "CommandResult script is explicitly preloaded")
	_check(START_PROJECT_COMMAND_SCRIPT != null, "StartProjectCommand script is explicitly preloaded")
	_check(ADVANCE_QUARTER_COMMAND_SCRIPT != null, "AdvanceQuarterCommand script is explicitly preloaded")
	_check(
		SET_COMPUTE_ALLOCATION_COMMAND_SCRIPT != null,
		"SetComputeAllocationCommand script is explicitly preloaded"
	)
	_check(SIMULATION_CLOCK_SCRIPT != null, "SimulationClock script is explicitly preloaded")
	_check(TICK_RESULT_SCRIPT != null, "TickResult script is explicitly preloaded")
	_check(SIMULATION_ENGINE_SCRIPT != null, "SimulationEngine script is explicitly preloaded")
	_check(GAME_STATE_SCRIPT != null, "GameState script is explicitly preloaded")
	_check(COMPANY_STATE_SCRIPT != null, "CompanyState script is explicitly preloaded")
	_check(PROJECT_STATE_SCRIPT != null, "ProjectState script is explicitly preloaded")
	_check(COMPUTE_STATE_SCRIPT != null, "ComputeState script is explicitly preloaded")
	_check(MARKET_STATE_SCRIPT != null, "MarketState script is explicitly preloaded")
	_check(OPPONENT_STATE_SCRIPT != null, "OpponentState script is explicitly preloaded")
	_check(
		OPPONENT_PERSONALITY_SCRIPT != null,
		"OpponentPersonality script is explicitly preloaded"
	)
	_check(
		OPPONENT_PLANNING_SNAPSHOT_SCRIPT != null,
		"OpponentPlanningSnapshot script is explicitly preloaded"
	)
	_check(OPPONENT_DECISION_SCRIPT != null, "OpponentDecision script is explicitly preloaded")
	_check(NAMED_RNG_STATE_SCRIPT != null, "NamedRngState script is explicitly preloaded")
	_check(VERSIONED_RNG_SCRIPT != null, "VersionedRng script is explicitly preloaded")
	_check(FINANCE_SYSTEM_SCRIPT != null, "FinanceSystem script is explicitly preloaded")
	_check(PROJECT_SYSTEM_SCRIPT != null, "ProjectSystem script is explicitly preloaded")
	_check(COMPUTE_SYSTEM_SCRIPT != null, "ComputeSystem script is explicitly preloaded")
	_check(MARKET_SYSTEM_SCRIPT != null, "MarketSystem script is explicitly preloaded")
	_check(AI_SYSTEM_SCRIPT != null, "AiSystem script is explicitly preloaded")
	_check(EFFECT_CONTRIBUTION_SCRIPT != null, "EffectContribution script is explicitly preloaded")
	_check(EFFECT_BATCH_RESULT_SCRIPT != null, "EffectBatchResult script is explicitly preloaded")
	_check(QUARTER_REPORT_SCRIPT != null, "QuarterReport script is explicitly preloaded")
	_check(
		QUARTER_REPORT_BUILDER_SCRIPT != null,
		"QuarterReportBuilder script is explicitly preloaded"
	)
	_check(GAME_SESSION_SCRIPT != null, "GameSession script is explicitly preloaded")
	_check(DASHBOARD_VIEW_MODEL_SCRIPT != null, "DashboardViewModel script is explicitly preloaded")
	_check(
		QUARTER_REPORT_VIEW_MODEL_SCRIPT != null,
		"QuarterReportViewModel script is explicitly preloaded"
	)
	_check(DASHBOARD_SCRIPT != null, "Dashboard script is explicitly preloaded")
	_check(
		SIX_QUARTER_BATCH_RESULT_SCRIPT != null,
		"SixQuarterBatchResult script is explicitly preloaded"
	)
	_check(
		SIX_QUARTER_BATCH_SIMULATOR_SCRIPT != null,
		"SixQuarterBatchSimulator script is explicitly preloaded"
	)
	_check(TEST_SIMULATION_CLOCK_SCRIPT != null, "Simulation clock unit suite is explicitly preloaded")
	TEST_SIMULATION_CLOCK_SCRIPT.run(Callable(self, "_check"))
	_check(
		TEST_FINANCE_PROJECT_EFFECTS_SCRIPT != null,
		"Finance project effect unit suite is explicitly preloaded"
	)
	TEST_FINANCE_PROJECT_EFFECTS_SCRIPT.run(Callable(self, "_check"))
	_check(
		TEST_QUARTER_SESSION_DASHBOARD_SCRIPT != null,
		"Quarter session dashboard integration suite is explicitly preloaded"
	)
	TEST_QUARTER_SESSION_DASHBOARD_SCRIPT.run(Callable(self, "_check"))
	_check(
		TEST_COMPUTE_CAPACITY_SCRIPT != null,
		"Compute capacity unit suite is explicitly preloaded"
	)
	TEST_COMPUTE_CAPACITY_SCRIPT.run(Callable(self, "_check"))
	_check(
		TEST_COMPUTE_SESSION_DASHBOARD_SCRIPT != null,
		"Compute session dashboard integration suite is explicitly preloaded"
	)
	TEST_COMPUTE_SESSION_DASHBOARD_SCRIPT.run(Callable(self, "_check"))
	_check(
		TEST_TWO_MARKET_ECONOMY_SCRIPT != null,
		"Two-market economy unit suite is explicitly preloaded"
	)
	TEST_TWO_MARKET_ECONOMY_SCRIPT.run(Callable(self, "_check"))
	_check(
		TEST_MARKET_SESSION_DASHBOARD_SCRIPT != null,
		"Market session dashboard integration suite is explicitly preloaded"
	)
	TEST_MARKET_SESSION_DASHBOARD_SCRIPT.run(Callable(self, "_check"))
	_check(
		TEST_EXPLAINABLE_OPPONENT_SCRIPT != null,
		"Explainable opponent unit suite is explicitly preloaded"
	)
	TEST_EXPLAINABLE_OPPONENT_SCRIPT.run(Callable(self, "_check"))
	_check(
		TEST_OPPONENT_SESSION_DASHBOARD_SCRIPT != null,
		"Opponent session dashboard integration suite is explicitly preloaded"
	)
	TEST_OPPONENT_SESSION_DASHBOARD_SCRIPT.run(Callable(self, "_check"))
	_check(
		TEST_QUARTER_REPORT_SCRIPT != null,
		"Quarter report unit suite is explicitly preloaded"
	)
	TEST_QUARTER_REPORT_SCRIPT.run(Callable(self, "_check"))
	_check(
		TEST_SIX_QUARTER_PROTOTYPE_SCRIPT != null,
		"Six-quarter Prototype integration suite is explicitly preloaded"
	)
	TEST_SIX_QUARTER_PROTOTYPE_SCRIPT.run(Callable(self, "_check"))
	_check(
		TEST_SIX_QUARTER_BATCH_SCRIPT != null,
		"Six-quarter batch suite is explicitly preloaded"
	)
	TEST_SIX_QUARTER_BATCH_SCRIPT.run(Callable(self, "_check"))

	_check(MAIN_SCENE != null, "Main scene is explicitly preloaded")

	var main_instance: Node = MAIN_SCENE.instantiate()
	_check(main_instance != null, "Main scene instantiates")
	if main_instance == null:
		_finish()
		return

	_check(root != null, "SceneTree root exists")
	if root == null:
		main_instance.free()
		_finish()
		return

	var signal_stability_exact: bool = false
	var applied_compute_exact: bool = false
	var applied_market_exact: bool = false
	var signal_instance: Node = MAIN_SCENE.instantiate()
	if signal_instance != null:
		root.add_child(signal_instance)
		await process_frame
		var signal_training_spin_box: SpinBox = signal_instance.get_node_or_null(
			^"DashboardMargin/Dashboard/ComputePlanControls/TrainingUnitsSpinBox"
		) as SpinBox
		var signal_apply_button: Button = signal_instance.get_node_or_null(
			^"DashboardMargin/Dashboard/ComputePlanControls/ApplyComputePlanButton"
		) as Button
		var signal_primary_button: Button = signal_instance.get_node_or_null(
			^"DashboardMargin/Dashboard/PrimaryButton"
		) as Button
		var signal_compute_plan_label: Label = signal_instance.get_node_or_null(
			^"DashboardMargin/Dashboard/ComputePlanLabel"
		) as Label
		var signal_project_label: Label = signal_instance.get_node_or_null(
			^"DashboardMargin/Dashboard/ProjectLabel"
		) as Label
		var signal_consumer_label: Label = signal_instance.get_node_or_null(
			^"DashboardMargin/Dashboard/MarketsGrid/ConsumerMarketLabel"
		) as Label
		var signal_developer_label: Label = signal_instance.get_node_or_null(
			^"DashboardMargin/Dashboard/MarketsGrid/DeveloperApiMarketLabel"
		) as Label
		var signal_label: Label = signal_instance.get_node_or_null(
			^"DashboardMargin/Dashboard/RivalGrid/RivalSignalLabel"
		) as Label
		var signal_reason_label: Label = signal_instance.get_node_or_null(
			^"DashboardMargin/Dashboard/RivalGrid/RivalReasonLabel"
		) as Label
		var signal_utility_label: Label = signal_instance.get_node_or_null(
			^"DashboardMargin/Dashboard/RivalGrid/RivalUtilityLabel"
		) as Label
		var signal_last_action_label: Label = signal_instance.get_node_or_null(
			^"DashboardMargin/Dashboard/RivalGrid/RivalLastActionLabel"
		) as Label
		var signal_quarter_label: Label = signal_instance.get_node_or_null(
			^"DashboardMargin/Dashboard/RivalGrid/RivalQuarterLabel"
		) as Label
		var signal_pressure_label: Label = signal_instance.get_node_or_null(
			^"DashboardMargin/Dashboard/RivalGrid/RivalMarketPressureLabel"
		) as Label
		var initial_signal_exact: bool = (
			signal_label != null
			and signal_label.text == "Northstar Labs signal: 70 training / 20 inference"
			and signal_reason_label != null
			and signal_reason_label.text == "Why: Close training gap"
			and signal_utility_label != null
			and signal_utility_label.text == "Utility: 688 = 680 + 8 seeded noise"
			and signal_last_action_label != null
			and signal_last_action_label.text == "Last action: —"
			and signal_quarter_label != null
			and signal_quarter_label.text == "Quarter: —"
			and signal_pressure_label != null
			and signal_pressure_label.text == "Market pressure: —"
		)
		if signal_training_spin_box != null:
			signal_training_spin_box.value = 70.0
		if signal_apply_button != null:
			signal_apply_button.pressed.emit()
		await process_frame
		applied_compute_exact = (
			signal_compute_plan_label != null
			and signal_compute_plan_label.text
				== "Compute/month: 100 = 70 training + 20 inference + 10 reserve"
		)
		applied_market_exact = (
			signal_consumer_label != null
			and signal_consumer_label.text
				== "Consumer: 3,000 bps | workload 30 | 30,000 cents/month"
			and signal_developer_label != null
			and signal_developer_label.text
				== "Developer/API: 2,000 bps | workload 20 | 90,000 cents/month"
		)
		var signal_after_allocation_exact: bool = (
			initial_signal_exact
			and signal_label.text == "Northstar Labs signal: 70 training / 20 inference"
			and signal_reason_label.text == "Why: Close training gap"
			and signal_utility_label.text == "Utility: 688 = 680 + 8 seeded noise"
			and signal_last_action_label.text == "Last action: —"
			and signal_quarter_label.text == "Quarter: —"
			and signal_pressure_label.text == "Market pressure: —"
		)
		if signal_primary_button != null:
			signal_primary_button.pressed.emit()
		await process_frame
		signal_stability_exact = (
			signal_after_allocation_exact
			and applied_compute_exact
			and applied_market_exact
			and signal_project_label != null
			and signal_project_label.text == "Project: project_alpha — ACTIVE 0/3"
			and signal_label.text == "Northstar Labs signal: 70 training / 20 inference"
			and signal_reason_label.text == "Why: Close training gap"
			and signal_utility_label.text == "Utility: 688 = 680 + 8 seeded noise"
			and signal_last_action_label.text == "Last action: —"
			and signal_quarter_label.text == "Quarter: —"
			and signal_pressure_label.text == "Market pressure: —"
		)
		signal_instance.queue_free()
		await process_frame

	root.add_child(main_instance)
	await process_frame

	_check(main_instance is Control, "Main scene root is Control")

	var dashboard_margin: MarginContainer = main_instance.get_node_or_null(
		^"DashboardMargin"
	) as MarginContainer
	var dashboard: VBoxContainer = main_instance.get_node_or_null(
		^"DashboardMargin/Dashboard"
	) as VBoxContainer
	var title_label: Label = main_instance.get_node_or_null(
		^"DashboardMargin/Dashboard/Header/TitleLabel"
	) as Label
	var header_spacer: Control = main_instance.get_node_or_null(
		^"DashboardMargin/Dashboard/Header/HeaderSpacer"
	) as Control
	var date_label: Label = main_instance.get_node_or_null(
		^"DashboardMargin/Dashboard/Header/DateLabel"
	) as Label
	var header_separator: HSeparator = main_instance.get_node_or_null(
		^"DashboardMargin/Dashboard/HeaderSeparator"
	) as HSeparator
	var company_heading: Label = main_instance.get_node_or_null(
		^"DashboardMargin/Dashboard/CompanyHeading"
	) as Label
	var cash_label: Label = main_instance.get_node_or_null(
		^"DashboardMargin/Dashboard/FinanceGrid/CashLabel"
	) as Label
	var revenue_label: Label = main_instance.get_node_or_null(
		^"DashboardMargin/Dashboard/FinanceGrid/RevenueLabel"
	) as Label
	var operating_cost_label: Label = main_instance.get_node_or_null(
		^"DashboardMargin/Dashboard/FinanceGrid/OperatingCostLabel"
	) as Label
	var project_label: Label = main_instance.get_node_or_null(
		^"DashboardMargin/Dashboard/ProjectLabel"
	) as Label
	var compute_heading: Label = main_instance.get_node_or_null(
		^"DashboardMargin/Dashboard/ComputeHeading"
	) as Label
	var compute_plan_label: Label = main_instance.get_node_or_null(
		^"DashboardMargin/Dashboard/ComputePlanLabel"
	) as Label
	var inference_workload_label: Label = main_instance.get_node_or_null(
		^"DashboardMargin/Dashboard/InferenceWorkloadLabel"
	) as Label
	var training_units_label: Label = main_instance.get_node_or_null(
		^"DashboardMargin/Dashboard/ComputePlanControls/TrainingUnitsLabel"
	) as Label
	var training_units_spin_box: SpinBox = main_instance.get_node_or_null(
		^"DashboardMargin/Dashboard/ComputePlanControls/TrainingUnitsSpinBox"
	) as SpinBox
	var compute_plan_spacer: Control = main_instance.get_node_or_null(
		^"DashboardMargin/Dashboard/ComputePlanControls/ComputePlanSpacer"
	) as Control
	var apply_compute_plan_button: Button = main_instance.get_node_or_null(
		^"DashboardMargin/Dashboard/ComputePlanControls/ApplyComputePlanButton"
	) as Button
	var advance_quarter_button: Button = main_instance.get_node_or_null(
		^"DashboardMargin/Dashboard/ComputePlanControls/AdvanceQuarterButton"
	) as Button
	var markets_heading: Label = main_instance.get_node_or_null(
		^"DashboardMargin/Dashboard/MarketsHeading"
	) as Label
	var consumer_market_label: Label = main_instance.get_node_or_null(
		^"DashboardMargin/Dashboard/MarketsGrid/ConsumerMarketLabel"
	) as Label
	var developer_api_market_label: Label = main_instance.get_node_or_null(
		^"DashboardMargin/Dashboard/MarketsGrid/DeveloperApiMarketLabel"
	) as Label
	var rival_heading: Label = main_instance.get_node_or_null(
		^"DashboardMargin/Dashboard/RivalHeading"
	) as Label
	var rival_signal_label: Label = main_instance.get_node_or_null(
		^"DashboardMargin/Dashboard/RivalGrid/RivalSignalLabel"
	) as Label
	var rival_last_action_label: Label = main_instance.get_node_or_null(
		^"DashboardMargin/Dashboard/RivalGrid/RivalLastActionLabel"
	) as Label
	var rival_reason_label: Label = main_instance.get_node_or_null(
		^"DashboardMargin/Dashboard/RivalGrid/RivalReasonLabel"
	) as Label
	var rival_quarter_label: Label = main_instance.get_node_or_null(
		^"DashboardMargin/Dashboard/RivalGrid/RivalQuarterLabel"
	) as Label
	var rival_utility_label: Label = main_instance.get_node_or_null(
		^"DashboardMargin/Dashboard/RivalGrid/RivalUtilityLabel"
	) as Label
	var rival_market_pressure_label: Label = main_instance.get_node_or_null(
		^"DashboardMargin/Dashboard/RivalGrid/RivalMarketPressureLabel"
	) as Label
	var project_heading: Label = main_instance.get_node_or_null(
		^"DashboardMargin/Dashboard/ProjectHeading"
	) as Label
	var primary_button: Button = main_instance.get_node_or_null(
		^"DashboardMargin/Dashboard/PrimaryButton"
	) as Button
	var explanation_heading: Label = main_instance.get_node_or_null(
		^"DashboardMargin/Dashboard/ExplanationHeading"
	) as Label
	var cash_explanation_label: Label = main_instance.get_node_or_null(
		^"DashboardMargin/Dashboard/Explanation/CashReconciliationLabel"
	) as Label
	var revenue_contribution_label: Label = main_instance.get_node_or_null(
		^"DashboardMargin/Dashboard/Explanation/RevenueContributionLabel"
	) as Label
	var operating_cost_contribution_label: Label = main_instance.get_node_or_null(
		^"DashboardMargin/Dashboard/Explanation/OperatingCostContributionLabel"
	) as Label
	var project_cost_contribution_label: Label = main_instance.get_node_or_null(
		^"DashboardMargin/Dashboard/Explanation/ProjectCostContributionLabel"
	) as Label
	var progress_contribution_label: Label = main_instance.get_node_or_null(
		^"DashboardMargin/Dashboard/Explanation/ProgressContributionLabel"
	) as Label
	var completion_revenue_contribution_label: Label = main_instance.get_node_or_null(
		^"DashboardMargin/Dashboard/Explanation/CompletionRevenueContributionLabel"
	) as Label
	var training_work_label: Label = main_instance.get_node_or_null(
		^"DashboardMargin/Dashboard/Explanation/ComputeExplanationGrid/TrainingWorkLabel"
	) as Label
	var inference_served_label: Label = main_instance.get_node_or_null(
		^"DashboardMargin/Dashboard/Explanation/ComputeExplanationGrid/InferenceServedLabel"
	) as Label
	var inference_unmet_label: Label = main_instance.get_node_or_null(
		^"DashboardMargin/Dashboard/Explanation/ComputeExplanationGrid/InferenceUnmetLabel"
	) as Label
	var prototype_heading: Label = main_instance.get_node_or_null(
		^"DashboardMargin/Dashboard/PrototypeHeading"
	) as Label
	var prototype_status_label: Label = main_instance.get_node_or_null(
		^"DashboardMargin/Dashboard/PrototypeReportBar/PrototypeStatusLabel"
	) as Label
	var selected_report_label: Label = main_instance.get_node_or_null(
		^"DashboardMargin/Dashboard/PrototypeReportBar/SelectedReportLabel"
	) as Label
	var previous_report_button: Button = main_instance.get_node_or_null(
		^"DashboardMargin/Dashboard/PrototypeReportBar/PreviousReportButton"
	) as Button
	var next_report_button: Button = main_instance.get_node_or_null(
		^"DashboardMargin/Dashboard/PrototypeReportBar/NextReportButton"
	) as Button
	var report_details_button: Button = main_instance.get_node_or_null(
		^"DashboardMargin/Dashboard/PrototypeReportBar/ReportDetailsButton"
	) as Button
	var report_summary_label: Label = main_instance.get_node_or_null(
		^"DashboardMargin/Dashboard/ReportSummaryLabel"
	) as Label
	var report_detail_scroll: ScrollContainer = main_instance.get_node_or_null(
		^"DashboardMargin/Dashboard/ReportDetailScroll"
	) as ScrollContainer
	var body_spacer: Control = main_instance.get_node_or_null(
		^"DashboardMargin/Dashboard/BodySpacer"
	) as Control

	_check(dashboard_margin != null, "Dashboard uses a full-screen MarginContainer")
	_check(dashboard != null, "Dashboard uses a VBoxContainer")
	_check(title_label != null, "Dashboard TitleLabel exists")
	_check(date_label != null, "Dashboard DateLabel exists")
	_check(cash_label != null and revenue_label != null and operating_cost_label != null, "Dashboard finance labels exist")
	_check(project_label != null, "Dashboard ProjectLabel exists")
	_check(primary_button != null, "Dashboard PrimaryButton exists")
	var initial_scene_exact: bool = (
		title_label != null
		and title_label.text == "AI COMPANY WAR"
		and date_label != null
		and date_label.text == "2026 Q1"
		and cash_label != null
		and cash_label.text == "Cash: 1,000,000 cents"
		and revenue_label != null
		and revenue_label.text == "Monthly revenue: 120,000 cents"
		and operating_cost_label != null
		and operating_cost_label.text == "Monthly operating cost: 80,000 cents"
		and project_label != null
		and project_label.text == "Project: project_alpha — NOT STARTED 0/3"
		and primary_button != null
		and primary_button.text == "START PROJECT"
		and primary_button.is_visible_in_tree()
		and not primary_button.disabled
	)
	_check(initial_scene_exact, "Dashboard initial fixed G1 fields are exact")
	var initial_compute_exact: bool = (
		compute_heading != null
		and compute_heading.text == "COMPUTE"
		and compute_plan_label != null
		and compute_plan_label.text
			== "Compute/month: 100 = 40 training + 50 inference + 10 reserve"
		and inference_workload_label != null
		and inference_workload_label.text == "Inference workload: 50 units/month"
		and training_units_label != null
		and training_units_label.text == "Training units/month"
		and training_units_spin_box != null
		and int(training_units_spin_box.value) == 40
		and int(training_units_spin_box.max_value) == 90
		and training_units_spin_box.is_visible_in_tree()
		and training_units_spin_box.editable
		and apply_compute_plan_button != null
		and apply_compute_plan_button.text == "SET COMPUTE ALLOCATION"
		and apply_compute_plan_button.is_visible_in_tree()
		and not apply_compute_plan_button.disabled
		and advance_quarter_button != null
		and advance_quarter_button.text == "ADVANCE QUARTER"
		and advance_quarter_button.is_visible_in_tree()
		and advance_quarter_button.disabled
		and training_work_label != null
		and training_work_label.text == "Training work: 0 compute-unit-months"
		and inference_served_label != null
		and inference_served_label.text == "Inference served: 0/0 compute-unit-months"
		and inference_unmet_label != null
		and inference_unmet_label.text == "Inference unmet: 0 compute-unit-months"
	)
	var initial_market_exact: bool = (
		markets_heading != null
		and markets_heading.text == "MARKETS"
		and consumer_market_label != null
		and consumer_market_label.text
			== "Consumer: 3,000 bps | workload 30 | 30,000 cents/month"
		and developer_api_market_label != null
		and developer_api_market_label.text
			== "Developer/API: 2,000 bps | workload 20 | 90,000 cents/month"
	)
	var initial_rival_exact: bool = (
		rival_heading != null
		and rival_heading.text == "RIVAL"
		and rival_signal_label != null
		and rival_signal_label.text
			== "Northstar Labs signal: 70 training / 20 inference"
		and rival_reason_label != null
		and rival_reason_label.text == "Why: Close training gap"
		and rival_utility_label != null
		and rival_utility_label.text == "Utility: 688 = 680 + 8 seeded noise"
		and rival_last_action_label != null
		and rival_last_action_label.text == "Last action: —"
		and rival_quarter_label != null
		and rival_quarter_label.text == "Quarter: —"
		and rival_market_pressure_label != null
		and rival_market_pressure_label.text == "Market pressure: —"
	)
	var initial_report_exact: bool = (
		prototype_heading != null
		and prototype_heading.text == "PROTOTYPE / QUARTER REPORT"
		and prototype_status_label != null
		and prototype_status_label.text == "Prototype quarter: 0/6"
		and selected_report_label != null
		and selected_report_label.text == "Quarter Report: —"
		and previous_report_button != null
		and previous_report_button.disabled
		and next_report_button != null
		and next_report_button.disabled
		and report_details_button != null
		and report_details_button.disabled
		and report_summary_label != null
		and report_summary_label.text == "No committed quarter report."
		and report_detail_scroll != null
		and not report_detail_scroll.visible
	)

	if primary_button != null:
		primary_button.pressed.emit()
	await process_frame
	var first_press_exact: bool = (
		date_label != null
		and date_label.text == "2026 Q1"
		and cash_label != null
		and cash_label.text == "Cash: 1,000,000 cents"
		and revenue_label != null
		and revenue_label.text == "Monthly revenue: 120,000 cents"
		and operating_cost_label != null
		and operating_cost_label.text == "Monthly operating cost: 80,000 cents"
		and project_label != null
		and project_label.text == "Project: project_alpha — ACTIVE 0/3"
		and primary_button != null
		and primary_button.text == "START PROJECT"
		and primary_button.disabled
		and apply_compute_plan_button != null
		and not apply_compute_plan_button.disabled
		and advance_quarter_button != null
		and advance_quarter_button.text == "ADVANCE QUARTER"
		and not advance_quarter_button.disabled
	)
	var first_press_market_exact: bool = (
		consumer_market_label != null
		and consumer_market_label.text
			== "Consumer: 3,000 bps | workload 30 | 30,000 cents/month"
		and developer_api_market_label != null
		and developer_api_market_label.text
			== "Developer/API: 2,000 bps | workload 20 | 90,000 cents/month"
	)
	var first_press_rival_exact: bool = (
		rival_signal_label != null
		and rival_signal_label.text
			== "Northstar Labs signal: 70 training / 20 inference"
		and rival_reason_label != null
		and rival_reason_label.text == "Why: Close training gap"
		and rival_utility_label != null
		and rival_utility_label.text == "Utility: 688 = 680 + 8 seeded noise"
		and rival_last_action_label != null
		and rival_last_action_label.text == "Last action: —"
		and rival_quarter_label != null
		and rival_quarter_label.text == "Quarter: —"
		and rival_market_pressure_label != null
		and rival_market_pressure_label.text == "Market pressure: —"
	)
	_check(first_press_exact, "First press starts only the fixed project")

	if advance_quarter_button != null:
		advance_quarter_button.pressed.emit()
	await process_frame
	var final_scene_exact: bool = (
		date_label != null
		and date_label.text == "2026 Q2"
		and cash_label != null
		and cash_label.text == "Cash: 1,071,130 cents"
		and revenue_label != null
		and revenue_label.text == "Monthly revenue: 146,130 cents"
		and operating_cost_label != null
		and operating_cost_label.text == "Monthly operating cost: 80,000 cents"
		and project_label != null
		and project_label.text == "Project: project_alpha — COMPLETED 3/3"
		and primary_button != null
		and primary_button.text == "START PROJECT"
		and primary_button.disabled
		and apply_compute_plan_button != null
		and not apply_compute_plan_button.disabled
		and advance_quarter_button != null
		and advance_quarter_button.text == "ADVANCE QUARTER"
		and not advance_quarter_button.disabled
		and cash_explanation_label != null
		and cash_explanation_label.text
			== "Cash: 1,000,000 → 1,071,130 = +71,130 cents"
		and revenue_contribution_label != null
		and revenue_contribution_label.text
			== "Revenue cash contributions: +386,130 cents"
		and operating_cost_contribution_label != null
		and operating_cost_contribution_label.text
			== "Operating-cost contributions: -240,000 cents"
		and project_cost_contribution_label != null
		and project_cost_contribution_label.text
			== "Project-cost contributions: -75,000 cents"
		and progress_contribution_label != null
		and progress_contribution_label.text == "Project progress: +3 months"
		and completion_revenue_contribution_label != null
		and completion_revenue_contribution_label.text
			== "Completion monthly revenue: +30,000 cents"
	)
	TEST_QUARTER_SESSION_DASHBOARD_SCRIPT.report_dashboard_scene(
		Callable(self, "_check"),
		initial_scene_exact and first_press_exact and final_scene_exact
	)
	var final_market_exact: bool = (
		consumer_market_label != null
		and consumer_market_label.text
			== "Consumer: served 90/90, share +18 → 3,018 bps, revenue +180 → 30,180"
		and developer_api_market_label != null
		and developer_api_market_label.text
			== "Developer/API: served 60/60, share -90 → 1,910 bps, revenue -4,050 → 85,950"
	)
	TEST_MARKET_SESSION_DASHBOARD_SCRIPT.report_dashboard_scene(
		Callable(self, "_check"),
		initial_market_exact
			and applied_market_exact
			and first_press_market_exact
			and final_market_exact
	)
	var final_compute_exact: bool = (
		compute_plan_label != null
		and compute_plan_label.text
			== "Compute/month: 100 = 40 training + 50 inference + 10 reserve"
		and training_work_label != null
		and training_work_label.text == "Training work: +120 compute-unit-months"
		and inference_served_label != null
		and inference_served_label.text == "Inference served: 150/150 compute-unit-months"
		and inference_unmet_label != null
		and inference_unmet_label.text == "Inference unmet: 0 compute-unit-months"
	)
	TEST_COMPUTE_SESSION_DASHBOARD_SCRIPT.report_dashboard_scene(
		Callable(self, "_check"),
		initial_compute_exact and applied_compute_exact and final_compute_exact
	)
	var final_rival_exact: bool = (
		rival_signal_label != null
		and rival_signal_label.text
			== "Next signal: 40 training / 50 inference — Defend market position"
		and rival_reason_label != null
		and rival_reason_label.text == "Why: Defend market position"
		and rival_utility_label != null
		and rival_utility_label.text == "Utility: 553 = 549 + 4 seeded noise"
		and rival_last_action_label != null
		and rival_last_action_label.text == "Last action: 70 training / 20 inference"
		and rival_quarter_label != null
		and rival_quarter_label.text
			== "Quarter: +210 training; inference 60/150; unmet 90"
		and rival_market_pressure_label != null
		and rival_market_pressure_label.text
			== "Market pressure: Consumer -72 bps; Developer/API -120 bps"
	)
	TEST_OPPONENT_SESSION_DASHBOARD_SCRIPT.report_dashboard_scene(
		Callable(self, "_check"),
		signal_stability_exact
			and initial_rival_exact
			and first_press_rival_exact
			and final_scene_exact
			and final_market_exact
			and final_compute_exact
			and final_rival_exact
	)
	var report_navigation_exact: bool = await (
		TEST_SIX_QUARTER_PROTOTYPE_SCRIPT.validate_dashboard_report_history_scene(
			main_instance as Control,
			root
		)
	)
	_check(
		initial_report_exact and report_navigation_exact,
		"TP-023 dashboard navigates six primitive reports without simulation access"
	)

	var visible_controls: Array[Control] = [
		title_label,
		header_spacer,
		date_label,
		header_separator,
		company_heading,
		cash_label,
		revenue_label,
		operating_cost_label,
		compute_heading,
		compute_plan_label,
		inference_workload_label,
		training_units_label,
		training_units_spin_box,
		compute_plan_spacer,
		apply_compute_plan_button,
		advance_quarter_button,
		markets_heading,
		consumer_market_label,
		developer_api_market_label,
		rival_heading,
		rival_signal_label,
		rival_last_action_label,
		rival_reason_label,
		rival_quarter_label,
		rival_utility_label,
		rival_market_pressure_label,
		project_heading,
		project_label,
		primary_button,
		explanation_heading,
		cash_explanation_label,
		revenue_contribution_label,
		operating_cost_contribution_label,
		project_cost_contribution_label,
		progress_contribution_label,
		completion_revenue_contribution_label,
		training_work_label,
		inference_served_label,
		inference_unmet_label,
		prototype_heading,
		prototype_status_label,
		selected_report_label,
		previous_report_button,
		next_report_button,
		report_details_button,
		report_summary_label,
		report_detail_scroll,
		body_spacer,
	]
	root.size = Vector2i(1280, 720)
	await process_frame
	await process_frame
	var fits_1280: bool = _dashboard_fits(
		main_instance as Control,
		dashboard_margin,
		dashboard,
		visible_controls,
		Vector2i(1280, 720)
	)
	root.size = Vector2i(1920, 1080)
	await process_frame
	await process_frame
	var fits_1920: bool = _dashboard_fits(
		main_instance as Control,
		dashboard_margin,
		dashboard,
		visible_controls,
		Vector2i(1920, 1080)
	)
	TEST_QUARTER_SESSION_DASHBOARD_SCRIPT.report_dashboard_layout(
		Callable(self, "_check"),
		fits_1280 and fits_1920
	)
	TEST_COMPUTE_SESSION_DASHBOARD_SCRIPT.report_dashboard_layout(
		Callable(self, "_check"),
		fits_1280 and fits_1920
	)
	TEST_MARKET_SESSION_DASHBOARD_SCRIPT.report_dashboard_layout(
		Callable(self, "_check"),
		fits_1280 and fits_1920
	)
	TEST_OPPONENT_SESSION_DASHBOARD_SCRIPT.report_dashboard_layout(
		Callable(self, "_check"),
		fits_1280 and fits_1920
	)
	_check(
		fits_1280 and fits_1920,
		"TP-023 dashboard report fits 1280x720 and 1920x1080"
	)

	main_instance.queue_free()
	await process_frame
	_finish()


func _dashboard_fits(
	main_control: Control,
	dashboard_margin: MarginContainer,
	dashboard: VBoxContainer,
	visible_controls: Array[Control],
	resolution: Vector2i
) -> bool:
	if main_control == null or dashboard_margin == null or dashboard == null:
		print("[LAYOUT] Missing root layout node at %dx%d" % [resolution.x, resolution.y])
		return false
	var viewport: Viewport = main_control.get_viewport()
	if viewport == null:
		print("[LAYOUT] Missing viewport at %dx%d" % [resolution.x, resolution.y])
		return false
	if not viewport is Window:
		print("[LAYOUT] Root viewport is not a Window at %dx%d" % [resolution.x, resolution.y])
		return false
	var window: Window = viewport as Window
	var viewport_rect: Rect2 = viewport.get_visible_rect()
	if (
		window.size != resolution
		or window.content_scale_size != Vector2i(1152, 648)
		or viewport_rect.size != Vector2(1152, 648)
	):
		print("[LAYOUT] Physical/logical viewport mismatch at %dx%d: window=%s base=%s visible=%s" % [
			resolution.x,
			resolution.y,
			window.size,
			window.content_scale_size,
			viewport_rect,
		])
		return false
	var main_rect: Rect2 = main_control.get_global_rect()
	var margin_rect: Rect2 = dashboard_margin.get_global_rect()
	if not viewport_rect.encloses(main_rect) or not viewport_rect.encloses(margin_rect):
		print("[LAYOUT] Root containment failed at %dx%d: main=%s margin=%s" % [
			resolution.x,
			resolution.y,
			main_rect,
			margin_rect,
		])
		for child in dashboard.get_children():
			if child is Control:
				var child_control: Control = child as Control
				print("[LAYOUT] Child %s visible=%s rect=%s minimum=%s" % [
					child_control.name,
					child_control.visible,
					child_control.get_global_rect(),
					child_control.get_combined_minimum_size(),
				])
		return false
	if main_rect.size != viewport_rect.size:
		print("[LAYOUT] Main logical size failed at %dx%d: main=%s visible=%s" % [
			resolution.x,
			resolution.y,
			main_rect.size,
			viewport_rect.size,
		])
		return false
	if margin_rect.size != viewport_rect.size:
		print("[LAYOUT] Margin logical size failed at %dx%d: margin=%s visible=%s" % [
			resolution.x,
			resolution.y,
			margin_rect.size,
			viewport_rect.size,
		])
		return false
	if not viewport_rect.encloses(dashboard.get_global_rect()):
		print("[LAYOUT] Dashboard containment failed at %dx%d: %s" % [
			resolution.x,
			resolution.y,
			dashboard.get_global_rect(),
		])
		return false
	var dashboard_rect: Rect2 = dashboard.get_global_rect()
	var dashboard_minimum: Vector2 = dashboard.get_combined_minimum_size()
	if (
		dashboard_rect.size.x < dashboard_minimum.x
		or dashboard_rect.size.y < dashboard_minimum.y
	):
		print("[LAYOUT] Dashboard minimum size failed at %dx%d: rect=%s minimum=%s" % [
			resolution.x,
			resolution.y,
			dashboard_rect,
			dashboard_minimum,
		])
		return false
	var top_safe_gap: float = dashboard_rect.position.y - main_rect.position.y
	var bottom_safe_gap: float = (
		main_rect.position.y + main_rect.size.y
		- dashboard_rect.position.y - dashboard_rect.size.y
	)
	if top_safe_gap < 8.0 or bottom_safe_gap < 8.0:
		print("[LAYOUT] Dashboard safe area failed at %dx%d: top=%s bottom=%s" % [
			resolution.x,
			resolution.y,
			top_safe_gap,
			bottom_safe_gap,
		])
		return false
	for control in visible_controls:
		if control == null:
			print("[LAYOUT] Missing visible control at %dx%d" % [resolution.x, resolution.y])
			return false
		if not control.is_visible_in_tree():
			print("[LAYOUT] Hidden control at %dx%d: %s" % [
				resolution.x,
				resolution.y,
				control.name,
			])
			return false
		var rect: Rect2 = control.get_global_rect()
		var minimum: Vector2 = control.get_combined_minimum_size()
		if rect.size.x <= 0.0 or rect.size.y <= 0.0:
			print("[LAYOUT] Empty control at %dx%d: %s rect=%s" % [
				resolution.x,
				resolution.y,
				control.name,
				rect,
			])
			return false
		if not viewport_rect.encloses(rect):
			print("[LAYOUT] Control outside viewport at %dx%d: %s rect=%s" % [
				resolution.x,
				resolution.y,
				control.name,
				rect,
			])
			return false
		if rect.size.x < minimum.x or rect.size.y < minimum.y:
			print("[LAYOUT] Minimum size failed at %dx%d: %s rect=%s minimum=%s" % [
				resolution.x,
				resolution.y,
				control.name,
				rect,
				minimum,
			])
			return false
	var header: HBoxContainer = main_control.get_node_or_null(
		^"DashboardMargin/Dashboard/Header"
	) as HBoxContainer
	var title: Label = main_control.get_node_or_null(
		^"DashboardMargin/Dashboard/Header/TitleLabel"
	) as Label
	var date: Label = main_control.get_node_or_null(
		^"DashboardMargin/Dashboard/Header/DateLabel"
	) as Label
	var separator: HSeparator = main_control.get_node_or_null(
		^"DashboardMargin/Dashboard/HeaderSeparator"
	) as HSeparator
	var detail_scroll: ScrollContainer = main_control.get_node_or_null(
		^"DashboardMargin/Dashboard/ReportDetailScroll"
	) as ScrollContainer
	var detail_label: Label = main_control.get_node_or_null(
		^"DashboardMargin/Dashboard/ReportDetailScroll/ReportDetailLabel"
	) as Label
	var bottom_spacer: Control = main_control.get_node_or_null(
		^"DashboardMargin/Dashboard/BodySpacer"
	) as Control
	if (
		header == null
		or title == null
		or date == null
		or separator == null
		or detail_scroll == null
		or detail_label == null
		or bottom_spacer == null
	):
		print("[LAYOUT] Missing safe-area control at %dx%d" % [resolution.x, resolution.y])
		return false
	var header_rect: Rect2 = header.get_global_rect()
	var title_font: Font = title.get_theme_font(&"font")
	var date_font: Font = date.get_theme_font(&"font")
	var required_header_height: float = maxf(
		title_font.get_height(title.get_theme_font_size(&"font_size")),
		date_font.get_height(date.get_theme_font_size(&"font_size"))
	) + 8.0
	if (
		not header_rect.encloses(title.get_global_rect())
		or not header_rect.encloses(date.get_global_rect())
		or header_rect.size.y < required_header_height
		or separator.get_global_rect().position.y
			< header_rect.position.y + header_rect.size.y
	):
		print("[LAYOUT] Header glyph safety failed at %dx%d: header=%s title=%s date=%s separator_y=%s required_height=%s" % [
			resolution.x,
			resolution.y,
			header_rect,
			title.get_global_rect(),
			date.get_global_rect(),
			separator.get_global_rect().position.y,
			required_header_height,
		])
		return false
	var detail_rect: Rect2 = detail_scroll.get_global_rect()
	var spacer_rect: Rect2 = bottom_spacer.get_global_rect()
	if (
		not detail_scroll.clip_contents
		or spacer_rect.size.y < 8.0
		or spacer_rect.position.y < detail_rect.position.y + detail_rect.size.y
		or detail_rect.position.y + detail_rect.size.y + 8.0
			> dashboard_rect.position.y + dashboard_rect.size.y
	):
		print("[LAYOUT] Report bottom safety failed at %dx%d" % [resolution.x, resolution.y])
		return false
	if detail_label.get_combined_minimum_size().y > detail_rect.size.y:
		var vertical_scroll_bar: VScrollBar = detail_scroll.get_v_scroll_bar()
		if (
			vertical_scroll_bar == null
			or not vertical_scroll_bar.is_visible_in_tree()
			or vertical_scroll_bar.max_value <= vertical_scroll_bar.page
		):
			print("[LAYOUT] Report overflow is not scrollable at %dx%d" % [
				resolution.x,
				resolution.y,
			])
			return false
	for first_index in visible_controls.size():
		for second_index in range(first_index + 1, visible_controls.size()):
			var first_control: Control = visible_controls[first_index]
			var second_control: Control = visible_controls[second_index]
			if first_control.get_global_rect().intersects(second_control.get_global_rect()):
				print("[LAYOUT] Controls overlap at %dx%d: %s and %s" % [
					resolution.x,
					resolution.y,
					first_control.name,
					second_control.name,
				])
				return false
	return true


func _check(condition: bool, description: String) -> void:
	if condition:
		_pass_count += 1
		print("[PASS] %s" % description)
	else:
		_fail_count += 1
		print("[FAIL] %s" % description)


func _finish() -> void:
	print("[SUMMARY] passed=%d failed=%d" % [_pass_count, _fail_count])
	quit(0 if _fail_count == 0 else 1)
