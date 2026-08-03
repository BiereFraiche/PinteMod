#using custom_scripts\ezz_admin_identity;
#using custom_scripts\ezz_admin_storage;
#using custom_scripts\ezz_admin_registry;

// ============================================================
// PinteMod Ranks & Records v2.0.0
// Fichier : ezz_admin_ranks.gsc
//
// Classements persistants par BOIII_XUID stable (fail-closed).
// - Activité totale et nombre de sessions
// - Meilleur round personnel
// - Top 5 des records par map, séparés en catégories 1P à 4P
// - Anciennes données v1 par pseudo conservées, jamais fusionnées automatiquement
// ============================================================

function ranks_private(player, message)
{
    if (isdefined(player))
        player iprintln(message);
}

function ranks_log_file(message)
{
    if (!ezz_admin_storage::append_managed_log(
        "pintemod/logs/ranks.log",
        "[" + GetTime() + "] " + message + "\n"
    ))
    {
        println(
            "^1[PinteMod Ranks]^7 WRITE_FAILED | " +
            "path=pintemod/logs/ranks.log"
        );
    }
}

function ranks_log(message)
{
    if (isdefined(level.pintemod_server_console_verbose) &&
        level.pintemod_server_console_verbose)
    {
        println("^5[PinteMod Ranks]^7 " + message);
    }

    ranks_log_file(message);
}

function ranks_broadcast_chat(message, event_name, live_console_message)
{
    if (!isdefined(message) || message == "")
        return;

    ExecuteCommand("say " + message);

    if (!isdefined(event_name) || event_name == "")
        event_name = "RECORD_CHAT";

    if (!isdefined(live_console_message) || live_console_message == "")
        live_console_message = message;

    // PinteMod Live Console v1.3 surveille community.log, pas ranks.log.
    // On conserve le journal spécialisé et on duplique uniquement les
    // annonces de records vers la source déjà suivie par la Live Console.
    live_console_written = ezz_admin_storage::append_managed_log(
        "pintemod/logs/community.log",
        "[" + GetTime() + "] RANKS | " + event_name +
        " | " + live_console_message + "\n"
    );

    if (!live_console_written)
    {
        println(
            "^1[PinteMod Ranks]^7 LIVE_CONSOLE_WRITE_FAILED" +
            " | pintemod/logs/community.log"
        );
    }

    ranks_log(event_name + " | " + live_console_message);
}

autoexec function init()
{
    addcommand("ezzrank", ::cmd_ezzrank);
    addcommand("ezzranks", ::cmd_ezzranks);
    addcommand("ezzrecords", ::cmd_ezzrecords);
    addcommand("ezzrankstatus", ::cmd_ezzrankstatus);
    addcommand("ezzrankmigrationstatus", ::cmd_ezzrankmigrationstatus);
    addcommand("ezzranktest", ::cmd_ezzranktest);
    addcommand("ezzrankaudit", ::cmd_ezzrankaudit);
    addcommand("ezzrankbackup", ::cmd_ezzrankbackup);
    addcommand("ezzrankreset", ::cmd_ezzrankreset);

    mkdir("pintemod");
    mkdir("pintemod/logs");
    mkdir("pintemod/ranks_v2");
    mkdir("pintemod/ranks_v2/players");
    mkdir("pintemod/ranks_v2/maps");
    mkdir("pintemod/ranks_v2/test");
    mkdir("pintemod/backups");
    mkdir("pintemod/backups/ranks_v2");

    level.pintemod_ranks_version = "2.0.0";
    level.pintemod_ranks_identity_kind = "BOIII_XUID";
    level.pintemod_ranks_player_schema_version = 2;
    level.pintemod_ranks_enabled = true;
    level.pintemod_ranks_last_round = -1;
    level.pintemod_ranks_match_started = false;
    level.pintemod_ranks_match_elapsed_seconds = 0;
    level.pintemod_ranks_record_presence_percent = 70;
    level.pintemod_ranks_activity_flush_seconds = 10;
    level.pintemod_ranks_map_schema_version = 4;
    level.pintemod_ranks_max_records_per_category = 5;
    level.pintemod_ranks_match_record_id = "";
    level.pintemod_ranks_match_map_baseline_json = "";
    level.pintemod_ranks_record_announcement_min_round = 5;
    level.pintemod_ranks_match_ranked = true;
    level.pintemod_ranks_unranked_command = "";
    level.pintemod_ranks_unranked_target = "";
    level.pintemod_ranks_participants = [];
    level.pintemod_ranks_team_record_announced = [];
    level.pintemod_ranks_reset_token = "";
    level.pintemod_ranks_reset_token_expires = 0;
    level.pintemod_ranks_reset_backup_id = 0;

    if (!isdefined(level.pintemod_gameplay_command_pending))
        level.pintemod_gameplay_command_pending = false;

    if (!isdefined(level.pintemod_gameplay_command_name))
        level.pintemod_gameplay_command_name = "";

    if (!isdefined(level.pintemod_gameplay_command_target))
        level.pintemod_gameplay_command_target = "";

    for (team_size = 0; team_size <= 4; team_size++)
        level.pintemod_ranks_team_record_announced[team_size] = false;

    ranks_remove_outdated_map_records();

    level thread ranks_monitor();
    level thread ranks_unranked_command_monitor();
    level thread ranks_game_ended_flush_monitor();
    level thread ranks_end_game_flush_monitor();

    println("^5[PinteMod]^7 Ranks v2.0.0 loaded");
    ranks_log_file(
        "MODULE_LOADED | version=2.0.0" +
        " | identity=BOIII_XUID" +
        " | player_schema=2" +
        " | map_schema=4" +
        " | active_root=pintemod/ranks_v2" +
        " | legacy_root_preserved=pintemod/ranks" +
        " | record_presence_required=70%" +
        " | activity_flush_seconds=10" +
        " | max_records_per_category=5"
    );
}

// ------------------------------------------------------------
// Generic helpers
// ------------------------------------------------------------

function ranks_join_args(args, start_index)
{
    result = "";

    for (i = start_index; i < args.size; i++)
    {
        if (result != "")
            result = result + " ";

        result = result + args[i];
    }

    return result;
}

function ranks_join_args_until(args, start_index, end_index)
{
    result = "";

    if (end_index > args.size)
        end_index = args.size;

    for (i = start_index; i < end_index; i++)
    {
        if (result != "")
            result = result + " ";

        result = result + args[i];
    }

    return result;
}

function ranks_find_player(player_name)
{
    return ezz_admin_identity::identity_find_player(player_name);
}

function ranks_is_safe_char(character)
{
    switch (character)
    {
        case "a":
        case "b":
        case "c":
        case "d":
        case "e":
        case "f":
        case "g":
        case "h":
        case "i":
        case "j":
        case "k":
        case "l":
        case "m":
        case "n":
        case "o":
        case "p":
        case "q":
        case "r":
        case "s":
        case "t":
        case "u":
        case "v":
        case "w":
        case "x":
        case "y":
        case "z":
        case "0":
        case "1":
        case "2":
        case "3":
        case "4":
        case "5":
        case "6":
        case "7":
        case "8":
        case "9":
        case "_":
        case "-":
            return true;
    }

    return false;
}

function ranks_player_key(player_name)
{
    lower_name = toLower(player_name);
    result = "";

    for (i = 0; i < lower_name.size; i++)
    {
        character = GetSubStr(lower_name, i, i + 1);

        if (ranks_is_safe_char(character))
            result = result + character;
        else
            result = result + "_";
    }

    if (result == "")
        result = "unknown_player";

    return result;
}

function ranks_data_root()
{
    return "pintemod/ranks_v2";
}

function ranks_players_directory()
{
    return ranks_data_root() + "/players";
}

function ranks_maps_directory()
{
    return ranks_data_root() + "/maps";
}

function ranks_legacy_root()
{
    return "pintemod/ranks";
}

function ranks_get_player_xuid(player)
{
    if (!isdefined(player))
        return "";

    xuid = ezz_admin_identity::get_player_xuid(player);

    if (!ezz_admin_identity::is_valid_xuid(xuid))
        return "";

    return ezz_admin_identity::normalize_xuid(xuid);
}

function ranks_player_key_from_xuid(xuid)
{
    normalized = ezz_admin_identity::normalize_xuid(xuid);

    if (!ezz_admin_identity::is_valid_xuid(normalized))
        return "";

    return normalized;
}

function ranks_player_path_from_name(player_name)
{
    // Compatibility export only. Pseudo-based persistence is disabled.
    return "";
}

function ranks_player_path_from_xuid(xuid)
{
    key = ranks_player_key_from_xuid(xuid);

    if (key == "")
        return "";

    return ranks_players_directory() + "/" + key + ".json";
}

function ranks_player_path(player)
{
    return ranks_player_path_from_xuid(ranks_get_player_xuid(player));
}


function ranks_map_path(map_name)
{
    return ranks_maps_directory() + "/" + map_name + ".json";
}


// Current BOIII implementation returns true when JSON has a parse error.
function ranks_json_int(json, key_name, default_value)
{
    if (!isdefined(json) || json == "" || jsonvalid(json))
        return default_value;

    value = jsonparse(json, key_name);

    if (!isdefined(value) || value == "")
        return default_value;

    return int(value);
}

function ranks_json_string(json, key_name, default_value)
{
    if (!isdefined(json) || json == "" || jsonvalid(json))
        return default_value;

    value = jsonparse(json, key_name);

    if (!isdefined(value) || value == "")
        return default_value;

    return value;
}

function ranks_write_json(path, json, context)
{
    if (ezz_admin_storage::write_json_safe(path, json, context))
        return true;

    ranks_log(
        "WRITE_FAILED | path=" + path +
        " | context=" + context
    );

    return false;
}

function ranks_load_json(path)
{
    return ezz_admin_storage::load_json_or_default(
        path,
        "{}",
        "ranks-json"
    );
}

function ranks_format_duration(seconds)
{
    if (seconds < 0)
        seconds = 0;

    hours = int(seconds / 3600);
    minutes = int(seconds / 60) - (hours * 60);

    if (hours > 0)
        return hours + "h " + minutes + "m";

    return minutes + "m";
}

function ranks_format_record_duration(seconds)
{
    if (seconds < 0)
        seconds = 0;

    hours = int(seconds / 3600);
    minutes = int(seconds / 60) - (hours * 60);
    remaining_seconds = seconds - (hours * 3600) - (minutes * 60);

    if (hours > 0)
        return hours + "h " + minutes + "m " + remaining_seconds + "s";

    return minutes + "m " + remaining_seconds + "s";
}

function ranks_get_map_name()
{
    map_name = GetDvarString("mapname");

    if (!isdefined(map_name) || map_name == "")
        return "unknown";

    return map_name;
}

function ranks_get_map_display(map_name)
{
    return ezz_admin_registry::get_map_display_name(map_name);
}


function ranks_map_record_key(field_name, team_size, position)
{
    return field_name + "_" + team_size + "p_" + position;
}

