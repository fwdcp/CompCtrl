#include <sourcemod>

#include <compctrl>
#include <morecolors>
#include <sdktools>

new Handle:g_Tournament = INVALID_HANDLE;
new Handle:g_RedTeamName = INVALID_HANDLE;
new Handle:g_BlueTeamName = INVALID_HANDLE;

public Plugin:myinfo =
{
	name = "CompCtrl Scoring Management",
	author = "Forward Command Post",
	description = "a plugin to manage scoring in tournament mode",
	version = "0.0.0",
	url = "http://github.com/fwdcp/CompCtrl/"
};

public OnPluginStart() {
	g_Tournament = FindConVar("mp_tournament");
	g_RedTeamName = FindConVar("mp_tournament_redteamname");
	g_BlueTeamName = FindConVar("mp_tournament_blueteamname");
}

public Action:CompCtrl_OnSetWinningTeam(&TFTeam:team, &WinReason:reason, &bool:forceMapReset, &bool:switchTeams, &bool:dontAddScore) {
	if (GetConVarBool(g_Tournament)) {
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
		
		CPrintToChatAll("[CompCtrl] Current score: {blue}%s{default} {olive}%i{default}, {red}%s{default} {olive}%i{default}", bluName, bluScore, redName, redScore);
	}
	
	return Plugin_Continue;
}
