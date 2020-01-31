#include <amxmodx>
#include <amxmisc>
#include <reapi>

//#define SUPPORT_FOR_UNSCRUPULOUS_SERV_OWNERS      // Поддержка для недобросовестных серверодержателей (возвращение дефолтных значений кваров регейма, 
                                                    // хотя, все и так должно возвращаться при загрузке карты, т.к. game.cfg загружается заного).
//#define AUTO_CFG                                  // Автосоздание конфига 

enum { STATUSICON_HIDE, STATUSICON_SHOW, STATUSICON_FLASH };

enum POS_COORD { Float:X, Float:Y };
enum COST_TYPE { WEAPON_COST, CLIP_COST };
enum VALUE_TYPE { OLD_VALUE, NEW_VALUE };
enum COLOR_TYPE { RED, GREEN, BLUE };

enum any:NOTICE_MSG_TYPE { NOTICE_MSG_OFF, NOTICE_MSG_TEXT, NOTICE_MSG_HUD };

enum CVARS {
    WARMUP_TIME,
    FREE_WEAPON,
    Float:IMMUNITY_TIME,
    Float:RESPAWN_TIME,
    ARMOR_ONSPAWN,
    OPEN_BUYMENU_ONSPAWN,
    NOTICE_MSG,
    SHOW_RESPAWN_BAR,
    SHOW_ICON_RESPAWN_PROTECT
};

enum PCVARS {
    PCVAR_ROUNDTIME,    
    PCVAR_BUY_TIME,
    PCVAR_ROUND_INFINITE,
    PCVAR_FORCERESPAWN,
    PCVAR_RESPAWN_IMMUNITYTIME,
    PCVAR_ITEM_STAYTIME,
    PCVAR_REFILL_BPAMMO,
    PCVAR_BUY_ANYWHERE,
    PCVAR_WPN_ALLOW_MAP_PLACED,
    PCVAR_GIVE_PLAYER_C4
};

enum RG_CVARS {
    Float:CVAR_ROUNDTIME,    
    Float:CVAR_BUY_TIME,
    CVAR_ROUND_INFINITE[8],
    Float:CVAR_FORCERESPAWN,
    Float:CVAR_RESPAWN_IMMUNITYTIME,
    CVAR_ITEM_STAYTIME,
    CVAR_REFILL_BPAMMO,
    CVAR_BUY_ANYWHERE,
    CVAR_WPN_ALLOW_MAP_PLACED,
    CVAR_PCVAR_GIVE_PLAYER_C4,
    CVAR_GIVE_PLAYER_C4
};

enum any:HOOK_CHAINS {
    HookChain:ROUND_END_POST,      
    HookChain:ON_SPAWN_EQUIP_POST,
    HookChain:SET_SPAWN_PROTECT_POST,
    HookChain:REMOVE_SPAWN_PROTECT_POST,
    HookChain:CLEAN_UP_MAP_POST,
    HookChain:PLAYER_KILLED_POST
};

const TASK_INDEX = 200;

const Float:MAX_TXT_MSG_HOLDTIME = 2.0;
const Float:MAX_HUD_HOLDTIME = 15.0; 

new const g_HudColor[COLOR_TYPE] = { 192, 192, 192 };
new const Float:g_HudPos[POS_COORD] = { -1.0, 0.87 };

new g_Pointer[PCVARS];
new g_Cvar[CVARS];
new g_GameCvar[VALUE_TYPE][RG_CVARS];

new WeaponIdType:g_DefaultWeapCost[WeaponIdType][COST_TYPE];
new HookChain:g_HookChain[HOOK_CHAINS];

new bool:g_WarmupStarted;

#define getCvarDesc(%0) fmt("%L", LANG_SERVER, %0)
#define getLangKey(%0) fmt("%l", %0)

public plugin_init() {
    register_plugin("Simple WarmUp Mode", "2.2.1", "d3m37r4");
    register_dictionary("simple_warmup_mode.txt");

    RegisterForwards();
    RegisterCvars();

#if defined AUTO_CFG  
    AutoExecConfig(true, "warmup_config");
#endif
}

