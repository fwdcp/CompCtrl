#include <sourcemod>

#include <compctrl_version>
#include <morecolors>
#include <sdktools>
#include <tf2>
#include <tf2_stocks>

new Handle:g_MinTeamPlayers = INVALID_HANDLE;
new Handle:g_MaxTeamPlayers = INVALID_HANDLE;
new Handle:g_AutoReadyTeam = INVALID_HANDLE;

public Plugin:myinfo =
{
	name = "CompCtrl Team Management",
	author = "Forward Command Post",
	description = "a plugin to manage teams in tournament mode",
	version = COMPCTRL_VERSION,
	url = "http://github.com/fwdcp/CompCtrl/"
};

public OnPluginStart() {
	g_MinTeamPlayers = CreateConVar("compctrl_team_players_min", "0", "the minimum number of players a team is required to play with (0 for no limit)", FCVAR_NOTIFY|FCVAR_REPLICATED|FCVAR_PLUGIN, true, 0.0);
	g_MaxTeamPlayers = CreateConVar("compctrl_team_players_max", "0", "the maximum number of players a team is required to play with (0 for no limit)", FCVAR_NOTIFY|FCVAR_REPLICATED|FCVAR_PLUGIN, true, 0.0);
	g_AutoReadyTeam = CreateConVar("compctrl_team_auto_ready", "0", "if non-zero, a team will be automatically readied when it has this number of players and all players are ready", FCVAR_NOTIFY|FCVAR_REPLICATED|FCVAR_PLUGIN, true, 0.0);
	
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
}

