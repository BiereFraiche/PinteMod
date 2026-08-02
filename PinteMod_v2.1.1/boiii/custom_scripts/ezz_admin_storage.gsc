// ============================================================
// PinteMod — Safe Storage & Managed Logs v2.0.0
// Fichier : ezz_admin_storage.gsc
// Créé par BiereFraiche et ChatGPT
//
// Écritures JSON en deux phases, restauration du dernier fichier
// valide, quarantaine des JSON corrompus et rotation des journaux.
// Tous les chemins sont relatifs à boiii/scriptdata/.
// ============================================================

#namespace ezz_admin_storage;

function storage_is_alnum(character)
{
    return character == "a" || character == "b" ||
        character == "c" || character == "d" ||
        character == "e" || character == "f" ||
        character == "g" || character == "h" ||
        character == "i" || character == "j" ||
        character == "k" || character == "l" ||
        character == "m" || character == "n" ||
        character == "o" || character == "p" ||
        character == "q" || character == "r" ||
        character == "s" || character == "t" ||
        character == "u" || character == "v" ||
        character == "w" || character == "x" ||
        character == "y" || character == "z" ||
        character == "0" || character == "1" ||
        character == "2" || character == "3" ||
        character == "4" || character == "5" ||
        character == "6" || character == "7" ||
        character == "8" || character == "9";
}

function storage_safe_component(value)
{
    if (!isdefined(value) || value == "")
        return "unknown";

    text = toLower("" + value);
    result = "";

    for (i = 0; i < text.size; i++)
    {
        character = GetSubStr(text, i, i + 1);

        if (storage_is_alnum(character) ||
            character == "-" || character == "_")
        {
            result = result + character;
        }
        else
        {
            result = result + "_";
        }
    }

    if (result == "")
        return "unknown";

    return result;
}

function storage_starts_with(value, prefix)
{
    if (!isdefined(value) || !isdefined(prefix) ||
        value.size < prefix.size)
    {
        return false;
    }

    return GetSubStr(value, 0, prefix.size) == prefix;
}

function storage_json_is_valid(json)
{
    // BOIII's currently deployed helper returns true on parse error.
    return isdefined(json) && json != "" && !jsonvalid(json);
}

function storage_get_map_name()
{
    map_name = GetDvarString("mapname");

    if (!isdefined(map_name) || map_name == "")
        return "unknown";

    return storage_safe_component(map_name);
}

function storage_initialize()
{
    if (isdefined(level.pintemod_storage_initialized) &&
        level.pintemod_storage_initialized)
    {
        return;
    }

    level.pintemod_storage_initialized = true;
    level.pintemod_storage_version = "2.0.0";
    level.pintemod_storage_rotation_counter = 0;
    level.pintemod_storage_corrupt_counter = 0;

    mkdir("pintemod");
    mkdir("pintemod/logs");
    mkdir("pintemod/logs/sessions");
    mkdir("pintemod/backups");
    mkdir("pintemod/backups/corrupt");

    // GetTime() may restart with each map. A persistent counter prevents
    // two sessions on the same map from reusing the same log directory.
    level.pintemod_storage_session_id =
        "bootstrap_" + storage_get_map_name() + "_" + GetTime();
    mkdir(
        "pintemod/logs/sessions/" +
        level.pintemod_storage_session_id
    );

    counter_default = "{}";
    counter_default = jsonset(counter_default, "schema_version", "1");
    counter_default = jsonset(counter_default, "count", "0");
    counter_json = load_json_or_default(
        "pintemod/logs/session_counter.json",
        counter_default,
        "session-counter"
    );
    session_counter = 0;
    counter_value = jsonparse(counter_json, "count");

    if (isdefined(counter_value) && counter_value != "")
        session_counter = int(counter_value);

    if (session_counter < 0)
        session_counter = 0;

    session_counter++;
    counter_json = jsonset(counter_json, "schema_version", "1");
    counter_json = jsonset(counter_json, "count", "" + session_counter);

    if (!write_json_safe(
        "pintemod/logs/session_counter.json",
        counter_json,
        "session-counter"
    ))
    {
        println(
            "^3[PinteMod Storage]^7 SESSION_COUNTER_WRITE_FAILED" +
            " | fallback=GetTime"
        );
    }

    level.pintemod_storage_session_id =
        storage_get_map_name() + "_s" + session_counter +
        "_" + GetTime();
    mkdir(
        "pintemod/logs/sessions/" +
        level.pintemod_storage_session_id
    );
    mkdir(
        "pintemod/logs/sessions/" +
        level.pintemod_storage_session_id + "/chat"
    );
    mkdir(
        "pintemod/logs/sessions/" +
        level.pintemod_storage_session_id + "/votekick"
    );
    manifest = "{}";
    manifest = jsonset(manifest, "schema_version", "1");
    manifest = jsonset(manifest, "module_version", "2.0.0");
    manifest = jsonset(
        manifest,
        "session_id",
        level.pintemod_storage_session_id
    );
    manifest = jsonset(manifest, "map", storage_get_map_name());
    manifest = jsonset(manifest, "started_gettime", "" + GetTime());
    write_json_safe(
        "pintemod/logs/current_session.json",
        manifest,
        "session-manifest"
    );

    println("^5[PinteMod]^7 Storage v2.0.0 loaded");
}

