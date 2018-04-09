
    get_member(iIndex, m_signals, iSignals);

    return bool:(SignalState:iSignals[US_State] & SIGNAL_BUY);   
}
#include <amxmodx>
#include <reapi>
#include <nvault_array>
       
new const PLUGIN_NAME[]    = "Vip System";
new const PLUGIN_VERSION[] = "3.2.4";
new const PLUGIN_AUTHOR[]  = "d3m37r4";

#define ADMIN_LOADER                                            // Совместимость с Admin Loader от neygomon
//#define GIVE_DEFUSEKIT_AND_ARMOR                              // Выдавать бронежилет и DefuseKit (если игрок КТ) в начале раунда
#define GIVE_GRENADES                                           // Выдавать гранаты в начале раунда
#define RESTRICT_AWP_ON_2x2_MAPS                                // Запрещать покупку awp на картах 2x2

const VIP_ACCESS        = ADMIN_LEVEL_H;        // Флаг доступа к vip-системе
const VIP_ROUND         = 3;                    // C какого раунда доступна покупка основного оружия через vip-меню 
const SPAWN_EQUIP_ROUND = 2;                    // С какого раунда выдавать аммуницию при спавне игрока
const PERCENT_DISCOUNT  = 40;                   // Скидка (указывается в процентах, выходное значение будет округлено до ближайшего десятка), на сколько дешевле будет стоить основное оружие в vip-меню
const VAULT_EXPIRE_DAYS = 180;                  // Сколько дней настройки игрока хранятся на сервере (отсчет идет с последнего посещения)
#if defined GIVE_DEFUSEKIT_AND_ARMOR 
    const ARMOR_VALUE   = 100;                  // Кол-во брони, выдаваемое игроку
#endif

enum _:PISTOL_INFO {WeaponIdType:PISTOL_ID, PISTOL_AMMO};
enum _:WEAPON_INFO {WeaponIdType:W_ID, W_AMMO, W_COST};
enum _:PLAYER_DATA {AuthId[32], Damager, Pistol, Automenu};
enum _:STATE_TYPE {STATE_DISABLED, STATE_ENABLED};
enum {PISTOL_DGL, PISTOL_USP, PISTOL_G18, PISTOL_OFF};

const MAX_PISTOLS = 3;
const MAX_ITEMS   = 5;
                                          
new const g_PistolName[MAX_PISTOLS + 1][] = {"\rDEAGLE", "\rUSP", "\rGLOCK", "\dOFF"}; 
new const g_WeaponName[MAX_ITEMS + 1][]   = {"AK47", "M4A1", "FAMAS", "GALIL", "SCOUT", "AWP"};

new const g_PistolClassNames[MAX_PISTOLS][] = {"weapon_deagle", "weapon_usp", "weapon_glock18"};
new const g_ItemClassNames[MAX_ITEMS + 1][] = {"weapon_ak47", "weapon_m4a1", "weapon_famas", "weapon_galil", "weapon_scout", "weapon_awp"};

new const g_VaultFile[]         = "vip_system_data";
new const g_MapPrefix[][]       = {"awp_", "aim_", "35hp", "fy_", "$"};
new const g_State[STATE_TYPE][] = {"\dOFF", "\rON"};

new const KEYS_MENU = MENU_KEY_1|MENU_KEY_2|MENU_KEY_3|MENU_KEY_4|MENU_KEY_5|MENU_KEY_6|MENU_KEY_7|MENU_KEY_8|MENU_KEY_9|MENU_KEY_0;

new g_Items[MAX_ITEMS + 1][WEAPON_INFO];
new g_Pistols[MAX_PISTOLS][PISTOL_INFO];
new g_aPlayerData[MAX_CLIENTS + 1][PLAYER_DATA];

new g_iCvarBuyTime, Float:g_flBuyTime;
new g_iMenuId, g_iRoundCount, g_iSyncMsgDamage;

