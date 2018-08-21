/*
    Credits:    
        BoecSpecOPs (original idea - "Focus on votemap"),
        Mistrick (API Map Manager [Modular]),
        fantom (help in implementation).
*/

#include <amxmodx>
#include <reapi>
#include <map_manager>

const HIDEHUD_FLAGS = (HIDEHUD_WEAPONS|HIDEHUD_FLASHLIGHT|HIDEHUD_HEALTH|HIDEHUD_TIMER|HIDEHUD_MONEY|HIDEHUD_CROSSHAIR);

new const g_sCmdList[][] = {"radio1", "radio2", "radio3"};

new HookChain:g_hookShowMenu;
new HookChain:g_hookPlayerSpawn;
new bool:g_bBlockRadioCmd;

new g_iHideHud, g_iBlockRadioMenu, g_iBlockMenu;

public plugin_init() {
    register_plugin("Hide HUD/Menu on Vote", "1.0", "d3m37r4");

    register_cvar("mapm_hide_hud_on_vote", "1");                        // Скрывать HUD игрока на время голосования
    register_cvar("mapm_block_radio_cmd_on_vote", "1");                 // Блокировать показ меню радио команд на время голосования
    register_cvar("mapm_block_menu_on_vote", "1");                      // Блокировать показ меню закупки оружия именю смены команды

    for(new i; i < sizeof g_sCmdList; i++) {
        register_clcmd(g_sCmdList[i], "block_radio_cmd");
    }

    DisableHookChain(g_hookShowMenu = RegisterHookChain(RG_ShowVGUIMenu, "show_menu_pre", false));
    DisableHookChain(g_hookPlayerSpawn = RegisterHookChain(RG_CSGameRules_PlayerSpawn, "player_spawn_post", true));
}

public OnConfigsExecuted() {
    g_iHideHud = get_cvar_num("mapm_hide_hud_on_vote");
    g_iBlockRadioMenu = get_cvar_num("mapm_block_radio_cmd_on_vote");
    g_iBlockMenu = get_cvar_num("mapm_block_menu_on_vote");
}

public block_radio_cmd(id) {
    return g_bBlockRadioCmd ? PLUGIN_HANDLED : PLUGIN_CONTINUE;
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

public mapm_prepare_votelist(type) {
    if(type != VOTE_BY_SCHEDULER_SECOND) {
        enable_block_func();
    }
}

public mapm_vote_finished(const map[], type, total_votes) {
    disable_block_func();
}

public mapm_vote_canceled(type) {
    disable_block_func();
}

enable_block_func() {
    if(g_iBlockRadioMenu) {
        g_bBlockRadioCmd = true;
    }

    if(g_iBlockMenu) {
        EnableHookChain(g_hookShowMenu);    
    }

    if(g_iHideHud) { 
        EnableHookChain(g_hookPlayerSpawn);
    }    
}

disable_block_func() {
    if(g_iBlockRadioMenu) {
        g_bBlockRadioCmd = false;
    }

    if(g_iBlockMenu) {
        DisableHookChain(g_hookShowMenu);
    }
    
    if(g_iHideHud) { 
        DisableHookChain(g_hookPlayerSpawn);

        for(new id; id <= MaxClients; id++) {
            if(is_user_connected(id)) {
                set_member(id, m_iHideHUD, get_member(id, m_iHideHUD) & ~HIDEHUD_FLAGS);
            }
        }
    }
}