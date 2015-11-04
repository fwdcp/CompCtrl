#include <sourcemod>

#include <compctrl_version>
#include <compctrl_extension>
#include <morecolors>
#include <sdktools_entinput>
#include <sdktools_functions>
#include <sdktools_gamerules>

bool g_StrategyPeriodActive = false;
bool g_StrategyPeriodCompleted = false;
bool g_StrategyPeriodPause = false;
int g_StrategyPeriodTimer = -1;
float g_TransitionTime = 0.0;

Handle g_OnStart;

ConVar g_Time;

public Plugin myinfo =
{
	name = "CompCtrl Strategy Periods",
	author = "Forward Command Post",
	description = "a plugin to add in strategy periods between rounds",
	version = COMPCTRL_VERSION,
	url = "http://github.com/fwdcp/CompCtrl/"
};

public void OnPluginStart() {
	g_Time = CreateConVar("compctrl_strategyperiods_time", "15", "the amount of time between rounds");

	RegConsoleCmd("sm_cancelpause", Command_CancelPause, "cancels any strategy period pauses");
	RegConsoleCmd("sm_requestpause", Command_RequestPause, "pauses the game at the soonest strategy period");

	g_OnStart = CreateGlobalForward("CompCtrl_OnStrategyPeriodBegin", ET_Hook);

	HookEvent("teamplay_round_start", Event_RoundStart);
}

public Action Command_CancelPause(int client, int args) {
	if (g_StrategyPeriodPause) {
		if (g_StrategyPeriodActive) {
			g_TransitionTime = GetGameTime() + g_Time.FloatValue;

			if (g_StrategyPeriodTimer != -1) {
				SetVariantInt(RoundToCeil(g_Time.FloatValue));
				AcceptEntityInput(g_StrategyPeriodTimer, "SetTime");
				AcceptEntityInput(g_StrategyPeriodTimer, "Resume");
			}

			g_StrategyPeriodPause = false;

			CPrintToChatAll("{green}[CompCtrl]{default} Current strategy period pause has been ended.");
		}
		else {
			g_StrategyPeriodPause = false;

			CPrintToChatAll("{green}[CompCtrl]{default} Next strategy period pause has been canceled.");
		}
	}
	else {
		CReplyToCommand(client, "{green}[CompCtrl]{default} No strategy period pause to cancel!");
	}
}

public Action Command_RequestPause(int client, int args) {
	if (!g_StrategyPeriodPause) {
		if (g_StrategyPeriodActive) {
			g_StrategyPeriodPause = true;

			if (g_StrategyPeriodTimer != -1) {
				SetVariantInt(RoundToCeil(g_Time.FloatValue));
				AcceptEntityInput(g_StrategyPeriodTimer, "SetTime");
				AcceptEntityInput(g_StrategyPeriodTimer, "Pause");
			}

			CPrintToChatAll("{green}[CompCtrl]{default} Current strategy period has been paused.");
		}
		else {
			g_StrategyPeriodPause = true;

			CPrintToChatAll("{green}[CompCtrl]{default} Pause has been scheduled for the next strategy period.");
		}
	}
	else {
		if (g_StrategyPeriodActive) {
			CReplyToCommand(client, "{green}[CompCtrl]{default} Strategy period is already paused!");
		}
		else {
			CReplyToCommand(client, "{green}[CompCtrl]{default} Strategy period pause is already scheduled!");
		}
	}
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast) {
	if (g_Time.FloatValue > 0.0) {
		Call_StartForward(g_OnStart);

		Action result;
		Call_Finish(result);
		if (result == Plugin_Continue) {
			RequestFrame(StrategyPeriodRequested);
		}
	}
}

public Action CompCtrl_OnBetweenRoundsStart() {
	if (!g_StrategyPeriodActive) {
		return Plugin_Continue;
	}

	SetUpStrategyPeriod();

	return Plugin_Handled;
}

public Action CompCtrl_OnBetweenRoundsEnd() {
	if (!g_StrategyPeriodActive) {
		return Plugin_Continue;
	}

	TearDownStrategyPeriod();

	return Plugin_Handled;
}

public Action CompCtrl_OnBetweenRoundsThink() {
	if (!g_StrategyPeriodActive) {
		return Plugin_Continue;
	}

	MaintainStrategyPeriod();

	if (!g_StrategyPeriodPause && GetGameTime() >= g_TransitionTime) {
		CompCtrl_StateTransition(RoundState_Preround);
	}

	return Plugin_Handled;
}

