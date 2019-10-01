#include <sourcemod>

#include <compctrl_version>
#include <compctrl_extension>
#include <compctrl-matches>
#include <compctrl-strategyperiods>
#include <hudnotify>
#include <morecolors>
#include <sdkhooks>
#include <sdktools>
#include <tf2>

#pragma newdecls required

KeyValues g_MatchConfig;
bool g_InMatch = false;
char g_MatchConfigName[256];
bool g_InPeriod = false;
char g_CurrentPeriod[256];
bool g_SwitchTeams = false;
bool g_PeriodNeedsSetup = false;
bool g_AllowScoreReset = true;
int g_RestartsLeft = 0;
int g_RoundsPlayed = 0;
int g_RedTeamScore = 0;
int g_BluTeamScore = 0;
int g_RedTeamTimeoutsRemaining = 0;
int g_BluTeamTimeoutsRemaining = 0;
int g_TimeoutLength = 30;
TFTeam g_TeamRequestingTimeout = TFTeam_Unassigned;
bool g_TimeoutAlreadyTaken = false;
bool g_AllowConcede = false;
TFTeam g_TeamConceding = TFTeam_Unassigned;
bool g_DisableRoundTimers = false;
char g_MainTimerName[128] = "";

ConVar g_Tournament;
ConVar g_TournamentNonAdminRestart;
ConVar g_Stopwatch;
ConVar g_SuddenDeath;
ConVar g_RedTeamName;
ConVar g_BlueTeamName;
ConVar g_TimeLimit;
ConVar g_WinLimit;
ConVar g_WinDifference;
ConVar g_WinDifferenceMin;
ConVar g_MaxRounds;
ConVar g_FlagCapsPerRound;
ConVar g_RestartGame;

public Plugin myinfo =
{
    name = "CompCtrl Match Management",
    author = "Forward Command Post",
    description = "a plugin to manage matches in tournament mode",
    version = COMPCTRL_VERSION,
    url = "http://github.com/fwdcp/CompCtrl/"
};

public void OnPluginStart() {
    RegAdminCmd("sm_startmatch", Command_StartMatch, ADMFLAG_CONFIG, "sets up and starts a match with the specified config");
    RegAdminCmd("sm_cancelmatch", Command_CancelMatch, ADMFLAG_CONFIG, "cancels and stops a match");

    RegConsoleCmd("sm_matchstatus", Command_MatchStatus, "get the status of the current match");
    RegConsoleCmd("sm_concede", Command_Concede, "concede the match");
    RegConsoleCmd("sm_timeout", Command_Timeout, "request a timeout in the match");

    g_Tournament = FindConVar("mp_tournament");
    g_TournamentNonAdminRestart = FindConVar("mp_tournament_allow_non_admin_restart");
    g_Stopwatch = FindConVar("mp_tournament_stopwatch");
    g_SuddenDeath = FindConVar("mp_stalemate_enable");
    g_RedTeamName = FindConVar("mp_tournament_redteamname");
    g_BlueTeamName = FindConVar("mp_tournament_blueteamname");
    g_TimeLimit = FindConVar("mp_timelimit");
    g_WinLimit = FindConVar("mp_winlimit");
    g_WinDifference = FindConVar("mp_windifference");
    g_WinDifferenceMin = FindConVar("mp_windifference_min");
    g_MaxRounds = FindConVar("mp_maxrounds");
    g_FlagCapsPerRound = FindConVar("tf_flag_caps_per_round");
    g_RestartGame = FindConVar("mp_restartgame");

    HookEvent("teamplay_round_start", Event_RoundStart);
}

public Action Command_StartMatch(int client, int args) {
    if (g_InMatch) {
        CPrintToChatAll("{green}[CompCtrl]{default} Current match is being reset.");

        ServerCommand("mp_tournament_restart");
    }

    if (g_MatchConfig != null) {
        CloseHandle(g_MatchConfig);
        g_MatchConfig = null;
    }

    g_InMatch = false;
    g_MatchConfigName = "";
    g_InPeriod = false;
    g_CurrentPeriod = "";
    g_SwitchTeams = false;
    g_PeriodNeedsSetup = false;
    g_AllowScoreReset = true;
    g_RestartsLeft = 0;
    g_RoundsPlayed = 0;
    g_RedTeamScore = 0;
    g_BluTeamScore = 0;
    g_RedTeamTimeoutsRemaining = 0;
    g_BluTeamTimeoutsRemaining = 0;
    g_TimeoutLength = 30;
    g_TeamRequestingTimeout = TFTeam_Unassigned;
    g_TimeoutAlreadyTaken = false;
    g_AllowConcede = false;
    g_TeamConceding = TFTeam_Unassigned;
    g_DisableRoundTimers = false;

    char arg[256];
    GetCmdArg(1, arg, sizeof(arg));

    g_MatchConfig = CreateKeyValues(arg);

    char configPath[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, configPath, sizeof(configPath), "configs/compctrl/matches/%s.cfg", arg);

    if (!FileExists(configPath) || !FileToKeyValues(g_MatchConfig, configPath)) {
        ReplyToCommand(client, "No such match config exists!");
        CloseHandle(g_MatchConfig);
        g_MatchConfig = null;
        return Plugin_Handled;
    }

    if (!g_MatchConfig.JumpToKey("periods") || !g_MatchConfig.GotoFirstSubKey()) {
        ReplyToCommand(client, "Match config is invalid!");
        CloseHandle(g_MatchConfig);
        g_MatchConfig = null;
        return Plugin_Handled;
    }

    g_Tournament.BoolValue = true;
    g_TournamentNonAdminRestart.BoolValue = false;
    g_InMatch = true;
    g_AllowScoreReset = true;
    strcopy(g_MatchConfigName, sizeof(g_MatchConfigName), arg);
    g_MatchConfig.GetSectionName(g_CurrentPeriod, sizeof(g_CurrentPeriod));

    CPrintToChatAll("{green}[CompCtrl]{default} Match has been set up with config {olive}%s{default}.", arg);

    BeginPeriod();

    g_MatchConfig.Rewind();
    return Plugin_Handled;
}