new HookChain:g_hookOnSpawnEquip;
new bool:g_bMapsBlock, g_MapName[32];

new g_hVault = INVALID_HANDLE;

#define is_user_vip(%1)         (get_user_flags(%1) & VIP_ACCESS)

#if defined ADMIN_LOADER 
    native admin_expired(index);
#endif

public plugin_cfg()
{
    if((g_hVault = nvault_open(g_VaultFile)) == INVALID_HANDLE)
    {
        set_fail_state("[%s] Opening nVault failed!", PLUGIN_NAME);
    } else {
        nvault_prune(g_hVault, 0, get_systime() - (86400 * VAULT_EXPIRE_DAYS));
    }

    for(new i; i < sizeof g_PistolClassNames; i++)
    {
        g_Pistols[i][PISTOL_ID]   = rg_get_weapon_info(g_PistolClassNames[i], WI_ID);
        g_Pistols[i][PISTOL_AMMO] = rg_get_weapon_info(g_Pistols[i][PISTOL_ID], WI_MAX_ROUNDS);
    }

    for(new i; i < sizeof g_ItemClassNames; i++)
    {
        g_Items[i][W_ID]   = rg_get_weapon_info(g_ItemClassNames[i], WI_ID);
        g_Items[i][W_AMMO] = rg_get_weapon_info(g_Items[i][W_ID], WI_MAX_ROUNDS);
        g_Items[i][W_COST] = ((floatround(float(rg_get_weapon_info(g_Items[i][W_ID], WI_COST)) * (1.0 - float(PERCENT_DISCOUNT) / 100.0)) + 5) / 10) * 10;
    }

    get_mapname(g_MapName, charsmax(g_MapName)); 

    for(new i; i < sizeof g_MapPrefix; i++)
    {             
        if(containi(g_MapName, g_MapPrefix[i]) != -1)
        {   
            g_bMapsBlock = true;
            break;
        }
    } 

    g_iSyncMsgDamage = CreateHudSyncObj();

    g_iCvarBuyTime = get_cvar_pointer("mp_buytime");    
    bind_pcvar_float(g_iCvarBuyTime, g_flBuyTime);
}

public plugin_init()
{   
    register_plugin(PLUGIN_NAME, PLUGIN_VERSION, PLUGIN_AUTHOR);
                                
    register_clcmd("say /vipmenu", "Cmd_Menu");
    register_clcmd("say_team /vipmenu", "Cmd_Menu");
    register_clcmd("vipmenu", "Cmd_Menu");
    
    g_iMenuId = register_menuid("Menu");
    register_menucmd(g_iMenuId, KEYS_MENU, "Menu_Handler");
    
    register_event("StatusIcon", "Event_HideStatusIcon", "b", "1=0", "2=buyzone");

    RegisterHookChain(RG_CSGameRules_RestartRound, "CSGameRules_RestartRound_Pre", false);
    RegisterHookChain(RG_CBasePlayer_TakeDamage, "CBasePlayer_TakeDamage", true); 
    DisableHookChain((g_hookOnSpawnEquip = RegisterHookChain(RG_CBasePlayer_OnSpawnEquip, "CBasePlayer_OnSpawnEquip", true)));    
} 

public client_disconnected(iIndex)
    save_user_settings(iIndex);                                       

public client_putinserver(iIndex)
{
    g_aPlayerData[iIndex][AuthId][0] = 0;

    if(!is_user_vip(iIndex))
        return PLUGIN_HANDLED;
    
    get_user_authid(iIndex, g_aPlayerData[iIndex][AuthId], charsmax(g_aPlayerData[][AuthId]));

    if(nvault_get_array(g_hVault, g_aPlayerData[iIndex][AuthId], g_aPlayerData[iIndex], PLAYER_DATA) <= 0)
    {
        g_aPlayerData[iIndex][Damager] = STATE_DISABLED
        g_aPlayerData[iIndex][Pistol] = PISTOL_DGL;
        g_aPlayerData[iIndex][Automenu] = STATE_DISABLED;
    }

    return PLUGIN_HANDLED;
}
            
