#ifndef _INCLUDE_COMPCTRL_GAMERULES_H_
#define _INCLUDE_COMPCTRL_GAMERULES_H_

#include "extension.h"
#include "ISDKHooks.h"

class GameRulesManager : public ISMEntityListener
{
public:
	GameRulesManager() : m_TFGameRules(0xFFFFFFFF) {}

	// management
public:
	bool TryEnable();
	void Disable();

	// ISMEntityListener
public:
	virtual void OnEntityCreated(CBaseEntity *pEntity, const char *classname);
	virtual void OnEntityDestroyed(CBaseEntity *pEntity);

	// natives
public:
	bool Call_CTFGameRules_SetWinningTeam(int team, int iWinReason, bool bForceMapReset = true, bool bSwitchTeams = false, bool bDontAddScore = false);
	bool Call_CTFGameRules_SetStalemate(int iReason, bool bForceMapReset = true, bool bSwitchTeams = false);

	// hooks
public:
	void Hook_CTFGameRules_SetWinningTeam(int team, int iWinReason, bool bForceMapReset = true, bool bSwitchTeams = false, bool bDontAddScore = false);
	void Hook_CTFGameRules_SetStalemate(int iReason, bool bForceMapReset = true, bool bSwitchTeams = false);
	bool Hook_CTFGameRules_ShouldScorePerRound();
	bool Hook_CTFGameRules_CheckWinLimit();

	// hook management
private:
	void AddHooks(CBaseEntity *pEntity);
	void RemoveHooks(CBaseEntity *pEntity);

private:
	bool m_hooksSetup;
	cell_t m_TFGameRules;
};

cell_t CompCtrl_SetWinningTeam(IPluginContext *pContext, const cell_t *params);
cell_t CompCtrl_SetStalemate(IPluginContext *pContext, const cell_t *params);

extern GameRulesManager g_GameRulesManager;

#endif //_INCLUDE_COMPCTRL_GAMERULES_H_