#include <sourcemod>

#include <compctrl_version>
#include <morecolors>
#include <sdktools>
#include <tf2>
#include <tf2_stocks>

#pragma newdecls required

ConVar g_MinTeamPlayers;
ConVar g_MaxTeamPlayers;
ConVar g_AutoReadyTeam;
ConVar g_DisplayReadyHUD;

Handle g_DisplayReadyHUDTimer;

Plugin myinfo =
{
    name = "CompCtrl Team Management",
    author = "Forward Command Post",
    description = "a plugin to manage teams in tournament mode",
    version = COMPCTRL_VERSION,
    url = "http://github.com/fwdcp/CompCtrl/"
};

public void OnPluginStart() {
    g_MinTeamPlayers = CreateConVar("compctrl_team_players_min", "0", "the minimum number of players a team is required to play with (0 for no limit)", FCVAR_NOTIFY|FCVAR_REPLICATED|FCVAR_PLUGIN, true, 0.0);
    g_MaxTeamPlayers = CreateConVar("compctrl_team_players_max", "0", "the maximum number of players a team is required to play with (0 for no limit)", FCVAR_NOTIFY|FCVAR_REPLICATED|FCVAR_PLUGIN, true, 0.0);
    g_AutoReadyTeam = CreateConVar("compctrl_team_auto_ready", "0", "if non-zero, a team will be automatically readied when it has this number of players and all players are ready", FCVAR_NOTIFY|FCVAR_REPLICATED|FCVAR_PLUGIN, true, 0.0);
    g_DisplayReadyHUD = CreateConVar("compctrl_team_ready_hud", "0", "displays a HUD with ready and unready players", FCVAR_NOTIFY|FCVAR_REPLICATED|FCVAR_PLUGIN, true, 0.0, true, 1.0);

    RegConsoleCmd("sm_ready", Command_ReadyPlayer, "set yourself as ready");
    RegConsoleCmd("sm_unready", Command_UnreadyPlayer, "set yourself as not ready");

    RegConsoleCmd("sm_teamready", Command_ReadyTeam, "set the team as ready");
    RegConsoleCmd("sm_teamunready", Command_UnreadyTeam, "set the team as not ready");
    AddCommandListener(Command_ChangeTeamReady, "tournament_readystate");

    AddCommandListener(Command_ChangeTeam, "jointeam");
    HookEvent("player_team", Event_PlayerTeam);

    RegConsoleCmd("sm_teamname", Command_SetTeamName, "set the name of the team");
    AddCommandListener(Command_ChangeTeamName, "tournament_teamname");

    RegConsoleCmd("sm_readystatus", Command_CheckReadyStatus, "check the ready status of players");

    g_DisplayReadyHUDTimer = CreateTimer(0.1, Timer_DisplayReadyHUD, _, TIMER_REPEAT);
}

public void OnPluginEnd() {
    KillTimer(g_DisplayReadyHUDTimer);
}

public void OnClientDisconnect(int client) {
    int team = GetClientTeam(client);

    int teamPlayers = 0;
    int teamPlayersReady = 0;

    for (int i = 1; i < MaxClients; i++) {
        if (!IsClientConnected(i) || !IsClientInGame(i) || GetClientTeam(i) != team) {
            continue;
        }

        teamPlayers++;

        if (GameRules_GetProp("m_bPlayerReady", 1, i) == 1) {
            teamPlayersReady++;
        }
    }

    int minPlayers = g_MinTeamPlayers.IntValue;
    int maxPlayers = g_MaxTeamPlayers.IntValue;

    if (minPlayers != 0 && teamPlayers < minPlayers) {
        FakeClientCommand(client, "tournament_readystate 0");
    }
    else if (maxPlayers != 0 && teamPlayers > maxPlayers) {
        FakeClientCommand(client, "tournament_readystate 0");
    }
    else if (teamPlayersReady < teamPlayers) {
        FakeClientCommand(client, "tournament_readystate 0");
    }
}

