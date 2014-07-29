#ifndef _INCLUDE_COMPCTRL_TEAM_H_
#define _INCLUDE_COMPCTRL_TEAM_H_

#include "extension.h"

class TeamManager : public ISMEntityListener
{
	// management
public:
	void Enable();
	void Disable();
	bool IsRunning() { return m_hooksSetup; }

	// calls
public:
	int Call_CTFTeam_GetTeamNumber(CBaseEntity *pEntity);

	// hooks
public:
	void Hook_CTFTeam_ResetScores();

	// entity listening
public:
	virtual void OnEntityCreated(CBaseEntity *pEntity, const char *classname);

private:
	bool m_hooksSetup;
	bool m_hooksEnabled;
	int m_resetScoresHook;
};

extern TeamManager g_TeamManager;

#endif //_INCLUDE_COMPCTRL_TEAM_H_