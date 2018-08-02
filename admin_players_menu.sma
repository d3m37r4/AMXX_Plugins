// добавить ограничение на слапы игрока за раунд (чтобы не закидывали игрока на текстуры слапами)
// добавить проверку на мут (если игрок в муте, меняем название пункта с "заблокировать чат" на "разблокировать чат")
// добавить квар/макрос на скрытие в списке игроков других администраторов, игроков с иммунитетом и т.д.
// добавить проверку на онлайн (зачем открывать меню, когда на сервере нет других доступных для наказания игроков)
// если игрок выбран в меню, можно добавить блок реконнекта/и дисконнекта для этого игрока

#include <amxmodx>

#if !defined PLAYERS_PER_PAGE
    const PLAYERS_PER_PAGE = 8;
#endif

const SCREEN_NUM_MAX = 5;                           //Максимальное кол-во скринов, которое можно сделать одному игроку

const ACCESS_FLAG = ADMIN_BAN;                      // Доступ к меню          
const ADMIN_SUPER_FLAG = ADMIN_LEVEL_A;             // Флаг главного админа 
const IMMUNITY_FLAG = ADMIN_IMMUNITY;               // Флаг иммунитета

new const LINK_TO_VK[] = "vk.com/id_group";          // Ссылка, куда предоставлять скриншоты

enum _:PUNISHTYPE {
    //TODO: add stop shooting
    PUNISHTYPE_SLAP,
    PUNISHTYPE_SLAY,
    PUNISHTYPE_KICK,
    PUNISHTYPE_MUTE,
    PUNISHTYPE_SCREEN,
    PUNISHTYPE_BAN
};

enum _:DATA {
    MENU_POS,
    SCREEN_NUM,
    SLAP_VALUE_ID,
    PLAYERS[MAX_PLAYERS],
    ADMIN_NAME[MAX_NAME_LENGTH],
    SELECTED_PLAYER_NAME[MAX_NAME_LENGTH],
    SELECTED_PLAYER_INDEX,
    SELECTED_PLAYER_USERID,
    USERID[MAX_PLAYERS + 1]
};

new g_PunishmentMenuItems[PUNISHTYPE][] = {
    "Ударить игрока",
    "Убить игрока",
    "Удалить с сервера",
    "Заблокировать чат",
    "Сделать скриншот",
    "Забанить игрока"
};

new g_iSlapValue[] = 
{                               
    0,     // 0 HP
    5,     // 5 HP
    15,    // 10 HP
    50,    // 50 HP
    99,    // 99 HP
};

new g_HostName[MAX_NAME_LENGTH], g_MapName[MAX_NAME_LENGTH];
new g_ScrCount;
new g_PlData[MAX_PLAYERS + 1][DATA];

public plugin_init() {
    register_plugin("Admin Players Menu", "0.1b", "d3m37r4");

    register_clcmd("amx_plmenu", "Cmd_PlayersMenu", ACCESS_FLAG);

    register_menucmd(register_menuid("Players Menu"), 1023, "Handle_PlayersMenu");
    register_menucmd(register_menuid("Punishment Menu"), 1023, "Handle_PunishmentMenu");

    register_menucmd(register_menuid("Slap Menu"), 1023, "Handle_SlapMenu");
    register_menucmd(register_menuid("Screen Menu"), 1023, "Handle_ScreenMenu");

    get_cvar_string("hostname", g_HostName, charsmax(g_HostName));
    get_mapname(g_MapName, charsmax(g_MapName));
}

public Cmd_PlayersMenu(const iIndex, iFlags) {
    if(~get_user_flags(iIndex) & iFlags) {
        console_print(iIndex, "* Недостаточно прав для использования данной команды!"); 
        return PLUGIN_HANDLED;
    }

    /*g_PlData[iIndex][MENU_POS] = 0;
    g_PlData[iIndex][SELECTED_PLAYER_INDEX] = 0;*/
    g_PlData[iIndex][SCREEN_NUM] = 1;
    g_ScrCount = g_PlData[iIndex][SCREEN_NUM] % 10;

    Show_PlayersMenu(iIndex, g_PlData[iIndex][MENU_POS]);
    return PLUGIN_HANDLED;
}