function get_session_id()
{
    storage_initialize();
    return level.pintemod_storage_session_id;
}

function get_active_log_root()
{
    storage_initialize();
    return "pintemod/logs/sessions/" +
        level.pintemod_storage_session_id;
}

function storage_managed_log_path(path)
{
    storage_initialize();

    if (!isdefined(path) || path == "")
        return get_active_log_root() + "/misc.log";

    prefix = "pintemod/logs/";

    if (storage_starts_with(path, prefix))
    {
        relative = GetSubStr(path, prefix.size, path.size);
        return get_active_log_root() + "/" + relative;
    }

    if (storage_starts_with(path, "ezz_admin/"))
    {
        relative = GetSubStr(path, 10, path.size);
        return get_active_log_root() + "/legacy_" +
            storage_safe_component(relative) + ".log";
    }

    return get_active_log_root() + "/" +
        storage_safe_component(path) + ".log";
}


function log_xuid(value)
{
    if (isdefined(level.pintemod_log_xuids) &&
        !level.pintemod_log_xuids)
    {
        return "<hidden>";
    }

    if (!isdefined(value) || value == "")
        return "<unavailable>";

    return "" + value;
}

function log_guid(value)
{
    if (!isdefined(level.pintemod_log_guids) ||
        !level.pintemod_log_guids)
    {
        return "<hidden>";
    }

    if (!isdefined(value) || value == "")
        return "<unavailable>";

    return "" + value;
}

function storage_log_header()
{
    return "=== PinteMod session=" + get_session_id() +
        " map=" + storage_get_map_name() + " ===\n";
}


function storage_is_hex_character(character)
{
    character = toLower(character);
    return storage_is_alnum(character) &&
        (character == "0" || character == "1" ||
         character == "2" || character == "3" ||
         character == "4" || character == "5" ||
         character == "6" || character == "7" ||
         character == "8" || character == "9" ||
         character == "a" || character == "b" ||
         character == "c" || character == "d" ||
         character == "e" || character == "f");
}

function storage_redact_hex_identifiers(text)
{
    if (!isdefined(text) || text == "")
        return text;

    result = "";
    run = "";

    for (i = 0; i < text.size; i++)
    {
        character = GetSubStr(text, i, i + 1);

        if (storage_is_hex_character(character))
        {
            run = run + character;
            continue;
        }

        if (run.size >= 12 && run.size <= 32)
            result = result + "<hidden>";
        else
            result = result + run;

        run = "";
        result = result + character;
    }

    if (run.size >= 12 && run.size <= 32)
        result = result + "<hidden>";
    else
        result = result + run;

    return result;
}

function storage_index_of_from(text, needle, start_index)
{
    if (!isdefined(text) || !isdefined(needle) || needle == "")
        return -1;

    if (start_index < 0)
        start_index = 0;

    if (needle.size > text.size)
        return -1;

    for (position = start_index;
        position <= text.size - needle.size;
        position++)
    {
        if (GetSubStr(text, position, position + needle.size) == needle)
            return position;
    }

    return -1;
}

function storage_redact_named_field(text, field_name)
{
    if (!isdefined(text) || text == "")
        return text;

    lower_text = toLower(text);
    marker = toLower(field_name) + "=";
    result = "";
    cursor = 0;

    for (;;)
    {
        position = storage_index_of_from(lower_text, marker, cursor);

        if (position < 0)
        {
            result = result + GetSubStr(text, cursor, text.size);
            return result;
        }

        value_start = position + marker.size;
        result = result + GetSubStr(text, cursor, value_start);
        result = result + "<hidden>";
        value_end = value_start;

        while (value_end < text.size)
        {
            character = GetSubStr(text, value_end, value_end + 1);

            if (character == " " || character == "|" ||
                character == "]" || character == "," ||
                character == "\n" || character == "\r")
            {
                break;
            }

            value_end++;
        }

        cursor = value_end;
    }
}

