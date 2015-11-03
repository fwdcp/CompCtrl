#include <sourcemod>

#include <compctrl_version>
#include <sdktools_gamerules>

bool g_Paused = false;
float g_TimeElapsed = 0.0;

ConVar g_AutoPause;

public Plugin myinfo =
{
    name = "CompCtrl Map Timers",
    author = "Forward Command Post",
    description = "a plugin to manage map timers for competitive games",
    version = COMPCTRL_VERSION,
    url = "http://github.com/fwdcp/CompCtrl/"
};

public void OnPluginStart() {
    g_AutoPause = CreateConVar("compctrl_maptimers_autopause", "1", "automatically pauses the map timer if the round is not running");
}

public void OnGameFrame() {
    if (g_AutoPause.BoolValue) {
        AutoPauseMapTimer();
    }

    if (g_Paused) {
        float newStartTime = GetGameTime() - g_TimeElapsed;
        GameRules_SetPropFloat("m_flMapResetTime", newStartTime, _, true);
    }
}

void AutoPauseMapTimer() {
    RoundState state = GameRules_GetRoundState();

    if (g_Paused) {
        if ((state == RoundState_Preround || state == RoundState_RoundRunning || state == RoundState_Stalemate) && !GameRules_GetProp("m_bInWaitingForPlayers")) {
            UnpauseMapTimer();
        }
    }
    else {
        if ((state != RoundState_Preround && state != RoundState_RoundRunning && state != RoundState_Stalemate) || GameRules_GetProp("m_bInWaitingForPlayers")) {
            PauseMapTimer();
        }
    }
}

void PauseMapTimer() {
    g_Paused = true;
    g_TimeElapsed = GetGameTime() - GameRules_GetPropFloat("m_flMapResetTime");
}

void UnpauseMapTimer() {
    g_Paused = false;
    g_TimeElapsed = 0.0;
}
