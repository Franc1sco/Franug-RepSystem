# Franug-RepSystem


### Installation:
```
Add a database entry called "franug_repsystem" on addons/sourcemod/configs/databases.cfg
```

### Cvars (put in server.cfg):
```
sm_repsystem_times "3" // Times that a regular player can vote during 24 H. 0 = unlimited.
sm_repsystem_viptimes "5" // Times that a vip player can vote during 24 H. 0 = unlimited.
sm_repsystem_admintimes "5" // Times that a admin player can vote during 24 H. 0 = unlimited.
sm_repsystem_vipflag "o" // Flag required for be Vip.
sm_repsystem_adminflag "b" // Flag required for be Admin.
```


### Commands:
```
!up <#userid|playername> // give +1 to a player
!down <#userid|playername> // give -1 to a player
!reptop // See the top
!rep <#userid|playername> // See the current points from a player
```
