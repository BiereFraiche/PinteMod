// ============================================================
// PinteMod — Anonymous Language & Population Statistics v2.1.1
// Aggregated counters only. No IP and no player-to-country mapping.
// ============================================================

#namespace ezz_admin_langstats;

#using custom_scripts\ezz_admin_identity;
#using custom_scripts\ezz_admin_storage;
#using custom_scripts\ezz_admin_localization;

function langstats_root()
{
    return "pintemod/localization/stats";
}

function langstats_languages_path(test_mode)
{
    if (isdefined(test_mode) && test_mode)
        return langstats_root() + "/test_languages.json";

    return langstats_root() + "/languages.json";
}

function langstats_countries_summary_path()
{
    return langstats_root() + "/countries_summary.txt";
}

function langstats_default_json()
{
    json = "{}";
    json = jsonset(json, "schema_version", "1");
    json = jsonset(json, "fr", "0");
    json = jsonset(json, "en", "0");
    json = jsonset(json, "es", "0");
    json = jsonset(json, "other", "0");
    json = jsonset(json, "total_connections", "0");
    return json;
}

function langstats_json_int(json, key_name)
{
    if (!isdefined(json) || json == "" || jsonvalid(json))
        return 0;

    value = jsonparse(json, key_name);

    if (!isdefined(value) || value == "")
        return 0;

    return int(value);
}

function langstats_load(test_mode)
{
    return ezz_admin_storage::load_json_or_default(
        langstats_languages_path(test_mode),
        langstats_default_json(),
        "langstats-load"
    );
}

function langstats_write(json, test_mode, context)
{
    return ezz_admin_storage::write_json_safe(
        langstats_languages_path(test_mode),
        json,
        context
    );
}

function langstats_normalize_bucket(language)
{
    if (!isdefined(language) || language == "")
        return "other";

    value = toLower(language);

    switch (value)
    {
        case "fr":
        case "francais":
        case "french":
            return "fr";

        case "en":
        case "english":
        case "anglais":
            return "en";

        case "es":
        case "espanol":
        case "spanish":
            return "es";
    }

    return "other";
}

function langstats_record_language(language, test_mode)
{
    if ((!isdefined(test_mode) || !test_mode) &&
        isdefined(level.pintemod_langstats_enabled) &&
        !level.pintemod_langstats_enabled)
    {
        return false;
    }

    bucket = langstats_normalize_bucket(language);
    json = langstats_load(test_mode);
    current = langstats_json_int(json, bucket);
    total = langstats_json_int(json, "total_connections");

    json = jsonset(json, bucket, "" + (current + 1));
    json = jsonset(json, "total_connections", "" + (total + 1));

    return langstats_write(json, test_mode, "langstats-record-" + bucket);
}

function langstats_record_player(player)
{
    if (isdefined(level.pintemod_langstats_enabled) &&
        !level.pintemod_langstats_enabled)
    {
        return;
    }

    if (!isdefined(player) ||
        (isdefined(player.pintemod_langstats_recorded) &&
         player.pintemod_langstats_recorded))
    {
        return;
    }

    xuid = ezz_admin_identity::get_player_xuid(player);

    if (!ezz_admin_identity::is_valid_xuid(xuid))
        return;

    language = ezz_admin_localization::get_player_language(player);

    if (langstats_record_language(language, false))
    {
        player.pintemod_langstats_recorded = true;
        ezz_admin_storage::append_managed_log(
            "pintemod/logs/language.log",
            "[" + GetTime() + "] LANGSTATS_CONNECTION | language=" +
            langstats_normalize_bucket(language) + "\n"
        );
    }
}

function langstats_delayed_record()
{
    self endon("disconnect");
    wait 12;
    langstats_record_player(self);
}

function langstats_attach(player)
{
    if (!isdefined(player))
        return;

    if (isdefined(player.pintemod_langstats_monitor_started) &&
        player.pintemod_langstats_monitor_started)
        return;

    player.pintemod_langstats_monitor_started = true;
    player thread langstats_delayed_record();
}

function langstats_bootstrap()
{
    wait 2;
    players = GetPlayers();

    for (i = 0; i < players.size; i++)
        langstats_attach(players[i]);

    for (;;)
    {
        level waittill("connected", player);
        langstats_attach(player);
    }
}

function langstats_percent(value, total)
{
    if (total <= 0)
        return 0;

    return int((value * 100) / total);
}

function langstats_print_languages()
{
    json = langstats_load(false);
    fr = langstats_json_int(json, "fr");
    en = langstats_json_int(json, "en");
    es = langstats_json_int(json, "es");
    other = langstats_json_int(json, "other");
    total = langstats_json_int(json, "total_connections");

    println("^5Languages (aggregated connections)");
    println("^7French        " + langstats_percent(fr, total) + "% (" + fr + ")");
    println("^7English       " + langstats_percent(en, total) + "% (" + en + ")");
    println("^7Spanish       " + langstats_percent(es, total) + "% (" + es + ")");
    println("^7Other         " + langstats_percent(other, total) + "% (" + other + ")");
    println("^7Total         " + total);
}

function langstats_print_countries()
{
    println("^5Countries (aggregated connections)");

    if (!fileexists(langstats_countries_summary_path()))
    {
        println("^3No country statistics yet. GeoIP Bridge has not produced a summary.");
        return;
    }

    summary = readfile(langstats_countries_summary_path());

    if (!isdefined(summary) || summary == "")
    {
        println("^3No country statistics yet.");
        return;
    }

    println("^7" + summary);
}

