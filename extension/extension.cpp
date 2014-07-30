#include "extension.h"

CompCtrl g_CompCtrl;		/**< Global singleton for extension's main interface */

SMEXT_LINK(&g_CompCtrl);

SH_DECL_HOOK6(IServerGameDLL, LevelInit, SH_NOATTRIB, false, bool, const char *, const char *, const char *, const char *, bool, bool);

IGameConfig *g_pGameConfig = NULL;
ISDKHooks *g_pSDKHooks = NULL;
ISDKTools *g_pSDKTools = NULL;

IForward *g_SetWinningTeamForward = NULL;
IForward *g_SetStalemateForward = NULL;
IForward *g_CheckWinLimitForward = NULL;
IForward *g_RestartTournamentForward = NULL;
IForward *g_ResetTeamScoresForward = NULL;

bool CompCtrl::SDK_OnLoad(char *error, size_t maxlength, bool late) {
	sharesys->AddDependency(myself, "sdkhooks.ext", true, true);
	sharesys->AddDependency(myself, "sdktools.ext", true, true);

	char *gameConfigError = new char[255];
	if (!gameconfs->LoadGameConfigFile("compctrl", &g_pGameConfig, gameConfigError, sizeof(gameConfigError)))
	{
		if (gameConfigError[0])
		{
			V_snprintf(error, maxlength, "Could not read compctrl.txt: %s", gameConfigError);
		}
		return false;
	}

	return true;
}

void CompCtrl::SDK_OnUnload() {
	g_GameRulesManager.Disable();
}

void CompCtrl::SDK_OnAllLoaded() {
	SM_GET_LATE_IFACE(SDKHOOKS, g_pSDKHooks);
	SM_GET_LATE_IFACE(SDKTOOLS, g_pSDKTools);

	if (QueryRunning(NULL, 0))
	{
		sharesys->AddNatives(myself, g_Natives);

		g_SetWinningTeamForward = forwards->CreateForward("CompCtrl_OnSetWinningTeam", ET_Hook, 5, NULL, Param_CellByRef, Param_CellByRef, Param_CellByRef, Param_CellByRef, Param_CellByRef);
		g_SetStalemateForward = forwards->CreateForward("CompCtrl_OnSetStalemate", ET_Hook, 3, NULL, Param_CellByRef, Param_CellByRef, Param_CellByRef);
		g_CheckWinLimitForward = forwards->CreateForward("CompCtrl_OnCheckWinLimit", ET_Hook, 1, NULL, Param_CellByRef);
		g_RestartTournamentForward = forwards->CreateForward("CompCtrl_OnRestartTournament", ET_Hook, 0, NULL);
		g_ResetTeamScoresForward = forwards->CreateForward("CompCtrl_OnResetTeamScores", ET_Hook, 1, NULL, Param_Cell);
	}
}

bool CompCtrl::QueryRunning(char *error, size_t maxlength) {
	SM_CHECK_IFACE(SDKHOOKS, g_pSDKHooks);
	SM_CHECK_IFACE(SDKTOOLS, g_pSDKTools);
	return true;
}

bool CompCtrl::SDK_OnMetamodLoad(ISmmAPI *ismm, char *error, size_t maxlength, bool late) {
	SH_ADD_HOOK(IServerGameDLL, LevelInit, gamedll, SH_MEMBER(this, &CompCtrl::OnLevelInit), true);

	return true;
}

bool CompCtrl::SDK_OnMetamodUnload(char *error, size_t maxlength) {
	SH_REMOVE_HOOK(IServerGameDLL, LevelInit, gamedll, SH_MEMBER(this, &CompCtrl::OnLevelInit), true);

	return true;
}

bool CompCtrl::OnLevelInit(const char *pMapName, char const *pMapEntities, char const *pOldLevel, char const *pLandmarkName, bool loadGame, bool background) {
	if (!g_GameRulesManager.IsRunning()) {
		g_GameRulesManager.Enable();
	}

	RETURN_META_VALUE(MRES_IGNORED, true);
}