public OnClientDisconnect(client) {
	new team = GetClientTeam(client);
		
	new teamPlayers;
	new teamPlayersReady;
	
	for (new i = 1; i < MaxClients; i++) {
		if (!IsClientConnected(i) || !IsClientInGame(i) || GetClientTeam(i) != team) {
			continue;
		}
		
		teamPlayers++;
		
		if (GameRules_GetProp("m_bPlayerReady", 1, i) == 1) {
			teamPlayersReady++;
		}
	}
	
	new minPlayers = GetConVarInt(g_MinTeamPlayers);
	new maxPlayers = GetConVarInt(g_MaxTeamPlayers);
	
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

public Action:Command_ChangeTeam(client, const String:command[], argc) {
	new team = GetClientTeam(client);
	
	new teamPlayers;
	new teamPlayersReady;
	
	for (new i = 1; i < MaxClients; i++) {
		if (!IsClientConnected(i) || !IsClientInGame(i) || i == client || GetClientTeam(i) != team) {
			continue;
		}
		
		teamPlayers++;
		
		if (GameRules_GetProp("m_bPlayerReady", 1, i) == 1) {
			teamPlayersReady++;
		}
	}
	
	new minPlayers = GetConVarInt(g_MinTeamPlayers);
	new maxPlayers = GetConVarInt(g_MaxTeamPlayers);
	
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

public Event_PlayerTeam(Handle:event, const String:name[], bool:dontBroadcast) {
	if (!GetEventInt(event, "disconnect")) {
		new client = GetClientOfUserId(GetEventInt(event, "userid"));
		
		new team = GetEventInt(event, "team");
		
		new teamPlayers;
		new teamPlayersReady;
		
		for (new i = 1; i < MaxClients; i++) {
			if (!IsClientConnected(i) || !IsClientInGame(i) || GetClientTeam(i) != team) {
				continue;
			}
			
			teamPlayers++;
			
			if (GameRules_GetProp("m_bPlayerReady", 1, i) == 1) {
				teamPlayersReady++;
			}
		}
		
		new minPlayers = GetConVarInt(g_MinTeamPlayers);
		new maxPlayers = GetConVarInt(g_MaxTeamPlayers);
		
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

public Action:Command_ReadyPlayer(client, args) {
	if (!IsClientConnected(client) || !IsClientInGame(client) || !(TFTeam:GetClientTeam(client) == TFTeam_Blue || TFTeam:GetClientTeam(client) == TFTeam_Red)) {
		ReplyToCommand(client, "You cannot ready yourself!");
		return Plugin_Stop;
	}
	
	if (GameRules_GetProp("m_bPlayerReady", 1, client) == 1) {
		return Plugin_Handled;
	}
	
	GameRules_SetProp("m_bPlayerReady", 1, 1, client, true);
	
	decl String:name[255];
	GetClientName(client, name, sizeof(name));
	
	CPrintToChatAllEx(client, "{teamcolor}%s{default} changed player state to {olive}Ready{default}", name);
	
	new String:classSound[32] = "";
	
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
		new Handle:soundBroadcast;
		
		soundBroadcast = CreateEvent("teamplay_broadcast_audio");
		if (soundBroadcast != INVALID_HANDLE) {
			SetEventInt(soundBroadcast, "team", _:TFTeam_Blue);
			SetEventString(soundBroadcast, "sound", classSound);
			SetEventInt(soundBroadcast, "additional_flags", 0);
			FireEvent(soundBroadcast);
		}
		
		soundBroadcast = CreateEvent("teamplay_broadcast_audio");
		if (soundBroadcast != INVALID_HANDLE) {
			SetEventInt(soundBroadcast, "team", _:TFTeam_Red);
			SetEventString(soundBroadcast, "sound", classSound);
			SetEventInt(soundBroadcast, "additional_flags", 0);
			FireEvent(soundBroadcast);
		}
	}
	
	new autoReady = GetConVarInt(g_AutoReadyTeam);
	
	if (autoReady > 0) {
		new team = GetClientTeam(client);
			
		new teamPlayers;
		new teamPlayersReady;
		
		for (new i = 1; i < MaxClients; i++) {
			if (!IsClientConnected(i) || !IsClientInGame(i) || GetClientTeam(i) != team) {
				continue;
			}
			
			teamPlayers++;
			
			if (GameRules_GetProp("m_bPlayerReady", 1, i) == 1) {
				teamPlayersReady++;
			}
		}
		
		new minPlayers = GetConVarInt(g_MinTeamPlayers);
		new maxPlayers = GetConVarInt(g_MaxTeamPlayers);
		
		if (teamPlayersReady == teamPlayers && teamPlayers >= autoReady && (minPlayers == 0 || teamPlayers >= minPlayers) && (maxPlayers == 0 || teamPlayers <= maxPlayers)) {
			FakeClientCommand(client, "tournament_readystate 1");
		}
	}
	
	return Plugin_Handled;
}

public Action:Command_UnreadyPlayer(client, args) {
	if (!IsClientConnected(client) || !IsClientInGame(client) || !(TFTeam:GetClientTeam(client) == TFTeam_Blue || TFTeam:GetClientTeam(client) == TFTeam_Red)) {
		ReplyToCommand(client, "You cannot unready yourself!");
		return Plugin_Stop;
	}
	
	if (GameRules_GetProp("m_bPlayerReady", 1, client) == 0) {
		return Plugin_Handled;
	}
	
	GameRules_SetProp("m_bPlayerReady", 0, 1, client, true);
	
	decl String:name[255];
	GetClientName(client, name, sizeof(name));
	
	CPrintToChatAllEx(client, "{teamcolor}%s{default} changed player state to {olive}Not Ready{default}", name);
	
	FakeClientCommand(client, "tournament_readystate 0");
	
	return Plugin_Handled;
}
public Action:Command_ReadyTeam(client, args) {
	if (!IsClientConnected(client) || !IsClientInGame(client) || !(TFTeam:GetClientTeam(client) == TFTeam_Blue || TFTeam:GetClientTeam(client) == TFTeam_Red)) {
		ReplyToCommand(client, "You cannot ready your team!");
		return Plugin_Stop;
	}
	
	FakeClientCommand(client, "tournament_readystate 1");
	
	return Plugin_Handled;
}

public Action:Command_UnreadyTeam(client, args) {
	if (!IsClientConnected(client) || !IsClientInGame(client) || !(TFTeam:GetClientTeam(client) == TFTeam_Blue || TFTeam:GetClientTeam(client) == TFTeam_Red)) {
		ReplyToCommand(client, "You cannot unready your team!");
		return Plugin_Stop;
	}
	
	FakeClientCommand(client, "tournament_readystate 0");
	
	return Plugin_Handled;
}

public Action:Command_ChangeTeamReady(client, const String:command[], argc) {
	if (!IsClientConnected(client) || !IsClientInGame(client) || !(TFTeam:GetClientTeam(client) == TFTeam_Blue || TFTeam:GetClientTeam(client) == TFTeam_Red)) {
		ReplyToCommand(client, "You cannot change your team ready state!");
		return Plugin_Stop;
	}
	
	decl String:arg[16];
	
	GetCmdArg(1, arg, sizeof(arg));
	
	new bool:ready = bool:StringToInt(arg);
	
	if (ready) {
		new team = GetClientTeam(client);
		
		new teamPlayers;
		new teamPlayersNotReady;
		
		new String:unreadyPlayers[512];
		
		for (new i = 1; i < MaxClients; i++) {
			if (!IsClientConnected(i) || !IsClientInGame(i) || GetClientTeam(i) != team) {
				continue;
			}
			
			teamPlayers++;
			
			if (GameRules_GetProp("m_bPlayerReady", 1, i) == 0) {
				if (teamPlayersNotReady > 0) {
					StrCat(unreadyPlayers, sizeof(unreadyPlayers), "; ");
				}
				
				decl String:playerName[64];
				GetClientName(i, playerName, sizeof(playerName));
				
				Format(unreadyPlayers, sizeof(unreadyPlayers), "%s{team}%s{default}", unreadyPlayers, playerName);
				
				teamPlayersNotReady++;
			}
		}
		
		new minPlayers = GetConVarInt(g_MinTeamPlayers);
		new maxPlayers = GetConVarInt(g_MaxTeamPlayers);
		
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

public Action:Command_SetTeamName(client, args) {
	if (!IsClientConnected(client) || !IsClientInGame(client) || !(TFTeam:GetClientTeam(client) == TFTeam_Blue || TFTeam:GetClientTeam(client) == TFTeam_Red)) {
		ReplyToCommand(client, "You cannot set your team name!");
		return Plugin_Stop;
	}
	
	decl String:arg[256];
	GetCmdArg(1, arg, sizeof(arg));
	
	FakeClientCommand(client, "tournament_teamname \"%s\"", arg);
	
	return Plugin_Handled;
}

public Action:Command_ChangeTeamName(client, const String:command[], argc) {
	if (!IsClientConnected(client) || !IsClientInGame(client) || !(TFTeam:GetClientTeam(client) == TFTeam_Blue || TFTeam:GetClientTeam(client) == TFTeam_Red)) {
		ReplyToCommand(client, "You cannot change your team name!");
		return Plugin_Stop;
	}
	
	decl String:arg[256];
	GetCmdArg(1, arg, sizeof(arg));
	
	new TFTeam:team = TFTeam:GetClientTeam(client);
	
	if (team == TFTeam_Blue) {
		new Handle:name = FindConVar("mp_tournament_blueteamname");
		SetConVarString(name, arg, true);
	}
	else if (team == TFTeam_Red) {
		new Handle:name = FindConVar("mp_tournament_redteamname");
		SetConVarString(name, arg, true);
	}
	
	new Handle:nameChange = CreateEvent("tournament_stateupdate");
	
	if (nameChange != INVALID_HANDLE) {
		SetEventInt(nameChange, "userid", client);
		SetEventBool(nameChange, "namechange", true);
		SetEventString(nameChange, "newname", arg);
		FireEvent(nameChange);
	}
	
	return Plugin_Handled;
}

public Action:Command_CheckReadyStatus(client, args) {
	new String:readyPlayers[512];
	new String:unreadyPlayers[512];
	
	new readyCount = 0;
	new unreadyCount = 0;
	
	for (new i = 1; i <= MaxClients; i++) {
		if (!IsClientConnected(i) || !IsClientInGame(i) || TFTeam:GetClientTeam(i) != TFTeam_Blue) {
			continue;
		}
		
		decl String:name[64];
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
	
	for (new i = 1; i <= MaxClients; i++) {
		if (!IsClientConnected(i) || !IsClientInGame(i) || TFTeam:GetClientTeam(i) != TFTeam_Red) {
			continue;
		}
		
		decl String:name[64];
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