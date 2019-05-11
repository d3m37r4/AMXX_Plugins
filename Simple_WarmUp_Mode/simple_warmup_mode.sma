#include <amxmodx>
#include <reapi>

#define NOTICE_IN_CENTER_OF_SCREEN				// Уведомление по центру экрана, о том, что включен разминочный режим
//#define AUTO_CFG								// Автосоздание конфига 

#if defined NOTICE_IN_CENTER_OF_SCREEN
    #include <amxmisc>
    const TASK_INDEX = 200;
#endif

new const g_ProtectIcon[] = "suithelmet_full";
new const g_WarmupModeIcon[] = "item_healthkit";

enum {
    STATUSICON_HIDE, 
    STATUSICON_SHOW, 
    STATUSICON_FLASH 
};

enum COST_TYPE {
    WEAPON_COST,
    CLIP_COST
};

enum CVARS {
    WARMUP_TIME,
    FREE_WEAPON,
    IMMUNITY_TIME,
    Float:RESPAWN_TIME,
    ARMOR_ONSPAWN
};

enum VALUE_TYPE {
    OLD_VALUE,
    NEW_VALUE
};

enum PCVARS {
    PCVAR_FREEZETIME,
    PCVAR_ROUNDTIME,    
    PCVAR_BUY_TIME,
    PCVAR_ROUND_INFINITE,
    PCVAR_FORCERESPAWN,
    PCVAR_REFILL_BPAMMO,
    PCVAR_RESPAWN_IMMUNITYTIME,
    PCVAR_ITEM_STAYTIME,
    PCVAR_REFILL_BPAMMO
};

enum RG_CVARS {
    CVAR_FREEZETIME,
    Float:CVAR_ROUNDTIME,    
    Float:CVAR_BUY_TIME,
    CVAR_ROUND_INFINITE[8],
    Float:CVAR_FORCERESPAWN,
    CVAR_REFILL_BPAMMO,
    CVAR_RESPAWN_IMMUNITYTIME,
    CVAR_ITEM_STAYTIME,
    CVAR_REFILL_BPAMMO
};

enum _:HOOK_CHAINS {
    HookChain:ROUND_END_POST,      
    HookChain:ON_SPAWN_EQUIP_POST,
    HookChain:DROP_PLAYER_ITEM_PRE,
    HookChain:GIVEC4_PRE,
    HookChain:BUY_WEAPON_PRE,
    HookChain:BUY_WEAPON_POST,
    HookChain:SET_SPAWN_PROTECT_POST,
    HookChain:REMOVE_SPAWN_PROTECT_POST,
    HookChain:CLEAN_UP_MAP_POST
};

new g_Pointer[PCVARS];
new g_Cvar[CVARS];
new g_GameCvar[VALUE_TYPE][RG_CVARS];
new g_MsgIdStatusIcon;

new WeaponIdType:g_DefaultWeapCost[WeaponIdType][COST_TYPE];
new HookChain:g_HookChain[HOOK_CHAINS];
new bool:g_WarmupStarted;

