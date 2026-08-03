// ============================================================
// PinteMod — v2.1.1 Grouped Validation Suite
// Static/runtime-safe checks only. Does not sanction a real player.
// ============================================================

#namespace ezz_admin_validation;

#using custom_scripts\ezz_admin_storage;
#using custom_scripts\ezz_admin_identity;
#using custom_scripts\ezz_admin_localization;
#using custom_scripts\ezz_admin_bans;
#using custom_scripts\ezz_admin_health;
#using custom_scripts\ezz_admin_langstats;
#using custom_scripts\ezz_admin_moderation;
#using custom_scripts\ezz_admin_map_audit;

function validation_add(total_result, child_result, suite_name)
{
    if (!isdefined(child_result))
    {
        total_result.total++;
        total_result.failed++;
        println("^1[FAIL]^7 " + suite_name + " returned no result");
        return;
    }

    total_result.total = total_result.total + child_result.total;
    total_result.passed = total_result.passed + child_result.passed;
    total_result.failed = total_result.failed + child_result.failed;

    if (isdefined(child_result.skipped))
        total_result.skipped = total_result.skipped + child_result.skipped;
}

function validation_skip(result, name)
{
    result.skipped++;
    println("^3[SKIP]^7 " + name);
}

function validation_assert(result, condition, name)
{
    result.total++;
    if (condition) { result.passed++; println("^2[PASS]^7 " + name); }
    else { result.failed++; println("^1[FAIL]^7 " + name); }
}

function validation_framework_suite()
{
    result = SpawnStruct(); result.total = 0; result.passed = 0; result.failed = 0; result.skipped = 0;
    validation_assert(result, level.ezz_admin_version == "2.1.1", "Public configuration version 2.1.1");
    validation_assert(result, level.pintemod_core_version == "2.1.1", "Core version 2.1.1");
    validation_assert(result, isdefined(level.ezz_owner_xuids) && level.ezz_owner_xuids.size == 1, "Exactly one public bootstrap owner");
    validation_assert(result, level.ezz_owner_xuids[0] == "9cf34426f668fb8b", "Bootstrap owner XUID unchanged");
    validation_assert(result, fileexists("pintemod/logs/current_session.json"), "Current session manifest accessible");
    validation_assert(result, !fileexists("pintemod/health/secret.json"), "No health secret file expected");
    validation_assert(result, isdefined(level.pintemod_moderation_loaded) && level.pintemod_moderation_loaded, "Moderation module loaded");
    validation_assert(result, isdefined(level.pintemod_map_audit_loaded) && level.pintemod_map_audit_loaded, "Map Audit module loaded");
    return result;
}

function validation_run_suite(player)
{
    total = SpawnStruct(); total.total = 0; total.passed = 0; total.failed = 0; total.skipped = 0;
    println("^5========== PinteMod v2.1.1 TEST SUITE ==========");

    validation_add(total, validation_framework_suite(), "Framework");
    validation_add(total, ezz_admin_storage::storage_run_grouped_suite(), "Storage");

    if (isdefined(player))
        validation_add(total, ezz_admin_identity::identity_run_grouped_suite(player), "Identity");
    else
    {
        validation_skip(total, "Identity connected-player suite (no player connected or targeted)");
    }

    validation_add(total, ezz_admin_localization::localization_run_suite(), "Localization");
    validation_add(total, ezz_admin_bans::bans_run_grouped_suite(), "Bans");
    validation_add(total, ezz_admin_health::health_run_grouped_suite(), "Health");
    validation_add(total, ezz_admin_langstats::langstats_run_grouped_suite(), "Langstats");
    validation_add(total, ezz_admin_moderation::moderation_run_grouped_suite(), "Moderation");
    validation_add(total, ezz_admin_map_audit::map_audit_run_grouped_suite(), "Map Audit");

    println("^5===============================================");
    println("^5[PinteMod v2.1.1]^7 RESULT " + total.passed + "/" + total.total + " PASS | failed=" + total.failed + " | skipped=" + total.skipped);

    ezz_admin_storage::append_managed_log(
        "pintemod/logs/validation.log",
        "[" + GetTime() + "] V211_SUITE | passed=" + total.passed +
        " | total=" + total.total + " | failed=" + total.failed +
        " | skipped=" + total.skipped + "\n"
    );

    return total;
}

function cmd_ezzv211test(args)
{
    if (args.size <= 0 || toLower(args[0]) != "suite")
    {
        println("^7ezzv211test suite [player|xuid|client]");
        return;
    }

    player = undefined;

    if (args.size >= 2)
        player = ezz_admin_identity::identity_find_player(args[1]);

    if (!isdefined(player))
    {
        players = GetPlayers();
        if (players.size > 0) player = players[0];
    }

    validation_run_suite(player);
}

autoexec function init()
{
    if (isdefined(level.pintemod_validation_loaded) && level.pintemod_validation_loaded)
        return;

    level.pintemod_validation_loaded = true;
    level.pintemod_validation_version = "2.1.1";
    addcommand("ezzv211test", ::cmd_ezzv211test);
    println("^5[PinteMod]^7 Validation v2.1.1 loaded");
}