Show_PlayersMenu(const iIndex, iPos) {
    new szMenu[512], iLen, iMenuItem; 
    new Keys = MENU_KEY_0;
    new iStartPos, iEndPos, iPagesNum;
    new iPlayersNum, iPlayerFlags, szName[MAX_NAME_LENGTH], AdminFlags = get_user_flags(iIndex);
  
    for(new pIndex = 1; pIndex <= MaxClients; pIndex++) {
        if(!is_user_connected(pIndex))
            continue;

        if(pIndex == iIndex)
            continue;

        iPlayerFlags = get_user_flags(pIndex);

        if((~AdminFlags & ADMIN_SUPER_FLAG) && (iPlayerFlags & IMMUNITY_FLAG))
            continue;

        if((~AdminFlags & ADMIN_SUPER_FLAG) && (iPlayerFlags & ACCESS_FLAG))
            continue;

        g_PlData[iIndex][PLAYERS][iPlayersNum++] = pIndex;
    }

    if(iPlayersNum <= 0)
    {
        client_print_color(iIndex, print_team_default, "[Server] Нет игроков, доступных вам для действий через данное меню!");
        return PLUGIN_HANDLED;
    }    

    iStartPos = iPos * PLAYERS_PER_PAGE;
    iEndPos = iStartPos + PLAYERS_PER_PAGE;
    iPagesNum = (iPlayersNum / PLAYERS_PER_PAGE + ((iPlayersNum % PLAYERS_PER_PAGE) ? 1 : 0));

    if(iStartPos >= iPlayersNum) 
        iStartPos = g_PlData[iIndex][MENU_POS] = 0;

    if(iEndPos > iPlayersNum)                                                     
        iEndPos = iPlayersNum;

    iLen = formatex(szMenu, charsmax(szMenu), "\w[\rPlayers Menu\w] Выберите игрока \w[\r%d\w/\r%d\w]^n^n", iPos + 1, iPagesNum);
  
    for(new i = iStartPos; i < iEndPos; i++) 
    {       
        g_PlData[iIndex][USERID][g_PlData[iIndex][PLAYERS][i]] = get_user_userid(g_PlData[iIndex][PLAYERS][i]);
        get_user_name(g_PlData[iIndex][PLAYERS][i], szName, charsmax(szName));

        Keys |= (1 << iMenuItem++);
        iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r%d. \w%s^n", iMenuItem, szName);
    }

    if(iEndPos < iPlayersNum) {
        Keys |= MENU_KEY_9;
        formatex(szMenu[iLen], charsmax(szMenu) - iLen, "^n\r9. \wДалее^n\r0. \w%s", iPos ? "Назад" : "Выход");
    } else {
        formatex(szMenu[iLen], charsmax(szMenu) - iLen, "^n\r0. \w%s", iPos ? "Назад" : "Выход");
    }
   
    show_menu(iIndex, Keys, szMenu, -1, "Players Menu");

    return PLUGIN_HANDLED;
}

public Handle_PlayersMenu(const iIndex, const iKey) {
    switch(iKey) {
        case 8: Show_PlayersMenu(iIndex, ++g_PlData[iIndex][MENU_POS]);
        case 9: {
            if(g_PlData[iIndex][MENU_POS])
                Show_PlayersMenu(iIndex, --g_PlData[iIndex][MENU_POS]);
        }
        default: {
            new iTargetID = g_PlData[iIndex][PLAYERS][g_PlData[iIndex][MENU_POS] * PLAYERS_PER_PAGE + iKey];
            new iTargetUID = get_user_userid(iTargetID);

            if(iTargetUID == g_PlData[iIndex][USERID][iTargetID]) {
                g_PlData[iIndex][SELECTED_PLAYER_INDEX] = iTargetID;
                g_PlData[iIndex][SELECTED_PLAYER_USERID] = iTargetUID;
                get_user_name(iTargetID, g_PlData[iIndex][SELECTED_PLAYER_NAME], charsmax(g_PlData[][SELECTED_PLAYER_NAME]));
                Show_PunishmentMenu(iIndex);
            } else {
                client_print_color(iIndex, print_team_default, "[Server] Выбранный вами игрок отсутствует на сервере.");
            }
        }
    }
}