function ranks_create_default_map_json(map_name)
{
    json = "{}";
    json = jsonset(
        json,
        "schema_version",
        "" + level.pintemod_ranks_map_schema_version
    );
    json = jsonset(json, "identity_kind", level.pintemod_ranks_identity_kind);
    json = jsonset(json, "map", map_name);
    json = jsonset(json, "display", ranks_get_map_display(map_name));
    json = jsonset(json, "next_run_id", "1");

    for (team_size = 1; team_size <= 4; team_size++)
    {
        for (position = 1;
            position <= level.pintemod_ranks_max_records_per_category;
            position++)
        {
            json = jsonset(
                json,
                ranks_map_record_key("round", team_size, position),
                "0"
            );
            json = jsonset(
                json,
                ranks_map_record_key("seconds", team_size, position),
                "0"
            );
            json = jsonset(
                json,
                ranks_map_record_key("holders", team_size, position),
                ""
            );
            json = jsonset(
                json,
                ranks_map_record_key("holder_xuids", team_size, position),
                ""
            );
            json = jsonset(
                json,
                ranks_map_record_key("match_id", team_size, position),
                ""
            );
        }
    }

    return json;
}


function ranks_load_map_json(map_name)
{
    path = ranks_map_path(map_name);

    if (!fileexists(path))
        return ranks_create_default_map_json(map_name);

    json = ranks_load_json(path);
    schema_version = ranks_json_int(json, "schema_version", 0);
    identity_kind = ranks_json_string(json, "identity_kind", "");

    if (schema_version != level.pintemod_ranks_map_schema_version ||
        identity_kind != level.pintemod_ranks_identity_kind)
    {
        fresh_json = ranks_create_default_map_json(map_name);
        ranks_write_json(path, fresh_json, "map-schema-reset");

        ranks_log(
            "OUTDATED_MAP_RECORD_RESET | map=" + map_name +
            " | old_schema=" + schema_version +
            " | old_identity=" + identity_kind
        );

        return fresh_json;
    }

    return json;
}


function ranks_create_record(
    round_number,
    seconds,
    holders,
    holder_xuids,
    match_id
)
{
    record = SpawnStruct();
    record.round = round_number;
    record.seconds = seconds;
    record.holders = holders;
    record.holder_xuids = holder_xuids;
    record.match_id = match_id;
    return record;
}


function ranks_load_record(json, team_size, position)
{
    round_number = ranks_json_int(
        json,
        ranks_map_record_key("round", team_size, position),
        0
    );

    if (round_number <= 0)
        return undefined;

    return ranks_create_record(
        round_number,
        ranks_json_int(
            json,
            ranks_map_record_key("seconds", team_size, position),
            0
        ),
        ranks_json_string(
            json,
            ranks_map_record_key("holders", team_size, position),
            "Unknown"
        ),
        ranks_json_string(
            json,
            ranks_map_record_key("holder_xuids", team_size, position),
            ""
        ),
        ranks_json_string(
            json,
            ranks_map_record_key("match_id", team_size, position),
            ""
        )
    );
}


function ranks_record_is_better(candidate, existing)
{
    if (!isdefined(existing))
        return true;

    if (candidate.round > existing.round)
        return true;

    if (candidate.round < existing.round)
        return false;

    if (candidate.seconds <= 0)
        return false;

    if (existing.seconds <= 0)
        return true;

    return candidate.seconds < existing.seconds;
}

function ranks_load_category_records(json, team_size, excluded_match_id)
{
    records = [];

    for (position = 1;
        position <= level.pintemod_ranks_max_records_per_category;
        position++)
    {
        record = ranks_load_record(json, team_size, position);

        if (!isdefined(record))
            continue;

        if (excluded_match_id != "" &&
            record.match_id == excluded_match_id)
        {
            continue;
        }

        records[records.size] = record;
    }

    return records;
}

function ranks_insert_record_top(records, candidate, maximum)
{
    result = [];
    inserted = false;

    for (i = 0; i < records.size; i++)
    {
        existing = records[i];

        if (!inserted && ranks_record_is_better(candidate, existing))
        {
            result[result.size] = candidate;
            inserted = true;
        }

        if (result.size < maximum)
            result[result.size] = existing;
    }

    if (!inserted && result.size < maximum)
        result[result.size] = candidate;

    return result;
}

function ranks_write_category_records(json, team_size, records)
{
    for (position = 1;
        position <= level.pintemod_ranks_max_records_per_category;
        position++)
    {
        index = position - 1;
        round_number = 0;
        seconds = 0;
        holders = "";
        holder_xuids = "";
        match_id = "";

        if (index < records.size && isdefined(records[index]))
        {
            record = records[index];
            round_number = record.round;
            seconds = record.seconds;
            holders = record.holders;
            holder_xuids = record.holder_xuids;
            match_id = record.match_id;
        }

        json = jsonset(
            json,
            ranks_map_record_key("round", team_size, position),
            "" + round_number
        );
        json = jsonset(
            json,
            ranks_map_record_key("seconds", team_size, position),
            "" + seconds
        );
        json = jsonset(
            json,
            ranks_map_record_key("holders", team_size, position),
            holders
        );
        json = jsonset(
            json,
            ranks_map_record_key("holder_xuids", team_size, position),
            holder_xuids
        );
        json = jsonset(
            json,
            ranks_map_record_key("match_id", team_size, position),
            match_id
        );
    }

    return json;
}


function ranks_find_record_position(records, match_id)
{
    if (!isdefined(records) || match_id == "")
        return -1;

    for (i = 0; i < records.size; i++)
    {
        if (isdefined(records[i]) && records[i].match_id == match_id)
            return i;
    }

    return -1;
}

function ranks_ensure_match_record_id(map_name)
{
    if (isdefined(level.pintemod_ranks_match_record_id) &&
        level.pintemod_ranks_match_record_id != "")
    {
        return;
    }

    path = ranks_map_path(map_name);
    json = ranks_load_map_json(map_name);
    next_run_id = ranks_json_int(json, "next_run_id", 1);

    if (next_run_id < 1)
        next_run_id = 1;

    candidate_match_id = map_name + "_run_" + next_run_id;
    json = jsonset(json, "next_run_id", "" + (next_run_id + 1));

    if (!ranks_write_json(path, json, "map-record-id"))
        return;

    level.pintemod_ranks_match_record_id = candidate_match_id;

    ranks_log(
        "MATCH_RECORD_ID | map=" + map_name +
        " | id=" + level.pintemod_ranks_match_record_id
    );
}

function ranks_resolve_listed_path(entry, fallback_directory)
{
    if (!isdefined(entry) || entry == "")
        return "";

    // BOIII ls() returns paths relative to boiii/scriptdata.
    if (entry.size >= 8 && GetSubStr(entry, 0, 8) == "pintemod")
        return entry;

    return fallback_directory + "/" + entry;
}

function ranks_remove_outdated_map_records()
{
    entries = ls(ranks_maps_directory(), false, false);

    if (!isdefined(entries))
        return;

    for (i = 0; i < entries.size; i++)
    {
        path = ranks_resolve_listed_path(
            entries[i],
            ranks_maps_directory()
        );

        if (path == "" || !fileexists(path))
            continue;

        json = ranks_load_json(path);
        schema_version = ranks_json_int(json, "schema_version", 0);
        identity_kind = ranks_json_string(json, "identity_kind", "");

        if (schema_version == level.pintemod_ranks_map_schema_version &&
            identity_kind == level.pintemod_ranks_identity_kind)
        {
            continue;
        }

        removefile(path);

        ranks_log(
            "OUTDATED_MAP_RECORD_REMOVED | path=" + path +
            " | old_schema=" + schema_version +
            " | old_identity=" + identity_kind
        );
    }
}


function ranks_find_participant_index_by_key(player_key)
{
    if (!isdefined(player_key) || player_key == "")
        return -1;

    for (i = 0; i < level.pintemod_ranks_participants.size; i++)
    {
        participant = level.pintemod_ranks_participants[i];

        if (isdefined(participant) && participant.key == player_key)
            return i;
    }

    return -1;
}

function ranks_get_or_create_participant(player)
{
    if (!isdefined(player))
        return undefined;

    xuid = ranks_get_player_xuid(player);

    if (xuid == "")
        return undefined;

    participant_index = ranks_find_participant_index_by_key(xuid);

    if (participant_index >= 0)
    {
        participant = level.pintemod_ranks_participants[participant_index];
        participant.name = player.name;
        participant.xuid = xuid;
        participant.connected = true;
        return participant;
    }

    participant = SpawnStruct();
    participant.key = xuid;
    participant.xuid = xuid;
    participant.name = player.name;
    participant.connected = true;
    participant.has_played = false;
    participant.present_seconds = 0;
    participant.eligibility_logged = false;
    participant.personal_record_announced = false;
    participant.personal_baseline_set = false;
    participant.personal_baseline_map = "";
    participant.personal_baseline_round = 0;
    participant.personal_baseline_overall_round = 0;

    level.pintemod_ranks_participants[
        level.pintemod_ranks_participants.size
    ] = participant;

    return participant;
}


function ranks_get_player_participant(player)
{
    if (!isdefined(player))
        return undefined;

    player_key = ranks_get_player_xuid(player);

    if (isdefined(player.pintemod_rank_participant_key))
        player_key = player.pintemod_rank_participant_key;

    participant_index = ranks_find_participant_index_by_key(player_key);

    if (participant_index < 0)
        return undefined;

    return level.pintemod_ranks_participants[participant_index];
}


function ranks_get_presence_percent_from_seconds(present_seconds)
{
    if (!isdefined(present_seconds) ||
        !isdefined(level.pintemod_ranks_match_elapsed_seconds) ||
        level.pintemod_ranks_match_elapsed_seconds <= 0)
    {
        return 0;
    }

    percentage = int(
        (present_seconds * 100) /
        level.pintemod_ranks_match_elapsed_seconds
    );

    if (percentage > 100)
        percentage = 100;

    if (percentage < 0)
        percentage = 0;

    return percentage;
}

function ranks_is_record_eligible_participant(participant)
{
    if (!isdefined(level.pintemod_ranks_match_ranked) ||
        !level.pintemod_ranks_match_ranked)
    {
        return false;
    }

    if (!isdefined(participant) ||
        !isdefined(participant.has_played) ||
        !participant.has_played)
    {
        return false;
    }

    return ranks_get_presence_percent_from_seconds(
        participant.present_seconds
    ) >= level.pintemod_ranks_record_presence_percent;
}

function ranks_get_round()
{
    if (isdefined(level.round_number))
        return int(level.round_number);

    return 0;
}

function ranks_is_active_player(player)
{
    if (!isdefined(player))
        return false;

    if (!isdefined(player.sessionstate))
        return false;

    return player.sessionstate != "spectator";
}

function ranks_get_presence_percent(player)
{
    participant = ranks_get_player_participant(player);

    if (!isdefined(participant))
        return 0;

    return ranks_get_presence_percent_from_seconds(
        participant.present_seconds
    );
}

