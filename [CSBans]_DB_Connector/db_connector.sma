#include <amxmodx>
#include <json>
#include <sqlx>

public stock const PluginName[] = "[CSBans] DB Connector";
public stock const PluginVersion[] = "0.0.9";
public stock const PluginAuthor[] = "d3m37r4";
public stock const PluginURL[] = "sib-game.ru";

new const SettingsFile[] = "/db_connector.json";
const TaskIndex = 100;

enum data_s {
	drivername[12],
    hostname[32],
    user[32],
    password[64],
    dbname[32],
    Float:retries_delay,
    retries,
};
new g_ConnectionData[data_s];

new Handle:g_DbTuple;
new g_ConnectionAttemptsNum;
new g_FwdConnectInitialized;

public plugin_init() {
	/**
	 *	Called when a database connection.
	 * 
	 *	@param db 			Tuple handle.
	 * 	
	 *	@return				A tuple handle used in connection routines.
	 *
	 *	DBC_ConnectInitialized(Handle:db)
	 */
	g_FwdConnectInitialized = CreateMultiForward("DBC_ConnectInitialized", ET_IGNORE, FP_CELL);
	readConfig();
}

readConfig() {
	new FilePath[PLATFORM_MAX_PATH];
	get_localinfo("amxx_configsdir", FilePath, charsmax(FilePath));
	add(FilePath, charsmax(FilePath), SettingsFile);

	if(!file_exists(FilePath)) {
		set_fail_state("Configuration file '%s' not found.", FilePath);
	}

	new JSON:Config = json_parse(FilePath, true);
	if(Config == Invalid_JSON)    {
		set_fail_state("Configuration file '%s' read error.", FilePath);
	}

	new Temp[64];
	json_object_get_string(Config, "driver", Temp, charsmax(Temp));
	copy(g_ConnectionData[drivername], charsmax(g_ConnectionData[drivername]), Temp);

	json_object_get_string(Config, "hostname", Temp, charsmax(Temp));
	copy(g_ConnectionData[hostname], charsmax(g_ConnectionData[hostname]), Temp);

	json_object_get_string(Config, "user", Temp, charsmax(Temp));
	copy(g_ConnectionData[user], charsmax(g_ConnectionData[user]), Temp);

	json_object_get_string(Config, "password", Temp, charsmax(Temp));
	copy(g_ConnectionData[password], charsmax(g_ConnectionData[password]), Temp);

	json_object_get_string(Config, "database", Temp, charsmax(Temp));
	copy(g_ConnectionData[dbname], charsmax(g_ConnectionData[dbname]), Temp);

	g_ConnectionData[retries_delay] = json_object_get_real(Config, "retries_delay");
	g_ConnectionData[retries] = json_object_get_number(Config, "retries");

	json_free(Config);
	log_amx("Config has been loaded.");

	initSqlConnect();
}

public initSqlConnect() {
	if(++g_ConnectionAttemptsNum >= g_ConnectionData[retries]) {
		remove_task(TaskIndex);
	}

	new DbType[12];
	SQL_GetAffinity(DbType, charsmax(DbType));

	if(!equali(DbType, g_ConnectionData[drivername])) {
		if(!SQL_SetAffinity(g_ConnectionData[drivername])) {
			set_fail_state("Failed to set affinity from %s to %s.", DbType, g_ConnectionData[drivername]);
		}
	}

	g_DbTuple = SQL_MakeDbTuple(g_ConnectionData[hostname], g_ConnectionData[user], g_ConnectionData[password], g_ConnectionData[dbname]);

	new ErrCode, Buffer[512];
	new Handle:SqlConnect = SQL_Connect(g_DbTuple, ErrCode, Buffer, charsmax(Buffer));

	if(SqlConnect == Empty_Handle) {
		if(g_DbTuple) {
			SQL_FreeHandle(g_DbTuple);
			g_DbTuple = Empty_Handle;
		}

		if(g_ConnectionAttemptsNum < g_ConnectionData[retries])   {
			log_amx("Connection [%d/%d] test error #%d: %s", g_ConnectionAttemptsNum, g_ConnectionData[retries], ErrCode, Buffer);
			log_amx("Reconnect to db in %0.f sec.", g_ConnectionData[retries_delay]);

			set_task(g_ConnectionData[retries_delay], "initSqlConnect", TaskIndex);
		} else {
			log_amx("Error connecting to db '%s': #%d: %s", g_ConnectionData[dbname], ErrCode, Buffer);
			g_ConnectionAttemptsNum = -1;
		}
	} else {
		remove_task(TaskIndex);
		if(g_ConnectionAttemptsNum == 1) {
			log_amx("Connection to '%s' database success!", g_ConnectionData[dbname]);
		} else {
			log_amx("Connection [%d/%d] to '%s' database success!", g_ConnectionAttemptsNum, g_ConnectionData[retries], g_ConnectionData[dbname]);
		}

		ExecuteForward(g_FwdConnectInitialized, _, g_DbTuple);
		if(SqlConnect) {
			SQL_FreeHandle(SqlConnect);
			SqlConnect = Empty_Handle;
		}
	}
}

public plugin_end() {
	if(g_DbTuple != Empty_Handle) {
		SQL_FreeHandle(g_DbTuple);
	}

	DestroyForward(g_FwdConnectInitialized);
}