public Action Command_ChangeTeam(int client, const char[] command, int argc) {
    int team = GetClientTeam(client);

    int teamPlayers = 0;
    int teamPlayersReady = 0;

    for (int i = 1; i < MaxClients; i++) {
        if (!IsClientConnected(i) || !IsClientInGame(i) || i == client || GetClientTeam(i) != team) {
            continue;
        }

        teamPlayers++;

        if (GameRules_GetProp("m_bPlayerReady", 1, i) == 1) {
            teamPlayersReady++;
        }
    }

    int minPlayers = g_MinTeamPlayers.IntValue;
    int maxPlayers = g_MaxTeamPlayers.IntValue;

    if (minPlayers != 0 && teamPlayers < minPlayers) {
        FakeClientCommand(client, "tournament_readystate 0");
    }
    else if (maxPlayers != 0 && teamPlayers > maxPlayers) {
        FakeClientCommand(client, "tournament_readystate 0");
    }
    else if (teamPlayersReady < teamPlayers) {
        FakeClientCommand(client, "tournament_readystate 0");
    }

    return Plugin_Continue;
}

public void Event_PlayerTeam(Event event, const char[] name, bool dontBroadcast) {
    if (!GetEventInt(event, "disconnect")) {
        int client = GetClientOfUserId(GetEventInt(event, "userid"));

        int team = GetEventInt(event, "team");

        int teamPlayers = 0;
        int teamPlayersReady = 0;

        for (int i = 1; i < MaxClients; i++) {
            if (!IsClientConnected(i) || !IsClientInGame(i) || GetClientTeam(i) != team) {
                continue;
            }

            teamPlayers++;

            if (GameRules_GetProp("m_bPlayerReady", 1, i) == 1) {
                teamPlayersReady++;
            }
        }

        int minPlayers = g_MinTeamPlayers.IntValue;
        int maxPlayers = g_MaxTeamPlayers.IntValue;

        if (minPlayers != 0 && teamPlayers < minPlayers) {
            FakeClientCommand(client, "tournament_readystate 0");
        }
        else if (maxPlayers != 0 && teamPlayers > maxPlayers) {
            FakeClientCommand(client, "tournament_readystate 0");
        }
        else if (teamPlayersReady < teamPlayers) {
            FakeClientCommand(client, "tournament_readystate 0");
        }
    }
}

public Action Command_ReadyPlayer(int client, int args) {
    if (!IsClientConnected(client) || !IsClientInGame(client) || !((GetClientTeam(client) == view_as<int>(TFTeam_Blue)) || (GetClientTeam(client) == view_as<int>(TFTeam_Red)))) {
        ReplyToCommand(client, "You cannot ready yourself!");
        return Plugin_Stop;
    }

    if (GameRules_GetProp("m_bPlayerReady", 1, client) == 1) {
        return Plugin_Handled;
    }

    GameRules_SetProp("m_bPlayerReady", 1, 1, client, true);

    char name[255];
    GetClientName(client, name, sizeof(name));

    CPrintToChatAllEx(client, "{teamcolor}%s{default} changed player state to {olive}Ready{default}", name);

    char classSound[32];

    switch (TF2_GetPlayerClass(client)) {
        case TFClass_Scout: {
            classSound = "Scout.Ready";
        }
        case TFClass_Soldier: {
            classSound = "Soldier.Ready";
        }
        case TFClass_Pyro: {
            classSound = "Pyro.Ready";
        }
        case TFClass_DemoMan: {
            classSound = "Demoman.Ready";
        }
        case TFClass_Heavy: {
            classSound = "Heavy.Ready";
        }
        case TFClass_Engineer: {
            classSound = "Engineer.Ready";
        }
        case TFClass_Medic: {
            classSound = "Medic.Ready";
        }
        case TFClass_Sniper: {
            classSound = "Sniper.Ready";
        }
        case TFClass_Spy: {
            classSound = "Spy.Ready";
        }
    }

    if (!StrEqual(classSound, "")) {
        Event soundBroadcast = CreateEvent("teamplay_broadcast_audio");
        if (soundBroadcast != null) {
            soundBroadcast.SetInt("team", view_as<int>(TFTeam_Blue));
            soundBroadcast.SetString("sound", classSound);
            soundBroadcast.SetInt("additional_flags", 0);
            soundBroadcast.Fire();
        }

        soundBroadcast = CreateEvent("teamplay_broadcast_audio");
        if (soundBroadcast != null) {
            soundBroadcast.SetInt("team", view_as<int>(TFTeam_Red));
            soundBroadcast.SetString("sound", classSound);
            soundBroadcast.SetInt("additional_flags", 0);
            soundBroadcast.Fire();
        }
    }

    int autoReady = g_AutoReadyTeam.IntValue;

    if (autoReady > 0) {
        int team = GetClientTeam(client);

        int teamPlayers = 0;
        int teamPlayersReady = 0;

        for (int i = 1; i < MaxClients; i++) {
            if (!IsClientConnected(i) || !IsClientInGame(i) || GetClientTeam(i) != team) {
                continue;
            }

            teamPlayers++;

            if (GameRules_GetProp("m_bPlayerReady", 1, i) == 1) {
                teamPlayersReady++;
            }
        }

        int minPlayers = g_MinTeamPlayers.IntValue;
        int maxPlayers = g_MaxTeamPlayers.IntValue;

        if (teamPlayersReady == teamPlayers && teamPlayers >= autoReady && (minPlayers == 0 || teamPlayers >= minPlayers) && (maxPlayers == 0 || teamPlayers <= maxPlayers)) {
            FakeClientCommand(client, "tournament_readystate 1");
        }
    }

    DisplayReadyHUD();

    return Plugin_Handled;
}

