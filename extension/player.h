#ifndef _INCLUDE_COMPCTRL_PLAYER_H_
#define _INCLUDE_COMPCTRL_PLAYER_H_

#include "extension.h"

class PlayerManager : public ISMEntityListener
{
	// management
public:
	void Enable();
	void Disable();
	bool IsRunning() { return m_hooksSetup; }

	// hooks
public:
	void Hook_CTFPlayer_ResetScores();

	// entity listening
public:
	virtual void OnEntityCreated(CBaseEntity *pEntity, const char *classname);

private:
	bool m_hooksSetup;
	bool m_hooksEnabled;
	int m_resetScoresHook;
};

extern PlayerManager g_PlayerManager;

#endif //_INCLUDE_COMPCTRL_PLAYER_H_
