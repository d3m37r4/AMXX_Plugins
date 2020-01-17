#include <amxmodx>
#include <authemu>
#tryinclude <reapi>

new const CONFIG_NAME[] = "/users_blackList.ini";

const MAX_BUFFER_LENGTH = 128;

enum {
    SETTINGS,
    BLACKLIST
};

enum any:SETTINGS_LIST {
    KICK_REASON_TXT[MAX_BUFFER_LENGTH],
    NOTIFICATION_MSG[MAX_BUFFER_LENGTH]
};

new Trie:g_BlackList;

new g_Settings[SETTINGS_LIST];
new g_CurrentSection;

public plugin_init() {
    register_plugin("Users BlackList", "1.0.1", "d3m37r4");

    g_BlackList = TrieCreate();
}

public plugin_cfg() {
    new filedir[MAX_RESOURCE_PATH_LENGTH];

    get_localinfo("amxx_configsdir", filedir, charsmax(filedir));
    add(filedir, charsmax(filedir), CONFIG_NAME);

    if(!parseConfigINI(filedir)) {
        set_fail_state("Fatal parse error!");
    }
}

public client_connect(id) {
    if(is_user_bot(id) || is_user_hltv(id)) {
        return PLUGIN_HANDLED;
    }

    new user_ip[MAX_IP_LENGTH];
    get_user_ip(id, user_ip, charsmax(user_ip), 1);
    
    if(!is_user_authemu(id) && TrieKeyExists(g_BlackList, user_ip)) {
        _console_print_ex(id, g_Settings[NOTIFICATION_MSG]);
    #if defined rh_drop_client
        rh_drop_client(id, g_Settings[KICK_REASON_TXT]);
    #else
        server_cmd("kick #%d %s", get_user_userid(id), g_Settings[KICK_REASON_TXT]);
    #endif
    } else {
        log_amx("Player '%n', who is on blacklist, is authorized through GSClient.", id);
    }

    return PLUGIN_HANDLED;
}

bool:parseConfigINI(const configFile[]) {
    new INIParser:parser = INI_CreateParser();

    if(parser != Invalid_INIParser) {
        INI_SetReaders(parser, "ReadCFGKeyValue", "ReadCFGNewSection");
        INI_ParseFile(parser, configFile);
        INI_DestroyParser(parser);

        return true;
    }

    return false;
}

public bool:ReadCFGNewSection(INIParser:handle, const section[], bool:invalid_tokens, bool:close_bracket) {
    if(!close_bracket) {
        log_amx("Closing bracket was not detected! Current section name is '%s'.", section);
        return false;
    }

    if(equal(section, "settings")) {
        g_CurrentSection = SETTINGS;
        return true;
    }

    if(equal(section, "blacklist")) {
        g_CurrentSection = BLACKLIST;
        return true;
    }

    return false;
}

public bool:ReadCFGKeyValue(INIParser:handle, const key[], const value[]) {
    if(g_CurrentSection == SETTINGS) {
        if(equal(key, "kick_reason_txt")) {
            copy(g_Settings[KICK_REASON_TXT], charsmax(g_Settings[KICK_REASON_TXT]), value);
        } else if(equal(key, "notification_msg")) {
            copy(g_Settings[NOTIFICATION_MSG], charsmax(g_Settings[NOTIFICATION_MSG]), value);
        }
    } else if(g_CurrentSection == BLACKLIST) {
        TrieSetCell(g_BlackList, key, 1);
    }

    return true;
}

_console_print_ex(const index, const message[], any:...) {
    new buffer[MAX_BUFFER_LENGTH]; 
    vformat(buffer, charsmax(buffer), message, 3);
    
    new len = strlen(buffer);
    buffer[len++] = '^n';
    buffer[len] = 0;    
  
    if(1 <= index <= MaxClients) {
        message_begin(MSG_ONE, SVC_PRINT, .player = index);
        write_string(buffer);
        message_end();
    } else {
        server_print(buffer);
    }

    return 1;
}
