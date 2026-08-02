// ============================================================
// PinteMod — Global Health Diagnostics v2.1.1
// Fichier : ezz_admin_health.gsc
// Diagnostic non sensible des modules GSC, du stockage et des
// outils Windows via heartbeats locaux sans secret ni adresse IP.
// ============================================================

#namespace ezz_admin_health;

#using custom_scripts\ezz_admin_storage;
#using custom_scripts\ezz_admin_identity;
#using custom_scripts\ezz_admin_registry;

function health_heartbeat_root()
{
    return "pintemod/health";
}

function health_heartbeat_path(tool_name)
{
    return health_heartbeat_root() + "/" + tool_name + ".json";
}

function health_json_string(json, key_name, default_value)
{
    if (!isdefined(json) || json == "" || jsonvalid(json))
        return default_value;

    value = jsonparse(json, key_name);

    if (!isdefined(value) || value == "")
        return default_value;

    return value;
}

function health_json_int(json, key_name, default_value)
{
    value = health_json_string(json, key_name, "");

    if (value == "")
        return default_value;

    return int(value);
}

function health_tool_slot(tool_name)
{
    switch (tool_name)
    {
        case "ban_service": return 0;
        case "geoip_bridge": return 1;
        case "live_console": return 2;
        case "supervisor": return 3;
    }

    return 7;
}

function health_external_status(tool_name)
{
    result = SpawnStruct();
    result.tool = tool_name;
    result.status = "ABSENT";
    result.version = "unknown";
    result.state = "absent";
    result.sequence = -1;
    result.error = "";

    path = health_heartbeat_path(tool_name);

    if (!fileexists(path))
        return result;

    json = readfile(path);

    if (!ezz_admin_storage::storage_json_is_valid(json))
    {
        result.status = "ERROR";
        result.state = "invalid_heartbeat";
        return result;
    }

    result.version = health_json_string(json, "version", "unknown");
    result.state = toLower(health_json_string(json, "state", "unknown"));
    result.sequence = health_json_int(json, "sequence", 0);
    result.error = health_json_string(json, "last_error_code", "");

    slot = health_tool_slot(tool_name);

    if (!isdefined(level.pintemod_health_last_sequence))
    {
        level.pintemod_health_last_sequence = [];
        level.pintemod_health_last_seen = [];
    }

    if (!isdefined(level.pintemod_health_last_sequence[slot]) ||
        level.pintemod_health_last_sequence[slot] != result.sequence)
    {
        level.pintemod_health_last_sequence[slot] = result.sequence;
        level.pintemod_health_last_seen[slot] = GetTime();
    }

    stale = false;

    if (isdefined(level.pintemod_health_last_seen[slot]) &&
        GetTime() - level.pintemod_health_last_seen[slot] > 45000)
    {
        stale = true;
    }

    if (stale)
    {
        result.status = "STALE";
        return result;
    }

    if (result.state == "running" || result.state == "connected" ||
        result.state == "active" || result.state == "monitoring")
    {
        result.status = "CONNECTED";
    }
    else if (result.state == "configured" || result.state == "inactive" ||
        result.state == "stopped" || result.state == "waiting")
    {
        result.status = "CONFIGURED_NOT_ACTIVE";
    }
    else if (result.state == "error" || result.error != "")
    {
        result.status = "ERROR";
    }
    else
    {
        result.status = "DETECTED";
    }

    return result;
}

function health_monitor_external_tools()
{
    wait 1;

    for (;;)
    {
        health_external_status("ban_service");
        health_external_status("geoip_bridge");
        health_external_status("live_console");
        health_external_status("supervisor");
        wait 5;
    }
}

function health_installation_report()
{
    report = SpawnStruct();
    report.status = "NOT_RUN";
    report.pass = 0;
    report.warning = 0;
    report.error = 0;
    report.version = "unknown";
    path = "pintemod/diagnostics/installation_verification.json";

    if (!fileexists(path))
        return report;

    json = readfile(path);

    if (!ezz_admin_storage::storage_json_is_valid(json))
    {
        report.status = "ERROR";
        return report;
    }

    report.pass = health_json_int(json, "pass", 0);
    report.warning = health_json_int(json, "warning", 0);
    report.error = health_json_int(json, "error", 0);
    report.version = health_json_string(json, "version", "unknown");

    if (report.error > 0)
        report.status = "ERROR";
    else if (report.warning > 0)
        report.status = "WARNING";
    else
        report.status = "PASS";

    return report;
}

