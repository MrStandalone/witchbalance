#include <sourcemod>

public Plugin:myinfo = 
{
    name = "Cookie's Witch Balance",
    author = "High Cookie & Standalone(aka Manu)",
    description = "A Witch balance plugin, still needs a little bit of work.",
    version = "1.1",
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
    //Removed the 
    
    HookEvent("revive_success", Event_ReviveSuccess);
    //Need this so we can store the amount of temp health the player was revived at.
    HookEvent("revive_begin", Event_ReviveBegin);
    
    //Storing arrays of player information at keys of the players user id as a string.
    //There's probably a better way to get this information rather than storing it on the hook events, but I'm not aware of them just yet.
    //values[0] = Perm health the player went down at
    //values[1] = Temp buffer health the player went down with
    //values[2] = The temp health the player was revived with
    PlayersDownedTrie = CreateTrie();
    
    wb_witchDamage = CreateConVar("wb_witchdamage", "30", "Set the perm health loss per witch incap.");
    wb_bufferThreshold = CreateConVar("wb_bufferthreshold", "0", "Set a temp health buffer for when players are revived after a witch incap that they would have survived.");
}

public Action:Event_PlayerIncapacitatedStart(Handle:event, const String:name[], bool:dontBroadcast) 
{
    new attacker = EntIndexToEntRef(GetEventInt(event, "attackerentid"));
    
    if (IsWitch(attacker)) {
        new userid = GetEventInt(event, "userid");
        decl String:str_userid[16];
        IntToString(userid, str_userid, sizeof(str_userid));
        new client = GetClientOfUserId(userid);
        
        new health = GetClientHealth(client);
        new currenthealthbuffer = GetCurrentBufferHealth(client);
        
        new values[3];
        values[0] = health;
        values[1] = currenthealthbuffer;
        
        SetTrieArray(PlayersDownedTrie, str_userid, values, 3);
    }
}

public Action:Event_ReviveBegin(Handle:event, const String:name[], bool:dontBroadcast) 
{
    new subject = GetEventInt(event, "subject");
    decl String:str_subject[16];
    IntToString(subject, str_subject, sizeof(str_subject));
    new values[3];
    
    if (GetTrieArray(PlayersDownedTrie, str_subject, values, 3)) {
        new client = GetClientOfUserId(subject);
        new health = GetClientHealth(client);
        
        values[2] = health;
        SetTrieArray(PlayersDownedTrie, str_subject, values, 3);
    }
}

public Action:Event_ReviveSuccess(Handle:event, const String:name[], bool:dontBroadcast) 
{
    new subject = GetEventInt(event, "subject");
    decl String:str_subject[16]
    IntToString(subject, str_subject, sizeof(str_subject));
    new values[3];
    new client = GetClientOfUserId(subject);

    if (GetTrieArray(PlayersDownedTrie, str_subject, values, 3)) {
        new health = values[0];
        new buffer = values[1];
        new revivehp = values[2];
        new witchdamage = GetConVarInt(wb_witchDamage);
        new bufferthreshold = GetConVarInt(wb_bufferThreshold);
        new currentbuffer = GetCurrentBufferHealth(client, buffer);
        new bleedout;
        
        if ((health + buffer) > witchdamage) {
            if (health < witchdamage) {
                buffer = RoundToFloor(float(buffer - (witchdamage - health)) * ((revivehp + currentbuffer) / (300.0 + buffer)));
                health = 1;
            } else {
                health = health - witchdamage;
                //I've got float() around most shit here because weird shit was happening without it, not sure how int/float operations work in pawn.
                bleedout = RoundToFloor(float(health+buffer) - (float(health+buffer) * (revivehp / (300.0 + buffer))));
                
                if (bleedout > buffer) {
                    health = health - (bleedout - buffer);
                    buffer = 0;
                } else {
                    buffer = buffer - bleedout;
                }
            }
            
            if ((health + buffer) < bufferthreshold) {
                buffer = bufferthreshold - health;
            }
            SetEntProp(client, Prop_Send, "m_currentReviveCount", GetEntProp(client, Prop_Send, "m_currentReviveCount") - 1);
            SetEntProp(client, Prop_Send, "m_iHealth", health);
            SetEntPropFloat(client, Prop_Send, "m_healthBuffer", float(buffer));
        }
        RemoveFromTrie(PlayersDownedTrie, str_subject);
    }
}

public Action:Event_PlayerDeath(Handle:event, const String:name[], bool:dontBroadcast) 
{
    new victim = GetEventInt(event, "userid");
    decl String:str_victim[16]
    IntToString(victim, str_victim, sizeof(str_victim));
    new values[3];
    new client = GetClientOfUserId(victim);

    if ((GetClientTeam(client) == 2) && GetTrieArray(PlayersDownedTrie, str_victim, values, 3)) {
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
    
    new values[3];
    
    if (GetTrieArray(PlayersDownedTrie, str_bot, values, 3)) {
        RemoveFromTrie(PlayersDownedTrie, str_bot);
        SetTrieArray(PlayersDownedTrie, str_player, values, 3)
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
    new values[3];
    
    if (GetTrieArray(PlayersDownedTrie, str_player, values, 3)) {
        RemoveFromTrie(PlayersDownedTrie, str_player);
        SetTrieArray(PlayersDownedTrie, str_bot, values, 3)
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

stock GetCurrentBufferHealth(client, inbuffer = -1)
{
    new Float:buffer
    if (inbuffer > 0) {
        buffer = float(inbuffer);
    } else {
        buffer = GetEntPropFloat(client, Prop_Send, "m_healthBuffer");
    }
    
    new Float:TempHealth;
    
    if (buffer <= 0.0) {
        TempHealth = 0.0;
    } else {
        new Float:difference = GetGameTime() - GetEntPropFloat(client, Prop_Send, "m_healthBufferTime");
        new Float:decay = GetConVarFloat(FindConVar("pain_pills_decay_rate"));
        new Float:constant = 1.0/decay;
        
        TempHealth = buffer - (difference / constant);
        
        if (TempHealth < 0.0) {
            TempHealth = 0.0;
        }
    }
    
    return RoundToFloor(TempHealth);
}