#include <sourcemod>

#include <compctrl>
#include <morecolors>
#include <sdktools>

new Handle:g_MatchConfigs = INVALID_HANDLE;
new bool:g_InMatch = false;
new String:g_MatchConfigName[256];
new bool:g_InPeriod = false;
new String:g_CurrentPeriod[256];
new bool:g_SwitchTeams = false;
new bool:g_ReadiedUp = false;
new bool:g_PeriodNeedsSetup = false;
new bool:g_AllowScoreReset = false;
new g_RoundsPlayed;

new Handle:g_Tournament = INVALID_HANDLE;
new Handle:g_TournamentNonAdminRestart = INVALID_HANDLE;
new Handle:g_RedTeamName = INVALID_HANDLE;
new Handle:g_BlueTeamName = INVALID_HANDLE;
new Handle:g_TimeLimit = INVALID_HANDLE;
new Handle:g_WinLimit = INVALID_HANDLE;
new Handle:g_WinDifference = INVALID_HANDLE;
new Handle:g_WinDifferenceMin = INVALID_HANDLE;
new Handle:g_MaxRounds = INVALID_HANDLE;

public Plugin:myinfo =
{
	name = "CompCtrl Match Management",
	author = "Forward Command Post",
	description = "a plugin to manage scoring in tournament mode",
	version = "0.0.0",
	url = "http://github.com/fwdcp/CompCtrl/"
};

public OnPluginStart() {
	g_MatchConfigs = CreateKeyValues("compctrl-matches");
	decl String:configPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, configPath, sizeof(configPath), "configs/compctrl-matches.cfg");
	FileToKeyValues(g_MatchConfigs, configPath);
	
	RegAdminCmd("sm_match", Command_SetupMatch, ADMFLAG_CONFIG, "sets up a match regulated by CompCtrl with the specified config", "compctrl");
	
	g_Tournament = FindConVar("mp_tournament");
	g_TournamentNonAdminRestart = FindConVar("mp_tournament_allow_non_admin_restart");
	g_RedTeamName = FindConVar("mp_tournament_redteamname");
	g_BlueTeamName = FindConVar("mp_tournament_blueteamname");
	g_TimeLimit = FindConVar("mp_timelimit");
	g_WinLimit = FindConVar("mp_winlimit");
	g_WinDifference = FindConVar("mp_windifference");
	g_WinDifferenceMin = FindConVar("mp_windifference_min");
	g_MaxRounds = FindConVar("mp_maxrounds");
	
	HookEvent("teamplay_round_start", Event_RoundStart);
}

public Action:Command_SetupMatch(client, args) {
	KvRewind(g_MatchConfigs);
	
	decl String:arg[256];
	GetCmdArg(1, arg, sizeof(arg));
	
	if (!KvJumpToKey(g_MatchConfigs, arg)) {
		ReplyToCommand(client, "No such match config exists!");
		KvRewind(g_MatchConfigs);
		return Plugin_Handled;
	}
	
	if (!KvJumpToKey(g_MatchConfigs, "periods") || !KvGotoFirstSubKey(g_MatchConfigs)) {
		ReplyToCommand(client, "Match config is invalid!");
		KvRewind(g_MatchConfigs);
		return Plugin_Handled;
	}
	
	SetConVarBool(g_Tournament, true, true, true);
	SetConVarBool(g_TournamentNonAdminRestart, false);
	g_InMatch = true;
	g_AllowScoreReset = true;
	strcopy(g_MatchConfigName, sizeof(g_MatchConfigName), arg);
	KvGetSectionName(g_MatchConfigs, g_CurrentPeriod, sizeof(g_CurrentPeriod));
	
	CPrintToChatAll("{green}[CompCtrl]{default} Match has been set up with config {olive}%s{default}.", arg);
	
	BeginPeriod();
	
	KvRewind(g_MatchConfigs);
	return Plugin_Handled;
}

