CompCtrl
========

a Team Fortress 2 server plugin that improves competitive play handling

Build Status
------------
[![Travis CI](https://travis-ci.org/fwdcp/CompCtrl.svg?branch=develop)](https://travis-ci.org/fwdcp/CompCtrl)
[![AppVeyor](https://ci.appveyor.com/api/projects/status/qjsojaof27c14xks/branch/develop?svg=true)](https://ci.appveyor.com/project/thesupremecommander/compctrl)

Installation
------------
1. Unzip the files for your platform into the `tf` directory.

Changelog
---------

### 0.5.4
* map timers
  * fix map timers not syncing with game changes

### 0.5.3
* matches
  * fix time left appearing incorrectly

### 0.5.2
* matches
  * update Insomnia configs

### 0.5.1
* coaches
  * fix coaches appearing on scoreboard

### 0.5.0
* coaches
  * release initial version of coaches module
* game countdowns
  * release initial version of game countdowns module
* matches
  * fix match status command
  * condense & update ozfortress configs
  * add Insomnia configs
* player aliases
  * release initial version of player aliases module

### 0.4.5
* general
  * update gamedata

### 0.4.4
* general
  * update gamedata

### 0.4.3
* general
  * recompile with latest SourceMod version

### 0.4.2
* general
  * include source for strategy periods plugin in package

### 0.4.1
* general
  * update gamedata
  * add forwards for demo recording

### 0.4.0
* general
  * fix gamedata for Windows servers
* map timers
  * release initial version of map timers module
* strategy periods
  * release initial version of strategy periods module

### 0.3.1
* general
  * update gamedata for Invasion update

### 0.3.0
* general
  * update for new SourceMod syntax
  * update gamedata for Gun Mettle update
* matches
  * add HUD match status
  * add live on x restarts
  * update configs
* teams
  * remove module

### 0.2.3
* general
  * fix offsets for 2014-09-10 update
* matches
  * add notification of team switch after period break
* teams
  * add HUD display of ready/unready players

### 0.2.2
* teams
  * list players on team that haven't readied up when team fails to ready up

### 0.2.1
* matches
  * prevent tournament from being restarted by CompCtrl if not managed by CompCtrl

### 0.2.0
* matches
  * split match configs into separate files
  * adjust ozfortress configs as requested
  * add command to cancel matches

### 0.1.4
* teams
  * fix ready status not working

### 0.1.3
* general
  * fix automatic versioning for plugins (again)

### 0.1.2
* matches
  * add ozfortress configs
  * improve win condition reporting
* teams
  * add command to check ready status
  * add ability to automatically set teams as ready
  * check more cases for a team not being eligible for ready

### 0.1.1
* general
  * fix automatic versioning

### 0.1.0
* matches
  * release initial version of matches module
* teams
  * release initial version of teams module

Modules
-------
**Notes:**
* Any commands prefixed with `sm_` may also be used in chat via `/` or `!` - for example, `/ready` or `!ready` in chat is equivalent to `sm_ready` in the console.

### Coaches
*adds abilities for players to act as coaches*

#### Console Commands
`sm_becomecoach`, if used while a player is on a team, places them in a coach role where they are only able to spectate other teammates. `sm_becomeplayer` removes the coach status and allows the player to play normally.

### Game Countdowns
*manages start countdowns for competitive games*

#### Console Variables
`compctrl_gamecountdowns_managed` determines whether the countdowns are managed - if not, game countdowns are run normally by the game. `compctrl_gamecountdowns_time` determines how long the countdowns will run, overriding the game's default countdown length of 5 or 10 seconds. `compctrl_gamecountdowns_paused` determines if the current countdown (if any) is paused - if a countdown is running and is paused, the countdown will be reset to full length. `compctrl_gamecountdowns_autorun` determines if the countdowns should automatically run when triggered by the game, though their length will still be customized and can still be paused/unpaused via the other console variables.

### Map Timers
*manages the map timer*

#### Console Variables
`compctrl_maptimers_autopause` determines whether the map timer should pause when the game is not being actively played.

### Matches
*manages the flow of a match*

#### Admin Commands
`sm_startmatch <config>` is used to start a match with a specified config. The command requires the name of a match config file (without the `.cfg` extension) that will be used to regulate the match. `sm_cancelmatch` cancels any match that may be in progress.

#### Console Commands
`sm_matchstatus` will display the current status of the ongoing match.

#### Configuration Files
All of the files within the `configs/compctrl/matches` may be used by the `sm_startmatch` command. You may add, remove, or modify configs in this folder as desired (but if you do, make sure to back up your configs in case they are overwritten during a CompCtrl update).

### Player Aliases
*enforces player aliases*

#### Admin Commands
`sm_setalias <steamid> <alias>` will set the enforced alias for a user, while `sm_removealias <steamid>` will remove it.

### Strategy Periods
*adds time between rounds to strategize*

#### Console Commands
`sm_requestpause` will pause the timer if currently in a strategy period, and otherwise will schedule a pause for the next strategy period. `sm_cancelpause` will cancel any current pause in a strategy period and any future requests.

#### Console Variables
`compctrl_strategyperiods_time` determines how long each strategy period is (in seconds).
