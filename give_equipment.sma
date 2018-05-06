#include <amxmodx>
#tryinclude <reapi>

#if defined _reapi_included
    #define cs_get_user_team(%1)            get_member(iIndex, m_iTeam)
    #define cs_get_user_defuse(%1)          get_member(iIndex, m_bHasDefuser)
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
new g_pcvEquipRound, g_pcvArmorValue;
new g_iRoundCount;

public plugin_init()
{
    register_plugin("Give Equipment", "1.6", "d3m37r4");

    DisableHookChain((g_hookOnSpawnEquip = RegisterHookChain(RG_CBasePlayer_OnSpawnEquip, "CBasePlayer_OnSpawnEquip", true))); 

#if defined _reapi_included
    RegisterHookChain(RG_CSGameRules_RestartRound, "CSGameRules_RestartRound", false);
#else
    register_event("TextMsg", "EventRestartRound", "a", "2=#Game_will_restart_in", "2=#Game_Commencing");
    register_event("HLTV", "EventRoundStart", "a", "1=0", "2=0");

    g_bMapHasBombZone = bool:(cs_find_ent_by_class(NULLENT, "func_bomb_target") || cs_find_ent_by_class(NULLENT, "info_bomb_target"));
#endif

    g_pcvEquipRound = register_cvar("amx_equip_round", "2");
    g_pcvArmorValue = register_cvar("amx_armor_value", "100"); 
}

#if defined _reapi_included
public CSGameRules_RestartRound()
{
    if(get_member_game(m_bCompleteReset))
    {
        g_iRoundCount = 0;
        DisableHookChain(g_hookOnSpawnEquip);
    }

    if(++g_iRoundCount >= get_pcvar_num(g_pcvEquipRound))
        EnableHookChain(g_hookOnSpawnEquip);
}
#else
public EventRestartRound()
{
    g_iRoundCount = 0;
    DisableHookChain(g_hookOnSpawnEquip);
}

public EventRoundStart()
{
    if(++g_iRoundCount >= get_pcvar_num(g_pcvEquipRound))
        EnableHookChain(g_hookOnSpawnEquip);
}
#endif

public CBasePlayer_OnSpawnEquip(const iIndex)
{
    if(!is_user_connected(iIndex))
        return HC_CONTINUE;

    new ArmorType:iArmorType, iArmorValue = get_pcvar_num(g_pcvArmorValue);

    if(rg_get_user_armor(iIndex, iArmorType) < iArmorValue || iArmorType != ARMOR_VESTHELM)
        rg_set_user_armor(iIndex, min(iArmorValue, 255), ARMOR_VESTHELM);

#if !defined _reapi_included
    if(!g_bMapHasBombZone)
        return HC_CONTINUE;
#endif

    if(cs_get_user_team(iIndex) == TEAM_CT && !cs_get_user_defuse(iIndex))
        rg_give_defusekit(iIndex, true);

    return HC_CONTINUE;
}
