#include <sourcemod>

#include <compctrl_version>
#include <sdktools>

#pragma newdecls required

public Plugin myinfo =
{
    name = "CompCtrl Player Aliases",
    author = "Forward Command Post",
    description = "a plugin to enforce player aliases",
    version = COMPCTRL_VERSION,
    url = "http://github.com/fwdcp/CompCtrl/"
};

StringMap playerAliases;

public void OnPluginStart() {
    RegAdminCmd("sm_setalias", Command_SetAlias, ADMFLAG_CONFIG, "sets an enforced player alias");
    RegAdminCmd("sm_removealias", Command_RemoveAlias, ADMFLAG_CONFIG, "removes an enforced player alias");

    playerAliases = new StringMap();

    HookEvent("player_changename", Event_NameChange, EventHookMode_Post);
    HookUserMessage(GetUserMessageId("SayText2"), UserMessage_SayText2, true);
}

public void OnClientPostAdminCheck(int client) {
    if (!IsFakeClient(client)) {
        char steamID[32];
        if (GetClientAuthId(client, AuthId_SteamID64, steamID, sizeof(steamID))) {
            char alias[32];
            if (playerAliases.GetString(steamID, alias, sizeof(alias))) {
                SetClientName(client, alias);
            }
        }
    }
}

public Action Command_SetAlias(int client, int args) {
    char steamID[32];
    GetCmdArg(1, steamID, sizeof(steamID));

    char alias[32];
    GetCmdArg(2, alias, sizeof(alias));

    playerAliases.SetString(steamID, alias, true);

    for (int i = 1; i <= MaxClients; i++) {
        if (IsClientConnected(i) && !IsFakeClient(i)) {
            char playerSteamID[32];
            if (GetClientAuthId(i, AuthId_SteamID64, playerSteamID, sizeof(playerSteamID))) {
                if (StrEqual(steamID, playerSteamID)) {
                    SetClientName(i, alias);
                }
            }
        }
    }
}

public Action Command_RemoveAlias(int client, int args) {
    char steamID[32];
    GetCmdArg(1, steamID, sizeof(steamID));

    playerAliases.Remove(steamID);
}

public void Event_NameChange(Event event, const char[] name, bool dontBroadcast) {
    int client = GetClientOfUserId(event.GetInt("userid"));

    if (!IsClientReplay(client) && !IsClientSourceTV(client)) {
        char newName[32];
        event.GetString("newname", newName, sizeof(newName));

        char steamID[32];
        GetClientAuthId(client, AuthId_SteamID64, steamID, sizeof(steamID));

        char playerAlias[32];
        if (playerAliases.GetString(steamID, playerAlias, sizeof(playerAlias))) {
            if (!StrEqual(newName, playerAlias)) {
                SetClientName(client, playerAlias);
            }
        }
    }
}

public Action UserMessage_SayText2(UserMsg msg_id, BfRead msg, const int[] players, int playersNum, bool reliable, bool init) {
    char buffer[512];

    if (!reliable) {
        return Plugin_Continue;
    }

    msg.ReadByte();
    msg.ReadByte();
    msg.ReadString(buffer, sizeof(buffer), false);

    if (StrContains(buffer, "#TF_Name_Change") != -1) {
        return Plugin_Handled;
    }

    return Plugin_Continue;
}