public CSGameRules_RestartRound_Pre()
{
    if(get_member_game(m_bCompleteReset))
    {
        g_iRoundCount = 0;
        DisableHookChain(g_hookOnSpawnEquip);
    }

    if(++g_iRoundCount >= SPAWN_EQUIP_ROUND && !g_bMapsBlock)
        EnableHookChain(g_hookOnSpawnEquip);
}

public CBasePlayer_OnSpawnEquip(const iIndex)
{ 
    if(!is_user_connected(iIndex) || !is_user_vip(iIndex))
        return HC_CONTINUE;

    new iPistolID = g_aPlayerData[iIndex][Pistol];

    if(iPistolID != PISTOL_OFF)
        UTIL_give_item(iIndex, g_PistolClassNames[iPistolID], GT_REPLACE, g_Pistols[iPistolID][PISTOL_AMMO]);

#if defined GIVE_GRENADES  
    UTIL_give_item(iIndex, "weapon_hegrenade",  GT_APPEND, 0);
    UTIL_give_item(iIndex, "weapon_flashbang",  GT_APPEND, 2);
    UTIL_give_item(iIndex, "weapon_smokegrenade", GT_APPEND, 0);
#endif

#if defined GIVE_DEFUSEKIT_AND_ARMOR
    new ArmorType:iArmorType;

    if(rg_get_user_armor(iIndex, iArmorType) < ARMOR_VALUE || iArmorType != ARMOR_VESTHELM)
        rg_set_user_armor(iIndex, min(ARMOR_VALUE, 255), ARMOR_VESTHELM);   

    if(get_member(iIndex, m_iTeam) == TEAM_CT && !get_member(iIndex, m_bHasDefuser))
        rg_give_defusekit(iIndex, true);        
#endif

    if(g_aPlayerData[iIndex][Automenu] == STATE_ENABLED)
    {
        if(g_iRoundCount >= VIP_ROUND && !get_member(iIndex, m_bHasPrimary))
            Show_Menu(iIndex, false);
    } 

    return HC_CONTINUE;             
} 

public CBasePlayer_TakeDamage(const pevVictim, pevInflictor, pevAttacker, Float:flDamage, bitsDamageType)
{
    if(!is_user_connected(pevAttacker) || !is_user_vip(pevAttacker) || g_aPlayerData[pevAttacker][Damager] == STATE_DISABLED || pevVictim == pevAttacker)
        return HC_CONTINUE;

    new dmg = floatround(flDamage, floatround_floor);

    if(GetHookChainReturn(ATYPE_INTEGER) && dmg > 0)
    {
        set_hudmessage(0, 100, 200, -1.0, 0.6, 0, 0.1, 2.5, 0.02, 0.02);
        ShowSyncHudMsg(pevAttacker, g_iSyncMsgDamage, "%d", dmg);
    }

    return HC_CONTINUE;
}             

public Cmd_Menu(iIndex)
    return Show_Menu(iIndex);

Show_Menu(iIndex, bool:iCheckBuyZone = true)
{
    if(!is_allow_use(iIndex, iCheckBuyZone))     
        return PLUGIN_HANDLED;

    new szMenu[512], iLen;

    iLen = formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\w[\rVipMenu\w] Меню VIP-Игрока^n");

#if defined ADMIN_LOADER
    new iExp = admin_expired(iIndex);
    if(iExp > 0)
    {
        new iSysTime = get_systime();

        if(iExp - iSysTime > 0)
        {
            new iTimeInDay = (iExp - iSysTime) / 86400;

            if(iTimeInDay > 0)
            {
                iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "Привелегия действует: еще \r%d \wдн.^n", iTimeInDay);
            } else {
                iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "Привелегия действует: \rпоследний день^n");
            }
        }
    } else if(iExp == 0) {
        iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "Привелегия действует: \rбессрочно^n");
    }
