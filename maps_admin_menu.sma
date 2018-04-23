/*
    Powered by Maps Menu
    Original plugin - Maps Menu v 1.4.1 (my-amxx.ru/threads/1-4-1-maps-menu.63)
    Author - neygomon (my-amxx.ru/members/neygomon.1)
*/

#include <amxmodx>

#define CMD_BLOCK_ON_START_VOTE                        // Блокировать различные меню во время голосования (смена команды, радио команды, покупка оружия и т.д.)
#define SHOW_MENU_WITH_PERCENTS                        // Показывать результаты голосования с процентами голосов

const ACCESS_FLAG           = ADMIN_BAN;               // Флаг для доступа в меню смены карт

const MAX_NOMINATE_MAP      = 4;                       // Максимальное количество карт в голосовании
const VOTE_TIME             = 10;                      // Время голосования (в секундах)
const TIME_UNTIL_CHANGE	    = 4;                       // Время до смены карты после голосования (через сколько пройдет intermission и последует смена карты)

const TASK_INDEX	    = 512452;

enum { 
    STATE_NONE,
    STATE_SELECT,
    STATE_CHANGELEVEL,
    STATE_START_VOTE,
    STATE_VOTING
};

enum _:MENUS {
    CHANGEMAP, 
    VOTEMAP
};

enum _:DATA {
    MENU_TYPE,
    MENU_POS,
    MENU_INDEX,
    MENU_INSIDER,
    NOMINATED_MAPS_NUM,
    NO_VOTE_NUM,
    NOMINATED_MAPS[MAX_NOMINATE_MAP + 1],
    VOTES_MAPS[MAX_NOMINATE_MAP + 1],
    NEW_MAP[32]
};

enum _:COLOR {R, G, B};
enum _:POS {Float:X, Float:Y};

new const g_FileName[]            = "admin_maps.ini";                    // Файл, в котором находятся карты для меню
new const g_Colors[COLOR]        = {50, 255, 50};                    // R G B цвет для HUD отсчета
new const Float:g_HudPos[POS]    = {-1.0, 0.6};                        // X и Y координаты в HUD отсчета

#if defined CMD_BLOCK_ON_START_VOTE 
    new const g_BlockCommands[][] = {
        "buy",
        "radio1",
        "radio2",
        "radio3",
        "jointeam",
        "chooseteam",
        "joinclass"
    };
#endif
new const g_Sounds[][] = {
    "/sound/fvox/one.wav",
    "/sound/fvox/two.wav",
    "/sound/fvox/three.wav"
};

new g_MapsMenu[DATA];
new Array:g_aMaps;              
new g_iMaps, g_iState;
new g_CurrentMap[32];

new g_pFreezeTime, g_iOldFreezeTime;

#if defined SHOW_MENU_WITH_PERCENTS
    new g_iVotes;
    new g_iTimeOst;
    new bool:g_bIsVoted[MAX_PLAYERS + 1];
    new g_VoteResMenu[512];
#endif

new bool:g_StartVote;

public plugin_cfg()
{
    new szFileDir[128];
    
    g_aMaps = ArrayCreate(32);
    g_pFreezeTime = get_cvar_pointer("mp_freezetime");

    get_mapname(g_CurrentMap, charsmax(g_CurrentMap));
    get_localinfo("amxx_configsdir", szFileDir, charsmax(szFileDir));

    formatex(szFileDir, charsmax(szFileDir), "%s/%s", szFileDir, g_FileName);

    if(file_exists(szFileDir))
    {
        new iFile = fopen(szFileDir, "rt");
    
        if(iFile)
        {
            new szBuffer[32], szMapName[32];

            while(!feof(iFile))
            {
                fgets(iFile, szBuffer, charsmax(szBuffer));
                remove_quotes(szBuffer);
                trim(szBuffer);

                if(!(szBuffer[0]) || szBuffer[0] == ';' || szBuffer[0] == '#')
                    continue;

                if(!parse(szBuffer, szMapName, charsmax(szMapName)) && !is_map_valid(szMapName))
                    continue;

                if(strcmp(g_CurrentMap, szMapName, true) == 0)
                    continue;

                ArrayPushString(g_aMaps, szMapName);
            }

            fclose(iFile);
      
            g_iMaps = ArraySize(g_aMaps);

            if(!g_iMaps)
                set_fail_state("Maps not found!");
        } else {
            set_fail_state("Map file not found!");
        }
    }
}

