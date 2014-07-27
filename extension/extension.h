#ifndef _INCLUDE_COMPCTRL_H_
#define _INCLUDE_COMPCTRL_H_

#include "smsdk_ext.h"
#include "ISDKHooks.h"

class CompCtrl : public SDKExtension
{
public:
	virtual bool SDK_OnLoad(char *error, size_t maxlength, bool late);
	//virtual void SDK_OnUnload();
	virtual void SDK_OnAllLoaded();
	//virtual void SDK_OnPauseChange(bool paused);
	virtual bool QueryRunning(char *error, size_t maxlength);
public:
#if defined SMEXT_CONF_METAMOD
	//virtual bool SDK_OnMetamodLoad(ISmmAPI *ismm, char *error, size_t maxlength, bool late);
	//virtual bool SDK_OnMetamodUnload(char *error, size_t maxlength);
	//virtual bool SDK_OnMetamodPauseChange(bool paused, char *error, size_t maxlength);
#endif
};

extern ISDKHooks *g_pSDKHooks;

#endif // _INCLUDE_COMPCTRL_H_