Show_PunishmentMenu(const iIndex) {
    new Len, Menu[512], Keys = MENU_KEY_0|MENU_KEY_9;

    Len = formatex(Menu, charsmax(Menu), "\w[\rPunishment Menu\w] Выберите действие^n^n");
    Len += formatex(Menu[Len], charsmax(Menu) - Len, "\wВыбран игрок: %s^n^n", g_PlData[iIndex][SELECTED_PLAYER_NAME]);

    for(new i; i < PUNISHTYPE; i++) {
        if(i == PUNISHTYPE_SLAP || i == PUNISHTYPE_SLAY) {
            if(is_user_alive(g_PlData[iIndex][SELECTED_PLAYER_INDEX])) {
                Keys |= (1 << i);
                Len += formatex(Menu[Len], charsmax(Menu) - Len, "\r%d. \w%s^n", i + 1, g_PunishmentMenuItems[i]);  
            } else {
                Len += formatex(Menu[Len], charsmax(Menu) - Len, "\d%d. %s^n", i + 1, g_PunishmentMenuItems[i]);
            }
        } else {
            Keys |= (1 << i);
            Len += formatex(Menu[Len], charsmax(Menu) - Len, "\r%d. \w%s^n", i + 1, g_PunishmentMenuItems[i]);
        }
    }

    Len += formatex(Menu[Len], charsmax(Menu) - Len, "^n\r9. \wВернуться к списку игроков^n");
    Len += formatex(Menu[Len], charsmax(Menu) - Len, "\r0. \wВыход");

    show_menu(iIndex, Keys, Menu, -1, "Punishment Menu");
}

public Handle_PunishmentMenu(const iIndex, const iKey) {
    get_user_name(iIndex, g_PlData[iIndex][ADMIN_NAME], charsmax(g_PlData[][ADMIN_NAME]));

    switch(iKey) {
        case PUNISHTYPE_SLAP: Show_SlapMenu(iIndex);
        case PUNISHTYPE_SLAY: {
            user_kill(g_PlData[iIndex][SELECTED_PLAYER_INDEX], 1);
            Show_PunishmentMenu(iIndex);

            client_print_color(0, g_PlData[iIndex][SELECTED_PLAYER_INDEX], "[Server] Администратор ^4%s^1 убил ^3%s^1.", g_PlData[iIndex][ADMIN_NAME], g_PlData[iIndex][SELECTED_PLAYER_NAME]);
            log_amx("Администратор %s убил %s.", g_PlData[iIndex][ADMIN_NAME], g_PlData[iIndex][SELECTED_PLAYER_NAME]);
        }
        case PUNISHTYPE_KICK: {
            server_cmd("kick #%d Вы были удалены с сервера Администратором %s.", g_PlData[iIndex][SELECTED_PLAYER_USERID], g_PlData[iIndex][ADMIN_NAME]);
            // Нужно ли возвращаться к списку игроков после исполнения наказания?
            //server_exec();
            //Show_PlayersMenu(iIndex, g_PlData[iIndex][MENU_POS]);

            client_print_color(0, g_PlData[iIndex][SELECTED_PLAYER_INDEX], "[Server] Администратор ^4%s^1 удалил с сервера ^3%s^1.", g_PlData[iIndex][ADMIN_NAME], g_PlData[iIndex][SELECTED_PLAYER_NAME]);
            log_amx("Администратор %s удалил с сервера %s.", g_PlData[iIndex][ADMIN_NAME], g_PlData[iIndex][SELECTED_PLAYER_NAME]);
        }
        //case PUNISHTYPE_MUTE:
        case PUNISHTYPE_SCREEN: Show_ScreenMenu(iIndex);
        //case PUNISHTYPE_BAN:
        case 8: Show_PlayersMenu(iIndex, g_PlData[iIndex][MENU_POS]);
        case 9: arrayset(g_PlData[iIndex], 0, DATA);
    }   
}