public plugin_init()
{
    register_plugin("Maps Admin Menu", "1.2", "d3m37r4");

    register_event("HLTV", "event_RestartRound", "a", "1=0", "2=0");

    register_clcmd("amx_mapmenu", "cmd_MapMenu", ACCESS_FLAG);
    register_clcmd("amx_votemapmenu", "cmd_VoteMenu", ACCESS_FLAG);

#if defined CMD_BLOCK_ON_START_VOTE 
    for(new i; i < sizeof g_BlockCommands; i++)
        register_clcmd(g_BlockCommands[i], "clcmd_Block");
#endif

    g_MapsMenu[MENU_INDEX] = register_menuid("Maps Menu");

    register_menucmd(g_MapsMenu[MENU_INDEX], 1023, "MapsMenu_Handler");
    register_menucmd(register_menuid("Vote Map"), (-1^(-1<<(MAX_NOMINATE_MAP+1)))|(1<<9), "VoteMap_Handler");
}

public plugin_natives()
{
    register_library("Maps Admin Menu");
    register_native("adminvote_is_start", "native_adminvote_is_start", 1);
    register_native("adminvote_is_create", "native_adminvote_is_create", 1);
}

public native_adminvote_is_start()
    return g_StartVote;

public native_adminvote_is_create()
    return bool:(g_iState == STATE_START_VOTE);

public plugin_end()
{
    if(g_aMaps)
        ArrayDestroy(g_aMaps);
}

public event_RestartRound()
{
    switch(g_iState)
    {
        case STATE_CHANGELEVEL: set_intermission_msg();
        case STATE_START_VOTE:
        {
            g_StartVote = true;
            set_screen_fade(.fade = 1);
            set_frozen_users(.frozen = true);
            set_task(1.0, "task_ShowTimer", .flags = "a", .repeat = 4);
        }
    }
}

#if defined CMD_BLOCK_ON_START_VOTE 
public clcmd_Block(iIndex)
{
    if(g_StartVote)
        return PLUGIN_HANDLED;

    return PLUGIN_CONTINUE; 
}
#endif

public cmd_MapMenu(iIndex, iFlags)
    return PreOpenMenu(iIndex, iFlags, CHANGEMAP);

public cmd_VoteMenu(iIndex, iFlags)
    return PreOpenMenu(iIndex, iFlags, VOTEMAP);

PreOpenMenu(iIndex, iFlags, iMenu)
{
    if(~get_user_flags(iIndex) & iFlags) 
    {
        console_print(iIndex, "* Недостаточно прав для использования данной команды!");

        return PLUGIN_HANDLED;
    } else {
        if(g_iState == STATE_SELECT)
        {
            new bool:bActive, pl[32], pnum;

            get_players(pl, pnum);

            for(new i, oldmenu, newmenu; i < pnum; i++)
            {
                player_menu_info(pl[i], oldmenu, newmenu);

                if(g_MapsMenu[MENU_INDEX] == oldmenu)
                {
                    bActive = true;
                    break;
                }    
            }

            if(!bActive)
                set_clear_data();
        }

        switch(g_iState)
        {
            case STATE_NONE:
            {
                g_MapsMenu[MENU_POS] = 0;
                g_MapsMenu[MENU_TYPE] = iMenu;
                g_MapsMenu[MENU_INSIDER] = iIndex;
                g_iState = STATE_SELECT;

                BuildMenu(iIndex, g_MapsMenu[MENU_POS]);
            }
            case STATE_SELECT: client_print_color(iIndex, 0, "[Server] Администратор уже выбирает %s!", iMenu == VOTEMAP ? "карты" : "карту");
            case STATE_START_VOTE: client_print_color(iIndex, 0, "[Server] Голосование уже создано и будет запущено после окончания текущего раунда!");
            case STATE_VOTING: client_print_color(iIndex, 0, "[Server] В данный момент идет голосование за смену карты!");
            case STATE_CHANGELEVEL: client_print_color(iIndex, 0, "[Server] Следующая карта определена. Смена произойдет после окончания текущего раунда.");
        }
    }

    return PLUGIN_HANDLED;     
}

