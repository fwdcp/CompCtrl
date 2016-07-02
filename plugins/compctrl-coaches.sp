#include <sourcemod>

#include <compctrl_version>
#include <compctrl_extension>
#include <morecolors>
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

public Action Command_BecomeCoach(int client, int args) {
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
}

public Action Command_BecomePlayer(int client, int args) {
	if (g_Coaches[client]) {
		g_Coaches[client] = false;

		TF2_RespawnPlayer(client);

		CReplyToCommand(client, "{green}[CompCtrl]{default} You have become a player.");
	}
	else {
		CReplyToCommand(client, "{green}[CompCtrl]{default} You are already a player!");
	}
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
