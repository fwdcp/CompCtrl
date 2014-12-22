#ifndef _INCLUDE_COMPCTRL_ENGINE_H_
#define _INCLUDE_COMPCTRL_ENGINE_H_

#include "extension.h"
#include "eiface.h"

class EngineManager
{
	// management
public:
	void Enable();
	void Disable();
	bool IsRunning() { return m_hooksSetup && m_hooksEnabled; }

	// calls
public:
	void Call_IVEngineServer_ChangeLevel(const char *s1, const char *s2);

	// hooks
public:
	void Hook_IVEngineServer_ChangeLevel(const char *s1, const char *s2);

private:
	bool m_hooksSetup;
	bool m_hooksEnabled;
	int m_changeLevelHook;
};

cell_t CompCtrl_ChangeLevel(IPluginContext *pContext, const cell_t *params);

extern EngineManager g_EngineManager;

#endif //_INCLUDE_COMPCTRL_ENGINE_H_