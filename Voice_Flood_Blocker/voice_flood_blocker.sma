/*
    Credits: F@nt0M (dev-cs.ru/members/16/) for assistance in implementations.
*/

#include <amxmodx>
#include <amxmisc>
#tryinclude <reapi>
#include <PersistentDataStorage>

#if !defined _reapi_included
    #include <VtcApi>
#endif

#define AUTO_CFG        // Автосоздание конфига 

enum (+=100) {
    TASK_CHECK_MUTED_PLAYERS = 100,
    TASK_CHECK_VOICE_SPAM
};

enum _:USER_DATA {
    IP[MAX_IP_LENGTH],   
    AUTHID[MAX_AUTHID_LENGTH],   
    START_SPEAK,
    LAST_SPEAK,
    BAN_TIME,
    bool:MUTED
};

enum _:CVARS {
    CHECK_TIME,
    BLOCK_TIME,
    CHECK_BLOCKED_TIME,
    DELAY_SPAM_CMD
};

new g_PlayerInfo[MAX_PLAYERS + 1][USER_DATA];
new Array:g_CacheData;
new g_Cvar[CVARS];

#define vtc_get_user_block(%0)    g_PlayerInfo[%0][MUTED]
#define vtc_get_user_speak(%0)    VTC_IsClientSpeaking(%0)

public plugin_init() {
    register_plugin("Voice Flood Blocker", "1.4", "d3m37r4");
    register_dictionary("vfb.txt");
    
#if defined _reapi_included
    if(!has_vtc()) {
        set_fail_state("Requires meta plugin VoiceTranscoder!");
    }
#endif

    RegisterCvars();

#if defined AUTO_CFG  
    AutoExecConfig(.autoCreate = true, .name = "vfb_config");
#endif
}

public plugin_cfg() {
    g_CacheData = ArrayCreate(USER_DATA);

    new CacheSize; PDS_GetCell("BackupArraySize", CacheSize);

    for(new i, systime = get_systime(0), pldata[USER_DATA]; i < CacheSize; i++) {
        PDS_GetArray(fmt("ArrayString_%d", i), pldata, sizeof pldata);

        if(pldata[BAN_TIME] > systime) {
            ArrayPushArray(g_CacheData, pldata);
        }
    }

    set_task_ex(float(g_Cvar[CHECK_BLOCKED_TIME]), "Task_CheckMutedPlayers", TASK_CHECK_MUTED_PLAYERS, _, _, SetTask_Repeat);
}

public client_putinserver(id) {
    if(is_user_bot(id) || is_user_hltv(id)) {
        return PLUGIN_HANDLED;
    }

    arrayset(g_PlayerInfo[id], 0, USER_DATA);

    remove_task(id);
    remove_task(TASK_CHECK_VOICE_SPAM + id);

    get_user_ip(id, g_PlayerInfo[id][IP], charsmax(g_PlayerInfo[][IP]), 1);
    get_user_authid(id, g_PlayerInfo[id][AUTHID], charsmax(g_PlayerInfo[][AUTHID]));

    for(new i, timeleft, systime = get_systime(0), SizeCacheData = ArraySize(g_CacheData), pldata[USER_DATA]; i < SizeCacheData; i++) {
        ArrayGetArray(g_CacheData, i, pldata);

        if(!strcmp(pldata[IP], g_PlayerInfo[id][IP], true) || !strcmp(pldata[AUTHID], g_PlayerInfo[id][AUTHID], true)) {
            timeleft = pldata[BAN_TIME] - systime;

            if(pldata[MUTED] && timeleft > 0) {
                g_PlayerInfo[id][START_SPEAK] = pldata[START_SPEAK];
                g_PlayerInfo[id][LAST_SPEAK] = pldata[LAST_SPEAK];

                vtc_set_user_mute(id, timeleft, .notice = false, .checkMute = true);
            } else {
                vtc_set_user_unmute(id, .notice = false);
            }

            ArrayDeleteItem(g_CacheData, i);
        }
    }

    return PLUGIN_HANDLED;
}

public VTC_OnClientStartSpeak(const id) {
    new systime = get_systime(0);

    if(vtc_get_user_block(id)) {    
        new timeleft = g_PlayerInfo[id][BAN_TIME] - systime;

        client_print(id, print_center, "%l", timeleft <= 0 ? 
            "VFB_EXP_NEED_UPD" : "VFB_WAIT_EXP", 
            fmt("%d", timeleft)
        );
        client_cmd(id, "-voicerecord");
    } else {
        new pldata[1];
        pldata[0] = get_user_userid(id);

        if(g_Cvar[DELAY_SPAM_CMD]) {
            if((systime - g_PlayerInfo[id][LAST_SPEAK]) <= g_Cvar[DELAY_SPAM_CMD]) {
                if(!task_exists(TASK_CHECK_VOICE_SPAM + id)) {
                    vtc_set_user_mute(id, g_Cvar[DELAY_SPAM_CMD], .notice = false, .checkMute = false);
                    set_task_ex(float(g_Cvar[DELAY_SPAM_CMD]), "Task_UnBlockVoiceSpam", TASK_CHECK_VOICE_SPAM + id, pldata, sizeof pldata);
                }

                client_print(id, print_center, "%l", "VFB_SPAM_CMD", g_Cvar[DELAY_SPAM_CMD]);
                client_cmd(id, "-voicerecord");

                return;
            }
        }

        g_PlayerInfo[id][START_SPEAK] = systime;

        if(!task_exists(id)) {
            set_task_ex(float(g_Cvar[CHECK_TIME]), "Task_BlockPlayerVoice", id, pldata, sizeof pldata);
        }
    }
}

