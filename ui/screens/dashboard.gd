class_name Dashboard
extends Control


const GameSessionType = preload("res://application/game_session.gd")
const DashboardViewModelType = preload("res://application/view_models/dashboard_view_model.gd")
const StartProjectCommandType = preload("res://simulation/commands/start_project_command.gd")
const AdvanceQuarterCommandType = preload("res://simulation/commands/advance_quarter_command.gd")

@onready var title_label: Label = $Header/TitleLabel
@onready var date_label: Label = $Header/DateLabel
@onready var cash_label: Label = $FinanceGrid/CashLabel
@onready var revenue_label: Label = $FinanceGrid/RevenueLabel
@onready var operating_cost_label: Label = $FinanceGrid/OperatingCostLabel
@onready var project_label: Label = $ProjectLabel
@onready var cash_explanation_label: Label = $Explanation/CashReconciliationLabel
@onready var revenue_contribution_label: Label = $Explanation/RevenueContributionLabel
@onready var operating_cost_contribution_label: Label = $Explanation/OperatingCostContributionLabel
@onready var project_cost_contribution_label: Label = $Explanation/ProjectCostContributionLabel
@onready var progress_contribution_label: Label = $Explanation/ProgressContributionLabel
@onready var completion_revenue_contribution_label: Label = $Explanation/CompletionRevenueContributionLabel
@onready var primary_button: Button = $PrimaryButton

var _session: GameSessionType
var _view_model: DashboardViewModelType


func _ready() -> void:
	primary_button.pressed.connect(_on_primary_button_pressed)


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
	primary_button.text = view_model.get_action_text()
	cash_explanation_label.text = view_model.get_cash_explanation_text()
	revenue_contribution_label.text = view_model.get_revenue_contributions_text()
	operating_cost_contribution_label.text = view_model.get_operating_cost_contributions_text()
	project_cost_contribution_label.text = view_model.get_project_cost_contributions_text()
	progress_contribution_label.text = view_model.get_progress_contributions_text()
	completion_revenue_contribution_label.text = view_model.get_completion_revenue_text()
