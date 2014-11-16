#include <sourcemod>

#include <compctrl_version>
#include <morecolors>
#include <sdktools>
#include <tf2>

public Plugin:myinfo =
{
	name = "CompCtrl Drafts",
	author = "Forward Command Post",
	description = "a plugin to manage player drafts for competitive games",
	version = COMPCTRL_VERSION,
	url = "http://github.com/fwdcp/CompCtrl/"
};

new Handle:g_DraftConfig = INVALID_HANDLE;
new String:g_DraftConfigName[64];
new g_BluCaptain = 0;
new g_RedCaptain = 0;
new TFTeam:g_FirstChoice = TFTeam_Unassigned;
new g_InDraft = false;
new g_CurrentPosition;
new g_ChosenUserIDs[MAXPLAYERS + 1];
new String:g_ChosenSteamIDs[MAXPLAYERS + 1][32];
new Handle:g_ChoiceMenu;

public OnPluginStart() {
	LoadTranslations("common.phrases");
	
	g_ChoiceMenu = CreateMenu(Menu_Choose);
	
	RegAdminCmd("sm_startdraft", Command_StartDraft, ADMFLAG_CONFIG, "starts the player draft with specified settings", "compctrl");
	RegAdminCmd("sm_canceldraft", Command_CancelDraft, ADMFLAG_CONFIG, "cancels the current player draft", "compctrl");
	RegAdminCmd("sm_setdraftconfig", Command_SetConfig, ADMFLAG_CONFIG, "sets a draft config to use", "compctrl");
	RegAdminCmd("sm_setdraftcaptain", Command_SetCaptain, ADMFLAG_CONFIG, "sets a team captain for the draft", "compctrl");
	RegAdminCmd("sm_setdraftfirstchoice", Command_SetFirstChoice, ADMFLAG_CONFIG, "sets the team to get first choice for the draft", "compctrl");
	
	RegConsoleCmd("sm_choose", Command_Choose, "select a player for the current draft phase");
	
	AddCommandListener(Command_ChangeTeam, "jointeam");
	AddCommandListener(Command_ChangeTeam, "spectate");
}

public OnClientPostAdminCheck(client) {
	if (g_InDraft) {
		decl String:clientSteamID[32];
		
		new TFTeam:team = TFTeam_Spectator;
		
		if (GetClientAuthId(client, AuthId_SteamID64, clientSteamID, sizeof(clientSteamID))) {
			for (new i = 1; i < g_CurrentPosition; i++) {
				if (StrEqual(clientSteamID, g_ChosenSteamIDs[i])) {
					g_ChosenUserIDs[i] = GetClientUserId(client);
					
					if (GetDraftChoice(i)) {
						decl String:choiceType[8];
						KvGetString(g_DraftConfig, "type", choiceType, sizeof(choiceType));
						
						if (StrEqual(choiceType, "pick")) {
							new choosingTeam = KvGetNum(g_DraftConfig, "team");
							
							if (choosingTeam == 1) {
								team = g_FirstChoice;
							}
							else if (choosingTeam == 2) {
								if (g_FirstChoice == TFTeam_Red) {
									team = TFTeam_Blue;
								}
								else if (g_FirstChoice == TFTeam_Blue) {
									team = TFTeam_Red;
								}
							}
						}
					}
					
					break;
				}
			}
		}
		
		ChangeClientTeam(client, _:team);
	}
}

public OnClientDisconnect(client) {
	if (g_RedCaptain == client) {
		if (g_InDraft) {
			CPrintToChatAll("{green}[CompCtrl]{default} A captain has left the game. Aborting draft!");
			
			CloseDraft();
		}
		
		g_RedCaptain = 0;
	}
	else if (g_BluCaptain == client) {
		if (g_InDraft) {
			CPrintToChatAll("{green}[CompCtrl]{default} A captain has left the game. Aborting draft!");
			
			CloseDraft();
		}
		
		g_BluCaptain = 0;
	}
}

