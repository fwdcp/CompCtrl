CompCtrl
========

a Team Fortress 2 server plugin that improves competitive play handling

Installation
------------
1. Unzip the files for your platform into the `tf` directory.

Changelog
---------

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

##### Match Configuration Command
`sm_match <config>` is used to start a match with a specified config. The command requires the name of a match config from the config file that will be used to regulate the match.

#### Configuration Files

##### Match Configuration
`compctrl-matches.cfg` contains all of the match configs. You may add or remove as desired (but if you do, make sure to back up your configs in case they are overwritten during a CompCtrl update).

### Teams
*implements a team ready system and other features*

#### Console Variables

##### Player Limit Commands
`compctrl_team_players_min` and `compctrl_team_players_max` set limits on the number of players a team is allowed to play with. A setting of 0 indicates no limit.
	
#### Console Commands

##### Player Ready Commands
`sm_ready` and `sm_unready` are used by a player to set their ready status.

##### Team Ready Commands
`sm_teamready` and `sm_teamunready` may be used as an alternative to the tournament interface. Note that teams will not be allowed to set themselves as ready if they have an incorrect number of players or if all of the players on the team are not ready.

##### Team Name Command
`sm_teamname <name>` may be used to set the name of a team, and supports longer names than is allowed by normal TF2. It is recommended that the team name be quoted.