function sanitize_log_text(text)
{
    sanitized = text;

    if (isdefined(level.pintemod_log_xuids) &&
        !level.pintemod_log_xuids)
    {
        sanitized = storage_redact_hex_identifiers(sanitized);
    }

    if (!isdefined(level.pintemod_log_guids) ||
        !level.pintemod_log_guids)
    {
        sanitized = storage_redact_named_field(sanitized, "guid");
    }

    return sanitized;
}

function storage_log_max_bytes()
{
    max_kb = 2048;

    if (isdefined(level.pintemod_log_max_size_kb))
        max_kb = level.pintemod_log_max_size_kb;

    if (max_kb < 64)
        max_kb = 64;

    return max_kb * 1024;
}

function storage_rotate_log_if_needed(path, incoming_size)
{
    if (!fileexists(path))
        return true;

    current_size = filesize(path);

    if (current_size < 0)
        current_size = 0;

    if (current_size + incoming_size <= storage_log_max_bytes())
        return true;

    level.pintemod_storage_rotation_counter++;
    rotated_path = path + "." + GetTime() + "_" +
        level.pintemod_storage_rotation_counter + ".rotated";
    previous = readfile(path);

    if (isdefined(previous) && previous != "")
    {
        if (!writefile(rotated_path, previous))
        {
            println(
                "^1[PinteMod Storage]^7 LOG_ROTATION_COPY_FAILED" +
                " | path=" + path
            );
            return false;
        }
    }

    if (!writefile(
        path,
        "=== PinteMod log rotated at GetTime " + GetTime() + " ===\n"
    ))
    {
        println(
            "^1[PinteMod Storage]^7 LOG_ROTATION_RESET_FAILED" +
            " | path=" + path
        );
        return false;
    }

    println(
        "^3[PinteMod Storage]^7 LOG_ROTATED | source=" + path +
        " | archive=" + rotated_path
    );
    return true;
}

function append_managed_log(path, text)
{
    storage_initialize();

    if (!isdefined(text) || text == "")
        return true;

    text = sanitize_log_text(text);
    managed_path = storage_managed_log_path(path);
    new_file = !fileexists(managed_path);

    if (!storage_rotate_log_if_needed(managed_path, text.size))
        return false;

    if (new_file)
    {
        if (!appendfile(managed_path, storage_log_header()))
            return false;
    }

    if (appendfile(managed_path, text))
        return true;

    println(
        "^1[PinteMod Storage]^7 LOG_WRITE_FAILED | path=" + managed_path
    );
    return false;
}

function write_managed_log(path, text)
{
    storage_initialize();

    if (!isdefined(text))
        text = "";

    text = sanitize_log_text(text);
    managed_path = storage_managed_log_path(path);
    output = storage_log_header() + text;

    if (!writefile(managed_path, output))
    {
        println(
            "^1[PinteMod Storage]^7 LOG_WRITE_FAILED | path=" + managed_path
        );
        return false;
    }

    return true;
}

function quarantine_corrupt(path, data, context)
{
    storage_initialize();
    level.pintemod_storage_corrupt_counter++;

    quarantine_path = "pintemod/backups/corrupt/" +
        storage_safe_component(path) + "_" +
        level.pintemod_storage_session_id + "_" +
        level.pintemod_storage_corrupt_counter + ".json";

    if (!isdefined(data))
        data = "";

    if (!writefile(quarantine_path, data))
    {
        println(
            "^1[PinteMod Storage]^7 CORRUPT_QUARANTINE_FAILED" +
            " | path=" + path + " | context=" + context
        );
        return "";
    }

    append_managed_log(
        "pintemod/logs/storage.log",
        "[" + GetTime() + "] CORRUPT_QUARANTINED" +
        " | source=" + path +
        " | quarantine=" + quarantine_path +
        " | context=" + context + "\n"
    );

    println(
        "^3[PinteMod Storage]^7 CORRUPT_QUARANTINED" +
        " | source=" + path +
        " | quarantine=" + quarantine_path
    );
    return quarantine_path;
}