public Action:Command_StartDraft(client, args) {
	if (g_InDraft) {
		ReplyToCommand(client, "Cannot start a draft while one is in progress!");
		return Plugin_Handled;
	}
	
	if (g_DraftConfig == INVALID_HANDLE) {
		ReplyToCommand(client, "Must set a valid config to begin draft!");
		return Plugin_Handled;
	}
	
	if (g_RedCaptain == 0 || g_BluCaptain == 0) {
		ReplyToCommand(client, "Must set team captains to begin draft!");
		return Plugin_Handled;
	}
	
	if (g_FirstChoice != TFTeam_Red && g_FirstChoice != TFTeam_Blue) {
		ReplyToCommand(client, "Must set team to choose first!");
		return Plugin_Handled;
	}
	
	OpenDraft();
	
	return Plugin_Handled;
}

public Action:Command_CancelDraft(client, args) {
	if (!g_InDraft) {
		ReplyToCommand(client, "There is no draft to cancel!");
		return Plugin_Handled;
	}
	
	CPrintToChatAll("{green}[CompCtrl]{default} The current draft has been canceled.");
	
	CloseDraft();
	
	return Plugin_Handled;
}

public Action:Command_SetConfig(client, args) {
	if (g_InDraft) {
		ReplyToCommand(client, "Cannot change options while a draft is occurring!");
		return Plugin_Handled;
	}
	
	if (args >= 1) {
		if (g_DraftConfig != INVALID_HANDLE) {
			CloseHandle(g_DraftConfig);
			g_DraftConfig = INVALID_HANDLE;
		}
		
		decl String:arg[256];
		GetCmdArg(1, arg, sizeof(arg));
		
		g_DraftConfig = CreateKeyValues(arg);
		
		decl String:configPath[PLATFORM_MAX_PATH];
		BuildPath(Path_SM, configPath, sizeof(configPath), "configs/compctrl/drafts/%s.cfg", arg);
		
		if (!FileExists(configPath) || !FileToKeyValues(g_DraftConfig, configPath)) {
			ReplyToCommand(client, "No such draft config exists!");
			CloseHandle(g_DraftConfig);
			g_DraftConfig = INVALID_HANDLE;
			return Plugin_Handled;
		}
		
		strcopy(g_DraftConfigName, sizeof(g_DraftConfigName), arg);
		
		CPrintToChatAll("{green}[CompCtrl]{default} Draft config set to {olive}%s{default}.", arg);
	}
	else {
		ReplyToCommand(client, "Must specify draft config!");
	}
	
	return Plugin_Handled;
}

public Action:Command_SetCaptain(client, args) {
	if (g_InDraft) {
		ReplyToCommand(client, "Cannot change options while a draft is occurring!");
		return Plugin_Handled;
	}
	
	if (args >= 1) {
		decl String:captainName[64];
		GetCmdArg(1, captainName, sizeof(captainName));
		
		new targets[1];
		new String:targetCaptainName[64];
		new bool:targetNameIsTranslation;
		
		new result = ProcessTargetString(captainName, client, targets, sizeof(targets), COMMAND_FILTER_NO_IMMUNITY|COMMAND_FILTER_NO_MULTI|COMMAND_FILTER_NO_BOTS, targetCaptainName, sizeof(targetCaptainName), targetNameIsTranslation);
		
		if (result == 1) {
			new captain = targets[0];
			
			new TFTeam:team;
			decl String:name[MAX_NAME_LENGTH];
			
			GetClientName(captain, name, sizeof(name));
			
			if (args >= 2) {
				decl String:teamName[16];
				GetCmdArg(2, teamName, sizeof(teamName));
				
				new teamResult = FindTeamByName(teamName);
				
				if (teamResult < 0) {
					if (StringToIntEx(teamName, teamResult) == 0) {
						ReplyToCommand(client, "Must specify a valid team!");
					}
				}
				
				if (teamResult != _:TFTeam_Red && teamResult != _:TFTeam_Blue) {
					ReplyToCommand(client, "Must specify a valid team!");
				}
				else {				
					team = TFTeam:teamResult;
				}
			}
			else {
				team = TFTeam:GetClientTeam(captain);
				
				if (team != TFTeam_Red && team != TFTeam_Blue) {
					ReplyToCommand(client, "The player indicated is not on a team! They must either join a team or a team must be specified as the second argument to this command in order to set them as a team captain.");
				}
			}
			
			if (team == TFTeam_Red) {
				g_RedCaptain = captain;
				
				CPrintToChatAll("{green}[CompCtrl]{default} {olive}%s{default} has been set as the captain for {red}RED{default}.", name);
			}
			else if (team == TFTeam_Blue) {
				g_BluCaptain = captain;
				
				CPrintToChatAll("{green}[CompCtrl]{default} {olive}%s{default} has been set as the captain for {blue}BLU{default}.", name);
			}
		}
		else if (result <= 0) {
			ReplyToTargetError(client, result);
		}
	}
	else {
		ReplyToCommand(client, "Must specify player to be captain!");
	}
	
	return Plugin_Handled;
}

