#include "extension.h"
#include "gamerules.h"

GameRulesManager g_GameRulesManager;

SH_DECL_MANUALHOOK5_void(CTFGameRules_SetWinningTeam, 0, 0, 0, int, int, bool, bool, bool);
SH_DECL_MANUALHOOK3_void(CTFGameRules_SetStalemate, 0, 0, 0, int, bool, bool);
SH_DECL_MANUALHOOK0(CTFGameRules_ShouldScorePerRound, 0, 0, 0, bool);
SH_DECL_MANUALHOOK0(CTFGameRules_CheckWinLimit, 0, 0, 0, bool);

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

		if (!g_pGameConfig->GetOffset("CTFGameRules::ShouldScorePerRound", &offset)) {
			g_pSM->LogError(myself, "Failed to find CTFGameRules::ShouldScorePerRound offset");
			return;
		}

		SH_MANUALHOOK_RECONFIGURE(CTFGameRules_ShouldScorePerRound, offset, 0, 0);

		if (!g_pGameConfig->GetOffset("CTFGameRules::CheckWinLimit", &offset)) {
			g_pSM->LogError(myself, "Failed to find CTFGameRules::CheckWinLimit offset");
			return;
		}

		SH_MANUALHOOK_RECONFIGURE(CTFGameRules_CheckWinLimit, offset, 0, 0);

		if (!g_pSDKTools->GetGameRules()) {
			return;
		}

		m_setWinningTeamHook = SH_ADD_MANUALDVPHOOK(CTFGameRules_SetWinningTeam, g_pSDKTools->GetGameRules(), SH_MEMBER(this, &GameRulesManager::Hook_CTFGameRules_SetWinningTeam), false);
		m_setStalemateHook = SH_ADD_MANUALDVPHOOK(CTFGameRules_SetStalemate, g_pSDKTools->GetGameRules(), SH_MEMBER(this, &GameRulesManager::Hook_CTFGameRules_SetStalemate), false);

		m_hooksSetup = true;
	}
}

void GameRulesManager::Disable() {
	if (m_hooksSetup) {
		SH_REMOVE_HOOK_ID(m_setWinningTeamHook);
		SH_REMOVE_HOOK_ID(m_setStalemateHook);

		m_hooksSetup = false;
	}
}

void GameRulesManager::Call_CTFGameRules_SetWinningTeam(int team, int iWinReason, bool bForceMapReset, bool bSwitchTeams, bool bDontAddScore) {
	if (g_pSDKTools->GetGameRules()) {
		SH_MCALL(g_pSDKTools->GetGameRules(), CTFGameRules_SetWinningTeam)(team, iWinReason, bForceMapReset, bSwitchTeams, bDontAddScore);
	}
}

void GameRulesManager::Call_CTFGameRules_SetStalemate(int iReason, bool bForceMapReset, bool bSwitchTeams) {
	if (g_pSDKTools->GetGameRules()) {
		SH_MCALL(g_pSDKTools->GetGameRules(), CTFGameRules_SetStalemate)(iReason, bForceMapReset, bSwitchTeams);
	}
}

void GameRulesManager::Hook_CTFGameRules_SetWinningTeam(int team, int iWinReason, bool bForceMapReset, bool bSwitchTeams, bool bDontAddScore) {
	cell_t forceMapReset = bForceMapReset ? 1 : 0;
	cell_t switchTeams = bSwitchTeams ? 1 : 0;
	cell_t dontAddScore = bDontAddScore ? 1 : 0;

	g_SetWinningTeamForward->PushCellByRef(&team);
	g_SetWinningTeamForward->PushCellByRef(&iWinReason);
	g_SetWinningTeamForward->PushCellByRef(&forceMapReset);
	g_SetWinningTeamForward->PushCellByRef(&switchTeams);
	g_SetWinningTeamForward->PushCellByRef(&dontAddScore);

	cell_t result = 0;

	g_SetWinningTeamForward->Execute(&result);

	if (result > Pl_Changed) {
		RETURN_META(MRES_SUPERCEDE);
	}
	else if (result == Pl_Changed) {
		RETURN_META_MNEWPARAMS(MRES_HANDLED, CTFGameRules_SetWinningTeam, (team, iWinReason, forceMapReset != 0, switchTeams != 0, dontAddScore != 0));
	}
	else {
		RETURN_META(MRES_IGNORED);
	}
}

void GameRulesManager::Hook_CTFGameRules_SetStalemate(int iReason, bool bForceMapReset, bool bSwitchTeams) {
	cell_t forceMapReset = bForceMapReset ? 1 : 0;
	cell_t switchTeams = bSwitchTeams ? 1 : 0;

	g_SetWinningTeamForward->PushCellByRef(&iReason);
	g_SetWinningTeamForward->PushCellByRef(&forceMapReset);
	g_SetWinningTeamForward->PushCellByRef(&switchTeams);

	cell_t result = 0;

	g_SetStalemateForward->Execute(&result);

	if (result > Pl_Changed) {
		RETURN_META(MRES_SUPERCEDE);
	}
	else if (result == Pl_Changed) {
		RETURN_META_MNEWPARAMS(MRES_HANDLED, CTFGameRules_SetStalemate, (iReason, forceMapReset != 0, switchTeams != 0));
	}
	else {
		RETURN_META(MRES_IGNORED);
	}
}