public Action CompCtrl_OnStrategyPeriodBegin() {
	if (GameRules_GetProp("m_bInWaitingForPlayers")) {
		return Plugin_Stop;
	}

	if (g_StrategyPeriodCompleted) {
		g_StrategyPeriodCompleted = false;
		return Plugin_Stop;
	}

	return Plugin_Continue;
}

public void StrategyPeriodRequested(any data) {
	g_StrategyPeriodActive = true;
	CompCtrl_StateTransition(RoundState_BetweenRounds);
}

void SetUpStrategyPeriod() {
	g_TransitionTime = GetGameTime() + g_Time.FloatValue;

	int timer = FindEntityByClassname(-1, "team_round_timer");

	while (timer != -1) {
		AcceptEntityInput(timer, "Disable");

		timer = FindEntityByClassname(timer, "team_round_timer");
	}

	g_StrategyPeriodTimer = CreateEntityByName("team_round_timer");

	if (g_StrategyPeriodTimer != -1) {
		DispatchKeyValue(g_StrategyPeriodTimer, "targetname", "zz_teamplay_strategyperiod_timer");

		if (g_StrategyPeriodPause) {
			DispatchKeyValue(g_StrategyPeriodTimer, "start_paused", "1");
		}
		else {
			DispatchKeyValue(g_StrategyPeriodTimer, "start_paused", "0");
		}

		DispatchKeyValue(g_StrategyPeriodTimer, "auto_countdown", "0");
		DispatchKeyValue(g_StrategyPeriodTimer, "show_in_hud", "1");
		DispatchSpawn(g_StrategyPeriodTimer);

		SetVariantInt(RoundToCeil(g_Time.FloatValue));
		AcceptEntityInput(g_StrategyPeriodTimer, "SetTime");

		AcceptEntityInput(g_StrategyPeriodTimer, "Enable");
	}

	CPrintToChatAll("{green}[CompCtrl]{default} Strategy period has begun.");

	if (g_StrategyPeriodPause) {
		CPrintToChatAll("{green}[CompCtrl]{default} The strategy period begins paused as requested.");
	}
}

void MaintainStrategyPeriod() {
	float endTime = g_StrategyPeriodPause ? GetGameTime() + g_Time.FloatValue : g_TransitionTime;

	if (g_StrategyPeriodPause) {
		if (g_StrategyPeriodTimer != -1) {
			AcceptEntityInput(g_StrategyPeriodTimer, "Pause");
			SetVariantInt(RoundToCeil(g_Time.FloatValue));
			AcceptEntityInput(g_StrategyPeriodTimer, "SetTime");
		}
	}

	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientConnected(i) && IsClientInGame(i) && !IsClientObserver(i)) {
			SetEntityMoveType(i, MOVETYPE_NONE);
			SetEntProp(i, Prop_Send, "m_bAllowMoveDuringTaunt", 0);
			SetEntPropFloat(i, Prop_Send, "m_flEnergyDrinkMeter", 0.0);
			SetEntPropFloat(i, Prop_Send, "m_flHypeMeter", 0.0);
			SetEntPropFloat(i, Prop_Send, "m_flChargeMeter", 0.0);
			SetEntPropFloat(i, Prop_Send, "m_flCloakMeter", 0.0);
			SetEntPropFloat(i, Prop_Send, "m_flRageMeter", 0.0);

			for (int j = 0; j < 6; j++) {
				int weapon = GetPlayerWeaponSlot(i, j);

				if (weapon != -1) {
					SetEntPropFloat(weapon, Prop_Send, "m_flNextPrimaryAttack", endTime);
					SetEntPropFloat(weapon, Prop_Send, "m_flNextSecondaryAttack", endTime);
				}
			}
		}
	}
}

void TearDownStrategyPeriod() {
	int timer = FindEntityByClassname(-1, "team_round_timer");

	while (timer != -1) {
		AcceptEntityInput(timer, "Enable");

		timer = FindEntityByClassname(timer, "team_round_timer");
	}

	if (g_StrategyPeriodTimer != -1) {
		AcceptEntityInput(g_StrategyPeriodTimer, "Disable");
		AcceptEntityInput(g_StrategyPeriodTimer, "Kill");
	}

	g_StrategyPeriodActive = false;
	g_StrategyPeriodCompleted = true;
	g_StrategyPeriodPause = false;
}