public Action:Command_SetFirstChoice(client, args) {
	if (g_InDraft) {
		ReplyToCommand(client, "Cannot change options while a draft is occurring!");
		return Plugin_Handled;
	}
	
	if (args >= 1) {
		decl String:firstChooser[16];
		GetCmdArg(1, firstChooser, sizeof(firstChooser));
		
		new teamResult = FindTeamByName(firstChooser);
				
		if (teamResult < 0) {
			if (StringToIntEx(firstChooser, teamResult) == 0) {
				ReplyToCommand(client, "Must specify a valid team!");
			}
		}
		
		if (teamResult == _:TFTeam_Red) {
			g_FirstChoice = TFTeam_Red;
			
			CPrintToChatAll("{green}[CompCtrl]{default} First choice given to {red}RED{default}.");
		}
		else if (teamResult != _:TFTeam_Blue) {
			g_FirstChoice = TFTeam_Blue;
			
			CPrintToChatAll("{green}[CompCtrl]{default} First choice given to {blue}BLU{default}.");
		}
		else {
			ReplyToCommand(client, "Must specify a valid team!");
		}
	}
	else {
		ReplyToCommand(client, "Must specify team to get first choice!");
	}
	
	return Plugin_Handled;
}

public Action:Command_Choose(client, args) {
	if (!g_InDraft) {
		ReplyToCommand(client, "Cannot choose while not in a draft!");
		return Plugin_Handled;
	}
	
	if (client != g_RedCaptain && client != g_BluCaptain) {
		ReplyToCommand(client, "Cannot choose if you are not a captain!");
		return Plugin_Handled;
	}
	
	GetDraftChoice(g_CurrentPosition);
	
	new TFTeam:team;
	new choosingTeam = KvGetNum(g_DraftConfig, "team");
							
	if (choosingTeam == 1) {
		team = g_FirstChoice;
	}
	else if (choosingTeam == 2) {
		if (g_FirstChoice == TFTeam_Red) {
			team = TFTeam_Blue;
		}
		else if (g_FirstChoice == TFTeam_Blue) {
			team = TFTeam_Red;
		}
	}
	
	if ((team == TFTeam_Red && client != g_RedCaptain) || (team == TFTeam_Blue && client != g_BluCaptain)) {
		ReplyToCommand(client, "Cannot choose right now!");
		return Plugin_Handled;
	}
	
	if (args < 1) {
		PrepareChoiceMenu();
		DisplayMenu(g_ChoiceMenu, client, MENU_TIME_FOREVER);
		
		return Plugin_Handled;
	}
		
	decl String:name[MAX_NAME_LENGTH];
	GetCmdArg(1, name, sizeof(name));
	
	new targets[1];
	new String:targetPlayerName[64];
	new bool:targetNameIsTranslation;
	
	new result = ProcessTargetString(name, client, targets, sizeof(targets), COMMAND_FILTER_NO_IMMUNITY|COMMAND_FILTER_NO_MULTI|COMMAND_FILTER_NO_BOTS, targetPlayerName, sizeof(targetPlayerName), targetNameIsTranslation);
	
	if (result == 1) {
		new player = targets[0];
		
		if (!IsClientConnected(player) || !IsClientInGame(player) || IsFakeClient(player) || !IsClientAuthorized(player) || IsClientSourceTV(player) || IsClientReplay(player)) {
			ReplyToCommand(client, "Cannot choose an invalid player!");
			return Plugin_Handled;
		}
		
		if (player == g_RedCaptain || player == g_BluCaptain) {
			ReplyToCommand(client, "Cannot choose a captain!");
			return Plugin_Handled;
		}
		
		for (new i = 1; i < g_CurrentPosition; i++) {
			if (GetClientUserId(player) == g_ChosenUserIDs[i]) {
				ReplyToCommand(client, "Cannot choose a player that has already been chosen!");
				return Plugin_Handled;
			}
		}
	
		g_ChosenUserIDs[g_CurrentPosition] = GetClientUserId(player);
		GetClientAuthId(player, AuthId_SteamID64, g_ChosenSteamIDs[g_CurrentPosition], sizeof(g_ChosenSteamIDs[]));
		
		decl String:captainName[MAX_NAME_LENGTH];
		GetClientName(client, captainName, sizeof(captainName));
		decl String:playerName[MAX_NAME_LENGTH];
		GetClientName(player, playerName, sizeof(playerName));
		
		decl String:choiceType[8];
		KvGetString(g_DraftConfig, "type", choiceType, sizeof(choiceType));
		
		if (StrEqual(choiceType, "pick")) {
			ChangeClientTeam(player, _:team);
			
			CPrintToChatAllEx(client, "{green}[CompCtrl]{default} {teamcolor}%s{default} has {olive}picked{default} {teamcolor}%s{default}.", captainName, playerName);
		}
		else if (StrEqual(choiceType, "ban")) {
			CPrintToChatAllEx(client, "{green}[CompCtrl]{default} {teamcolor}%s{default} has {olive}banned{default} {yellow}%s{default}.", captainName, playerName);
		}
		
		BeginNextChoice();
	}
	else if (result <= 0) {
		ReplyToTargetError(client, result);
		return Plugin_Handled;
	}
	
	return Plugin_Handled;
}