public VTC_OnClientStopSpeak(const id) {
    new systime = get_systime(0);
    g_PlayerInfo[id][LAST_SPEAK] = systime;

    if((systime - g_PlayerInfo[id][START_SPEAK]) < g_Cvar[CHECK_TIME]) {
        remove_task(id);
    }
}

public Task_BlockPlayerVoice(data[1], id) {
    if(!is_user_connected(id) || data[0] != get_user_userid(id)) {
        return;
    }

    if(!vtc_get_user_block(id) && vtc_get_user_speak(id)) {
        vtc_set_user_mute(id, g_Cvar[BLOCK_TIME], .notice = true, .checkMute = true);
        client_cmd(id, "-voicerecord");
        remove_task(id);
    }
}

public Task_UnBlockVoiceSpam(data[1], id) {
    id -= TASK_CHECK_VOICE_SPAM;

    if(is_user_connected(id) || data[0] == get_user_userid(id)) {
        vtc_set_user_unmute(id, .notice = false);
        remove_task(TASK_CHECK_VOICE_SPAM + id);
    }
}

public Task_CheckMutedPlayers() {
    for(new id, systime = get_systime(0); id <= MaxClients; id++) {
        if(is_user_connected(id) && vtc_get_user_block(id) && (g_PlayerInfo[id][BAN_TIME] - systime) <= 0) {
            vtc_set_user_unmute(id);
        }
    }
}

// либо заменить на RH_SV_DropClient и принудительно использовать reapi, либо убрать plugin end
// т.к. client_disconnected вызывается и при смене карты, а RH_SV_DropClient только при дисконнекте
public client_disconnected(id) {
    if(vtc_get_user_block(id) && (g_PlayerInfo[id][BAN_TIME] - get_systime(0)) > 0) {
        ArrayPushArray(g_CacheData, g_PlayerInfo[id]);

        //log_amx("client_disconnected | Игрок %n вышел с сервера, информация о нем записана в массив.", id);
    }
}

/*public plugin_end() {
    for(new id, systime = get_systime(0); id <= MaxClients; id++) {
        if(!is_user_connected(id) || !vtc_get_user_block(id)) {
            continue;
        }

        if((g_PlayerInfo[id][BAN_TIME] - systime) <= 0) {
            continue;
        }

        ArrayPushArray(g_CacheData, g_PlayerInfo[id]);
    }

    log_amx("plugin_end | записей в массиве: %d", ArraySize(g_CacheData));
}*/

public PDS_Save() {
    new SizeCacheData = ArraySize(g_CacheData);

    for(new i, pldata[USER_DATA]; i < SizeCacheData; i++) {
        ArrayGetArray(g_CacheData, i, pldata);
        PDS_SetArray(fmt("ArrayString_%d", i), pldata, sizeof pldata);
    }

    PDS_SetCell("BackupArraySize", SizeCacheData);
}

RegisterCvars() {
    bind_pcvar_num(
        create_cvar(
            .name = "amx_vfb_checktime", 
            .string = "15",
            .flags = FCVAR_SERVER,
            .description = fmt("%L", LANG_SERVER, "VFB_CHECKTIME_CVAR_DESC"), 
            .has_min = true, 
            .min_val = 1.0
        ),
        g_Cvar[CHECK_TIME]
    );
    bind_pcvar_num(
        create_cvar(
            .name = "amx_vfb_blocktime", 
            .string = "30",
            .flags = FCVAR_SERVER,
            .description = fmt("%L", LANG_SERVER, "VFB_BLOCKTIME_CVAR_DESC"),
            .has_min = true, 
            .min_val = 1.0
        ),
        g_Cvar[BLOCK_TIME]
    );
    bind_pcvar_num(
        create_cvar(
            .name = "amx_vfb_check_blocked_time", 
            .string = "10",
            .flags = FCVAR_SERVER,
            .description = fmt("%L", LANG_SERVER, "VFB_CHECK_BLOCKED_TIME_CVAR_DESC"),
            .has_min = true, 
            .min_val = 1.0
        ),
        g_Cvar[CHECK_BLOCKED_TIME]
    );
    bind_pcvar_num(
        create_cvar(
            .name = "amx_vfb_delay_spam_cmd", 
            .string = "1",
            .flags = FCVAR_SERVER,
            .description = fmt("%L", LANG_SERVER, "VFB_DELAY_SPAM_CVAR_DESC"), 
            .has_min = true, 
            .min_val = 0.0
        ),
        g_Cvar[DELAY_SPAM_CMD]
    );    
}

vtc_set_user_mute(const index, const blocktime, bool:notice = true, bool:checkMute = false) {
    g_PlayerInfo[index][BAN_TIME] = get_systime(0) + blocktime;

    if(checkMute) {
        g_PlayerInfo[index][MUTED] = true;
    }

    if(notice) { 
        client_print(index, print_center, "%l", "VFB_BLOCK_FLOOD", blocktime);
        //log_amx("Игроку %n был заблокирован голосовой чат на %d сек.", index, blocktime);
    }

    VTC_MuteClient(index);
}

vtc_set_user_unmute(const index, bool:notice = true) {
    g_PlayerInfo[index][BAN_TIME] = 0;
    g_PlayerInfo[index][MUTED] = false;

    if(notice) { 
        client_print(index, print_center, "%l", "VFB_BLOCK_FLOOD_EXP");
        //log_amx("Голосовой чат для игрока %n был разблокирован.", index);
    }

    VTC_UnmuteClient(index);
}