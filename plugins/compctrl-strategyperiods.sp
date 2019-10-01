#include <sourcemod>

#include <compctrl_version>
#include <compctrl_extension>
#include <morecolors>
#include <sdktools_entinput>
#include <sdktools_functions>
#include <sdktools_gamerules>

bool g_StrategyPeriodActive = false;
bool g_StrategyPeriodCompleted = false;
bool g_StrategyPeriodPaused = false;
float g_StrategyPeriodNextPauseLength = -1.0;
int g_StrategyPeriodTimer = -1;
float g_StrategyPeriodPauseEnd = -1.0;
float g_TransitionTime = 0.0;

Handle g_OnPeriodStart;
Handle g_OnPauseStart;
Handle g_OnPauseEnd;

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
    g_Time = CreateConVar("compctrl_strategyperiods_time", "15", "the amount of time between rounds", 0, true, 0.0);

    g_OnPeriodStart = CreateGlobalForward("CompCtrl_OnStrategyPeriodBegin", ET_Hook);
    g_OnPauseStart = CreateGlobalForward("CompCtrl_OnStrategyPeriodPauseBegin", ET_Hook, Param_FloatByRef);
    g_OnPauseEnd = CreateGlobalForward("CompCtrl_OnStrategyPeriodPauseEnd", ET_Hook, Param_FloatByRef);

    HookEvent("teamplay_round_start", Event_RoundStart);
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) {
    CreateNative("CompCtrl_PauseStrategyPeriod", Native_PauseStrategyPeriod);
    CreateNative("CompCtrl_UnpauseStrategyPeriod", Native_UnpauseStrategyPeriod);
    return APLRes_Success;
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast) {
    if (g_Time.FloatValue > 0.0 || g_StrategyPeriodNextPauseLength >= 0.0) {
        Call_StartForward(g_OnPeriodStart);

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

    if (!g_StrategyPeriodPaused && GetGameTime() >= g_TransitionTime) {
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

public int Native_PauseStrategyPeriod(Handle plugin, int numParams) {
    float pauseTime = view_as<float>(GetNativeCell(1));

    if (g_StrategyPeriodActive) {
        if (!g_StrategyPeriodPaused) {
            PauseStrategyPeriod(pauseTime);
            return view_as<int>(g_StrategyPeriodPaused);
        }
        else {
            return view_as<int>(false);
        }
    }
    else {
        if (g_StrategyPeriodNextPauseLength < 0.0) {
            g_StrategyPeriodNextPauseLength = pauseTime;
            return view_as<int>(true);
        }
        else {
            return view_as<int>(false);
        }
    }
}

public int Native_UnpauseStrategyPeriod(Handle plugin, int numParams) {
    if (g_StrategyPeriodActive) {
        if (g_StrategyPeriodPaused) {
            UnpauseStrategyPeriod();
            return view_as<int>(!g_StrategyPeriodPaused);
        }
        else {
            return view_as<int>(false);
        }
    }
    else {
        if (g_StrategyPeriodNextPauseLength >= 0.0) {
            g_StrategyPeriodNextPauseLength = -1.0;
            return view_as<int>(true);
        }
        else {
            return view_as<int>(false);
        }
    }
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

        DispatchKeyValue(g_StrategyPeriodTimer, "start_paused", "0");
        DispatchKeyValue(g_StrategyPeriodTimer, "auto_countdown", "0");
        DispatchKeyValue(g_StrategyPeriodTimer, "show_in_hud", "1");
        DispatchSpawn(g_StrategyPeriodTimer);

        SetVariantInt(RoundToCeil(g_Time.FloatValue));
        AcceptEntityInput(g_StrategyPeriodTimer, "SetTime");

        AcceptEntityInput(g_StrategyPeriodTimer, "Enable");
    }

    CPrintToChatAll("{green}[CompCtrl]{default} Strategy period has begun.");

    if (g_StrategyPeriodNextPauseLength >= 0.0) {
        PauseStrategyPeriod(g_StrategyPeriodNextPauseLength);
        g_StrategyPeriodNextPauseLength = -1.0;
    }
}

void MaintainStrategyPeriod() {
    if (g_StrategyPeriodPaused) {
        if (g_StrategyPeriodPauseEnd > 0.0) {
            if (GetGameTime() >= g_StrategyPeriodPauseEnd) {
                UnpauseStrategyPeriod();
            }
        }
        else {
            if (g_StrategyPeriodTimer != -1) {
                AcceptEntityInput(g_StrategyPeriodTimer, "Pause");
                SetVariantInt(RoundToCeil(g_Time.FloatValue));
                AcceptEntityInput(g_StrategyPeriodTimer, "SetTime");
            }
        }
    }

    float endTime = g_StrategyPeriodPaused ? GetGameTime() + g_Time.FloatValue + 0.1 : g_TransitionTime;

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
    g_StrategyPeriodPaused = false;
}

void PauseStrategyPeriod(float time) {
    Call_StartForward(g_OnPauseStart);
    Call_PushFloatRef(time);

    Action result;
    Call_Finish(result);

    if (result == Plugin_Continue || result == Plugin_Changed) {
        g_StrategyPeriodPaused = true;

        if (time > 0.0) {
            g_StrategyPeriodPauseEnd = GetGameTime() + time;

            if (g_StrategyPeriodTimer != -1) {
                SetVariantInt(RoundToCeil(time));
                AcceptEntityInput(g_StrategyPeriodTimer, "SetTime");
                AcceptEntityInput(g_StrategyPeriodTimer, "Resume");
            }

            CPrintToChatAll("{green}[CompCtrl]{default} Current strategy period has been paused for {olive}%f{default} seconds.", time);
        }
        else {
            g_StrategyPeriodPauseEnd = -1.0;

            if (g_StrategyPeriodTimer != -1) {
                SetVariantInt(RoundToCeil(g_Time.FloatValue));
                AcceptEntityInput(g_StrategyPeriodTimer, "SetTime");
                AcceptEntityInput(g_StrategyPeriodTimer, "Pause");
            }

            CPrintToChatAll("{green}[CompCtrl]{default} Current strategy period has been paused.");
        }
    }
}

void UnpauseStrategyPeriod() {
    Call_StartForward(g_OnPauseEnd);

    float time = -1.0;
    Call_PushFloatRef(time);

    Action result;
    Call_Finish(result);

    if (result == Plugin_Continue) {
        g_StrategyPeriodPaused = false;
        g_StrategyPeriodPauseEnd = -1.0;

        g_TransitionTime = GetGameTime() + g_Time.FloatValue;

        if (g_StrategyPeriodTimer != -1) {
            SetVariantInt(RoundToCeil(g_Time.FloatValue));
            AcceptEntityInput(g_StrategyPeriodTimer, "SetTime");
            AcceptEntityInput(g_StrategyPeriodTimer, "Resume");
        }

        CPrintToChatAll("{green}[CompCtrl]{default} Current strategy period pause has ended.");
    }
    else {
        if (time > 0.0) {
            g_StrategyPeriodPauseEnd = GetGameTime() + time;

            if (g_StrategyPeriodTimer != -1) {
                SetVariantInt(RoundToCeil(time));
                AcceptEntityInput(g_StrategyPeriodTimer, "SetTime");
                AcceptEntityInput(g_StrategyPeriodTimer, "Resume");
            }
        }
        else {
            g_StrategyPeriodPauseEnd = -1.0;

            if (g_StrategyPeriodTimer != -1) {
                SetVariantInt(RoundToCeil(g_Time.FloatValue));
                AcceptEntityInput(g_StrategyPeriodTimer, "SetTime");
                AcceptEntityInput(g_StrategyPeriodTimer, "Pause");
            }
        }
    }
}