public Action:Command_DraftStatus(client, args) {
	if (!g_InDraft) {
		CReplyToCommand(client, "No draft currently occurring.");
	}
	else {
		CReplyToCommand(client, "Drafting with config {olive}%s{default}.", g_DraftConfigName);
		
		new String:bluTeamPlayers[2048];
		new String:redTeamPlayers[2048];
		new String:bannedPlayers[2048];
		new bannedPlayersCount;
		new String:unchosenPlayers[2048];
		new unchosenPlayersCount;
		
		decl String:bluCaptainName[MAX_NAME_LENGTH];
		GetClientName(g_BluCaptain, bluCaptainName, sizeof(bluCaptainName));
		decl String:redCaptainName[MAX_NAME_LENGTH];
		GetClientName(g_RedCaptain, redCaptainName, sizeof(redCaptainName));
		CReplyToCommand(client, "Captains: {blue}%s{default} and {red}%s{default}.", bluCaptainName, redCaptainName);
		
		Format(bluTeamPlayers, sizeof(bluTeamPlayers), "{blue}%s{default} (captain)", bluCaptainName);
		Format(redTeamPlayers, sizeof(redTeamPlayers), "{red}%s{default} (captain)", redCaptainName);
		
		decl String:draftChoices[4096];
		
		for (new i = 1; i < g_CurrentPosition; i++) {
			if (GetDraftChoice(g_CurrentPosition)) {
				new player = GetClientOfUserId(g_ChosenUserIDs[i]);
				
				new captain;
				new TFTeam:team;
				new choosingTeam = KvGetNum(g_DraftConfig, "team");
										
				if (choosingTeam == 1) {
					team = g_FirstChoice;
				}
				else if (choosingTeam == 2) {
					if (g_FirstChoice == TFTeam_Red) {
						team = TFTeam_Blue;
					}
					else if (g_FirstChoice == TFTeam_Blue) {
						team = TFTeam_Red;
					}
				}
				
				if (team == TFTeam_Red) {
					captain = g_RedCaptain;
				}
				else if (team == TFTeam_Blue) {
					captain = g_BluCaptain;
				}
				
				decl String:captainName[MAX_NAME_LENGTH];
				GetClientName(captain, captainName, sizeof(captainName));
				decl String:playerName[MAX_NAME_LENGTH];
				GetClientName(player, playerName, sizeof(playerName));
				
				decl String:choiceType[8];
				KvGetString(g_DraftConfig, "type", choiceType, sizeof(choiceType));
				
				if (i > 1) {
					StrCat(draftChoices, sizeof(draftChoices), "; ");
				}
				
				if (StrEqual(choiceType, "pick")) {
					if (team == TFTeam_Red) {
						Format(draftChoices, sizeof(draftChoices), "%s{red}%s{default} {olive}picked{default} {red}%s{default}.", draftChoices, captainName, playerName);
						
						Format(redTeamPlayers, sizeof(redTeamPlayers), "%s; {red}%s{default}", redTeamPlayers, playerName);
					}
					else if (team == TFTeam_Blue) {
						Format(draftChoices, sizeof(draftChoices), "%s{blue}%s{default} {olive}picked{default} {blue}%s{default}.", draftChoices, captainName, playerName);
						
						Format(bluTeamPlayers, sizeof(bluTeamPlayers), "%s; {blue}%s{default}", bluTeamPlayers, playerName);
					}
				}
				else if (StrEqual(choiceType, "ban")) {
					if (team == TFTeam_Red) {
						Format(draftChoices, sizeof(draftChoices), "%s{red}%s{default} {olive}banned{default} {yellow}%s{default}.", draftChoices, captainName, playerName);
					}
					else if (team == TFTeam_Blue) {
						Format(draftChoices, sizeof(draftChoices), "%s{blue}%s{default} {olive}banned{default} {yellow}%s{default}.", draftChoices, captainName, playerName);
					}
					
					if (bannedPlayersCount > 0) {
						StrCat(bannedPlayers, sizeof(bannedPlayers), "; ");
					}
					
					Format(bannedPlayers, sizeof(bannedPlayers), "%s{yellow}%s{default}", bannedPlayers, playerName);
			
					bannedPlayersCount++;
				}
			}
		}
		
		if (g_CurrentPosition > 1) {
			CReplyToCommand(client, "Draft choices: %s.", draftChoices);
		}
		
		if (GetDraftChoice(g_CurrentPosition)) {
			new captain;
			decl String:captainName[MAX_NAME_LENGTH];
			new TFTeam:team;
			new choosingTeam = KvGetNum(g_DraftConfig, "team");
									
			if (choosingTeam == 1) {
				team = g_FirstChoice;
			}
			else if (choosingTeam == 2) {
				if (g_FirstChoice == TFTeam_Red) {
					team = TFTeam_Blue;
				}
				else if (g_FirstChoice == TFTeam_Blue) {
					team = TFTeam_Red;
				}
			}
			
			if (team == TFTeam_Red) {
				captain = g_RedCaptain;
			}
			else if (team == TFTeam_Blue) {
				captain = g_BluCaptain;
			}
			
			GetClientName(captain, captainName, sizeof(captainName));
			
			decl String:choiceType[8];
			KvGetString(g_DraftConfig, "type", choiceType, sizeof(choiceType));
			
			if (StrEqual(choiceType, "pick")) {
				if (team == TFTeam_Red) {
					CReplyToCommand(client, "Currently choice {olive}%i{default}: {red}%s{default}'s turn to {olive}pick{default} a player.", g_CurrentPosition, captainName);
				}
				else if (team == TFTeam_Blue) {
					CReplyToCommand(client, "Currently choice {olive}%i{default}: {blue}%s{default}'s turn to {olive}pick{default} a player.", g_CurrentPosition, captainName);
				}
			}
			else if (StrEqual(choiceType, "ban")) {
				if (team == TFTeam_Red) {
					CReplyToCommand(client, "Currently choice {olive}%i{default}: {red}%s{default}'s turn to {olive}ban{default} a player.", g_CurrentPosition, captainName);
				}
				else if (team == TFTeam_Blue) {
					CReplyToCommand(client, "Currently choice {olive}%i{default}: {blue}%s{default}'s turn to {olive}ban{default} a player.", g_CurrentPosition, captainName);
				}
			}
		}
		
		CReplyToCommand(client, "{blue}BLU{default} team: %s.", bluTeamPlayers);
		CReplyToCommand(client, "{red}RED{default} team: %s.", redTeamPlayers);
		if (bannedPlayersCount > 0) {
			CReplyToCommand(client, "{yellow}Banned{default}: %s.", bannedPlayers);
		}
		
		for (new i = 1; i <= MaxClients; i++) {
			if (!IsClientConnected(i) || !IsClientInGame(i) || IsFakeClient(i) || !IsClientAuthorized(i) || IsClientSourceTV(i) || IsClientReplay(i)) {
				continue;
			}
			
			if (g_RedCaptain == i || g_BluCaptain == i) {
				continue;
			}
			
			new bool:chosen = false;
			
			for (new j = 1; j < g_CurrentPosition; j++) {
				if (GetClientUserId(i) == g_ChosenUserIDs[j]) {
					chosen = true;
					break;
				}
			}
			
			if (chosen) {
				continue;
			}
			
			decl String:name[MAX_NAME_LENGTH];
			GetClientName(i, name, sizeof(name));
			
			if (unchosenPlayersCount > 0) {
				StrCat(unchosenPlayers, sizeof(unchosenPlayers), "; ");
			}
			
			Format(unchosenPlayers, sizeof(unchosenPlayers), "%s{gray}%s{default}", unchosenPlayers, name);
			
			unchosenPlayersCount++;
		}
		
		if (unchosenPlayersCount > 0) {
			CReplyToCommand(client, "{gray}Unchosen{default}: %s.", bannedPlayers);
		}
	}
	
	return Plugin_Handled;
}

