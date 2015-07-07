#include <sourcemod>
#include <sdktools>

public Plugin:myinfo = 
{
    name = "Cookie's Witch Balance",
    author = "High Cookie & Standalone(aka Manu)",
    description = "A Witch balance plugin, still needs a little bit of work.",
    version = "1.1.0",
    url = ""
};

new Handle:PlayersDownedTrie    = INVALID_HANDLE;
new Handle:wb_witchDamage       = INVALID_HANDLE;
new Handle:wb_bufferThreshold   = INVALID_HANDLE;
new Handle:wb_announceMode      = INVALID_HANDLE;

public OnPluginStart()
{
    //not sure if m_preIncapacitatedHealth/Buffer could be of better use on revive_success, will try later.
    HookEvent("player_incapacitated_start", Event_PlayerIncapacitatedStart);
    HookEvent("player_death", Event_PlayerDeath);
    //Called when a Bot replaces a Player. (Disconnects?)
    HookEvent("player_bot_replace", Event_PlayerBotReplace);
    //Called when a Player replaces a Bot. (Connection?)
    HookEvent("bot_player_replace", Event_BotPlayerReplace);
    
    HookEvent("revive_success", Event_ReviveSuccess);
    //Need this so we can store the amount of temp health the player was revived at.
    HookEvent("revive_begin", Event_ReviveBegin);
    
    //Storing arrays of player information at keys of the players user id as a string.
    //There's probably a better way to get this information rather than storing it on the hook events, but I'm not aware of them just yet.
    //values[0] = health the player went down with
    //values[1] = current temp health the player went down with
    //values[2] = health the player was revived with
    //values[4] = current temp health the player was revived with
    PlayersDownedTrie = CreateTrie();
    
    wb_witchDamage      = CreateConVar("wb_witchdamage", "30", "Set the perm health loss per witch incap.", FCVAR_NOTIFY, true, 0.0);
    wb_bufferThreshold  = CreateConVar("wb_bufferthreshold", "0", "Set a temp health buffer for when players are revived after a witch incap that they would have survived.", FCVAR_NOTIFY, true, 0.0);
    wb_announceMode     = CreateConVar("wb_announcemode", "1", "'0' = Disabled, '1' = Announce when a player will survive a witch incap, '2' = Announce when a player will not survive a witch incap, '3' = Announce both", FCVAR_NOTIFY, true, 0.0, true, 3.0);
}

public Action:Event_PlayerIncapacitatedStart(Handle:event, const String:name[], bool:dontBroadcast) 
{
    new attackerentid = GetEventInt(event, "attackerentid");
    new attacker = EntIndexToEntRef(attackerentid);
    
    //Do witch damage before they get revived
    if (IsWitch(attacker)) {
        new userid = GetEventInt(event, "userid");
        decl String:str_userid[16];
        IntToString(userid, str_userid, sizeof(str_userid));
        new client = GetClientOfUserId(userid);
        new announcemode     = GetConVarInt(wb_announceMode);
        decl String:clientname[32]
        GetClientName(client, clientname, sizeof(clientname));
        
        new witchdamage = GetConVarInt(wb_witchDamage);
        new health = GetClientHealth(client);
        new temphealth = GetCurrentTempHealth(client);
        
        PrintToChatAll("witchdamage: %i", witchdamage);
        PrintToChatAll("health: %i", health);
        PrintToChatAll("temphealth: %i", temphealth);
        
        //If player can survive the witch damage with how much health they have
        if ((health + temphealth) > witchdamage) {
            //Remove perm health first
            if (health > witchdamage) { //Enough perm health to survive the damage
                health = health - witchdamage;
            } else { //Not enough perm health to survive
                if (temphealth > witchdamage) { //Enough temp health to survive the damage
                    temphealth = temphealth - witchdamage;
                } else { //Not enough in one, but enough in both to survive the damage
                    temphealth = temphealth - (witchdamage - (health - 1));
                }
                health = 1
            }
            
            if (announcemode == 1 || announcemode == 3) {
                PrintToChatAll("%s has survived the witch incap and has not lost an incap.", clientname);
            }
        } else {
            temphealth = 0;
            health = 0;
            
            if (announcemode == 2 || announcemode == 3) {
                PrintToChatAll("%s has not survived the witch incap and has lost an incap.", clientname);
            }
        }
        
        new values[4];
        values[0] = health;
        values[1] = temphealth;
        
        //Set the new temphealth of the player here because temp health carries across to downed health
        SetEntPropFloat(client, Prop_Send, "m_healthBuffer", float(temphealth));
        
        SetTrieArray(PlayersDownedTrie, str_userid, values, 4);
    }
}

public Action:Event_ReviveBegin(Handle:event, const String:name[], bool:dontBroadcast) 
{
    new subject = GetEventInt(event, "subject");
    decl String:str_subject[16];
    IntToString(subject, str_subject, sizeof(str_subject));
    new values[4];
    
    if (GetTrieArray(PlayersDownedTrie, str_subject, values, 4)) {
        new client = GetClientOfUserId(subject);
        new health = GetClientHealth(client);
        
        values[2] = health;
        values[3] = GetCurrentTempHealth(client);
        SetTrieArray(PlayersDownedTrie, str_subject, values, 4);
    }
}

