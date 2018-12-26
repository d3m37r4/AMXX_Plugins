/*
    Credits:    
        BoecSpecOPs (original idea - "Focus on votemap"),
        Mistrick (API Map Manager [Modular]),
        fantom (help in implementation).
*/

#include <amxmodx>
#include <reapi>
#include <map_manager>

enum {
    MSG_ARG_STATUS = 1,
    MSG_ARG_SPRITE_NAME
};

enum {
    STATUSICON_HIDE,
    STATUSICON_SHOW  
};

const HIDEHUD_FLAGS = (-1 & ~HIDEHUD_ALL); 

new const g_sCmdList[][] = {"radio1", "radio2", "radio3"};

new HookChain:g_hookShowMenu, HookChain:g_hookPlayerSpawn;

new bool:g_bBlockRadioMenu;

new g_iHideHud, g_iHideIconStatus, g_iBlockRadioMenu, g_iBlockMenu;
new g_iMsgId, g_iIconStatus;

public plugin_init() {
    register_plugin("Hide HUD/Menu on Vote", "1.2", "d3m37r4");

    register_cvar("mapm_hide_hud_on_vote", "1");			// Скрывать HUD игрока на время голосования.
    register_cvar("mapm_hide_status_icons_on_vote", "1");	// Скрывать иконки статуса (бомба, дефьюзкит, байзона, зона спасения заложников и т.д.).
    register_cvar("mapm_block_radio_cmd_on_vote", "1");		// Блокировать показ меню радио команд на время голосования.
    register_cvar("mapm_block_menu_on_vote", "1");			// Блокировать показ меню закупки оружия, именю смены команды.

    for(new i; i < sizeof g_sCmdList; i++) {
        register_clcmd(g_sCmdList[i], "block_radio_cmd");
    }

    DisableHookChain(g_hookShowMenu = RegisterHookChain(RG_ShowVGUIMenu, "show_menu_pre", false));
    DisableHookChain(g_hookPlayerSpawn = RegisterHookChain(RG_CSGameRules_PlayerSpawn, "player_spawn_post", true));

    g_iIconStatus = get_user_msgid("StatusIcon");
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
    }
}

public msg_status_icon(msg_id, msg_dest, id)  {
    if(get_msg_arg_int(MSG_ARG_STATUS)) {
        new sprite_name[10];

        get_msg_arg_string(MSG_ARG_SPRITE_NAME, sprite_name, charsmax(sprite_name))

        if(equali(sprite_name, "buyzone") || equali(sprite_name, "c4") || 
            equali(sprite_name, "defuser") || equali(sprite_name, "rescue") || 
            equali(sprite_name, "escape") || equali(sprite_name, "vipsafety")
        ) {
            set_msg_arg_int(MSG_ARG_STATUS, ARG_BYTE, STATUSICON_HIDE);    
        }    
    }
}

public mapm_prepare_votelist(type) {
    if(type != VOTE_BY_SCHEDULER_SECOND) {
        g_iHideHud = get_cvar_num("mapm_hide_hud_on_vote");
        g_iBlockRadioMenu = get_cvar_num("mapm_block_radio_cmd_on_vote");
        g_iBlockMenu = get_cvar_num("mapm_block_menu_on_vote");
        g_iHideIconStatus = get_cvar_num("mapm_hide_status_icons_on_vote");

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
    if(g_iBlockRadioMenu) {
        g_bBlockRadioMenu = true;
    }

    if(g_iBlockMenu) {
        EnableHookChain(g_hookShowMenu);   
    }

    if(g_iHideHud) { 
        EnableHookChain(g_hookPlayerSpawn);
    }

    if(g_iHideIconStatus) { 
        g_iMsgId = register_message(g_iIconStatus, "msg_status_icon");
    }
}

disable_block_func() {
    if(g_iBlockRadioMenu) {
        g_bBlockRadioMenu = false;
    }

    if(g_iBlockMenu) {
        DisableHookChain(g_hookShowMenu);
    }

    if(g_iHideIconStatus) {
        unregister_message(g_iIconStatus, g_iMsgId);
    }

    if(g_iHideHud) { 
        DisableHookChain(g_hookPlayerSpawn);
    }

    for(new id, SignalState:signals; id <= MaxClients; id++) {
        if(!is_user_connected(id)) {
            continue;
        }
          
        signals = rg_get_user_signals(id);

        if(g_iHideHud) {
        	set_member(id, m_iHideHUD, get_member(id, m_iHideHUD) & ~HIDEHUD_FLAGS);
        }

        if(g_iHideIconStatus) {
        	if(get_member_game(m_bMapHasBuyZone) && (signals & SIGNAL_BUY)) {
            	send_status_icon(id, "buyzone", STATUSICON_SHOW); 
        	}

        	if(get_member_game(m_bMapHasBombZone)) {    
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
        message_begin(index ? MSG_ONE_UNRELIABLE : MSG_BROADCAST, g_iIconStatus, _, index);
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