function ranks_is_record_eligible_player(player)
{
    participant = ranks_get_player_participant(player);
    return ranks_is_record_eligible_participant(participant);
}


function ranks_find_connected_player_for_participant(participant)
{
    if (!isdefined(participant) ||
        !isdefined(participant.xuid) ||
        participant.xuid == "")
    {
        return undefined;
    }

    players = GetPlayers();

    for (i = 0; i < players.size; i++)
    {
        player = players[i];

        if (!isdefined(player))
            continue;

        player_xuid = ranks_get_player_xuid(player);

        if (player_xuid == participant.xuid)
            return player;
    }

    return undefined;
}


// ------------------------------------------------------------
// Player persistence
// ------------------------------------------------------------

function ranks_create_default_player_json(xuid, player_name)
{
    json = "{}";
    json = jsonset(
        json,
        "schema_version",
        "" + level.pintemod_ranks_player_schema_version
    );
    json = jsonset(json, "identity_kind", level.pintemod_ranks_identity_kind);
    json = jsonset(json, "xuid", xuid);
    json = jsonset(json, "key", xuid);
    json = jsonset(json, "name", player_name);
    json = jsonset(json, "last_name", player_name);
    json = jsonset(json, "total_seconds", "0");
    json = jsonset(json, "sessions", "0");
    json = jsonset(json, "best_overall_round", "0");
    return json;
}


function ranks_save_player(player)
{
    if (!isdefined(player) ||
        !isdefined(player.pintemod_rank_json) ||
        !isdefined(player.pintemod_rank_path) ||
        !isdefined(player.pintemod_rank_xuid))
    {
        return;
    }

    player.pintemod_rank_json = jsonset(
        player.pintemod_rank_json,
        "schema_version",
        "" + level.pintemod_ranks_player_schema_version
    );
    player.pintemod_rank_json = jsonset(
        player.pintemod_rank_json,
        "identity_kind",
        level.pintemod_ranks_identity_kind
    );
    player.pintemod_rank_json = jsonset(
        player.pintemod_rank_json,
        "xuid",
        player.pintemod_rank_xuid
    );
    player.pintemod_rank_json = jsonset(
        player.pintemod_rank_json,
        "key",
        player.pintemod_rank_xuid
    );
    player.pintemod_rank_json = jsonset(
        player.pintemod_rank_json,
        "name",
        player.name
    );
    player.pintemod_rank_json = jsonset(
        player.pintemod_rank_json,
        "last_name",
        player.name
    );

    ranks_write_json(
        player.pintemod_rank_path,
        player.pintemod_rank_json,
        "player-save"
    );
}


function ranks_attach_player(player)
{
    if (!isdefined(player))
        return false;

    if (isdefined(player.pintemod_rank_attached) &&
        player.pintemod_rank_attached)
    {
        return true;
    }

    xuid = ranks_get_player_xuid(player);

    if (xuid == "")
    {
        if (!isdefined(player.pintemod_rank_identity_unavailable_logged) ||
            !player.pintemod_rank_identity_unavailable_logged)
        {
            player.pintemod_rank_identity_unavailable_logged = true;
            ranks_log(
                "IDENTITY_UNAVAILABLE | player=" + player.name +
                " | client=" + player GetEntityNumber() +
                " | persistence=disabled"
            );
        }

        return false;
    }

    participant = ranks_get_or_create_participant(player);

    if (!isdefined(participant))
        return false;

    path = ranks_player_path_from_xuid(xuid);
    json = ranks_load_json(path);

    if (json == "{}" ||
        ranks_json_int(json, "schema_version", 0) !=
            level.pintemod_ranks_player_schema_version ||
        ranks_json_string(json, "identity_kind", "") !=
            level.pintemod_ranks_identity_kind ||
        ezz_admin_identity::normalize_xuid(
            ranks_json_string(json, "xuid", "")
        ) != xuid)
    {
        json = ranks_create_default_player_json(xuid, player.name);
    }

    player.pintemod_rank_attached = true;
    player.pintemod_rank_identity_unavailable_logged = false;
    player.pintemod_rank_xuid = xuid;
    player.pintemod_rank_has_played = participant.has_played;
    player.pintemod_rank_match_present_seconds = participant.present_seconds;
    player.pintemod_rank_pending_seconds = 0;
    player.pintemod_rank_session_counted = false;
    player.pintemod_rank_eligibility_logged = participant.eligibility_logged;
    player.pintemod_rank_participant_key = participant.key;
    player.pintemod_rank_path = path;
    player.pintemod_rank_json = json;

    ranks_save_player(player);
    player thread ranks_disconnect_monitor();

    ranks_log(
        "PLAYER_ATTACHED | " + player.name +
        " | xuid=" + xuid +
        " | session_waiting_for_gameplay=true" +
        " | restored_presence_seconds=" + participant.present_seconds
    );

    return true;
}


function ranks_disconnect_monitor()
{
    player_key = ranks_get_player_xuid(self);

    if (isdefined(self.pintemod_rank_participant_key))
        player_key = self.pintemod_rank_participant_key;

    self waittill("disconnect");
    ranks_flush_player_activity(self, "disconnect");

    participant_index = ranks_find_participant_index_by_key(player_key);

    if (participant_index < 0)
        return;

    participant = level.pintemod_ranks_participants[participant_index];
    participant.connected = false;

    ranks_log(
        "PLAYER_DISCONNECTED | " + participant.name +
        " | xuid=" + participant.xuid +
        " | presence_seconds=" + participant.present_seconds +
        " | current_presence=" +
        ranks_get_presence_percent_from_seconds(
            participant.present_seconds
        ) + "%"
    );
}


function ranks_start_player_session(player)
{
    if (!isdefined(player) ||
        !isdefined(player.pintemod_rank_json) ||
        (isdefined(player.pintemod_rank_session_counted) &&
            player.pintemod_rank_session_counted))
    {
        return;
    }

    player.pintemod_rank_session_counted = true;

    sessions = ranks_json_int(
        player.pintemod_rank_json,
        "sessions",
        0
    ) + 1;

    player.pintemod_rank_json = jsonset(
        player.pintemod_rank_json,
        "sessions",
        "" + sessions
    );

    ranks_save_player(player);

    ranks_log(
        "SESSION_STARTED | " + player.name +
        " | xuid=" + player.pintemod_rank_xuid +
        " | sessions=" + sessions
    );
}


function ranks_flush_player_activity(player, reason)
{
    if (!isdefined(player) ||
        !isdefined(player.pintemod_rank_pending_seconds) ||
        player.pintemod_rank_pending_seconds <= 0)
    {
        return;
    }

    seconds = player.pintemod_rank_pending_seconds;
    player.pintemod_rank_pending_seconds = 0;
    ranks_add_activity(player, seconds);

    if (reason != "periodic")
    {
        ranks_log(
            "ACTIVITY_FLUSH | " + player.name +
            " | seconds=" + seconds +
            " | reason=" + reason
        );
    }
}

function ranks_flush_all_pending(reason)
{
    players = GetPlayers();

    for (i = 0; i < players.size; i++)
        ranks_flush_player_activity(players[i], reason);
}

function ranks_game_ended_flush_monitor()
{
    level waittill("game_ended");
    ranks_flush_all_pending("game_ended");
}

function ranks_end_game_flush_monitor()
{
    level waittill("end_game");
    ranks_flush_all_pending("end_game");
}

function ranks_add_activity(player, seconds)
{
    if (!isdefined(player) || !isdefined(player.pintemod_rank_json))
        return;

    total_seconds = ranks_json_int(
        player.pintemod_rank_json,
        "total_seconds",
        0
    ) + seconds;

    player.pintemod_rank_json = jsonset(
        player.pintemod_rank_json,
        "total_seconds",
        "" + total_seconds
    );

    ranks_save_player(player);
}


function ranks_announce_personal_record(participant, map_name, round_number)
{
    if (!isdefined(participant) ||
        !participant.personal_baseline_set ||
        participant.personal_record_announced ||
        participant.personal_baseline_round <= 0 ||
        round_number <= participant.personal_baseline_round ||
        round_number < level.pintemod_ranks_record_announcement_min_round)
    {
        return;
    }

    participant.personal_record_announced = true;

    message = "^5[PinteMod Records]^7 ^3" + participant.name +
        " ^7beat their personal record on ^3" +
        ranks_get_map_display(map_name) +
        "^7: Round ^2" + round_number +
        " ^7(previous: " + participant.personal_baseline_round + ")";

    live_console_message = participant.name +
        " beat their personal record on " +
        ranks_get_map_display(map_name) +
        ": Round " + round_number +
        " (previous: " + participant.personal_baseline_round + ")";

    ranks_broadcast_chat(
        message,
        "PERSONAL_RECORD_CHAT",
        live_console_message
    );

    ranks_log(
        "PERSONAL_RECORD | player=" + participant.name +
        " | map=" + map_name +
        " | previous_round=" + participant.personal_baseline_round +
        " | new_round=" + round_number
    );
}

function ranks_update_personal_round(player, map_name, round_number)
{
    if (!isdefined(player) || !isdefined(player.pintemod_rank_json))
        return;

    map_key = "best_" + map_name;
    map_best = ranks_json_int(player.pintemod_rank_json, map_key, 0);
    overall_best = ranks_json_int(
        player.pintemod_rank_json,
        "best_overall_round",
        0
    );
    participant = ranks_get_player_participant(player);
    changed = false;

    if (round_number > map_best)
    {
        player.pintemod_rank_json = jsonset(
            player.pintemod_rank_json,
            map_key,
            "" + round_number
        );
        changed = true;
    }

    if (round_number > overall_best)
    {
        player.pintemod_rank_json = jsonset(
            player.pintemod_rank_json,
            "best_overall_round",
            "" + round_number
        );
        changed = true;
    }

    if (changed)
        ranks_save_player(player);

    ranks_announce_personal_record(
        participant,
        map_name,
        round_number
    );
}

function ranks_update_offline_personal_round(
    participant,
    map_name,
    round_number
)
{
    if (!isdefined(participant) ||
        !isdefined(participant.xuid) ||
        participant.xuid == "")
    {
        return;
    }

    path = ranks_player_path_from_xuid(participant.xuid);
    json = ranks_load_json(path);

    if (json == "{}")
    {
        json = ranks_create_default_player_json(
            participant.xuid,
            participant.name
        );
    }

    map_key = "best_" + map_name;
    map_best = ranks_json_int(json, map_key, 0);
    overall_best = ranks_json_int(json, "best_overall_round", 0);
    changed = false;

    if (round_number > map_best)
    {
        json = jsonset(json, map_key, "" + round_number);
        changed = true;
    }

    if (round_number > overall_best)
    {
        json = jsonset(
            json,
            "best_overall_round",
            "" + round_number
        );
        changed = true;
    }

    if (changed)
    {
        json = jsonset(json, "name", participant.name);
        json = jsonset(json, "last_name", participant.name);
        json = jsonset(json, "xuid", participant.xuid);
        json = jsonset(json, "key", participant.xuid);

        if (ranks_write_json(path, json, "offline-personal-record"))
        {
            ranks_log(
                "OFFLINE_PERSONAL_ROUND_UPDATED | player=" +
                participant.name +
                " | xuid=" + participant.xuid +
                " | map=" + map_name +
                " | round=" + round_number
            );
        }
    }

    ranks_announce_personal_record(participant, map_name, round_number);
}