BuildMenu(iIndex, pos)
{
    new szMenu[512], iLen;
    new start, end, pages;
    new iKeys = MENU_KEY_0;

    switch(g_MapsMenu[MENU_TYPE])
    {
        case CHANGEMAP:
        {
            start = pos * 8;
            end = start + 8;
            pages = (g_iMaps / 8 + ((g_iMaps % 8) ? 1 : 0));

            iLen = formatex(szMenu, charsmax(szMenu), "\w[\rMaps Menu\w] Выберите карту");
        }
        case VOTEMAP:
        {
            start = pos * 7;
            end = start + 7;
            pages = (g_iMaps / 7 + ((g_iMaps % 7) ? 1 : 0));

            iLen = formatex(szMenu, charsmax(szMenu), "\w[\rVoteMap Menu\w] Выберите карты");
        }
    }

    if(start >= g_iMaps)
        start = g_MapsMenu[MENU_POS] = 0;

    if(end > g_iMaps)
        end = g_iMaps;

    iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\w [\r%d\w/\r%d\w]^n^n", pos + 1, pages);

    if(g_MapsMenu[MENU_TYPE] == VOTEMAP)
        iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "Выбрано карт: \r%d\w из \r%d\w^n^n", g_MapsMenu[NOMINATED_MAPS_NUM], MAX_NOMINATE_MAP);

    for(new i = start, a, szMapName[32]; i < end; i++)
    {
        ArrayGetString(g_aMaps, i, szMapName, charsmax(szMapName));

        switch(g_MapsMenu[MENU_TYPE])
        {
            case CHANGEMAP:
            {
                iKeys |= (1 << a);
                iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r%d. \w%s^n", ++a, szMapName);
            }    
            case VOTEMAP:
            {
                if(is_map_selected(i))
                {
                    iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r# \d%s \w[\r*\w]^n", szMapName);
                } else {
                    iKeys |= (1 << a);
                    iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r%d. \w%s^n", a + 1, szMapName);
                }

                a++;
            }
        }
    }

    if(g_MapsMenu[MENU_TYPE] == VOTEMAP)
    {
        if(g_MapsMenu[NOMINATED_MAPS_NUM])
        {
            iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "^n\r8. \wНачать голосование^n");
            iKeys |= MENU_KEY_8;
        } else {
            iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "^n\r# \dНачать голосование^n");
        }
    }

    if(end != g_iMaps)
    {
        switch(g_MapsMenu[MENU_TYPE])
        {
            case CHANGEMAP: formatex(szMenu[iLen], charsmax(szMenu) - iLen, "^n\r9. \wДалее^n\r0. \w%s", pos ? "Назад" : "Выход");
            case VOTEMAP: formatex(szMenu[iLen], charsmax(szMenu) - iLen, "^n\r9. \wДалее^n\r0. \w%s", pos ? "Назад" : (g_MapsMenu[NOMINATED_MAPS_NUM] > 0) ? "Отмена и выход" : "Выход");
        }

        iKeys |= MENU_KEY_9;
    } else {
        switch(g_MapsMenu[MENU_TYPE])
        {
            case CHANGEMAP: formatex(szMenu[iLen], charsmax(szMenu) - iLen, "^n\r0. \w%s", pos ? "Назад" : "Выход"); 
            case VOTEMAP: formatex(szMenu[iLen], charsmax(szMenu) - iLen, "^n\r0. \w%s", pos ? "Назад" : (g_MapsMenu[NOMINATED_MAPS_NUM] > 0) ? "Отмена и выход" : "Выход"); 
        }
    }

    show_menu(iIndex, iKeys, szMenu, -1, "Maps Menu");  
}

