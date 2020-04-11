#include <amxmodx>
#include <map_manager>
#include <map_manager_scheduler>

new const ADMIN_MAPLIST[]   = "admin_maps.ini";       // Список карт для формирования меню (в строку указывается только название карты без учета онлайна)
const ACCESS_FLAG           = ADMIN_MAP;              // Флаг для доступа к меню

const VOTE_BY_ADMIN_MENU    = 4;
const MAX_ITEMS_MENU        = 6;
const MAX_VOTELIST_SIZE     = 9;

enum {
    MenuKeyConfirm = 6, 
    MenuKeyBack,
    MenuKeyNext,
    MenuKeyExit
};

enum {
    ChangeMapMenu, 
    VoteMapMenu
};

enum InfoList {
    MenuType,
    MenuPos,
    MenuId,
    MenuUserId
};

enum StateType { 
    StateNone = -1,
    StateSelect
};

new Array:g_MapList, Array:g_VoteList, Array:g_MainMapList;
new g_LoadedMaps, g_VoteItems;

new g_MenuInfo[InfoList];
new StateType:g_State = StateNone;
new g_EventNewRound;

new g_LastRound;
new g_NextMap[MAPNAME_LENGTH];
new g_Prefix[48];

public plugin_init() {
    register_plugin("Admin Mapmenu", "0.3", "d3m37r4");

    register_clcmd("amx_changemap_menu", "CmdChangeMapMenu", ACCESS_FLAG);
    register_clcmd("amx_votemap_menu", "CmdVoteMapMenu", ACCESS_FLAG);

    register_menucmd(g_MenuInfo[MenuId] = register_menuid("MapMenu"), 1023, "HandleMapMenu");
    disable_event(g_EventNewRound = register_event("HLTV", "EventNewRound", "a", "1=0", "2=0"));

    RegisterBlockCmd();
}

public plugin_cfg() {
    g_MapList = ArrayCreate(MAPNAME_LENGTH);
    g_VoteList = ArrayCreate(MAPNAME_LENGTH);

    new filename[32];
    copy(filename, charsmax(filename), ADMIN_MAPLIST);

    if(!mapm_load_maplist_to_array(g_MapList, filename)) {
        ArrayDestroy(g_MapList);
        ArrayDestroy(g_VoteList);
        set_fail_state("nothing loaded from ^"%s^"", filename);
    }

    if(g_MapList) {
        g_LoadedMaps = ArraySize(g_MapList);
    }

    bind_pcvar_num(get_cvar_pointer("mapm_last_round"), g_LastRound);
    mapm_get_prefix(g_Prefix, charsmax(g_Prefix));
}

public CmdSay(id) {
    if(!is_vote_started() && !is_vote_finished() && !is_vote_will_in_next_round()) {
        return PLUGIN_CONTINUE;
    }

    new text[MAPNAME_LENGTH]; read_args(text, charsmax(text));
    remove_quotes(text); trim(text); strtolower(text);
    
    if(is_string_with_space(text)) {
        return PLUGIN_CONTINUE;
    }

    new bool:nomination = false;
    new map_index = mapm_get_map_index(text);
    if(map_index != INVALID_MAP_INDEX) {
        nomination = true;
    } else if(strlen(text) >= 4) {
        map_index = __FindSimilarMapByString(text, g_MainMapList);
        if(map_index != INVALID_MAP_INDEX ) {
            nomination = true;
        }
    }

    if(nomination) {
        return PLUGIN_HANDLED;
    }

    return PLUGIN_CONTINUE;
}

public CmdBlock(id) {
    if(is_vote_started() || is_vote_finished() || is_vote_will_in_next_round()) {
        return PLUGIN_HANDLED;
    }

    return PLUGIN_CONTINUE;
}

public CmdChangeMapMenu(const id, const flags) {
    if(!MenuEnabled(id, flags)) {
        return PLUGIN_HANDLED; 
    }

    OpenMapMenu(id, ChangeMapMenu);
    return PLUGIN_HANDLED;     
}

public CmdVoteMapMenu(const id, const flags) {
    if(!MenuEnabled(id, flags)) {
        return PLUGIN_HANDLED; 
    }

    OpenMapMenu(id, VoteMapMenu);
    return PLUGIN_HANDLED;   
}