#endif

    iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\R\%sЦена $^n", (VIP_ROUND > g_iRoundCount) ? "d" : "y");

    for(new i; i < sizeof g_ItemClassNames; i++)
    	iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, (VIP_ROUND > g_iRoundCount) ? "\d%d. Купить %s\R%d^n" : "\r%d. \wКупить \r%s\R\y%d^n", i + 1, g_WeaponName[i], g_Items[i][W_COST]);

    iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "^n");
    iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r7. \wПистолет [%s\w]^n", g_PistolName[g_aPlayerData[iIndex][Pistol]]);
    iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r8. \wДамагер [%s\w]^n", g_State[g_aPlayerData[iIndex][Damager]]);
    iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r9. \wАвтооткрытие меню [%s\w]^n^n", g_State[g_aPlayerData[iIndex][Automenu]]); 

    formatex(szMenu[iLen], charsmax(szMenu), "\r0. \wВыход");

    show_menu(iIndex, KEYS_MENU, szMenu, -1, "Menu");

    return PLUGIN_HANDLED;             
}

public Menu_Handler(iIndex, iKey)
{
    new iPlayerMoney, iPistolID;

    switch(iKey)
    {     
        case 6:
        {
            switch(g_aPlayerData[iIndex][Pistol])
            {
                case PISTOL_DGL: g_aPlayerData[iIndex][Pistol] = PISTOL_OFF;
                case PISTOL_USP: g_aPlayerData[iIndex][Pistol] = PISTOL_G18;
                case PISTOL_G18: g_aPlayerData[iIndex][Pistol] = PISTOL_DGL;
                case PISTOL_OFF: g_aPlayerData[iIndex][Pistol] = PISTOL_USP;
            }

            iPistolID = g_aPlayerData[iIndex][Pistol];

            if(g_iRoundCount >= SPAWN_EQUIP_ROUND && iPistolID != PISTOL_OFF)
            {
                UTIL_give_item(iIndex, g_PistolClassNames[iPistolID], GT_REPLACE, g_Pistols[iPistolID][PISTOL_AMMO]);
            } else if(iPistolID == PISTOL_OFF) {
                switch(get_member(iIndex, m_iTeam))
                {
                    case TEAM_TERRORIST: UTIL_give_item(iIndex, g_PistolClassNames[PISTOL_G18], GT_REPLACE, g_Pistols[PISTOL_G18][PISTOL_AMMO]);
                    case TEAM_CT: UTIL_give_item(iIndex, g_PistolClassNames[PISTOL_USP], GT_REPLACE, g_Pistols[PISTOL_USP][PISTOL_AMMO]);
                }
            }
        }
        case 7:
        {
            switch(g_aPlayerData[iIndex][Damager])
            {
                case STATE_DISABLED: 
                {
                    g_aPlayerData[iIndex][Damager] = STATE_ENABLED;
                    client_print(iIndex, print_center, "Показ нанесенного урона включен!");
                }
                case STATE_ENABLED: 
                {
                    g_aPlayerData[iIndex][Damager] = STATE_DISABLED;
                    client_print(iIndex, print_center, "Показ нанесенного урона отключен!");
                }
            }
        }
        case 8:
        {
            switch(g_aPlayerData[iIndex][Automenu])
            {
                case STATE_DISABLED: 
                {
                    g_aPlayerData[iIndex][Automenu]= STATE_ENABLED;
                    client_print(iIndex, print_center, "Автооткрытие меню включено!");
                }
                case STATE_ENABLED: 
                {
                    g_aPlayerData[iIndex][Automenu] = STATE_DISABLED;
                    client_print(iIndex, print_center, "Автооткрытие меню отключено!");
                }
            }
        }
    }

    if(iKey <= charsmax(g_ItemClassNames)) 
    {
        if(g_iRoundCount == 0)
        {
            client_print(iIndex, print_center, "Основное оружие доступно с %d-го раунда!^rСейчас идет разминочный раунд.", VIP_ROUND);
            return Show_Menu(iIndex);
        } else if(VIP_ROUND > g_iRoundCount) {
            client_print(iIndex, print_center, "Основное оружие доступно с %d-го раунда!^rСейчас идет %d-й раунд.", VIP_ROUND, g_iRoundCount);
            return Show_Menu(iIndex);                               
        }

    #if defined RESTRICT_AWP_ON_2x2_MAPS
        if(equali(g_ItemClassNames[iKey], "weapon_awp"))
        {
            if(containi(g_MapName, "2x2") != -1)
            {
                client_print(iIndex, print_center, "Данное оружие недоступно на текущей карте!");
                return Show_Menu(iIndex);
            }
        }
    #endif

        iPlayerMoney = get_member(iIndex, m_iAccount);

        if(iPlayerMoney < g_Items[iKey][W_COST])
        {
            client_print(iIndex, print_center, "Недостаточно средств для покупки данного предмета!");
            return Show_Menu(iIndex);
        }

        UTIL_give_item(iIndex, g_ItemClassNames[iKey], GT_REPLACE, g_Items[iKey][W_AMMO]);
        rg_add_account(iIndex, iPlayerMoney - g_Items[iKey][W_COST], AS_SET);
    } else {
        if(iKey != 9) 
            Show_Menu(iIndex);

        save_user_settings(iIndex);
    }

    return PLUGIN_HANDLED;    
} 