public Action:Command_ChangeTeam(client, const String:command[], argc) {
	if (!IsClientConnected(client) || !IsClientInGame(client)) {
		ReplyToCommand(client, "Cannot change teams!");
		return Plugin_Stop;
	}
	
	if (g_InDraft) {
		PrintToChat(client, "Cannot change your team manually while a draft is occurring!");
		return Plugin_Stop;
	}
	
	return Plugin_Continue;
}

public Menu_Choose(Handle:menu, MenuAction:action, param1, param2) {
	if (action == MenuAction_Select) {
		decl String:userid[8];
		
		if (GetMenuItem(g_ChoiceMenu, param2, userid, sizeof(userid))) {
			ClientCommand(param1, "sm_choose %s", userid);
		}
	}
}

OpenDraft() {
	g_InDraft = true;
	g_CurrentPosition = 0;
	
	for (new i = 1; i <= MaxClients; i++) {
		if (IsClientConnected(i) && IsClientInGame(i)) {
			if (g_RedCaptain == i) {
				ChangeClientTeam(i, _:TFTeam_Red);
			}
			else if (g_BluCaptain == i) {
				ChangeClientTeam(i, _:TFTeam_Blue);
			}
			else {
				ChangeClientTeam(i, _:TFTeam_Spectator);
			}
		}
	}
	
	decl String:bluCaptainName[MAX_NAME_LENGTH];
	GetClientName(g_BluCaptain, bluCaptainName, sizeof(bluCaptainName));
	decl String:redCaptainName[MAX_NAME_LENGTH];
	GetClientName(g_RedCaptain, redCaptainName, sizeof(redCaptainName));
	
	CPrintToChatAll("{green}[CompCtrl]{default} Draft started with config {olive}%s{default}, with captains {blue}%s{default} and {red}%s{default}.", g_DraftConfigName, bluCaptainName, redCaptainName);
}