// ------------------------------------------------------------
// Ranked match integrity
// ------------------------------------------------------------

function ranks_remove_current_match_from_map_records()
{
    if (!isdefined(level.pintemod_ranks_match_record_id) ||
        level.pintemod_ranks_match_record_id == "")
    {
        return;
    }

    map_name = ranks_get_map_name();
    path = ranks_map_path(map_name);

    if (isdefined(level.pintemod_ranks_match_map_baseline_json) &&
        level.pintemod_ranks_match_map_baseline_json != "")
    {
        if (ranks_write_json(
            path,
            level.pintemod_ranks_match_map_baseline_json,
            "unranked-map-baseline-restore"
        ))
        {
            ranks_log(
                "UNRANKED_MAP_BASELINE_RESTORED | match_id=" +
                level.pintemod_ranks_match_record_id
            );
        }

        return;
    }

    json = ranks_load_map_json(map_name);
    changed = false;

    for (team_size = 1; team_size <= 4; team_size++)
    {
        records_before = ranks_load_category_records(
            json,
            team_size,
            ""
        );
        records_after = ranks_load_category_records(
            json,
            team_size,
            level.pintemod_ranks_match_record_id
        );

        if (records_before.size != records_after.size)
            changed = true;

        json = ranks_write_category_records(
            json,
            team_size,
            records_after
        );
    }

    if (changed)
    {
        ranks_write_json(path, json, "unranked-remove-match-records");
        ranks_log(
            "UNRANKED_MATCH_RECORDS_REMOVED | match_id=" +
            level.pintemod_ranks_match_record_id
        );
    }
}

function ranks_restore_participant_record_baseline(participant)
{
    if (!isdefined(participant) ||
        !participant.personal_baseline_set ||
        participant.personal_baseline_map == "" ||
        !isdefined(participant.xuid) ||
        participant.xuid == "")
    {
        return;
    }

    path = ranks_player_path_from_xuid(participant.xuid);
    json = ranks_load_json(path);

    if (json == "{}")
    {
        json = ranks_create_default_player_json(
            participant.xuid,
            participant.name
        );
    }

    json = jsonset(
        json,
        "best_" + participant.personal_baseline_map,
        "" + participant.personal_baseline_round
    );
    json = jsonset(
        json,
        "best_overall_round",
        "" + participant.personal_baseline_overall_round
    );
    json = jsonset(json, "name", participant.name);
    json = jsonset(json, "last_name", participant.name);
    json = jsonset(json, "xuid", participant.xuid);
    json = jsonset(json, "key", participant.xuid);

    if (!ranks_write_json(path, json, "unranked-personal-rollback"))
        return;

    player = ranks_find_connected_player_for_participant(participant);

    if (isdefined(player))
        player.pintemod_rank_json = json;

    ranks_log(
        "UNRANKED_PERSONAL_ROLLBACK | player=" + participant.name +
        " | xuid=" + participant.xuid +
        " | map_round=" + participant.personal_baseline_round +
        " | overall_round=" + participant.personal_baseline_overall_round
    );
}


function ranks_restore_all_personal_record_baselines()
{
    for (i = 0; i < level.pintemod_ranks_participants.size; i++)
    {
        ranks_restore_participant_record_baseline(
            level.pintemod_ranks_participants[i]
        );
    }
}

function ranks_mark_match_unranked(command_name, target_name)
{
    if (!isdefined(level.pintemod_ranks_match_ranked) ||
        !level.pintemod_ranks_match_ranked)
    {
        return;
    }

    if (!isdefined(command_name) || command_name == "")
        command_name = "unknown gameplay command";

    if (!isdefined(target_name))
        target_name = "";

    level.pintemod_ranks_match_ranked = false;
    level.pintemod_ranks_unranked_command = command_name;
    level.pintemod_ranks_unranked_target = target_name;

    ranks_remove_current_match_from_map_records();
    ranks_restore_all_personal_record_baselines();

    detail = command_name;

    if (target_name != "")
        detail = detail + " | target=" + target_name;

    ranks_broadcast_chat(
        "^1[PinteMod Records]^7 This match is now ^1UNRANKED^7 " +
        "because a gameplay command was used: ^3" + command_name,
        "MATCH_UNRANKED",
        "Match marked UNRANKED | " + detail
    );

    ranks_log("MATCH_UNRANKED | " + detail);
}

function ranks_process_pending_unranked_command()
{
    if (!isdefined(level.pintemod_gameplay_command_pending) ||
        !level.pintemod_gameplay_command_pending)
    {
        return;
    }

    command_name = level.pintemod_gameplay_command_name;
    target_name = level.pintemod_gameplay_command_target;
    level.pintemod_gameplay_command_pending = false;

    ranks_mark_match_unranked(command_name, target_name);
}

function ranks_unranked_command_monitor()
{
    for (;;)
    {
        level waittill(
            "pintemod_gameplay_command_used",
            command_name,
            target_name
        );

        level.pintemod_gameplay_command_pending = false;
        ranks_mark_match_unranked(command_name, target_name);
    }
}

// ------------------------------------------------------------
// Map records
// ------------------------------------------------------------

function ranks_collect_eligible_participants()
{
    result = [];

    for (i = 0; i < level.pintemod_ranks_participants.size; i++)
    {
        participant = level.pintemod_ranks_participants[i];

        if (!ranks_is_record_eligible_participant(participant))
            continue;

        result[result.size] = participant;
    }

    return result;
}

function ranks_join_participant_names(participants)
{
    result = "";

    if (!isdefined(participants))
        return result;

    for (i = 0; i < participants.size; i++)
    {
        participant = participants[i];

        if (!isdefined(participant))
            continue;

        if (result != "")
            result = result + " + ";

        result = result + participant.name;
    }

    return result;
}

function ranks_join_participant_xuids(participants)
{
    result = "";

    if (!isdefined(participants))
        return result;

    for (i = 0; i < participants.size; i++)
    {
        participant = participants[i];

        if (!isdefined(participant) ||
            !isdefined(participant.xuid) ||
            participant.xuid == "")
        {
            continue;
        }

        if (result != "")
            result = result + "+";

        result = result + participant.xuid;
    }

    return result;
}

function ranks_update_map_record(map_name, round_number)
{
    if (!level.pintemod_ranks_match_ranked)
        return;

    eligible_participants = ranks_collect_eligible_participants();
    team_size = eligible_participants.size;

    if (team_size < 1 || team_size > 4)
        return;

    holders = ranks_join_participant_names(eligible_participants);
    holder_xuids = ranks_join_participant_xuids(eligible_participants);

    if (holders == "" || holder_xuids == "")
        return;

    if (!isdefined(level.pintemod_ranks_match_map_baseline_json) ||
        level.pintemod_ranks_match_map_baseline_json == "")
    {
        level.pintemod_ranks_match_map_baseline_json =
            ranks_load_map_json(map_name);
    }

    ranks_ensure_match_record_id(map_name);

    if (!isdefined(level.pintemod_ranks_match_record_id) ||
        level.pintemod_ranks_match_record_id == "")
    {
        return;
    }

    path = ranks_map_path(map_name);
    json = ranks_load_map_json(map_name);
    match_id = level.pintemod_ranks_match_record_id;
    reached_in_seconds = level.pintemod_ranks_match_elapsed_seconds;
    previous_top = ranks_load_record(json, team_size, 1);
    candidate = ranks_create_record(
        round_number,
        reached_in_seconds,
        holders,
        holder_xuids,
        match_id
    );
    candidate_position = -1;

    for (category = 1; category <= 4; category++)
    {
        records = ranks_load_category_records(json, category, match_id);

        if (category == team_size)
        {
            records = ranks_insert_record_top(
                records,
                candidate,
                level.pintemod_ranks_max_records_per_category
            );
            candidate_position = ranks_find_record_position(records, match_id);
        }

        json = ranks_write_category_records(json, category, records);
    }

    json = jsonset(json, "map", map_name);
    json = jsonset(json, "display", ranks_get_map_display(map_name));
    json = jsonset(json, "identity_kind", level.pintemod_ranks_identity_kind);
    json = jsonset(
        json,
        "schema_version",
        "" + level.pintemod_ranks_map_schema_version
    );

    if (!ranks_write_json(path, json, "map-top5"))
        return;

    if (candidate_position < 0)
    {
        ranks_log(
            "MAP_RECORD_OUTSIDE_TOP5 | map=" + map_name +
            " | team_size=" + team_size +
            " | round=" + round_number +
            " | reached_in_seconds=" + reached_in_seconds +
            " | holders=" + holders +
            " | holder_xuids=" + holder_xuids
        );
        return;
    }

    ranks_log(
        "MAP_RECORD_TOP5 | map=" + map_name +
        " | team_size=" + team_size +
        " | position=" + (candidate_position + 1) +
        " | round=" + round_number +
        " | reached_in_seconds=" + reached_in_seconds +
        " | holders=" + holders +
        " | holder_xuids=" + holder_xuids
    );

    if (candidate_position != 0 ||
        level.pintemod_ranks_team_record_announced[team_size] ||
        round_number < level.pintemod_ranks_record_announcement_min_round)
    {
        return;
    }

    level.pintemod_ranks_team_record_announced[team_size] = true;
    display_name = ranks_get_map_display(map_name);
    duration = ranks_format_record_duration(reached_in_seconds);
    previous_other_record = isdefined(previous_top) &&
        previous_top.match_id != match_id;

    if (!previous_other_record)
    {
        message = "^5[PinteMod Records]^7 New server ^2" + team_size +
            "P ^7record on ^3" + display_name +
            "^7: Round ^2" + round_number +
            " ^7in ^3" + duration + "^7 | " + holders;
    }
    else if (round_number == previous_top.round &&
        reached_in_seconds > 0 &&
        previous_top.seconds > 0 &&
        reached_in_seconds < previous_top.seconds)
    {
        message = "^5[PinteMod Records]^7 ^2" + team_size +
            "P ^7record beaten faster on ^3" + display_name +
            "^7: Round ^2" + round_number +
            " ^7in ^3" + duration + "^7 | " + holders;
    }
    else
    {
        message = "^5[PinteMod Records]^7 ^2" + team_size +
            "P ^7record beaten on ^3" + display_name +
            "^7: Round ^2" + round_number +
            " ^7in ^3" + duration + "^7 | " + holders;
    }

    live_console_message = team_size + "P record on " + display_name +
        ": Round " + round_number + " in " + duration +
        " | " + holders + " | xuids=" + holder_xuids;

    ranks_broadcast_chat(message, "TEAM_RECORD_CHAT", live_console_message);
}