OpenMapMenu(const id, const menuid) {
    if(g_State == StateNone) {
        g_MenuInfo[MenuPos] = 0;
        g_MenuInfo[MenuType] = menuid;
        g_MenuInfo[MenuUserId] = id;
        g_State = StateSelect;
        ShowMapMenu(id);
    }

    if(g_State == StateSelect) {
        new bool:menu_open, menu_index, dummy;
        for(new player = 1; player <= MaxClients; player++) {
            if(!is_user_connected(player)) {
                continue;
            }

            player_menu_info(player, menu_index, dummy);
            if(g_MenuInfo[MenuId] != menu_index) {
                continue;
            }

            menu_open = true;
            break;
        }

        if(!menu_open) {
            ClearData();
        }
    }
}

ShowMapMenu(const id, const page = 0) {
    new start, end;
    new current = GetMenuPage(page, g_LoadedMaps, MAX_ITEMS_MENU, start, end);
    new pages = GetMenuPagesNum(g_LoadedMaps, MAX_ITEMS_MENU);
    new max_items = g_MenuInfo[MenuType] == VoteMapMenu ? mapm_get_votelist_size() : 1;

    new menu[MAX_MENU_LENGTH];
    new len = formatex(menu, charsmax(menu), g_MenuInfo[MenuType] == VoteMapMenu ? 
    "\y[\rVoteMap Menu\y] \wСписок карт" : "\y[\rChangeMap Menu\y] \wСписок карт");

    len += formatex(menu[len], charsmax(menu) - len, " \y%d/%d^n", current + 1, pages + 1);
    len += formatex(menu[len], charsmax(menu) - len, "\wВыбрано карт: \y%d/%d^n^n", g_VoteItems, max_items);

    new keys = MENU_KEY_0;
    for(new i = start, item, map_name[MAPNAME_LENGTH]; i < end; i++) {
        ArrayGetString(g_MapList, i, map_name, charsmax(map_name));

        keys |= (1 << item);
        len += formatex(menu[len], charsmax(menu) - len, ArrayFindString(g_VoteList, map_name) != INVALID_MAP_INDEX ?
        "\d%d. %s \y[\r*\y]^n" : "\r%d. \w%s^n", ++item, map_name);
    }

    new tmp[15];
    setc(tmp, MAX_ITEMS_MENU - (end - start) + 1, '^n');
    len += copy(menu[len], charsmax(menu) - len, tmp);

    if(g_VoteItems) {
        keys |= MENU_KEY_7;
        len += formatex(menu[len], charsmax(menu) - len, g_MenuInfo[MenuType] == VoteMapMenu ?
        "\r7. \wСоздать голосование^n" : "\r7. \wПодтвердить выбор^n");
    } else {
        len += formatex(menu[len], charsmax(menu) - len, g_MenuInfo[MenuType] == VoteMapMenu ?
        "\d7. Создать голосование^n" : "\d7. Подтвердить выбор^n");
    }

    if(g_MenuInfo[MenuPos] != 0) {
        keys |= MENU_KEY_8;
        len += formatex(menu[len], charsmax(menu) - len, "^n\r8. \wНазад");
    } else {
        len += formatex(menu[len], charsmax(menu) - len, "^n\d8. Назад");
    }

    if(end < g_LoadedMaps) {
        keys |= MENU_KEY_9;
        len += formatex(menu[len], charsmax(menu) - len, "^n\r9. \wДалее");
    } else {
        len += formatex(menu[len], charsmax(menu) - len, "^n\d9. Далее");
    }

    formatex(menu[len], charsmax(menu) - len, "^n\r0. \wВыход");
    show_menu(id, keys, menu, -1, "MapMenu");
}

public HandleMapMenu(const id, const key) {
    new max_items = g_MenuInfo[MenuType] == VoteMapMenu ? mapm_get_votelist_size() : 1;
    switch(key) {
        case MenuKeyConfirm: {
            if(g_MenuInfo[MenuType] == VoteMapMenu) {
                client_print_color(0, print_team_default, "%s ^4%n ^1создал голосование за смену карты.", g_Prefix, id);
                map_scheduler_start_vote(VOTE_BY_ADMIN_MENU);               
            } else {
                ArrayGetString(g_VoteList, 0, g_NextMap, charsmax(g_NextMap));
                set_cvar_string("amx_nextmap", g_NextMap);
                client_print_color(0, print_team_default, "%s ^4%n ^1сменил текущую карту на ^4%s^1.", g_Prefix, id, g_NextMap);
                if(g_LastRound) {
                    enable_event(g_EventNewRound);
                    client_print_color(0, print_team_default, "%s ^1Смена карты произойдет в начале следующего раунда.", g_Prefix);
                } else {
                    intermission();
                }
            }
        }
        case MenuKeyBack: {
            ShowMapMenu(id, --g_MenuInfo[MenuPos]);
        }
        case MenuKeyNext: {
            ShowMapMenu(id, ++g_MenuInfo[MenuPos]);
        }
        case MenuKeyExit: {
            ClearData();
        }
        default: {
            new map_name[MAPNAME_LENGTH];
            ArrayGetString(g_MapList, g_MenuInfo[MenuPos] * MAX_ITEMS_MENU + key, map_name, charsmax(map_name));

            new map_index = ArrayFindString(g_VoteList, map_name);
            if(map_index == INVALID_MAP_INDEX) {
                if(g_VoteItems != max_items) {
                    ArrayPushString(g_VoteList, map_name);
                    g_VoteItems++;
                }
            } else {
                ArrayDeleteItem(g_VoteList, map_index);
                g_VoteItems--;
            }
           
            ShowMapMenu(id, g_MenuInfo[MenuPos]);
        }
    }
}

