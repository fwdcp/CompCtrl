#include <sourcemod>

#include <compctrl_version>
#include <sdktools_gamerules>

bool g_AutoRunActivated = false;
float g_TargetTime = -1.0;

ConVar g_AutoRun;
ConVar g_Managed;
ConVar g_Paused;
ConVar g_Time;

public Plugin myinfo =
{
    name = "CompCtrl Game Countdowns",
    author = "Forward Command Post",
    description = "a plugin to manage start countdowns for competitive games",
    version = COMPCTRL_VERSION,
    url = "http://github.com/fwdcp/CompCtrl/"
};

public void OnPluginStart() {
    g_AutoRun = CreateConVar("compctrl_gamecountdowns_autorun", "0", "automatically run game countdowns");
    g_Managed = CreateConVar("compctrl_gamecountdowns_managed", "0", "enables management of game countdowns");
    g_Paused = CreateConVar("compctrl_gamecountdowns_paused", "1", "whether the countdown is paused");
    g_Time = CreateConVar("compctrl_gamecountdowns_time", "60", "the amount of time that game countdowns should run");
}

public void OnGameFrame() {
    if (g_Managed.BoolValue) {
        ManageRestartTimer();
    }
}

void ManageRestartTimer() {
    if (GameRules_GetProp("m_bInWaitingForPlayers") && GameRules_GetPropFloat("m_flRestartRoundTime") > 0.0) {
        if (g_Paused.BoolValue) {
            g_TargetTime = GetGameTime() + g_Time.FloatValue;
        }

        GameRules_SetPropFloat("m_flRestartRoundTime", g_TargetTime, _, true);

        if (g_AutoRun.BoolValue && !g_AutoRunActivated) {
            g_AutoRunActivated = true;
            g_Paused.BoolValue = false;
        }
    }
    else {
        g_Paused.BoolValue = true;

        g_AutoRunActivated = false;
        g_TargetTime = -1.0;
    }
}