public Action Command_CancelMatch(int client, int args) {
    if (g_InMatch) {
        CPrintToChatAll("{green}[CompCtrl]{default} Match has been canceled.");

        ServerCommand("mp_tournament_restart");
    }

    if (g_MatchConfig != null) {
        CloseHandle(g_MatchConfig);
        g_MatchConfig = null;
    }

    g_InMatch = false;
    g_MatchConfigName = "";
    g_InPeriod = false;
    g_CurrentPeriod = "";
    g_SwitchTeams = false;
    g_PeriodNeedsSetup = false;
    g_AllowScoreReset = true;
    g_RestartsLeft = 0;
    g_RoundsPlayed = 0;
    g_RedTeamScore = 0;
    g_BluTeamScore = 0;
    g_RedTeamTimeoutsRemaining = 0;
    g_BluTeamTimeoutsRemaining = 0;
    g_TimeoutLength = 30;
    g_TeamRequestingTimeout = TFTeam_Unassigned;
    g_TimeoutAlreadyTaken = false;
    g_AllowConcede = false;
    g_TeamConceding = TFTeam_Unassigned;
    g_DisableRoundTimers = false;

    return Plugin_Handled;
}

public Action Command_MatchStatus(int client, int args) {
    if (!g_InMatch) {
        CReplyToCommand(client, "{green}[CompCtrl]{default} No match currently occurring.");
        return Plugin_Handled;
    }

    GetCurrentRoundConfig();

    char periodName[256];
    g_MatchConfig.GetString("name", periodName, sizeof(periodName), "period");

    if (g_InPeriod) {
        CReplyToCommand(client, "{green}[CompCtrl]{default} Currently in {olive}%s{default}.", periodName);

        int currentRound = g_RoundsPlayed + 1;

        if (GameRules_GetProp("m_bStopWatch", 1)) {
            if (g_MatchConfig.GetNum("timelimit", 0) > 0) {
                int timeLeft = RoundToFloor(GetTimeLeft());

                switch (GetStopwatchStatus()) {
                    case StopwatchStatus_SetTarget: {
                        CReplyToCommand(client, "{green}[CompCtrl]{default} Period status: {olive}%s{default}, {olive}%i:%02i{default} remaining, set part of round {olive}%i{default}.", periodName, timeLeft / 60, timeLeft % 60, currentRound);
                    }
                    case StopwatchStatus_ChaseTarget: {
                        CReplyToCommand(client, "{green}[CompCtrl]{default} Period status: {olive}%s{default}, {olive}%i:%02i{default} remaining, chase part of round {olive}%i{default}.", periodName, timeLeft / 60, timeLeft % 60, currentRound);
                    }
                    default: {
                        CReplyToCommand(client, "{green}[CompCtrl]{default} Period status: {olive}%s{default}, {olive}%i:%02i{default} remaining, round {olive}%i{default}.", periodName, timeLeft / 60, timeLeft % 60, currentRound);
                    }
                }
            }
            else {
                switch (GetStopwatchStatus()) {
                    case StopwatchStatus_SetTarget: {
                        CReplyToCommand(client, "{green}[CompCtrl]{default} Period status: {olive}%s{default}, set part of round {olive}%i{default}.", periodName, currentRound);
                    }
                    case StopwatchStatus_ChaseTarget: {
                        CReplyToCommand(client, "{green}[CompCtrl]{default} Period status: {olive}%s{default}, chase part of round {olive}%i{default}.", periodName, currentRound);
                    }
                    default: {
                        CReplyToCommand(client, "{green}[CompCtrl]{default} Period status: {olive}%s{default}, round {olive}%i{default}.", periodName, currentRound);
                    }
                }
            }
        }
        else {
            if (g_MatchConfig.GetNum("timelimit", 0) > 0) {
                int timeLeft = RoundToFloor(GetTimeLeft());

                CReplyToCommand(client, "{green}[CompCtrl]{default} Period status: {olive}%s{default}, {olive}%i:%02i{default} remaining, round {olive}%i{default}.", periodName, timeLeft / 60, timeLeft % 60, currentRound);
            }
            else {
                CReplyToCommand(client, "{green}[CompCtrl]{default} Period status: {olive}%s{default}, round {olive}%i{default}.", periodName, currentRound);
            }
        }
    }
    else {
        CReplyToCommand(client, "{green}[CompCtrl]{default} Period status: awaiting start of {olive}%s{default}.", periodName);
    }

    char redName[256];
    g_RedTeamName.GetString(redName, sizeof(redName));
    char bluName[256];
    g_BlueTeamName.GetString(bluName, sizeof(bluName));

    CReplyToCommand(client, "{green}[CompCtrl]{default} Current score: {blue}%s{default} {olive}%i{default}, {red}%s{default} {olive}%i{default}.", bluName, GetScore(TFTeam_Blue), redName, GetScore(TFTeam_Red));
    CReplyToCommand(client, "{green}[CompCtrl]{default} Timeouts available: {blue}%s{default} {olive}%i{default}, {red}%s{default} {olive}%i{default}.", bluName, g_BluTeamTimeoutsRemaining, redName, g_RedTeamTimeoutsRemaining);

    return Plugin_Handled;
}