public MapsMenu_Handler(iIndex, iKey)
{
    switch(iKey)
    {
        case 8: BuildMenu(iIndex, ++g_MapsMenu[MENU_POS]);
        case 9:
        {
            if(--g_MapsMenu[MENU_POS] < 0)
            {
                if(g_MapsMenu[MENU_TYPE] == VOTEMAP && g_MapsMenu[NOMINATED_MAPS_NUM] > 0)
                    client_print_color(iIndex, 0, "[Server] Голосование было отменено! Все данные о голосовании удалены!");

                g_MapsMenu[MENU_POS] = 0;
                set_clear_data();
            } else {
                BuildMenu(iIndex, g_MapsMenu[MENU_POS]);
            }
        }
        default:
        {
            new szAdminName[MAX_NAME_LENGTH];

            get_user_name(iIndex, szAdminName, charsmax(szAdminName));

            switch(g_MapsMenu[MENU_TYPE])
            {
                case CHANGEMAP:
                {
                    ArrayGetString(g_aMaps, g_MapsMenu[MENU_POS] * 8 + iKey, g_MapsMenu[NEW_MAP], charsmax(g_MapsMenu[NEW_MAP]));

                    client_print_color(0, 0, "[Server] Установлена следующая карта: ^4%s^1. Смена произойдет в конце раунда.", g_MapsMenu[NEW_MAP]);
                    log_amx("Администратор %s установил следующую карту: %s. Смена произойдет в конце раунда.", szAdminName, g_MapsMenu[NEW_MAP]);

                    g_iState = STATE_CHANGELEVEL;
                }
                case VOTEMAP:
                {
                    if(iKey == 7)
                    {
                        g_iState = STATE_START_VOTE;

                        client_print_color(0, 0, "[Server] Администратор ^4%s^1 создал голосование за смену карты, которое начнется в следующем раунде.", szAdminName);                 
                        log_amx("Администратор %s создал голосование за смену карты, которое начнется в следующем раунде.", szAdminName);
                    } else {
                        if(g_MapsMenu[NOMINATED_MAPS_NUM] == MAX_NOMINATE_MAP)
                        {
                            client_print_color(iIndex, 0, "[Server] Вы выбрали максимальное количество карт. Необходимо начать голосование!");
                        } else {
                            g_MapsMenu[NOMINATED_MAPS][g_MapsMenu[NOMINATED_MAPS_NUM]] = g_MapsMenu[MENU_POS] * 7 + iKey;
                            g_MapsMenu[NOMINATED_MAPS_NUM]++;
                        }

                        BuildMenu(iIndex, g_MapsMenu[MENU_POS]);
                    }
                }
            }
        }
    }
}

VoteMap_Start()
{
    new szMenu[512], iLen, iKeys;

#if defined SHOW_MENU_WITH_PERCENTS    
    g_iVotes = 0;
    arrayset(g_bIsVoted, false, sizeof g_bIsVoted);
#endif    

    switch(g_MapsMenu[NOMINATED_MAPS_NUM])
    {
        case 1:
        {    
            ArrayGetString(g_aMaps, g_MapsMenu[NOMINATED_MAPS][0], g_MapsMenu[NEW_MAP], charsmax(g_MapsMenu[NEW_MAP]));

            iLen = formatex(szMenu, charsmax(szMenu), "\w[\rVoteMap\w] Сменить карту на \r%s \w?^n^n", g_MapsMenu[NEW_MAP]);
            iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r1. \wДа^n\r0. \wНет^n^n^n");
            iKeys = MENU_KEY_1|MENU_KEY_0;
        }
        default:
        {
            iLen = formatex(szMenu, charsmax(szMenu), "\w[\rVoteMap\w] Выберите карту:^n^n");

            for(new i, szMapName[32]; i < g_MapsMenu[NOMINATED_MAPS_NUM]; i++)
            {
                ArrayGetString(g_aMaps, g_MapsMenu[NOMINATED_MAPS][i], szMapName, charsmax(szMapName));

                iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r%d. \w%s^n", i+1, szMapName);
                iKeys |= (1 << i);
            }

            iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "^n\r0. \wОставить текущую^n^n^n");
            iKeys |= MENU_KEY_0;
        }
    }

    show_menu(0, iKeys, szMenu, VOTE_TIME, "Vote Map");
    send_audio(0, "/sound/Gman/Gman_Choose2.wav");

#if defined SHOW_MENU_WITH_PERCENTS
    g_iTimeOst = VOTE_TIME;
    set_task(1.0, "ShowCacheMenu", TASK_INDEX, .flags = "a", .repeat = VOTE_TIME);
#else
    set_task(float(VOTE_TIME), "task_CheckVotes");
#endif
}

public VoteMap_Handler(iIndex, iKey)
{  
    new szName[MAX_NAME_LENGTH];

    get_user_name(iIndex, szName, charsmax(szName));

    switch(iKey)
    {
        case 9:
        {
            client_print_color(0, iIndex, "[Server] ^3%s^1 проголосовал против смены карты.", szName);
            g_MapsMenu[NO_VOTE_NUM]++;
        }
        default:
        {
            if(g_MapsMenu[NOMINATED_MAPS_NUM] == 1)
            {
                client_print_color(0, iIndex, "[Server] ^3%s^1 проголосовал за смену карты.", szName);
            } else {
                new szMapName[MAX_NAME_LENGTH];

                ArrayGetString(g_aMaps, g_MapsMenu[NOMINATED_MAPS][iKey], szMapName, charsmax(szMapName));

                client_print_color(0, iIndex, "[Server] ^3%s ^1выбрал карту ^4%s^1.", szName, szMapName);
            }

            g_MapsMenu[VOTES_MAPS][iKey]++;
        }
    }

#if defined SHOW_MENU_WITH_PERCENTS
    g_bIsVoted[iIndex] = true;
    g_iVotes++;

    ShowCacheMenu(iIndex);
}

