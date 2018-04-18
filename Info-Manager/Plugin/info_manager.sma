#include <amxmodx>

#define is_valid_player(%1)        (1 <= (%1) <= g_iMaxPlayers)

enum _:SETTINGS            
{
    bool:MSG_TYPE,
    bool:MSG_OFF,
    Float:MSG_INTERVAL,
    MSG_PREFIX[32]
};

enum _:O_SETTINGS            
{
    LINK_MOTD_HELP[64],
    LINK_MOTD_RULES[64],
    LINK_MOTD_ADMIN[64],
    LINK_MOTD_VIP[64],
    SITE_LINK[32],
    IP_LINK[32],
    VK_LINK[32]
};

const MESSAGE_LENGTH = 190;

new g_PluginSettings[SETTINGS], g_OtherSettings[O_SETTINGS];

new Array:g_aMessages, g_iMsgArraySize, g_iMsgIndex;

new bool:g_bHideMsg[MAX_PLAYERS + 1] = false;

new iFile, szFileDir[128];
new g_iMaxPlayers;

public plugin_precache()
{
    get_localinfo("amxx_configsdir", szFileDir, charsmax(szFileDir));
    formatex(szFileDir, charsmax(szFileDir), "%s/info_manager.ini", szFileDir);

    switch(file_exists(szFileDir))
    {
        case 0: set_fail_state("Файл ^"%s^" не найден.", szFileDir);
        case 1:
        {
            g_aMessages = ArrayCreate(MESSAGE_LENGTH);
            iFile = fopen(szFileDir, "rt");

            if(iFile)
            {
                new szBuffer[MESSAGE_LENGTH], szBlock[32], szKey[32], szValue[64], iStrLen;

                while(!feof(iFile))
                {
                    fgets(iFile, szBuffer, charsmax(szBuffer));
                    trim(szBuffer);

                    if(!(szBuffer[0]) || szBuffer[0] == ';' || szBuffer[0] == '#')
                        continue;
            
                    iStrLen = strlen(szBuffer);
            
                    if(szBuffer[0] == '[' && szBuffer[iStrLen - 1] == ']')
                    {
                        copyc(szBlock, charsmax(szBlock), szBuffer[1], szBuffer[iStrLen - 1]);
                        continue;
                    }

                    if(szBlock[0])
                    {
                        if(szBlock[0] == 'e' && szBlock[1] == 'n' && szBlock[2] == 'd')
                            continue;
                    }

                    if(equali(szBlock, "plugin_settings"))
                    {
                        strtok(szBuffer, szKey, charsmax(szKey), szValue, charsmax(szValue), '=');
                            
                        trim(szKey);
                        trim(szValue);
                            
                        remove_quotes(szKey);
                        remove_quotes(szValue);

                        if(equali(szKey, "msg_type"))
                        {
                            g_PluginSettings[MSG_TYPE] = bool:(str_to_num(szValue) ? false : true); 
                            continue;
                        }

                        if(equali(szKey, "msg_interval"))
                        {
                            g_PluginSettings[MSG_INTERVAL] = str_to_float(szValue); 
                            continue;
                        }

                        if(equali(szKey, "msg_prefix"))
                        {
                            formatex(g_PluginSettings[MSG_PREFIX], charsmax(g_PluginSettings[MSG_PREFIX]), szValue);

                            replace_all(g_PluginSettings[MSG_PREFIX], charsmax(g_PluginSettings[MSG_PREFIX]), "!n", "^1");
                            replace_all(g_PluginSettings[MSG_PREFIX], charsmax(g_PluginSettings[MSG_PREFIX]), "!t", "^3");
                            replace_all(g_PluginSettings[MSG_PREFIX], charsmax(g_PluginSettings[MSG_PREFIX]), "!g", "^4");
                            continue;                            
                        }

                        if(equali(szKey, "msg_off"))
                            g_PluginSettings[MSG_OFF] = bool:(str_to_num(szValue) ? true : false); 
                    }

                    if(equali(szBlock, "messages"))
                    {
                        trim(szBuffer);
                        remove_quotes(szBuffer);

                        replace_all(szBuffer, charsmax(szBuffer), "!n", "^1");
                        replace_all(szBuffer, charsmax(szBuffer), "!t", "^3");
                        replace_all(szBuffer, charsmax(szBuffer), "!g", "^4");

                        trim(szBuffer);

                        ArrayPushString(g_aMessages, szBuffer);
                    }

                    if(equali(szBlock, "other_settings"))
                    {
                        strtok(szBuffer, szKey, charsmax(szKey), szValue, charsmax(szValue), '=');
                            
                        trim(szKey);
                        trim(szValue);
                            
                        remove_quotes(szKey);
                        remove_quotes(szValue);

                        if(equali(szKey, "motd_help"))
                        {
                            formatex(g_OtherSettings[LINK_MOTD_HELP], charsmax(g_OtherSettings[LINK_MOTD_HELP]), szValue);
                            continue;
                        }

                        if(equali(szKey, "motd_rules"))
                        {
                            formatex(g_OtherSettings[LINK_MOTD_RULES], charsmax(g_OtherSettings[LINK_MOTD_RULES]), szValue);
                            continue;
                        }

                        if(equali(szKey, "motd_admin"))
                        {
                            formatex(g_OtherSettings[LINK_MOTD_ADMIN], charsmax(g_OtherSettings[LINK_MOTD_ADMIN]), szValue);
                            continue;
                        }

                        if(equali(szKey, "motd_vip"))
                        {
                            formatex(g_OtherSettings[LINK_MOTD_VIP], charsmax(g_OtherSettings[LINK_MOTD_VIP]), szValue);
                            continue;
                        }

                        if(equali(szKey, "site_link"))
                        {
                            formatex(g_OtherSettings[SITE_LINK], charsmax(g_OtherSettings[SITE_LINK]), szValue);
                            continue;
                        }

                        if(equali(szKey, "ip_link"))
                        {
                            formatex(g_OtherSettings[IP_LINK], charsmax(g_OtherSettings[IP_LINK]), szValue);
                            continue;
                        }

                        if(equali(szKey, "vk_link"))
                            formatex(g_OtherSettings[VK_LINK], charsmax(g_OtherSettings[VK_LINK]), szValue);
                    }
                }

                g_iMsgArraySize = ArraySize(g_aMessages);

                if(!g_iMsgArraySize)
                    log_amx("Блок сообщений пуст! Необходимо проверить файл ^"%s^" на наличие сообщений!", szFileDir);
                  
                fclose(iFile);
            }
        }
    }
}

