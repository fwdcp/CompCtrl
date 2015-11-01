#include "extension.h"
#include "gamerules.h"

GameRulesManager g_GameRulesManager;

SH_DECL_MANUALHOOK6_void(CTFGameRules_SetWinningTeam, 0, 0, 0, int, int, bool, bool, bool, bool);
SH_DECL_MANUALHOOK3_void(CTFGameRules_SetStalemate, 0, 0, 0, int, bool, bool);
SH_DECL_MANUALHOOK0_void(CTFGameRules_HandleSwitchTeams, 0, 0, 0);
SH_DECL_MANUALHOOK0_void(CTFGameRules_RestartTournament, 0, 0, 0);
SH_DECL_MANUALHOOK1(CTFGameRules_CheckWinLimit, 0, 0, 0, bool, bool);

void GameRulesManager::Enable() {
	if (!m_hooksSetup) {
		int offset;

		if (!g_pGameConfig->GetOffset("CTFGameRules::SetWinningTeam", &offset)) {
			g_pSM->LogError(myself, "Failed to find CTFGameRules::SetWinningTeam offset");
			return;
		}

		SH_MANUALHOOK_RECONFIGURE(CTFGameRules_SetWinningTeam, offset, 0, 0);

		if (!g_pGameConfig->GetOffset("CTFGameRules::SetStalemate", &offset)) {
			g_pSM->LogError(myself, "Failed to find CTFGameRules::SetStalemate offset");
			return;
		}

		SH_MANUALHOOK_RECONFIGURE(CTFGameRules_SetStalemate, offset, 0, 0);

		if (!g_pGameConfig->GetOffset("CTFGameRules::HandleSwitchTeams", &offset)) {
			g_pSM->LogError(myself, "Failed to find CTFGameRules::HandleSwitchTeams offset");
			return;
		}

		SH_MANUALHOOK_RECONFIGURE(CTFGameRules_HandleSwitchTeams, offset, 0, 0);

		if (!g_pGameConfig->GetOffset("CTFGameRules::RestartTournament", &offset)) {
			g_pSM->LogError(myself, "Failed to find CTFGameRules::RestartTournament offset");
			return;
		}

		SH_MANUALHOOK_RECONFIGURE(CTFGameRules_RestartTournament, offset, 0, 0);

		if (!g_pGameConfig->GetOffset("CTFGameRules::CheckWinLimit", &offset)) {
			g_pSM->LogError(myself, "Failed to find CTFGameRules::CheckWinLimit offset");
			return;
		}

		SH_MANUALHOOK_RECONFIGURE(CTFGameRules_CheckWinLimit, offset, 0, 0);

		m_hooksSetup = true;
	}

	if (!m_hooksEnabled) {
		if (!g_pSDKTools->GetGameRules()) {
			return;
		}

		m_setWinningTeamHook = SH_ADD_MANUALVPHOOK(CTFGameRules_SetWinningTeam, g_pSDKTools->GetGameRules(), SH_MEMBER(this, &GameRulesManager::Hook_CTFGameRules_SetWinningTeam), false);
		m_setStalemateHook = SH_ADD_MANUALVPHOOK(CTFGameRules_SetStalemate, g_pSDKTools->GetGameRules(), SH_MEMBER(this, &GameRulesManager::Hook_CTFGameRules_SetStalemate), false);
		m_handleSwitchTeamsHook = SH_ADD_MANUALVPHOOK(CTFGameRules_HandleSwitchTeams, g_pSDKTools->GetGameRules(), SH_MEMBER(this, &GameRulesManager::Hook_CTFGameRules_HandleSwitchTeams), false);
		m_restartTournamentHook = SH_ADD_MANUALVPHOOK(CTFGameRules_RestartTournament, g_pSDKTools->GetGameRules(), SH_MEMBER(this, &GameRulesManager::Hook_CTFGameRules_RestartTournament), false);
		m_checkWinLimitHook = SH_ADD_MANUALVPHOOK(CTFGameRules_CheckWinLimit, g_pSDKTools->GetGameRules(), SH_MEMBER(this, &GameRulesManager::Hook_CTFGameRules_CheckWinLimit), false);

		m_hooksEnabled = true;
	}
}

void GameRulesManager::Disable() {
	if (m_hooksEnabled) {
		SH_REMOVE_HOOK_ID(m_setWinningTeamHook);
		SH_REMOVE_HOOK_ID(m_setStalemateHook);
		SH_REMOVE_HOOK_ID(m_handleSwitchTeamsHook);
		SH_REMOVE_HOOK_ID(m_restartTournamentHook);
		SH_REMOVE_HOOK_ID(m_checkWinLimitHook);

		m_hooksEnabled = false;
	}
}

void GameRulesManager::Call_CTFGameRules_SetWinningTeam(int team, int iWinReason, bool bForceMapReset, bool bSwitchTeams, bool bDontAddScore, bool bFinal) {
	if (g_pSDKTools->GetGameRules()) {
		SH_MCALL(g_pSDKTools->GetGameRules(), CTFGameRules_SetWinningTeam)(team, iWinReason, bForceMapReset, bSwitchTeams, bDontAddScore, bFinal);
	}
}

void GameRulesManager::Call_CTFGameRules_SetStalemate(int iReason, bool bForceMapReset, bool bSwitchTeams) {
	if (g_pSDKTools->GetGameRules()) {
		SH_MCALL(g_pSDKTools->GetGameRules(), CTFGameRules_SetStalemate)(iReason, bForceMapReset, bSwitchTeams);
	}
}

void GameRulesManager::Call_CTFGameRules_HandleSwitchTeams() {
	if (g_pSDKTools->GetGameRules()) {
		SH_MCALL(g_pSDKTools->GetGameRules(), CTFGameRules_HandleSwitchTeams)();
	}
}