public Action Command_UnreadyPlayer(int client, int args) {
    if (!IsClientConnected(client) || !IsClientInGame(client) || !((GetClientTeam(client) == view_as<int>(TFTeam_Blue)) || (GetClientTeam(client) == view_as<int>(TFTeam_Red)))) {
        ReplyToCommand(client, "You cannot unready yourself!");
        return Plugin_Stop;
    }

    if (GameRules_GetProp("m_bPlayerReady", 1, client) == 0) {
        return Plugin_Handled;
    }

    GameRules_SetProp("m_bPlayerReady", 0, 1, client, true);

    char name[255];
    GetClientName(client, name, sizeof(name));

    CPrintToChatAllEx(client, "{teamcolor}%s{default} changed player state to {olive}Not Ready{default}", name);

    FakeClientCommand(client, "tournament_readystate 0");

    DisplayReadyHUD();

    return Plugin_Handled;
}

public Action Command_ReadyTeam(int client, int args) {
    if (!IsClientConnected(client) || !IsClientInGame(client) || !((GetClientTeam(client) == view_as<int>(TFTeam_Blue)) || (GetClientTeam(client) == view_as<int>(TFTeam_Red)))) {
        ReplyToCommand(client, "You cannot ready your team!");
        return Plugin_Stop;
    }

    FakeClientCommand(client, "tournament_readystate 1");

    return Plugin_Handled;
}

public Action Command_UnreadyTeam(int client, int args) {
    if (!IsClientConnected(client) || !IsClientInGame(client) || !((GetClientTeam(client) == view_as<int>(TFTeam_Blue)) || (GetClientTeam(client) == view_as<int>(TFTeam_Red)))) {
        ReplyToCommand(client, "You cannot unready your team!");
        return Plugin_Stop;
    }

    FakeClientCommand(client, "tournament_readystate 0");

    return Plugin_Handled;
}