public Event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast) {
	if (g_InMatch) {
		g_AllowScoreReset = false;
		g_SwitchTeams = false;
		
		GetCurrentRoundConfig();
		
		if (g_RoundsPlayed == 0) {
			decl String:periodName[256];
			KvGetString(g_MatchConfigs, "name", periodName, sizeof(periodName), "period");
			
			CPrintToChatAll("{green}[CompCtrl]{default} Starting {olive}%s{default}.", periodName);
			
			g_InPeriod = true;
		}
		
		new currentRound = g_RoundsPlayed + 1;
		
		if (KvGetNum(g_MatchConfigs, "timelimit", 0) > 0) {
			new timeLeft;
			GetMapTimeLeft(timeLeft);
			
			CPrintToChatAll("{green}[CompCtrl]{default} Period status: round {olive}%i{default} with {olive}%i:%02i{default} remaining.", currentRound, timeLeft / 60, timeLeft % 60);
		}
		else {
			CPrintToChatAll("{green}[CompCtrl]{default} Period status: round {olive}%i{default}.", currentRound);
		}
		
		new redScore = GetTeamScore(_:TFTeam_Red);
		new bluScore = GetTeamScore(_:TFTeam_Blue);
		
		decl String:redName[256];
		GetConVarString(g_RedTeamName, redName, sizeof(redName));
		decl String:bluName[256];
		GetConVarString(g_BlueTeamName, bluName, sizeof(bluName));
		
		CPrintToChatAll("{green}[CompCtrl]{default} Current score: {blue}%s{default} {olive}%i{default}, {red}%s{default} {olive}%i{default}.", bluName, bluScore, redName, redScore);
	}
}

public Action:CompCtrl_OnSetWinningTeam(&TFTeam:team, &WinReason:reason, &bool:forceMapReset, &bool:switchTeams, &bool:dontAddScore) {
	if (g_InMatch) {
		new redScore = GetTeamScore(_:TFTeam_Red);
		new bluScore = GetTeamScore(_:TFTeam_Blue);
		
		decl String:redName[256];
		GetConVarString(g_RedTeamName, redName, sizeof(redName));
		decl String:bluName[256];
		GetConVarString(g_BlueTeamName, bluName, sizeof(bluName));
		
		if (!dontAddScore) {
			if (team == TFTeam_Red) {
				redScore++;
			}
			else if (team == TFTeam_Blue) {
				bluScore++;
			}
		}
		
		g_RoundsPlayed++;
		
		new EndCondition:endCondition;
		new TFTeam:cause;
		
		if (!CheckEndConditions(redScore, bluScore, endCondition, cause)) {
			GetCurrentRoundConfig();
			
			if (KvGetNum(g_MatchConfigs, "switch-teams-each-round")) {
				g_SwitchTeams = true;
			}
		}
		else {
			EndPeriod(redScore, bluScore, endCondition, cause);
		}
		
		if (g_SwitchTeams) {
			switchTeams = true;
			g_SwitchTeams = false;
			return Plugin_Changed;
		}
	}
	
	return Plugin_Continue;
}

public Action:CompCtrl_OnRestartTournament() {
	if (g_InMatch && g_PeriodNeedsSetup) {
		BeginPeriod();
		g_PeriodNeedsSetup = false;
	}
	
	return Plugin_Continue;
}

public Action:CompCtrl_OnResetTeamScores(TFTeam:team) {
	if (g_InMatch && !g_AllowScoreReset) {
		if (team == TFTeam_Red || team == TFTeam_Blue) {
			return Plugin_Stop;
		}
	}
	
	return Plugin_Continue;
}

GetCurrentRoundConfig() {
	KvRewind(g_MatchConfigs);
	
	if (!KvJumpToKey(g_MatchConfigs, g_MatchConfigName) || !KvJumpToKey(g_MatchConfigs, "periods") || !KvJumpToKey(g_MatchConfigs, g_CurrentPeriod)) {
		ThrowError("Failed to find period!");
	}
}

