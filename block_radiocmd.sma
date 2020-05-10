#include <amxmodx>

public plugin_init() {
	register_plugin("Block Radio Commands", "1.0", "d3m37r4");

	new cmd_list[][] = { "radio1", "radio2", "radio3" };
	for(new i; i < sizeof cmd_list; i++) {
		register_clcmd(cmd_list[i], "CmdBlock");
	}

	set_cvar_num("mp_radio_maxinround", 0);
}

public CmdBlock(id) {
	return PLUGIN_HANDLED;                      
}