public Action Command_Concede(int client, int args) {
    if (!g_InMatch) {
        CReplyToCommand(client, "{green}[CompCtrl]{default} No match is currently occurring!");
        return Plugin_Handled;
    }

    if (!IsClientInGame(client) || (GetClientTeam(client) != view_as<int>(TFTeam_Red) && GetClientTeam(client) != view_as<int>(TFTeam_Blue))) {
        CReplyToCommand(client, "{green}[CompCtrl]{default} Cannot concede the match!");
        return Plugin_Handled;
    }

    if (!g_AllowConcede) {
        CReplyToCommand(client, "{green}[CompCtrl]{default} Cannot concede the match at this time!");
        return Plugin_Handled;
    }

    TFTeam team = view_as<TFTeam>(GetClientTeam(client));
    ConcedeMatch(team);

    return Plugin_Handled;
}

public Action Command_Timeout(int client, int args) {
    if (!g_InMatch) {
        CReplyToCommand(client, "{green}[CompCtrl]{default} No match is currently occurring!");
        return Plugin_Handled;
    }

    if (!IsClientInGame(client) || (GetClientTeam(client) != view_as<int>(TFTeam_Red) && GetClientTeam(client) != view_as<int>(TFTeam_Blue))) {
        CReplyToCommand(client, "{green}[CompCtrl]{default} Cannot take a timeout!");
        return Plugin_Handled;
    }

    if (g_TimeoutAlreadyTaken) {
        CReplyToCommand(client, "{green}[CompCtrl]{default} Cannot take another timeout at this time!");
        return Plugin_Handled;
    }

    if (g_TeamRequestingTimeout == TFTeam_Red || g_TeamRequestingTimeout == TFTeam_Blue) {
        CReplyToCommand(client, "{green}[CompCtrl]{default} Timeout is already scheduled!");
    }

    TFTeam team = view_as<TFTeam>(GetClientTeam(client));

    if ((team == TFTeam_Red && g_RedTeamTimeoutsRemaining <= 0) || (team == TFTeam_Blue && g_BluTeamTimeoutsRemaining <= 0)) {
        CReplyToCommand(client, "{green}[CompCtrl]{default} No timeouts available!");
        return Plugin_Handled;
    }

    RequestTimeout(team);

    return Plugin_Handled;
}

public void OnMapStart() {
    g_MainTimerName = "";

    for (int timer = FindEntityByClassname(-1, "team_round_timer"); timer != -1; timer = FindEntityByClassname(timer, "team_round_timer")) {
        if (view_as<bool>(GetEntProp(timer, Prop_Send, "m_bShowInHUD"))) {
            GetEntPropString(timer, Prop_Data, "m_iName", g_MainTimerName, sizeof(g_MainTimerName));
            SetUpMainTimer(timer);
        }
    }
}

