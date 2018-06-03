/*
    Credits: F@nt0M (dev-cs.ru/members/16/) for assistance in implementations.
*/

#include <amxmodx>
#tryinclude <reapi>

#if !defined _reapi_included
    #include <VtcApi>
#endif

#define BLOCK_SPAM_CMD                           // Блокировать частое нажатие на кнопку войса

const TIME_CHECK                = 15;            // Через сколько секунд непрерывного флуда будет блокировка голосового чата
const TIME_BLOCK                = 10;            // На сколько секунд будет заблокирован голосовой чат игроку
const Float:TIME_CHECK_MUTED_PL = 30.0;          // Интервал между проверками заблокированных игроков (указывается в секундах)

#if defined BLOCK_SPAM_CMD
    const MIN_CMD_DELAY = 2;                     // Минимальная задержка между использованием голосового чата (указывается в секундах)
#endif

const CHECK_MUTED_PL_TASKID = 200;

enum _:USER_DATA {
    START_SPEAK,
    LAST_SPEAK,
    BAN_TIME,
    bool:MUTED
};

new g_PlayerInfo[MAX_PLAYERS + 1][USER_DATA];

#define vtc_get_user_block(%0)    g_PlayerInfo[%0][MUTED]

public plugin_init()
{
    register_plugin("Voice Flood Blocker", "1.0", "d3m37r4");

#if defined _reapi_included
    if(!has_vtc())
        set_fail_state("Requires meta plugin VoiceTranscoder!");
#endif

    set_task(TIME_CHECK_MUTED_PL, "task_CheckMutedPlayers", CHECK_MUTED_PL_TASKID, .flags = "b");
}

public client_putinserver(iIndex)
{
    arrayset(g_PlayerInfo[iIndex], 0, USER_DATA);
    remove_task(iIndex);
}

public VTC_OnClientStartSpeak(const iIndex)
{
    new iSysTime = get_systime(0);

#if defined BLOCK_SPAM_CMD
    if((iSysTime - g_PlayerInfo[iIndex][LAST_SPEAK]) < MIN_CMD_DELAY)
    {
        client_print(iIndex, print_center, "Слишком часто используете голосовой чат! Подождите %d сек.", MIN_CMD_DELAY);
        return;
    }
#endif

    if(vtc_get_user_block(iIndex))
    {    
        new iSecLeft = g_PlayerInfo[iIndex][BAN_TIME] - iSysTime;

        if(iSecLeft <= 0)
        {
            client_print(iIndex, print_center, "Время блокировки истекло. Пожалуйста, дождитесь обновления информации."); 
        } else {
            client_print(iIndex, print_center, "Голосовой чат будет доступен через %d сек.", iSecLeft);    
        }
    } else {
        g_PlayerInfo[iIndex][START_SPEAK] = iSysTime;
        
        if(!task_exists(iIndex))
        {
            new PlData[1];

            PlData[0] = get_user_userid(iIndex);
            set_task(float(TIME_CHECK), "task_BlockPlayerVoice", iIndex, PlData, sizeof PlData);
        }
    }
}

public VTC_OnClientStopSpeak(const iIndex)
{
    new iSysTime = get_systime(0);

    g_PlayerInfo[iIndex][LAST_SPEAK] = iSysTime;

    if((iSysTime - g_PlayerInfo[iIndex][START_SPEAK]) < TIME_CHECK)
        remove_task(iIndex);
}

public task_BlockPlayerVoice(PlData[1], iIndex)
{
    if(!is_user_connected(iIndex) || PlData[0] != get_user_userid(iIndex))
        return;

    if(vtc_get_user_block(iIndex) || !VTC_IsClientSpeaking(iIndex))
        return;

    vtc_set_user_mute(iIndex, TIME_BLOCK);
    remove_task(iIndex);
}

public task_CheckMutedPlayers()
{
    new aPl[MAX_PLAYERS], iPlNum;

    get_players(aPl, iPlNum); 

    for(new i, iSysTime = get_systime(0); i < iPlNum; ++i)
    {
        new iIndex = aPl[i];

        if(!is_user_connected(iIndex) || !vtc_get_user_block(iIndex))
            continue;

        if(g_PlayerInfo[iIndex][BAN_TIME] - iSysTime > 0)
            continue;

        vtc_set_user_unmute(iIndex);
    }
}

vtc_set_user_mute(const pIndex, const iBlockTime)
{
    new szName[MAX_NAME_LENGTH];

    get_user_name(pIndex, szName, charsmax(szName));
    client_print(pIndex, print_center, "Голосовой чат был заблокирован из-за флуда на %d сек.", iBlockTime);
    log_amx("Игроку %s был заблокирован голосовой чат на %d сек.", szName, iBlockTime);

    g_PlayerInfo[pIndex][BAN_TIME] = get_systime(0) + iBlockTime;
    g_PlayerInfo[pIndex][MUTED] = true;

    VTC_MuteClient(pIndex);
    client_cmd(pIndex, "-voicerecord");
}

vtc_set_user_unmute(const pIndex)
{
    client_print(pIndex, print_center, "Время блокировки истекло. Голосовой чат был разблокирован!");

    g_PlayerInfo[pIndex][BAN_TIME] = 0;
    g_PlayerInfo[pIndex][MUTED] = false;

    VTC_UnmuteClient(pIndex);
}
