class_name Dashboard
extends Control


const GameSessionType = preload("res://application/game_session.gd")
const DashboardViewModelType = preload("res://application/view_models/dashboard_view_model.gd")
const QuarterReportViewModelType = preload(
	"res://application/view_models/quarter_report_view_model.gd"
)
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
@onready var prototype_status_label: Label = (
	$PrototypeReportBar/PrototypeStatusLabel
)
@onready var selected_report_label: Label = (
	$PrototypeReportBar/SelectedReportLabel
)
@onready var previous_report_button: Button = (
	$PrototypeReportBar/PreviousReportButton
)
@onready var next_report_button: Button = $PrototypeReportBar/NextReportButton
@onready var report_details_button: Button = (
	$PrototypeReportBar/ReportDetailsButton
)
@onready var report_summary_label: Label = $ReportSummaryLabel
@onready var report_detail_scroll: ScrollContainer = $ReportDetailScroll
@onready var report_detail_label: Label = $ReportDetailScroll/ReportDetailLabel
@onready var primary_button: Button = $PrimaryButton

var _session: GameSessionType
var _view_model: DashboardViewModelType
var _report_view_models: Array[QuarterReportViewModelType] = []
var _selected_report_index: int = -1
var _report_drawer_expanded: bool = false


func _ready() -> void:
	primary_button.pressed.connect(_on_primary_button_pressed)
	apply_compute_plan_button.pressed.connect(_on_apply_compute_plan_button_pressed)
	previous_report_button.pressed.connect(_on_previous_report_button_pressed)
	next_report_button.pressed.connect(_on_next_report_button_pressed)
	report_details_button.pressed.connect(_on_report_details_button_pressed)


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
	if not _view_model.are_business_actions_enabled():
		return
	if _view_model.is_start_project_available():
		_session.submit_command(StartProjectCommandType.new())
	else:
		_session.submit_command(AdvanceQuarterCommandType.new())


func _on_apply_compute_plan_button_pressed() -> void:
	if _session == null or _view_model == null:
		return
	if not _view_model.are_business_actions_enabled():
		return
	_session.submit_command(SetComputeAllocationCommandType.new(
		int(training_units_spin_box.value)
	))


func _on_previous_report_button_pressed() -> void:
	if _selected_report_index <= 0:
		return
	_selected_report_index -= 1
	_refresh_report_presentation()


func _on_next_report_button_pressed() -> void:
	if (
		_selected_report_index < 0
		or _selected_report_index >= _report_view_models.size() - 1
	):
		return
	_selected_report_index += 1
	_refresh_report_presentation()


func _on_report_details_button_pressed() -> void:
	if _selected_report_index < 0 or _report_view_models.is_empty():
		return
	_report_drawer_expanded = not _report_drawer_expanded
	_refresh_report_presentation()


func _on_committed_result(view_model: DashboardViewModelType) -> void:
	_refresh(view_model)


func _refresh(view_model: DashboardViewModelType) -> void:
	if view_model == null:
		return
	var previous_report_count: int = _report_view_models.size()
	_view_model = view_model
	_report_view_models = view_model.get_quarter_report_view_models()
	if _report_view_models.is_empty():
		_selected_report_index = -1
		_report_drawer_expanded = false
	elif _report_view_models.size() > previous_report_count:
		_selected_report_index = _report_view_models.size() - 1
	elif _selected_report_index < 0:
		_selected_report_index = 0
	elif _selected_report_index >= _report_view_models.size():
		_selected_report_index = _report_view_models.size() - 1
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
	var business_actions_enabled: bool = view_model.are_business_actions_enabled()
	primary_button.disabled = not business_actions_enabled
	apply_compute_plan_button.disabled = not business_actions_enabled
	training_units_spin_box.editable = business_actions_enabled
	cash_explanation_label.text = view_model.get_cash_explanation_text()
	revenue_contribution_label.text = view_model.get_revenue_contributions_text()
	operating_cost_contribution_label.text = view_model.get_operating_cost_contributions_text()
	project_cost_contribution_label.text = view_model.get_project_cost_contributions_text()
	progress_contribution_label.text = view_model.get_progress_contributions_text()
	completion_revenue_contribution_label.text = view_model.get_completion_revenue_text()
	training_work_label.text = view_model.get_training_work_text()
	inference_served_label.text = view_model.get_inference_served_text()
	inference_unmet_label.text = view_model.get_inference_unmet_text()
	prototype_status_label.text = view_model.get_prototype_status_text()
	_refresh_report_presentation()


func _refresh_report_presentation() -> void:
	var has_selected_report: bool = (
		_selected_report_index >= 0
		and _selected_report_index < _report_view_models.size()
	)
	previous_report_button.disabled = not has_selected_report or _selected_report_index == 0
	next_report_button.disabled = (
		not has_selected_report
		or _selected_report_index >= _report_view_models.size() - 1
	)
	report_details_button.disabled = not has_selected_report
	if not has_selected_report:
		selected_report_label.text = "Quarter Report: —"
		report_summary_label.text = "No committed quarter report."
		report_detail_label.text = ""
		report_detail_scroll.visible = false
		report_details_button.text = "DETAILS"
		return

	var report_view_model: QuarterReportViewModelType = (
		_report_view_models[_selected_report_index]
	)
	if report_view_model == null or not report_view_model.is_valid():
		selected_report_label.text = "Quarter Report: unavailable"
		report_summary_label.text = "Committed report is unavailable."
		report_detail_label.text = ""
		report_detail_scroll.visible = false
		report_details_button.disabled = true
		report_details_button.text = "DETAILS"
		return
	selected_report_label.text = report_view_model.get_report_title_text()
	report_summary_label.text = report_view_model.get_summary_text()
	report_detail_label.text = report_view_model.get_detail_text()
	report_detail_scroll.visible = _report_drawer_expanded
	report_details_button.text = "HIDE DETAILS" if _report_drawer_expanded else "DETAILS"
