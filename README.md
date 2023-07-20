# CampBuddy
An addon for ashita to help you track placeholder repop times.

When there's a timer prepared using the below commands, when the chosen mob(s) die, a timer will automatically be started. You'll see it on your screen. It will continue to start again whenever the chosen mob dies. You will not see a timer until the chosen mob dies. The timer starts when you see the "X was defeated by Y." or other similar defeat messages. So set your timers accordingly (and extra 16 seconds normally).

Once you put it into you addons folder (`..\HorizonXI-Launcher\HorizonXI\Game\addons\campbuddy`) load it with
`/addon load campbuddy`

Here are your campbuddy commands:

```
/cbud addtg <H> <M> <S>  will prepare a timer for the current targeted mob.
/cbud addid <ID> <H> <M> <S>  will prepare a timer for the defined mob ID.
/cbud addnm <name> <H> <M> <S>  will prepare a timer for the defined mob name (name must not contain spaces).
/cbud addpr <profile>  will prepare a timers for the defined profile.
/cbud zonepr  toggles profile loading on zone in (and addon load).
/cbud start <ID or name>  force start defined timer with max time.
/cbud start <ID or name> <H> <M> <S>  force start defined timer at H M S.
/cbud del <ID>  delete chosen timer.
/cbud del all  delete all timers.
/cbud list  print timers list.
/cbud move <X> <Y>  move the timers.
/cbud sound  toggle sound when a timer reaches 00:00:00.
/cbud info  prints target ID, clock position, and sound status.
/cbud help  print help.
```
Timers created with `addtg` or `addid` (ID named timers) will not renew after zoning.<br />
Timers created with `addnm` (Mob named timers) will renew, even if you've zoned (as long as you can see the defeat message in chat).

This is so you can make a timer for the NM itself and set it for the window reopen.<br />
Example: `/cbud addnm Despot 2 0 0` will start a 2hour timer when you see Despot die.

When using `addtg` or `addid` commands you can also use `dng` (16min 16sec) or `fld` (5min 46sec) instead of a defined H M S.

If you want to change any settings permanently you'll have to edit the settings at the top of the lua. It's all pretty obvious what options there are.

If you want to add a new NM profile, You'll need to manually add it to profiles.lua.