function load_json_or_default(path, default_json, context)
{
    storage_initialize();

    if (!fileexists(path))
        return default_json;

    json = readfile(path);

    if (storage_json_is_valid(json))
        return json;

    quarantine_corrupt(path, json, context);

    backup_path = path + ".bak";

    if (fileexists(backup_path))
    {
        backup_json = readfile(backup_path);

        if (storage_json_is_valid(backup_json))
        {
            if (writefile(path, backup_json))
            {
                restored_json = readfile(path);

                if (restored_json == backup_json &&
                    storage_json_is_valid(restored_json))
                {
                    append_managed_log(
                        "pintemod/logs/storage.log",
                        "[" + GetTime() + "] JSON_RESTORED_FROM_BACKUP" +
                        " | path=" + path +
                        " | context=" + context + "\n"
                    );
                    return restored_json;
                }
            }
        }
        else if (isdefined(backup_json) && backup_json != "")
        {
            quarantine_corrupt(
                backup_path,
                backup_json,
                context + "-backup"
            );
            removefile(backup_path);
        }
    }

    // The invalid active file has already been preserved in quarantine.
    // Replace it with a verified neutral structure so later loads do not
    // repeatedly parse the same corruption.
    removefile(path);

    if (storage_json_is_valid(default_json))
    {
        if (!write_json_safe(
            path,
            default_json,
            context + "-default-recovery"
        ))
        {
            println(
                "^1[PinteMod Storage]^7 DEFAULT_RECOVERY_WRITE_FAILED" +
                " | path=" + path + " | context=" + context
            );
        }
    }

    return default_json;
}

function write_json_safe(path, json, context)
{
    storage_initialize();

    if (!storage_json_is_valid(json))
    {
        println(
            "^1[PinteMod Storage]^7 JSON_WRITE_REJECTED_INVALID_INPUT" +
            " | path=" + path + " | context=" + context
        );
        return false;
    }

    temp_path = path + ".tmp";
    backup_path = path + ".bak";
    old_exists = fileexists(path);
    old_data = "";

    if (old_exists)
        old_data = readfile(path);

    if (!writefile(temp_path, json))
    {
        println(
            "^1[PinteMod Storage]^7 JSON_TEMP_WRITE_FAILED" +
            " | path=" + path + " | context=" + context
        );
        return false;
    }

    temp_data = readfile(temp_path);

    if (temp_data != json || !storage_json_is_valid(temp_data))
    {
        quarantine_corrupt(temp_path, temp_data, context + "-temp");
        removefile(temp_path);
        return false;
    }

    if (old_exists && storage_json_is_valid(old_data))
    {
        if (!writefile(backup_path, old_data))
        {
            removefile(temp_path);
            println(
                "^1[PinteMod Storage]^7 JSON_BACKUP_WRITE_FAILED" +
                " | path=" + path + " | context=" + context
            );
            return false;
        }

        backup_data = readfile(backup_path);

        if (backup_data != old_data || !storage_json_is_valid(backup_data))
        {
            removefile(temp_path);
            println(
                "^1[PinteMod Storage]^7 JSON_BACKUP_VERIFY_FAILED" +
                " | path=" + path + " | context=" + context
            );
            return false;
        }
    }
    else if (old_exists && old_data != "")
    {
        quarantine_corrupt(path, old_data, context + "-previous");
    }

    if (!writefile(path, temp_data))
    {
        removefile(temp_path);
        println(
            "^1[PinteMod Storage]^7 JSON_ACTIVE_WRITE_FAILED" +
            " | path=" + path + " | context=" + context
        );
        return false;
    }

    active_data = readfile(path);

    if (active_data != json || !storage_json_is_valid(active_data))
    {
        quarantine_corrupt(path, active_data, context + "-active");

        if (old_exists && storage_json_is_valid(old_data))
            writefile(path, old_data);

        removefile(temp_path);
        println(
            "^1[PinteMod Storage]^7 JSON_ACTIVE_VERIFY_FAILED" +
            " | path=" + path + " | restored_previous=" + old_exists
        );
        return false;
    }

    removefile(temp_path);
    return true;
}


function storage_test_assert(result, condition, test_name, details)
{
    result.total++;

    if (condition)
    {
        result.passed++;
        println("^2[PASS]^7 " + test_name);
        return;
    }

    result.failed++;
    println("^1[FAIL]^7 " + test_name + " | " + details);
}