function ranks_process_round(round_number)
{
    if (!level.pintemod_ranks_match_ranked)
    {
        ranks_log(
            "ROUND_SKIPPED_UNRANKED | round=" + round_number +
            " | command=" + level.pintemod_ranks_unranked_command
        );
        return;
    }

    map_name = ranks_get_map_name();
    eligible_participants = ranks_collect_eligible_participants();

    for (i = 0; i < eligible_participants.size; i++)
    {
        participant = eligible_participants[i];
        player = ranks_find_connected_player_for_participant(participant);

        if (isdefined(player))
        {
            ranks_update_personal_round(
                player,
                map_name,
                round_number
            );
        }
        else
        {
            ranks_update_offline_personal_round(
                participant,
                map_name,
                round_number
            );
        }
    }

    ranks_update_map_record(map_name, round_number);
}

// ------------------------------------------------------------
// Central monitor: one writer avoids persistence races
// ------------------------------------------------------------

function ranks_monitor()
{
    for (;;)
    {
        ranks_process_pending_unranked_command();

        if (!level.pintemod_ranks_enabled)
        {
            wait 1;
            continue;
        }

        players = GetPlayers();
        has_active_player = false;

        for (i = 0; i < players.size; i++)
        {
            player = players[i];

            if (!ranks_attach_player(player))
                continue;

            participant = ranks_get_player_participant(player);

            if (isdefined(participant))
            {
                participant.connected = true;
                participant.name = player.name;
                participant.xuid = player.pintemod_rank_xuid;
            }

            if (ranks_is_active_player(player))
            {
                has_active_player = true;

                if (!player.pintemod_rank_has_played)
                {
                    player.pintemod_rank_has_played = true;

                    if (isdefined(participant))
                    {
                        participant.has_played = true;

                        if (!participant.personal_baseline_set)
                        {
                            map_name = ranks_get_map_name();
                            participant.personal_baseline_set = true;
                            participant.personal_baseline_map = map_name;
                            participant.personal_baseline_round = ranks_json_int(
                                player.pintemod_rank_json,
                                "best_" + map_name,
                                0
                            );
                            participant.personal_baseline_overall_round =
                                ranks_json_int(
                                    player.pintemod_rank_json,
                                    "best_overall_round",
                                    0
                                );
                        }
                    }

                    ranks_start_player_session(player);

                    ranks_log(
                        "PLAYER_STARTED | " + player.name +
                        " | xuid=" + player.pintemod_rank_xuid +
                        " | round=" + ranks_get_round() +
                        " | match_elapsed_seconds=" +
                        level.pintemod_ranks_match_elapsed_seconds
                    );
                }

                player.pintemod_rank_pending_seconds++;

                if (player.pintemod_rank_pending_seconds >=
                    level.pintemod_ranks_activity_flush_seconds)
                {
                    ranks_flush_player_activity(player, "periodic");
                }
            }
        }

        if (!level.pintemod_ranks_match_started && has_active_player)
        {
            level.pintemod_ranks_match_started = true;
            ranks_log("MATCH_CLOCK_STARTED");
        }

        if (level.pintemod_ranks_match_started)
        {
            level.pintemod_ranks_match_elapsed_seconds++;

            for (i = 0; i < level.pintemod_ranks_participants.size; i++)
            {
                participant = level.pintemod_ranks_participants[i];

                if (isdefined(participant) &&
                    participant.connected &&
                    participant.has_played)
                {
                    participant.present_seconds++;

                    if (!participant.eligibility_logged &&
                        ranks_is_record_eligible_participant(participant))
                    {
                        participant.eligibility_logged = true;

                        ranks_log(
                            "RECORD_ELIGIBLE | " + participant.name +
                            " | xuid=" + participant.xuid +
                            " | presence=" +
                            ranks_get_presence_percent_from_seconds(
                                participant.present_seconds
                            ) + "%" +
                            " | match_elapsed_seconds=" +
                            level.pintemod_ranks_match_elapsed_seconds
                        );
                    }
                }
            }

            for (i = 0; i < players.size; i++)
            {
                player = players[i];
                participant = ranks_get_player_participant(player);

                if (!isdefined(participant))
                    continue;

                player.pintemod_rank_match_present_seconds =
                    participant.present_seconds;
                player.pintemod_rank_eligibility_logged =
                    participant.eligibility_logged;
            }
        }

        current_round = ranks_get_round();

        if (current_round > 0 &&
            current_round != level.pintemod_ranks_last_round)
        {
            level.pintemod_ranks_last_round = current_round;
            ranks_process_round(current_round);
        }

        wait 1;
    }
}


// ------------------------------------------------------------
// Leaderboard scanning and sorting
// ------------------------------------------------------------



function ranks_collect_all_stats()
{
    entries = ls(ranks_players_directory(), false, false);
    result = [];

    if (!isdefined(entries))
        return result;

    for (i = 0; i < entries.size; i++)
    {
        path = ranks_resolve_listed_path(
            entries[i],
            ranks_players_directory()
        );

        if (path == "" || !fileexists(path))
            continue;

        json = ranks_load_json(path);

        if (json == "{}" ||
            ranks_json_int(json, "schema_version", 0) !=
                level.pintemod_ranks_player_schema_version ||
            ranks_json_string(json, "identity_kind", "") !=
                level.pintemod_ranks_identity_kind)
        {
            continue;
        }

        xuid = ezz_admin_identity::normalize_xuid(
            ranks_json_string(json, "xuid", "")
        );

        if (!ezz_admin_identity::is_valid_xuid(xuid))
            continue;

        stat = SpawnStruct();
        stat.xuid = xuid;
        stat.name = ranks_json_string(
            json,
            "last_name",
            ranks_json_string(json, "name", "Unknown")
        );
        stat.total_seconds = ranks_json_int(json, "total_seconds", 0);
        stat.sessions = ranks_json_int(json, "sessions", 0);
        stat.best_round = ranks_json_int(json, "best_overall_round", 0);

        result[result.size] = stat;
    }

    return result;
}


function ranks_insert_activity_top(list, candidate, maximum)
{
    result = [];
    inserted = false;

    for (i = 0; i < list.size; i++)
    {
        existing = list[i];

        if (!inserted &&
            candidate.total_seconds > existing.total_seconds)
        {
            result[result.size] = candidate;
            inserted = true;
        }

        result[result.size] = existing;
    }

    if (!inserted)
        result[result.size] = candidate;

    while (result.size > maximum)
        result = ranks_copy_without_last(result);

    return result;
}

function ranks_insert_round_top(list, candidate, maximum)
{
    result = [];
    inserted = false;

    for (i = 0; i < list.size; i++)
    {
        existing = list[i];

        if (!inserted && candidate.best_round > existing.best_round)
        {
            result[result.size] = candidate;
            inserted = true;
        }

        result[result.size] = existing;
    }

    if (!inserted)
        result[result.size] = candidate;

    while (result.size > maximum)
        result = ranks_copy_without_last(result);

    return result;
}

function ranks_copy_without_last(values)
{
    result = [];

    for (i = 0; i < values.size - 1; i++)
        result[result.size] = values[i];

    return result;
}

function ranks_get_activity_position(stats, player_xuid, player_seconds)
{
    position = 1;

    for (i = 0; i < stats.size; i++)
    {
        stat = stats[i];

        if (stat.xuid == player_xuid)
            continue;

        if (stat.total_seconds > player_seconds)
            position++;
    }

    return position;
}


// ------------------------------------------------------------
// Maintenance: audit, backup and protected reset
// ------------------------------------------------------------

function ranks_maintenance_path()
{
    return ranks_data_root() + "/maintenance.json";
}


function ranks_create_default_maintenance_json()
{
    json = "{}";
    json = jsonset(json, "schema_version", "2");
    json = jsonset(json, "identity_kind", "BOIII_XUID");
    json = jsonset(json, "next_backup_id", "1");
    json = jsonset(json, "last_backup_id", "0");
    json = jsonset(json, "last_backup_path", "");
    json = jsonset(json, "last_backup_label", "");
    json = jsonset(json, "last_backup_gettime", "0");
    json = jsonset(json, "last_reset_backup_id", "0");
    json = jsonset(json, "last_reset_gettime", "0");
    return json;
}

function ranks_load_maintenance_json()
{
    path = ranks_maintenance_path();
    json = ranks_load_json(path);

    if (json == "{}" || ranks_json_int(json, "schema_version", 0) != 2 ||
        ranks_json_string(json, "identity_kind", "") != "BOIII_XUID")
        json = ranks_create_default_maintenance_json();

    return json;
}

function ranks_save_maintenance_json(json, context)
{
    return ranks_write_json(
        ranks_maintenance_path(),
        json,
        context
    );
}

function ranks_file_basename(path)
{
    if (!isdefined(path) || path == "")
        return "";

    last_separator = -1;

    for (i = 0; i < path.size; i++)
    {
        character = GetSubStr(path, i, i + 1);

        if (character == "/" || character == "\\")
            last_separator = i;
    }

    if (last_separator >= 0 && last_separator + 1 < path.size)
        return GetSubStr(path, last_separator + 1, path.size);

    return path;
}

function ranks_copy_directory_files(source_directory, target_directory)
{
    result = SpawnStruct();
    result.copied = 0;
    result.failed = 0;
    result.skipped = 0;

    mkdir(target_directory);
    entries = ls(source_directory, false, false);

    if (!isdefined(entries))
        return result;

    for (i = 0; i < entries.size; i++)
    {
        source_path = ranks_resolve_listed_path(
            entries[i],
            source_directory
        );
        filename = ranks_file_basename(source_path);

        if (source_path == "" || filename == "" || !fileexists(source_path))
        {
            result.skipped++;
            continue;
        }

        data = readfile(source_path);

        if (!isdefined(data) || data == "")
        {
            result.failed++;
            ranks_log(
                "BACKUP_READ_FAILED | path=" + source_path
            );
            continue;
        }

        target_path = target_directory + "/" + filename;

        if (ezz_admin_storage::write_json_safe(target_path, data, "rank-backup-copy"))
        {
            result.copied++;
        }
        else
        {
            result.failed++;
            ranks_log(
                "BACKUP_WRITE_FAILED | source=" + source_path +
                " | target=" + target_path
            );
        }
    }

    return result;
}

function ranks_reserve_backup_id()
{
    json = ranks_load_maintenance_json();
    backup_id = ranks_json_int(json, "next_backup_id", 1);

    if (backup_id < 1)
        backup_id = 1;

    json = jsonset(json, "next_backup_id", "" + (backup_id + 1));

    if (!ranks_save_maintenance_json(json, "backup-id-reserve"))
        return 0;

    return backup_id;
}