public OnConfigsExecuted() {
    GetCvarsPointers();

    if(g_Cvar[FREE_WEAPON]) {
        for(new WeaponIdType:weapon = WEAPON_P228; weapon <= WEAPON_P90; weapon++) {
            if(weapon != WEAPON_C4 && weapon != WEAPON_KNIFE) {
                g_DefaultWeapCost[weapon][WEAPON_COST] = rg_get_weapon_info(weapon, WI_COST);
                g_DefaultWeapCost[weapon][CLIP_COST] = rg_get_weapon_info(weapon, WI_CLIP_COST);
            }
        }
    }

    WarmUpStart();
}

// Thanks fantom for note
#if defined SUPPORT_FOR_UNSCRUPULOUS_SERV_OWNERS
public plugin_end() {
    if(g_WarmupStarted) {
        SetCvarsValues(OLD_VALUE);
    }
}
#endif

public RoundEnd_Post(WinStatus:status, ScenarioEventEndRound:event, Float:tmDelay) {
    if(g_WarmupStarted && !get_member_game(m_bCompleteReset) && !get_member_game(m_bGameStarted)) {
        WarmUpStop();
    }
}

public CSGameRules_CleanUpMap_Post() {
    RemoveHostageEntities();

    if(!get_member_game(m_bMapHasBuyZone)) {
        set_member_game(m_bCTCantBuy, false);
        set_member_game(m_bTCantBuy, false);
    }

    ChangeTargetNameEntities(true);
}

public CBasePlayer_SetSpawnProtection_Post(const id) {
    if(g_Cvar[SHOW_ICON_RESPAWN_PROTECT]) {
        send_status_icon(id, "suithelmet_full", STATUSICON_FLASH);
    }
}

public CBasePlayer_RemoveSpawnProtection_Post(const id) {
    send_status_icon(id, "suithelmet_full", STATUSICON_HIDE);
}

public CBasePlayer_Killed_Post(const victim, const killer, const gibs) {
    // https://github.com/wopox1337/CSDM-ReAPI/blob/6cef091f44ba9377897207b3855e0dff3c3e711f/amxmodx/scripting/csdm_core.sma#L271
    if(g_Cvar[SHOW_RESPAWN_BAR] && g_Cvar[RESPAWN_TIME] >= 1.5 && !(Menu_ChooseTeam <= get_member(victim, m_iMenu) <= Menu_ChooseAppearance)) {
        rg_send_bartime(victim, floatround(g_Cvar[RESPAWN_TIME]), false);
    }
}

public CBasePlayer_OnSpawnEquip_Post(const id, bool:addDefault, bool:equipGame) {
    if(is_user_connected(id)) {
        if(get_member(id, m_bNotKilled)) {
            rg_remove_all_items(id);
            rg_give_default_items(id);
        }

        if(g_Cvar[ARMOR_ONSPAWN]) {
            rg_set_user_armor(id, g_Cvar[ARMOR_ONSPAWN], ARMOR_VESTHELM);                                                         
        }

        if(g_Cvar[FREE_WEAPON]) {
            set_member(id, m_iHideHUD, get_member(id, m_iHideHUD) | HIDEHUD_MONEY);
        }

        if(g_Cvar[OPEN_BUYMENU_ONSPAWN]) {
            OpenDefaultBuyMenu(id);
        }
    }
}

public SendNoticeMessage() {
    if(g_Cvar[NOTICE_MSG] == NOTICE_MSG_TEXT) {
        client_print(0, print_center, _replace_string_ex(getLangKey("SWM_WARMUP_MODE"), "$n", "^r", true));
    } else if(g_Cvar[NOTICE_MSG] == NOTICE_MSG_HUD) {
        set_hudmessage(g_HudColor[RED], g_HudColor[GREEN], g_HudColor[BLUE], g_HudPos[X], g_HudPos[Y], any:MAX_HUD_HOLDTIME, any:-1);
        show_hudmessage(0, _replace_string_ex(getLangKey("SWM_WARMUP_MODE"), "$n", "^n", true));
    }
}

// https://github.com/s1lentq/ReGameDLL_CS/blob/5eee533c7279342071b2fb5a02f58e0e384819b8/regamedll/dlls/client.cpp#L3372
OpenDefaultBuyMenu(id) {
    _show_vgui_menu_ex(id, VGUI_Menu_Buy, (MENU_KEY_1|MENU_KEY_2|MENU_KEY_3|MENU_KEY_4|MENU_KEY_5|MENU_KEY_6|MENU_KEY_7|MENU_KEY_8|MENU_KEY_0), "#Buy");
    set_member(id, m_iMenu, Menu_Buy);    // for oldstyle menu 
}