bool GameRulesManager::Hook_CTFGameRules_ShouldScorePerRound() {
	cell_t returnValue = SH_MCALL(META_IFACEPTR(CBaseEntity), CTFGameRules_ShouldScorePerRound)() ? 1 : 0;

	g_ShouldScoreByRoundForward->PushCellByRef(&returnValue);

	cell_t result = 0;

	g_ShouldScoreByRoundForward->Execute(&result);

	if (result > Pl_Continue) {
		RETURN_META_VALUE(MRES_SUPERCEDE, returnValue != 0);
	}
	else {
		RETURN_META_VALUE(MRES_IGNORED, false);
	}
}

bool GameRulesManager::Hook_CTFGameRules_CheckWinLimit() {
	cell_t returnValue = SH_MCALL(META_IFACEPTR(CBaseEntity), CTFGameRules_CheckWinLimit)() ? 1 : 0;

	g_CheckWinLimitForward->PushCellByRef(&returnValue);

	cell_t result = 0;

	g_CheckWinLimitForward->Execute(&result);

	if (result > Pl_Continue) {
		RETURN_META_VALUE(MRES_SUPERCEDE, returnValue != 0);
	}
	else {
		RETURN_META_VALUE(MRES_IGNORED, false);
	}
}

void GameRulesManager::AddHooks(CBaseEntity *pEntity) {
	SH_ADD_MANUALHOOK(CTFGameRules_SetWinningTeam, pEntity, SH_MEMBER(&g_GameRulesManager, &GameRulesManager::Hook_CTFGameRules_SetWinningTeam), false);
	SH_ADD_MANUALHOOK(CTFGameRules_SetStalemate, pEntity, SH_MEMBER(&g_GameRulesManager, &GameRulesManager::Hook_CTFGameRules_SetStalemate), false);
	SH_ADD_MANUALHOOK(CTFGameRules_ShouldScorePerRound, pEntity, SH_MEMBER(&g_GameRulesManager, &GameRulesManager::Hook_CTFGameRules_ShouldScorePerRound), false);
	SH_ADD_MANUALHOOK(CTFGameRules_CheckWinLimit, pEntity, SH_MEMBER(&g_GameRulesManager, &GameRulesManager::Hook_CTFGameRules_CheckWinLimit), false);
}

void GameRulesManager::RemoveHooks(CBaseEntity *pEntity) {
	SH_REMOVE_MANUALHOOK(CTFGameRules_SetWinningTeam, pEntity, SH_MEMBER(&g_GameRulesManager, &GameRulesManager::Hook_CTFGameRules_SetWinningTeam), false);
	SH_REMOVE_MANUALHOOK(CTFGameRules_SetStalemate, pEntity, SH_MEMBER(&g_GameRulesManager, &GameRulesManager::Hook_CTFGameRules_SetStalemate), false);
	SH_REMOVE_MANUALHOOK(CTFGameRules_ShouldScorePerRound, pEntity, SH_MEMBER(&g_GameRulesManager, &GameRulesManager::Hook_CTFGameRules_ShouldScorePerRound), false);
	SH_REMOVE_MANUALHOOK(CTFGameRules_CheckWinLimit, pEntity, SH_MEMBER(&g_GameRulesManager, &GameRulesManager::Hook_CTFGameRules_CheckWinLimit), false);
}

cell_t CompCtrl_SetWinningTeam(IPluginContext *pContext, const cell_t *params) {
	int team = params[1];
	int iWinReason = params[2];
	bool bForceMapReset = (params[3] != 0);
	bool bSwitchTeams = (params[4] != 0);
	bool bDontAddScore = (params[5] != 0);

	if (!g_pSDKTools->GetGameRules()) {
		pContext->ThrowNativeError("Could not get pointer to CTFGameRules!");
	}

	g_GameRulesManager.Call_CTFGameRules_SetWinningTeam(team, iWinReason, bForceMapReset, bSwitchTeams, bDontAddScore);

	return 0;
}

cell_t CompCtrl_SetStalemate(IPluginContext *pContext, const cell_t *params) {
	int iReason = params[1];
	bool bForceMapReset = (params[2] != 0);
	bool bSwitchTeams = (params[3] != 0);

	if (!g_pSDKTools->GetGameRules()) {
		pContext->ThrowNativeError("Could not get pointer to CTFGameRules!");
	}

	g_GameRulesManager.Call_CTFGameRules_SetStalemate(iReason, bForceMapReset, bSwitchTeams);

	return 0;
}