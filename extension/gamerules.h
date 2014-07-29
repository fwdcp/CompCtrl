#ifndef _INCLUDE_COMPCTRL_GAMERULES_H_
#define _INCLUDE_COMPCTRL_GAMERULES_H_

#include "extension.h"
#include "ISDKHooks.h"

class GameRulesManager : public ISMEntityListener
{
	// management
public:
	void Enable();
	void Disable();

	// natives
public:
	void Call_CTFGameRules_SetWinningTeam(int team, int iWinReason, bool bForceMapReset = true, bool bSwitchTeams = false, bool bDontAddScore = false);
	void Call_CTFGameRules_SetStalemate(int iReason, bool bForceMapReset = true, bool bSwitchTeams = false);

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
	int m_setWinningTeamHook;
	int m_setStalemateHook;
};

cell_t CompCtrl_SetWinningTeam(IPluginContext *pContext, const cell_t *params);
cell_t CompCtrl_SetStalemate(IPluginContext *pContext, const cell_t *params);

extern GameRulesManager g_GameRulesManager;

#endif //_INCLUDE_COMPCTRL_GAMERULES_H_