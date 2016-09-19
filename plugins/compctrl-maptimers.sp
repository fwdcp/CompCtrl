#include <sourcemod>

#include <compctrl_version>
#include <sdktools_gamerules>

bool g_Paused = false;
float g_CurrentStartTime = 0.0;
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
        UpdatePauseStatus();
    }

    if (g_Paused) {
        g_CurrentStartTime = GetGameTime() - g_TimeElapsed;
        GameRules_SetPropFloat("m_flMapResetTime", g_CurrentStartTime, _, true);
    }
}

void UpdatePauseStatus() {
    RoundState state = GameRules_GetRoundState();

    g_Paused = ((state != RoundState_Preround && state != RoundState_RoundRunning && state != RoundState_Stalemate) || GameRules_GetProp("m_bInWaitingForPlayers"));

    float newStartTime = GameRules_GetPropFloat("m_flMapResetTime");

    if (!g_Paused || g_CurrentStartTime != newStartTime) {
        g_TimeElapsed = GetGameTime() - newStartTime;
    }
}