public ShowCacheMenu(id)
{
    if(id == TASK_INDEX)
    {
        g_iTimeOst--;

        if(!g_iTimeOst)
        {
            show_menu(0, 0, "^n", 1);
            task_CheckVotes();
        } else {

            new iLen = formatex(g_VoteResMenu, charsmax(g_VoteResMenu), "\w[\rVoteMap\w] ");

            switch(g_MapsMenu[NOMINATED_MAPS_NUM])
            {
                case 1:
                {   
                    new iChangeNum = (g_iVotes ? floatround(g_MapsMenu[VOTES_MAPS][0] * 100.0 / g_iVotes) : 0);
                    new iNoChangeNum = (g_iVotes ? floatround(g_MapsMenu[NO_VOTE_NUM] * 100.0 / g_iVotes) : 0);

                    iLen += formatex(g_VoteResMenu[iLen], charsmax(g_VoteResMenu) - iLen, "Сменить карту на \r%s \w?^n^n", g_MapsMenu[NEW_MAP]);
                    iLen += formatex(g_VoteResMenu[iLen], charsmax(g_VoteResMenu) - iLen, "\r1. \wДа \d[\y%d%%\d]^n", iChangeNum);
                    iLen += formatex(g_VoteResMenu[iLen], charsmax(g_VoteResMenu) - iLen, "\r0. \wНет \d[\y%d%%\d]^n", iNoChangeNum);
                }
                default:
                {
                    iLen += formatex(g_VoteResMenu[iLen], charsmax(g_VoteResMenu) - iLen, "Выберите карту:^n^n");

                    for(new i, iChangeNum, szMapName[32]; i < g_MapsMenu[NOMINATED_MAPS_NUM]; ++i)
                    {
                        iChangeNum = (g_iVotes ? floatround(g_MapsMenu[VOTES_MAPS][i] * 100.0 / g_iVotes) : 0);

                        ArrayGetString(g_aMaps, g_MapsMenu[NOMINATED_MAPS][i], szMapName, charsmax(szMapName));

                        iLen += formatex(g_VoteResMenu[iLen], charsmax(g_VoteResMenu) - iLen, "\r%d. \w%s \d[\y%d%%\d]^n", i + 1, szMapName, iChangeNum);
                    }

                    new iNoChangeNum = (g_iVotes ? floatround(g_MapsMenu[NO_VOTE_NUM] * 100.0 / g_iVotes) : 0);

                    iLen += formatex(g_VoteResMenu[iLen], charsmax(g_VoteResMenu) - iLen, "^n\r0. \wОставить текущую \d[\y%d%%\d]^n", iNoChangeNum);
                }
            }

            iLen += formatex(g_VoteResMenu[iLen], charsmax(g_VoteResMenu) - iLen, "^n\yВы уже проголосовали!");
            iLen += formatex(g_VoteResMenu[iLen], charsmax(g_VoteResMenu) - iLen, "^n\wДо конца голосования осталось \r%d \wсекунд%s!", g_iTimeOst, (g_iTimeOst == 1) ? "а" : ((1 < g_iTimeOst < 5) ? "ы" : ""));

            for(new id = 1; id <= MaxClients; ++id)
            {
                if(is_user_connected(id))
                {
                    if(g_bIsVoted[id])
                        show_menu(id, 1023, g_VoteResMenu, -1, "ShowPercentMenu");
                }
            }
        }
    } else {
        show_menu(id, 1023, g_VoteResMenu, -1, "ShowPercentMenu");
    }
#endif    
}

public task_CheckVotes()
{
    new x;
    for(new i; i < g_MapsMenu[NOMINATED_MAPS_NUM]; ++i)
    {
        if(g_MapsMenu[VOTES_MAPS][x] < g_MapsMenu[VOTES_MAPS][i])
            x = i;
    }

    if(!g_MapsMenu[VOTES_MAPS][x] && !g_MapsMenu[NO_VOTE_NUM])
    {
        client_print_color(0, 0, "[Server] Голосование не состоялось, поскольку никто из игроков не проголосовал!");
        log_amx("Голосование не состоялось, поскольку никто из игроков не проголосовал!");

        set_clear_data();
    } else if(g_MapsMenu[VOTES_MAPS][x] <= g_MapsMenu[NO_VOTE_NUM]) {
        client_print_color(0, 0, "[Server] Смена карты отменена! Большинство игроков проголосовало против смены карты!");
        log_amx("Смена карты отменена! Большинство игроков проголосовало против смены карты!");

        set_clear_data();
    } else {
        ArrayGetString(g_aMaps, g_MapsMenu[NOMINATED_MAPS][x], g_MapsMenu[NEW_MAP], charsmax(g_MapsMenu[NEW_MAP]));

        client_print_color(0, 0, "[Server] Голосование завершено! Cледующая карта ^4%s^1.", g_MapsMenu[NEW_MAP]);
        log_amx("Голосование завершено! Cледующая карта ^4%s^1.", g_MapsMenu[NEW_MAP]);

        set_intermission_msg();
    }

    set_screen_fade(.fade = 0);
    set_frozen_users(.frozen = false);
}