public plugin_init() {
    register_plugin("Simple WarmUp Mode", "0.3.2", "d3m37r4");

    RegisterForwards();
    RegisterCvars();

#if defined AUTO_CFG  
    AutoExecConfig(.autoCreate = true, .name = "warmup_config");
#endif

    g_MsgIdStatusIcon = get_user_msgid("StatusIcon");     
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

public HC_RoundEnd_Post(WinStatus:status, ScenarioEventEndRound:event, Float:tmDelay) {
    if(g_WarmupStarted && !get_member_game(m_bCompleteReset) && !get_member_game(m_bGameStarted)) {
        WarmUpStop();
    }
}

#if defined NOTICE_IN_CENTER_OF_SCREEN
public TaskWarmupMsg() {
    client_print(0, print_center, "Разминочный режим DeathMatch!");
}
#endif

public HC_BuyWeaponByWeaponID_Pre() {
    DisableHookChain(g_HookChain[DROP_PLAYER_ITEM_PRE]);
}

public HC_BuyWeaponByWeaponID_Post() {
    EnableHookChain(g_HookChain[DROP_PLAYER_ITEM_PRE]);
}

public HC_CBasePlayer_DropPlayerItem_Pre(const id) {
    client_print(id, print_center, /*"#Weapon_Cannot_Be_Dropped"*/"Данный предмет нельзя выбросить!");
    SetHookChainReturn(ATYPE_INTEGER, 1);
    return HC_SUPERCEDE;
}

public HC_CSGameRules_GiveC4_Pre() {
    return HC_SUPERCEDE;
}

public HC_CSGameRules_CleanUpMap_Post() {
    RemoveHostageEntity();
}

public HC_CBasePlayer_SetSpawnProtection_Post(const id) {
    SendStatusIcon(id, .icon = g_ProtectIcon, .status = STATUSICON_FLASH);
}

public HC_CBasePlayer_RemoveSpawnProtection_Post(const id) {
    SendStatusIcon(id, .icon = g_ProtectIcon, .status = STATUSICON_HIDE);
}

public HC_CBasePlayer_OnSpawnEquip_Post(const id) {
    if(is_user_connected(id)) {
        SendStatusIcon(id, .icon = g_WarmupModeIcon, .status = STATUSICON_SHOW, .red = 255, .green = 0, .blue = 0);

        if(g_Cvar[ARMOR_ONSPAWN]) {
            new ArmorType:armorType;
            if(rg_get_user_armor(id, armorType) < g_Cvar[ARMOR_ONSPAWN] || armorType != ARMOR_VESTHELM) {
                rg_set_user_armor(id, g_Cvar[ARMOR_ONSPAWN], ARMOR_VESTHELM);                                                         
            }
        }

        if(g_Cvar[FREE_WEAPON]) {
            set_member(id, m_iHideHUD, get_member(id, m_iHideHUD) | HIDEHUD_MONEY);
        }
    }
}

WarmUpStart() {
    if(!g_WarmupStarted) {
        SetCvarsValues(.valueType = NEW_VALUE);
        ToggleForwards(.enable = true);

        if(g_Cvar[FREE_WEAPON]) {
            SetAllFreeWeapon(.freeWeapon = true);
        }

    #if defined NOTICE_IN_CENTER_OF_SCREEN
        set_task_ex(2.0, "TaskWarmupMsg", .id = TASK_INDEX, .flags = SetTask_Repeat);
    #endif

        rg_round_end(
            .tmDelay = 1.5, 
            .st = WINSTATUS_DRAW, 
            .event = ROUND_GAME_COMMENCE, 
            .message = "Разминочный режим DeathMatch запущен!",
            .sentence = "", 
            .trigger = false
        );

        set_member_game(m_bCompleteReset, false);
        set_member_game(m_bGameStarted, false);

        log_amx("Warmup mode is started!");

        g_WarmupStarted = true;
    } else {
        log_amx("Warmup mode is already running!");
    }
}

WarmUpStop() {
    if(g_WarmupStarted) {
        SetCvarsValues(.valueType = OLD_VALUE);
        ToggleForwards(.enable = false);

        if(g_Cvar[FREE_WEAPON]) {
            SetAllFreeWeapon(.freeWeapon = false);

            for(new id; id <= MaxClients; id++) {
                if(is_user_connected(id)) {
                    set_member(id, m_iHideHUD, get_member(id, m_iHideHUD) & ~HIDEHUD_MONEY);
                    SendStatusIcon(id, .icon = g_WarmupModeIcon, .status = STATUSICON_HIDE);
                }
            }            
        }

        // TODO: заморозить игроков и убрать возможность стрелять до начала основной игры
        rg_round_end(1.5, WINSTATUS_DRAW, ROUND_END_DRAW, "Разминочный режим DeathMatch отключен!^rПриготовьтесь к бою, игра началась!", _, true);

        set_member_game(m_bCompleteReset, true);
        set_member_game(m_bGameStarted, true);

        log_amx("Warmup mode is finished!");

    #if defined NOTICE_IN_CENTER_OF_SCREEN
        remove_task(TASK_INDEX);
    #endif

        g_WarmupStarted = false;
        
        pause("d"); 
    }
}

SetAllFreeWeapon(bool:freeWeapon = true) {
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
            .description = "Длительность разминки (в секундах)", 
            .has_min = true, 
            .min_val = 0.0
        ),
        g_Cvar[WARMUP_TIME]
    );
    bind_pcvar_num(
        create_cvar(
            .name = "amx_warmup_free_weapon", 
            .string = "1",
            .flags = FCVAR_SERVER,
            .description = "Бесплатное оружие и патроны из стандартного меню закупки", 
            .has_min = true, 
            .min_val = 0.0,
            .has_max = true, 
            .max_val = 1.0
        ),
        g_Cvar[FREE_WEAPON]
    );
    bind_pcvar_num(
        create_cvar(
            .name = "amx_warmup_immunity_time", 
            .string = "3",
            .flags = FCVAR_SERVER,
            .description = "Время защиты игрока после возрождения (указывается в секундах, 0 - отключает защиту)", 
            .has_min = true, 
            .min_val = 0.0
        ),
        g_Cvar[IMMUNITY_TIME]
    );
    bind_pcvar_float(
        create_cvar(
            .name = "amx_warmup_respawn_time", 
            .string = "1.5",
            .flags = FCVAR_SERVER,
            .description = "Время, спустя которое игрок возрождается после смерти (в секундах)", 
            .has_min = true, 
            .min_val = 0.0
        ),
        g_Cvar[RESPAWN_TIME]
    );
    bind_pcvar_num(
        create_cvar(
            .name = "amx_warmup_armor_onspawn", 
            .string = "100",
            .flags = FCVAR_SERVER,
            .description = "Сколько брони выдавать игроку при возрождении (0 - отключить выдачу брони)", 
            .has_min = true, 
            .min_val = 0.0,
            .has_max = true, 
            .max_val = 255.0
        ),
        g_Cvar[ARMOR_ONSPAWN]
    );           
}

