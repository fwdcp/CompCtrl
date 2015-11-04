#ifndef _INCLUDE_COMPCTRL_H_
#define _INCLUDE_COMPCTRL_H_

#include "smsdk_ext.h"
#include "ISDKHooks.h"
#include "ISDKTools.h"

#include "gamerules.h"
#include "team.h"

class CompCtrl : public SDKExtension
{
public:
	virtual bool SDK_OnLoad(char *error, size_t maxlength, bool late);
	virtual void SDK_OnUnload();
	virtual void SDK_OnAllLoaded();
	//virtual void SDK_OnPauseChange(bool paused);
	virtual bool QueryRunning(char *error, size_t maxlength);
public:
#if defined SMEXT_CONF_METAMOD
	virtual bool SDK_OnMetamodLoad(ISmmAPI *ismm, char *error, size_t maxlength, bool late);
	virtual bool SDK_OnMetamodUnload(char *error, size_t maxlength);
	//virtual bool SDK_OnMetamodPauseChange(bool paused, char *error, size_t maxlength);
#endif
public:
	bool OnLevelInit(const char *pMapName, char const *pMapEntities, char const *pOldLevel, char const *pLandmarkName, bool loadGame, bool background);
};

extern IGameConfig *g_pGameConfig;
extern ISDKHooks *g_pSDKHooks;
extern ISDKTools *g_pSDKTools;

const sp_nativeinfo_t g_Natives[] =
{
	{ "CompCtrl_SetWinningTeam", CompCtrl_SetWinningTeam },
	{ "CompCtrl_SetStalemate", CompCtrl_SetStalemate },
	{ "CompCtrl_SwitchTeams", CompCtrl_SwitchTeams },
	{ NULL, NULL }
};

extern IForward *g_SetWinningTeamForward;
extern IForward *g_SetStalemateForward;
extern IForward *g_SwitchTeamsForward;
extern IForward *g_BetweenRoundsStartForward;
extern IForward *g_BetweenRoundsEndForward;
extern IForward *g_BetweenRoundsThinkForward;
extern IForward *g_RestartTournamentForward;
extern IForward *g_CheckWinLimitForward;
extern IForward *g_ResetTeamScoresForward;

#endif // _INCLUDE_COMPCTRL_H_