public void OnEntityCreated(int entity, const char[] classname) {
    if (StrEqual(classname, "team_round_timer")) {
        RequestFrame(SetUpMainTimer, entity);
    }
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast) {
    if (g_InMatch) {
        g_AllowScoreReset = false;
        g_SwitchTeams = false;

        GetCurrentRoundConfig();

        char periodName[256];
        g_MatchConfig.GetString("name", periodName, sizeof(periodName), "period");

        if (g_RestartsLeft > 0) {
            CPrintToChatAll("{green}[CompCtrl]{default} The {olive}%s{default} period will be live after {olive}%i{default} restarts.", periodName, g_RestartsLeft);

            g_RestartGame.IntValue = 5;

            g_RestartsLeft--;

            return;
        }

        if (g_MatchConfig.GetNum("manual-scoring", 0)) {
            g_TimeLimit.IntValue = 0;
            g_WinLimit.IntValue = 0;
            g_WinDifference.IntValue = 0;
            g_WinDifferenceMin.IntValue = 0;
            g_MaxRounds.IntValue = 0;
        }

        if (!GameRules_GetProp("m_bStopWatch", 1) || GetStopwatchStatus() == StopwatchStatus_SetTarget) {
            if (g_RoundsPlayed == 0) {
                CPrintToChatAll("{green}[CompCtrl]{default} The {olive}%s{default} period is {olive}live{default}.", periodName);
                HudNotifyAll("timer_icon", TFTeam_Unassigned, "The %s period is live.", periodName);

                g_InPeriod = true;
            }
        }

        int currentRound = g_RoundsPlayed + 1;

        if (GameRules_GetProp("m_bStopWatch", 1)) {
            if (g_MatchConfig.GetNum("timelimit", 0) > 0) {
                int timeLeft = RoundToFloor(GetTimeLeft());

                switch (GetStopwatchStatus()) {
                    case StopwatchStatus_SetTarget: {
                        CPrintToChatAll("{green}[CompCtrl]{default} Period status: {olive}%s{default}, {olive}%i:%02i{default} remaining, set part of round {olive}%i{default}.", periodName, timeLeft / 60, timeLeft % 60, currentRound);
                    }
                    case StopwatchStatus_ChaseTarget: {
                        CPrintToChatAll("{green}[CompCtrl]{default} Period status: {olive}%s{default}, {olive}%i:%02i{default} remaining, chase part of round {olive}%i{default}.", periodName, timeLeft / 60, timeLeft % 60, currentRound);
                    }
                    default: {
                        CPrintToChatAll("{green}[CompCtrl]{default} Period status: {olive}%s{default}, {olive}%i:%02i{default} remaining, round {olive}%i{default}.", periodName, timeLeft / 60, timeLeft % 60, currentRound);
                    }
                }
            }
            else {
                switch (GetStopwatchStatus()) {
                    case StopwatchStatus_SetTarget: {
                        CPrintToChatAll("{green}[CompCtrl]{default} Period status: {olive}%s{default}, set part of round {olive}%i{default}.", periodName, currentRound);
                    }
                    case StopwatchStatus_ChaseTarget: {
                        CPrintToChatAll("{green}[CompCtrl]{default} Period status: {olive}%s{default}, chase part of round {olive}%i{default}.", periodName, currentRound);
                    }
                    default: {
                        CPrintToChatAll("{green}[CompCtrl]{default} Period status: {olive}%s{default}, round {olive}%i{default}.", periodName, currentRound);
                    }
                }
            }
        }
        else {
            if (g_MatchConfig.GetNum("timelimit", 0) > 0) {
                int timeLeft = RoundToFloor(GetTimeLeft());

                CPrintToChatAll("{green}[CompCtrl]{default} Period status: {olive}%s{default}, {olive}%i:%02i{default} remaining, round {olive}%i{default}.", periodName, timeLeft / 60, timeLeft % 60, currentRound);
            }
            else {
                CPrintToChatAll("{green}[CompCtrl]{default} Period status: {olive}%s{default}, round {olive}%i{default}.", periodName, currentRound);
            }
        }

        char redName[256];
        g_RedTeamName.GetString(redName, sizeof(redName));
        char bluName[256];
        g_BlueTeamName.GetString(bluName, sizeof(bluName));

        CPrintToChatAll("{green}[CompCtrl]{default} Current score: {blue}%s{default} {olive}%i{default}, {red}%s{default} {olive}%i{default}.", bluName, GetScore(TFTeam_Blue), redName, GetScore(TFTeam_Red));

        if (g_MatchConfig.GetNum("timelimit", 0) > 0) {
            int timeLeft = RoundToFloor(GetTimeLeft());

            if (GetScore(TFTeam_Red) > GetScore(TFTeam_Blue)) {
                HudNotifyAll("redcapture", TFTeam_Red, "With %i:%02i remaining in the %s period, the score is %s %i, %s %i.", timeLeft / 60, timeLeft % 60, periodName, bluName, GetScore(TFTeam_Blue), redName, GetScore(TFTeam_Red));
            }
            else if (GetScore(TFTeam_Blue) > GetScore(TFTeam_Red)) {
                HudNotifyAll("bluecapture", TFTeam_Blue, "With %i:%02i remaining in the %s period, the score is %s %i, %s %i.", timeLeft / 60, timeLeft % 60, periodName, bluName, GetScore(TFTeam_Blue), redName, GetScore(TFTeam_Red));
            }
            else {
                HudNotifyAll("timer_icon", TFTeam_Unassigned, "With %i:%02i remaining in the %s period, the score is %s %i, %s %i.", timeLeft / 60, timeLeft % 60, periodName, bluName, GetScore(TFTeam_Blue), redName, GetScore(TFTeam_Red));
            }
        }
        else {
            if (GetScore(TFTeam_Red) > GetScore(TFTeam_Blue)) {
                HudNotifyAll("redcapture", TFTeam_Red, "The current score in the %s period is %s %i, %s %i.", periodName, bluName, GetScore(TFTeam_Blue), redName, GetScore(TFTeam_Red));
            }
            else if (GetScore(TFTeam_Blue) > GetScore(TFTeam_Red)) {
                HudNotifyAll("bluecapture", TFTeam_Blue, "The current score in the %s period is %s %i, %s %i.", periodName, bluName, GetScore(TFTeam_Blue), redName, GetScore(TFTeam_Red));
            }
            else {
                HudNotifyAll("timer_icon", TFTeam_Unassigned, "The current score in the period %s is %s %i, %s %i.", periodName, bluName, GetScore(TFTeam_Blue), redName, GetScore(TFTeam_Red));
            }
        }
    }
}

void Hook_TimerThink(int entity) {
    if (g_DisableRoundTimers) {
	   DisableTimer(entity);
    }
    else {
        SDKUnhook(entity, SDKHook_Think, Hook_TimerThink);
    }
}

public Action CompCtrl_OnSetWinningTeam(TFTeam &team, WinReason &reason, bool &forceMapReset, bool &switchTeams, bool &dontAddScore, bool &final) {
    if (g_InMatch) {
        GetCurrentRoundConfig();

        int redScore = GetScore(TFTeam_Red);
        int bluScore = GetScore(TFTeam_Blue);

        if (GameRules_GetProp("m_bStopWatch", 1)) {
            if (GetStopwatchStatus() == StopwatchStatus_ChaseTarget) {
                if (team == TFTeam_Red) {
                    redScore++;
                }
                else if (team == TFTeam_Blue) {
                    bluScore++;
                }

                g_RoundsPlayed++;
            }
        }
        else {
            if (!dontAddScore) {
                if (team == TFTeam_Red) {
                    redScore++;
                }
                else if (team == TFTeam_Blue) {
                    bluScore++;
                }
            }

            g_RoundsPlayed++;
        }

        if (g_MatchConfig.GetNum("manual-scoring", 0)) {
            g_RedTeamScore = redScore;
            g_BluTeamScore = bluScore;
        }

        EndCondition endCondition;
        TFTeam cause;

        if (!CheckEndConditions(redScore, bluScore, endCondition, cause)) {
            if (g_MatchConfig.GetNum("switch-teams-each-round", 0)) {
                g_SwitchTeams = true;
            }

            final = false;
        }
        else {
            EndPeriod(redScore, bluScore, endCondition, cause);

            final = true;
        }

        if (g_SwitchTeams) {
            if (GameRules_GetProp("m_bStopWatch", 1) && GetStopwatchStatus() == StopwatchStatus_ChaseTarget) {
                switchTeams = false;
            }
            else {
                switchTeams = true;
            }

            g_SwitchTeams = false;
            return Plugin_Changed;
        }
    }

    return Plugin_Continue;
}

