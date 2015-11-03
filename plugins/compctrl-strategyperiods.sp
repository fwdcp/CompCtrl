#include <sourcemod>

#include <compctrl_version>
#include <compctrl_extension>
#include <sdktools_entinput>
#include <sdktools_functions>
#include <sdktools_gamerules>

bool g_StrategyPeriodActive = false;
bool g_StrategyPeriodCompleted = false;
float g_TransitionTime = 0.0;

Handle g_OnStart;

ConVar g_MatchEndAtTimelimit;
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
	g_MatchEndAtTimelimit = FindConVar("mp_match_end_at_timelimit");
	g_Time = CreateConVar("compctrl_strategyperiods_time", "15", "the amount of time between rounds");

	g_OnStart = CreateGlobalForward("CompCtrl_OnStrategyPeriodBegin", ET_Hook);

	HookEvent("teamplay_round_start", Event_RoundStart);
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

	GameRules_SetPropFloat("m_flRestartRoundTime", g_TransitionTime);
}

void TearDownStrategyPeriod() {
	CompCtrl_CleanUpMap();

	int timelimit = 0;
	GetMapTimeLimit(timelimit);

	if (timelimit != 0 && GameRules_GetProp("m_nGameType") != 4 && !GameRules_GetProp("m_bPlayingKoth") && g_MatchEndAtTimelimit.BoolValue) {
		int timer = FindEntityByClassname(-1, "team_round_timer");

		if (timer == -1) {
			timer = CreateEntityByName("team_round_timer");

			if (timer != -1) {
				DispatchKeyValue(timer, "targetname", "zz_teamplay_timelimit_timer");
				DispatchKeyValue(timer, "show_in_hud", "1");
				DispatchSpawn(timer);

				int timeleft = 0;
				GetMapTimeLeft(timeleft);
				SetVariantInt(timeleft);
				AcceptEntityInput(timer, "SetTime");

				AcceptEntityInput(timer, "Resume");
				AcceptEntityInput(timer, "Enable");
			}
		}
	}

	g_StrategyPeriodActive = false;
	g_StrategyPeriodCompleted = true;
}