public Action Command_ChangeTeamReady(int client, const char[] command, int argc) {
    if (!IsClientConnected(client) || !IsClientInGame(client) || !((GetClientTeam(client) == view_as<int>(TFTeam_Blue)) || (GetClientTeam(client) == view_as<int>(TFTeam_Red)))) {
        ReplyToCommand(client, "You cannot change your team ready state!");
        return Plugin_Stop;
    }

    char arg[16];

    GetCmdArg(1, arg, sizeof(arg));

    bool ready = view_as<bool>(StringToInt(arg));

    if (ready) {
        int team = GetClientTeam(client);

        int teamPlayers = 0;
        int teamPlayersNotReady = 0;

        char unreadyPlayers[1024];

        for (int i = 1; i < MaxClients; i++) {
            if (!IsClientConnected(i) || !IsClientInGame(i) || GetClientTeam(i) != team) {
                continue;
            }

            teamPlayers++;

            if (GameRules_GetProp("m_bPlayerReady", 1, i) == 0) {
                if (teamPlayersNotReady > 0) {
                    StrCat(unreadyPlayers, sizeof(unreadyPlayers), "; ");
                }

                char playerName[64];
                GetClientName(i, playerName, sizeof(playerName));

                Format(unreadyPlayers, sizeof(unreadyPlayers), "%s{teamcolor}%s{default}", unreadyPlayers, playerName);

                teamPlayersNotReady++;
            }
        }

        int minPlayers = g_MinTeamPlayers.IntValue;
        int maxPlayers = g_MaxTeamPlayers.IntValue;

        if (minPlayers != 0 && teamPlayers < minPlayers) {
            PrintToChat(client, "You cannot ready your team because it has %i player(s), which is less than the %i minimum player(s) required to play.", teamPlayers, minPlayers);
            return Plugin_Stop;
        }
        else if (maxPlayers != 0 && teamPlayers > maxPlayers) {
            PrintToChat(client, "You cannot ready your team because it has %i player(s), which is more than the %i maximum player(s) allowed to play.", teamPlayers, maxPlayers);
            return Plugin_Stop;
        }
        else if (teamPlayersNotReady > 0) {
            CPrintToChatEx(client, client, "You cannot ready your team because the following players on it are not ready: %s.", unreadyPlayers);
            return Plugin_Stop;
        }
        else {
            return Plugin_Continue;
        }
    }
    else {
        return Plugin_Continue;
    }
}

public Action Command_SetTeamName(int client, int args) {
    if (!IsClientConnected(client) || !IsClientInGame(client) || !((GetClientTeam(client) == view_as<int>(TFTeam_Blue)) || (GetClientTeam(client) == view_as<int>(TFTeam_Red)))) {
        ReplyToCommand(client, "You cannot set your team name!");
        return Plugin_Stop;
    }

    char arg[256];
    GetCmdArg(1, arg, sizeof(arg));

    FakeClientCommand(client, "tournament_teamname \"%s\"", arg);

    return Plugin_Handled;
}

public Action Command_ChangeTeamName(int client, const char[] command, int argc) {
    if (!IsClientConnected(client) || !IsClientInGame(client) || !((GetClientTeam(client) == view_as<int>(TFTeam_Blue)) || (GetClientTeam(client) == view_as<int>(TFTeam_Red)))) {
        ReplyToCommand(client, "You cannot change your team name!");
        return Plugin_Stop;
    }

    char arg[256];
    GetCmdArg(1, arg, sizeof(arg));

    TFTeam team = view_as<TFTeam>(GetClientTeam(client));

    if (team == TFTeam_Blue) {
        ConVar name = FindConVar("mp_tournament_blueteamname");
        name.SetString(arg, true, true);
    }
    else if (team == TFTeam_Red) {
		ConVar name = FindConVar("mp_tournament_redteamname");
		name.SetString(arg, true, true);
    }

    Event nameChange = CreateEvent("tournament_stateupdate");

    if (nameChange != null) {
        nameChange.SetInt("userid", client);
        nameChange.SetBool("namechange", true);
        nameChange.SetString("newname", arg);
        nameChange.Fire();
    }

    return Plugin_Handled;
}