public Action CompCtrl_OnSwitchTeams() {
    if (g_InMatch) {
        GetCurrentRoundConfig();

        if (g_MatchConfig.GetNum("manual-scoring", 0)) {
            int newBluScore = g_RedTeamScore;
            int newRedScore = g_BluTeamScore;

            g_RedTeamScore = newRedScore;
            g_BluTeamScore = newBluScore;
        }
    }

    return Plugin_Continue;
}

public Action CompCtrl_OnRestartTournament() {
    if (g_InMatch && g_PeriodNeedsSetup) {
        BeginPeriod();
        g_PeriodNeedsSetup = false;
    }

    return Plugin_Continue;
}

public Action CompCtrl_OnCheckWinLimit(bool &allowEnd, int &incrementScores, bool &returnValue) {
    if (g_InMatch) {
        GetCurrentRoundConfig();

        if (g_MatchConfig.GetNum("manual-scoring", 0)) {
            EndCondition endCondition;
            TFTeam cause;

            returnValue = CheckEndConditions(GetScore(TFTeam_Red) + incrementScores, GetScore(TFTeam_Blue) + incrementScores, endCondition, cause);
            return Plugin_Handled;
        }
    }

    return Plugin_Continue;
}

public Action CompCtrl_OnResetTeamScores(TFTeam team) {
    if (g_InMatch) {
        GetCurrentRoundConfig();

        if (g_InMatch && !g_AllowScoreReset && !g_MatchConfig.GetNum("manual-scoring", 0)) {
            if (team == TFTeam_Red || team == TFTeam_Blue) {
                return Plugin_Stop;
            }
        }
    }

    return Plugin_Continue;
}

public Action CompCtrl_OnStrategyPeriodBegin() {
    if (g_InMatch) {
        if (g_RestartsLeft > 0 || g_RestartGame.IntValue == 5) {
            return Plugin_Stop;
        }
    }

    return Plugin_Continue;
}

public Action CompCtrl_OnStrategyPeriodPauseBegin() {
    if (g_InMatch) {
        if (g_TeamRequestingTimeout == TFTeam_Red) {
            g_RedTeamTimeoutsRemaining--;

            char redName[256];
            g_RedTeamName.GetString(redName, sizeof(redName));

            CPrintToChatAll("{green}[CompCtrl]{default} Starting timeout requested by {red}%s{default} ({olive}%i{default} remaining).", redName, g_RedTeamTimeoutsRemaining);
        }
        else if (g_TeamRequestingTimeout == TFTeam_Blue) {
            g_BluTeamTimeoutsRemaining--;

            char bluName[256];
            g_BlueTeamName.GetString(bluName, sizeof(bluName));

            CPrintToChatAll("{green}[CompCtrl]{default} Starting timeout requested by {blue}%s{default} ({olive}%i{default} remaining).", bluName, g_BluTeamTimeoutsRemaining);
        }
    }

    return Plugin_Continue;
}

