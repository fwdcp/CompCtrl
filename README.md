CompCtrl
========

a Team Fortress 2 server plugin that improves competitive play handling

Installation
------------
1. Unzip the files for your platform into the `tf` directory.

Changelog
---------

**0.2.3**
* general
  * fix offsets for 2014-09-10 update
* matches
  * add notification of team switch after period break
* teams
  * add HUD display of ready/unready players

**0.2.2**
* teams
  * list players on team that haven't readied up when team fails to ready up

**0.2.1**
* matches
  * prevent tournament from being restarted by CompCtrl if not managed by CompCtrl

**0.2.0**
* matches
  * split match configs into separate files
  * adjust ozfortress configs as requested
  * add command to cancel matches

**0.1.4**
* teams
  * fix ready status not working

**0.1.3**
* general
  * fix automatic versioning for plugins (again)

**0.1.2**
* matches
  * add ozfortress configs
  * improve win condition reporting
* teams
  * add command to check ready status
  * add ability to automatically set teams as ready
  * check more cases for a team not being eligible for ready

**0.1.1**
* general
  * fix automatic versioning

**0.1.0**
* matches
  * release initial version of matches module
* teams
  * release initial version of teams module

Modules
-------
**Notes:**
* Any commands prefixed with `sm_` may also be used in chat via `/` or `!` - for example, `/ready` or `!ready` in chat is equivalent to `sm_ready` in the console.

### Matches
*manages the flow of a match*

#### Admin Commands

##### Match Management Commands
`sm_startmatch <config>` is used to start a match with a specified config. The command requires the name of a match config file (without the `.cfg` extension) that will be used to regulate the match. `sm_cancelmatch` cancels any match that may be in progress.

#### Configuration Files

##### Match Configurations
All of the files within the `configs/compctrl/matches` may be used by the `sm_startmatch` command. You may add, remove, or modify configs in this folder as desired (but if you do, make sure to back up your configs in case they are overwritten during a CompCtrl update).

### Teams
*implements a team ready system and other features*

#### Console Variables

##### Auto Ready Variable
`compctrl_team_auto_ready` sets the number of players at which, if all the players on the team are ready, a team will be automatically set to ready. A setting of 0 disables this feature.

##### Player Limit Variables
`compctrl_team_players_min` and `compctrl_team_players_max` set limits on the number of players a team is allowed to play with. A setting of 0 indicates no limit.

##### Team Ready HUD Variables
`compctrl_team_ready_hud` sets whether or not to show a HUD that displays the players who are ready and not ready to all clients.
	
#### Console Commands

##### Player Ready Commands
`sm_ready` and `sm_unready` are used by a player to set their ready status.

##### Ready Status Command
`sm_readystatus` will display a list of players that are ready and not ready.

##### Team Ready Commands
`sm_teamready` and `sm_teamunready` may be used as an alternative to the tournament interface. Note that teams will not be allowed to set themselves as ready if they have an incorrect number of players or if all of the players on the team are not ready.

##### Team Name Command
`sm_teamname <name>` may be used to set the name of a team, and supports longer names than is allowed by normal TF2. It is recommended that the team name be quoted.