WarmUpStart() {
    if(!g_WarmupStarted) {
        SetCvarsValues(NEW_VALUE);
        ToggleForwards(true);

        if(g_Cvar[FREE_WEAPON]) {
            SetFreeAllWeapon(true);
        }

        if(g_Cvar[NOTICE_MSG] != NOTICE_MSG_OFF) {      	
            set_task_ex(g_Cvar[NOTICE_MSG] == NOTICE_MSG_TEXT ? MAX_TXT_MSG_HOLDTIME : MAX_HUD_HOLDTIME, "SendNoticeMessage", TASK_INDEX, .flags = SetTask_Repeat);
        }

        set_member_game(m_bCompleteReset, false);
        set_member_game(m_bGameStarted, false);

        rg_round_end(
            .tmDelay = 5.0, 
            .st = WINSTATUS_DRAW, 
            .event = ROUND_GAME_COMMENCE, 
            .message = _replace_string_ex(getLangKey("SWM_WARMUP_MODE_ON"), "$n", "^r", true),  
            .sentence = "", 
            .trigger = true
        );

        g_WarmupStarted = true;

        log_amx("Warmup mode is started!");
    }
}

WarmUpStop() {
    if(g_WarmupStarted) {
        SetCvarsValues(OLD_VALUE);
        ToggleForwards(false);
        ChangeTargetNameEntities(false);

        if(g_Cvar[FREE_WEAPON]) {
            SetFreeAllWeapon(false);

            for(new id = 1; id <= MaxClients; id++) {
                if(is_user_connected(id)) {
                    set_entvar(id, var_flags, get_entvar(id, var_flags) | FL_FROZEN);
                    set_member(id, m_iHideHUD, get_member(id, m_iHideHUD) & ~HIDEHUD_MONEY);
                    set_member(id, m_flNextAttack, 3.0);
                }
            }            
        }

        set_member_game(m_bCompleteReset, true);
        set_member_game(m_bGameStarted, true);

        rg_round_end(
            .tmDelay = 3.0, 
            .st = WINSTATUS_DRAW, 
            .event = ROUND_END_DRAW, 
            .message = _replace_string_ex(getLangKey("SWM_WARMUP_MODE_OFF"), "$n", "^r", true), 
            .sentence = "", 
            .trigger = true
        );

        remove_task(TASK_INDEX);

        g_WarmupStarted = false;
        log_amx("Warmup mode is finished!");   
    }
}

SetFreeAllWeapon(bool:freeWeapon = true) {
    for(new WeaponIdType:weapon = WEAPON_P228; weapon <= WEAPON_P90; weapon++) {
        if(weapon != WEAPON_C4 && weapon != WEAPON_KNIFE) {
            rg_set_weapon_info(weapon, WI_COST, freeWeapon ? 0 : g_DefaultWeapCost[weapon][WEAPON_COST]);
            rg_set_weapon_info(weapon, WI_CLIP_COST, freeWeapon ? 0 : g_DefaultWeapCost[weapon][CLIP_COST]);
        }          
    }
}

