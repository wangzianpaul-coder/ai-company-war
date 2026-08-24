class_name OpponentPlanningSnapshot
extends RefCounted


## Public quarter-boundary values visible to an opponent planner.
## The snapshot deliberately contains exactly these three primitive fields.
var _elapsed_months: int
var _consumer_player_share_bps: int
var _developer_api_player_share_bps: int


func _init(
	p_elapsed_months: int,
	p_consumer_player_share_bps: int,
	p_developer_api_player_share_bps: int
) -> void:
	_elapsed_months = p_elapsed_months
	_consumer_player_share_bps = p_consumer_player_share_bps
	_developer_api_player_share_bps = p_developer_api_player_share_bps


func copy():
	return new(
		_elapsed_months,
		_consumer_player_share_bps,
		_developer_api_player_share_bps
	)


func get_elapsed_months() -> int:
	return _elapsed_months


func get_consumer_player_share_bps() -> int:
	return _consumer_player_share_bps


func get_developer_api_player_share_bps() -> int:
	return _developer_api_player_share_bps
