#include <amxmodx>
#include <reapi>

//#define AUTO_CFG        // Автосоздание конфига 

#define parseColors(%1,%2) parse(%1, %2[RED], charsmax(%2[]), %2[GREEN], charsmax(%2[]), %2[BLUE], charsmax(%2[]))

enum _:COLORS { RED, GREEN, BLUE };

new g_OptionSwitch[MAX_PLAYERS + 1];
new g_DynLightColor[COLORS];

new g_DynLighRadius, g_DynLighDecay, g_DynLighDuration;
new bool:g_RandomColor;

public plugin_init() {
    register_plugin("Grenade Effects", "1.4", "F@nt0M, d3m37r4");

    register_dictionary("grenade_effects.txt");

    register_clcmd("say /flash", "CmdOptionSwitch");
    register_clcmd("say_team /flash", "CmdOptionSwitch");

    RegisterHookChain(RG_CGrenade_ExplodeFlashbang, "CGrenade_ExplodeFlashbang_Post", true);
    RegisterCvars();

#if defined AUTO_CFG  
    AutoExecConfig(.autoCreate = true, .name = "grenade_effects_cfg");
#endif
}

public plugin_cfg() {
    new color[12];
    get_cvar_string("amx_ge_dynlight_color", color, charsmax(color));
    parseColorValue(color);
}

public client_putinserver(id) {
    g_OptionSwitch[id] = true;
}

public CmdOptionSwitch(id) {
    g_OptionSwitch[id] = g_OptionSwitch[id] ? false : true;
    client_print_color(id, print_team_default, "%l", "GE_DYNLIGHT_MESSAGE", fmt("%l", g_OptionSwitch[id] ? "GE_DYNLIGHT_EFFECT_ON" : "GE_DYNLIGHT_EFFECT_OFF"));
}

public HookChangeColor(const pcvar, const oldValue[], const newValue[]) {
    parseColorValue(newValue);
}

public CGrenade_ExplodeFlashbang_Post(const ent) {
    new Float:origin[3];
    get_entvar(ent, var_origin, origin);
   
    new players[MAX_PLAYERS], num;
    get_players(players, num, "ch");

    for(new i = 0, player; i < num; i++) {
        player = players[i];
        if(g_OptionSwitch[player]) {
            SendDynamicLightMessage(player, origin);
        }
    }
}
 
RegisterCvars() {
    hook_cvar_change(create_cvar(
        .name = "amx_ge_dynlight_color", 
        .string = "255 50 0",
        .flags = FCVAR_SERVER,
        .description = fmt("%L", LANG_SERVER, "GE_DYNLIGHT_COLOR_CVAR_DESC")
    ), "HookChangeColor"); 

    bind_pcvar_num(create_cvar(
        .name = "amx_ge_dynlight_radius", 
        .string = "50",
        .flags = FCVAR_SERVER,
        .description = fmt("%L", LANG_SERVER, "GE_DYNLIGHT_RADIUS_CVAR_DESC"), 
        .has_min = true, 
        .min_val = 0.0
    ), g_DynLighRadius); 

    bind_pcvar_num(create_cvar(
        .name = "amx_ge_dynlight_decay_radius", 
        .string = "60",
        .flags = FCVAR_SERVER,
        .description = fmt("%L", LANG_SERVER, "GE_DYNLIGHT_DECAY_RADIUS_CVAR_DESC"), 
        .has_min = true, 
        .min_val = Float:g_DynLighRadius
    ), g_DynLighDecay);

    bind_pcvar_num(create_cvar(
        .name = "amx_ge_dynlight_duration_time", 
        .string = "8",
        .flags = FCVAR_SERVER,
        .description = fmt("%L", LANG_SERVER, "GE_DYNLIGHT_DURATION_TIME_CVAR_DESC"),
        .has_min = true, 
        .min_val = 0.0
    ), g_DynLighDuration);
}

SendDynamicLightMessage(const index, const Float:origin[3]) {
    message_begin(MSG_ONE_UNRELIABLE, SVC_TEMPENTITY, .player = index);
    write_byte(TE_DLIGHT);
    write_coord_f(origin[0]);
    write_coord_f(origin[1]);
    write_coord_f(origin[2]);
    write_byte(g_DynLighRadius);
   
    if(g_RandomColor) {
        write_byte(random(255));
        write_byte(random(255));
        write_byte(random(255));
    } else {
        write_byte(g_DynLightColor[RED]);
        write_byte(g_DynLightColor[GREEN]);
        write_byte(g_DynLightColor[BLUE]);
    }

    write_byte(g_DynLighDuration);
    write_byte(g_DynLighDecay);
    message_end();
}

parseColorValue(const value[]) {
    new color[COLORS][COLORS];
    if(value[0] == EOS || parseColors(value, color) < 3) {
        g_RandomColor = true;
    } else {
        g_RandomColor = false;
        for(new i; i < sizeof g_DynLightColor; i++) {
            g_DynLightColor[i] = str_to_num(color[i]);
        }
    }    
}
