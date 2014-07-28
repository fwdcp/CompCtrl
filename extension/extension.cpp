#include "extension.h"

CompCtrl g_CompCtrl;		/**< Global singleton for extension's main interface */

SMEXT_LINK(&g_CompCtrl);

IGameConfig *g_pGameConfig = nullptr;
ISDKHooks *g_pSDKHooks = nullptr;

bool CompCtrl::SDK_OnLoad(char *error, size_t maxlength, bool late) {
	sharesys->AddDependency(myself, "sdkhooks.ext", true, true);

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
}

bool CompCtrl::QueryRunning(char *error, size_t maxlength) {
	SM_CHECK_IFACE(SDKHOOKS, g_pSDKHooks);
	return true;
}