void BeginPeriod() {
    GetCurrentRoundConfig();

    g_Stopwatch.BoolValue = view_as<bool>(g_MatchConfig.GetNum("stopwatch", 1));
    g_SuddenDeath.BoolValue = view_as<bool>(g_MatchConfig.GetNum("sudden-death", 0));
    g_TimeLimit.IntValue = g_MatchConfig.GetNum("timelimit", 0);
    g_WinLimit.IntValue = g_MatchConfig.GetNum("winlimit", 0);
    g_WinDifference.IntValue = g_MatchConfig.GetNum("windifference", 0);
    g_WinDifferenceMin.IntValue = g_MatchConfig.GetNum("windifference-min", 0);
    g_MaxRounds.IntValue = g_MatchConfig.GetNum("maxrounds", 0);
    g_FlagCapsPerRound.IntValue = g_MatchConfig.GetNum("flag-caps-per-round", 0);
    g_RestartsLeft = g_MatchConfig.GetNum("live-on", 0);
    if (!view_as<bool>(g_MatchConfig.GetNum("timeouts-carryover", 0))) {
        g_RedTeamTimeoutsRemaining = 0;
        g_BluTeamTimeoutsRemaining = 0;
    }
    g_RedTeamTimeoutsRemaining += g_MatchConfig.GetNum("timeouts-add", 0);
    g_BluTeamTimeoutsRemaining += g_MatchConfig.GetNum("timeouts-add", 0);
    g_TimeoutLength = g_MatchConfig.GetNum("timeout-length", 30);
    g_AllowConcede = view_as<bool>(g_MatchConfig.GetNum("allow-concede", 0));
    g_DisableRoundTimers = view_as<bool>(g_MatchConfig.GetNum("disable-round-timers", 0));

    g_RoundsPlayed = 0;

    char periodName[256];
    g_MatchConfig.GetString("name", periodName, sizeof(periodName), "period");

    CPrintToChatAll("{green}[CompCtrl]{default} The next period will be: {olive}%s{default}.", periodName);
    HudNotifyAll("timer_icon", TFTeam_Unassigned, "Next period: %s.", periodName);

    int winConditions = 0;
    char winConditionInformation[512];
    if (g_MatchConfig.GetNum("timelimit", 0) > 0) {
        if (winConditions > 0) {
            StrCat(winConditionInformation, sizeof(winConditionInformation), "; ");
        }

        Format(winConditionInformation, sizeof(winConditionInformation), "%s{olive}time limit %i{default}", winConditionInformation, g_MatchConfig.GetNum("timelimit", 0));

        winConditions++;
    }
    if (g_MatchConfig.GetNum("winlimit", 0) > 0) {
        if (winConditions > 0) {
            StrCat(winConditionInformation, sizeof(winConditionInformation), "; ");
        }

        Format(winConditionInformation, sizeof(winConditionInformation), "%s{olive}win limit %i{default}", winConditionInformation, g_MatchConfig.GetNum("winlimit", 0));

        winConditions++;
    }
    if (g_MatchConfig.GetNum("windifference", 0) > 0) {
        if (winConditions > 0) {
            StrCat(winConditionInformation, sizeof(winConditionInformation), "; ");
        }

        Format(winConditionInformation, sizeof(winConditionInformation), "%s{olive}win difference %i{default} (with {olive}minimum score %i{default})", winConditionInformation, g_MatchConfig.GetNum("windifference", 0), g_MatchConfig.GetNum("windifference-min", 0));

        winConditions++;
    }
    if (g_MatchConfig.GetNum("maxrounds", 0) > 0) {
        if (winConditions > 0) {
            StrCat(winConditionInformation, sizeof(winConditionInformation), "; ");
        }

        Format(winConditionInformation, sizeof(winConditionInformation), "%s{olive}max rounds %i{default}", winConditionInformation, g_MatchConfig.GetNum("maxrounds", 0));

        winConditions++;
    }

    if (winConditions > 0) {
        CPrintToChatAll("{green}[CompCtrl]{default} This period will end upon the fulfillment of one of the following: %s.", winConditionInformation);
    }
    else {
        CPrintToChatAll("{green}[CompCtrl]{default} This period does not have any end conditions.");
    }

    char nextPeriod[256];
    g_MatchConfig.GetString("next-period", nextPeriod, sizeof(nextPeriod), g_CurrentPeriod);
    char nextPeriodName[256];
    g_MatchConfig.Rewind();
    if (!g_MatchConfig.JumpToKey("periods") || !g_MatchConfig.JumpToKey(nextPeriod)) {
        ThrowError("Failed to find period!");
    }
    g_MatchConfig.GetString("name", nextPeriodName, sizeof(nextPeriodName));

    GetCurrentRoundConfig();

    if (g_MatchConfig.GetNum("end-game", 1)) {
        if (g_MatchConfig.GetNum("allow-draw", 0)) {
            CPrintToChatAll("{green}[CompCtrl]{default} Upon completion of this period, the match will end, even if there is a tie.");
        }
        else {
            CPrintToChatAll("{green}[CompCtrl]{default} Upon completion of this period, the match will end if a team is leading. If there is a tie, the match will proceed to the {olive}%s{default} period.", nextPeriodName);
        }
    }
    else {
        CPrintToChatAll("{green}[CompCtrl]{default} Upon completion of this period, the match will proceed to the {olive}%s{default} period.", nextPeriodName);
    }

    if (g_AllowConcede) {
        CPrintToChatAll("{green}[CompCtrl]{default} Teams may concede the match in this period.");
    }
    else {
        CPrintToChatAll("{green}[CompCtrl]{default} Teams cannot concede the match in this period.");
    }

    char redName[256];
    g_RedTeamName.GetString(redName, sizeof(redName));
    char bluName[256];
    g_BlueTeamName.GetString(bluName, sizeof(bluName));

    CPrintToChatAll("{green}[CompCtrl]{default} Timeouts available: {blue}%s{default} {olive}%i{default}, {red}%s{default} {olive}%i{default}.", bluName, g_BluTeamTimeoutsRemaining, redName, g_RedTeamTimeoutsRemaining);
}

