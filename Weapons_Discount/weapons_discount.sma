#include <amxmodx>
#include <reapi>

new const CONFIG_NAME[] = "weapons_discount";

const MAX_DISCOUNTS = 5;

enum any:WEAPON_INFO {
    WI_FLAGS,
    Float:WI_DISCOUNT
};

new g_WeaponsDiscountsNum[any:WEAPON_P90 + 1];
new g_WeaponsDiscounts[any:WEAPON_P90 + 1][MAX_DISCOUNTS][WEAPON_INFO];

new WeaponIdType:g_WeaponIndex = WEAPON_NONE;
new g_DefaultCost;

public plugin_init() {
    register_plugin("Weapons Discount", "1.0", "d3m37r4");

    RegisterHookChain(RG_BuyWeaponByWeaponID, "BuyWeaponByWeaponID_Pre", false);
    RegisterHookChain(RG_BuyWeaponByWeaponID, "BuyWeaponByWeaponID_Post", true);
}

public plugin_cfg() {
    new filedir[128];

    get_localinfo("amxx_configsdir", filedir, charsmax(filedir));
    formatex(filedir, charsmax(filedir), "%s/%s.ini", filedir, CONFIG_NAME);

    parseConfigINI(filedir);
}

public BuyWeaponByWeaponID_Pre(const id, const WeaponIdType:weaponID) {
    g_DefaultCost = -1;

    if(weaponID == WEAPON_NONE) {
        return HC_CONTINUE;
    }

    g_DefaultCost = rg_get_weapon_info(weaponID, WI_COST);

    new wCost = getWeaponCost(id, getWeaponIndex(weaponID));

    if(wCost >= 0) {
        rg_set_weapon_info(weaponID, WI_COST, wCost);
    }

    return HC_CONTINUE;
}
 
public BuyWeaponByWeaponID_Post(const id, const WeaponIdType:weaponID) {
    if(g_DefaultCost >= 0) {
        rg_set_weapon_info(weaponID, WI_COST, g_DefaultCost);
    }
}

getWeaponCost(const id, const index) {
    if(g_WeaponsDiscountsNum[index] <= 0) {
        return -1;
    }

    for(new i, num = g_WeaponsDiscountsNum[index], flags = get_user_flags(id); i < num; i++) {
        if((flags & g_WeaponsDiscounts[index][i][WI_FLAGS]) == g_WeaponsDiscounts[index][i][WI_FLAGS]) {
            return floatround(g_DefaultCost * (1.0 - g_WeaponsDiscounts[index][i][WI_DISCOUNT] / 100.0));
        }
    }
   
    return -1;
}
 
getWeaponIndex(const WeaponIdType:weaponID) {
    return any:(weaponID == WEAPON_SHIELDGUN ? WEAPON_P90 : weaponID - WeaponIdType:1);
}

parseConfigINI(const configFile[]) {
    new INIParser:parser = INI_CreateParser();

    if(parser != Invalid_INIParser) {
        INI_SetReaders(parser, "ReadCFGKeyValue", "ReadCFGNewSection");
        INI_ParseFile(parser, configFile);
        INI_DestroyParser(parser);
    }
}

public bool:ReadCFGNewSection(INIParser:handle, const section[]) {
    g_WeaponIndex = rg_get_weapon_info(section, WI_ID);

    if(g_WeaponIndex == WEAPON_NONE) {
        return false;
    }

    return true;
}

public bool:ReadCFGKeyValue(INIParser:handle, const key[], const value[]) {
    if(g_WeaponIndex == WEAPON_NONE) {
        return false;
    }

    new index = getWeaponIndex(g_WeaponIndex);
    new num = g_WeaponsDiscountsNum[index];

    g_WeaponsDiscounts[index][num][WI_FLAGS] = read_flags(key);
    g_WeaponsDiscounts[index][num][WI_DISCOUNT] = str_to_float(value);
    g_WeaponsDiscountsNum[index]++;

    return true;
}