function ranks_create_backup(label)
{
    result = SpawnStruct();
    result.success = false;
    result.backup_id = 0;
    result.path = "";
    result.players_copied = 0;
    result.maps_copied = 0;
    result.failed = 0;

    if (!isdefined(label) || label == "")
        label = "manual";

    safe_label = ranks_player_key(label);
    backup_id = ranks_reserve_backup_id();

    if (backup_id <= 0)
    {
        ranks_log("BACKUP_ABORTED | reason=id-reservation-failed");
        return result;
    }

    ranks_flush_all_pending("manual-backup");

    backup_path = "pintemod/backups/ranks_v2/backup_" + backup_id;
    players_path = backup_path + "/players";
    maps_path = backup_path + "/maps";

    mkdir(backup_path);
    mkdir(players_path);
    mkdir(maps_path);

    players_result = ranks_copy_directory_files(
        ranks_players_directory(),
        players_path
    );
    maps_result = ranks_copy_directory_files(
        ranks_maps_directory(),
        maps_path
    );

    result.backup_id = backup_id;
    result.path = backup_path;
    result.players_copied = players_result.copied;
    result.maps_copied = maps_result.copied;
    result.failed = players_result.failed + maps_result.failed;

    manifest = "{}";
    manifest = jsonset(manifest, "schema_version", "2");
    manifest = jsonset(manifest, "backup_id", "" + backup_id);
    manifest = jsonset(manifest, "label", safe_label);
    manifest = jsonset(manifest, "module_version", level.pintemod_ranks_version);
    manifest = jsonset(manifest, "map", ranks_get_map_name());
    manifest = jsonset(manifest, "created_gettime", "" + GetTime());
    manifest = jsonset(
        manifest,
        "players_copied",
        "" + result.players_copied
    );
    manifest = jsonset(
        manifest,
        "maps_copied",
        "" + result.maps_copied
    );
    manifest = jsonset(manifest, "failed_files", "" + result.failed);

    status = "complete";

    if (result.failed > 0)
        status = "partial";

    manifest = jsonset(manifest, "status", status);

    manifest_written = ranks_write_json(
        backup_path + "/manifest.json",
        manifest,
        "backup-manifest"
    );

    if (!manifest_written)
        result.failed++;

    maintenance = ranks_load_maintenance_json();
    maintenance = jsonset(
        maintenance,
        "last_backup_id",
        "" + backup_id
    );
    maintenance = jsonset(
        maintenance,
        "last_backup_path",
        backup_path
    );
    maintenance = jsonset(
        maintenance,
        "last_backup_label",
        safe_label
    );
    maintenance = jsonset(
        maintenance,
        "last_backup_gettime",
        "" + GetTime()
    );
    maintenance_written = ranks_save_maintenance_json(
        maintenance,
        "backup-maintenance-update"
    );

    if (!maintenance_written)
        result.failed++;

    result.success = result.failed == 0;
    final_status = "complete";

    if (!result.success)
        final_status = "partial";

    ranks_log(
        "BACKUP_" + final_status +
        " | id=" + backup_id +
        " | label=" + safe_label +
        " | players=" + result.players_copied +
        " | maps=" + result.maps_copied +
        " | failed=" + result.failed +
        " | path=" + backup_path
    );

    return result;
}

function ranks_string_array_contains(values, value)
{
    if (!isdefined(values) || !isdefined(value) || value == "")
        return false;

    for (i = 0; i < values.size; i++)
    {
        if (values[i] == value)
            return true;
    }

    return false;
}

function ranks_audit_player_files(audit)
{
    entries = ls(ranks_players_directory(), false, false);

    if (!isdefined(entries))
        return;

    for (i = 0; i < entries.size; i++)
    {
        path = ranks_resolve_listed_path(entries[i], ranks_players_directory());

        if (path == "" || !fileexists(path))
            continue;

        audit.player_files++;
        json = readfile(path);

        if (!isdefined(json) || json == "" || jsonvalid(json))
        {
            audit.invalid_json++;
            ranks_log("AUDIT_INVALID_PLAYER_JSON | path=" + path);
            continue;
        }

        schema = ranks_json_int(json, "schema_version", 0);
        identity_kind = ranks_json_string(json, "identity_kind", "");
        xuid = ezz_admin_identity::normalize_xuid(
            ranks_json_string(json, "xuid", "")
        );
        key = ezz_admin_identity::normalize_xuid(
            ranks_json_string(json, "key", "")
        );
        name = ranks_json_string(json, "last_name", "");
        total_seconds = ranks_json_int(json, "total_seconds", -1);
        sessions = ranks_json_int(json, "sessions", -1);
        best_round = ranks_json_int(json, "best_overall_round", -1);

        if (schema != level.pintemod_ranks_player_schema_version ||
            identity_kind != level.pintemod_ranks_identity_kind ||
            !ezz_admin_identity::is_valid_xuid(xuid) ||
            key != xuid ||
            name == "")
        {
            audit.invalid_player_fields++;
            ranks_log("AUDIT_PLAYER_IDENTITY_INVALID | path=" + path);
        }

        if (total_seconds < 0 || sessions < 0 || best_round < 0)
        {
            audit.invalid_player_fields++;
            ranks_log("AUDIT_PLAYER_NUMERIC_INVALID | path=" + path);
        }
    }
}


function ranks_audit_map_files(audit)
{
    entries = ls(ranks_maps_directory(), false, false);

    if (!isdefined(entries))
        return;

    for (i = 0; i < entries.size; i++)
    {
        path = ranks_resolve_listed_path(entries[i], ranks_maps_directory());

        if (path == "" || !fileexists(path))
            continue;

        audit.map_files++;
        json = readfile(path);

        if (!isdefined(json) || json == "" || jsonvalid(json))
        {
            audit.invalid_json++;
            ranks_log("AUDIT_INVALID_MAP_JSON | path=" + path);
            continue;
        }

        if (ranks_json_int(json, "schema_version", 0) !=
                level.pintemod_ranks_map_schema_version ||
            ranks_json_string(json, "identity_kind", "") !=
                level.pintemod_ranks_identity_kind)
        {
            audit.invalid_map_schema++;
            ranks_log("AUDIT_MAP_SCHEMA_INVALID | path=" + path);
        }

        if (ranks_json_string(json, "map", "") == "" ||
            ranks_json_int(json, "next_run_id", 0) < 1)
        {
            audit.invalid_map_fields++;
            ranks_log("AUDIT_MAP_HEADER_INVALID | path=" + path);
        }

        seen_match_ids = [];

        for (team_size = 1; team_size <= 4; team_size++)
        {
            previous = undefined;
            empty_position_seen = false;

            for (position = 1;
                position <= level.pintemod_ranks_max_records_per_category;
                position++)
            {
                record = ranks_load_record(json, team_size, position);

                if (!isdefined(record))
                {
                    empty_position_seen = true;
                    continue;
                }

                if (empty_position_seen)
                {
                    audit.unsorted_records++;
                    ranks_log(
                        "AUDIT_RECORD_GAP | path=" + path +
                        " | category=" + team_size +
                        " | position=" + position
                    );
                }

                if (record.seconds <= 0 || record.holders == "" ||
                    record.holder_xuids == "" || record.match_id == "")
                {
                    audit.invalid_map_fields++;
                    ranks_log(
                        "AUDIT_RECORD_FIELDS_INVALID | path=" + path +
                        " | category=" + team_size +
                        " | position=" + position
                    );
                }

                if (isdefined(previous) &&
                    ranks_record_is_better(record, previous))
                {
                    audit.unsorted_records++;
                    ranks_log(
                        "AUDIT_RECORD_ORDER_INVALID | path=" + path +
                        " | category=" + team_size +
                        " | position=" + position
                    );
                }

                if (record.match_id != "")
                {
                    if (ranks_string_array_contains(
                        seen_match_ids,
                        record.match_id
                    ))
                    {
                        audit.duplicate_match_ids++;
                        ranks_log(
                            "AUDIT_DUPLICATE_MATCH_ID | path=" + path +
                            " | match_id=" + record.match_id
                        );
                    }
                    else
                    {
                        seen_match_ids[seen_match_ids.size] = record.match_id;
                    }
                }

                previous = record;
            }
        }
    }
}


function ranks_run_audit()
{
    audit = SpawnStruct();
    audit.player_files = 0;
    audit.map_files = 0;
    audit.invalid_json = 0;
    audit.invalid_player_fields = 0;
    audit.invalid_map_schema = 0;
    audit.invalid_map_fields = 0;
    audit.unsorted_records = 0;
    audit.duplicate_match_ids = 0;

    ranks_audit_player_files(audit);
    ranks_audit_map_files(audit);

    audit.issue_count = audit.invalid_json +
        audit.invalid_player_fields +
        audit.invalid_map_schema +
        audit.invalid_map_fields +
        audit.unsorted_records +
        audit.duplicate_match_ids;

    ranks_log(
        "AUDIT_COMPLETE | players=" + audit.player_files +
        " | maps=" + audit.map_files +
        " | issues=" + audit.issue_count +
        " | invalid_json=" + audit.invalid_json +
        " | invalid_player_fields=" + audit.invalid_player_fields +
        " | invalid_map_schema=" + audit.invalid_map_schema +
        " | invalid_map_fields=" + audit.invalid_map_fields +
        " | unsorted=" + audit.unsorted_records +
        " | duplicate_match_ids=" + audit.duplicate_match_ids
    );

    return audit;
}

function ranks_reset_runtime_state()
{
    level.pintemod_ranks_last_round = -1;
    level.pintemod_ranks_match_started = false;
    level.pintemod_ranks_match_elapsed_seconds = 0;
    level.pintemod_ranks_match_record_id = "";
    level.pintemod_ranks_match_map_baseline_json = "";
    level.pintemod_ranks_match_ranked = true;
    level.pintemod_ranks_unranked_command = "";
    level.pintemod_ranks_unranked_target = "";
    level.pintemod_ranks_participants = [];
    level.pintemod_ranks_team_record_announced = [];

    for (team_size = 0; team_size <= 4; team_size++)
        level.pintemod_ranks_team_record_announced[team_size] = false;

    level.pintemod_gameplay_command_pending = false;
    level.pintemod_gameplay_command_name = "";
    level.pintemod_gameplay_command_target = "";
}

function ranks_clear_reset_token()
{
    level.pintemod_ranks_reset_token = "";
    level.pintemod_ranks_reset_token_expires = 0;
    level.pintemod_ranks_reset_backup_id = 0;
}

