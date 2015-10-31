#ifndef _INCLUDE_COMPCTRL_GAMERULES_H_
#define _INCLUDE_COMPCTRL_GAMERULES_H_

#include "extension.h"

class GameRulesManager
{
	// management
public:
	void Enable();
	void Disable();
	bool IsRunning() { return m_hooksSetup && m_hooksEnabled; }

	// calls
public:
	void Call_CTFGameRules_SetWinningTeam(int team, int iWinReason, bool bForceMapReset = true, bool bSwitchTeams = false, bool bDontAddScore = false, bool bFinal = false);
	void Call_CTFGameRules_SetStalemate(int iReason, bool bForceMapReset = true, bool bSwitchTeams = false);
	void Call_CTFGameRules_HandleSwitchTeams();

	// hooks
public:
	void Hook_CTFGameRules_SetWinningTeam(int team, int iWinReason, bool bForceMapReset = true, bool bSwitchTeams = false, bool bDontAddScore = false, bool bFinal = false);
	void Hook_CTFGameRules_SetStalemate(int iReason, bool bForceMapReset = true, bool bSwitchTeams = false);
	void Hook_CTFGameRules_HandleSwitchTeams();
	void Hook_CTFGameRules_RestartTournament();
	bool Hook_CTFGameRules_CheckWinLimit(bool bAllowEnd = true);

private:
	bool m_hooksSetup;
	bool m_hooksEnabled;
	int m_setWinningTeamHook;
	int m_setStalemateHook;
	int m_handleSwitchTeamsHook;
	int m_restartTournamentHook;
	int m_checkWinLimitHook;
};

cell_t CompCtrl_SetWinningTeam(IPluginContext *pContext, const cell_t *params);
cell_t CompCtrl_SetStalemate(IPluginContext *pContext, const cell_t *params);
cell_t CompCtrl_SwitchTeams(IPluginContext *pContext, const cell_t *params);

extern GameRulesManager g_GameRulesManager;

#endif //_INCLUDE_COMPCTRL_GAMERULES_H_
