#pragma newdecls required

/**
 * @brief   Called when a strategy period is about to be entered.
 *
 * @return  Plugin_Continue to allow the strategy period to begin, Plugin_Changed or above to bypass the strategy period.
 */
forward Action CompCtrl_OnStrategyPeriodBegin();

#pragma newdecls optional