void EndPeriod(int redScore, int bluScore, EndCondition endCondition, TFTeam cause) {
    g_InPeriod = false;

    GetCurrentRoundConfig();

    char periodName[256];
    g_MatchConfig.GetString("name", periodName, sizeof(periodName), "period");

    char redName[256];
    g_RedTeamName.GetString(redName, sizeof(redName));
    char bluName[256];
    g_BlueTeamName.GetString(bluName, sizeof(bluName));

    if (endCondition == EndCondition_TimeLimit) {
        CPrintToChatAll("{green}[CompCtrl]{default} The {olive}%s{default} period ends because the {olive}time limit{default} of {olive}%i{default} has expired.", periodName, g_MatchConfig.GetNum("timelimit", 0));
    }
    else if (endCondition == EndCondition_WinLimit) {
        if (cause == TFTeam_Red) {
            CPrintToChatAll("{green}[CompCtrl]{default} The {olive}%s{default} period ends because {red}%s{default} has reached the {olive}win limit{default} of {olive}%i{default}.", periodName, redName, g_MatchConfig.GetNum("winlimit", 0));
        }
        else if (cause == TFTeam_Blue) {
            CPrintToChatAll("{green}[CompCtrl]{default} The {olive}%s{default} period ends because {blue}%s{default} has reached the {olive}win limit{default} of {olive}%i{default}.", periodName, bluName, g_MatchConfig.GetNum("winlimit", 0));
        }
    }
    else if (endCondition == EndCondition_WinDifference) {
        if (cause == TFTeam_Red) {
            CPrintToChatAll("{green}[CompCtrl]{default} The {olive}%s{default} period ends because {red}%s{default} has reached the {olive}win difference{default} of {olive}%i{default} (with a minimum score of {olive}%i{default}).", periodName, redName, g_MatchConfig.GetNum("windifference", 0), g_MatchConfig.GetNum("windifference-min", 0));
        }
        else if (cause == TFTeam_Blue) {
            CPrintToChatAll("{green}[CompCtrl]{default} The {olive}%s{default} period ends because {blue}%s{default} has reached the {olive}win difference{default} of {olive}%i{default} (with a minimum score of {olive}%i{default}).", periodName, bluName, g_MatchConfig.GetNum("windifference", 0), g_MatchConfig.GetNum("windifference-min", 0));
        }
    }
    else if (endCondition == EndCondition_TimeLimit) {
        CPrintToChatAll("{green}[CompCtrl]{default} The {olive}%s{default} period ends because the {olive}max rounds{default} of {olive}%i{default} has been reached.", periodName, g_MatchConfig.GetNum("maxrounds", 0));
    }

    bool matchComplete = false;
    TFTeam leadingTeam = TFTeam_Unassigned;

    if (endCondition == EndCondition_Concede) {
        matchComplete = true;

        if (cause == TFTeam_Red) {
            leadingTeam = TFTeam_Blue;

            CPrintToChatAll("{green}[CompCtrl]{default} {red}%s{default} has conceded the match.", periodName, redName);
        }
        else if (cause == TFTeam_Blue) {
            leadingTeam = TFTeam_Red;

            CPrintToChatAll("{green}[CompCtrl]{default} {blue}%s{default} has conceded the match.", periodName, bluName);
        }
    }
    else {
        if (redScore > bluScore) {
            leadingTeam = TFTeam_Red;
        }
        else if (bluScore > redScore) {
            leadingTeam = TFTeam_Blue;
        }
        else {
            leadingTeam = TFTeam_Unassigned;
        }

        if (g_MatchConfig.GetNum("end-game", 1)) {
            if (leadingTeam == TFTeam_Unassigned && !g_MatchConfig.GetNum("allow-draw", 0)) {
                matchComplete = false;

                CPrintToChatAll("{green}[CompCtrl]{default} Score after {olive}%s{default}: {blue}%s{default} {olive}%i{default}, {red}%s{default} {olive}%i{default}.", periodName, bluName, bluScore, redName, redScore);
                CPrintToChatAll("{green}[CompCtrl]{default} Because no team has a lead, the match cannot end after this period and will proceed to another period.");
            }
            else {
                matchComplete = true;
            }
        }
        else {
            matchComplete = false;

            CPrintToChatAll("{green}[CompCtrl]{default} Score after {olive}%s{default}: {blue}%s{default} {olive}%i{default}, {red}%s{default} {olive}%i{default}.", periodName, bluName, bluScore, redName, redScore);
            CPrintToChatAll("{green}[CompCtrl]{default} The match will continue to the next period.");
        }
    }

    if (!matchComplete) {
        char nextPeriod[256];
        g_MatchConfig.GetString("next-period", nextPeriod, sizeof(nextPeriod), g_CurrentPeriod);

        if (g_TeamRequestingTimeout == TFTeam_Red) {
            g_TeamRequestingTimeout = TFTeam_Unassigned;

            CPrintToChatAll("{green}[CompCtrl]{default} Timeout requested earlier by {red}%s{default} has not been taken due to the period ending.", redName);
        }
        else if (g_TeamRequestingTimeout == TFTeam_Blue) {
            g_TeamRequestingTimeout = TFTeam_Unassigned;

            CPrintToChatAll("{green}[CompCtrl]{default} Timeout requested earlier by {blue}%s{default} has not been taken due to the period ending.", redName);
        }

        if (GetScore(TFTeam_Red) > GetScore(TFTeam_Blue)) {
            HudNotifyAll("redcapture", TFTeam_Red, "After the %s period, the score is %s %i, %s %i.", periodName, bluName, GetScore(TFTeam_Blue), redName, GetScore(TFTeam_Red));
        }
        else if (GetScore(TFTeam_Blue) > GetScore(TFTeam_Red)) {
            HudNotifyAll("bluecapture", TFTeam_Blue, "After the %s period, the score is %s %i, %s %i.", periodName, bluName, GetScore(TFTeam_Blue), redName, GetScore(TFTeam_Red));
        }
        else {
            HudNotifyAll("timer_icon", TFTeam_Unassigned, "After the %s period, the score is %s %i, %s %i.", periodName, bluName, GetScore(TFTeam_Blue), redName, GetScore(TFTeam_Red));
        }

        strcopy(g_CurrentPeriod, sizeof(g_CurrentPeriod), nextPeriod);

        GetCurrentRoundConfig();
        if (g_MatchConfig.GetNum("switch-teams-to-begin", 0)) {
            CPrintToChatAll("{green}[CompCtrl]{default} Teams will be automatically switched prior to the start of the next period.");
            g_SwitchTeams = true;
        }

        g_PeriodNeedsSetup = true;
    }
    else {
        CPrintToChatAll("{green}[CompCtrl]{default} The match is now over.");
        CPrintToChatAll("{green}[CompCtrl]{default} Final score: {blue}%s{default} {olive}%i{default}, {red}%s{default} {olive}%i{default}.", bluName, bluScore, redName, redScore);
        if (leadingTeam == TFTeam_Red) {
            CPrintToChatAll("{green}[CompCtrl]{default} {red}%s{default} has won the match against {blue}%s{default}.", redName, bluName);
            HudNotifyAll("redcapture", TFTeam_Red, "%s has defeated %s (final score %i - %i).", redName, bluName, GetScore(TFTeam_Red), GetScore(TFTeam_Blue));
        }
        else if (leadingTeam == TFTeam_Blue) {
            CPrintToChatAll("{green}[CompCtrl]{default} {blue}%s{default} has won the match against {red}%s{default}.", bluName, redName);
            HudNotifyAll("bluecapture", TFTeam_Blue, "%s has defeated %s (final score %i - %i).", bluName, redName, GetScore(TFTeam_Blue), GetScore(TFTeam_Red));
        }
        else {
            CPrintToChatAll("{green}[CompCtrl]{default} {blue}%s{default} and {red}%s{default} have drawn the match.", bluName, redName);
            HudNotifyAll("timer_icon", TFTeam_Unassigned, "%s and %s have drawn (final score %i - %i).", bluName, redName, GetScore(TFTeam_Blue), GetScore(TFTeam_Red));
        }

        CloseHandle(g_MatchConfig);
        g_MatchConfig = null;
        g_InMatch = false;
        g_MatchConfigName = "";
        g_InPeriod = false;
        g_CurrentPeriod = "";
        g_SwitchTeams = false;
        g_PeriodNeedsSetup = false;
        g_AllowScoreReset = true;
        g_RestartsLeft = 0;
        g_RoundsPlayed = 0;
        g_RedTeamScore = 0;
        g_BluTeamScore = 0;
        g_RedTeamTimeoutsRemaining = 0;
        g_BluTeamTimeoutsRemaining = 0;
        g_TimeoutLength = 30;
        g_TeamRequestingTimeout = TFTeam_Unassigned;
        g_TimeoutAlreadyTaken = false;
        g_AllowConcede = false;
        g_TeamConceding = TFTeam_Unassigned;
        g_DisableRoundTimers = false;
    }
}