Show_SlapMenu(const iIndex) {
    new Len, Menu[512], Keys = MENU_KEY_0|MENU_KEY_1|MENU_KEY_2|MENU_KEY_8|MENU_KEY_9;

    Len = formatex(Menu, charsmax(Menu), "\w[\rSlap Menu\w] Ударить игрока^n^n");
    Len += formatex(Menu[Len], charsmax(Menu) - Len, "\wВыбран игрок: %s^n^n", g_PlData[iIndex][SELECTED_PLAYER_NAME]);

    Len += formatex(Menu[Len], charsmax(Menu) - Len, "\r1. \wУдарить игрока на \r%d \wHP^n", g_iSlapValue[g_PlData[iIndex][SLAP_VALUE_ID]]);
    Len += formatex(Menu[Len], charsmax(Menu) - Len, "\r2. \wИзменить значение HP для удара^n^n");

    Len += formatex(Menu[Len], charsmax(Menu) - Len, "\r8. \wВернуться к списку действий^n^n");
    Len += formatex(Menu[Len], charsmax(Menu) - Len, "\r9. \wВернуться к списку игроков^n");
    Len += formatex(Menu[Len], charsmax(Menu) - Len, "\r0. \wВыход");

    show_menu(iIndex, Keys, Menu, -1, "Slap Menu");
}

public Handle_SlapMenu(const iIndex, const iKey) {
    switch(iKey) {
        case 0: {
            new iHealtValue = get_user_health(g_PlData[iIndex][SELECTED_PLAYER_INDEX]);
            user_slap(g_PlData[iIndex][SELECTED_PLAYER_INDEX], (iHealtValue > g_iSlapValue[g_PlData[iIndex][SLAP_VALUE_ID]]) ? g_iSlapValue[g_PlData[iIndex][SLAP_VALUE_ID]] : (iHealtValue - 1));
            Show_SlapMenu(iIndex);

            client_print_color(0, g_PlData[iIndex][SELECTED_PLAYER_INDEX],"[Server] Администратор ^4%s^1 ударил ^3%s^1 на ^4%d^1 НР.", g_PlData[iIndex][ADMIN_NAME], g_PlData[iIndex][SELECTED_PLAYER_NAME], g_iSlapValue[g_PlData[iIndex][SLAP_VALUE_ID]]);
            log_amx("Администратор %s ударил %s на %d HP.", g_PlData[iIndex][ADMIN_NAME], g_PlData[iIndex][SELECTED_PLAYER_NAME], g_iSlapValue[g_PlData[iIndex][SLAP_VALUE_ID]]);           
        }        
        case 1: {
            g_PlData[iIndex][SLAP_VALUE_ID] = (++g_PlData[iIndex][SLAP_VALUE_ID] > charsmax(g_iSlapValue) ? 0 : g_PlData[iIndex][SLAP_VALUE_ID]);
            Show_SlapMenu(iIndex);            
        }
        case 7: Show_PunishmentMenu(iIndex);
        case 8: Show_PlayersMenu(iIndex, g_PlData[iIndex][MENU_POS]);
        case 9: arrayset(g_PlData[iIndex], 0, DATA);
    }
}