BeginPeriod() {
	GetCurrentRoundConfig();
	
	SetConVarInt(g_TimeLimit, KvGetNum(g_MatchConfigs, "timelimit", 0), true, true);
	SetConVarInt(g_WinLimit, KvGetNum(g_MatchConfigs, "winlimit", 0), true, true);
	SetConVarInt(g_WinDifference, KvGetNum(g_MatchConfigs, "windifference", 0), true, true);
	SetConVarInt(g_WinDifferenceMin, KvGetNum(g_MatchConfigs, "windifference-min", 0), true, true);
	SetConVarInt(g_MaxRounds, KvGetNum(g_MatchConfigs, "maxrounds", 0), true, true);
	
	g_RoundsPlayed = 0;
	
	decl String:periodName[256];
	KvGetString(g_MatchConfigs, "name", periodName, sizeof(periodName), "period");
	
	CPrintToChatAll("{green}[CompCtrl]{default} The next period will be: {olive}%s{default}.", periodName);
	
	new String:winConditionInformation[512] = "{green}[CompCtrl]{default} This period will end upon the fulfillment of one of the following:";
	if (KvGetNum(g_MatchConfigs, "timelimit", 0) > 0) {
		if (!StrEqual(winConditionInformation, "{green}[CompCtrl]{default} This period will end upon the fulfillment of one of the following:")) {
			StrCat(winConditionInformation, sizeof(winConditionInformation), ";");
		}
		
		Format(winConditionInformation, sizeof(winConditionInformation), "%s {olive}time limit %i{default}", winConditionInformation, KvGetNum(g_MatchConfigs, "timelimit", 0));
	}
	if (KvGetNum(g_MatchConfigs, "winlimit", 0) > 0) {
		if (!StrEqual(winConditionInformation, "{green}[CompCtrl]{default} This period will end upon the fulfillment of one of the following:")) {
			StrCat(winConditionInformation, sizeof(winConditionInformation), ";");
		}
		
		Format(winConditionInformation, sizeof(winConditionInformation), "%s {olive}win limit %i{default}", winConditionInformation, KvGetNum(g_MatchConfigs, "winlimit", 0));
	}
	if (KvGetNum(g_MatchConfigs, "windifference", 0) > 0) {
		if (!StrEqual(winConditionInformation, "{green}[CompCtrl]{default} This period will end upon the fulfillment of one of the following:")) {
			StrCat(winConditionInformation, sizeof(winConditionInformation), ";");
		}
		
		Format(winConditionInformation, sizeof(winConditionInformation), "%s {olive}win difference %i{default} (with {olive}minimum score %i{default})", winConditionInformation, KvGetNum(g_MatchConfigs, "windifference", 0), KvGetNum(g_MatchConfigs, "windifference-min", 0));
	}
	if (KvGetNum(g_MatchConfigs, "maxrounds", 0) > 0) {
		
		Format(winConditionInformation, sizeof(winConditionInformation), "%s {olive}max rounds %i{default}", winConditionInformation, KvGetNum(g_MatchConfigs, "maxrounds", 0));
	}
	
	if (!StrEqual(winConditionInformation, "{green}[CompCtrl]{default} This period will end upon the fulfillment of one of the following:")) {
		StrCat(winConditionInformation, sizeof(winConditionInformation), ".");
	}
	else {
		winConditionInformation = "{green}[CompCtrl]{default} This period does not have any end conditions.";
	}
	
	CPrintToChatAll(winConditionInformation);
	
	decl String:nextPeriod[256];
	KvGetString(g_MatchConfigs, "next-period", nextPeriod, sizeof(nextPeriod), g_CurrentPeriod);
	decl String:nextPeriodName[256];
	KvRewind(g_MatchConfigs);
	if (!KvJumpToKey(g_MatchConfigs, g_MatchConfigName) || !KvJumpToKey(g_MatchConfigs, "periods") || !KvJumpToKey(g_MatchConfigs, nextPeriod)) {
		ThrowError("Failed to find period!");
	}
	KvGetString(g_MatchConfigs, "name", nextPeriodName, sizeof(nextPeriodName));
	
	GetCurrentRoundConfig();
	
	if (KvGetNum(g_MatchConfigs, "end-game", 1)) {
		if (KvGetNum(g_MatchConfigs, "allow-tie", 0)) {
			CPrintToChatAll("{green}[CompCtrl]{default} Upon completion of this period, the match will end, even if there is a tie.");
		}
		else {
			CPrintToChatAll("{green}[CompCtrl]{default} Upon completion of this period, the match will end if a team is leading. If there is a tie, the match will proceed to the {olive}%s{default} period.", nextPeriodName);
		}
	}
	else {
		CPrintToChatAll("{green}[CompCtrl]{default} Upon completion of this period, the match will proceed to the {olive}%s{default} period.", nextPeriodName);
	}
}

