#include <sourcemod>

#include <compctrl_version>
#include <compctrl_extension>
#include <morecolors>

new Handle:g_Delay = INVALID_HANDLE;
new Handle:g_DelayEnabled = INVALID_HANDLE;

public Plugin:myinfo =
{
	name = "CompCtrl Map Change Management",
	author = "Forward Command Post",
	description = "a plugin to ensure map changes are properly done",
	version = COMPCTRL_VERSION,
	url = "http://github.com/fwdcp/CompCtrl/"
};

public OnPluginStart() {
	g_Delay = FindConVar("tv_delay");
	g_DelayEnabled = FindConVar("tv_delaymapchange");
	
	AddCommandListener(Command_ChangeLevel, "changelevel");
}

public Action:CompCtrl_OnChangeLevel(const String:s1[], const String:s2[]) {
	if (GetConVarBool(g_DelayEnabled)) {
		new Float:delay = GetConVarFloat(g_Delay);
		CPrintToChatAll("{green}[CompCtrl]{default} Map change to {olive}%s{default} will occur in {olive}%i{default} seconds.", s1, RoundToNearest(delay));
		PrintToServer("[CompCtrl] Map change to %s will occur in %i seconds.", s1, RoundToNearest(delay));
		
		new Handle:timerData;
		CreateDataTimer(delay, Timer_ChangeMap, timerData, TIMER_FLAG_NO_MAPCHANGE);
		
		ResetPack(timerData);
		WritePackString(timerData, s1);
		WritePackString(timerData, s2);
		
		return Plugin_Stop;
	}
	
	CPrintToChatAll("{green}[CompCtrl]{default} Map is being changed to {olive}%s{default}.", s1);
	PrintToServer("[CompCtrl] Map is being changed to %s.", s1);
	
	return Plugin_Continue;
}

public Action:Command_ChangeLevel(client, const String:command[], argc) {
	decl String:map[128];
	
	GetCmdArg(1, map, sizeof(map));
	
	if (GetConVarBool(g_DelayEnabled)) {
		new Float:delay = GetConVarFloat(g_Delay);
		CPrintToChatAll("{green}[CompCtrl]{default} Map change to {olive}%s{default} will occur in {olive}%i{default} seconds.", map, RoundToNearest(delay));
		PrintToServer("[CompCtrl] Map change to %s will occur in %i seconds.", map, RoundToNearest(delay));
		
		new Handle:timerData;
		CreateDataTimer(delay, Timer_ChangeMap, timerData, TIMER_FLAG_NO_MAPCHANGE);
		
		ResetPack(timerData);
		WritePackString(timerData, map);
		WritePackString(timerData, "");
		
		return Plugin_Stop;
	}
	
	CPrintToChatAll("{green}[CompCtrl]{default} Map is being changed to {olive}%s{default}.", map);
	PrintToServer("[CompCtrl] Map is being changed to %s.", map);
	
	return Plugin_Continue;
}

public Action:Timer_ChangeMap(Handle:timer, Handle:hndl) {
	decl String:s1[128];
	decl String:s2[128];
	
	ResetPack(hndl);
	ReadPackString(hndl, s1, sizeof(s1));
	ReadPackString(hndl, s2, sizeof(s2));
	
	CPrintToChatAll("{green}[CompCtrl]{default} Map is being changed to {olive}%s{default}.", s1);
	PrintToServer("[CompCtrl] Map is being changed to %s.", s1);
	
	CompCtrl_ChangeLevel(s1, s2);
	
	return Plugin_Stop;
}