public task_ChangeLevel()
    engine_changelevel(g_MapsMenu[NEW_MAP]); 

public task_ShowTimer()
{
    static iTimer = 3;

    if(iTimer == 0)
    {
        g_iState = STATE_VOTING;
        iTimer = 3;

        VoteMap_Start();
    } else {
        set_hudmessage(g_Colors[R], g_Colors[G], g_Colors[B], g_HudPos[X], g_HudPos[Y], 0, 0.0, 1.0, 0.0, 0.0, 4);
        show_hudmessage(0, "До голосования осталось %d секунд%s!", iTimer--, (iTimer == 1) ? "а" : ((1 < iTimer < 5) ? "ы" : ""));

        send_audio(0, g_Sounds[iTimer]);     
    }
}

public set_screen_fade(fade)
{
    new flags;
    new time = (0 <= fade <= 1) ? 4096 : 1;
    new hold = (0 <= fade <= 1) ? 1024 : 1;

    static msgScreenFade;

    if(!msgScreenFade)
        msgScreenFade = get_user_msgid("ScreenFade");
    
    switch(fade)
    {
        case 0:
        {
            flags = 2;
            set_msg_block(msgScreenFade, BLOCK_NOT);
        }
        case 1:
        {
            flags = 1;
            set_task(1.0, "set_screen_fade", 2);
        }
        case 2:
        {
            flags = 4;
            set_msg_block(msgScreenFade, BLOCK_SET);
        }
    }
    
    message_begin(MSG_BROADCAST, msgScreenFade);
    write_short(time);
    write_short(hold);
    write_short(flags);
    write_byte(0);
    write_byte(0);
    write_byte(0);
    write_byte(255);
    message_end();
}

stock bool:is_map_selected(const iMapID)
{
    if(g_MapsMenu[NOMINATED_MAPS_NUM] == 0)
        return false;

    for(new i; i < g_MapsMenu[NOMINATED_MAPS_NUM]; i++)
    {
        if(g_MapsMenu[NOMINATED_MAPS][i] == iMapID)
            return true;
    }

    return false;        
}

stock set_clear_data()
{
    g_iState = STATE_NONE;
    g_StartVote = false;

    g_MapsMenu[NOMINATED_MAPS_NUM] = 0;
    g_MapsMenu[MENU_INSIDER] = 0;
    g_MapsMenu[NEW_MAP][0] = 0;
    g_MapsMenu[NO_VOTE_NUM] = 0;

    arrayset(g_MapsMenu[NOMINATED_MAPS], 0, sizeof g_MapsMenu[NOMINATED_MAPS]);
}

stock set_intermission_msg()
{
    message_begin(MSG_ALL, SVC_INTERMISSION);
    message_end();

    set_task(float(TIME_UNTIL_CHANGE), "task_ChangeLevel", 0);
}

stock set_frozen_users(bool:frozen)
{
    if(frozen)
    {
        g_iOldFreezeTime = get_pcvar_num(g_pFreezeTime);
        set_pcvar_num(g_pFreezeTime, g_iOldFreezeTime + VOTE_TIME + 5);
    } else {
        if(get_pcvar_num(g_pFreezeTime) != g_iOldFreezeTime)
            set_pcvar_num(g_pFreezeTime, g_iOldFreezeTime);
    }
}

stock send_audio(const pIndex, szSound[])
{
    static gmsgSendAudio;

    if(!gmsgSendAudio) gmsgSendAudio = get_user_msgid("SendAudio");

    message_begin(pIndex ? MSG_ONE_UNRELIABLE : MSG_BROADCAST, gmsgSendAudio, _, pIndex);
    write_byte(pIndex);
    write_string(szSound);
    write_short(PITCH_NORM);
    message_end();
}
