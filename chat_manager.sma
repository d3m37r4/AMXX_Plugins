/*
    Powered by Lite Translit 
    Original plugin - Lite Translit v 2.8
    Author - neygomon

    Fragments of code from Chat Manager by Mistrick
*/

#include <amxmodx>

#if !defined NO_ACCESS
    const NO_ACCESS = -1;
#endif

#if !defined MAX_MESSAGE_LENGTH
    const MAX_MESSAGE_LENGTH = 191;
#endif

#define ADMIN_ALLCHAT                               // Показывать весь чат админам
#define ANTI_FLOOD                                  // Антифлуд для сообщений в текстовый чат
#define BLOCK_IDENTICAL_MSG                         // Блокировать повторяющиеся сообщения
#define BLOCK_CHAT_ON_VOTE                          // Блокирует чат на время голосования за смену карты

#if defined BLOCK_IDENTICAL_MSG 
    const MAX_IDENTICAL_MSG             = 3;        // Максимальное количество одинаковых сообщений сподряд
#endif

#if defined BLOCK_IDENTICAL_MSG || defined ANTI_FLOOD
    const MAX_WARNINGS_TO_BLOCK_CHAT    = 3;        // Максимальное количество предупреждений до блокировки чата
    const Float:BLOCK_CHAT_TIME         = 15.0;     // На сколько блокировать (в секундах)
    const Float:MIN_MESSAGE_DELAY       = 0.8;      // Минимальная задержка между сообщениями
#endif

const SUPER_ADMIN_FLAG = ADMIN_LEVEL_A;             // Флаг доступа для тега "Гл. Админ" в чате
const ADMIN_FLAG       = ADMIN_BAN;                 // Флаг доступа для тега "Админ" в чате
const VIP_FLAG         = ADMIN_LEVEL_H;             // Флаг доступа для тега "VIP" в чате   

enum _:USER_TYPE {
    CH_ADMIN, 
    ADMIN, 
    VIP
};

new const g_UserPrefix[USER_TYPE][] = {
    "[Ch.Admin]", 
    "[Admin]", 
    "[Vip]"
};

new const g_UserFlag[USER_TYPE] = {
    SUPER_ADMIN_FLAG, 
    ADMIN_FLAG, 
    VIP_FLAG
};

new const g_SumbolsTable[][] = {
    "Э", "#", ";", "%", "?", "э", "(", ")", "*", "+", "б", "-", "ю", ".", "0", "1", "2", "3", "4",
    "5", "6", "7", "8", "9", "Ж", "ж", "Б", "=", "Ю", ",", "^"", "Ф", "И", "С", "В", "У", "А", "П",
    "Р", "Ш", "О", "Л", "Д", "Ь", "Т", "Щ", "З", "Й", "К", "Ы", "Е", "Г", "М", "Ц", "Ч", "Н", "Я",
    "х", "\", "ъ", ":", "_", "ё", "ф", "и", "с", "в", "у", "а", "п", "р", "ш", "о", "л", "д", "ь",
    "т", "щ", "з", "й", "к", "ы", "е", "г", "м", "ц", "ч", "н", "я", "Х", "/", "Ъ", "Ё"
};

enum _:USER_DATA {
#if defined BLOCK_IDENTICAL_MSG
    LAST_MSG[MAX_IDENTICAL_MSG],
    REPEAT_WARN,
#endif
#if defined ANTI_FLOOD || defined BLOCK_IDENTICAL_MSG
    Float:LAST_MSG_TIME,
    Float:BLOCK_TIME,
    WARN_COUNT,
#endif
    bool:TRANSLATE
};

new g_PlayerInfo[MAX_PLAYERS + 1][USER_DATA];
new g_LogFileName[16], g_LogData[10];
new g_LogMsg;

#if defined BLOCK_CHAT_ON_VOTE
    #include <map_manager>
#endif

public plugin_init() {
    register_plugin("Chat Manager", "2.1.3", "d3m37r4");

    register_clcmd("say", "CmdSayHandler");
    register_clcmd("say_team", "CmdSayHandler");

    g_LogMsg = get_cvar_num("mp_logmessages");

    if(g_LogMsg) {
        get_time("20%y%m%d", g_LogData, charsmax(g_LogData));
        formatex(g_LogFileName, charsmax(g_LogFileName), "L%s.log", g_LogData);
    }
}

public client_putinserver(id) {
    arrayset(g_PlayerInfo[id], 0, USER_DATA);
}

