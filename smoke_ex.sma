#include <amxmodx>
#include <fakemeta>
#include <reapi>

const SmokeCount = 2;

public plugin_init() {
	register_plugin("SmokeEX", "0.1", "d3m37r4");
	RegisterHookChain(RG_CGrenade_ExplodeSmokeGrenade, "CGrenade_ExplodeSmokeGrenade_Post", true);
}

public CGrenade_ExplodeSmokeGrenade_Post(const ent) {
	new Float:origin[3];
	get_entvar(ent, var_origin, origin);

	new m_usEvent = get_member(ent, m_Grenade_usEvent);
	for (new i; i < SmokeCount; i++) {
		engfunc(EngFunc_PlaybackEvent, FEV_GLOBAL, 0, m_usEvent, 0.0, origin, Float:{0.0, 0.0, 0.0}, 0.0, 0.0, 0, 1, 1, 0);
	}

	return HC_CONTINUE;
}