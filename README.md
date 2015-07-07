# Witch Balance
This is a sourcemod plugin concept for Left 4 Dead 2 thought up by High Cookie to try and balance the Witch in competitive play.

## Specifics
Originally whenever a player is revived after being downed by a witch, they are revived at 1 health and 29 temporary buffer health which slowly degrades over time, in most competitive modes this immediately removes a large portion of the bonus points from health that are available to that team without any input required by the enemy team, this plugin aims to change that.

There are 2 cvars available to customise this plugin:
* **wb_witchdamage** - *Default: 30* This sets the amount of health lost on revival after being downed by a witch, if this is set to 100, then the witch incap will act as normal (unless the player somehow has more than 100 health at the time of incap due to shady reasons)
* **wb_bufferthreshold** - *Default: 0* This sets the minimum amount of health a survivor can have after being revived, eg. if wb_bufferthreshold is set to 30 and a player is to be revived with 10 perm health then they will be given 20 temp health to bring their total health up to 30.
* **wb_announcemode** - *Default: 1* This sets what information should be announced to players, 0 = No announcements, 1 = Players will be informed whether a player downed by a witch will not lose an incap, 2 = Players will be informed whether a player downed by a witch will lose an incap, 3 = Both 1 & 2.

Whenever a player is downed by a witch, we check to see if the total health the player has (health + temp buffer) can survive the witch damage, if the player can survive then we remove the witch damage from their total health prioritising permanent health first and then buffer health and the incap (provided they get revived) does not count to the total incaps the player has suffered.

If the players total health is not greater than the witch damage, then the incap is counted as an incap and the survivor is revived with the normal 1 perm health and 29 temp buffer health.

##Possible Issues
I'm not experienced with SourcePawn or SourceMod coding, so there will undoubtedly be many changes that need to be made.
* Not sure how to stop the heartbeat sound from playing.