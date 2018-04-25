#include <amxmodx>
#tryinclude <reapi>                       

const ARMOR_VALUE = 100;    // Сколько выдавать игроку AP.

#if !defined _reapi_included
    #include <cstrike>
    #include <hamsandwich>

    #define ArmorType 				CsArmorType
    #define ARMOR_VESTHELM			CS_ARMOR_VESTHELM
    #define TEAM_CT					CS_TEAM_CT
    #define HC_CONTINUE				HAM_IGNORED

    new bool:g_bMapHasBombZone  	= false;                                
#endif

#if !defined NULLENT
    const NULLENT = -1;
#endif

public plugin_init()
{
    register_plugin("Give Equipment", "1.5", "d3m37r4");

#if !defined _reapi_included
    RegisterHam(Ham_Spawn, "player", "CBasePlayer_Spawn_Post", true);

    if(cs_find_ent_by_class(NULLENT, "func_bomb_target") || cs_find_ent_by_class(NULLENT, "info_bomb_target"))
        g_bMapHasBombZone = true;
#else
    RegisterHookChain(RG_CBasePlayer_OnSpawnEquip, "CBasePlayer_OnSpawnEquip", true);
#endif
}

#if !defined _reapi_included
public CBasePlayer_Spawn_Post(const iIndex)
#else
public CBasePlayer_OnSpawnEquip(const iIndex, bool:addDefault, bool:equipGame)
#endif
{
    if(!is_user_connected(iIndex))
        return HC_CONTINUE;

    new ArmorType:iArmorType;

#if !defined _reapi_included
    if(cs_get_user_armor(iIndex, iArmorType) < ARMOR_VALUE || iArmorType != ARMOR_VESTHELM)
        cs_set_user_armor(iIndex, min(ARMOR_VALUE, 255), ARMOR_VESTHELM);                            

    if(g_bMapHasBombZone)
    {
        if(cs_get_user_team(iIndex) == TEAM_CT && !cs_get_user_defuse(iIndex))
            cs_set_user_defuse(iIndex, 1, 0, 160, 0, _, 0);
    }
#else
    if(rg_get_user_armor(iIndex, iArmorType) < ARMOR_VALUE || iArmorType != ARMOR_VESTHELM)
        rg_set_user_armor(iIndex, min(ARMOR_VALUE, 255), ARMOR_VESTHELM);

    if(get_member(iIndex, m_iTeam) == TEAM_CT && !get_member(iIndex, m_bHasDefuser))
        rg_give_defusekit(iIndex, true);                        
#endif

    return HC_CONTINUE;
}
