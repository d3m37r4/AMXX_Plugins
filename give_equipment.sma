#include <amxmodx>
#include <reapi>                         

const ARMOR_VALUE = 100;	// Сколько выдавать игроку AP.

public plugin_init()
{
    register_plugin("Give Equipment", "1.4", "d3m37r4");

    RegisterHookChain(RG_CBasePlayer_OnSpawnEquip, "CBasePlayer_OnSpawnEquip", true); 
}

public CBasePlayer_OnSpawnEquip(const iIndex, bool:addDefault, bool:equipGame) 
{
	new ArmorType:iArmorType;

	if(rg_get_user_armor(iIndex, iArmorType) < ARMOR_VALUE || iArmorType != ARMOR_VESTHELM)
		rg_set_user_armor(iIndex, min(ARMOR_VALUE, 255), ARMOR_VESTHELM);                            

	if(get_member(iIndex, m_iTeam) == TEAM_CT && !get_member(iIndex, m_bHasDefuser))
		rg_give_defusekit(iIndex, true);                               
}