bool:CheckEndConditions(redScore, bluScore, &EndCondition:endCondition, &TFTeam:cause) {
	GetCurrentRoundConfig();
	
	new timeLimit = KvGetNum(g_MatchConfigs, "timelimit", 0);
	
	if (timeLimit > 0) {
		new timeLeft;
		GetMapTimeLeft(timeLeft);
		
		if (timeLeft <= 0) {
			endCondition = EndCondition_TimeLimit;
			cause = TFTeam_Unassigned;
			return true;
		}
	}
	
	new winLimit = KvGetNum(g_MatchConfigs, "winlimit", 0);
	
	if (winLimit > 0) {
		if (redScore >= winLimit) {
			endCondition = EndCondition_WinLimit;
			cause = TFTeam_Red;
			return true;
		}
		else if (bluScore >= winLimit) {
			endCondition = EndCondition_WinLimit;
			cause = TFTeam_Blue;
			return true;
		}
	}
	
	new winDifference = KvGetNum(g_MatchConfigs, "windifference", 0);
	
	if (winDifference > 0) {
		new winDifferenceMin = KvGetNum(g_MatchConfigs, "windifference-min", 0);
		
		if (redScore >= winDifferenceMin && redScore - bluScore >= winDifference) {
			endCondition = EndCondition_WinDifference;
			cause = TFTeam_Red;
			return true;
		}
		else if (bluScore >= winDifferenceMin && bluScore - redScore >= winDifference) {
			endCondition = EndCondition_WinDifference;
			cause = TFTeam_Blue;
			return true;
		}
	}
	
	new maxRounds = KvGetNum(g_MatchConfigs, "maxrounds", 0);
	
	if (maxRounds > 0) {
		if (g_RoundsPlayed >= maxRounds) {
			endCondition = EndCondition_MaxRounds;
			cause = TFTeam_Unassigned;
			return true;
		}
	}
	
	endCondition = EndCondition_None;
	cause = TFTeam_Unassigned;
	return false;
}