void GameRulesManager::Hook_CTFGameRules_SetWinningTeam(int team, int iWinReason, bool bForceMapReset, bool bSwitchTeams, bool bDontAddScore, bool bFinal) {
	cell_t teamCell = team;
	cell_t winReasonCell = iWinReason;
	cell_t forceMapResetCell = bForceMapReset;
	cell_t switchTeamsCell = bSwitchTeams;
	cell_t dontAddScoreCell = bDontAddScore;
	cell_t finalCell = bFinal;

	g_SetWinningTeamForward->PushCellByRef(&teamCell);
	g_SetWinningTeamForward->PushCellByRef(&winReasonCell);
	g_SetWinningTeamForward->PushCellByRef(&forceMapResetCell);
	g_SetWinningTeamForward->PushCellByRef(&switchTeamsCell);
	g_SetWinningTeamForward->PushCellByRef(&dontAddScoreCell);
	g_SetWinningTeamForward->PushCellByRef(&finalCell);

	cell_t result = 0;

	g_SetWinningTeamForward->Execute(&result);

	if (result > Pl_Changed) {
		RETURN_META(MRES_SUPERCEDE);
	}
	else if (result == Pl_Changed) {
		RETURN_META_MNEWPARAMS(MRES_HANDLED, CTFGameRules_SetWinningTeam, ((int)teamCell, (int)winReasonCell, (bool)forceMapResetCell, (bool)switchTeamsCell, (bool)dontAddScoreCell, (bool)finalCell));
	}
	else {
		RETURN_META(MRES_IGNORED);
	}
}

void GameRulesManager::Hook_CTFGameRules_SetStalemate(int iReason, bool bForceMapReset, bool bSwitchTeams) {
	cell_t reasonCell = iReason;
	cell_t forceMapResetCell = bForceMapReset;
	cell_t switchTeamsCell = bSwitchTeams;

	g_SetStalemateForward->PushCellByRef(&reasonCell);
	g_SetStalemateForward->PushCellByRef(&forceMapResetCell);
	g_SetStalemateForward->PushCellByRef(&switchTeamsCell);

	cell_t result = 0;

	g_SetStalemateForward->Execute(&result);

	if (result > Pl_Changed) {
		RETURN_META(MRES_SUPERCEDE);
	}
	else if (result == Pl_Changed) {
		RETURN_META_MNEWPARAMS(MRES_HANDLED, CTFGameRules_SetStalemate, ((int)reasonCell, (bool)forceMapResetCell, (bool)switchTeamsCell));
	}
	else {
		RETURN_META(MRES_IGNORED);
	}
}

void GameRulesManager::Hook_CTFGameRules_HandleSwitchTeams() {
	cell_t result = 0;

	g_SwitchTeamsForward->Execute(&result);

	if (result > Pl_Continue) {
		RETURN_META(MRES_SUPERCEDE);
	}
	else {
		RETURN_META(MRES_IGNORED);
	}
}

void GameRulesManager::Hook_CTFGameRules_RestartTournament() {
	cell_t result = 0;

	g_RestartTournamentForward->Execute(&result);

	if (result > Pl_Continue) {
		RETURN_META(MRES_SUPERCEDE);
	}
	else {
		RETURN_META(MRES_IGNORED);
	}
}

bool GameRulesManager::Hook_CTFGameRules_CheckWinLimit(bool bAllowEnd) {
	cell_t allowEndCell = bAllowEnd;
	cell_t returnValue = SH_MCALL(g_pSDKTools->GetGameRules(), CTFGameRules_CheckWinLimit)(false);

	g_CheckWinLimitForward->PushCellByRef(&allowEndCell);
	g_CheckWinLimitForward->PushCellByRef(&returnValue);

	cell_t result = 0;

	g_CheckWinLimitForward->Execute(&result);

	if (result > Pl_Continue) {
		RETURN_META_VALUE(MRES_SUPERCEDE, (bool)returnValue);
	}
	else {
		RETURN_META_VALUE(MRES_IGNORED, false);
	}
}

cell_t CompCtrl_SetWinningTeam(IPluginContext *pContext, const cell_t *params) {
	if (!g_pSDKTools->GetGameRules()) {
		return pContext->ThrowNativeError("Could not get pointer to CTFGameRules!");
	}

	int team = (int)params[1];
	int iWinReason = (int)params[2];
	bool bForceMapReset = (bool)params[3];
	bool bSwitchTeams = (bool)params[4];
	bool bDontAddScore = (bool)params[5];
	bool bFinal = (bool)params[6];

	g_GameRulesManager.Call_CTFGameRules_SetWinningTeam(team, iWinReason, bForceMapReset, bSwitchTeams, bDontAddScore, bFinal);

	return 0;
}

cell_t CompCtrl_SetStalemate(IPluginContext *pContext, const cell_t *params) {
	if (!g_pSDKTools->GetGameRules()) {
		return pContext->ThrowNativeError("Could not get pointer to CTFGameRules!");
	}

	int iReason = (int)params[1];
	bool bForceMapReset = (bool)params[2];
	bool bSwitchTeams = (bool)params[3];

	g_GameRulesManager.Call_CTFGameRules_SetStalemate(iReason, bForceMapReset, bSwitchTeams);

	return 0;
}

cell_t CompCtrl_SwitchTeams(IPluginContext *pContext, const cell_t *params) {
	if (!g_pSDKTools->GetGameRules()) {
		return pContext->ThrowNativeError("Could not get pointer to CTFGameRules!");
	}

	g_GameRulesManager.Call_CTFGameRules_HandleSwitchTeams();

	return 0;
}
