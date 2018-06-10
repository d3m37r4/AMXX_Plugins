#include <amxmodx>
 
new const MAP_NAME[] = "de_dust2_2x2";        // Карта, на которую будет изменена текущая, если сервер пустой

new g_MapName[MAX_NAME_LENGTH];
new g_pcvRoundTime;

public plugin_cfg()    
{
    get_mapname(g_MapName, charsmax(g_MapName));

    if(equali(g_MapName, MAP_NAME))
    {                
        server_print("[No Players Map] Plugin is stopped! Current map %s.", g_MapName);
        pause("d");
    }
}

public plugin_init()      
{                                         
    register_plugin("No Players Map", "1.3", "d3m37r4");
    
    g_pcvRoundTime = get_cvar_pointer("mp_roundtime");

    if(0.0 < get_pcvar_float(g_pcvRoundTime) < 120.0)
    {
        register_event("HLTV", "Event_CheckPlayers", "a", "1=0", "2=0");
    } else {
        set_task(60.0, "Event_CheckPlayers", .flags = "b");
    }
}                                    

public Event_CheckPlayers()
{
    if(get_playersnum() == 0)
    {
        log_amx("No players on server. Current map is changed to ^"%s^".", MAP_NAME);
        engine_changelevel(MAP_NAME);
    }
}
