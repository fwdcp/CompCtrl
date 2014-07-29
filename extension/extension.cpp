#include "extension.h"

CompCtrl g_CompCtrl;		/**< Global singleton for extension's main interface */

SMEXT_LINK(&g_CompCtrl);

IGameConfig *g_pGameConfig = NULL;
ISDKHooks *g_pSDKHooks = NULL;
ISDKTools *g_pSDKTools = NULL;

IForward *g_SetWinningTeamForward = NULL;
IForward *g_SetStalemateForward = NULL;
IForward *g_ShouldScoreByRoundForward = NULL;
IForward *g_CheckWinLimitForward = NULL;

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

void CompCtrl::SDK_OnAllLoaded() {
	SM_GET_LATE_IFACE(SDKHOOKS, g_pSDKHooks);
	SM_GET_LATE_IFACE(SDKTOOLS, g_pSDKTools);

	if (QueryRunning(NULL, 0))
	{
		sharesys->AddNatives(myself, g_Natives);

		g_SetWinningTeamForward = forwards->CreateForward("CompCtrl_OnSetWinningTeam", ET_Hook, 5, NULL, Param_CellByRef, Param_CellByRef, Param_CellByRef, Param_CellByRef, Param_CellByRef);
		g_SetStalemateForward = forwards->CreateForward("CompCtrl_OnSetStalemate", ET_Hook, 3, NULL, Param_CellByRef, Param_CellByRef, Param_CellByRef);
		g_ShouldScoreByRoundForward = forwards->CreateForward("CompCtrl_OnShouldScorePerRound", ET_Hook, 1, NULL, Param_CellByRef);
		g_CheckWinLimitForward = forwards->CreateForward("CompCtrl_OnCheckWinLimit", ET_Hook, 1, NULL, Param_CellByRef);
	}
}

bool CompCtrl::QueryRunning(char *error, size_t maxlength) {
	SM_CHECK_IFACE(SDKHOOKS, g_pSDKHooks);
	SM_CHECK_IFACE(SDKTOOLS, g_pSDKTools);
	return true;
}