RegisterCvars() {
    bind_pcvar_num(
        create_cvar(
            .name = "amx_warmup_time", 
            .string = "120",
            .flags = FCVAR_SERVER,
            .description = getCvarDesc("SWM_WARMUP_TIME_CVAR_DESC"),  
            .has_min = true, 
            .min_val = 0.0
        ), g_Cvar[WARMUP_TIME]
    );
    bind_pcvar_num(
        create_cvar(
            .name = "amx_warmup_free_weapon", 
            .string = "1",
            .flags = FCVAR_SERVER,
            .description = getCvarDesc("SWM_FREE_WEAPON_CVAR_DESC"), 
            .has_min = true, 
            .min_val = 0.0,
            .has_max = true, 
            .max_val = 1.0
        ), g_Cvar[FREE_WEAPON]
    );
    bind_pcvar_float(
        create_cvar(
            .name = "amx_warmup_immunity_time", 
            .string = "3.0",
            .flags = FCVAR_SERVER,
            .description = getCvarDesc("SWM_IMMUNITY_TIME_CVAR_DESC"), 
            .has_min = true, 
            .min_val = 0.0
        ), g_Cvar[IMMUNITY_TIME]
    );
    bind_pcvar_float(
        create_cvar(
            .name = "amx_warmup_respawn_time", 
            .string = "1.5",
            .flags = FCVAR_SERVER,
            .description = getCvarDesc("SWM_RESPAWN_TIME_CVAR_DESC"),  
            .has_min = true, 
            .min_val = 0.0
        ), g_Cvar[RESPAWN_TIME]
    );
    bind_pcvar_num(
        create_cvar(
            .name = "amx_warmup_armor_onspawn", 
            .string = "100",
            .flags = FCVAR_SERVER,
            .description = getCvarDesc("SWM_ARMOR_ONSPAWN_CVAR_DESC"), 
            .has_min = true, 
            .min_val = 0.0,
            .has_max = true, 
            .max_val = 255.0
        ), g_Cvar[ARMOR_ONSPAWN]
    );
    bind_pcvar_num(
        create_cvar(
            .name = "amx_warmup_open_buymenu_onspawn", 
            .string = "1",
            .flags = FCVAR_SERVER,
            .description = getCvarDesc("SWM_OPEN_BUY_ONSPAWN_CVAR_DESC"), 
            .has_min = true, 
            .min_val = 0.0,
            .has_max = true, 
            .max_val = 1.0
        ), g_Cvar[OPEN_BUYMENU_ONSPAWN]
    );
    bind_pcvar_num(
        create_cvar(
            .name = "amx_warmup_notice_msg", 
            .string = "1",
            .flags = FCVAR_SERVER,
            .description = getCvarDesc("SWM_NOTICE_MSG_CVAR_DESC"), 
            .has_min = true, 
            .min_val = 0.0,
            .has_max = true, 
            .max_val = 2.0
        ), g_Cvar[NOTICE_MSG]
    );    
    bind_pcvar_num(
        create_cvar(
            .name = "amx_warmup_show_respawn_bar", 
            .string = "0",
            .flags = FCVAR_SERVER,
            .description = getCvarDesc("SWM_SHOW_RESPAWN_BAR_CVAR_DESC"), 
            .has_min = true,
            .min_val = 0.0,
            .has_max = true, 
            .max_val = 1.0
        ), g_Cvar[SHOW_RESPAWN_BAR]
    );
    bind_pcvar_num(
        create_cvar(
            .name = "amx_warmup_show_icon_respawn_protect", 
            .string = "1",
            .flags = FCVAR_SERVER,
            .description = getCvarDesc("SWM_SHOW_ICON_RESPAWN_PROTECT_CVAR_DESC"), 
            .has_min = true,
            .min_val = 0.0,
            .has_max = true, 
            .max_val = 1.0
        ), g_Cvar[SHOW_ICON_RESPAWN_PROTECT]
    );
}

GetCvarsPointers() {                                          
    g_Pointer[PCVAR_ROUNDTIME] = get_cvar_pointer("mp_roundtime");
    g_Pointer[PCVAR_BUY_TIME] = get_cvar_pointer("mp_buytime");
    g_Pointer[PCVAR_ROUND_INFINITE] = get_cvar_pointer("mp_round_infinite");
    g_Pointer[PCVAR_FORCERESPAWN] = get_cvar_pointer("mp_forcerespawn");
    g_Pointer[PCVAR_RESPAWN_IMMUNITYTIME] = get_cvar_pointer("mp_respawn_immunitytime");
    g_Pointer[PCVAR_ITEM_STAYTIME] = get_cvar_pointer("mp_item_staytime");
    g_Pointer[PCVAR_REFILL_BPAMMO] = get_cvar_pointer("mp_refill_bpammo_weapons");
    g_Pointer[PCVAR_BUY_ANYWHERE] = get_cvar_pointer("mp_buy_anywhere");
    g_Pointer[PCVAR_WPN_ALLOW_MAP_PLACED] = get_cvar_pointer("mp_weapons_allow_map_placed");
    g_Pointer[PCVAR_GIVE_PLAYER_C4] = get_cvar_pointer("mp_give_player_c4");
}