function langstats_is_owner(actor)
{
    if (!isdefined(actor))
        return true;

    return ezz_admin_identity::get_player_role(actor) >= 4;
}

function langstats_make_reset_token()
{
    level.pintemod_langstats_reset_counter++;
    return "LS" + GetTime() + "X" + level.pintemod_langstats_reset_counter;
}

function langstats_prepare_reset(actor)
{
    if (!langstats_is_owner(actor))
    {
        if (isdefined(actor)) actor iprintln("^1[PinteMod]^7 Owner role required.");
        println("^1[PinteMod Langstats]^7 RESET_REFUSED | reason=owner_required");
        return;
    }

    level.pintemod_langstats_reset_token = langstats_make_reset_token();
    level.pintemod_langstats_reset_expires = GetTime() + 60000;
    println("^3[PinteMod Langstats]^7 Reset prepared. Confirm within 60s:");
    println("^7ezzlangstats reset confirm " + level.pintemod_langstats_reset_token);

    if (isdefined(actor))
        actor iprintln("^3[PinteMod]^7 Langstats reset token: " + level.pintemod_langstats_reset_token);
}

function langstats_confirm_reset(actor, token)
{
    if (!langstats_is_owner(actor))
    {
        if (isdefined(actor)) actor iprintln("^1[PinteMod]^7 Owner role required.");
        return false;
    }

    if (!isdefined(level.pintemod_langstats_reset_token) ||
        level.pintemod_langstats_reset_token == "" ||
        token != level.pintemod_langstats_reset_token)
    {
        println("^1[PinteMod Langstats]^7 Invalid reset token.");
        return false;
    }

    if (GetTime() > level.pintemod_langstats_reset_expires)
    {
        println("^1[PinteMod Langstats]^7 Reset token expired.");
        return false;
    }

    languages_ok = langstats_write(langstats_default_json(), false, "langstats-owner-reset");

    if (fileexists(langstats_countries_summary_path()))
        removefile(langstats_countries_summary_path());

    if (fileexists(langstats_root() + "/countries.json"))
        removefile(langstats_root() + "/countries.json");

    level.pintemod_langstats_reset_token = "";
    level.pintemod_langstats_reset_expires = 0;

    if (languages_ok)
        println("^2[PinteMod Langstats]^7 Aggregated statistics reset.");
    else
        println("^1[PinteMod Langstats]^7 Reset write failed.");

    return languages_ok;
}

function langstats_show(actor, mode)
{
    if (!isdefined(mode) || mode == "")
        mode = "all";

    mode = toLower(mode);
    println("^5========== PinteMod Population ==========");

    if (mode == "all" || mode == "countries")
        langstats_print_countries();

    if (mode == "all" || mode == "languages")
        langstats_print_languages();

    println("^7Privacy: aggregate counters only; no IP stored.");
    println("^5=========================================");
}

function langstats_test_assert(result, condition, name)
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

function langstats_run_grouped_suite()
{
    result = SpawnStruct();
    result.total = 0;
    result.passed = 0;
    result.failed = 0;

    path = langstats_languages_path(true);
    removefile(path);
    removefile(path + ".tmp");
    removefile(path + ".bak");

    langstats_test_assert(result, langstats_record_language("fr", true), "Write French aggregate");
    langstats_test_assert(result, langstats_record_language("de", true), "Unknown language uses Other");
    json = langstats_load(true);
    langstats_test_assert(result, langstats_json_int(json, "fr") == 1, "French counter equals one");
    langstats_test_assert(result, langstats_json_int(json, "other") == 1, "Other counter equals one");
    langstats_test_assert(result, langstats_json_int(json, "total_connections") == 2, "Connection total equals two");

    removefile(path);
    removefile(path + ".tmp");
    removefile(path + ".bak");

    return result;
}

function cmd_ezzlangstats(args)
{
    if (args.size <= 0)
    {
        langstats_show(undefined, "all");
        return;
    }

    action = toLower(args[0]);

    if (action == "countries" || action == "languages")
    {
        langstats_show(undefined, action);
        return;
    }

    if (action == "reset")
    {
        if (args.size >= 2 && toLower(args[1]) == "prepare")
        {
            langstats_prepare_reset(undefined);
            return;
        }

        if (args.size >= 3 && toLower(args[1]) == "confirm")
        {
            langstats_confirm_reset(undefined, args[2]);
            return;
        }
    }

    println("^7ezzlangstats [countries|languages]");
    println("^7ezzlangstats reset prepare");
    println("^7ezzlangstats reset confirm <token>");
}

autoexec function init()
{
    if (isdefined(level.pintemod_langstats_loaded) && level.pintemod_langstats_loaded)
        return;

    level.pintemod_langstats_loaded = true;
    level.pintemod_langstats_version = "2.1.1";
    level.pintemod_langstats_reset_counter = 0;
    level.pintemod_langstats_reset_token = "";
    level.pintemod_langstats_reset_expires = 0;

    mkdir("pintemod");
    mkdir("pintemod/localization");
    mkdir(langstats_root());

    addcommand("ezzlangstats", ::cmd_ezzlangstats);

    if (!isdefined(level.pintemod_langstats_enabled))
        level.pintemod_langstats_enabled = true;

    if (level.pintemod_langstats_enabled)
        level thread langstats_bootstrap();

    println("^5[PinteMod]^7 Langstats v2.1.1 loaded");
}
