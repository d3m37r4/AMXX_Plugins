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
    STATUSICON_HIDE,
    STATUSICON_SHOW
}

const HIDEHUD_FLAGS = (-1 & ~HIDEHUD_ALL); 

new const g_sCmdList[][] = {"radio1", "radio2", "radio3"};

new HookChain:g_hookShowMenu;
new HookChain:g_hookPlayerSpawn;
new HookChain:g_hookMakeBomber;

new bool:g_bBlockRadioMenu;
new bool:g_bMapHasBombZone;

new g_iHideHud, g_iBlockRadioMenu, g_iBlockMenu;

public plugin_init() {
    register_plugin("Hide HUD/Menu on Vote", "1.1", "d3m37r4");

    register_cvar("mapm_hide_hud_on_vote", "1");                        // Скрывать HUD игрока на время голосования (игровой худ, иконку бомбы, щипцов).
    register_cvar("mapm_block_radio_cmd_on_vote", "1");                 // Блокировать показ меню радио команд на время голосования.
    register_cvar("mapm_block_menu_on_vote", "1");                      // Блокировать показ меню закупки оружия, именю смены команды.

    for(new i; i < sizeof g_sCmdList; i++) {
        register_clcmd(g_sCmdList[i], "block_radio_cmd");
    }

    DisableHookChain(g_hookShowMenu = RegisterHookChain(RG_ShowVGUIMenu, "show_menu_pre", false));
    DisableHookChain(g_hookPlayerSpawn = RegisterHookChain(RG_CSGameRules_PlayerSpawn, "player_spawn_post", true));
    DisableHookChain(g_hookMakeBomber = RegisterHookChain(RG_CBasePlayer_MakeBomber, "make_bomber_post", true));

	g_bMapHasBombZone = get_member_game(m_bMapHasBombZone);
}

public block_radio_cmd(id) {
    return g_bBlockRadioMenu ? PLUGIN_HANDLED : PLUGIN_CONTINUE;
}

public show_menu_pre(id) {
    SetHookChainReturn(ATYPE_INTEGER, 0);
    return HC_SUPERCEDE;
}

public make_bomber_post(id) {
    if(is_user_connected(id)) {
        set_user_icon(id, "c4", STATUSICON_HIDE);
    }
}

public player_spawn_post(id) {
    if(!is_user_connected(id)) {
        return;
    }
    
    set_member(id, m_iHideHUD, get_member(id, m_iHideHUD) | HIDEHUD_FLAGS);

    if(g_bMapHasBombZone && get_member(id, m_bHasDefuser)) {
        set_user_icon(id, "defuser", STATUSICON_HIDE);
    }
}

public mapm_prepare_votelist(type) {
    if(type != VOTE_BY_SCHEDULER_SECOND) {
        g_iHideHud = get_cvar_num("mapm_hide_hud_on_vote");
        g_iBlockRadioMenu = get_cvar_num("mapm_block_radio_cmd_on_vote");
        g_iBlockMenu = get_cvar_num("mapm_block_menu_on_vote");

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
        buyzone_toogle_solid(SOLID_NOT);    
    }

    if(g_iHideHud) { 
        EnableHookChain(g_hookPlayerSpawn);

        if(g_bMapHasBombZone) {
        	EnableHookChain(g_hookMakeBomber);
        }
    }
}

disable_block_func() {
    if(g_iBlockRadioMenu) {
        g_bBlockRadioMenu = false;
    }

    if(g_iBlockMenu) {
        DisableHookChain(g_hookShowMenu);
        buyzone_toogle_solid(SOLID_TRIGGER);
    }
    
    if(g_iHideHud) { 
        DisableHookChain(g_hookPlayerSpawn);
        DisableHookChain(g_hookMakeBomber);

        for(new id; id <= MaxClients; id++) {
            if(!is_user_connected(id)) {
                continue;
            }

            set_member(id, m_iHideHUD, get_member(id, m_iHideHUD) & ~HIDEHUD_FLAGS);   

            if(!g_bMapHasBombZone) {
            	continue;
            }

			if(get_member(id, m_bHasC4)) {
				set_user_icon(id, "c4", STATUSICON_SHOW);
			}

			if(get_member(id, m_bHasDefuser)) {
				set_user_icon(id, "defuser", STATUSICON_SHOW);
			}
        }
    }
}

stock buyzone_toogle_solid(const solid) {
    new ent;
    while((ent = rg_find_ent_by_class(ent, "func_buyzone"))) {
        set_entvar(ent, var_solid, solid);
    }
}

stock set_user_icon(const index, icon[], icon_state) {
    static msgStatusIcon;

    if(msgStatusIcon || (msgStatusIcon = get_user_msgid("StatusIcon")))
    {
		message_begin(index ? MSG_ONE : MSG_ALL, msgStatusIcon, _, index);
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
