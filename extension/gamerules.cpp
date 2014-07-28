#include "extension.h"
#include "gamerules.h"

GameRulesManager g_GameRulesManager;

SH_DECL_MANUALHOOK5_void(CTFGameRules_SetWinningTeam, 0, 0, 0, int, int, bool, bool, bool);
SH_DECL_MANUALHOOK3_void(CTFGameRules_SetStalemate, 0, 0, 0, int, bool, bool);
SH_DECL_MANUALHOOK0(CTFGameRules_ShouldScorePerRound, 0, 0, 0, bool);
SH_DECL_MANUALHOOK0(CTFGameRules_CheckWinLimit, 0, 0, 0, bool);

bool GameRulesManager::TryEnable() {
	if (!m_hooksSetup) {
		int offset;

		if (!g_pGameConfig->GetOffset("CTFGameRules::SetWinningTeam", &offset)) {
			g_pSM->LogError(myself, "Failed to find CTFGameRules::SetWinningTeam offset");
			return false;
		}

		SH_MANUALHOOK_RECONFIGURE(CTFGameRules_SetWinningTeam, offset, 0, 0);

		if (!g_pGameConfig->GetOffset("CTFGameRules::SetStalemate", &offset)) {
			g_pSM->LogError(myself, "Failed to find CTFGameRules::SetStalemate offset");
			return false;
		}

		SH_MANUALHOOK_RECONFIGURE(CTFGameRules_SetStalemate, offset, 0, 0);

		if (!g_pGameConfig->GetOffset("CTFGameRules::ShouldScorePerRound", &offset)) {
			g_pSM->LogError(myself, "Failed to find CTFGameRules::ShouldScorePerRound offset");
			return false;
		}

		SH_MANUALHOOK_RECONFIGURE(CTFGameRules_ShouldScorePerRound, offset, 0, 0);

		if (!g_pGameConfig->GetOffset("CTFGameRules::CheckWinLimit", &offset)) {
			g_pSM->LogError(myself, "Failed to find CTFGameRules::CheckWinLimit offset");
			return false;
		}

		SH_MANUALHOOK_RECONFIGURE(CTFGameRules_CheckWinLimit, offset, 0, 0);

		m_hooksSetup = true;
	}

	for (int i = 0; i < MAX_EDICTS; ++i) {
		CBaseEntity *pEntity = gamehelpers->ReferenceToEntity(i);
		if (!pEntity) {
			continue;
		}

		const char *classname = gamehelpers->GetEntityClassname(pEntity);

		OnEntityCreated(pEntity, classname);
	}

	return true;
}

void GameRulesManager::Disable() {

}

void GameRulesManager::OnEntityCreated(CBaseEntity *pEntity, const char *classname) {
	if (V_strcmp(classname, "CTFGameRules") == 0) {
		CBaseEntity *oldTFGameRules = gamehelpers->ReferenceToEntity(m_TFGameRules);

		if (oldTFGameRules) {
			RemoveHooks(oldTFGameRules);
		}

		m_TFGameRules = gamehelpers->EntityToReference(pEntity);

		AddHooks(pEntity);
	}
}

void GameRulesManager::OnEntityDestroyed(CBaseEntity *pEntity) {
	if (gamehelpers->EntityToReference(pEntity) == m_TFGameRules) {
		RemoveHooks(pEntity);
	}

	m_TFGameRules = 0xFFFFFFFF;
}

bool GameRulesManager::Call_CTFGameRules_SetWinningTeam(int team, int iWinReason, bool bForceMapReset, bool bSwitchTeams, bool bDontAddScore) {
	CBaseEntity *tfGameRules = gamehelpers->ReferenceToEntity(m_TFGameRules);

	if (tfGameRules) {
		SH_MCALL(tfGameRules, CTFGameRules_SetWinningTeam)(team, iWinReason, bForceMapReset, bSwitchTeams, bDontAddScore);
		return true;
	}
	else {
		return false;
	}
}

bool GameRulesManager::Call_CTFGameRules_SetStalemate(int iReason, bool bForceMapReset, bool bSwitchTeams) {
	CBaseEntity *tfGameRules = gamehelpers->ReferenceToEntity(m_TFGameRules);

	if (tfGameRules) {
		SH_MCALL(tfGameRules, CTFGameRules_SetStalemate)(iReason, bForceMapReset, bSwitchTeams);
		return true;
	}
	else {
		return false;
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

	if (result > Pl_Continue) {
		RETURN_META_MNEWPARAMS(MRES_HANDLED, CTFGameRules_SetWinningTeam, (team, iWinReason, forceMapReset == 1, switchTeams == 1, dontAddScore == 1));
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

	if (result > Pl_Continue) {
		RETURN_META_MNEWPARAMS(MRES_HANDLED, CTFGameRules_SetStalemate, (iReason, forceMapReset == 1, switchTeams == 1));
	}
	else {
		RETURN_META(MRES_IGNORED);
	}
}

bool GameRulesManager::Hook_CTFGameRules_ShouldScorePerRound() {
	cell_t returnValue = 0;

	g_ShouldScoreByRoundForward->PushCellByRef(&returnValue);

	cell_t result = 0;

	g_ShouldScoreByRoundForward->Execute(&result);

	if (result > Pl_Continue) {
		RETURN_META_VALUE(MRES_SUPERCEDE, returnValue == 1);
	}
	else {
		RETURN_META_VALUE(MRES_IGNORED, false);
	}
}

bool GameRulesManager::Hook_CTFGameRules_CheckWinLimit() {
	cell_t returnValue = 0;

	g_CheckWinLimitForward->PushCellByRef(&returnValue);

	cell_t result = 0;

	g_CheckWinLimitForward->Execute(&result);

	if (result > Pl_Continue) {
		RETURN_META_VALUE(MRES_SUPERCEDE, returnValue == 1);
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
	bool bForceMapReset = (params[3] == 1);
	bool bSwitchTeams = (params[4] == 1);
	bool bDontAddScore = (params[5] == 1);

	if (!g_GameRulesManager.Call_CTFGameRules_SetWinningTeam(team, iWinReason, bForceMapReset, bSwitchTeams, bDontAddScore)) {
		pContext->ThrowNativeError("Unable to call CTFGameRules::SetWinningTeam!");
	}

	return 0;
}

cell_t CompCtrl_SetStalemate(IPluginContext *pContext, const cell_t *params) {
	int iReason = params[1];
	bool bForceMapReset = (params[2] == 1);
	bool bSwitchTeams = (params[3] == 1);

	if (!g_GameRulesManager.Call_CTFGameRules_SetStalemate(iReason, bForceMapReset, bSwitchTeams)) {
		pContext->ThrowNativeError("Unable to call CTFGameRules::SetStalemate!");
	}

	return 0;
}