#include <amxmodx>
#tryinclude <reapi>

const ARMOR_VALUE = 100;    // Сколько выдавать игроку AP.

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
    #define RegisterHookChain               RegisterHam
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

public plugin_init()
{
    register_plugin("Give Equipment", "1.5.1", "d3m37r4");

    RegisterHookChain(RG_CBasePlayer_OnSpawnEquip, "CBasePlayer_OnSpawnEquip", true);

#if !defined _reapi_included
    g_bMapHasBombZone = bool:(cs_find_ent_by_class(NULLENT, "func_bomb_target") || cs_find_ent_by_class(NULLENT, "info_bomb_target"));
#endif 
}

public CBasePlayer_OnSpawnEquip(const iIndex)
{
    if(!is_user_connected(iIndex))
        return HC_CONTINUE;

    new ArmorType:iArmorType;

    if(rg_get_user_armor(iIndex, iArmorType) < ARMOR_VALUE || iArmorType != ARMOR_VESTHELM)
        rg_set_user_armor(iIndex, min(ARMOR_VALUE, 255), ARMOR_VESTHELM);

#if !defined _reapi_included
    if(!g_bMapHasBombZone)
        return HC_CONTINUE;
#endif

    if(cs_get_user_team(iIndex) == TEAM_CT && !cs_get_user_defuse(iIndex))
        rg_give_defusekit(iIndex, true);

    return HC_CONTINUE;
}
