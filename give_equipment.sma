#include <amxmodx>
#include <reapi>                         

public plugin_init()
{
    register_plugin("Give Equipment", "1.2", "d3m37r4");

    RegisterHookChain(RG_CBasePlayer_Spawn, "CBasePlayer_Spawn", true); 
}

public CBasePlayer_Spawn(iIndex) 
{
	if(!is_user_alive(iIndex))
		return HC_CONTINUE;

	new ArmorType:iArmorType;
	new iArmor = rg_get_user_armor(iIndex, iArmorType); 
	new TeamName:iTeam = get_member(iIndex, m_iTeam); 
        
	if(iArmor < 100 || iArmorType != ARMOR_VESTHELM)                   
		rg_set_user_armor(iIndex, 100, ARMOR_VESTHELM);                   

	new bool:bUserHasDefuser = get_member(iIndex, m_bHasDefuser);

	if(iTeam == TEAM_CT && !bUserHasDefuser) 
		rg_give_defusekit(iIndex, true);                                

	return HC_CONTINUE;
}