Show_ScreenMenu(const iIndex) {
    new Len, Menu[512], Keys = MENU_KEY_0|MENU_KEY_1|MENU_KEY_2|MENU_KEY_8|MENU_KEY_9;

    Len = formatex(Menu, charsmax(Menu), "\w[\rScreen Menu\w] Сделать скриншоты игроку^n^n");
    Len += formatex(Menu[Len], charsmax(Menu) - Len, "\wВыбран игрок: %s^n^n", g_PlData[iIndex][SELECTED_PLAYER_NAME]);

    Len += formatex(Menu[Len], charsmax(Menu) - Len, "\r1. \wСделать \r%d \wскриншот%s^n", g_PlData[iIndex][SCREEN_NUM], g_ScrCount == 1 ? "" : ((1 < g_ScrCount < 5) ? "а" : "ов"));
    Len += formatex(Menu[Len], charsmax(Menu) - Len, "\r2. \wИзменить ко-во скриншотов^n^n");

    Len += formatex(Menu[Len], charsmax(Menu) - Len, "\r8. \wВернуться к списку действий^n^n");
    Len += formatex(Menu[Len], charsmax(Menu) - Len, "\r9. \wВернуться к списку игроков^n");
    Len += formatex(Menu[Len], charsmax(Menu) - Len, "\r0. \wВыход");

    show_menu(iIndex, Keys, Menu, -1, "Screen Menu");
}

public Handle_ScreenMenu(const iIndex, const iKey) {
    switch(iKey) {
        case 0: ScreenHandler(iIndex, g_PlData[iIndex][SELECTED_PLAYER_INDEX], false);   
        case 1: {
            g_PlData[iIndex][SCREEN_NUM] = (++g_PlData[iIndex][SCREEN_NUM] > SCREEN_NUM_MAX ? 1 : g_PlData[iIndex][SCREEN_NUM]);
            g_ScrCount = g_PlData[iIndex][SCREEN_NUM] % 10;
            Show_ScreenMenu(iIndex);            
        }
        case 7: Show_PlayersMenu(iIndex, g_PlData[iIndex][MENU_POS]);
        case 8: Show_PunishmentMenu(iIndex);
        case 9: arrayset(g_PlData[iIndex], 0, DATA);
    }
}

public task_MakeScreen(iIndex)
{                 
    if(is_user_connected(iIndex))
    {
        client_cmd(iIndex, "snapshot");
    } else {
        remove_task(iIndex);
    } 
}

ScreenHandler(iIndex, iPlayer, bool:bIsBan)
{
    new szMsg[190], szTime[22];
    get_time("%d.%m.%Y - %H:%M:%S", szTime, charsmax(szTime));                 

    if(iIndex)
    {       
        formatex(szMsg, charsmax(szMsg), "Время: %s^nАдминистратор: %s^nКарта: %s^nСкриншоты предоставить сюда: %s", szTime, g_PlData[iIndex][ADMIN_NAME], g_MapName, LINK_TO_VK);
        
        client_print_color(iIndex, iPlayer, "[Server] Вы сделали ^4%d^1 скриншот%s ^3%s^1.", g_PlData[iIndex][SCREEN_NUM], g_ScrCount == 1 ? "" : ((1 < g_ScrCount < 5) ? "а" : "ов"), g_PlData[iIndex][SELECTED_PLAYER_NAME]);
        log_amx("Администратор %s сделал скриншоты %s.", g_PlData[iIndex][ADMIN_NAME], g_PlData[iIndex][SELECTED_PLAYER_NAME]);
/*#if defined USE_SCREEN_MAKER_FOR_BANS
    } else {
        formatex(szMsg, charsmax(szMsg), "Время: %s^nСервер: %s^nКарта: %s^nИнформация о разбане: %s", szTime, g_HostName, g_MapName, LINK_TO_UNBAN);
#endif*/
    }

    set_hudmessage(0, 200, 0, -1.0, 0.21, 0, 0.0, float(g_PlData[iIndex][SCREEN_NUM] + 1), 0.0, 0.1, -1);
    show_hudmessage(iPlayer, szMsg);

    if(bIsBan) client_cmd(iPlayer, "stop");
  
    set_task(1.0, "task_MakeScreen", iPlayer, .flags = "a", .repeat = g_PlData[iIndex][SCREEN_NUM]);
} 
