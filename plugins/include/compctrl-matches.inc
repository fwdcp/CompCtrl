enum EndCondition {
	EndCondition_None = 0,
	EndCondition_TimeLimit,
	EndCondition_WinLimit,
	EndCondition_WinDifference,
	EndCondition_MaxRounds
};

enum StopwatchStatus {
	StopwatchStatus_Unknown = 0,
	StopwatchStatus_SetTarget,
	StopwatchStatus_ChaseTarget
};