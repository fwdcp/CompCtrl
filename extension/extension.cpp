#include "extension.h"

CompCtrl g_CompCtrl;		/**< Global singleton for extension's main interface */

SMEXT_LINK(&g_CompCtrl);

ISDKHooks *g_pSDKHooks = NULL;

bool CompCtrl::SDK_OnLoad(char *error, size_t maxlength, bool late)
{
	sharesys->AddDependency(myself, "sdkhooks.ext", true, true);
	return true;
}

void CompCtrl::SDK_OnAllLoaded()
{
	SM_GET_LATE_IFACE(SDKHOOKS, g_pSDKHooks);
}

bool CompCtrl::QueryRunning(char *error, size_t maxlength)
{
	SM_CHECK_IFACE(SDKHOOKS, g_pSDKHooks);
	return true;
}