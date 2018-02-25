#include <amxmodx>
#include <reapi>

#define BLOCK_MSG                                  // Блокировать сообщения о рестарте и о начале игры

const WARMUP_TIME = 45;                            // Кол-во времени в секундах, через которое произойдёт рестарт (только целые числа; по умолчанию 20)
const TASK_INDEX   = 100;
#if defined BLOCK_MSG
    const g_TextMsg = 77;
#endif

enum pos_e {Float:X, Float:Y};

new const DHUD_POS[pos_e] = {-1.0, 0.16};           // Координаты положения сообщения

new g_iTimeCount;
new g_pcvRoundRespawnTime, g_iRoundRespawnTime;
new g_HudSyncObj;

public plugin_init()
{
    register_plugin("Warmup Time", "1.0", "d3m37r4");

    RegisterHookChain(RG_RoundEnd, "EventHook_RoundEnd_Post", true);

#if defined BLOCK_MSG
    register_message(g_TextMsg, "MessageTextMsg");
#endif

    g_pcvRoundRespawnTime = get_cvar_pointer("mp_roundrespawn_time");
    g_iRoundRespawnTime = get_pcvar_num(g_pcvRoundRespawnTime);

    g_HudSyncObj = CreateHudSyncObj();
}

public EventHook_RoundEnd_Post(WinStatus:status, ScenarioEventEndRound:event, Float:tmDelay)
{  
    switch(event)
    {
        case ROUND_GAME_COMMENCE:
        {
            set_task(1.0, "task_TimeCount", TASK_INDEX, .flags = "a", .repeat = WARMUP_TIME);
            set_pcvar_num(g_pcvRoundRespawnTime, 0);
        }
        case ROUND_GAME_RESTART:
        {
            set_hudmessage(0, 255, 0, DHUD_POS[X], DHUD_POS[Y], 0, 0.0, 5.0, 0.0, 0.0, -1);
            ShowSyncHudMsg(0, g_HudSyncObj, "Приготовьтесь к бою!^nИгра началась!");
            pause("d"); 
        }
    }
} 

#if defined BLOCK_MSG
public MessageTextMsg()
{
    new szMsg[24];

    get_msg_arg_string(2, szMsg, charsmax(szMsg));

    if(equal(szMsg, "#Game_Commencing") || equal(szMsg, "#Game_will_restart_in"))
        return PLUGIN_HANDLED;

    return PLUGIN_CONTINUE;
}
#endif

public task_TimeCount()
{
    set_hudmessage(255, 0, 0, DHUD_POS[X], DHUD_POS[Y], 0, 0.0, 1.0, 0.0, 0.0, -1);
    ShowSyncHudMsg(0, g_HudSyncObj, "Рестарт через %d сек...", WARMUP_TIME - g_iTimeCount++);

    if(g_iTimeCount == WARMUP_TIME)
    {
        set_pcvar_num(g_pcvRoundRespawnTime, g_iRoundRespawnTime);
        server_cmd("sv_restart 3");
    }
}