function storage_run_grouped_suite()
{
    storage_initialize();
    result = SpawnStruct();
    result.total = 0;
    result.passed = 0;
    result.failed = 0;

    println("^5===== PINTEMOD STORAGE GROUPED SUITE =====");

    mkdir("pintemod/storage_test");
    test_path = "pintemod/storage_test/state.json";
    temp_path = test_path + ".tmp";
    backup_path = test_path + ".bak";

    removefile(test_path);
    removefile(temp_path);
    removefile(backup_path);

    json_a = "{}";
    json_a = jsonset(json_a, "schema_version", "1");
    json_a = jsonset(json_a, "value", "alpha");
    json_b = jsonset(json_a, "value", "beta");

    storage_test_assert(
        result,
        write_json_safe(test_path, json_a, "storage-suite-first"),
        "01 verified first JSON write",
        "first safe write failed"
    );
    storage_test_assert(
        result,
        fileexists(test_path) && readfile(test_path) == json_a,
        "02 active JSON readback matches",
        "active file mismatch"
    );
    storage_test_assert(
        result,
        write_json_safe(test_path, json_b, "storage-suite-second") &&
        fileexists(backup_path) && readfile(backup_path) == json_a,
        "03 previous valid JSON backed up",
        "backup missing or mismatched"
    );

    corrupt_before = level.pintemod_storage_corrupt_counter;
    writefile(test_path, "{broken-json");
    recovered = load_json_or_default(
        test_path,
        "{}",
        "storage-suite-corrupt"
    );
    quarantine_path = "pintemod/backups/corrupt/" +
        storage_safe_component(test_path) + "_" +
        level.pintemod_storage_session_id + "_" +
        (corrupt_before + 1) + ".json";

    storage_test_assert(
        result,
        recovered == json_a,
        "04 corrupt active JSON restored from backup",
        "recovered JSON did not match last backup"
    );
    storage_test_assert(
        result,
        fileexists(quarantine_path),
        "05 corrupt source quarantined",
        "quarantine file missing"
    );
    storage_test_assert(
        result,
        storage_json_is_valid(readfile(test_path)),
        "06 restored active JSON validates",
        "active JSON is still invalid"
    );

    orphan_path = "pintemod/storage_test/orphan.json";
    orphan_backup = orphan_path + ".bak";
    removefile(orphan_path);
    removefile(orphan_backup);
    orphan_corrupt_before = level.pintemod_storage_corrupt_counter;
    writefile(orphan_path, "{orphan-broken-json");
    orphan_recovered = load_json_or_default(
        orphan_path,
        json_b,
        "storage-suite-orphan"
    );
    orphan_quarantine = "pintemod/backups/corrupt/" +
        storage_safe_component(orphan_path) + "_" +
        level.pintemod_storage_session_id + "_" +
        (orphan_corrupt_before + 1) + ".json";

    storage_test_assert(
        result,
        orphan_recovered == json_b,
        "07 corrupt JSON without backup returns neutral default",
        "returned default mismatch"
    );
    storage_test_assert(
        result,
        fileexists(orphan_quarantine),
        "08 corrupt JSON without backup is quarantined",
        "orphan quarantine file missing"
    );
    storage_test_assert(
        result,
        fileexists(orphan_path) && readfile(orphan_path) == json_b &&
        storage_json_is_valid(readfile(orphan_path)),
        "09 neutral default is rewritten and verified",
        "recovered active file is missing or invalid"
    );

    removefile(test_path);
    removefile(temp_path);
    removefile(backup_path);
    removefile(quarantine_path);
    removefile(orphan_path);
    removefile(orphan_backup);
    removefile(orphan_quarantine);

    storage_test_assert(
        result,
        !fileexists(test_path) && !fileexists(temp_path) &&
        !fileexists(backup_path) && !fileexists(quarantine_path) &&
        !fileexists(orphan_path) && !fileexists(orphan_backup) &&
        !fileexists(orphan_quarantine),
        "10 TEST artifacts cleaned",
        "one or more storage test files remain"
    );

    println(
        "^5[PinteMod Storage]^7 RESULT " +
        result.passed + "/" + result.total + " PASS" +
        " | failed=" + result.failed
    );
    println("^5==========================================");
    return result;
}

function cmd_ezzstoragetest(args)
{
    if (args.size <= 0 || toLower(args[0]) != "suite")
    {
        println("^3[PinteMod Storage]^7 Usage: ezzstoragetest suite");
        return;
    }

    storage_run_grouped_suite();
}

function cmd_ezzstoragestatus(args)
{
    storage_initialize();
    println("^5===== PINTEMOD STORAGE v2.0.0 =====");
    println("^7Session: " + level.pintemod_storage_session_id);
    println("^7Map: " + storage_get_map_name());
    println("^7Log root: boiii/scriptdata/" + get_active_log_root());
    println("^7Log max size: " + storage_log_max_bytes() + " bytes/file");
    println("^7JSON strategy: temp verify + .bak + restore/quarantine");
    println("^7Corrupt quarantine: boiii/scriptdata/pintemod/backups/corrupt/");
    println("^5====================================");
}

autoexec function init()
{
    storage_initialize();
    addcommand("ezzstoragestatus", ::cmd_ezzstoragestatus);
    addcommand("ezzstoragetest", ::cmd_ezzstoragetest);
}
