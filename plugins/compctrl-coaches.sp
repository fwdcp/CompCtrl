#include <sourcemod>

#include <compctrl_version>
#include <compctrl_extension>
#include <morecolors>
#include <sdkhooks>
#include <tf2>

#pragma newdecls required

#define OBS_MODE_IN_EYE 4

bool g_Coaches[MAXPLAYERS + 1];

public Plugin myinfo =
{
    name = "CompCtrl Coach Support",
    author = "Forward Command Post",
    description = "a plugin to allow players to assume a coach role",
    version = COMPCTRL_VERSION,
    url = "http://github.com/fwdcp/CompCtrl/"
};

public void OnPluginStart() {
    RegConsoleCmd("sm_becomecoach", Command_BecomeCoach, "become coach for current team");
    RegConsoleCmd("sm_becomeplayer", Command_BecomePlayer, "become player for current team");
}

public void OnMapStart() {
    int playerManager = FindEntityByClassname(-1, "tf_player_manager");

    if (playerManager != -1) {
        SDKHook(playerManager, SDKHook_PostThink, Hook_OnPlayerManagerPostThink);
    }
}

public Action Command_BecomeCoach(int client, int args) {
    if (!IsClientInGame(client) || (GetClientTeam(client) != view_as<int>(TFTeam_Red) && GetClientTeam(client) != view_as<int>(TFTeam_Blue))) {
        CReplyToCommand(client, "{green}[CompCtrl]{default} You cannot become a team coach!");
        return Plugin_Handled;
    }

    if (!g_Coaches[client]) {
        g_Coaches[client] = true;

        ForcePlayerSuicide(client);

        SetEntProp(client, Prop_Send, "m_iClass", view_as<int>(TFClass_Unknown));
        SetEntProp(client, Prop_Send, "m_iDesiredPlayerClass", view_as<int>(TFClass_Unknown));

        SetEntProp(client, Prop_Send, "m_iObserverMode", OBS_MODE_IN_EYE);

        CReplyToCommand(client, "{green}[CompCtrl]{default} You have become a team coach.");
    }
    else {
        CReplyToCommand(client, "{green}[CompCtrl]{default} You are already a team coach!");
    }

    return Plugin_Handled;
}

public Action Command_BecomePlayer(int client, int args) {
    if (!IsClientInGame(client) || (GetClientTeam(client) != view_as<int>(TFTeam_Red) && GetClientTeam(client) != view_as<int>(TFTeam_Blue))) {
        CReplyToCommand(client, "{green}[CompCtrl]{default} You cannot become a player!");
        return Plugin_Handled;
    }

    if (g_Coaches[client]) {
        g_Coaches[client] = false;

        TF2_RespawnPlayer(client);

        CReplyToCommand(client, "{green}[CompCtrl]{default} You have become a player.");
    }
    else {
        CReplyToCommand(client, "{green}[CompCtrl]{default} You are already a player!");
    }

    return Plugin_Handled;
}

public void OnClientConnected(int client) {
    g_Coaches[client] = false;
}

public Action CompCtrl_OnRespawn(int client) {
    if (!g_Coaches[client]) {
        return Plugin_Continue;
    }

    SetEntProp(client, Prop_Send, "m_iClass", view_as<int>(TFClass_Unknown));
    SetEntProp(client, Prop_Send, "m_iDesiredPlayerClass", view_as<int>(TFClass_Unknown));

    return Plugin_Stop;
}

public void Hook_OnPlayerManagerPostThink(int entity) {
    for (int i = 1; i <= MaxClients; i++) {
        if (!IsClientInGame(i) || (GetClientTeam(i) != view_as<int>(TFTeam_Red) && GetClientTeam(i) != view_as<int>(TFTeam_Blue))) {
            if (g_Coaches[i] && IsClientInGame(i)) {
                CPrintToChat(i, "{green}[CompCtrl]{default} Your coach status was removed.");
            }

            g_Coaches[i] = false;
        }

        if (g_Coaches[i]) {
            SetEntProp(entity, Prop_Send, "m_bConnected", 0, _, i);
        }
    }
}