bool CheckEndConditions(int redScore, int bluScore, EndCondition &endCondition, TFTeam &cause) {
    if (g_TeamConceding == TFTeam_Red || g_TeamConceding == TFTeam_Blue) {
        endCondition = EndCondition_Concede;
        cause = g_TeamConceding;
        return true;
    }

    GetCurrentRoundConfig();

    int timeLimit = g_MatchConfig.GetNum("timelimit", 0);

    if (timeLimit > 0 && GetTimeLeft() <= 0) {
        endCondition = EndCondition_TimeLimit;
        cause = TFTeam_Unassigned;
        return true;
    }

    int winLimit = g_MatchConfig.GetNum("winlimit", 0);

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

    int winDifference = g_MatchConfig.GetNum("windifference", 0);

    if (winDifference > 0) {
        int winDifferenceMin = g_MatchConfig.GetNum("windifference-min", 0);

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

    int maxRounds = g_MatchConfig.GetNum("maxrounds", 0);

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

void ConcedeMatch(TFTeam team) {
    g_TeamConceding = team;

    TFTeam winningTeam = TFTeam_Unassigned;
    if (team == TFTeam_Red) {
        winningTeam = TFTeam_Blue;
    }
    else if (team == TFTeam_Blue) {
        winningTeam = TFTeam_Red;
    }

    CompCtrl_SetWinningTeam(winningTeam, WinReason_None, true, false, false, true);
}

void RequestTimeout(TFTeam team) {
    g_TeamRequestingTimeout = team;

    if (team == TFTeam_Red) {
        char redName[256];
        g_RedTeamName.GetString(redName, sizeof(redName));

        CPrintToChatAll("{green}[CompCtrl]{default} Timeout requested by {red}%s{default} (currently has {olive}%i{default} remaining).", redName, g_RedTeamTimeoutsRemaining);
    }
    else if (team == TFTeam_Blue) {
        char bluName[256];
        g_BlueTeamName.GetString(bluName, sizeof(bluName));

        CPrintToChatAll("{green}[CompCtrl]{default} Timeout requested by {blue}%s{default} (currently has {olive}%i{default} remaining).", bluName, g_BluTeamTimeoutsRemaining);
    }

    CompCtrl_PauseStrategyPeriod(float(g_TimeoutLength));
}

void SetUpMainTimer(int timer) {
    if (g_DisableRoundTimers) {
    	char className[32] = "";
    	GetEntityClassname(timer, className, sizeof(className));

    	if (StrEqual(className, "team_round_timer")) {
			char timerName[128];
			GetEntPropString(timer, Prop_Data, "m_iName", timerName, sizeof(timerName));

			if (StrEqual(timerName, g_MainTimerName)) {
                DisableTimer(timer);
                SDKHook(timer, SDKHook_Think, Hook_TimerThink);
            }
		}
	}
}

void DisableTimer(int timer) {
	AcceptEntityInput(timer, "Disable");
}

StopwatchStatus GetStopwatchStatus() {
    if (!GameRules_GetProp("m_bStopWatch", 1)) {
        return StopwatchStatus_Unknown;
    }

    int tfObjectiveResource = FindEntityByClassname(-1, "tf_objective_resource");

    if (tfObjectiveResource != -1){
        int timer = GetEntProp(tfObjectiveResource, Prop_Send, "m_iStopWatchTimer");

        if (timer != -1) {
            char timerClassname[256];
            GetEdictClassname(timer, timerClassname, sizeof(timerClassname));

            if (StrEqual(timerClassname, "team_round_timer")) {
                if (GetEntProp(timer, Prop_Send, "m_bStopWatchTimer")) {
                    if (GetEntProp(timer, Prop_Send, "m_bInCaptureWatchState")) {
                        return StopwatchStatus_SetTarget;
                    }
                    else {
                        return StopwatchStatus_ChaseTarget;
                    }
                }
            }
        }
    }

    switch (GameRules_GetProp("m_nStopWatchState", 1)) {
        case 0: {
            return StopwatchStatus_SetTarget;
        }
        case 2: {
            return StopwatchStatus_ChaseTarget;
        }
        default: {
            return StopwatchStatus_Unknown;
        }
    }

    return StopwatchStatus_Unknown;
}

float GetTimeLeft() {
    float startTime = GameRules_GetPropFloat("m_flMapResetTime");
    float timeLimit = float(g_TimeLimit.IntValue * 60);
    float currentTime = GetGameTime();

    return (startTime + timeLimit) - currentTime;
}

int GetScore(TFTeam team) {
    GetCurrentRoundConfig();

    if (g_MatchConfig.GetNum("manual-scoring", 0)) {
        if (team == TFTeam_Red) {
            return g_RedTeamScore;
        }
        else if (team == TFTeam_Blue) {
            return g_BluTeamScore;
        }
    }
    else {
        return GetTeamScore(view_as<int>(team));
    }

    return 0;
}

void GetCurrentRoundConfig() {
    g_MatchConfig.Rewind();

    if (!g_MatchConfig.JumpToKey("periods") || !g_MatchConfig.JumpToKey(g_CurrentPeriod)) {
        ThrowError("Failed to find period!");
    }
}
