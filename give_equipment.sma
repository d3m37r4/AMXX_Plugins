#include <amxmodx>
#tryinclude <reapi>

#if defined _reapi_included
    #define cs_get_user_team(%1)            get_member(%1, m_iTeam)
    #define cs_get_user_defuse(%1)          get_member(%1, m_bHasDefuser)
#endif

#if !defined _reapi_included
    #include <cstrike>
    #include <hamsandwich>

    #define ArmorType                       CsArmorType
    #define ARMOR_VESTHELM                  CS_ARMOR_VESTHELM
    #define TEAM_CT                         CS_TEAM_CT
    #define HookChain                       HamHook
    #define RegisterHookChain               RegisterHam
    #define EnableHookChain                 EnableHamForward
    #define DisableHookChain                DisableHamForward
    #define RG_CBasePlayer_OnSpawnEquip     Ham_Spawn, "player"
    #define HC_CONTINUE                     HAM_IGNORED
    #define rg_get_user_armor               cs_get_user_armor
    #define rg_set_user_armor               cs_set_user_armor
    #define rg_give_defusekit               cs_set_user_defuse

    new bool:g_bMapHasBombZone = false;

    #if !defined cs_find_ent_by_class
        #include <engine>
        #define cs_find_ent_by_class        find_ent_by_class
    #endif
#endif

#if !defined NULLENT
    const NULLENT = -1;
#endif

new HookChain:g_hookOnSpawnEquip;
new g_iEquipRound, g_iArmorValue, g_iRoundCount;

public plugin_init() {
    register_plugin("Give Equipment", "1.6.1", "d3m37r4");

    DisableHookChain(g_hookOnSpawnEquip = RegisterHookChain(RG_CBasePlayer_OnSpawnEquip, "CBasePlayer_OnSpawnEquip", true)); 

#if defined _reapi_included
    RegisterHookChain(RG_CSGameRules_RestartRound, "CSGameRules_RestartRound", false);
#else
    register_event("TextMsg", "EventRestartRound", "a", "2=#Game_will_restart_in", "2=#Game_Commencing");
    register_event("HLTV", "EventRoundStart", "a", "1=0", "2=0");

    g_bMapHasBombZone = bool:(cs_find_ent_by_class(NULLENT, "func_bomb_target") || cs_find_ent_by_class(NULLENT, "info_bomb_target"));
#endif

    bind_pcvar_num(
        create_cvar(
            .name = "amx_equip_round", 
            .string = "2", 
            .description = "С какого раунда выдается броня и дефьюзкит.",
            .has_min = true, 
            .min_val = 0.0
        ), 
        g_iEquipRound
    );
    bind_pcvar_num(
        create_cvar(
            .name = "amx_armor_value", 
            .string = "100", 
            .description = "Кол-во выдаваемой брони (0 - откл. выдачу, 255 - макс. значение).", 
            .has_min = true, 
            .min_val = 0.0, 
            .has_max = true, 
            .max_val = 255.0
        ), 
        g_iArmorValue
    );
}

#if defined _reapi_included
public CSGameRules_RestartRound() {
    if(get_member_game(m_bCompleteReset)) {
        g_iRoundCount = 0;
        DisableHookChain(g_hookOnSpawnEquip);
    }

    if(++g_iRoundCount >= g_iEquipRound)
        EnableHookChain(g_hookOnSpawnEquip);
}
#else
public EventRestartRound() {
    g_iRoundCount = 0;
    DisableHookChain(g_hookOnSpawnEquip);
}

public EventRoundStart() {
    if(++g_iRoundCount >= g_iEquipRound)
        EnableHookChain(g_hookOnSpawnEquip);
}
#endif

public CBasePlayer_OnSpawnEquip(const iIndex) {
    if(!is_user_connected(iIndex))
        return HC_CONTINUE;

    if(g_iArmorValue) {
        new ArmorType:iArmorType;
        if(rg_get_user_armor(iIndex, iArmorType) < g_iArmorValue || iArmorType != ARMOR_VESTHELM)
            rg_set_user_armor(iIndex, g_iArmorValue, ARMOR_VESTHELM);
    }
#if !defined _reapi_included
    if(!g_bMapHasBombZone)
        return HC_CONTINUE;
#endif

    if(cs_get_user_team(iIndex) == TEAM_CT && !cs_get_user_defuse(iIndex))
        rg_give_defusekit(iIndex, true);

    return HC_CONTINUE;
}