GetCvarsPointers() {                                          
    g_Pointer[PCVAR_FREEZETIME] = get_cvar_pointer("mp_freezetime");
    g_Pointer[PCVAR_ROUNDTIME] = get_cvar_pointer("mp_roundtime");
    g_Pointer[PCVAR_BUY_TIME] = get_cvar_pointer("mp_buytime");
    g_Pointer[PCVAR_ROUND_INFINITE] = get_cvar_pointer("mp_round_infinite");
    g_Pointer[PCVAR_FORCERESPAWN] = get_cvar_pointer("mp_forcerespawn");
    g_Pointer[PCVAR_REFILL_BPAMMO] = get_cvar_pointer("mp_refill_bpammo_weapons");
    g_Pointer[PCVAR_RESPAWN_IMMUNITYTIME] = get_cvar_pointer("mp_respawn_immunitytime");
    g_Pointer[PCVAR_ITEM_STAYTIME] = get_cvar_pointer("mp_item_staytime");
    g_Pointer[PCVAR_REFILL_BPAMMO] = get_cvar_pointer("mp_refill_bpammo_weapons");
}

SetCvarsValues(VALUE_TYPE:valueType) {
    if(valueType == NEW_VALUE) {
        g_GameCvar[NEW_VALUE][CVAR_ROUNDTIME] = float(g_Cvar[WARMUP_TIME]) / 60.0;
        g_GameCvar[NEW_VALUE][CVAR_FORCERESPAWN] = g_Cvar[RESPAWN_TIME];         
        g_GameCvar[NEW_VALUE][CVAR_FREEZETIME] = 0;
        g_GameCvar[NEW_VALUE][CVAR_BUY_TIME] = -1.0;
        g_GameCvar[NEW_VALUE][CVAR_REFILL_BPAMMO] = 1;
        g_GameCvar[NEW_VALUE][CVAR_RESPAWN_IMMUNITYTIME] = g_Cvar[IMMUNITY_TIME];
        g_GameCvar[NEW_VALUE][CVAR_ITEM_STAYTIME] = 0;
        g_GameCvar[NEW_VALUE][CVAR_REFILL_BPAMMO] = 3;
        copy(g_GameCvar[NEW_VALUE][CVAR_ROUND_INFINITE], charsmax(g_GameCvar[][CVAR_ROUND_INFINITE]), "bcdefg");

        g_GameCvar[OLD_VALUE][CVAR_ROUNDTIME] = get_pcvar_float(g_Pointer[PCVAR_ROUNDTIME]); 
        g_GameCvar[OLD_VALUE][CVAR_FORCERESPAWN] = get_pcvar_float(g_Pointer[PCVAR_FORCERESPAWN]);
        g_GameCvar[OLD_VALUE][CVAR_FREEZETIME] = get_pcvar_num(g_Pointer[PCVAR_FREEZETIME]);   
        g_GameCvar[OLD_VALUE][CVAR_BUY_TIME] = get_pcvar_float(g_Pointer[PCVAR_BUY_TIME]);
        g_GameCvar[OLD_VALUE][CVAR_REFILL_BPAMMO] = get_pcvar_num(g_Pointer[PCVAR_REFILL_BPAMMO]);
        g_GameCvar[OLD_VALUE][CVAR_RESPAWN_IMMUNITYTIME] = get_pcvar_num(g_Pointer[PCVAR_RESPAWN_IMMUNITYTIME]);
        g_GameCvar[OLD_VALUE][CVAR_ITEM_STAYTIME] = get_pcvar_num(g_Pointer[PCVAR_ITEM_STAYTIME]);
        g_GameCvar[OLD_VALUE][CVAR_REFILL_BPAMMO] = get_pcvar_num(g_Pointer[PCVAR_REFILL_BPAMMO]);
        get_pcvar_string(g_Pointer[PCVAR_ROUND_INFINITE], g_GameCvar[OLD_VALUE][CVAR_ROUND_INFINITE], charsmax(g_GameCvar[][CVAR_ROUND_INFINITE]));                 
    }

    set_pcvar_float(g_Pointer[PCVAR_ROUNDTIME], g_GameCvar[valueType][CVAR_ROUNDTIME]);
    set_pcvar_float(g_Pointer[PCVAR_FORCERESPAWN], g_GameCvar[valueType][CVAR_FORCERESPAWN]); 
    set_pcvar_num(g_Pointer[PCVAR_FREEZETIME], g_GameCvar[valueType][CVAR_FREEZETIME]);   
    set_pcvar_float(g_Pointer[PCVAR_BUY_TIME], g_GameCvar[valueType][CVAR_BUY_TIME]);
    set_pcvar_num(g_Pointer[PCVAR_REFILL_BPAMMO], g_GameCvar[valueType][CVAR_REFILL_BPAMMO]);
    set_pcvar_num(g_Pointer[PCVAR_RESPAWN_IMMUNITYTIME], g_GameCvar[valueType][CVAR_RESPAWN_IMMUNITYTIME]);
    set_pcvar_num(g_Pointer[PCVAR_ITEM_STAYTIME], g_GameCvar[valueType][CVAR_ITEM_STAYTIME]);
    set_pcvar_num(g_Pointer[PCVAR_REFILL_BPAMMO], g_GameCvar[valueType][CVAR_REFILL_BPAMMO]);
    set_pcvar_string(g_Pointer[PCVAR_ROUND_INFINITE], g_GameCvar[valueType][CVAR_ROUND_INFINITE]);
}

