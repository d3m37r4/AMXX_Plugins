/*
    CSDM Hud HP/AP v1.2
    Спасибо Vaqtincha за многочисленные подсказки и предоставленное API для плагина.

    *** НАСТРОЙКИ ПЛАГИНА ***
        Цвет HUD жизней и брони.
        Задается как "R G B".
        hud_hp_color = "255 233 0" - значение по умолчанию.
    
        Позиция HUD жизней и брони.
        Задается как "X Y".
        hud_hp_position = "0.02 0.96" - значение по умолчанию.

        Тип HUD сообщения:
        0 - HUD,
        1 - DHUD.
        hud_hp_type = 0 - значение по умолчанию.

        ВАЖНО: Представленные выше настройки учитываются, если квар "hide_hud_flags", в конфиге /csdm/config.ini, имеет флаг "h".
*/

#include <amxmodx>
#include <csdm>

#if AMXX_VERSION_NUM < 183
    #include <dhudmessage>
    #define client_disconnected		client_disconnect
#endif

new const PLUGIN_NAME[]         = "CSDM Hud HP/AP";
new const PLUGIN_VERSION[]      = "1.2";
new const PLUGIN_AUTHOR[]       = "d3m37r4";

#define FIX_MESSAGE_OVERLAY     // Исправление наложения DHUD сообщений друг на друга.

#define PlayerTask(%1)          (%1 + PLAYER_HUD_TASK_ID)
#define GetPlayerByTaskID(%1)   (%1 - PLAYER_HUD_TASK_ID)

const PLAYER_HUD_TASK_ID        = 433794;
const Float:MAX_HOLDTIME        = 20.0;

enum Color { R, G, B };
enum Pos { Float:X, Float:Y };
enum HudTypes { HUD, DHUD };

new g_iHudColor[Color]          = { 255, 0, 0 };
new Float:g_fHudPosition[Pos]   = { 0.02, 0.96 };
new HudTypes:g_iHudType;
new g_iSyncPlayerHud;

new szCvarValue[MAX_VALUE_LEN];
new g_iHealth[MAX_CLIENTS + 1], g_iArmor[MAX_CLIENTS + 1];

public plugin_init()
{
    register_plugin(PLUGIN_NAME, PLUGIN_VERSION, PLUGIN_AUTHOR);

    CSDM_GetConfigKeyValue("hide_hud_flags", szCvarValue, charsmax(szCvarValue));

    if(!ContainFlag(szCvarValue, "h")) 
    {
        server_print("[CSDM] Plugin ^"%s^" is stopped working! Flag ^"h^" was not found in cvar ^"hide_hud_flags^"!", PLUGIN_NAME);
        pause("ad");
        return;
    }
    
    register_event("Health", "Event_Health", "be");
    register_event("Battery", "Event_Battery", "be");

    g_iSyncPlayerHud = CreateHudSyncObj();
    
    new szRed[4], szGreen[4], szBlue[4], szX[8], szY[8];

    CSDM_GetConfigKeyValue("hud_hp_color", szCvarValue, charsmax(szCvarValue));
        
    if(parse(szCvarValue, szRed, charsmax(szRed), szGreen, charsmax(szGreen), szBlue, charsmax(szBlue)) == 3)
    {
        g_iHudColor[R] = str_to_num(szRed);
        g_iHudColor[G] = str_to_num(szGreen);
        g_iHudColor[B] = str_to_num(szBlue);
    }

    CSDM_GetConfigKeyValue("hud_hp_position", szCvarValue, charsmax(szCvarValue));

    if(parse(szCvarValue, szX, charsmax(szX), szY, charsmax(szY)) == 2)
    {
        g_fHudPosition[X] = str_to_float(szX);
        g_fHudPosition[Y] = str_to_float(szY);
    }

    CSDM_GetConfigKeyValue("hud_hp_type", szCvarValue, charsmax(szCvarValue));

    g_iHudType = HudTypes:clamp(str_to_num(szCvarValue), _:HUD, _:DHUD);

    server_print("[CSDM] Plugin ^"%s^" successfully loaded. Flag ^"h^" found.", PLUGIN_NAME);
}

public CSDM_PlayerSpawned(const pPlayer, const bool:bIsBot, const iNumSpawns)
{
    if(!bIsBot) 
    {
        FixHealthMsgSend(pPlayer);
        set_task(MAX_HOLDTIME, "taskPlayerHud", PlayerTask(pPlayer), .flags = "b");
    }
}

public CSDM_PlayerKilled(const pVictim, const pKiller, const HitBoxGroup:iLastHitGroup)
{
    if(task_exists(PlayerTask(pVictim))) 
    {
        remove_task(PlayerTask(pVictim));
        if(g_iHudType == HUD)
        {
            ClearSyncHud(pVictim, g_iSyncPlayerHud);
        }
    }
}

public client_disconnected(pPlayer)
{
    remove_task(PlayerTask(pPlayer));
}

public client_putinserver(pPlayer)
{
    remove_task(PlayerTask(pPlayer));
}

public taskPlayerHud(iTaskId)
{
    UpdateHUD(GetPlayerByTaskID(iTaskId));
}

public Event_Health(pPlayer) 
{
    g_iHealth[pPlayer] = read_data(1);
    UpdateHUD(pPlayer);
}

public Event_Battery(pPlayer) 
{
    g_iArmor[pPlayer] = read_data(1);
    UpdateHUD(pPlayer);
}

UpdateHUD(pPlayer)
{
    switch(g_iHudType)
    {
        case HUD:
        {
            set_hudmessage(
                g_iHudColor[R], g_iHudColor[G], g_iHudColor[B],
                g_fHudPosition[X], g_fHudPosition[Y],
                .holdtime = MAX_HOLDTIME, .channel = next_hudchannel(pPlayer)
            );
            ShowSyncHudMsg(pPlayer, g_iSyncPlayerHud, "[%i HP|%i AP]", g_iHealth[pPlayer], g_iArmor[pPlayer]);
        }
        case DHUD:
        {
        #if defined FIX_MESSAGE_OVERLAY
            ClearDHUDMessages(pPlayer);
        #endif
            set_dhudmessage(
                g_iHudColor[R], g_iHudColor[G], g_iHudColor[B],
                g_fHudPosition[X], g_fHudPosition[Y], 
                .holdtime = MAX_HOLDTIME
            );
            show_dhudmessage(pPlayer, "[%i HP|%i AP]", g_iHealth[pPlayer], g_iArmor[pPlayer]);
        }
    }
}

FixHealthMsgSend(pPlayer)
{
    static gmsgHealth;
    if(gmsgHealth > 0 || (gmsgHealth = get_user_msgid("Health")))
    {
        emessage_begin(MSG_ONE, gmsgHealth, .player = pPlayer);
        ewrite_byte(get_user_health(pPlayer));
        emessage_end();
    }
}

// Thx PRoSToTeM@.
// Link: http://amx-x.ru/viewtopic.php?f=9&t=4578&start=60
#if defined FIX_MESSAGE_OVERLAY
ClearDHUDMessages(pPlayer, iClear = 8)
{
	for(new iDHUD; iDHUD < iClear; iDHUD++)
	{
		show_dhudmessage(pPlayer, "");
	} 
}
#endif