SetCvarsValues(VALUE_TYPE:valueType) {
    if(valueType == NEW_VALUE) {
        g_GameCvar[NEW_VALUE][CVAR_ROUNDTIME] = float(g_Cvar[WARMUP_TIME]) / 60.0;
        g_GameCvar[NEW_VALUE][CVAR_FORCERESPAWN] = g_Cvar[RESPAWN_TIME];         
        g_GameCvar[NEW_VALUE][CVAR_BUY_TIME] = -1.0;
        g_GameCvar[NEW_VALUE][CVAR_RESPAWN_IMMUNITYTIME] = g_Cvar[IMMUNITY_TIME];
        g_GameCvar[NEW_VALUE][CVAR_ITEM_STAYTIME] = 0;
        g_GameCvar[NEW_VALUE][CVAR_REFILL_BPAMMO] = 3;
        g_GameCvar[NEW_VALUE][CVAR_BUY_ANYWHERE] = 1;
        g_GameCvar[NEW_VALUE][CVAR_WPN_ALLOW_MAP_PLACED] = 0;
        g_GameCvar[NEW_VALUE][CVAR_GIVE_PLAYER_C4] = 0;
        copy(g_GameCvar[NEW_VALUE][CVAR_ROUND_INFINITE], charsmax(g_GameCvar[][CVAR_ROUND_INFINITE]), "bcdefg");

        g_GameCvar[OLD_VALUE][CVAR_ROUNDTIME] = get_pcvar_float(g_Pointer[PCVAR_ROUNDTIME]); 
        g_GameCvar[OLD_VALUE][CVAR_FORCERESPAWN] = get_pcvar_float(g_Pointer[PCVAR_FORCERESPAWN]);  
        g_GameCvar[OLD_VALUE][CVAR_BUY_TIME] = get_pcvar_float(g_Pointer[PCVAR_BUY_TIME]);
        g_GameCvar[OLD_VALUE][CVAR_RESPAWN_IMMUNITYTIME] = get_pcvar_float(g_Pointer[PCVAR_RESPAWN_IMMUNITYTIME]);
        g_GameCvar[OLD_VALUE][CVAR_ITEM_STAYTIME] = get_pcvar_num(g_Pointer[PCVAR_ITEM_STAYTIME]);
        g_GameCvar[OLD_VALUE][CVAR_REFILL_BPAMMO] = get_pcvar_num(g_Pointer[PCVAR_REFILL_BPAMMO]);
        g_GameCvar[OLD_VALUE][CVAR_BUY_ANYWHERE] = get_pcvar_num(g_Pointer[PCVAR_BUY_ANYWHERE]);
        g_GameCvar[OLD_VALUE][CVAR_WPN_ALLOW_MAP_PLACED] = get_pcvar_num(g_Pointer[PCVAR_WPN_ALLOW_MAP_PLACED]);
        g_GameCvar[OLD_VALUE][CVAR_GIVE_PLAYER_C4] = get_pcvar_num(g_Pointer[PCVAR_GIVE_PLAYER_C4]);
        get_pcvar_string(g_Pointer[PCVAR_ROUND_INFINITE], g_GameCvar[OLD_VALUE][CVAR_ROUND_INFINITE], charsmax(g_GameCvar[][CVAR_ROUND_INFINITE]));                 
    }

    set_pcvar_float(g_Pointer[PCVAR_ROUNDTIME], g_GameCvar[valueType][CVAR_ROUNDTIME]);
    set_pcvar_float(g_Pointer[PCVAR_FORCERESPAWN], g_GameCvar[valueType][CVAR_FORCERESPAWN]); 
    set_pcvar_float(g_Pointer[PCVAR_BUY_TIME], g_GameCvar[valueType][CVAR_BUY_TIME]);
    set_pcvar_float(g_Pointer[PCVAR_RESPAWN_IMMUNITYTIME], g_GameCvar[valueType][CVAR_RESPAWN_IMMUNITYTIME]);
    set_pcvar_num(g_Pointer[PCVAR_REFILL_BPAMMO], g_GameCvar[valueType][CVAR_REFILL_BPAMMO]);
    set_pcvar_num(g_Pointer[PCVAR_ITEM_STAYTIME], g_GameCvar[valueType][CVAR_ITEM_STAYTIME]);
    set_pcvar_num(g_Pointer[PCVAR_BUY_ANYWHERE], g_GameCvar[valueType][CVAR_BUY_ANYWHERE]);
    set_pcvar_num(g_Pointer[PCVAR_WPN_ALLOW_MAP_PLACED], g_GameCvar[valueType][CVAR_WPN_ALLOW_MAP_PLACED]);
    set_pcvar_num(g_Pointer[PCVAR_GIVE_PLAYER_C4], g_GameCvar[valueType][CVAR_GIVE_PLAYER_C4]);
    set_pcvar_string(g_Pointer[PCVAR_ROUND_INFINITE], g_GameCvar[valueType][CVAR_ROUND_INFINITE]);
}