function ranks_execute_full_reset(backup_id)
{
    players_removed = true;
    maps_removed = true;

    if (directoryexists(ranks_players_directory()))
        players_removed = rmdir(ranks_players_directory());

    if (directoryexists(ranks_maps_directory()))
        maps_removed = rmdir(ranks_maps_directory());

    if (!players_removed || !maps_removed)
    {
        ranks_log(
            "RESET_FAILED | players_removed=" + players_removed +
            " | maps_removed=" + maps_removed
        );
        return false;
    }

    mkdir(ranks_players_directory());
    mkdir(ranks_maps_directory());
    ranks_reset_runtime_state();

    maintenance = ranks_load_maintenance_json();
    maintenance = jsonset(
        maintenance,
        "last_reset_backup_id",
        "" + backup_id
    );
    maintenance = jsonset(
        maintenance,
        "last_reset_gettime",
        "" + GetTime()
    );
    ranks_save_maintenance_json(maintenance, "reset-maintenance-update");

    ranks_log(
        "FULL_RESET_COMPLETE | root=" + ranks_data_root() +
        " | backup_id=" + backup_id +
        " | legacy_root_untouched=" + ranks_legacy_root()
    );

    ezz_admin_storage::append_managed_log(
        "pintemod/logs/community.log",
        "[" + GetTime() + "] RANKS | MAINTENANCE_RESET" +
        " | XUID v2 reset completed | backup_id=" + backup_id + "\n"
    );

    return true;
}


function ranks_count_files(directory)
{
    entries = ls(directory, false, false);
    count = 0;

    if (!isdefined(entries))
        return 0;

    for (i = 0; i < entries.size; i++)
    {
        path = ranks_resolve_listed_path(entries[i], directory);

        if (path != "" && fileexists(path))
            count++;
    }

    return count;
}

function cmd_ezzrankmigrationstatus(args)
{
    println("^5===== PINTEMOD RANKS XUID CUTOVER =====");
    println("^7Active identity: BOIII_XUID");
    println("^7Active player schema: " + level.pintemod_ranks_player_schema_version);
    println("^7Active map schema: " + level.pintemod_ranks_map_schema_version);
    println("^7Active root: boiii/scriptdata/" + ranks_data_root());
    println("^7Active player files: " + ranks_count_files(ranks_players_directory()));
    println("^7Active map files: " + ranks_count_files(ranks_maps_directory()));
    println("^7Legacy root preserved: boiii/scriptdata/" + ranks_legacy_root());
    println("^7Legacy player files: " + ranks_count_files(ranks_legacy_root() + "/players"));
    println("^7Legacy map files: " + ranks_count_files(ranks_legacy_root() + "/maps"));
    println("^7Automatic pseudo-to-XUID merge: disabled (security)");
    println("^5========================================");
}

function ranks_test_assert(result, condition, test_name, details)
{
    result.total++;

    if (condition)
    {
        result.passed++;
        println("^2[PASS]^7 " + result.total + " " + test_name);
        return;
    }

    result.failed++;
    println("^1[FAIL]^7 " + result.total + " " + test_name + " | " + details);
}

function ranks_run_grouped_suite(player)
{
    result = SpawnStruct();
    result.total = 0;
    result.passed = 0;
    result.failed = 0;

    println("^5===== PINTEMOD RANKS XUID GROUPED SUITE =====");

    ranks_test_assert(
        result,
        isdefined(player),
        "connected target resolved",
        "Use ezzranktest suite <PlayerName|BOIII_XUID|ClientNumber>"
    );

    if (!isdefined(player))
        return result;

    xuid = ranks_get_player_xuid(player);
    path = ranks_player_path_from_xuid(xuid);
    default_json = ranks_create_default_player_json(xuid, player.name);
    map_json = ranks_create_default_map_json(ranks_get_map_name());
    test_path = ranks_data_root() + "/test/player_identity.json";

    ranks_test_assert(
        result,
        ezz_admin_identity::is_valid_xuid(xuid),
        "native BOIII_XUID available",
        "xuid=" + xuid
    );
    ranks_test_assert(
        result,
        ranks_player_key_from_xuid(xuid) == xuid,
        "player key equals normalized XUID",
        "key=" + ranks_player_key_from_xuid(xuid)
    );
    ranks_test_assert(
        result,
        path == ranks_players_directory() + "/" + xuid + ".json",
        "player path is XUID-bound",
        "path=" + path
    );
    ranks_test_assert(
        result,
        ranks_json_int(default_json, "schema_version", 0) == 2,
        "player schema v2",
        "schema=" + ranks_json_int(default_json, "schema_version", 0)
    );
    ranks_test_assert(
        result,
        ranks_json_string(default_json, "identity_kind", "") == "BOIII_XUID",
        "player identity kind",
        "identity=" + ranks_json_string(default_json, "identity_kind", "")
    );
    ranks_test_assert(
        result,
        ranks_json_string(default_json, "xuid", "") == xuid,
        "player JSON stores XUID",
        "stored=" + ranks_json_string(default_json, "xuid", "")
    );
    ranks_test_assert(
        result,
        ranks_json_string(default_json, "last_name", "") == player.name,
        "display name remains metadata",
        "stored=" + ranks_json_string(default_json, "last_name", "")
    );

    removefile(test_path);
    wrote = ranks_write_json(test_path, default_json, "grouped-suite-test-write");
    ranks_test_assert(result, wrote, "isolated TEST player write", "path=" + test_path);

    read_json = ranks_load_json(test_path);
    ranks_test_assert(
        result,
        ranks_json_string(read_json, "xuid", "") == xuid,
        "isolated TEST player read",
        "stored=" + ranks_json_string(read_json, "xuid", "")
    );

    renamed_json = jsonset(read_json, "last_name", "RenamedPlayer");
    ranks_test_assert(
        result,
        ranks_json_string(renamed_json, "xuid", "") == xuid,
        "name change cannot alter identity",
        "xuid changed unexpectedly"
    );
    ranks_test_assert(
        result,
        ranks_json_int(map_json, "schema_version", 0) == 4,
        "map schema v4",
        "schema=" + ranks_json_int(map_json, "schema_version", 0)
    );
    ranks_test_assert(
        result,
        ranks_json_string(map_json, "identity_kind", "") == "BOIII_XUID",
        "map identity kind",
        "identity=" + ranks_json_string(map_json, "identity_kind", "")
    );
    ranks_test_assert(
        result,
        isdefined(jsonparse(
            map_json,
            ranks_map_record_key("holder_xuids", 1, 1)
        )),
        "map holder XUID field exists",
        "holder_xuids_1p_1 missing"
    );
    ranks_test_assert(
        result,
        ranks_data_root() != ranks_legacy_root(),
        "legacy and XUID roots isolated",
        "roots must differ"
    );

    removed = removefile(test_path);
    ranks_test_assert(
        result,
        removed || !fileexists(test_path),
        "isolated TEST file cleaned",
        "path=" + test_path
    );
    ranks_test_assert(
        result,
        !fileexists(ranks_legacy_root() + "/test/player_identity.json"),
        "legacy storage untouched",
        "unexpected legacy test file"
    );

    println(
        "^5[PinteMod Ranks]^7 RESULT " + result.passed + "/" +
        result.total + " PASS | failed=" + result.failed
    );
    println("^5=============================================");

    ranks_log(
        "GROUPED_SUITE | target=" + player.name +
        " | xuid=" + xuid +
        " | passed=" + result.passed +
        " | total=" + result.total +
        " | failed=" + result.failed
    );

    return result;
}

function cmd_ezzranktest(args)
{
    if (args.size <= 0 || toLower(args[0]) != "suite")
    {
        println("^3[PinteMod Ranks]^7 Usage: ezzranktest suite [PlayerName|BOIII_XUID|ClientNumber]");
        return;
    }

    player = undefined;

    if (args.size >= 2)
        player = ranks_find_player(ranks_join_args(args, 1));
    else if (GetPlayers().size > 0)
        player = GetPlayers()[0];

    ranks_run_grouped_suite(player);
}

function cmd_ezzrankaudit(args)
{
    audit = ranks_run_audit();

    println("^5===== PINTEMOD RANKS v2 XUID DATA AUDIT =====");
    println("^7Player files: " + audit.player_files);
    println("^7Map files: " + audit.map_files);
    println("^7Issues: " + audit.issue_count);
    println("^7Invalid JSON: " + audit.invalid_json);
    println("^7Invalid player fields: " + audit.invalid_player_fields);
    println("^7Invalid map schema: " + audit.invalid_map_schema);
    println("^7Invalid map fields: " + audit.invalid_map_fields);
    println("^7Unsorted records: " + audit.unsorted_records);
    println("^7Duplicate match IDs: " + audit.duplicate_match_ids);
    println(
        "^7Details: boiii/scriptdata/" +
        ezz_admin_storage::get_active_log_root() + "/ranks.log"
    );
    println("^5=====================================");
}

function cmd_ezzrankbackup(args)
{
    label = "manual";

    if (args.size > 0)
        label = ranks_join_args(args, 0);

    result = ranks_create_backup(label);

    if (!result.success)
    {
        println(
            "^1[PinteMod Ranks]^7 Backup incomplete or failed" +
            " | id=" + result.backup_id +
            " | failed=" + result.failed
        );
        println(
            "^7See boiii/scriptdata/" +
            ezz_admin_storage::get_active_log_root() + "/ranks.log"
        );
        return;
    }

    println(
        "^2[PinteMod Ranks]^7 Backup complete" +
        " | id=" + result.backup_id +
        " | players=" + result.players_copied +
        " | maps=" + result.maps_copied
    );
    println("^7Path: boiii/scriptdata/" + result.path);
}

function cmd_ezzrankreset(args)
{
    if (args.size <= 0)
    {
        println("^3[PinteMod Ranks]^7 Usage:");
        println("^7ezzrankreset prepare");
        println("^7ezzrankreset confirm <token>");
        println("^7ezzrankreset cancel");
        return;
    }

    action = toLower(args[0]);

    if (action == "cancel")
    {
        ranks_clear_reset_token();
        println("^2[PinteMod Ranks]^7 Pending reset cancelled.");
        ranks_log("RESET_CANCELLED");
        return;
    }

    if (GetPlayers().size > 0)
    {
        println(
            "^1[PinteMod Ranks]^7 Reset refused: " +
            "the server must be empty."
        );
        return;
    }

    if (action == "prepare")
    {
        backup = ranks_create_backup("pre_reset");

        if (!backup.success)
        {
            println(
                "^1[PinteMod Ranks]^7 Reset preparation aborted: " +
                "mandatory backup failed."
            );
            return;
        }

        token = "RESET_" + GetTime();
        level.pintemod_ranks_reset_token = token;
        level.pintemod_ranks_reset_token_expires = GetTime() + 60000;
        level.pintemod_ranks_reset_backup_id = backup.backup_id;

        println("^1===== DESTRUCTIVE RANKS RESET ARMED =====");
        println("^7Mandatory backup ID: " + backup.backup_id);
        println("^7Confirmation expires in 60 seconds.");
        println("^3ezzrankreset confirm " + token);
        println("^1=========================================");

        ranks_log(
            "RESET_PREPARED | token=" + token +
            " | backup_id=" + backup.backup_id
        );
        return;
    }

    if (action != "confirm" || args.size < 2)
    {
        println("^1[PinteMod Ranks]^7 Invalid reset action.");
        return;
    }

    supplied_token = args[1];

    if (level.pintemod_ranks_reset_token == "" ||
        supplied_token != level.pintemod_ranks_reset_token)
    {
        println("^1[PinteMod Ranks]^7 Invalid reset token.");
        return;
    }

    if (GetTime() > level.pintemod_ranks_reset_token_expires)
    {
        ranks_clear_reset_token();
        println("^1[PinteMod Ranks]^7 Reset token expired.");
        ranks_log("RESET_TOKEN_EXPIRED");
        return;
    }

    backup_id = level.pintemod_ranks_reset_backup_id;

    if (backup_id <= 0 ||
        !ranks_execute_full_reset(backup_id))
    {
        ranks_clear_reset_token();
        println("^1[PinteMod Ranks]^7 Reset failed. Data was not cleared safely.");
        return;
    }

    ranks_clear_reset_token();
    println(
        "^2[PinteMod Ranks]^7 Full XUID v2 reset complete." +
        " Backup ID: " + backup_id
    );
}

