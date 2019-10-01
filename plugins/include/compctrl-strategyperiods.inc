#pragma newdecls required

/**
 * @brief       Called when a strategy period is about to be entered.
 *
 * @return      Plugin_Continue to allow the strategy period to begin, Plugin_Changed or above to bypass the strategy period.
 */
forward Action CompCtrl_OnStrategyPeriodBegin();

/**
 * @brief       Called when a strategy period pause is about to begin.
 *
 * @param time  The amount of time the pause will last for. A value of zero indicates the pause is indefinite.
 * @return      Plugin_Continue to allow the pause to begin, Plugin_Changed if the pause time has been altered, Plugin_Handled or above to prevent the pause.
 */
forward Action CompCtrl_OnStrategyPeriodPauseBegin(float &time);

/**
 * @brief       Called when a strategy period pause is about to end.
 *
 * @param time  If the pause is not ended, the amount of extra time the pause will continue. A value of zero indicates the pause will continue indefinitely.
 * @return      Plugin_Continue to allow the pause to end, Plugin_Changed or above to continue the pause.
 */
forward Action CompCtrl_OnStrategyPeriodPauseEnd(float &time);

/**
 * @brief       Begins a pause if one is currently not running (or, if a strategy period is not active, schedules a pause for the next strategy period).
 *
 * @param time  How long the pause should last. A value of zero indicates the pause should last indefinitely.
 * @return      Whether the pause was successfully started or scheduled.
 */
native bool CompCtrl_PauseStrategyPeriod(float time = 0.0);

/**
 * @brief       Ends a pause if one is currently running (or, if a strategy period is not active, cancels a scheduled pause if one exists).
 *
 * @return      Whether the pause was successfully ended or canceled.
 */
native bool CompCtrl_UnpauseStrategyPeriod();

#pragma newdecls optional
