/*
    Credits:    
        BoecSpecOPs (original idea - "Focus on votemap"),
        Mistrick (API Map Manager [Modular]),
        fantom (help in implementation).
*/

#include <amxmodx>
#include <reapi>
#include <map_manager>

#pragma semicolon 1

#if !defined ARG_ICON_STATUS 
    const ARG_ICON_STATUS = 1;
#endif

enum {
    STATUSICON_HIDE,
    STATUSICON_SHOW  
};

enum _:CVARS {
    HIDE_HUD,
    HIDE_ICONSTATUS,
    BLOCK_RADIOMENU,
    BLOCK_MENU
}

const HIDEHUD_FLAGS = (-1 & ~HIDEHUD_ALL); 

new const g_sCmdList[][] = {"radio1", "radio2", "radio3"};

new HookChain:g_hookShowMenu;
new HookChain:g_hookPlayerSpawn;

new bool:g_bMapHasBombZone;
new bool:g_bBlockRadioMenu;

new g_pCvars[CVARS];
new g_Cvars[CVARS];

new g_iIconStatus;
new g_iMsgId;

public plugin_init() {
    register_plugin("Hide HUD/Menu on Vote", "1.2.2", "d3m37r4");

    g_pCvars[HIDE_HUD] = register_cvar("mapm_hide_hud_on_vote", "1");			        // Скрывать HUD игрока на время голосования.
    g_pCvars[HIDE_ICONSTATUS] = register_cvar("mapm_hide_status_icons_on_vote", "1");   // Скрывать иконки статуса (бомба, дефьюзкит, байзона, зона спасения заложников и т.д.).
    g_pCvars[BLOCK_RADIOMENU] = register_cvar("mapm_block_radio_cmd_on_vote", "1");		// Блокировать показ меню радио команд на время голосования.
    g_pCvars[BLOCK_MENU] = register_cvar("mapm_block_menu_on_vote", "1");			    // Блокировать показ меню закупки оружия, именю смены команды.

    for(new i; i < sizeof g_sCmdList; i++) {
        register_clcmd(g_sCmdList[i], "block_radio_cmd");
    }

    DisableHookChain(g_hookShowMenu = RegisterHookChain(RG_ShowVGUIMenu, "show_menu_pre", false));
    DisableHookChain(g_hookPlayerSpawn = RegisterHookChain(RG_CSGameRules_PlayerSpawn, "player_spawn_post", true));

    g_iIconStatus = get_user_msgid("StatusIcon");
    g_bMapHasBombZone = get_member_game(m_bMapHasBombZone);
}

public block_radio_cmd(id) {
    return g_bBlockRadioMenu ? PLUGIN_HANDLED : PLUGIN_CONTINUE;
}

public show_menu_pre(id) {
    SetHookChainReturn(ATYPE_INTEGER, 0);
    return HC_SUPERCEDE;
}

public player_spawn_post(id) {
    if(is_user_connected(id)) {
        set_member(id, m_iHideHUD, get_member(id, m_iHideHUD) | HIDEHUD_FLAGS);

        if(g_bMapHasBombZone) {    
            RequestFrame("hide_icons", id);
        }
    }
}

public hide_icons(id) {
    if(get_member(id, m_bHasC4)) {
        send_status_icon(id, "c4", STATUSICON_HIDE);             
    }

    if(get_member(id, m_bHasDefuser)) {
        send_status_icon(id, "defuser", STATUSICON_HIDE);             
    }  
}

public msg_status_icon(msg_id, msg_dest, id)  {
    if(get_msg_arg_int(ARG_ICON_STATUS)) {
        set_msg_arg_int(ARG_ICON_STATUS, ARG_BYTE, STATUSICON_HIDE);
    }
}

public mapm_prepare_votelist(type) {
    if(type != VOTE_BY_SCHEDULER_SECOND) {
        g_Cvars[HIDE_HUD] = get_pcvar_num(g_pCvars[HIDE_HUD]);
        g_Cvars[HIDE_ICONSTATUS] = get_pcvar_num(g_pCvars[HIDE_ICONSTATUS]);
        g_Cvars[BLOCK_RADIOMENU] = get_pcvar_num(g_pCvars[BLOCK_RADIOMENU]);
        g_Cvars[BLOCK_MENU] = get_pcvar_num(g_pCvars[BLOCK_MENU]);

        enable_block_func();
    }
}

public mapm_vote_finished() {
    disable_block_func();
}

public mapm_vote_canceled() {
    disable_block_func();
}

enable_block_func() {
    if(g_Cvars[BLOCK_RADIOMENU]) {
        g_bBlockRadioMenu = true;
    }

    if(g_Cvars[BLOCK_MENU]) {
        EnableHookChain(g_hookShowMenu);   
    }

    if(g_Cvars[HIDE_HUD]) { 
        EnableHookChain(g_hookPlayerSpawn);
    }

    if(g_Cvars[HIDE_ICONSTATUS]) {
        g_iMsgId = register_message(g_iIconStatus, "msg_status_icon");
    }
}

disable_block_func() {
    if(g_Cvars[BLOCK_RADIOMENU]) {
        g_bBlockRadioMenu = false;
    }

    if(g_Cvars[BLOCK_MENU]) {
        DisableHookChain(g_hookShowMenu);
    }

    if(g_Cvars[HIDE_ICONSTATUS]) {
        unregister_message(g_iIconStatus, g_iMsgId);
    }

    if(g_Cvars[HIDE_HUD]) { 
        DisableHookChain(g_hookPlayerSpawn);
    }

    for(new id, SignalState:signals; id <= MaxClients; id++) {
        if(!is_user_connected(id)) {
            continue;
        }
          
        signals = rg_get_user_signals(id);

        if(g_Cvars[HIDE_HUD]) {
        	set_member(id, m_iHideHUD, get_member(id, m_iHideHUD) & ~HIDEHUD_FLAGS);
        }

        if(g_Cvars[HIDE_ICONSTATUS]) {
        	if(get_member_game(m_bMapHasBuyZone) && (signals & SIGNAL_BUY)) {
            	send_status_icon(id, "buyzone", STATUSICON_SHOW); 
        	}

        	if(g_bMapHasBombZone) {    
            	if(get_member(id, m_bHasC4)) {
                	send_status_icon(id, "c4", STATUSICON_SHOW);             
            	}

            	if(get_member(id, m_bHasDefuser)) {
                	send_status_icon(id, "defuser", STATUSICON_SHOW);             
            	}
        	}

        	if(get_member_game(m_bMapHasRescueZone) && (signals & SIGNAL_RESCUE)) {
            	send_status_icon(id, "rescue", STATUSICON_SHOW); 
        	}

        	if(get_member_game(m_bMapHasEscapeZone) && (signals & SIGNAL_ESCAPE)) {
            	send_status_icon(id, "escape", STATUSICON_SHOW); 
        	}

        	if(get_member_game(m_bMapHasVIPSafetyZone) && (signals & SIGNAL_VIPSAFETY)) {
            	send_status_icon(id, "vipsafety", STATUSICON_SHOW); 
        	}
    	}
    }
}

send_status_icon(const index, const icon[], const icon_state) {
    if(g_iIconStatus) {
        message_begin(index ? MSG_ONE : MSG_ALL, g_iIconStatus, _, index);
        write_byte(icon_state);
        write_string(icon);

        if(icon_state) {
            write_byte(0);
            write_byte(160);
            write_byte(0);
        }

        message_end();
    }
}

stock SignalState:rg_get_user_signals(const index) {
    new iSignals[UnifiedSignals];

    get_member(index, m_signals, iSignals);

    return SignalState:iSignals[US_State];
}
