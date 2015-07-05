# Witch Balance
This is a sourcemod plugin concept for Left 4 Dead 2 thought up by High Cookie to try and balance the Witch in competitive play.

## Specifics
Originally whenever a player is revived after being downed by a witch, they are revived at 1 health and 29 temporary buffer health which slowly degrades over time, in most competitive modes this immediately removes a large portion of the bonus points from health that are available to that team without any input required by the enemy team, this plugin aims to change that.

There are 2 cvars available to customise this plugin:
* **wb_witchdamage** - *Default: 30* This sets the amount of health lost on revival after being downed by a witch, if this is set to 100, then the witch incap will act as normal (unless the player somehow has more than 100 health at the time of incap due to shady reasons)
* **wb_bufferthreshold** - *Default: 0* This sets the minimum amount of health a survivor can have after being revived, if they have 10 health then they will be given temporary buffer health to bring them up to the buffer threshold.

Whenever a player that was downed by a witch is revived, we check to see if the total health the player had (health + temp buffer) can survive the witch damage, if the player can survive then we remove the witch damage from their total health prioritising permanent health first and then buffer health and the incap does not count to the total incaps.

If the players total health is not greater than the witch damage, then the incap is counted as an incap and the survivor is revived with the normal 1 perm health and 29 temp buffer health.

##Possible Issues
I'm not experienced with SourcePawn or SourceMod coding, so there will undoubtedly be many changes that need to be made.

* Not getting the current temp buffer health correctly when calculating the health to revive the survivor at, need to find out if the damage the witch does to downed players removes perm health first and then temp health and if it changes the maximum buffer health the player has, will do this soon unless somenone else knows.