function health_state_text(condition)
{
    if (condition)
        return "OK";

    return "MISSING";
}

function health_print_module(name, loaded, version)
{
    line = name;

    while (line.size < 15)
        line = line + " ";

    if (loaded)
        println("^2" + line + " OK^7 | v" + version);
    else
        println("^1" + line + " MISSING");
}

function health_print_tool(label, tool)
{
    line = label;

    while (line.size < 15)
        line = line + " ";

    color = "^2";

    if (tool.status == "ABSENT" || tool.status == "ERROR")
        color = "^1";
    else if (tool.status == "STALE" ||
        tool.status == "CONFIGURED_NOT_ACTIVE")
        color = "^3";

    println(color + line + " " + tool.status + "^7 | v" + tool.version);
}

function health_print_tool_details(label, tool)
{
    health_print_tool(label, tool);
    error_text = tool.error;

    if (!isdefined(error_text) || error_text == "")
        error_text = "none";

    println("^7  state=" + tool.state +
        " | sequence=" + tool.sequence +
        " | last_error=" + error_text);
}

function health_warning_count()
{
    warnings = 0;

    if (!isdefined(level.pintemod_core_loaded) || !level.pintemod_core_loaded)
        warnings++;
    if (!isdefined(level.pintemod_storage_initialized) || !level.pintemod_storage_initialized)
        warnings++;
    if (!isdefined(level.pintemod_identity_initialized) || !level.pintemod_identity_initialized)
        warnings++;
    if (!fileexists("pintemod/logs/current_session.json"))
        warnings++;

    ban = health_external_status("ban_service");
    geo = health_external_status("geoip_bridge");
    live = health_external_status("live_console");
    supervisor = health_external_status("supervisor");
    installation = health_installation_report();

    if (ban.status != "CONNECTED") warnings++;
    if (geo.status != "CONNECTED") warnings++;
    if (live.status != "CONNECTED") warnings++;
    if (supervisor.status != "CONNECTED") warnings++;
    if (installation.status == "ERROR" || installation.status == "WARNING") warnings++;

    return warnings;
}

function health_print_short()
{
    ban = health_external_status("ban_service");
    geo = health_external_status("geoip_bridge");
    live = health_external_status("live_console");

    println("^5========== [PinteMod Health] ==========");
    health_print_module("Core", isdefined(level.pintemod_core_loaded) && level.pintemod_core_loaded, "2.1.1");
    health_print_module("Identity", isdefined(level.pintemod_identity_initialized) && level.pintemod_identity_initialized, "2.0.2");
    health_print_module("Storage", isdefined(level.pintemod_storage_initialized) && level.pintemod_storage_initialized, "2.0.0");
    health_print_module("Localization", isdefined(level.pintemod_localization_initialized) && level.pintemod_localization_initialized, "2.1.1");
    health_print_tool("GeoIP Bridge", geo);
    health_print_tool("Ban Service", ban);
    health_print_tool("Live Console", live);
    health_print_module("Ranks", isdefined(level.pintemod_ranks_version), "2.0.0");
    println("^7EE Profiles     14 declared");
    println("^7Warnings        " + health_warning_count());
    println("^5=========================================");
}

