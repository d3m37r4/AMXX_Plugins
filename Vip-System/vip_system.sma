#include <amxmodx>
#include <reapi>
#include <nvault_array>

#if AMXX_VERSION_NUM < 183           
    #include <colorchat>
    #define client_disconnected         client_disconnect   
#endif                                                      

#define VIP_ACCESS                      ADMIN_LEVEL_H           // Флаг доступа к vip-системе                 
#define VIP_ROUND                       3                       // C какого раунда доступно vip-меню                 
#define ADMIN_LOADER                                            // Совместимость с Admin Loader от neygomon
//#define GIVE_DEFUSEKIT_AND_ARMOR                              // Выдавать бронежилет и DefuseKit (если игрок КТ) каждый раунд  
#define GIVE_GRENADES                                           // Выдавать гранаты каждый раунд 
#define VAULT_EXPIRE_DAYS                60                     // Через сколько дней удалить настройку (если игрок не заходил)

#if defined ADMIN_LOADER 
    native admin_expired(index);
#endif               
       
enum player_s { AuthId[32], Damager, Pistol, Automenu };
enum { STATE_DISABLED, STATE_ENABLED };
enum { PISTOL_DGL, PISTOL_USP, PISTOL_G18 };

new g_aPlayerData[MAX_CLIENTS + 1][player_s];
new g_hVault = INVALID_HANDLE;
new const VAULT_FILE[] = "vipmenu_data";
                                          
new bool:g_bUseWeapon[MAX_CLIENTS + 1];

new g_iCvarBuyTime, Float: g_flBuyTime;
new g_bRoundCount; 

new g_bMapName[32], bool:g_bMapsBlock;
new const g_iMapPrefix[][] = { "awp_", "aim_", "35hp", "fy_", "$" };

new g_bMenuId;
new const KEYS_MENU = MENU_KEY_1|MENU_KEY_2|MENU_KEY_3|MENU_KEY_4|MENU_KEY_5|MENU_KEY_6|MENU_KEY_7|MENU_KEY_8|MENU_KEY_0;

new g_bMaxPlayers, g_bSyncMsgDamage;

#define is_valid_player(%1)      (1 <= (%1) <= g_bMaxPlayers)
#define is_user_vip(%1)          (get_user_flags(%1) & VIP_ACCESS)

public plugin_end() 
{
    if(g_hVault != INVALID_HANDLE)
        nvault_close(g_hVault);
}

public plugin_cfg()
{
    if((g_hVault = nvault_open(VAULT_FILE)) == INVALID_HANDLE)
    {
        set_fail_state("[VIP SYSTEM] ERROR: Opening nVault failed!");
    } else {
        nvault_prune(g_hVault, 0, get_systime() - (86400 * VAULT_EXPIRE_DAYS));
    }
}

public plugin_init()
{   
    register_plugin("Vip System", "2.7.5", "d3m37r4");
                                
    register_clcmd("say /vipmenu", "Cmd_Menu");
    register_clcmd("say_team /vipmenu", "Cmd_Menu");
    register_clcmd("vipmenu", "Cmd_Menu");
    
    g_bMenuId = register_menuid("Menu");
    register_menucmd(g_bMenuId, KEYS_MENU, "Menu_Handler");
    
    register_event("StatusIcon", "Event_HideStatusIcon", "b", "1=0", "2=buyzone");

    RegisterHookChain(RG_CSGameRules_RestartRound, "CSGameRules_RestartRound_Pre", false);
    RegisterHookChain(RG_CBasePlayer_TakeDamage, "CBasePlayer_TakeDamage", true); 

    if(!g_bMapsBlock) RegisterHookChain(RG_CBasePlayer_Spawn, "CBasePlayer_Spawn", true); 
    
    g_iCvarBuyTime   = get_cvar_pointer("mp_buytime");
    g_flBuyTime      = get_pcvar_float(g_iCvarBuyTime);
    g_bSyncMsgDamage = CreateHudSyncObj();
    g_bMaxPlayers    = get_maxplayers();
    
    get_mapname(g_bMapName, charsmax(g_bMapName));    
    for(new i; i < sizeof g_iMapPrefix; i ++)
    {             
        if(containi(g_bMapName, g_iMapPrefix[i]) != -1)
        {   
            g_bMapsBlock = true;
            break;
        }
    }     
} 

public client_disconnected(pClient)
    SaveUserInfo(pClient);                                       

public client_putinserver(pClient)
{
    g_aPlayerData[pClient][AuthId][0] = 0;

    if(!is_user_vip(pClient))
        return;
    
    get_user_authid(pClient, g_aPlayerData[pClient][AuthId], charsmax(g_aPlayerData[][AuthId]));

    if(nvault_get_array(g_hVault, g_aPlayerData[pClient][AuthId], g_aPlayerData[pClient], player_s) <= 0)
    {
        g_aPlayerData[pClient][Damager] = STATE_DISABLED
        g_aPlayerData[pClient][Pistol] = PISTOL_DGL;
        g_aPlayerData[pClient][Automenu] = STATE_DISABLED;
    }
}
            
