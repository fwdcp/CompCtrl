#ifndef _INCLUDE_COMPCTRL_DEMORECORDER_H_
#define _INCLUDE_COMPCTRL_DEMORECORDER_H_

#include "extension.h"

#include "CDetour/detours.h"

// because detours.h includes extension.h, we have to forward-declare CDetour to avoid issues
class CDetour;

class DemoRecorderManager
{
	// management
public:
	void Enable();
	void Disable();
	bool IsRunning() { return m_detoursSetup && m_detoursEnabled; }

private:
	bool m_detoursSetup;
	bool m_detoursEnabled;
	CDetour *m_startRecordingDetour;
	CDetour *m_stopRecordingDetour;
};

extern DemoRecorderManager g_DemoRecorderManager;

#endif //_INCLUDE_COMPCTRL_DEMORECORDER_H_