CloseDraft() {
	g_InDraft = false;
	
	for (new i = 1; i <= MAXPLAYERS; i++) {
		g_ChosenUserIDs[i] = 0;
		g_ChosenSteamIDs[i] = "";
	}
}

BeginNextChoice() {
	CancelMenu(g_ChoiceMenu);
	
	g_CurrentPosition++;
	
	if (GetDraftChoice(g_CurrentPosition)) {
		new captain;
		decl String:captainName[MAX_NAME_LENGTH];
		new TFTeam:team;
		new choosingTeam = KvGetNum(g_DraftConfig, "team");
								
		if (choosingTeam == 1) {
			team = g_FirstChoice;
		}
		else if (choosingTeam == 2) {
			if (g_FirstChoice == TFTeam_Red) {
				team = TFTeam_Blue;
			}
			else if (g_FirstChoice == TFTeam_Blue) {
				team = TFTeam_Red;
			}
		}
		else {
			CPrintToChatAll("{green}[CompCtrl]{default} Invalid configuration. Aborting draft!");
			
			CloseDraft();
			
			return;
		}
		
		if (team == TFTeam_Red) {
			captain = g_RedCaptain;
		}
		else if (team == TFTeam_Blue) {
			captain = g_BluCaptain;
		}
		
		GetClientName(captain, captainName, sizeof(captainName));
		
		decl String:choiceType[8];
		KvGetString(g_DraftConfig, "type", choiceType, sizeof(choiceType));
		
		if (StrEqual(choiceType, "pick")) {
			CPrintToChatAllEx(captain, "{green}[CompCtrl]{default} Choice {olive}%i{default}: {teamcolor}%s{default}'s turn to {olive}pick{default} a player.", g_CurrentPosition, captainName);
		}
		else if (StrEqual(choiceType, "ban")) {
			CPrintToChatAllEx(captain, "{green}[CompCtrl]{default} Choice {olive}%i{default}: {teamcolor}%s{default}'s turn to {olive}ban{default} a player.", g_CurrentPosition, captainName);
		}
		else {
			CPrintToChatAll("{green}[CompCtrl]{default} Invalid configuration. Aborting draft!");
			
			CloseDraft();
			
			return;
		}
	}
	else {
		CPrintToChatAll("{green}[CompCtrl]{default} Draft completed.");
		
		CloseDraft();
	}
}