public plugin_init()
{
    register_plugin("Info Manager", "2.0", "d3m37r4");

    register_clcmd("say", "cmd_SayHandler");
    register_clcmd("say_team", "cmd_SayHandler");

    if(g_iMsgArraySize)
        set_task(g_PluginSettings[MSG_INTERVAL], "ShowMsg", .flags="b");

    g_iMaxPlayers = get_maxplayers();
}

public plugin_end()   
    ArrayDestroy(g_aMessages);

public client_putinserver(id)
{
    if(!g_PluginSettings[MSG_OFF] && !is_valid_player(id))
        return;

    new szUserInfo[4];

    get_user_info(id, "_msg", szUserInfo, charsmax(szUserInfo));

    if(szUserInfo[0] && equal(szUserInfo, "off"))
    {
        g_bHideMsg[id] = true;
    } else {
        g_bHideMsg[id] = false;
    }
}

public ShowMsg()
{
    new szMessage[MESSAGE_LENGTH];
    new iPlayers[32], szPlFlags[10], iPlNum;

    ArrayGetString(g_aMessages, ++g_iMsgIndex >= g_iMsgArraySize ? (g_iMsgIndex = 0) : g_iMsgIndex, szMessage, charsmax(szMessage));

    switch(g_PluginSettings[MSG_TYPE])
    {
        case true: formatex(szPlFlags, charsmax(szPlFlags), "ch");
        case false: formatex(szPlFlags, charsmax(szPlFlags), "bch");
    }

    get_players(iPlayers, iPlNum, szPlFlags);

    for(new i; i < iPlNum; i++)
    {
        if(g_PluginSettings[MSG_OFF])
        {
            if(!g_bHideMsg[iPlayers[i]])
                client_print_color(iPlayers[i], 0,"%s %s", g_PluginSettings[MSG_PREFIX], szMessage);
        } else {
            client_print_color(iPlayers[i], 0,"%s %s", g_PluginSettings[MSG_PREFIX], szMessage);
        }
    }
}

