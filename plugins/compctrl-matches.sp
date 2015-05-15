#include <sourcemod>

#include <compctrl_version>
#include <compctrl_extension>
#include <compctrl-matches>
#include <morecolors>
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
int g_RoundsPlayed = 0;
int g_RedTeamScore = 0;
int g_BluTeamScore = 0;

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

public Plugin myinfo =
{
    name = "CompCtrl Match Management",
    author = "Forward Command Post",
    description = "a plugin to manage matches in tournament mode",
    version = COMPCTRL_VERSION,
    url = "http://github.com/fwdcp/CompCtrl/"
};

public void OnPluginStart() {
    RegAdminCmd("sm_startmatch", Command_StartMatch, ADMFLAG_CONFIG, "sets up and starts a match regulated by CompCtrl with the specified config", "compctrl");
    RegAdminCmd("sm_cancelmatch", Command_CancelMatch, ADMFLAG_CONFIG, "cancels and stops a CompCtrl match", "compctrl");

    RegConsoleCmd("sm_matchstatus", Command_MatchStatus, "get the status of the current match");

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

    HookEvent("teamplay_round_start", Event_RoundStart);
}

public Action Command_StartMatch(int client, int args) {
    if (g_InMatch) {
        CPrintToChatAll("{green}[CompCtrl]{default} Current match is being reset.");

        ServerCommand("mp_tournament_restart");
    }

    if (g_MatchConfig != INVALID_HANDLE) {
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
    g_RoundsPlayed = 0;
    g_RedTeamScore = 0;
    g_BluTeamScore = 0;

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

    SetConVarBool(g_Tournament, true, true, true);
    SetConVarBool(g_TournamentNonAdminRestart, false);
    g_InMatch = true;
    g_AllowScoreReset = true;
    strcopy(g_MatchConfigName, sizeof(g_MatchConfigName), arg);
    KvGetSectionName(g_MatchConfig, g_CurrentPeriod, sizeof(g_CurrentPeriod));

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

    if (g_MatchConfig != INVALID_HANDLE) {
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
    g_RoundsPlayed = 0;
    g_RedTeamScore = 0;
    g_BluTeamScore = 0;

    return Plugin_Handled;
}

public Action Command_MatchStatus(int client, int args) {
    if (g_InMatch) {
        CPrintToChat(client, "{green}[CompCtrl]{default} No match currently occurring.");
    }
    else {
        GetCurrentRoundConfig();

        int currentRound = g_RoundsPlayed + 1;

        if (GameRules_GetProp("m_bStopWatch", 1)) {
            if (g_MatchConfig.GetNum("timelimit", 0) > 0) {
                int timeLeft;
                GetMapTimeLeft(timeLeft);

                switch (GetStopwatchStatus()) {
                    case StopwatchStatus_SetTarget: {
                        CPrintToChat(client, "{green}[CompCtrl]{default} Period status: set part of round {olive}%i{default} with {olive}%i:%02i{default} remaining.", currentRound, timeLeft / 60, timeLeft % 60);
                    }
                    case StopwatchStatus_ChaseTarget: {
                        CPrintToChat(client, "{green}[CompCtrl]{default} Period status: chase part of round {olive}%i{default} with {olive}%i:%02i{default} remaining.", currentRound, timeLeft / 60, timeLeft % 60);
                    }
                    default: {
                        CPrintToChat(client, "{green}[CompCtrl]{default} Period status: round {olive}%i{default} with {olive}%i:%02i{default} remaining.", currentRound, timeLeft / 60, timeLeft % 60);
                    }
                }
            }
            else {
                switch (GetStopwatchStatus()) {
                    case StopwatchStatus_SetTarget: {
                        CPrintToChat(client, "{green}[CompCtrl]{default} Period status: set part of round {olive}%i{default}.", currentRound);
                    }
                    case StopwatchStatus_ChaseTarget: {
                        CPrintToChat(client, "{green}[CompCtrl]{default} Period status: chase part of round {olive}%i{default}.", currentRound);
                    }
                    default: {
                        CPrintToChat(client, "{green}[CompCtrl]{default} Period status: round {olive}%i{default}.", currentRound);
                    }
                }
            }
        }
        else {
            if (g_MatchConfig.GetNum("timelimit", 0) > 0) {
                int timeLeft;
                GetMapTimeLeft(timeLeft);

                CPrintToChat(client, "{green}[CompCtrl]{default} Period status: round {olive}%i{default} with {olive}%i:%02i{default} remaining.", currentRound, timeLeft / 60, timeLeft % 60);
            }
            else {
                CPrintToChat(client, "{green}[CompCtrl]{default} Period status: round {olive}%i{default}.", currentRound);
            }
        }

        char redName[256];
        GetConVarString(g_RedTeamName, redName, sizeof(redName));
        char bluName[256];
        GetConVarString(g_BlueTeamName, bluName, sizeof(bluName));

        CPrintToChat(client, "{green}[CompCtrl]{default} Current score: {blue}%s{default} {olive}%i{default}, {red}%s{default} {olive}%i{default}.", bluName, GetScore(TFTeam_Blue), redName, GetScore(TFTeam_Red));
    }

    return Plugin_Handled;
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast) {
    if (g_InMatch) {
        g_AllowScoreReset = false;
        g_SwitchTeams = false;

        GetCurrentRoundConfig();

        if (g_MatchConfig.GetNum("manual-scoring", 0)) {
            SetConVarInt(g_TimeLimit, 0, true, true);
            SetConVarInt(g_WinLimit, 0, true, true);
            SetConVarInt(g_WinDifference, 0, true, true);
            SetConVarInt(g_WinDifferenceMin, 0, true, true);
            SetConVarInt(g_MaxRounds, 0, true, true);
        }

        if (!GameRules_GetProp("m_bStopWatch", 1) || GetStopwatchStatus() == StopwatchStatus_SetTarget) {
            if (g_RoundsPlayed == 0) {
                char periodName[256];
                KvGetString(g_MatchConfig, "name", periodName, sizeof(periodName), "period");

                CPrintToChatAll("{green}[CompCtrl]{default} Starting {olive}%s{default}.", periodName);

                g_InPeriod = true;
            }
        }

        int currentRound = g_RoundsPlayed + 1;

        if (GameRules_GetProp("m_bStopWatch", 1)) {
            if (g_MatchConfig.GetNum("timelimit", 0) > 0) {
                int timeLeft;
                GetMapTimeLeft(timeLeft);

                switch (GetStopwatchStatus()) {
                    case StopwatchStatus_SetTarget: {
                        CPrintToChatAll("{green}[CompCtrl]{default} Period status: set part of round {olive}%i{default} with {olive}%i:%02i{default} remaining.", currentRound, timeLeft / 60, timeLeft % 60);
                    }
                    case StopwatchStatus_ChaseTarget: {
                        CPrintToChatAll("{green}[CompCtrl]{default} Period status: chase part of round {olive}%i{default} with {olive}%i:%02i{default} remaining.", currentRound, timeLeft / 60, timeLeft % 60);
                    }
                    default: {
                        CPrintToChatAll("{green}[CompCtrl]{default} Period status: round {olive}%i{default} with {olive}%i:%02i{default} remaining.", currentRound, timeLeft / 60, timeLeft % 60);
                    }
                }
            }
            else {
                switch (GetStopwatchStatus()) {
                    case StopwatchStatus_SetTarget: {
                        CPrintToChatAll("{green}[CompCtrl]{default} Period status: set part of round {olive}%i{default}.", currentRound);
                    }
                    case StopwatchStatus_ChaseTarget: {
                        CPrintToChatAll("{green}[CompCtrl]{default} Period status: chase part of round {olive}%i{default}.", currentRound);
                    }
                    default: {
                        CPrintToChatAll("{green}[CompCtrl]{default} Period status: round {olive}%i{default}.", currentRound);
                    }
                }
            }
        }
        else {
            if (g_MatchConfig.GetNum("timelimit", 0) > 0) {
                int timeLeft;
                GetMapTimeLeft(timeLeft);

                CPrintToChatAll("{green}[CompCtrl]{default} Period status: round {olive}%i{default} with {olive}%i:%02i{default} remaining.", currentRound, timeLeft / 60, timeLeft % 60);
            }
            else {
                CPrintToChatAll("{green}[CompCtrl]{default} Period status: round {olive}%i{default}.", currentRound);
            }
        }

        char redName[256];
        GetConVarString(g_RedTeamName, redName, sizeof(redName));
        char bluName[256];
        GetConVarString(g_BlueTeamName, bluName, sizeof(bluName));

        CPrintToChatAll("{green}[CompCtrl]{default} Current score: {blue}%s{default} {olive}%i{default}, {red}%s{default} {olive}%i{default}.", bluName, GetScore(TFTeam_Blue), redName, GetScore(TFTeam_Red));
    }
}

public Action CompCtrl_OnSetWinningTeam(TFTeam &team, WinReason &reason, bool &forceMapReset, bool &switchTeams, bool &dontAddScore) {
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
        }
        else {
            EndPeriod(redScore, bluScore, endCondition, cause);
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

public Action CompCtrl_OnCheckWinLimit(bool &returnValue) {
    if (g_InMatch) {
        GetCurrentRoundConfig();

        if (g_MatchConfig.GetNum("manual-scoring", 0)) {
            EndCondition endCondition;
            TFTeam cause;

            returnValue = CheckEndConditions(GetScore(TFTeam_Red), GetScore(TFTeam_Blue), endCondition, cause);
            return Plugin_Changed;
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

void BeginPeriod() {
    GetCurrentRoundConfig();

    SetConVarBool(g_Stopwatch, view_as<bool>(g_MatchConfig.GetNum("stopwatch", 1)), true, true);
    SetConVarBool(g_SuddenDeath, view_as<bool>(g_MatchConfig.GetNum("sudden-death", 0)), true, true);
    SetConVarInt(g_TimeLimit, g_MatchConfig.GetNum("timelimit", 0), true, true);
    SetConVarInt(g_WinLimit, g_MatchConfig.GetNum("winlimit", 0), true, true);
    SetConVarInt(g_WinDifference, g_MatchConfig.GetNum("windifference", 0), true, true);
    SetConVarInt(g_WinDifferenceMin, g_MatchConfig.GetNum("windifference-min", 0), true, true);
    SetConVarInt(g_MaxRounds, g_MatchConfig.GetNum("maxrounds", 0), true, true);
    SetConVarInt(g_FlagCapsPerRound, g_MatchConfig.GetNum("flag-caps-per-round", 0), true, true);

    g_RoundsPlayed = 0;

    char periodName[256];
    KvGetString(g_MatchConfig, "name", periodName, sizeof(periodName), "period");

    CPrintToChatAll("{green}[CompCtrl]{default} The next period will be: {olive}%s{default}.", periodName);

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
    KvGetString(g_MatchConfig, "next-period", nextPeriod, sizeof(nextPeriod), g_CurrentPeriod);
    char nextPeriodName[256];
    g_MatchConfig.Rewind();
    if (!g_MatchConfig.JumpToKey("periods") || !g_MatchConfig.JumpToKey(nextPeriod)) {
        ThrowError("Failed to find period!");
    }
    KvGetString(g_MatchConfig, "name", nextPeriodName, sizeof(nextPeriodName));

    GetCurrentRoundConfig();

    if (g_MatchConfig.GetNum("end-game", 1)) {
        if (g_MatchConfig.GetNum("allow-tie", 0)) {
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

void EndPeriod(int redScore, int bluScore, EndCondition endCondition, TFTeam cause) {
    g_InPeriod = false;

    GetCurrentRoundConfig();

    char periodName[256];
    KvGetString(g_MatchConfig, "name", periodName, sizeof(periodName), "period");

    char redName[256];
    GetConVarString(g_RedTeamName, redName, sizeof(redName));
    char bluName[256];
    GetConVarString(g_BlueTeamName, bluName, sizeof(bluName));

    if (endCondition == EndCondition_TimeLimit) {
        CPrintToChatAll("{green}[CompCtrl]{default} The {olive}%s{default} ends because the {olive}time limit{default} of {olive}%i{default} has expired.", periodName, g_MatchConfig.GetNum("timelimit", 0));
    }
    else if (endCondition == EndCondition_WinLimit) {
        if (cause == TFTeam_Red) {
            CPrintToChatAll("{green}[CompCtrl]{default} The {olive}%s{default} ends because {red}%s{default} has reached the {olive}win limit{default} of {olive}%i{default}.", periodName, redName, g_MatchConfig.GetNum("winlimit", 0));
        }
        else if (cause == TFTeam_Blue) {
            CPrintToChatAll("{green}[CompCtrl]{default} The {olive}%s{default} ends because {blue}%s{default} has reached the {olive}win limit{default} of {olive}%i{default}.", periodName, bluName, g_MatchConfig.GetNum("winlimit", 0));
        }
    }
    else if (endCondition == EndCondition_WinDifference) {
        if (cause == TFTeam_Red) {
            CPrintToChatAll("{green}[CompCtrl]{default} The {olive}%s{default} ends because {red}%s{default} has reached the {olive}win difference{default} of {olive}%i{default} (with a minimum score of {olive}%i{default}).", periodName, redName, g_MatchConfig.GetNum("windifference", 0), g_MatchConfig.GetNum("windifference-min", 0));
        }
        else if (cause == TFTeam_Blue) {
            CPrintToChatAll("{green}[CompCtrl]{default} The {olive}%s{default} ends because {blue}%s{default} has reached the {olive}win difference{default} of {olive}%i{default} (with a minimum score of {olive}%i{default}).", periodName, bluName, g_MatchConfig.GetNum("windifference", 0), g_MatchConfig.GetNum("windifference-min", 0));
        }
    }
    else if (endCondition == EndCondition_TimeLimit) {
        CPrintToChatAll("{green}[CompCtrl]{default} The {olive}%s{default} ends because the {olive}max rounds{default} of {olive}%i{default} has been reached.", periodName, g_MatchConfig.GetNum("maxrounds", 0));
    }

    char nextPeriod[256];
    KvGetString(g_MatchConfig, "next-period", nextPeriod, sizeof(nextPeriod), g_CurrentPeriod);

    if (g_MatchConfig.GetNum("end-game", 1)) {
        if (redScore == bluScore && !g_MatchConfig.GetNum("allow-tie", 0)) {
            CPrintToChatAll("{green}[CompCtrl]{default} Score after {olive}%s{default}: {blue}%s{default} {olive}%i{default}, {red}%s{default} {olive}%i{default}.", periodName, bluName, bluScore, redName, redScore);
            CPrintToChatAll("{green}[CompCtrl]{default} Because no team has a lead, the match cannot end after this period and will proceed to another period.");

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

            CloseHandle(g_MatchConfig);
            g_MatchConfig = null;
            g_InMatch = false;
            g_MatchConfigName = "";
            g_InPeriod = false;
            g_CurrentPeriod = "";
            g_SwitchTeams = false;
            g_PeriodNeedsSetup = false;
            g_AllowScoreReset = true;
            g_RoundsPlayed = 0;
            g_RedTeamScore = 0;
            g_BluTeamScore = 0;
        }
    }
    else {
        CPrintToChatAll("{green}[CompCtrl]{default} Score after {olive}%s{default}: {blue}%s{default} {olive}%i{default}, {red}%s{default} {olive}%i{default}.", periodName, bluName, bluScore, redName, redScore);
        CPrintToChatAll("{green}[CompCtrl]{default} The match will continue to the next period.");

        strcopy(g_CurrentPeriod, sizeof(g_CurrentPeriod), nextPeriod);

        GetCurrentRoundConfig();
        if (g_MatchConfig.GetNum("switch-teams-to-begin", 0)) {
            CPrintToChatAll("{green}[CompCtrl]{default} Teams will be automatically switched prior to the start of the next period.");
            g_SwitchTeams = true;
        }

        g_PeriodNeedsSetup = true;
    }
}

bool CheckEndConditions(int redScore, int bluScore, EndCondition &endCondition, TFTeam &cause) {
    GetCurrentRoundConfig();

    int timeLimit = g_MatchConfig.GetNum("timelimit", 0);

    if (timeLimit > 0) {
        int timeLeft;
        GetMapTimeLeft(timeLeft);

        if (timeLeft <= 0) {
            endCondition = EndCondition_TimeLimit;
            cause = TFTeam_Unassigned;
            return true;
        }
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