public Action:Event_ReviveSuccess(Handle:event, const String:name[], bool:dontBroadcast) 
{
    new subject = GetEventInt(event, "subject");
    decl String:str_subject[16]
    IntToString(subject, str_subject, sizeof(str_subject));
    new values[4];
    new client = GetClientOfUserId(subject);
    
    if (GetTrieArray(PlayersDownedTrie, str_subject, values, 4)) {
        new down_health     = values[0]; //health
        new down_temphealth = values[1]; //buffer
        new rev_health      = values[2]; //revivehp
        new rev_temphealth  = values[3]; //Pills temp health the player had when they were revived (this is only really needed when the rev_health is 1 and the damage 
        new new_health;
        new new_temphealth;
        new bufferthreshold = GetConVarInt(wb_bufferThreshold);
        new bleedout;
        
        PrintToChatAll("down_health: %i", down_health);
        PrintToChatAll("down_temphealth: %i", down_temphealth);
        
        //Witch damage already taken off of the down_health and down_temphealth values
        if (down_health > 0) {//player did survive the damage from the witch, we must now remove health lost from downed bleedout.
            //calculate bleedout based on damaged health values
            bleedout = RoundToFloor(float(down_health + down_temphealth) - (float(down_health + down_temphealth) * ((rev_health + rev_temphealth) / (300.0 + down_temphealth))));
            
            //The bleedout from being pseudo witch downed will remove temp health first
            if (rev_temphealth > bleedout) { //Enough temp health to absorb total bleedout damage
                new_temphealth = rev_temphealth - bleedout;
                new_health = down_health;
            } else { //Not enough temp health, remove some perm health
                new_temphealth = 0;
                new_health = down_health - (bleedout - rev_temphealth);
            }
            
            //wb_bufferthreshold check
            if ((new_health + new_temphealth) < bufferthreshold) {
                new_temphealth = bufferthreshold - new_health;
            }
            
            new revivecount = GetEntProp(client, Prop_Send, "m_currentReviveCount");
            
            SetEntProp(client, Prop_Send, "m_currentReviveCount", revivecount - 1);
            SetEntProp(client, Prop_Send, "m_iHealth", new_health);
            SetEntPropFloat(client, Prop_Send, "m_healthBuffer", float(new_temphealth));
            
            if (revivecount == 2) {
                SetEntProp(client, Prop_Send, "m_bIsOnThirdStrike", 0);
                SetEntProp(client, Prop_Send, "m_isGoingToDie", 0);
                //Need to find out how to stop the sound effect
            }
        }
        
        RemoveFromTrie(PlayersDownedTrie, str_subject);
    }
}

public Action:Event_PlayerDeath(Handle:event, const String:name[], bool:dontBroadcast) 
{
    new victim = GetEventInt(event, "userid");
    decl String:str_victim[16]
    IntToString(victim, str_victim, sizeof(str_victim));
    new values[4];

    if (GetTrieArray(PlayersDownedTrie, str_victim, values, 4)) {
        RemoveFromTrie(PlayersDownedTrie, str_victim);
    }
}

//Called when a Player replaces a Bot
public Action:Event_BotPlayerReplace(Handle:event, const String:name[], bool:dontBroadcast) 
{
    new player = GetEventInt(event, "player");
    decl String:str_player[16];
    IntToString(player, str_player, sizeof(str_player));
    
    new bot = GetEventInt(event, "bot");
    decl String:str_bot[16];
    IntToString(bot, str_bot, sizeof(str_bot));
    
    new values[4];
    
    if (GetTrieArray(PlayersDownedTrie, str_bot, values, 4)) {
        RemoveFromTrie(PlayersDownedTrie, str_bot);
        SetTrieArray(PlayersDownedTrie, str_player, values, 4)
    }
}

//Called when a Bot replaces a Player
public Action:Event_PlayerBotReplace(Handle:event, const String:name[], bool:dontBroadcast) 
{
    new player = GetEventInt(event, "player");
    decl String:str_player[16];
    IntToString(player, str_player, sizeof(str_player));
    
    new bot = GetEventInt(event, "bot");
    decl String:str_bot[16];
    IntToString(bot, str_bot, sizeof(str_bot));
    new values[4];
    
    if (GetTrieArray(PlayersDownedTrie, str_player, values, 4)) {
        RemoveFromTrie(PlayersDownedTrie, str_player);
        SetTrieArray(PlayersDownedTrie, str_bot, values, 4)
    }
}

//General Purpose Generic Stock Functions Below
stock bool:IsWitch(entity)
{
    if (!IsValidEntity(entity)) {
        return false;
    }
    
    decl String:classname[24];
    GetEdictClassname(entity, classname, sizeof(classname));
    
    if (StrContains(classname, "witch", false) == -1) {
    return false;
    } else {
        return true;
    }
}

stock GetCurrentTempHealth(client)
{
    new Float:buffer = GetEntPropFloat(client, Prop_Send, "m_healthBuffer");
    new Float:temphealth;
    
    if (buffer <= 0.0) {
        temphealth = 0.0;
    } else {
        new Float:difference = GetGameTime() - GetEntPropFloat(client, Prop_Send, "m_healthBufferTime");
        new Float:decay = GetConVarFloat(FindConVar("pain_pills_decay_rate"));
        new Float:constant = 1.0/decay;
        
        temphealth = buffer - (difference / constant);
        
        if (temphealth < 0.0) {
            temphealth = 0.0;
        }
    }
    
    return RoundToFloor(temphealth);
}