public cmd_SayHandler(id)
{
    if(!is_valid_player(id))
        return PLUGIN_HANDLED;

    new szMessage[MESSAGE_LENGTH];

    read_args(szMessage, charsmax(szMessage));
    remove_quotes(szMessage);
    trim(szMessage);

    if(szMessage[0] == '/')
    {
        if(g_PluginSettings[MSG_OFF])
        {
            new szUserInfo[4];

            get_user_info(id, "_msg", szUserInfo, charsmax(szUserInfo));

            if(strcmp(szMessage[1], "msg_off", true) == 0)
            {
                if(szUserInfo[0] && equal(szUserInfo, "off"))
                {
                    client_print(id, print_center, "Показ сообщений сервера в текством чате уже отключен!");
                } else {
                    g_bHideMsg[id] = true;
                        
                    client_print(id, print_center, "Показ сообщений сервера в текством чате отключен!");
                    client_cmd(id, "setinfo _msg off");               
                }
            }

            if(strcmp(szMessage[1], "msg_on", true) == 0)
            {
                if(szUserInfo[0] && equal(szUserInfo, "on"))
                {
                    client_print(id, print_center, "Показ сообщений сервера в текством чате уже включен!");
                } else {
                    g_bHideMsg[id] = false; 
                                  
                    client_print(id, print_center, "Показ сообщений сервера в текством чате включен!");
                    client_cmd(id, "setinfo _msg on");             
                }
            }
        }

        if(g_OtherSettings[LINK_MOTD_HELP])
        {
            if(strcmp(szMessage[1], "help", true) == 0)
                return show_motd(id, g_OtherSettings[LINK_MOTD_HELP], "Команды чата");
        }

        if(g_OtherSettings[LINK_MOTD_RULES])
        {
            if(strcmp(szMessage[1], "rules", true) == 0)
                return show_motd(id, g_OtherSettings[LINK_MOTD_RULES], "Пpaвилa cepвepa");
        }

        if(g_OtherSettings[LINK_MOTD_ADMIN])
        {
            if(strcmp(szMessage[1], "admin", true) == 0)
                return show_motd(id, g_OtherSettings[LINK_MOTD_ADMIN], "Пpaвa Aдминиcтpaтopa");
        }

        if(g_OtherSettings[LINK_MOTD_VIP])
        {
            if(strcmp(szMessage[1], "vip", true) == 0)
                return show_motd(id, g_OtherSettings[LINK_MOTD_VIP], "Cтaтyc Vip-игpoкa");
        }

        if(g_OtherSettings[IP_LINK])
        {
            if(strcmp(szMessage[1], "ip", true) == 0)
                return client_print_color(id, -2, "%s Ip-Адрес сервера: ^3%s", g_PluginSettings[MSG_PREFIX], g_OtherSettings[IP_LINK]);
           }

        if(g_OtherSettings[SITE_LINK])
        {
            if(strcmp(szMessage[1], "site", true) == 0)
                return client_print_color(id, -2, "%s Наш сайт: ^3%s", g_PluginSettings[MSG_PREFIX], g_OtherSettings[SITE_LINK]);
        }

        if(g_OtherSettings[VK_LINK])
        {
            if(strcmp(szMessage[1], "vk", true) == 0)
                return client_print_color(id, -2, "%s Наша группа ВКонтакте: ^3%s", g_PluginSettings[MSG_PREFIX], g_OtherSettings[VK_LINK]);
        }
    }

    return PLUGIN_CONTINUE;
}