RegisterForwards() {
    DisableHookChain(g_HookChain[ROUND_END_POST] = RegisterHookChain(RG_RoundEnd, "HC_RoundEnd_Post", true));
    DisableHookChain(g_HookChain[DROP_PLAYER_ITEM_PRE] = RegisterHookChain(RG_CBasePlayer_DropPlayerItem, "HC_CBasePlayer_DropPlayerItem_Pre", false));
    DisableHookChain(g_HookChain[BUY_WEAPON_PRE] = RegisterHookChain(RG_BuyWeaponByWeaponID, "HC_BuyWeaponByWeaponID_Pre", false));
    DisableHookChain(g_HookChain[BUY_WEAPON_POST] = RegisterHookChain(RG_BuyWeaponByWeaponID, "HC_BuyWeaponByWeaponID_Post", true));
    DisableHookChain(g_HookChain[SET_SPAWN_PROTECT_POST] = RegisterHookChain(RG_CBasePlayer_SetSpawnProtection, "HC_CBasePlayer_SetSpawnProtection_Post", true));
    DisableHookChain(g_HookChain[REMOVE_SPAWN_PROTECT_POST] = RegisterHookChain(RG_CBasePlayer_RemoveSpawnProtection, "HC_CBasePlayer_RemoveSpawnProtection_Post", true));
    DisableHookChain(g_HookChain[ON_SPAWN_EQUIP_POST] = RegisterHookChain(RG_CBasePlayer_OnSpawnEquip, "HC_CBasePlayer_OnSpawnEquip_Post", true));
    DisableHookChain(g_HookChain[GIVEC4_PRE] = RegisterHookChain(RG_CSGameRules_GiveC4, "HC_CSGameRules_GiveC4_Pre", false));
    DisableHookChain(g_HookChain[CLEAN_UP_MAP_POST] = RegisterHookChain(RG_CSGameRules_CleanUpMap, "HC_CSGameRules_CleanUpMap_Post", true));
}

ToggleForwards(const bool:enable) {
    for(new i; i < sizeof g_HookChain; i++) {
        enable ? EnableHookChain(g_HookChain[i]) : DisableHookChain(g_HookChain[i]);
    }
}

SendStatusIcon(const index, const icon[], const status = STATUSICON_HIDE, red = 0, green = 160, blue = 0) {
    if(g_MsgIdStatusIcon) {
        message_begin(index ? MSG_ONE_UNRELIABLE : MSG_BROADCAST, g_MsgIdStatusIcon, _, index);
        write_byte(status);
        write_string(icon);
        if(status) {
            write_byte(red);
            write_byte(green);
            write_byte(blue);
        }
        message_end();
    }
}

// thanks wopox1337 for help with this code. 
RemoveHostageEntity() {
    new ent;
    while((ent = rg_find_ent_by_class(ent, "hostage_entity"))) {
        set_entvar(ent, var_health, 0);
        set_entvar(ent, var_movetype, /*MOVETYPE_NONE*/MOVETYPE_TOSS);
        //set_entvar(ent, var_flags, ~FL_ONGROUND);
        set_entvar(ent, var_solid, SOLID_NOT);
        set_entvar(ent, var_deadflag, DEAD_DEAD);
        set_entvar(ent, var_effects, EF_NODRAW);
    }
}
