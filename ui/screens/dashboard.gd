class_name Dashboard
extends Control


const GameSessionType = preload("res://application/game_session.gd")
const DashboardViewModelType = preload("res://application/view_models/dashboard_view_model.gd")
const StartProjectCommandType = preload("res://simulation/commands/start_project_command.gd")
const AdvanceQuarterCommandType = preload("res://simulation/commands/advance_quarter_command.gd")
const SetComputeAllocationCommandType = preload(
	"res://simulation/commands/set_compute_allocation_command.gd"
)

@onready var title_label: Label = $Header/TitleLabel
@onready var date_label: Label = $Header/DateLabel
@onready var cash_label: Label = $FinanceGrid/CashLabel
@onready var revenue_label: Label = $FinanceGrid/RevenueLabel
@onready var operating_cost_label: Label = $FinanceGrid/OperatingCostLabel
@onready var project_label: Label = $ProjectLabel
@onready var compute_plan_label: Label = $ComputePlanLabel
@onready var inference_workload_label: Label = $InferenceWorkloadLabel
@onready var training_units_spin_box: SpinBox = $ComputePlanControls/TrainingUnitsSpinBox
@onready var apply_compute_plan_button: Button = (
	$ComputePlanControls/ApplyComputePlanButton
)
@onready var consumer_market_label: Label = $MarketsGrid/ConsumerMarketLabel
@onready var developer_api_market_label: Label = $MarketsGrid/DeveloperApiMarketLabel
@onready var rival_signal_label: Label = $RivalGrid/RivalSignalLabel
@onready var rival_last_action_label: Label = $RivalGrid/RivalLastActionLabel
@onready var rival_reason_label: Label = $RivalGrid/RivalReasonLabel
@onready var rival_quarter_label: Label = $RivalGrid/RivalQuarterLabel
@onready var rival_utility_label: Label = $RivalGrid/RivalUtilityLabel
@onready var rival_market_pressure_label: Label = $RivalGrid/RivalMarketPressureLabel
@onready var cash_explanation_label: Label = $Explanation/CashReconciliationLabel
@onready var revenue_contribution_label: Label = $Explanation/RevenueContributionLabel
@onready var operating_cost_contribution_label: Label = $Explanation/OperatingCostContributionLabel
@onready var project_cost_contribution_label: Label = $Explanation/ProjectCostContributionLabel
@onready var progress_contribution_label: Label = $Explanation/ProgressContributionLabel
@onready var completion_revenue_contribution_label: Label = $Explanation/CompletionRevenueContributionLabel
@onready var training_work_label: Label = (
	$Explanation/ComputeExplanationGrid/TrainingWorkLabel
)
@onready var inference_served_label: Label = (
	$Explanation/ComputeExplanationGrid/InferenceServedLabel
)
@onready var inference_unmet_label: Label = (
	$Explanation/ComputeExplanationGrid/InferenceUnmetLabel
)
@onready var primary_button: Button = $PrimaryButton

var _session: GameSessionType
var _view_model: DashboardViewModelType


func _ready() -> void:
	primary_button.pressed.connect(_on_primary_button_pressed)
	apply_compute_plan_button.pressed.connect(_on_apply_compute_plan_button_pressed)


## Injects the sole business entry, connects once, and performs the initial refresh.
func initialize(p_session: GameSessionType) -> void:
	if p_session == null or _session != null:
		return
	_session = p_session
	_session.committed_result.connect(_on_committed_result)
	_refresh(_session.get_current_view_model())


func _on_primary_button_pressed() -> void:
	if _session == null or _view_model == null:
		return
	if _view_model.is_start_project_available():
		_session.submit_command(StartProjectCommandType.new())
	else:
		_session.submit_command(AdvanceQuarterCommandType.new())


func _on_apply_compute_plan_button_pressed() -> void:
	if _session == null or _view_model == null:
		return
	_session.submit_command(SetComputeAllocationCommandType.new(
		int(training_units_spin_box.value)
	))


func _on_committed_result(view_model: DashboardViewModelType) -> void:
	_refresh(view_model)


func _refresh(view_model: DashboardViewModelType) -> void:
	if view_model == null:
		return
	_view_model = view_model
	title_label.text = view_model.get_title_text()
	date_label.text = view_model.get_date_text()
	cash_label.text = view_model.get_cash_text()
	revenue_label.text = view_model.get_monthly_revenue_text()
	operating_cost_label.text = view_model.get_monthly_operating_cost_text()
	project_label.text = view_model.get_project_text()
	compute_plan_label.text = view_model.get_compute_plan_text()
	inference_workload_label.text = view_model.get_inference_workload_text()
	consumer_market_label.text = view_model.get_consumer_market_text()
	developer_api_market_label.text = view_model.get_developer_api_market_text()
	rival_signal_label.text = view_model.get_rival_signal_text()
	rival_last_action_label.text = view_model.get_rival_last_action_text()
	rival_reason_label.text = view_model.get_rival_reason_text()
	rival_quarter_label.text = view_model.get_rival_quarter_text()
	rival_utility_label.text = view_model.get_rival_utility_text()
	rival_market_pressure_label.text = view_model.get_rival_market_pressure_text()
	training_units_spin_box.max_value = float(
		view_model.get_maximum_training_allocation_units_per_month()
	)
	training_units_spin_box.value = float(
		view_model.get_training_allocation_units_per_month()
	)
	primary_button.text = view_model.get_action_text()
	cash_explanation_label.text = view_model.get_cash_explanation_text()
	revenue_contribution_label.text = view_model.get_revenue_contributions_text()
	operating_cost_contribution_label.text = view_model.get_operating_cost_contributions_text()
	project_cost_contribution_label.text = view_model.get_project_cost_contributions_text()
	progress_contribution_label.text = view_model.get_progress_contributions_text()
	completion_revenue_contribution_label.text = view_model.get_completion_revenue_text()
	training_work_label.text = view_model.get_training_work_text()
	inference_served_label.text = view_model.get_inference_served_text()
	inference_unmet_label.text = view_model.get_inference_unmet_text()