public CSGameRules_RestartRound_Pre()
{
    arrayset(g_bUseWeapon, false, sizeof(g_bUseWeapon));

    if(get_member_game(m_bCompleteReset))
        g_bRoundCount = 0;

    g_bRoundCount++;                                                                          
} 

public CBasePlayer_Spawn(const pPlayer)
{ 
    if(is_bonus_spawn(pPlayer))
    {
        switch(g_aPlayerData[pPlayer][Pistol])
        {
            case PISTOL_DGL: 
            {
                rg_give_item(pPlayer, "weapon_deagle", GT_REPLACE);
                rg_set_user_bpammo(pPlayer, WEAPON_DEAGLE, 35);
            }
            case PISTOL_USP:
            {
                rg_give_item(pPlayer, "weapon_usp", GT_REPLACE);
                rg_set_user_bpammo(pPlayer, WEAPON_USP, 100);
            }
            case PISTOL_G18: 
            {
                rg_give_item(pPlayer, "weapon_glock18", GT_REPLACE);
                rg_set_user_bpammo(pPlayer, WEAPON_GLOCK18, 120);
            }
        }
#if defined GIVE_GRENADES    
        rg_give_item(pPlayer, "weapon_hegrenade", GT_APPEND);
        rg_give_item(pPlayer, "weapon_flashbang", GT_APPEND);  
        rg_set_user_bpammo(pPlayer, WEAPON_FLASHBANG, 2);
        rg_give_item(pPlayer, "weapon_smokegrenade", GT_APPEND);
#endif    
#if defined GIVE_DEFUSEKIT_AND_ARMOR    
        rg_set_user_armor(pPlayer, 100, ARMOR_VESTHELM);

        new bool:bUserHasDefuser = get_member(pPlayer, m_bHasDefuser);
        new TeamName:iTeam = get_member(pPlayer, m_iTeam); 

        if(iTeam == TEAM_CT && !bUserHasDefuser)
            rg_give_defusekit (pPlayer, true);        
#endif
        if(g_aPlayerData[pPlayer][Automenu] == STATE_ENABLED)
        {
            if(VIP_ROUND <= g_bRoundCount && !get_member(pPlayer, m_bHasPrimary))
                Show_Menu(pPlayer, false);
        }              
    }
} 

public CBasePlayer_TakeDamage(const pevVictim, pevInflictor, pevAttacker, Float: flDamage, bitsDamageType)
{
    if(!is_valid_player(pevAttacker) || !is_user_vip(pevAttacker) || g_aPlayerData[pevAttacker][Damager] == STATE_DISABLED || pevVictim == pevAttacker)
        return HC_CONTINUE;

    if(GetHookChainReturn(ATYPE_INTEGER) && flDamage > 0.0)
    {
        set_hudmessage(0, 100, 200, -1.0, 0.6, 0, 0.1, 2.5, 0.02, 0.02);
        ShowSyncHudMsg(pevAttacker, g_bSyncMsgDamage, "%.0f", flDamage);
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

    static const szPistolText[PISTOL_G18 + 1][] = { "DEAGLE", "USP", "GLOCK" }; 
    static const szStateText[STATE_ENABLED + 1][] = { "\dOFF", "\rON" };

#if defined ADMIN_LOADER
    new iExp = admin_expired(iIndex);
    if(iExp > 0)
    {
        new iSysTime = get_systime();

        if(iExp - iSysTime > 0)
        {
            if((iExp - iSysTime) / 86400 > 0)
            {
                iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\wПривелегия действует: еще \r%d \wдн.^n", ((iExp - iSysTime) / 86400));
            } else {
                iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\wПривелегия действует: \rпоследний день^n");
            }
        }
    } else if(iExp == 0) {
        iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\wПривелегия действует: \rбессрочно^n");
    }
#endif 

    iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "^n");

    if(VIP_ROUND > g_bRoundCount || g_bUseWeapon[iIndex])
    {
        iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\d1. Взять AK47^n");
        iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\d2. Взять M4A1^n");
        iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\d3. Взять FAMAS^n");
        iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\d4. Взять SCOUT^n");
        iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\d5. Взять AWP^n^n");
    } else {
        iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r1. \wВзять AK47^n");
        iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r2. \wВзять M4A1^n");
        iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r3. \wВзять FAMAS^n");
        iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r4. \wВзять SCOUT^n");
        iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r5. \wВзять AWP^n^n");    
    }

    iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r6. \wПистолет \w[\r%s\w]^n", szPistolText[g_aPlayerData[iIndex][Pistol]]);
    iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r7. \wДамагер \w[%s\w]^n", szStateText[g_aPlayerData[iIndex][Damager]]);
    iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r8. \wАвтооткрытие меню \w[%s\w]^n^n", szStateText[g_aPlayerData[iIndex][Automenu]]); 

    iLen += formatex(szMenu[iLen], charsmax(szMenu) - iLen, "\r0. \wВыход");
         
    show_menu(iIndex, KEYS_MENU, szMenu, -1, "Menu");

    return PLUGIN_HANDLED;             
}