public Event_HideStatusIcon(iIndex)
{
    new iViewMenu, iMenuKey;  

    if(get_user_menu (iIndex, iViewMenu, iMenuKey) == 1 && iViewMenu == g_iMenuId)
        show_menu(iIndex, 0, "^n", 1);
}

save_user_settings(iIndex)
{
    if(g_aPlayerData[iIndex][AuthId][0] > 0)
        nvault_set_array(g_hVault, g_aPlayerData[iIndex][AuthId], g_aPlayerData[iIndex], PLAYER_DATA);
}

public plugin_end() 
{
    if(g_hVault != INVALID_HANDLE)
        nvault_close(g_hVault);
}

bool:is_allow_use(iIndex, bool:iCheckBuyZone)
{
    if(!is_user_alive(iIndex))
    {
        client_print_color(iIndex, 0, "[Server] Данная команда доступна только для живых игроков!");
        return false;
    }

    if(!is_user_vip(iIndex))
    {
        client_print_color(iIndex, 0, "[Server] Только Vip-игрок может воспользоваться данной командой!");
        return false;
    }   

    if(g_bMapsBlock)
    {                
        client_print_color(iIndex, 0, "[Server] Данная команда недоступна на текущей карте!");
        return false;
    }

    if(iCheckBuyZone && !UTIL_user_in_buyzone(iIndex))
    {
        client_print(iIndex, print_center, "Вы должны находиться в зоне закупки!");
        return false;
    } 

    if(g_flBuyTime == 0.0 || (get_gametime() - Float: get_member_game(m_fRoundStartTime) > (g_flBuyTime * 60)))
    {  
        client_print(iIndex, print_center, "%0.0f секунд истекли.^rПокупка экипировки запрещена!", g_flBuyTime * 60);
        return false;                                         
    }  

    return true;                                                                                                           
}

stock UTIL_give_item(const iIndex, const iWeapon[], GiveType:GtState, iAmmount)
{
    rg_give_item(iIndex, iWeapon, GtState);

    if(iAmmount)
        rg_set_user_bpammo(iIndex, rg_get_weapon_info(iWeapon, WI_ID), iAmmount);
}

stock bool:UTIL_user_in_buyzone(const iIndex)
{
    new iSignals[UnifiedSignals];

    get_member(iIndex, m_signals, iSignals);

    return bool:(SignalState:iSignals[US_State] & SIGNAL_BUY);   
}