// ------------------------------------------------------------
// Public commands
// ------------------------------------------------------------

function ranks_stats_contains_player(stats, player_xuid)
{
    if (!isdefined(stats) ||
        !isdefined(player_xuid) ||
        player_xuid == "")
    {
        return false;
    }

    for (i = 0; i < stats.size; i++)
    {
        if (stats[i].xuid == player_xuid)
            return true;
    }

    return false;
}


function cmd_ezzrank(args)
{
    if (args.size <= 0)
    {
        println("^3[PinteMod Ranks]^7 Usage: ezzrank <PlayerName|BOIII_XUID|ClientNumber>");
        return;
    }

    player_name = ranks_join_args(args, 0);
    player = ranks_find_player(player_name);

    if (!isdefined(player))
    {
        println("^1[PinteMod Ranks]^7 Player not found: " + player_name);
        return;
    }

    if (!ranks_attach_player(player))
    {
        ranks_private(
            player,
            "^1[PinteMod Ranks]^7 Stable BOIII_XUID unavailable."
        );
        return;
    }

    json = player.pintemod_rank_json;
    xuid = player.pintemod_rank_xuid;
    total_seconds = ranks_json_int(json, "total_seconds", 0);

    if (isdefined(player.pintemod_rank_pending_seconds))
        total_seconds += player.pintemod_rank_pending_seconds;

    sessions = ranks_json_int(json, "sessions", 0);
    best_overall = ranks_json_int(json, "best_overall_round", 0);
    map_name = ranks_get_map_name();
    map_best = ranks_json_int(json, "best_" + map_name, 0);
    stats = ranks_collect_all_stats();
    position = ranks_get_activity_position(stats, xuid, total_seconds);
    known_player_count = stats.size;

    if (!ranks_stats_contains_player(stats, xuid))
        known_player_count++;

    ranks_private(player, "^5=== YOUR PINTE MOD RANK v2 ===");
    ranks_private(
        player,
        "^7Activity rank: ^2#" + position + "^7 / " + known_player_count
    );
    ranks_private(
        player,
        "^7Playtime: ^3" + ranks_format_duration(total_seconds) +
        " ^7| Sessions: ^3" + sessions
    );
    ranks_private(player, "^7Best overall round: ^2" + best_overall);
    ranks_private(
        player,
        "^7" + ranks_get_map_display(map_name) +
        " best: ^2Round " + map_best
    );

    presence_percent = ranks_get_presence_percent(player);
    eligibility_text = "^1No";

    if (ranks_is_record_eligible_player(player))
        eligibility_text = "^2Yes";

    ranks_private(
        player,
        "^7Current match presence: ^3" + presence_percent +
        "% ^7| Record eligible: " + eligibility_text
    );

    if (level.pintemod_ranks_match_ranked)
        ranks_private(player, "^7Current match: ^2RANKED");
    else
        ranks_private(
            player,
            "^7Current match: ^1UNRANKED ^7(" +
            level.pintemod_ranks_unranked_command + ")"
        );

    ranks_private(player, "^7Identity: ^3BOIII_XUID " + xuid);
}


function cmd_ezzranks(args)
{
    if (args.size <= 0)
    {
        println("^3[PinteMod Ranks]^7 Usage: ezzranks <PlayerName|BOIII_XUID|ClientNumber>");
        return;
    }

    player_name = ranks_join_args(args, 0);
    player = ranks_find_player(player_name);

    if (!isdefined(player))
        return;

    stats = ranks_collect_all_stats();
    activity_top = [];
    round_top = [];

    for (i = 0; i < stats.size; i++)
    {
        activity_top = ranks_insert_activity_top(
            activity_top,
            stats[i],
            3
        );

        round_top = ranks_insert_round_top(
            round_top,
            stats[i],
            3
        );
    }

    ranks_private(player, "^5=== MOST ACTIVE PLAYERS ===");

    for (i = 0; i < activity_top.size; i++)
    {
        stat = activity_top[i];
        ranks_private(
            player,
            "^7" + (i + 1) + ". ^2" + stat.name +
            " ^7- " + ranks_format_duration(stat.total_seconds)
        );
    }

    ranks_private(player, "^5=== BEST PERSONAL ROUNDS ===");

    for (i = 0; i < round_top.size; i++)
    {
        stat = round_top[i];
        ranks_private(
            player,
            "^7" + (i + 1) + ". ^2" + stat.name +
            " ^7- Round " + stat.best_round
        );
    }
}

function cmd_ezzrecords(args)
{
    if (args.size <= 0)
    {
        println(
            "^3[PinteMod Ranks]^7 Usage: " +
            "ezzrecords <PlayerName|BOIII_XUID|ClientNumber> [1-4]"
        );
        return;
    }

    requested_team_size = 0;
    player_name = ranks_join_args(args, 0);
    player = ranks_find_player(player_name);

    // First prefer an exact full player name. This avoids interpreting
    // a nickname ending in 1, 2, 3 or 4 as a category argument.
    if (!isdefined(player) && args.size >= 2)
    {
        possible_team_size = int(args[args.size - 1]);

        if (possible_team_size >= 1 && possible_team_size <= 4)
        {
            requested_team_size = possible_team_size;
            player_name = ranks_join_args_until(
                args,
                0,
                args.size - 1
            );
            player = ranks_find_player(player_name);
        }
    }

    if (!isdefined(player))
        return;

    map_name = ranks_get_map_name();
    display_name = ranks_get_map_display(map_name);
    json = ranks_load_map_json(map_name);

    if (requested_team_size <= 0)
    {
        ranks_private(player, "^5=== " + display_name + " RECORDS ===");

        for (team_size = 1; team_size <= 4; team_size++)
        {
            top_record = ranks_load_record(json, team_size, 1);

            if (!isdefined(top_record))
            {
                ranks_private(
                    player,
                    "^7" + team_size + "P: ^3No record yet"
                );
                continue;
            }

            ranks_private(
                player,
                "^7" + team_size + "P: ^2R" + top_record.round +
                " ^3" + ranks_format_record_duration(top_record.seconds) +
                " ^7| " + top_record.holders
            );
        }

        ranks_private(
            player,
            "^3Use .records <1-4> or Community > Rankings & Records."
        );
        return;
    }

    ranks_private(
        player,
        "^5=== " + display_name + " " + requested_team_size +
        "P TOP 5 ==="
    );
    has_record = false;

    for (position = 1;
        position <= level.pintemod_ranks_max_records_per_category;
        position++)
    {
        record = ranks_load_record(json, requested_team_size, position);

        if (!isdefined(record))
            continue;

        has_record = true;
        ranks_private(
            player,
            "^7#" + position + " ^2R" + record.round +
            " ^3" + ranks_format_record_duration(record.seconds) +
            " ^7| " + record.holders
        );
    }

    if (!has_record)
        ranks_private(player, "^3No record yet");

    ranks_private(
        player,
        "^7Easter Egg speed: ^3disabled until map-specific detection is verified."
    );
}

function cmd_ezzrankstatus(args)
{
    stats = ranks_collect_all_stats();
    map_name = ranks_get_map_name();
    map_json = ranks_load_map_json(map_name);

    println("^5===== PINTEMOD RANKS v2.0 =====");
    println("^7Enabled: " + level.pintemod_ranks_enabled);
    println("^7Identity kind: " + level.pintemod_ranks_identity_kind);
    println("^7Player schema: " + level.pintemod_ranks_player_schema_version);
    println("^7Map schema: " + level.pintemod_ranks_map_schema_version);
    println("^7Known XUID players: " + stats.size);
    println("^7Match participants: " + level.pintemod_ranks_participants.size);
    println("^7Current map: " + ranks_get_map_display(map_name));
    println("^7Current match ranked: " + level.pintemod_ranks_match_ranked);

    if (!level.pintemod_ranks_match_ranked)
    {
        println(
            "^7Unranked by: " + level.pintemod_ranks_unranked_command +
            " | target: " + level.pintemod_ranks_unranked_target
        );
    }

    for (team_size = 1; team_size <= 4; team_size++)
    {
        top_record = ranks_load_record(map_json, team_size, 1);

        if (!isdefined(top_record))
        {
            println("^7" + team_size + "P top record: none");
            continue;
        }

        println(
            "^7" + team_size + "P top record: Round " +
            top_record.round + " | " +
            ranks_format_record_duration(top_record.seconds) +
            " | " + top_record.holders +
            " | xuids=" + top_record.holder_xuids
        );
    }

    println(
        "^7Match elapsed: " +
        ranks_format_record_duration(
            level.pintemod_ranks_match_elapsed_seconds
        )
    );
    println(
        "^7Record presence required: " +
        level.pintemod_ranks_record_presence_percent + "%"
    );
    println(
        "^7Records kept per category: " +
        level.pintemod_ranks_max_records_per_category
    );
    println(
        "^7Activity flush interval: " +
        level.pintemod_ranks_activity_flush_seconds + "s"
    );
    println(
        "^7Record chat minimum round: " +
        level.pintemod_ranks_record_announcement_min_round
    );
    println("^7Player data: boiii/scriptdata/" + ranks_players_directory());
    println("^7Map data: boiii/scriptdata/" + ranks_maps_directory());
    println("^7Legacy v1 preserved: boiii/scriptdata/" + ranks_legacy_root());
    println(
        "^7Log: boiii/scriptdata/" +
        ezz_admin_storage::get_active_log_root() + "/ranks.log"
    );
    println(
        "^7Live Console records: boiii/scriptdata/" +
        ezz_admin_storage::get_active_log_root() + "/community.log"
    );

    maintenance = ranks_load_maintenance_json();
    println(
        "^7Last backup ID: " +
        ranks_json_int(maintenance, "last_backup_id", 0)
    );
    println(
        "^7Last backup path: " +
        ranks_json_string(maintenance, "last_backup_path", "none")
    );
    println("^7Migration: ezzrankmigrationstatus");
    println("^7Grouped suite: ezzranktest suite [PlayerName|BOIII_XUID|ClientNumber]");
    println("^7Maintenance: ezzrankaudit | ezzrankbackup [label]");
    println("^7Protected XUID reset: ezzrankreset prepare");
    println("^5============================================");
}