public Action Command_CheckReadyStatus(int client, int args) {
    char readyPlayers[512];
    char unreadyPlayers[512];

    int readyCount = 0;
    int unreadyCount = 0;

    for (int i = 1; i <= MaxClients; i++) {
        if (!IsClientConnected(i) || !IsClientInGame(i) || GetClientTeam(i) != view_as<int>(TFTeam_Blue)) {
            continue;
        }

        char name[64];
        GetClientName(i, name, sizeof(name));

        if (GameRules_GetProp("m_bPlayerReady", 1, i) == 1) {
            if (readyCount > 0) {
                StrCat(readyPlayers, sizeof(readyPlayers), "; ");
            }

            Format(readyPlayers, sizeof(readyPlayers), "%s{blue}%s{default}", readyPlayers, name);

            readyCount++;
        }
        else {
            if (unreadyCount > 0) {
                StrCat(unreadyPlayers, sizeof(unreadyPlayers), "; ");
            }

            Format(unreadyPlayers, sizeof(unreadyPlayers), "%s{blue}%s{default}", unreadyPlayers, name);

            unreadyCount++;
        }
    }

    for (int i = 1; i <= MaxClients; i++) {
        if (!IsClientConnected(i) || !IsClientInGame(i) || GetClientTeam(i) != view_as<int>(TFTeam_Red)) {
            continue;
        }

        char name[64];
        GetClientName(i, name, sizeof(name));

        if (GameRules_GetProp("m_bPlayerReady", 1, i) == 1) {
            if (readyCount > 0) {
                StrCat(readyPlayers, sizeof(readyPlayers), "; ");
            }

            Format(readyPlayers, sizeof(readyPlayers), "%s{red}%s{default}", readyPlayers, name);

            readyCount++;
        }
        else {
            if (unreadyCount > 0) {
                StrCat(unreadyPlayers, sizeof(unreadyPlayers), "; ");
            }

            Format(unreadyPlayers, sizeof(unreadyPlayers), "%s{red}%s{default}", unreadyPlayers, name);

            unreadyCount++;
        }
    }

    if (readyCount > 0) {
        CReplyToCommand(client, "{green}Ready{default}: %s", readyPlayers);
    }

    if (unreadyCount > 0) {
        CReplyToCommand(client, "{yellow}Not ready{default}: %s", unreadyPlayers);
    }

    return Plugin_Handled;
}

public Action Timer_DisplayReadyHUD(Handle timer) {
    DisplayReadyHUD();
}

void DisplayReadyHUD() {
    if (!g_DisplayReadyHUD.BoolValue) {
        return;
    }

    if (!GameRules_GetProp("m_bAwaitingReadyRestart")) {
        return;
    }

    char readyPlayers[512];
    char unreadyPlayers[512];

    int readyCount = 0;
    int unreadyCount = 0;

    for (int i = 1; i <= MaxClients; i++) {
        if (!IsClientConnected(i) || !IsClientInGame(i) || GetClientTeam(i) != view_as<int>(TFTeam_Blue)) {
            continue;
        }

        char name[64];
        GetClientName(i, name, sizeof(name));

        if (GameRules_GetProp("m_bPlayerReady", 1, i) == 1) {
            Format(readyPlayers, sizeof(readyPlayers), "%s\n%s", readyPlayers, name);

            readyCount++;
        }
        else {
            Format(unreadyPlayers, sizeof(unreadyPlayers), "%s\n%s", unreadyPlayers, name);

            unreadyCount++;
        }
    }

    for (int i = 1; i <= MaxClients; i++) {
        if (!IsClientConnected(i) || !IsClientInGame(i) || GetClientTeam(i) != view_as<int>(TFTeam_Red)) {
            continue;
        }

        char name[64];
        GetClientName(i, name, sizeof(name));

        if (GameRules_GetProp("m_bPlayerReady", 1, i) == 1) {
            Format(readyPlayers, sizeof(readyPlayers), "%s\n%s", readyPlayers, name);

            readyCount++;
        }
        else {
            Format(unreadyPlayers, sizeof(unreadyPlayers), "%s\n%s", unreadyPlayers, name);

            unreadyCount++;
        }
    }

    char message[1024];

    if (readyCount > 0 && unreadyCount > 0) {
        Format(message, sizeof(message), "Ready:%s\n \nUnready:%s", readyPlayers, unreadyPlayers);
    }
    else if (readyCount > 0) {
        Format(message, sizeof(message), "Ready:%s", readyPlayers);
    }
    else if (unreadyCount > 0) {
        Format(message, sizeof(message), "Unready:%s", unreadyPlayers);
    }
    else {
        Format(message, sizeof(message), " ");
    }

    Handle keyHint = StartMessageAll("KeyHintText");
    BfWriteByte(keyHint, 1);
    BfWriteString(keyHint, message);
    EndMessage();
}