public CmdSayHandler(id) {
    if(!is_user_connected(id)) {
        return PLUGIN_HANDLED;
    }

    if(is_vote_started()) {
        return PLUGIN_HANDLED;
    }

    new message[MAX_MESSAGE_LENGTH + 1];

    read_argv(0, message, charsmax(message));

    new bool:say_team = bool:(message[3] == '_');

    read_args(message, charsmax(message));

    remove_quotes(message);
    ReplaceWrongSimbols(message);
    trim(message);

    if(!message[0]) {
        return PLUGIN_HANDLED;
    }

    if(message[0] == '/') {
        if(equal(message[1], "eng")) {
            if(!g_PlayerInfo[id][TRANSLATE]) {
                client_print_color(id, print_team_default, "[Server] Вы уже используете английскую раскладку!");
            } else {
                client_print_color(id, print_team_default, "[Server] Английская раскладка активирована.");
                g_PlayerInfo[id][TRANSLATE] = false;
            }
        } else if(equal(message[1], "rus")) {
            if(g_PlayerInfo[id][TRANSLATE]) {
                client_print_color(id, print_team_default, "[Server] Вы уже используете русскую раскладку!");
            } else {
                client_print_color(id, print_team_default, "[Server] Русская раскладка активирована.");
                g_PlayerInfo[id][TRANSLATE] = true;
            }
        }

        return PLUGIN_HANDLED_MAIN;
    }

#if defined ANTI_FLOOD   
    new Float:gametime = get_gametime();

    if(gametime < g_PlayerInfo[id][BLOCK_TIME]) {
        new secleft = floatround(g_PlayerInfo[id][BLOCK_TIME] - gametime);
        client_print(id, print_center, secleft != 0 ? ("Чат будет доступен через %s сек.", fmt("%d", secleft)) : "Чат вновь доступен для вас!");
 
        return PLUGIN_HANDLED;
    }

    if(gametime < g_PlayerInfo[id][LAST_MSG_TIME] + MIN_MESSAGE_DELAY) {
        client_print_color(id, 0, "[Server] Сообщение было заблокировано! Вы слишком часто отправляете сообщения!");
        AddUserWarning(id);

        return PLUGIN_HANDLED;
    }

    g_PlayerInfo[id][LAST_MSG_TIME] = gametime;
#endif
    if(g_PlayerInfo[id][TRANSLATE]) {
        if(message[0] == '/') {
            copy(message, charsmax(message), message[1]);
        } else {
            new translated_msg[MAX_MESSAGE_LENGTH];

            TransliteString(translated_msg, charsmax(translated_msg), message);
            copy(message, charsmax(message), translated_msg);
        }
    }
#if defined BLOCK_IDENTICAL_MSG
    if(equal(message, g_PlayerInfo[id][LAST_MSG])) {
        if(++g_PlayerInfo[id][REPEAT_WARN] >= MAX_IDENTICAL_MSG) {
            client_print_color(id, 0, "[Server] Сообщение было заблокировано! Вы слишком часто отправляете однотипные сообщения!");
            AddUserWarning(id);

            return PLUGIN_HANDLED;
        }
    } else if(g_PlayerInfo[id][REPEAT_WARN]) {
        g_PlayerInfo[id][REPEAT_WARN]--;
    }

    copy(g_PlayerInfo[id][LAST_MSG], charsmax(g_PlayerInfo[][LAST_MSG]), message);
#endif

    new new_msg[MAX_MESSAGE_LENGTH + 1], team_name[12];
    new access = GetUserFlagsIndex(id);
    new CsTeams:sender_team = CsTeams:get_user_team(id, team_name, charsmax(team_name));

    formatex(new_msg, charsmax(new_msg), "^4%s ^3%n ^1%s: %s", (access != NO_ACCESS) ? g_UserPrefix[access] : "", id, say_team ? "(^4TEAM^1)" : "", message);

    if(say_team) {
        for(new player = 1; player <= MaxClients; player++) {
            if(!is_user_connected(player)) {
                continue;
            }
        #if defined ADMIN_ALLCHAT
            if(sender_team == CsTeams:get_user_team(player) || get_user_flags(player) & g_UserFlag[ADMIN]) {
                SendMsgChat(player, sender_team, new_msg);
            }
        #else
            if(sender_team == CsTeams:get_user_team(player)) {
                SendMsgChat(player, sender_team, new_msg);
            }
        #endif
        }
    } else {
        SendMsgChat(0, sender_team, new_msg);
    }

    if(g_LogMsg) {
        new authid[MAX_AUTHID_LENGTH];
        new userid = get_user_userid(id);
        get_user_authid(id, authid, charsmax(authid));
        log_to_file(g_LogFileName, "[#%d|%s|%s] %n%s: %s", userid, authid, team_name, id, say_team ? " (TEAM)" : "", message);
    }

    return PLUGIN_HANDLED;

}

#if defined BLOCK_IDENTICAL_MSG || defined ANTI_FLOOD
AddUserWarning(player) {
    if(++g_PlayerInfo[player][WARN_COUNT] >= MAX_WARNINGS_TO_BLOCK_CHAT) {
        g_PlayerInfo[player][BLOCK_TIME] = get_gametime() + BLOCK_CHAT_TIME;
        g_PlayerInfo[player][WARN_COUNT] = 0;

        client_print(player, print_center, "Чат был заблокирован на %0.f сек.", BLOCK_CHAT_TIME);
    }
}
#endif

GetUserFlagsIndex(player) {                                 
    new flags = get_user_flags(player);

    for(new i; i < sizeof g_UserFlag; i++) {
        if(flags & g_UserFlag[i]) {
            return i;
        }
    }

    return NO_ACCESS;
}

ReplaceWrongSimbols(string[]) {
    new len;

    for(new i; string[i] != EOS; i++) {
        if(string[i] == '%' || string[i] == '#' || 0x01 <= string[i] <= 0x04) {
            continue;
        }

        string[len++] = string[i];
    }

    string[len] = EOS;
}

TransliteString(string[], size, source[]) {
    new len;

    for(new i; source[i] != EOS && len < size; i++) {
        new ch = source[i];
     
        if('"' <= ch <= '~') {
            ch -= '"';
            string[len++] = g_SumbolsTable[ch][0];

            if(g_SumbolsTable[ch][1] != EOS) {
                string[len++] = g_SumbolsTable[ch][1];
            }
        } else {
            string[len++] = ch;
        }
    }

    string[len] = EOS;

    return len;
}

SendMsgChat(const player, const CsTeams:team, const msg[]) {
    switch(team) {
        case CS_TEAM_T: client_print_color(player, print_team_red, msg);
        case CS_TEAM_CT: client_print_color(player, print_team_blue, msg);
        default: client_print_color(player, print_team_grey, msg);
    }
}