PrepareChoiceMenu() {
	CancelMenu(g_ChoiceMenu);
	RemoveAllMenuItems(g_ChoiceMenu);
	
	for (new client = 1; client <= MaxClients; client++) {
		if (!IsClientConnected(client) || !IsClientInGame(client) || IsFakeClient(client) || !IsClientAuthorized(client) || IsClientSourceTV(client) || IsClientReplay(client)) {
			continue;
		}
		
		if (g_RedCaptain == client || g_BluCaptain == client) {
			continue;
		}
		
		new bool:chosen = false;
		
		for (new i = 1; i < g_CurrentPosition; i++) {
			if (GetClientUserId(client) == g_ChosenUserIDs[i]) {
				chosen = true;
				break;
			}
		}
		
		if (chosen) {
			continue;
		}
		
		decl String:userid[8];
		Format(userid, sizeof(userid), "#%i", GetClientUserId(client));
		decl String:name[MAX_NAME_LENGTH];
		GetClientName(client, name, sizeof(name));
		
		AddMenuItem(g_ChoiceMenu, userid, name);
	}
}

bool:GetDraftChoice(choice) {
	decl String:draftPosition[4];
	IntToString(choice, draftPosition, sizeof(draftPosition));
	
	KvRewind(g_DraftConfig);
	return KvJumpToKey(g_DraftConfig, draftPosition);
}