EndPeriod(redScore, bluScore, EndCondition:endCondition, TFTeam:cause) {
	g_InPeriod = false;
	
	GetCurrentRoundConfig();
	
	decl String:periodName[256];
	KvGetString(g_MatchConfigs, "name", periodName, sizeof(periodName), "period");

	decl String:redName[256];
	GetConVarString(g_RedTeamName, redName, sizeof(redName));
	decl String:bluName[256];
	GetConVarString(g_BlueTeamName, bluName, sizeof(bluName));
	
	if (endCondition == EndCondition_TimeLimit) {
		CPrintToChatAll("{green}[CompCtrl]{default} The {olive}%s{default} ends because the {olive}time limit{default} of {olive}%i{default} has expired.", periodName, KvGetNum(g_MatchConfigs, "timelimit", 0));
	}
	else if (endCondition == EndCondition_WinLimit) {
		if (cause == TFTeam_Red) {
			CPrintToChatAll("{green}[CompCtrl]{default} The {olive}%s{default} ends because {red}%s{default} has reached the {olive}win limit{default} of {olive}%i{default}.", periodName, redName, KvGetNum(g_MatchConfigs, "winlimit", 0));
		}
		else if (cause == TFTeam_Blue) {
			CPrintToChatAll("{green}[CompCtrl]{default} The {olive}%s{default} ends because {blue}%s{default} has reached the {olive}win limit{default} of {olive}%i{default}.", periodName, bluName, KvGetNum(g_MatchConfigs, "winlimit", 0));
		}
	}
	else if (endCondition == EndCondition_WinDifference) {
		if (cause == TFTeam_Red) {
			CPrintToChatAll("{green}[CompCtrl]{default} The {olive}%s{default} ends because {red}%s{default} has reached the {olive}win difference{default} of {olive}%i{default} (with a minimum score of {olive}%i{default}).", periodName, redName, KvGetNum(g_MatchConfigs, "windifference", 0), KvGetNum(g_MatchConfigs, "windifference-min", 0));
		}
		else if (cause == TFTeam_Blue) {
			CPrintToChatAll("{green}[CompCtrl]{default} The {olive}%s{default} ends because {blue}%s{default} has reached the {olive}win difference{default} of {olive}%i{default} (with a minimum score of {olive}%i{default}).", periodName, bluName, KvGetNum(g_MatchConfigs, "windifference", 0), KvGetNum(g_MatchConfigs, "windifference-min", 0));
		}
	}
	else if (endCondition == EndCondition_TimeLimit) {
		CPrintToChatAll("{green}[CompCtrl]{default} The {olive}%s{default} ends because the {olive}max rounds{default} of {olive}%i{default} has been reached.", periodName, KvGetNum(g_MatchConfigs, "maxrounds", 0));
	}
	
	decl String:nextPeriod[256];
	KvGetString(g_MatchConfigs, "next-period", nextPeriod, sizeof(nextPeriod), g_CurrentPeriod);
	
	if (KvGetNum(g_MatchConfigs, "end-game", 1)) {
		if (redScore == bluScore && !KvGetNum(g_MatchConfigs, "allow-tie", 0)) {
			CPrintToChatAll("{green}[CompCtrl]{default} Score after {olive}%s{default}: {blue}%s{default} {olive}%i{default}, {red}%s{default} {olive}%i{default}.", periodName, bluName, bluScore, redName, redScore);
			CPrintToChatAll("{green}[CompCtrl]{default} Because no team has a lead, the match cannot end after this period and will proceed to another period.");
			
			strcopy(g_CurrentPeriod, sizeof(g_CurrentPeriod), nextPeriod);
			
			GetCurrentRoundConfig();
			if (KvGetNum(g_MatchConfigs, "switch-teams-to-begin", 0)) {
				g_SwitchTeams = true;
			}
			
			g_PeriodNeedsSetup = true;
		}
		else {
			CPrintToChatAll("{green}[CompCtrl]{default} The match is now over.");
			CPrintToChatAll("{green}[CompCtrl]{default} Final score: {blue}%s{default} {olive}%i{default}, {red}%s{default} {olive}%i{default}.", bluName, bluScore, redName, redScore);
			
			g_InMatch = false;
			g_AllowScoreReset = true;
		}
	}
	else {
		CPrintToChatAll("{green}[CompCtrl]{default} Score after {olive}%s{default}: {blue}%s{default} {olive}%i{default}, {red}%s{default} {olive}%i{default}.", periodName, bluName, bluScore, redName, redScore);
		CPrintToChatAll("{green}[CompCtrl]{default} The match will continue to the next period.");
		
		strcopy(g_CurrentPeriod, sizeof(g_CurrentPeriod), nextPeriod);
			
		GetCurrentRoundConfig();
		if (KvGetNum(g_MatchConfigs, "switch-teams-to-begin", 0)) {
			g_SwitchTeams = true;
		}
			
		g_PeriodNeedsSetup = true;
	}
}