public Menu_Handler(iIndex, iKey)
{
    if(VIP_ROUND > g_bRoundCount)
    {
        if(iKey <= 4) 
        {
            if(g_bRoundCount == 0)
            {
                client_print(iIndex, print_center, "Основное оружие доступно с %d-го раунда!^rСейчас идет разминочный раунд.", VIP_ROUND);  
            } else {
                client_print(iIndex, print_center, "Основное оружие доступно с %d-го раунда!^rСейчас идет %d-й раунд.", VIP_ROUND, g_bRoundCount);                                 
            }

            return Show_Menu(iIndex);
        }    
    } else {
        if(iKey <= 4 && g_bUseWeapon[iIndex]) 
        {
            client_print(iIndex, print_center, "Вы уже воспользовались основным оружием из Vip-меню в текущем раунде!");

            return Show_Menu(iIndex);
        }       
    }

    switch(iKey)
    {
        case 0:
        {
            rg_give_item(iIndex, "weapon_ak47", GT_REPLACE);
            rg_set_user_bpammo(iIndex, WEAPON_AK47, 90); 
        }
        case 1:
        {
            rg_give_item(iIndex, "weapon_m4a1", GT_REPLACE);
            rg_set_user_bpammo(iIndex, WEAPON_M4A1, 90); 
        }
        case 2:
        {
            rg_give_item(iIndex, "weapon_famas", GT_REPLACE);
            rg_set_user_bpammo(iIndex, WEAPON_FAMAS, 90); 
        }
        case 3:
        {
            rg_give_item(iIndex, "weapon_scout", GT_REPLACE);
            rg_set_user_bpammo(iIndex, WEAPON_SCOUT, 90);
        }
        case 4:
        {
            if(containi(g_bMapName, "2x2") != -1)
            { 
                client_print(iIndex, print_center, "Вы не можете взять данное оружие на текущей карте!");

                return Show_Menu(iIndex);
            } else {
                rg_give_item(iIndex, "weapon_awp", GT_REPLACE);
                rg_set_user_bpammo(iIndex, WEAPON_AWP, 30);     
            }
        }       
        case 5:
        {
            switch(g_aPlayerData[iIndex][Pistol])
            {
                case PISTOL_DGL: 
                {
                    rg_give_item(iIndex, "weapon_usp", GT_REPLACE);
                    rg_set_user_bpammo(iIndex, WEAPON_USP, 100);                    
                    g_aPlayerData[iIndex][Pistol] = PISTOL_USP;
                }
                case PISTOL_USP:
                {
                    rg_give_item(iIndex, "weapon_glock18", GT_REPLACE);
                    rg_set_user_bpammo(iIndex, WEAPON_GLOCK18, 120);
                    g_aPlayerData[iIndex][Pistol] = PISTOL_G18;
                }
                case PISTOL_G18: 
                {
                    rg_give_item(iIndex, "weapon_deagle", GT_REPLACE);
                    rg_set_user_bpammo(iIndex, WEAPON_DEAGLE, 35);
                    g_aPlayerData[iIndex][Pistol] = PISTOL_DGL;
                }
            } 

            Show_Menu(iIndex);
        }
        case 6:
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

            Show_Menu(iIndex);
        }
        case 7:
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

            Show_Menu(iIndex);
        }
    }

    if(iKey <= 4)
        g_bUseWeapon[iIndex] = true;

    if(iKey > 4)
        SaveUserInfo(iIndex);

    return PLUGIN_HANDLED;    
} 

public Event_HideStatusIcon(iIndex)
{
    new iViewMenu, iMenuKey;  

    if(get_user_menu (iIndex, iViewMenu, iMenuKey) == 1 && iViewMenu == g_bMenuId)
        show_menu(iIndex, 0, "^n", 1);
}

SaveUserInfo(pPlayer)
{
    if(g_aPlayerData[pPlayer][AuthId][0] > 0)
        nvault_set_array(g_hVault, g_aPlayerData[pPlayer][AuthId], g_aPlayerData[pPlayer], player_s);
}

bool:is_bonus_spawn(iIndex)
{
    if(!is_user_alive(iIndex))
        return false;

    if(!is_user_vip(iIndex))
        return false;

    if(g_bMapsBlock)
        return false;

    return true;
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

    if(iCheckBuyZone && !rg_user_in_buyzone(iIndex))
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

stock bool:rg_user_in_buyzone(const pPlayer)
{
    new iSignals[UnifiedSignals];

    get_member(pPlayer, m_signals, iSignals);

    return bool:(SignalState:iSignals[US_State] & SIGNAL_BUY);   
}