RegisterForwards() {
    DisableHookChain(g_HookChain[ROUND_END_POST] = RegisterHookChain(RG_RoundEnd, "RoundEnd_Post", true));
    DisableHookChain(g_HookChain[SET_SPAWN_PROTECT_POST] = RegisterHookChain(RG_CBasePlayer_SetSpawnProtection, "CBasePlayer_SetSpawnProtection_Post", true));
    DisableHookChain(g_HookChain[REMOVE_SPAWN_PROTECT_POST] = RegisterHookChain(RG_CBasePlayer_RemoveSpawnProtection, "CBasePlayer_RemoveSpawnProtection_Post", true));
    DisableHookChain(g_HookChain[ON_SPAWN_EQUIP_POST] = RegisterHookChain(RG_CBasePlayer_OnSpawnEquip, "CBasePlayer_OnSpawnEquip_Post", true));
    DisableHookChain(g_HookChain[CLEAN_UP_MAP_POST] = RegisterHookChain(RG_CSGameRules_CleanUpMap, "CSGameRules_CleanUpMap_Post", true));
    DisableHookChain(g_HookChain[PLAYER_KILLED_POST] = RegisterHookChain(RG_CBasePlayer_Killed, "CBasePlayer_Killed_Post", true));
}

ToggleForwards(const bool:enable) {
    for(new i; i < sizeof g_HookChain; i++) {
        if(g_HookChain[i]) {
            enable ? EnableHookChain(g_HookChain[i]) : DisableHookChain(g_HookChain[i]);
        }
    }   
}

RemoveHostageEntities() {
    new ent;

    while((ent = rg_find_ent_by_class(ent, "hostage_entity"))) {
        set_entvar(ent, var_health, 0);
        set_entvar(ent, var_movetype, MOVETYPE_TOSS);
        set_entvar(ent, var_deadflag, DEAD_DEAD);              
        set_entvar(ent, var_effects, EF_NODRAW);
        set_entvar(ent, var_solid, SOLID_NOT);
    }
}

ChangeTargetNameEntities(const bool:change = false) {
    new ent, targetname[MAX_NAME_LENGTH];

    while((ent = rg_find_ent_by_class(ent, "game_player_equip"))) {
        get_entvar(ent, var_targetname, targetname, charsmax(targetname));

        if(equali(targetname, fmt(change ? "equipment" : "equipment_dummy"))) {
            set_entvar(ent, var_targetname, change ? "equipment_dummy" : "equipment");
        }
    }

    while((ent = rg_find_ent_by_class(ent, "player_weaponstrip"))) {
        get_entvar(ent, var_targetname, targetname, charsmax(targetname));

        if(equali(targetname, fmt(change ? "stripper" : "stripper_dummy"))) {
            set_entvar(ent, var_targetname, change ? "stripper_dummy" : "stripper");
        }
    }    
}

stock send_status_icon(const index, const icon[], const status = STATUSICON_HIDE, red = 0, green = 160, blue = 0) {
    static msgStatusIcon;

    if(!msgStatusIcon) {
        msgStatusIcon = get_user_msgid("StatusIcon");
    }

    message_begin(index ? MSG_ONE_UNRELIABLE : MSG_BROADCAST, msgStatusIcon, _, index);
    write_byte(status);
    write_string(icon);

    if(status) {
        write_byte(red);
        write_byte(green);
        write_byte(blue);
    }

    message_end();
}

stock _show_vgui_menu_ex(const index, const any:menu, const keys, const text[]) {
    if(get_member(index, m_bVGUIMenus) || menu > any:VGUI_Menu_Buy_Item) {
        static msgVGUIMenu;

        if(!msgVGUIMenu) {
            msgVGUIMenu = get_user_msgid("VGUIMenu");
        }

        message_begin(index ? MSG_ONE : MSG_ALL, msgVGUIMenu, _, index);
        write_byte(menu);
        write_short(keys);
        write_char(-1);
        write_byte(0);
        write_string(text);
        message_end();
    } else {
        show_menu(index, keys, text);
    }
}

// Crutch for line breaks. <3 ML:)
stock _replace_string_ex(const _buffer[], const _search[], const _string[], bool:_caseSensitive = true) {
    new buffer[MAX_FMT_LENGTH];

    formatex(buffer, charsmax(buffer), _buffer);
    replace_string(buffer, charsmax(buffer), _search, _string, _caseSensitive);

    return buffer;
}