#include <amxmodx>
#include <reapi>                         

#define is_valid_player(%1)      (1 <= (%1) <= g_iMaxPlayers)

new g_iMaxPlayers;
new bool:g_bMapHasBombZone;

public plugin_init()
{
    register_plugin("Give Equipment", "1.1", "d3m37r4");

    RegisterHookChain(RG_CBasePlayer_Spawn, "CBasePlayer_Spawn", true); 

    g_bMapHasBombZone = get_member_game(m_bMapHasBombZone);
    g_iMaxPlayers = get_maxplayers();
}

public CBasePlayer_Spawn(iIndex) 
{
	if(!is_valid_player(iIndex))
		return HC_CONTINUE;

	new ArmorType:iArmorType;
	new iArmor = rg_get_user_armor(iIndex, iArmorType); 
	new TeamName:iTeam = get_member(iIndex, m_iTeam); 
        
	if(iArmor < 100 || iArmorType != ARMOR_VESTHELM)                   
		rg_set_user_armor(iIndex, 100, ARMOR_VESTHELM);                   

	new bool:bUserHasDefuser = get_member(iIndex, m_bHasDefuser);

	if(g_bMapHasBombZone)
	{
		if(iTeam == TEAM_CT && !bUserHasDefuser) 
			rg_give_defusekit (iIndex, true);                                
	}

	return HC_CONTINUE;
}

