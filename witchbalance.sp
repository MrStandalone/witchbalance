#include <sourcemod>

public Plugin:myinfo = 
{
    name = "Cookie's Witch Balance",
    author = "High Cookie & Standalone(aka Manu)",
    description = "A Witch balance plugin, still needs a little bit of work.",
    version = "1.0.2",
    url = ""
};

new Handle:PlayersDownedTrie = INVALID_HANDLE;
new Handle:wb_witchDamage = INVALID_HANDLE;
new Handle:wb_bufferThreshold = INVALID_HANDLE;

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
    
    wb_witchDamage = CreateConVar("wb_witchdamage", "30", "Set the perm health loss per witch incap.");
    wb_bufferThreshold = CreateConVar("wb_bufferthreshold", "0", "Set a temp health buffer for when players are revived after a witch incap that they would have survived.");
}

public Action:Event_PlayerIncapacitatedStart(Handle:event, const String:name[], bool:dontBroadcast) 
{
    new attackerentid = GetEventInt(event, "attackerentid");
    new attacker = EntIndexToEntRef(attackerentid);
    
    if (IsWitch(attacker)) {
        new userid = GetEventInt(event, "userid");
        decl String:str_userid[16];
        IntToString(userid, str_userid, sizeof(str_userid));
        new client = GetClientOfUserId(userid);
        
        new health = GetClientHealth(client);
        new currenthealthbuffer = GetCurrentTempHealth(client);
        
        new values[4];
        values[0] = health;
        values[1] = currenthealthbuffer;
        
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
        new witchdamage     = GetConVarInt(wb_witchDamage);
        new bufferthreshold = GetConVarInt(wb_bufferThreshold);
        new bleedout;
        
        //If player cannot survive an amount of damage = witchdamage then do normal witch incap.
        if ((down_health + down_temphealth) > witchdamage) {
            if (down_health < witchdamage) {
                new_temphealth = RoundToFloor(float(down_temphealth - (witchdamage - down_health)) * ((rev_health + rev_temphealth) / (300.0 + down_temphealth)));
                new_health = 1;
            } else {
                //I've got float() around most shit here because weird shit was happening without it, not sure how int/float operations work in pawn.
                bleedout = RoundToFloor(float(down_health + down_temphealth) - (float(down_health + down_temphealth) * ((rev_health + rev_temphealth) / (300.0 + down_temphealth))));
                
                if (bleedout > down_temphealth) {
                    new_health = down_health - (bleedout - down_temphealth) - witchdamage;
                    new_temphealth = 0;
                } else {
                    new_health = down_health - witchdamage;
                    new_temphealth = down_temphealth - bleedout;
                }
            }
            
            if ((new_health + new_temphealth) < bufferthreshold) {
                new_temphealth = bufferthreshold - new_health;
            }
            
            SetEntProp(client, Prop_Send, "m_currentReviveCount", GetEntProp(client, Prop_Send, "m_currentReviveCount") - 1);
            //Probably need to change some other incap variables here as we still go black and white screen, however the next incap does not kill player.
            SetEntProp(client, Prop_Send, "m_iHealth", new_health);
            SetEntPropFloat(client, Prop_Send, "m_healthBuffer", float(new_temphealth));
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
