#include "extension.h"
#include "engine.h"

EngineManager g_EngineManager;

SH_DECL_HOOK2_void(IVEngineServer, ChangeLevel, SH_NOATTRIB, 0, const char *, const char *);

void EngineManager::Enable() {
	if (!m_hooksSetup) {
		m_hooksSetup = true;
	}

	if (!m_hooksEnabled) {
		if (!engine) {
			return;
		}

		m_changeLevelHook = SH_ADD_HOOK(IVEngineServer, ChangeLevel, engine, SH_MEMBER(this, &EngineManager::Hook_IVEngineServer_ChangeLevel), false);

		m_hooksEnabled = true;
	}
}

void EngineManager::Disable() {
	if (m_hooksEnabled) {
		SH_REMOVE_HOOK_ID(m_changeLevelHook);

		m_hooksEnabled = false;
	}
}

void EngineManager::Call_IVEngineServer_ChangeLevel(const char *s1, const char *s2) {
	if (engine) {
		SH_CALL(engine, &IVEngineServer::ChangeLevel)(s1, s2);
	}
}

void EngineManager::Hook_IVEngineServer_ChangeLevel(const char *s1, const char *s2) {
	g_ChangeLevelForward->PushString(s1);
	g_ChangeLevelForward->PushString(s2);

	cell_t result = 0;

	g_ChangeLevelForward->Execute(&result);

	if (result > Pl_Continue) {
		RETURN_META(MRES_SUPERCEDE);
	}
	else {
		RETURN_META(MRES_IGNORED);
	}
}

cell_t CompCtrl_ChangeLevel(IPluginContext *pContext, const cell_t *params) {
	char *s1;
	char *s2;

	pContext->LocalToString(params[1], &s1);
	pContext->LocalToString(params[2], &s2);

	if (!engine) {
		pContext->ThrowNativeError("Could not get pointer to IVEngineServer!");
	}

	g_EngineManager.Call_IVEngineServer_ChangeLevel(s1, s2);

	return 0;
}