function health_print_full()
{
    health_print_short();
    println("^5----- GSC modules -----");
    health_print_module("Registry", isdefined(level.pintemod_registry_initialized) && level.pintemod_registry_initialized, "2.1.1");
    health_print_module("Chat", isdefined(level.ezz_chat_loaded) && level.ezz_chat_loaded, "0.18.0");
    health_print_module("Community", isdefined(level.pintemod_community_loaded) && level.pintemod_community_loaded, "2.1.1");
    health_print_module("Bans", isdefined(level.pintemod_bans_initialized) && level.pintemod_bans_initialized, "2.1.1");
    health_print_module("Moderation", isdefined(level.pintemod_moderation_loaded) && level.pintemod_moderation_loaded, "2.1.1");
    health_print_module("Langstats", isdefined(level.pintemod_langstats_loaded) && level.pintemod_langstats_loaded, "2.1.1");
    health_print_module("Menu", isdefined(level.pintemod_menu_version), "1.0.0");
    health_print_module("Maps", isdefined(level.pintemod_maps_loaded) && level.pintemod_maps_loaded, "0.11.0");
    health_print_module("Map Audit", isdefined(level.pintemod_map_audit_loaded) && level.pintemod_map_audit_loaded, "2.1.1");
    health_print_module("Music", isdefined(level.pintemod_music_loaded) && level.pintemod_music_loaded, "0.5.1");
    health_print_module("Events", isdefined(level.pintemod_events_loaded) && level.pintemod_events_loaded, "0.6.2");
    health_print_module("EE Records", isdefined(level.pintemod_ee_records_loaded) && level.pintemod_ee_records_loaded, "2.0.1");

    println("^5----- External tools -----");
    health_print_tool_details("Supervisor", health_external_status("supervisor"));
    health_print_tool_details("Ban Service", health_external_status("ban_service"));
    health_print_tool_details("GeoIP Bridge", health_external_status("geoip_bridge"));
    health_print_tool_details("Live Console", health_external_status("live_console"));

    installation = health_installation_report();
    println("^5----- Installation verification -----");
    println("^7Status          " + installation.status + " | v" + installation.version);
    println("^7Results         PASS=" + installation.pass +
        " | WARNING=" + installation.warning +
        " | ERROR=" + installation.error);
    println("^7Report          boiii/scriptdata/pintemod/diagnostics/installation_verification.json");

    println("^5----- Files and privacy -----");
    println("^7Session manifest: " + health_state_text(fileexists("pintemod/logs/current_session.json")));
    println("^7Identity registry: " + health_state_text(fileexists("pintemod/identity/roles.json") || isdefined(level.pintemod_identity_roles_json)));
    println("^7Ban status: " + health_state_text(fileexists("pintemod/bans/service_status.json") || fileexists(health_heartbeat_path("ban_service"))));
    println("^7Heartbeat root: boiii/scriptdata/" + health_heartbeat_root());
    println("^7Privacy: no password, secret, player IP or GUID displayed");
}

function health_test_assert(result, condition, name)
{
    result.total++;

    if (condition)
    {
        result.passed++;
        println("^2[PASS]^7 " + name);
    }
    else
    {
        result.failed++;
        println("^1[FAIL]^7 " + name);
    }
}

function health_run_grouped_suite()
{
    result = SpawnStruct();
    result.total = 0;
    result.passed = 0;
    result.failed = 0;

    health_test_assert(result, isdefined(level.pintemod_core_loaded) && level.pintemod_core_loaded, "Health sees Core");
    health_test_assert(result, isdefined(level.pintemod_storage_initialized) && level.pintemod_storage_initialized, "Health sees Storage");
    health_test_assert(result, isdefined(level.pintemod_identity_initialized) && level.pintemod_identity_initialized, "Health sees Identity");
    health_test_assert(result, ezz_admin_registry::official_map_codes().size == 14, "Fourteen official map profiles declared");
    health_test_assert(result, health_heartbeat_path("geoip_bridge") == "pintemod/health/geoip_bridge.json", "Heartbeat path is public-safe");

    return result;
}

function cmd_ezzhealth(args)
{
    if (args.size > 0 && toLower(args[0]) == "full")
        health_print_full();
    else
        health_print_short();
}

autoexec function init()
{
    if (isdefined(level.pintemod_health_loaded) && level.pintemod_health_loaded)
        return;

    level.pintemod_health_loaded = true;
    level.pintemod_health_version = "2.1.1";
    level.pintemod_health_last_sequence = [];
    level.pintemod_health_last_seen = [];

    mkdir("pintemod");
    mkdir(health_heartbeat_root());

    addcommand("ezzhealth", ::cmd_ezzhealth);
    level thread health_monitor_external_tools();

    println("^5[PinteMod]^7 Health v2.1.1 loaded");
}