public EventNewRound() {
    client_print_color(0, print_team_default, "%s ^1Следующая карта: ^4%s^1.", g_Prefix, g_NextMap);
    intermission();
}

public mapm_maplist_loaded(Array:maplist) {
    g_MainMapList = ArrayClone(maplist);
}

public mapm_prepare_votelist(type) { 
    if(type != VOTE_BY_ADMIN_MENU) {
        return;
    }

    for(new i, map_name[MAPNAME_LENGTH]; i < g_VoteItems; i++) {
        ArrayGetString(g_VoteList, i, map_name, charsmax(map_name));
        mapm_push_map_to_votelist(map_name, PUSH_BY_NATIVE, CHECK_IGNORE_MAP_ALLOWED);
    }

    mapm_set_votelist_max_items(g_VoteItems);
}

bool:MenuEnabled(const id, const flags) {
    if(~get_user_flags(id) & flags) {
        console_print(id, "* Недостаточно прав для использования команды!");
        return false;
    }

    if(is_vote_started()) {
        client_print_color(id, print_team_default, "%s ^1Команда недоступна! Голосование уже запущено!", g_Prefix);
        return false;
    }

    if(is_vote_will_in_next_round()) {
        client_print_color(id, print_team_default, "%s ^1Команда недоступна! В следующем раунде начнется голосование за смену карты!", g_Prefix);
        return false;
    }

    if(is_last_round()) {
        get_cvar_string("amx_nextmap", g_NextMap, charsmax(g_NextMap));
        client_print_color(id, print_team_default, "%s ^1Команда недоступна! Cледующая карта уже определена: ^4%s^1.", g_Prefix, g_NextMap);
        return false;        
    }

    if(g_State == StateSelect && g_MenuInfo[MenuUserId] != id) {
        client_print_color(id, print_team_default, "%s ^1Команда недоступна! ^4%n^1 уже выбирает %s!", 
        g_Prefix, g_MenuInfo[MenuUserId], g_MenuInfo[MenuType] == VoteMapMenu ? "карты" : "карту");
        return false;
    }

    return true;
}

RegisterBlockCmd() {
    register_clcmd("say", "CmdSay");
    register_clcmd("say_team", "CmdSay");

    register_clcmd("say rtv", "CmdBlock");
    register_clcmd("say /rtv", "CmdBlock");
    register_clcmd("say maps", "CmdBlock");
    register_clcmd("say /maps", "CmdBlock");
}

GetMenuPage(cur_page, elements_num, per_page, &start, &end) {
    new max = min(cur_page * per_page, elements_num);
    start = max - (max % MAX_ITEMS_MENU);
    end = min(start + per_page, elements_num);
    return start / per_page;
}

GetMenuPagesNum(elements_num, per_page) {
    return (elements_num - 1) / per_page;
}

ClearData() {
    g_State = StateNone;
    g_VoteItems = 0;
    g_NextMap[0] = EOS;
    g_MenuInfo[MenuUserId] = 0;
    ArrayClear(g_VoteList);
}

__FindSimilarMapByString(string[MAPNAME_LENGTH], Array:maplist) {
    if(maplist == Invalid_Array) {
        return INVALID_MAP_INDEX;
    }

    new map_info[MapStruct], end = ArraySize(maplist);
    for(new i; i < end; i++) {
        ArrayGetArray(maplist, i, map_info);
        if(containi(map_info[Map], string) != -1) {
            return i;
        }
    }

    return INVALID_MAP_INDEX;
}