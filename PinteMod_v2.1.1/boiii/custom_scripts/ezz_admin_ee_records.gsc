// ============================================================
// PinteMod — Easter Egg Records v2.0.1
// Fichier : ezz_admin_ee_records.gsc
//
// Profils des 14 maps officielles BO3 Zombies.
// Neuf quetes principales disposent d un detecteur passif.
// Ecriture officielle uniquement pour un profil explicitement OFFICIAL.
// Un profil doit avoir ete observe, valide puis active manuellement.
// La categorie represente la taille de completion de la quete lorsque
// quatre joueurs sont obligatoires. Seuls les joueurs actifs avec au
// moins 70% de presence deviennent titulaires du record.
// Le coeur des detecteurs v0.4.4 reste gele. Le stockage v2 utilise
// exclusivement le BOIII_XUID pour participants, titulaires et signatures.
// Aucune lecture ni migration du stockage legacy par pseudonyme.
// Les simulations utilisent un stockage TEST v2 totalement separe.
// ============================================================

#using scripts\shared\flag_shared;
#using custom_scripts\ezz_admin_identity;
#using custom_scripts\ezz_admin_storage;
#using custom_scripts\ezz_admin_registry;


function ee_diag_bool_text(value)
{
    if (isdefined(value) && value)
        return "true";

    return "false";
}

function ee_identity_kind()
{
    return "BOIII_XUID";
}

function ee_identity_player_xuid(player)
{
    if (!isdefined(player))
        return "";

    xuid = ezz_admin_identity::get_player_xuid(player);

    if (!ezz_admin_identity::is_valid_xuid(xuid))
        return "";

    return ezz_admin_identity::normalize_xuid(xuid);
}

function ee_diag_participant_xuid(participant)
{
    if (!isdefined(participant) ||
        !isdefined(participant.xuid))
    {
        return "";
    }

    xuid = ezz_admin_identity::normalize_xuid(participant.xuid);

    if (!ezz_admin_identity::is_valid_xuid(xuid))
        return "";

    return xuid;
}

function ee_diag_map_name()
{
    return toLower(GetDvarString("mapname"));
}

function ee_diag_event_prefix()
{
    map_name = ee_diag_map_name();

    switch (map_name)
    {
        case "zm_zod": return "ZOD";
        case "zm_factory": return "FACTORY";
        case "zm_castle": return "CASTLE";
        case "zm_island": return "ISLAND";
        case "zm_stalingrad": return "STALINGRAD";
        case "zm_genesis": return "GENESIS";
        case "zm_prototype": return "PROTOTYPE";
        case "zm_asylum": return "ASYLUM";
        case "zm_sumpf": return "SUMPF";
        case "zm_theater": return "THEATER";
        case "zm_cosmodrome": return "COSMODROME";
        case "zm_temple": return "TEMPLE";
        case "zm_moon": return "MOON";
        case "zm_tomb": return "TOMB";
    }

    return "EE";
}

function ee_diag_round()
{
    if (isdefined(level.round_number))
        return int(level.round_number);

    return 0;
}

function ee_diag_elapsed_seconds()
{
    if (isdefined(level.pintemod_ranks_match_elapsed_seconds))
        return int(level.pintemod_ranks_match_elapsed_seconds);

    return 0;
}

function ee_diag_match_ranked()
{
    if (!isdefined(level.pintemod_ranks_match_ranked))
        return false;

    return level.pintemod_ranks_match_ranked;
}

function ee_diag_presence_percent(present_seconds)
{
    elapsed_seconds = ee_diag_elapsed_seconds();

    if (!isdefined(present_seconds) || elapsed_seconds <= 0)
        return 0;

    percentage = int((present_seconds * 100) / elapsed_seconds);

    if (percentage > 100)
        percentage = 100;

    if (percentage < 0)
        percentage = 0;

    return percentage;
}

function ee_diag_required_presence()
{
    if (isdefined(level.pintemod_ranks_record_presence_percent))
        return int(level.pintemod_ranks_record_presence_percent);

    return 70;
}

function ee_diag_is_completion_participant(participant)
{
    if (!isdefined(participant) ||
        ee_diag_participant_xuid(participant) == "" ||
        !isdefined(participant.connected) ||
        !participant.connected ||
        !isdefined(participant.has_played) ||
        !participant.has_played)
    {
        return false;
    }

    return true;
}


function ee_diag_count_completion_participants()
{
    count = 0;

    if (!isdefined(level.pintemod_ranks_participants))
        return count;

    for (i = 0; i < level.pintemod_ranks_participants.size; i++)
    {
        if (ee_diag_is_completion_participant(
            level.pintemod_ranks_participants[i]
        ))
        {
            count++;
        }
    }

    return count;
}

function ee_diag_collect_completion_names()
{
    result = "";

    if (!isdefined(level.pintemod_ranks_participants))
        return result;

    for (i = 0; i < level.pintemod_ranks_participants.size; i++)
    {
        participant = level.pintemod_ranks_participants[i];

        if (!ee_diag_is_completion_participant(participant))
            continue;

        if (result != "")
            result = result + " + ";

        if (isdefined(participant.name) && participant.name != "")
            result = result + participant.name;
        else
            result = result + "UnknownPlayer";
    }

    return result;
}

function ee_diag_collect_ineligible_completion_names()
{
    result = "";

    if (!isdefined(level.pintemod_ranks_participants))
        return result;

    required_presence = ee_diag_required_presence();

    for (i = 0; i < level.pintemod_ranks_participants.size; i++)
    {
        participant = level.pintemod_ranks_participants[i];

        if (!ee_diag_is_completion_participant(participant) ||
            !isdefined(participant.present_seconds))
        {
            continue;
        }

        percentage = ee_diag_presence_percent(
            participant.present_seconds
        );

        if (percentage >= required_presence)
            continue;

        if (result != "")
            result = result + " + ";

        if (isdefined(participant.name) && participant.name != "")
            result = result + participant.name;
        else
            result = result + "UnknownPlayer";

        result = result + "(" + percentage + "%)";
    }

    return result;
}

function ee_diag_collect_eligible_names()
{
    result = "";

    if (!isdefined(level.pintemod_ranks_participants))
        return result;

    required_presence = ee_diag_required_presence();

    for (i = 0; i < level.pintemod_ranks_participants.size; i++)
    {
        participant = level.pintemod_ranks_participants[i];

        if (!ee_diag_is_completion_participant(participant) ||
            !isdefined(participant.present_seconds))
        {
            continue;
        }

        if (ee_diag_presence_percent(participant.present_seconds) <
            required_presence)
        {
            continue;
        }

        if (result != "")
            result = result + " + ";

        if (isdefined(participant.name) && participant.name != "")
            result = result + participant.name;
        else
            result = result + "UnknownPlayer";
    }

    return result;
}

function ee_diag_collect_completion_xuids()
{
    result = "";

    if (!isdefined(level.pintemod_ranks_participants))
        return result;

    for (i = 0; i < level.pintemod_ranks_participants.size; i++)
    {
        participant = level.pintemod_ranks_participants[i];

        if (!ee_diag_is_completion_participant(participant))
            continue;

        xuid = ee_diag_participant_xuid(participant);

        if (xuid == "")
            continue;

        if (result != "")
            result = result + "+";

        result = result + xuid;
    }

    return result;
}

function ee_diag_collect_ineligible_completion_xuids()
{
    result = "";

    if (!isdefined(level.pintemod_ranks_participants))
        return result;

    required_presence = ee_diag_required_presence();

    for (i = 0; i < level.pintemod_ranks_participants.size; i++)
    {
        participant = level.pintemod_ranks_participants[i];

        if (!ee_diag_is_completion_participant(participant) ||
            !isdefined(participant.present_seconds))
        {
            continue;
        }

        if (ee_diag_presence_percent(participant.present_seconds) >=
            required_presence)
        {
            continue;
        }

        xuid = ee_diag_participant_xuid(participant);

        if (xuid == "")
            continue;

        if (result != "")
            result = result + "+";

        result = result + xuid;
    }

    return result;
}

function ee_diag_collect_eligible_xuids()
{
    result = "";

    if (!isdefined(level.pintemod_ranks_participants))
        return result;

    required_presence = ee_diag_required_presence();

    for (i = 0; i < level.pintemod_ranks_participants.size; i++)
    {
        participant = level.pintemod_ranks_participants[i];

        if (!ee_diag_is_completion_participant(participant) ||
            !isdefined(participant.present_seconds))
        {
            continue;
        }

        if (ee_diag_presence_percent(participant.present_seconds) <
            required_presence)
        {
            continue;
        }

        xuid = ee_diag_participant_xuid(participant);

        if (xuid == "")
            continue;

        if (result != "")
            result = result + "+";

        result = result + xuid;
    }

    return result;
}

function ee_diag_count_eligible_participants()
{
    count = 0;

    if (!isdefined(level.pintemod_ranks_participants))
        return count;

    required_presence = ee_diag_required_presence();

    for (i = 0; i < level.pintemod_ranks_participants.size; i++)
    {
        participant = level.pintemod_ranks_participants[i];

        if (!ee_diag_is_completion_participant(participant) ||
            !isdefined(participant.present_seconds))
        {
            continue;
        }

        if (ee_diag_presence_percent(participant.present_seconds) >=
            required_presence)
        {
            count++;
        }
    }

    return count;
}

function ee_diag_append(path, text)
{
    if (ezz_admin_storage::append_managed_log(path, text))
        return true;

    println("^1[PinteMod EE]^7 WRITE_FAILED | path=" + path);
    return false;
}

function ee_diag_log_file(event_name, detail)
{
    if (!isdefined(event_name) || event_name == "")
        event_name = "EE_DIAG";

    if (!isdefined(detail))
        detail = "";

    ee_diag_append(
        "pintemod/logs/easter_eggs.log",
        "[" + GetTime() + "] " + event_name + " | " + detail + "\n"
    );
}

function ee_diag_log(event_name, detail, send_live_console)
{
    if (!isdefined(event_name) || event_name == "")
        event_name = "EE_DIAG";

    if (!isdefined(detail))
        detail = "";

    line = "[" + GetTime() + "] " + event_name + " | " + detail;

    println("^6[PinteMod EE]^7 " + event_name + " | " + detail);

    ee_diag_log_file(event_name, detail);

    if (isdefined(send_live_console) && send_live_console)
    {
        ee_diag_append(
            "pintemod/logs/community.log",
            "[" + GetTime() + "] EE_DIAG | " + event_name +
            " | " + detail + "\n"
        );
    }
}

function ee_diag_snapshot(event_name)
{
    eligible_names = ee_diag_collect_eligible_names();
    eligible_count = ee_diag_count_eligible_participants();

    if (eligible_names == "")
        eligible_names = "none";

    detail =
        "map=" + ee_diag_map_name() +
        " | round=" + ee_diag_round() +
        " | elapsed_seconds=" + ee_diag_elapsed_seconds() +
        " | ranked=" + ee_diag_bool_text(ee_diag_match_ranked()) +
        " | eligible_players=" + eligible_count +
        " | players=" + eligible_names;

    ee_diag_log(event_name, detail, true);
}

function ee_diag_wait_for_ranks()
{
    waited_seconds = 0;

    while (!isdefined(level.pintemod_ranks_version) &&
        waited_seconds < 30)
    {
        wait(1);
        waited_seconds++;
    }

    if (!isdefined(level.pintemod_ranks_version))
    {
        ee_diag_log(
            "RANKS_NOT_READY",
            "Ranks module unavailable after 30 seconds",
            true
        );

        return false;
    }

    return true;
}

function ee_diag_wait_for_flag(flag_name, timeout_seconds)
{
    waited_seconds = 0;

    while (!level flag::exists(flag_name))
    {
        if (timeout_seconds > 0 && waited_seconds >= timeout_seconds)
            return false;

        wait(1);
        waited_seconds++;
    }

    return true;
}



// ------------------------------------------------------------
// Multi-map Easter Egg detector profiles
// ------------------------------------------------------------


// ------------------------------------------------------------
// Native candidate ledger
// ------------------------------------------------------------

function ee_records_data_root()
{
    return "pintemod/easter_eggs_v2";
}

function ee_records_legacy_root()
{
    return "pintemod/easter_eggs";
}

function ee_records_test_root()
{
    return ee_records_data_root() + "/test";
}

function ee_records_profile_schema()
{
    return 3;
}

function ee_records_map_schema()
{
    return 2;
}

function ee_candidates_schema()
{
    return 2;
}

function ee_candidates_mode_text(test_mode)
{
    if (test_mode)
        return "TEST";

    return "NATIVE";
}

function ee_candidates_event_name(test_mode, native_name, test_name)
{
    if (test_mode)
        return test_name;

    return native_name;
}

function ee_candidates_max_entries()
{
    return 20;
}

function ee_candidates_fields()
{
    fields = [];
    fields[fields.size] = "id";
    fields[fields.size] = "signature";
    fields[fields.size] = "identity_kind";
    fields[fields.size] = "source";
    fields[fields.size] = "map";
    fields[fields.size] = "trigger";
    fields[fields.size] = "confirmation_trigger";
    fields[fields.size] = "primary_seen";
    fields[fields.size] = "confirmation_seen";
    fields[fields.size] = "primary_seconds";
    fields[fields.size] = "confirmation_seconds";
    fields[fields.size] = "seconds";
    fields[fields.size] = "round";
    fields[fields.size] = "ranked";
    fields[fields.size] = "profile_status";
    fields[fields.size] = "official_enabled";
    fields[fields.size] = "completion_players";
    fields[fields.size] = "completion_names";
    fields[fields.size] = "completion_xuids";
    fields[fields.size] = "presence_detail";
    fields[fields.size] = "active_holders";
    fields[fields.size] = "holders";
    fields[fields.size] = "holder_xuids";
    fields[fields.size] = "excluded";
    fields[fields.size] = "excluded_xuids";
    fields[fields.size] = "record_category";
    fields[fields.size] = "eligibility_outcome";
    fields[fields.size] = "would_be_recordable";
    fields[fields.size] = "outcome";
    fields[fields.size] = "official_data_modified";
    fields[fields.size] = "official_position";
    return fields;
}


function ee_candidates_key(field_name, position)
{
    return "candidate_" + position + "_" + field_name;
}

function ee_candidates_path(map_name, test_mode)
{
    if (test_mode)
    {
        return ee_records_test_root() + "/candidates/maps/" +
            map_name + ".json";
    }

    return ee_records_data_root() + "/candidates/maps/" +
        map_name + ".json";
}


function ee_candidates_default_json(map_name, test_mode)
{
    json = "{}";
    json = jsonset(json, "schema_version", "" + ee_candidates_schema());
    json = jsonset(json, "storage_generation", "2");
    json = jsonset(json, "identity_kind", ee_identity_kind());
    json = jsonset(json, "map", map_name);
    json = jsonset(json, "display", ee_records_map_display(map_name));
    json = jsonset(json, "mode", ee_candidates_mode_text(test_mode));
    json = jsonset(json, "next_candidate_id", "1");
    json = jsonset(json, "candidate_count", "0");
    return json;
}


function ee_candidates_load_json(map_name, test_mode)
{
    path = ee_candidates_path(map_name, test_mode);

    if (!fileexists(path))
        return ee_candidates_default_json(map_name, test_mode);

    json = ee_records_load_json(path);

    if (json == "{}" ||
        ee_records_json_int(json, "schema_version", 0) !=
            ee_candidates_schema() ||
        ee_records_json_string(json, "identity_kind", "") !=
            ee_identity_kind())
    {
        return ee_candidates_default_json(map_name, test_mode);
    }

    return json;
}


function ee_candidates_count(map_name, test_mode)
{
    json = ee_candidates_load_json(map_name, test_mode);
    count = ee_records_json_int(json, "candidate_count", 0);

    if (count < 0)
        count = 0;

    if (count > ee_candidates_max_entries())
        count = ee_candidates_max_entries();

    return count;
}

function ee_candidates_has_signature(json, signature)
{
    if (!isdefined(signature) || signature == "")
        return false;

    count = ee_records_json_int(json, "candidate_count", 0);

    if (count > ee_candidates_max_entries())
        count = ee_candidates_max_entries();

    for (position = 1; position <= count; position++)
    {
        existing = ee_records_json_string(
            json,
            ee_candidates_key("signature", position),
            ""
        );

        if (existing == signature)
            return true;
    }

    return false;
}

function ee_candidates_commit(map_name, test_mode, candidate)
{
    json = ee_candidates_load_json(map_name, test_mode);
    signature = candidate["signature"];

    if (ee_candidates_has_signature(json, signature))
    {
        ee_diag_log(
            ee_candidates_event_name(
                test_mode,
                "NATIVE_CANDIDATE_DUPLICATE_IGNORED",
                "TEST_CANDIDATE_DUPLICATE_IGNORED"
            ),
            "map=" + map_name +
            " | signature=" + signature +
            " | candidate_data_modified=false" +
            " | official_data_modified=false" +
            " | identity=BOIII_XUID" +
            " | active_root=pintemod/easter_eggs_v2" +
            " | legacy_modified=false",
            true
        );
        return false;
    }

    fields = ee_candidates_fields();
    count = ee_records_json_int(json, "candidate_count", 0);

    if (count < 0)
        count = 0;

    if (count > ee_candidates_max_entries())
        count = ee_candidates_max_entries();

    next_id = ee_records_json_int(json, "next_candidate_id", 1);

    if (next_id < 1)
        next_id = 1;

    candidate["id"] = "" + next_id;
    new_count = count + 1;

    if (new_count > ee_candidates_max_entries())
        new_count = ee_candidates_max_entries();

    for (position = new_count; position >= 2; position--)
    {
        for (field_index = 0;
            field_index < fields.size;
            field_index++)
        {
            field_name = fields[field_index];
            previous_value = ee_records_json_string(
                json,
                ee_candidates_key(field_name, position - 1),
                ""
            );
            json = jsonset(
                json,
                ee_candidates_key(field_name, position),
                previous_value
            );
        }
    }

    for (field_index = 0;
        field_index < fields.size;
        field_index++)
    {
        field_name = fields[field_index];
        value = "";

        if (isdefined(candidate[field_name]))
            value = candidate[field_name];

        json = jsonset(
            json,
            ee_candidates_key(field_name, 1),
            value
        );
    }

    json = jsonset(json, "candidate_count", "" + new_count);
    json = jsonset(json, "next_candidate_id", "" + (next_id + 1));

    if (!ee_records_write_json(
        ee_candidates_path(map_name, test_mode),
        json,
        ee_candidates_event_name(
            test_mode,
            "native-candidate-ledger",
            "test-candidate-ledger"
        )
    ))
    {
        ee_diag_log(
            "CANDIDATE_LEDGER_WRITE_FAILED",
            "map=" + map_name +
            " | mode=" + ee_candidates_mode_text(test_mode) +
            " | official_data_modified=false",
            true
        );
        return false;
    }

    level.pintemod_ee_last_candidate_id = next_id;

    ee_diag_log(
        ee_candidates_event_name(
            test_mode,
            "NATIVE_CANDIDATE_STORED",
            "TEST_CANDIDATE_STORED"
        ),
        "map=" + map_name +
        " | candidate_id=" + next_id +
        " | outcome=" + candidate["outcome"] +
        " | eligibility=" + candidate["eligibility_outcome"] +
        " | would_be_recordable=" +
        candidate["would_be_recordable"] +
        " | completion_players=" + candidate["completion_players"] +
        " | active_holders=" + candidate["active_holders"] +
        " | record_category=" + candidate["record_category"] +
        " | signature=" + signature +
        " | candidate_data_modified=true" +
        " | official_data_modified=" +
        candidate["official_data_modified"],
        true
    );

    return true;
}

function ee_candidates_build_presence_detail()
{
    result = "";
    required_presence = ee_diag_required_presence();

    if (!isdefined(level.pintemod_ranks_participants))
        return "none";

    for (i = 0; i < level.pintemod_ranks_participants.size; i++)
    {
        participant = level.pintemod_ranks_participants[i];
        name = "UnknownPlayer";
        xuid = ee_diag_participant_xuid(participant);
        present_seconds = 0;

        if (isdefined(participant.name) && participant.name != "")
            name = participant.name;

        if (isdefined(participant.present_seconds))
            present_seconds = int(participant.present_seconds);

        percentage = ee_diag_presence_percent(present_seconds);
        connected = isdefined(participant.connected) &&
            participant.connected;
        has_played = isdefined(participant.has_played) &&
            participant.has_played;
        eligible = xuid != "" && connected && has_played &&
            percentage >= required_presence;

        if (result != "")
            result = result + " | ";

        result = result + name +
            "{xuid=" + xuid +
            ";presence=" + percentage + "%" +
            ";seconds=" + present_seconds +
            ";connected=" + ee_diag_bool_text(connected) +
            ";played=" + ee_diag_bool_text(has_played) +
            ";eligible=" + ee_diag_bool_text(eligible) + "}";
    }

    if (result == "")
        result = "none";

    return result;
}


function ee_candidates_record_category(
    map_name,
    completion_team_size,
    active_holder_count
)
{
    if (ee_profiles_uses_fixed_completion_category(map_name))
        return ee_profiles_minimum_players(map_name);

    if (active_holder_count >= 1 && active_holder_count <= 4)
        return active_holder_count;

    return 0;
}

function ee_candidates_native_signature(trigger_name, candidate_seconds)
{
    map_name = ee_diag_map_name();
    completion_xuids = ee_diag_collect_completion_xuids();
    holder_xuids = ee_diag_collect_eligible_xuids();

    if (isdefined(level.pintemod_ranks_match_record_id) &&
        level.pintemod_ranks_match_record_id != "")
    {
        return "native|" + map_name + "|" +
            level.pintemod_ranks_match_record_id + "|" +
            trigger_name +
            "|completion_xuids=" + completion_xuids +
            "|holder_xuids=" + holder_xuids;
    }

    return "native|" + map_name +
        "|round=" + ee_diag_round() +
        "|seconds=" + candidate_seconds +
        "|completion_xuids=" + completion_xuids +
        "|holder_xuids=" + holder_xuids +
        "|trigger=" + trigger_name;
}


function ee_candidates_native_eligibility_outcome(
    map_name,
    candidate_seconds
)
{
    if (!ee_profiles_has_main_quest(map_name))
        return "no_main_quest";

    if (!ee_diag_match_ranked())
        return "match_unranked";

    if (candidate_seconds <= 0)
        return "timer_not_started";

    completion_team_size = ee_diag_count_completion_participants();
    active_holder_count = ee_diag_count_eligible_participants();
    holders = ee_diag_collect_eligible_names();

    if (completion_team_size < 1 || completion_team_size > 4)
        return "invalid_completion_team_size";

    if (active_holder_count <
        ee_profiles_minimum_active_holders(map_name) || holders == "")
    {
        return "not_enough_active_holders";
    }

    if (active_holder_count > completion_team_size ||
        active_holder_count > 4)
    {
        return "invalid_active_holder_count";
    }

    if (ee_profiles_uses_fixed_completion_category(map_name) &&
        completion_team_size < ee_profiles_minimum_players(map_name))
    {
        return "below_required_completion_players";
    }

    return "eligible";
}

function ee_candidates_store_native(
    trigger_name,
    candidate_seconds,
    outcome,
    official_data_modified,
    official_position
)
{
    map_name = ee_diag_map_name();
    completion_team_size = ee_diag_count_completion_participants();
    active_holder_count = ee_diag_count_eligible_participants();
    completion_names = ee_diag_collect_completion_names();
    completion_xuids = ee_diag_collect_completion_xuids();
    holders = ee_diag_collect_eligible_names();
    holder_xuids = ee_diag_collect_eligible_xuids();
    excluded = ee_diag_collect_ineligible_completion_names();
    excluded_xuids = ee_diag_collect_ineligible_completion_xuids();
    eligibility_outcome = ee_candidates_native_eligibility_outcome(
        map_name,
        candidate_seconds
    );

    if (completion_names == "")
        completion_names = "none";

    if (completion_xuids == "")
        completion_xuids = "none";

    if (holders == "")
        holders = "none";

    if (holder_xuids == "")
        holder_xuids = "none";

    if (excluded == "")
        excluded = "none";

    if (excluded_xuids == "")
        excluded_xuids = "none";

    candidate = [];
    candidate["signature"] = ee_candidates_native_signature(
        trigger_name,
        candidate_seconds
    );
    candidate["identity_kind"] = ee_identity_kind();
    candidate["source"] = "native";
    candidate["map"] = map_name;
    candidate["trigger"] = trigger_name;
    candidate["confirmation_trigger"] =
        ee_profiles_confirmation_trigger(map_name);
    candidate["primary_seen"] = ee_diag_bool_text(
        level.pintemod_ee_diag_primary_detected
    );
    candidate["confirmation_seen"] = ee_diag_bool_text(
        level.pintemod_ee_diag_confirmation_detected
    );
    candidate["primary_seconds"] = "" +
        level.pintemod_ee_diag_primary_seconds;
    candidate["confirmation_seconds"] = "" +
        level.pintemod_ee_diag_confirmation_seconds;
    candidate["seconds"] = "" + candidate_seconds;
    candidate["round"] = "" + ee_diag_round();
    candidate["ranked"] = ee_diag_bool_text(ee_diag_match_ranked());
    candidate["profile_status"] = ee_profiles_get_status(map_name);
    candidate["official_enabled"] = ee_diag_bool_text(
        ee_profiles_official_enabled(map_name)
    );
    candidate["completion_players"] = "" + completion_team_size;
    candidate["completion_names"] = completion_names;
    candidate["completion_xuids"] = completion_xuids;
    candidate["presence_detail"] =
        ee_candidates_build_presence_detail();
    candidate["active_holders"] = "" + active_holder_count;
    candidate["holders"] = holders;
    candidate["holder_xuids"] = holder_xuids;
    candidate["excluded"] = excluded;
    candidate["excluded_xuids"] = excluded_xuids;
    candidate["record_category"] = "" +
        ee_candidates_record_category(
            map_name,
            completion_team_size,
            active_holder_count
        );
    candidate["eligibility_outcome"] = eligibility_outcome;
    candidate["would_be_recordable"] = ee_diag_bool_text(
        eligibility_outcome == "eligible"
    );
    candidate["outcome"] = outcome;
    candidate["official_data_modified"] =
        ee_diag_bool_text(official_data_modified);
    candidate["official_position"] = "" + official_position;

    return ee_candidates_commit(map_name, false, candidate);
}


function ee_test_xuid(index)
{
    if (index < 1)
        index = 1;

    if (index > 9)
        index = 9;

    return "110000100000000" + index;
}

function ee_candidates_test_completion_xuids(completion_team_size)
{
    result = "";

    for (i = 1; i <= completion_team_size; i++)
    {
        if (result != "")
            result = result + "+";

        result = result + ee_test_xuid(i);
    }

    return result;
}

function ee_candidates_test_holder_xuids(active_holder_count)
{
    result = "";

    for (i = 1; i <= active_holder_count; i++)
    {
        if (result != "")
            result = result + "+";

        result = result + ee_test_xuid(i);
    }

    return result;
}

function ee_candidates_test_excluded_xuids(
    active_holder_count,
    completion_team_size
)
{
    result = "";

    for (i = active_holder_count + 1;
        i <= completion_team_size;
        i++)
    {
        if (result != "")
            result = result + "+";

        result = result + ee_test_xuid(i);
    }

    if (result == "")
        result = "none";

    return result;
}

function ee_candidates_test_names(active_holder_count, completion_team_size)
{
    result = "";

    for (i = 1; i <= completion_team_size; i++)
    {
        if (result != "")
            result = result + " + ";

        if (i <= active_holder_count)
            result = result + "TEST_ACTIVE_" + i;
        else
            result = result + "TEST_LATE_" + i;
    }

    return result;
}

function ee_candidates_test_holders(active_holder_count)
{
    result = "";

    for (i = 1; i <= active_holder_count; i++)
    {
        if (result != "")
            result = result + " + ";

        result = result + "TEST_ACTIVE_" + i;
    }

    if (result == "")
        result = "none";

    return result;
}

function ee_candidates_test_excluded(
    active_holder_count,
    completion_team_size
)
{
    result = "";

    for (i = active_holder_count + 1;
        i <= completion_team_size;
        i++)
    {
        if (result != "")
            result = result + " + ";

        result = result + "TEST_LATE_" + i + "(25%)";
    }

    if (result == "")
        result = "none";

    return result;
}

function ee_candidates_test_presence(
    active_holder_count,
    completion_team_size
)
{
    result = "";

    for (i = 1; i <= completion_team_size; i++)
    {
        if (result != "")
            result = result + " | ";

        if (i <= active_holder_count)
        {
            result = result + "TEST_ACTIVE_" + i +
                "{xuid=" + ee_test_xuid(i) +
                ";presence=100%;seconds=TEST" +
                ";connected=true;played=true;eligible=true}";
        }
        else
        {
            result = result + "TEST_LATE_" + i +
                "{xuid=" + ee_test_xuid(i) +
                ";presence=25%;seconds=TEST" +
                ";connected=true;played=true;eligible=false}";
        }
    }

    return result;
}


function ee_candidates_test_eligibility_outcome(
    map_name,
    completion_team_size,
    active_holder_count,
    ranked
)
{
    if (!ee_profiles_has_main_quest(map_name))
        return "no_main_quest";

    if (!ranked)
        return "match_unranked";

    if (completion_team_size < 1 || completion_team_size > 4)
        return "invalid_completion_team_size";

    if (active_holder_count <
        ee_profiles_minimum_active_holders(map_name))
    {
        return "not_enough_active_holders";
    }

    if (active_holder_count > completion_team_size ||
        active_holder_count > 4)
    {
        return "invalid_active_holder_count";
    }

    if (ee_profiles_uses_fixed_completion_category(map_name) &&
        completion_team_size < ee_profiles_minimum_players(map_name))
    {
        return "below_required_completion_players";
    }

    return "eligible";
}

function ee_candidates_store_test(
    map_name,
    completion_team_size,
    active_holder_count,
    seconds,
    ranked
)
{
    eligibility_outcome = ee_candidates_test_eligibility_outcome(
        map_name,
        completion_team_size,
        active_holder_count,
        ranked
    );
    outcome = eligibility_outcome;
    completion_xuids = ee_candidates_test_completion_xuids(
        completion_team_size
    );
    holder_xuids = ee_candidates_test_holder_xuids(
        active_holder_count
    );
    excluded_xuids = ee_candidates_test_excluded_xuids(
        active_holder_count,
        completion_team_size
    );

    if (eligibility_outcome == "eligible")
        outcome = "profile_not_official";

    candidate = [];
    candidate["signature"] = "test|" + map_name +
        "|completion=" + completion_team_size +
        "|completion_xuids=" + completion_xuids +
        "|active=" + active_holder_count +
        "|holder_xuids=" + holder_xuids +
        "|seconds=" + seconds +
        "|ranked=" + ee_diag_bool_text(ranked) +
        "|outcome=" + outcome;
    candidate["identity_kind"] = ee_identity_kind();
    candidate["source"] = "simulation";
    candidate["map"] = map_name;
    candidate["trigger"] = "SIMULATED_NATIVE_COMPLETION";
    candidate["confirmation_trigger"] =
        ee_profiles_confirmation_trigger(map_name);
    candidate["primary_seen"] = "true";
    candidate["confirmation_seen"] = "true";
    candidate["primary_seconds"] = "" + seconds;
    candidate["confirmation_seconds"] = "" + seconds;
    candidate["seconds"] = "" + seconds;
    candidate["round"] = "1";
    candidate["ranked"] = ee_diag_bool_text(ranked);
    candidate["profile_status"] = "TEST_ONLY";
    candidate["official_enabled"] = "false";
    candidate["completion_players"] = "" + completion_team_size;
    candidate["completion_names"] = ee_candidates_test_names(
        active_holder_count,
        completion_team_size
    );
    candidate["completion_xuids"] = completion_xuids;
    candidate["presence_detail"] = ee_candidates_test_presence(
        active_holder_count,
        completion_team_size
    );
    candidate["active_holders"] = "" + active_holder_count;
    candidate["holders"] =
        ee_candidates_test_holders(active_holder_count);
    candidate["holder_xuids"] = holder_xuids;
    candidate["excluded"] = ee_candidates_test_excluded(
        active_holder_count,
        completion_team_size
    );
    candidate["excluded_xuids"] = excluded_xuids;
    candidate["record_category"] = "" +
        ee_candidates_record_category(
            map_name,
            completion_team_size,
            active_holder_count
        );
    candidate["eligibility_outcome"] = eligibility_outcome;
    candidate["would_be_recordable"] = ee_diag_bool_text(
        eligibility_outcome == "eligible"
    );
    candidate["outcome"] = outcome;
    candidate["official_data_modified"] = "false";
    candidate["official_position"] = "0";

    return ee_candidates_commit(map_name, true, candidate);
}


function ee_candidates_clear_test_map(map_name)
{
    return ee_records_write_json(
        ee_candidates_path(map_name, true),
        ee_candidates_default_json(map_name, true),
        "test-candidate-clear"
    );
}

function ee_candidates_print_map(map_name, test_mode)
{
    json = ee_candidates_load_json(map_name, test_mode);
    count = ee_records_json_int(json, "candidate_count", 0);

    if (count > ee_candidates_max_entries())
        count = ee_candidates_max_entries();

    println(
        "^6========== " + ee_candidates_mode_text(test_mode) +
        " EE CANDIDATES | " + ee_records_map_display(map_name) +
        " =========="
    );

    if (count <= 0)
    {
        println("^7No candidates recorded yet");
        return;
    }

    for (position = 1; position <= count; position++)
    {
        id = ee_records_json_string(
            json,
            ee_candidates_key("id", position),
            "?"
        );
        seconds = ee_records_json_int(
            json,
            ee_candidates_key("seconds", position),
            0
        );
        completion_players = ee_records_json_int(
            json,
            ee_candidates_key("completion_players", position),
            0
        );
        active_holders = ee_records_json_int(
            json,
            ee_candidates_key("active_holders", position),
            0
        );
        record_category = ee_records_json_int(
            json,
            ee_candidates_key("record_category", position),
            0
        );
        outcome = ee_records_json_string(
            json,
            ee_candidates_key("outcome", position),
            "unknown"
        );
        eligibility = ee_records_json_string(
            json,
            ee_candidates_key("eligibility_outcome", position),
            "unknown"
        );
        would_be_recordable = ee_records_json_string(
            json,
            ee_candidates_key("would_be_recordable", position),
            "false"
        );
        holders = ee_records_json_string(
            json,
            ee_candidates_key("holders", position),
            "none"
        );
        holder_xuids = ee_records_json_string(
            json,
            ee_candidates_key("holder_xuids", position),
            "none"
        );
        completion_xuids = ee_records_json_string(
            json,
            ee_candidates_key("completion_xuids", position),
            "none"
        );
        excluded = ee_records_json_string(
            json,
            ee_candidates_key("excluded", position),
            "none"
        );
        presence = ee_records_json_string(
            json,
            ee_candidates_key("presence_detail", position),
            "none"
        );
        signature = ee_records_json_string(
            json,
            ee_candidates_key("signature", position),
            "none"
        );

        println(
            "^3#" + id + "^7 " +
            ee_records_format_duration(seconds) +
            " | round=" + ee_records_json_int(
                json,
                ee_candidates_key("round", position),
                0
            ) +
            " | ranked=" + ee_records_json_string(
                json,
                ee_candidates_key("ranked", position),
                "false"
            ) +
            " | outcome=^3" + outcome
        );
        println(
            "^7eligibility=" + eligibility +
            " | would_be_recordable=" + would_be_recordable
        );
        println(
            "^7completion=" + completion_players + "P" +
            " | category=" + record_category + "P" +
            " | holders=" + active_holders + "/" +
            completion_players + " | " + holders
        );
        println(
            "^8completion_xuids=" + completion_xuids +
            " | holder_xuids=" + holder_xuids
        );
        println("^7excluded=" + excluded);
        println("^7presence=" + presence);
        println("^8signature=" + signature);
    }

    println("^6============================================");
}

function ee_candidates_print_summary(test_mode)
{
    maps = ee_profiles_maps();
    println(
        "^6========== " + ee_candidates_mode_text(test_mode) +
        " EE CANDIDATE SUMMARY =========="
    );

    for (i = 0; i < maps.size; i++)
    {
        map_name = maps[i];

        if (!ee_profiles_has_main_quest(map_name))
            continue;

        json = ee_candidates_load_json(map_name, test_mode);
        count = ee_records_json_int(json, "candidate_count", 0);
        outcome = "none";
        seconds = 0;

        if (count > 0)
        {
            outcome = ee_records_json_string(
                json,
                ee_candidates_key("outcome", 1),
                "unknown"
            );
            seconds = ee_records_json_int(
                json,
                ee_candidates_key("seconds", 1),
                0
            );
        }

        println(
            "^7" + map_name + " | " +
            ee_records_map_display(map_name) +
            " | candidates=" + count +
            " | latest=" + outcome +
            " | time=" + ee_records_format_duration(seconds)
        );
    }

    println("^6============================================");
}

function cmd_ezzeecandidates(args)
{
    if (args.size <= 0)
    {
        ee_candidates_print_summary(false);
        return;
    }

    test_mode = false;
    map_index = 0;

    if (toLower(args[0]) == "test")
    {
        test_mode = true;
        map_index = 1;

        if (args.size <= 1)
        {
            ee_candidates_print_summary(true);
            return;
        }
    }

    requested = args[map_index];

    if (toLower(requested) == "current")
        map_name = ee_diag_map_name();
    else
        map_name = ee_profiles_resolve_map(requested);

    if (!isdefined(map_name))
    {
        println("^1[PinteMod EE]^7 Unknown map alias: " + requested);
        println("^7Usage: ezzeecandidates|ezzeecands [test] [map|current]");
        return;
    }

    ee_candidates_print_map(map_name, test_mode);
}

function cmd_ezzeeplayers(args)
{
    println("^6========== PINTEMOD EE XUID PARTICIPANTS ==========");
    println(
        "^7Map=" + ee_diag_map_name() +
        " | identity=" + ee_identity_kind() +
        " | elapsed=" + ee_diag_elapsed_seconds() +
        " | round=" + ee_diag_round() +
        " | ranked=" + ee_diag_bool_text(ee_diag_match_ranked()) +
        " | required_presence=" + ee_diag_required_presence() + "%"
    );

    if (!isdefined(level.pintemod_ranks_participants) ||
        level.pintemod_ranks_participants.size <= 0)
    {
        println("^7No rank participants attached yet");
        return;
    }

    for (i = 0; i < level.pintemod_ranks_participants.size; i++)
    {
        participant = level.pintemod_ranks_participants[i];
        name = "UnknownPlayer";
        xuid = ee_diag_participant_xuid(participant);
        present_seconds = 0;

        if (isdefined(participant.name) && participant.name != "")
            name = participant.name;

        if (isdefined(participant.present_seconds))
            present_seconds = int(participant.present_seconds);

        percentage = ee_diag_presence_percent(present_seconds);
        connected = isdefined(participant.connected) &&
            participant.connected;
        has_played = isdefined(participant.has_played) &&
            participant.has_played;
        completion_participant = xuid != "" && connected && has_played;
        eligible = completion_participant &&
            percentage >= ee_diag_required_presence();

        println(
            "^7" + name +
            " | xuid=" + xuid +
            " | present=" + present_seconds + "s" +
            " | presence=" + percentage + "%" +
            " | connected=" + ee_diag_bool_text(connected) +
            " | played=" + ee_diag_bool_text(has_played) +
            " | completion=" +
            ee_diag_bool_text(completion_participant) +
            " | eligible=" + ee_diag_bool_text(eligible)
        );
    }

    println(
        "^7Completion players=" +
        ee_diag_count_completion_participants() +
        " | completion_xuids=" + ee_diag_collect_completion_xuids()
    );
    println(
        "^7Active holders=" +
        ee_diag_count_eligible_participants() +
        " | holder_xuids=" + ee_diag_collect_eligible_xuids()
    );
    println("^6===================================================");
}


function ee_profiles_maps()
{
    return ezz_admin_registry::official_map_codes();
}

function ee_profiles_is_known_map(map_name)
{
    return ezz_admin_registry::is_official_map(map_name);
}

function ee_profiles_resolve_map(value)
{
    return ezz_admin_registry::resolve_map_alias(value);
}

function ee_profiles_has_main_quest(map_name)
{
    return ezz_admin_registry::map_has_main_quest(map_name);
}

function ee_profiles_minimum_players(map_name)
{
    return ezz_admin_registry::map_min_ee_players(map_name);
}

function ee_profiles_uses_fixed_completion_category(map_name)
{
    return ee_profiles_minimum_players(map_name) == 4;
}

function ee_profiles_minimum_active_holders(map_name)
{
    if (ee_profiles_uses_fixed_completion_category(map_name))
        return 2;

    if (ee_profiles_has_main_quest(map_name))
        return 1;

    return 0;
}

function ee_profiles_trigger_type(map_name)
{
    switch (map_name)
    {
        case "zm_zod": return "FLAG";
        case "zm_castle": return "DUAL_FLAG";
        case "zm_island": return "FLAG";
        case "zm_stalingrad": return "NOTIFY";
        case "zm_genesis": return "NOTIFY";
        case "zm_cosmodrome": return "NOTIFY";
        case "zm_temple": return "NOTIFY";
        case "zm_moon": return "NOTIFY";
        case "zm_tomb": return "NOTIFY_FLAG";
    }

    return "NONE";
}

function ee_profiles_primary_trigger(map_name)
{
    switch (map_name)
    {
        case "zm_zod": return "ee_complete";
        case "zm_castle": return "sent_rockets_to_the_moon";
        case "zm_island": return "flag_play_outro_cutscene";
        case "zm_stalingrad": return "hash_c1471acf";
        case "zm_genesis": return "hash_91a3107";
        case "zm_cosmodrome": return "help_found";
        case "zm_temple": return "temple_sidequest_achieved";
        case "zm_moon": return "moon_sidequest_achieved";
        case "zm_tomb": return "ee_samantha_released";
    }

    return "none";
}

function ee_profiles_confirmation_trigger(map_name)
{
    switch (map_name)
    {
        case "zm_castle": return "ee_outro";
        case "zm_tomb": return "tomb_sidequest_complete";
    }

    return "none";
}

function ee_profiles_status_valid(map_name, status)
{
    if (!ee_profiles_has_main_quest(map_name))
        return status == "NO_MAIN_QUEST";

    return status == "DIAGNOSTIC" ||
        status == "NATIVE_DETECTED" ||
        status == "VALIDATED" ||
        status == "OFFICIAL";
}

function ee_profiles_default_status(map_name)
{
    if (!ee_profiles_has_main_quest(map_name))
        return "NO_MAIN_QUEST";

    return "DIAGNOSTIC";
}

function ee_profiles_state_path()
{
    return ee_records_data_root() + "/profiles.json";
}


function ee_profiles_status_key(map_name)
{
    return "status_" + map_name;
}

function ee_profiles_native_key(map_name)
{
    return "native_seen_" + map_name;
}

function ee_profiles_seconds_key(map_name)
{
    return "native_seconds_" + map_name;
}

function ee_profiles_round_key(map_name)
{
    return "native_round_" + map_name;
}

function ee_profiles_trigger_key(map_name)
{
    return "native_trigger_" + map_name;
}

function ee_profiles_default_json()
{
    json = "{}";
    json = jsonset(json, "schema_version", "" + ee_records_profile_schema());
    json = jsonset(json, "storage_generation", "2");
    json = jsonset(json, "identity_kind", ee_identity_kind());
    json = jsonset(json, "official_write_mode", "per_map_validated_only");
    json = jsonset(json, "official_mode", "per_map_validated_only");
    json = jsonset(json, "legacy_merge", "disabled");

    maps = ee_profiles_maps();

    for (i = 0; i < maps.size; i++)
    {
        map_name = maps[i];
        json = jsonset(
            json,
            ee_profiles_status_key(map_name),
            ee_profiles_default_status(map_name)
        );
        json = jsonset(json, ee_profiles_native_key(map_name), "0");
        json = jsonset(json, ee_profiles_seconds_key(map_name), "0");
        json = jsonset(json, ee_profiles_round_key(map_name), "0");
        json = jsonset(json, ee_profiles_trigger_key(map_name), "");
    }

    return json;
}


function ee_profiles_load_state()
{
    path = ee_profiles_state_path();

    if (!fileexists(path))
    {
        json = ee_profiles_default_json();
        ee_records_write_json(path, json, "profiles-v2-neutral-create");
        return json;
    }

    json = ee_records_load_json(path);

    if (json == "{}" ||
        ee_records_json_int(json, "schema_version", 0) !=
            ee_records_profile_schema() ||
        ee_records_json_string(json, "identity_kind", "") !=
            ee_identity_kind())
    {
        json = ee_profiles_default_json();
        ee_records_write_json(path, json, "profiles-v2-invalid-reset");
        return json;
    }

    changed = false;
    maps = ee_profiles_maps();

    for (i = 0; i < maps.size; i++)
    {
        map_name = maps[i];
        status_key = ee_profiles_status_key(map_name);
        status = ee_records_json_string(json, status_key, "");

        if (!ee_profiles_status_valid(map_name, status))
        {
            json = jsonset(
                json,
                status_key,
                ee_profiles_default_status(map_name)
            );
            changed = true;
        }

        if (ee_records_json_string(
            json,
            ee_profiles_native_key(map_name),
            ""
        ) == "")
        {
            json = jsonset(json, ee_profiles_native_key(map_name), "0");
            changed = true;
        }

        if (ee_records_json_string(
            json,
            ee_profiles_seconds_key(map_name),
            ""
        ) == "")
        {
            json = jsonset(json, ee_profiles_seconds_key(map_name), "0");
            changed = true;
        }

        if (ee_records_json_string(
            json,
            ee_profiles_round_key(map_name),
            ""
        ) == "")
        {
            json = jsonset(json, ee_profiles_round_key(map_name), "0");
            changed = true;
        }

    }

    if (changed)
        ee_records_write_json(path, json, "profiles-v2-repair");

    return json;
}


function ee_profiles_write_state(context)
{
    return ee_records_write_json(
        ee_profiles_state_path(),
        level.pintemod_ee_profiles_json,
        context
    );
}

function ee_profiles_get_status(map_name)
{
    if (!ee_profiles_is_known_map(map_name))
        return "UNKNOWN_MAP";

    return ee_records_json_string(
        level.pintemod_ee_profiles_json,
        ee_profiles_status_key(map_name),
        ee_profiles_default_status(map_name)
    );
}

function ee_profiles_official_enabled(map_name)
{
    return ee_profiles_get_status(map_name) == "OFFICIAL";
}

function ee_profiles_refresh_current_write_state()
{
    level.pintemod_ee_official_writes_enabled =
        ee_profiles_official_enabled(ee_diag_map_name());
}

function ee_profiles_native_seen(map_name)
{
    return ee_records_json_int(
        level.pintemod_ee_profiles_json,
        ee_profiles_native_key(map_name),
        0
    ) > 0;
}

function ee_profiles_native_seconds(map_name)
{
    return ee_records_json_int(
        level.pintemod_ee_profiles_json,
        ee_profiles_seconds_key(map_name),
        0
    );
}

function ee_profiles_native_round(map_name)
{
    return ee_records_json_int(
        level.pintemod_ee_profiles_json,
        ee_profiles_round_key(map_name),
        0
    );
}

function ee_profiles_native_trigger(map_name)
{
    return ee_records_json_string(
        level.pintemod_ee_profiles_json,
        ee_profiles_trigger_key(map_name),
        "none"
    );
}

function ee_profiles_set_status(map_name, status, context)
{
    if (!ee_profiles_is_known_map(map_name))
        return false;

    if (!ee_profiles_has_main_quest(map_name))
        status = "NO_MAIN_QUEST";

    level.pintemod_ee_profiles_json = jsonset(
        level.pintemod_ee_profiles_json,
        ee_profiles_status_key(map_name),
        status
    );

    if (map_name == ee_diag_map_name())
    {
        level.pintemod_ee_detection_status = status;
        ee_profiles_refresh_current_write_state();
    }

    return ee_profiles_write_state(context);
}

function ee_profiles_reset_map(map_name)
{
    if (!ee_profiles_is_known_map(map_name))
        return false;

    level.pintemod_ee_profiles_json = jsonset(
        level.pintemod_ee_profiles_json,
        ee_profiles_status_key(map_name),
        ee_profiles_default_status(map_name)
    );
    level.pintemod_ee_profiles_json = jsonset(
        level.pintemod_ee_profiles_json,
        ee_profiles_native_key(map_name),
        "0"
    );
    level.pintemod_ee_profiles_json = jsonset(
        level.pintemod_ee_profiles_json,
        ee_profiles_seconds_key(map_name),
        "0"
    );
    level.pintemod_ee_profiles_json = jsonset(
        level.pintemod_ee_profiles_json,
        ee_profiles_round_key(map_name),
        "0"
    );
    level.pintemod_ee_profiles_json = jsonset(
        level.pintemod_ee_profiles_json,
        ee_profiles_trigger_key(map_name),
        ""
    );

    if (map_name == ee_diag_map_name())
    {
        level.pintemod_ee_detection_status =
            ee_profiles_default_status(map_name);
        level.pintemod_ee_native_handled = false;
        ee_profiles_refresh_current_write_state();
    }

    return ee_profiles_write_state("profile-reset");
}

function ee_profiles_mark_native_detected(trigger_name, candidate_seconds)
{
    map_name = ee_diag_map_name();

    if (!ee_profiles_has_main_quest(map_name))
        return;

    if (isdefined(level.pintemod_ee_native_handled) &&
        level.pintemod_ee_native_handled)
    {
        return;
    }

    level.pintemod_ee_native_handled = true;
    level.pintemod_ee_diag_confirmation_detected = true;

    if (!isdefined(candidate_seconds) || candidate_seconds <= 0)
        candidate_seconds = ee_diag_elapsed_seconds();

    level.pintemod_ee_diag_confirmation_seconds = candidate_seconds;

    status = ee_profiles_get_status(map_name);

    level.pintemod_ee_profiles_json = jsonset(
        level.pintemod_ee_profiles_json,
        ee_profiles_native_key(map_name),
        "1"
    );
    level.pintemod_ee_profiles_json = jsonset(
        level.pintemod_ee_profiles_json,
        ee_profiles_seconds_key(map_name),
        "" + candidate_seconds
    );
    level.pintemod_ee_profiles_json = jsonset(
        level.pintemod_ee_profiles_json,
        ee_profiles_round_key(map_name),
        "" + ee_diag_round()
    );
    level.pintemod_ee_profiles_json = jsonset(
        level.pintemod_ee_profiles_json,
        ee_profiles_trigger_key(map_name),
        trigger_name
    );

    if (status != "VALIDATED" && status != "OFFICIAL")
    {
        level.pintemod_ee_profiles_json = jsonset(
            level.pintemod_ee_profiles_json,
            ee_profiles_status_key(map_name),
            "NATIVE_DETECTED"
        );
        status = "NATIVE_DETECTED";
    }

    ee_profiles_write_state("native-detected");
    level.pintemod_ee_detection_status = status;

    ee_diag_log(
        "NATIVE_COMPLETION_DETECTED",
        "map=" + map_name +
        " | display=" + ee_records_map_display(map_name) +
        " | trigger=" + trigger_name +
        " | candidate_seconds=" + candidate_seconds +
        " | round=" + ee_diag_round() +
        " | profile_status=" + status +
        " | official_data_modified=false",
        true
    );

    ee_records_process_native_completion(
        trigger_name,
        candidate_seconds
    );
}

function cmd_ezzeemaps(args)
{
    maps = ee_profiles_maps();

    println("^6========== PINTEMOD EE MAP PROFILES ==========");

    for (i = 0; i < maps.size; i++)
    {
        map_name = maps[i];
        println(
            "^7" + map_name +
            " | " + ee_records_map_display(map_name) +
            " | status=^3" + ee_profiles_get_status(map_name) +
            "^7 | write=" +
            ee_diag_bool_text(ee_profiles_official_enabled(map_name)) +
            " | min_players=" +
            ee_profiles_minimum_players(map_name) +
            " | trigger=" +
            ee_profiles_primary_trigger(map_name)
        );
    }

    println("^7Official mode: ^3PER-MAP / VALIDATED ONLY");
    println("^6===============================================");
}

function cmd_ezzeevalidate(args)
{
    if (args.size <= 0)
    {
        println("^3[PinteMod EE]^7 Usage:");
        println("^7ezzeevalidate <map>");
        println("^7ezzeevalidate <map> confirm");
        println("^7ezzeevalidate <map> reset");
        return;
    }

    map_name = ee_profiles_resolve_map(args[0]);

    if (!isdefined(map_name))
    {
        println("^1[PinteMod EE]^7 Unknown map alias: " + args[0]);
        return;
    }

    if (!ee_profiles_has_main_quest(map_name))
    {
        println(
            "^3[PinteMod EE]^7 " +
            ee_records_map_display(map_name) +
            " has no supported main quest."
        );
        return;
    }

    action = "";

    if (args.size >= 2)
        action = toLower(args[1]);

    if (action == "reset")
    {
        if (ee_profiles_reset_map(map_name))
        {
            println(
                "^2[PinteMod EE]^7 Profile reset to DIAGNOSTIC: " +
                ee_records_map_display(map_name)
            );

            ee_diag_log(
                "PROFILE_RESET",
                "map=" + map_name +
                " | official_write=false",
                true
            );
        }
        return;
    }

    if (!ee_profiles_native_seen(map_name))
    {
        println(
            "^3[PinteMod EE]^7 No real native completion has been " +
            "observed for " + ee_records_map_display(map_name) + "."
        );
        return;
    }

    if (action != "confirm")
    {
        println("^6========== EE VALIDATION REVIEW ==========");
        println("^7Map: " + ee_records_map_display(map_name));
        println("^7Current status: " + ee_profiles_get_status(map_name));
        println("^7Native trigger: " + ee_profiles_native_trigger(map_name));
        println(
            "^7Observed time: " +
            ee_records_format_duration(
                ee_profiles_native_seconds(map_name)
            )
        );
        println("^7Observed round: " + ee_profiles_native_round(map_name));
        println(
            "^3Review easter_eggs.log, then run: " +
            "ezzeevalidate " + map_name + " confirm"
        );
        println(
            "^7Validation does not enable writes. " +
            "Use ezzeeofficial after validation."
        );
        println("^6==========================================");
        return;
    }

    status = ee_profiles_get_status(map_name);

    if (status == "OFFICIAL")
    {
        println(
            "^3[PinteMod EE]^7 Already OFFICIAL: " +
            ee_records_map_display(map_name)
        );
        return;
    }

    if (ee_profiles_set_status(map_name, "VALIDATED", "profile-validated"))
    {
        println(
            "^2[PinteMod EE]^7 Detector marked VALIDATED: " +
            ee_records_map_display(map_name)
        );

        ee_diag_log(
            "PROFILE_VALIDATED",
            "map=" + map_name +
            " | trigger=" + ee_profiles_native_trigger(map_name) +
            " | official_write=false",
            true
        );
    }
}

function cmd_ezzeeval(args)
{
    if (args.size <= 0)
    {
        println("^3[PinteMod EE]^7 Usage: ezzeeval <map>");
        return;
    }

    validate_args = [];
    validate_args[0] = args[0];
    validate_args[1] = "confirm";

    cmd_ezzeevalidate(validate_args);
}


function cmd_ezzeeofficial(args)
{
    if (args.size <= 0)
    {
        println("^3[PinteMod EE]^7 Usage:");
        println("^7ezzeeofficial <map> status");
        println("^7ezzeeofficial <map> enable");
        println("^7ezzeeofficial <map> disable");
        println("^7A map must be VALIDATED before enable.");
        return;
    }

    map_name = ee_profiles_resolve_map(args[0]);

    if (!isdefined(map_name))
    {
        println("^1[PinteMod EE]^7 Unknown map alias: " + args[0]);
        return;
    }

    if (!ee_profiles_has_main_quest(map_name))
    {
        println(
            "^3[PinteMod EE]^7 " +
            ee_records_map_display(map_name) +
            " has no supported main quest."
        );
        return;
    }

    action = "status";

    if (args.size >= 2)
        action = toLower(args[1]);

    status = ee_profiles_get_status(map_name);

    if (action == "status")
    {
        println("^6========== EE OFFICIAL WRITE STATUS ==========");
        println("^7Map: " + ee_records_map_display(map_name));
        println("^7Profile status: ^3" + status);
        println(
            "^7Native completion seen: " +
            ee_diag_bool_text(ee_profiles_native_seen(map_name))
        );
        println(
            "^7Official write enabled: " +
            ee_diag_bool_text(ee_profiles_official_enabled(map_name))
        );
        println("^6==============================================");
        return;
    }

    if (action == "enable")
    {
        if (!ee_profiles_native_seen(map_name))
        {
            println(
                "^1[PinteMod EE]^7 Enable rejected: no native " +
                "completion observed for " +
                ee_records_map_display(map_name) + "."
            );
            return;
        }

        if (status != "VALIDATED" && status != "OFFICIAL")
        {
            println(
                "^1[PinteMod EE]^7 Enable rejected: profile must " +
                "be VALIDATED first. Current status=" + status
            );
            return;
        }

        if (status == "OFFICIAL")
        {
            println(
                "^3[PinteMod EE]^7 Official writes already enabled: " +
                ee_records_map_display(map_name)
            );
            return;
        }

        if (ee_profiles_set_status(map_name, "OFFICIAL", "official-enable"))
        {
            println(
                "^2[PinteMod EE]^7 OFFICIAL writes enabled: " +
                ee_records_map_display(map_name)
            );

            ee_diag_log(
                "PROFILE_OFFICIAL_ENABLED",
                "map=" + map_name +
                " | trigger=" + ee_profiles_native_trigger(map_name) +
                " | future_ranked_completions_only=true",
                true
            );
        }
        return;
    }

    if (action == "disable")
    {
        if (status != "OFFICIAL")
        {
            println(
                "^3[PinteMod EE]^7 Official writes already disabled: " +
                ee_records_map_display(map_name)
            );
            return;
        }

        if (ee_profiles_set_status(map_name, "VALIDATED", "official-disable"))
        {
            println(
                "^2[PinteMod EE]^7 OFFICIAL writes disabled: " +
                ee_records_map_display(map_name)
            );

            ee_diag_log(
                "PROFILE_OFFICIAL_DISABLED",
                "map=" + map_name +
                " | profile_status=VALIDATED",
                true
            );
        }
        return;
    }

    println("^1[PinteMod EE]^7 Unknown official action: " + action);
}

function ee_profiles_arm_log(map_name)
{
    level.pintemod_ee_diag_armed = true;

    ee_diag_log_file(
        "PROFILE_ARMED",
        "map=" + map_name +
        " | display=" + ee_records_map_display(map_name) +
        " | type=" + ee_profiles_trigger_type(map_name) +
        " | primary=" + ee_profiles_primary_trigger(map_name) +
        " | confirmation=" +
        ee_profiles_confirmation_trigger(map_name) +
        " | status=" + ee_profiles_get_status(map_name) +
        " | official_write=" +
        ee_diag_bool_text(ee_profiles_official_enabled(map_name))
    );
}

function ee_profiles_monitor_zod()
{
    level endon("game_ended");
    level endon("end_game");
    ee_diag_wait_for_ranks();

    if (!ee_diag_wait_for_flag("ee_complete", 60))
    {
        ee_diag_log(
            "PROFILE_NOT_ARMED",
            "map=zm_zod | missing_flag=ee_complete",
            true
        );
        return;
    }

    ee_profiles_arm_log("zm_zod");

    if (!level flag::get("ee_complete"))
        level flag::wait_till("ee_complete");

    ee_profiles_mark_native_detected(
        "ee_complete",
        ee_diag_elapsed_seconds()
    );
}

function ee_profiles_monitor_island()
{
    level endon("game_ended");
    level endon("end_game");
    ee_diag_wait_for_ranks();

    if (!ee_diag_wait_for_flag("flag_play_outro_cutscene", 60))
    {
        ee_diag_log(
            "PROFILE_NOT_ARMED",
            "map=zm_island | missing_flag=flag_play_outro_cutscene",
            true
        );
        return;
    }

    ee_profiles_arm_log("zm_island");

    if (!level flag::get("flag_play_outro_cutscene"))
        level flag::wait_till("flag_play_outro_cutscene");

    ee_profiles_mark_native_detected(
        "flag_play_outro_cutscene",
        ee_diag_elapsed_seconds()
    );
}

function ee_profiles_monitor_stalingrad()
{
    level endon("game_ended");
    level endon("end_game");
    ee_diag_wait_for_ranks();
    ee_profiles_arm_log("zm_stalingrad");

    level waittill(#"hash_c1471acf");

    ee_profiles_mark_native_detected(
        "hash_c1471acf",
        ee_diag_elapsed_seconds()
    );
}

function ee_profiles_monitor_genesis()
{
    level endon("game_ended");
    level endon("end_game");
    ee_diag_wait_for_ranks();
    ee_profiles_arm_log("zm_genesis");

    level waittill(#"hash_91a3107");

    ee_profiles_mark_native_detected(
        "hash_91a3107",
        ee_diag_elapsed_seconds()
    );
}

function ee_profiles_monitor_cosmodrome()
{
    level endon("game_ended");
    level endon("end_game");
    ee_diag_wait_for_ranks();
    ee_profiles_arm_log("zm_cosmodrome");

    level waittill(#"help_found");

    ee_profiles_mark_native_detected(
        "help_found",
        ee_diag_elapsed_seconds()
    );
}

function ee_profiles_monitor_temple()
{
    level endon("game_ended");
    level endon("end_game");
    ee_diag_wait_for_ranks();
    ee_profiles_arm_log("zm_temple");

    level waittill(#"temple_sidequest_achieved");

    ee_profiles_mark_native_detected(
        "temple_sidequest_achieved",
        ee_diag_elapsed_seconds()
    );
}

function ee_profiles_monitor_moon()
{
    level endon("game_ended");
    level endon("end_game");
    ee_diag_wait_for_ranks();
    ee_profiles_arm_log("zm_moon");

    level waittill(#"moon_sidequest_achieved");

    ee_profiles_mark_native_detected(
        "moon_sidequest_achieved",
        ee_diag_elapsed_seconds()
    );
}

function ee_profiles_start_current_monitor()
{
    map_name = ee_diag_map_name();

    switch (map_name)
    {
        case "zm_zod":
            level thread ee_profiles_monitor_zod();
            return;

        case "zm_castle":
            level thread ee_diag_castle_monitor();
            return;

        case "zm_island":
            level thread ee_profiles_monitor_island();
            return;

        case "zm_stalingrad":
            level thread ee_profiles_monitor_stalingrad();
            return;

        case "zm_genesis":
            level thread ee_profiles_monitor_genesis();
            return;

        case "zm_cosmodrome":
            level thread ee_profiles_monitor_cosmodrome();
            return;

        case "zm_temple":
            level thread ee_profiles_monitor_temple();
            return;

        case "zm_moon":
            level thread ee_profiles_monitor_moon();
            return;

        case "zm_tomb":
            level thread ee_diag_tomb_monitor();
            return;
    }

    level.pintemod_ee_diag_armed = false;

    ee_diag_log(
        "PROFILE_IDLE",
        "map=" + map_name +
        " | status=" + ee_profiles_get_status(map_name) +
        " | reason=no_supported_main_quest",
        false
    );
}

// ------------------------------------------------------------
// Easter Egg record storage
// ------------------------------------------------------------

function ee_records_private(player, message)
{
    if (isdefined(player))
        player iprintln(message);
}

function ee_records_broadcast(message)
{
    players = GetPlayers();

    for (i = 0; i < players.size; i++)
    {
        if (isdefined(players[i]))
            players[i] iprintln(message);
    }
}

function ee_records_find_completion_player(participant)
{
    participant_xuid = ee_diag_participant_xuid(participant);

    if (participant_xuid == "")
        return undefined;

    players = GetPlayers();

    for (i = 0; i < players.size; i++)
    {
        player = players[i];

        if (!isdefined(player))
            continue;

        if (ee_identity_player_xuid(player) == participant_xuid)
            return player;
    }

    return undefined;
}


function ee_records_notify_active_holders(
    map_name,
    record_category,
    completion_team_size,
    active_holder_count,
    seconds
)
{
    if (!isdefined(level.pintemod_ranks_participants))
        return;

    required_presence = ee_diag_required_presence();

    for (i = 0; i < level.pintemod_ranks_participants.size; i++)
    {
        participant = level.pintemod_ranks_participants[i];

        if (!ee_diag_is_completion_participant(participant) ||
            !isdefined(participant.present_seconds))
        {
            continue;
        }

        player = ee_records_find_completion_player(participant);

        if (!isdefined(player))
            continue;

        percentage = ee_diag_presence_percent(
            participant.present_seconds
        );

        if (percentage >= required_presence)
        {
            ee_records_private(
                player,
                "^2[PinteMod EE]^7 You are credited as an active " +
                "holder of the " + record_category + "P record " +
                "(^2" + percentage + "% presence^7)."
            );
        }
        else
        {
            ee_records_private(
                player,
                "^3[PinteMod EE]^7 EE completed as " +
                completion_team_size + "P, but you were not " +
                "credited: presence " + percentage + "%, required " +
                required_presence + "%."
            );
        }
    }
}

function ee_records_join_args(args, start_index)
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

function ee_records_join_args_until(args, start_index, end_index)
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

function ee_records_find_player(player_name)
{
    return ezz_admin_identity::identity_find_player(player_name);
}

function ee_records_map_display(map_name)
{
    return ezz_admin_registry::get_map_display_name(map_name);
}

function ee_records_format_duration(seconds)
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

function ee_records_json_int(json, key_name, default_value)
{
    if (!isdefined(json) || json == "" || jsonvalid(json))
        return default_value;

    value = jsonparse(json, key_name);

    if (!isdefined(value) || value == "")
        return default_value;

    return int(value);
}

function ee_records_json_string(json, key_name, default_value)
{
    if (!isdefined(json) || json == "" || jsonvalid(json))
        return default_value;

    value = jsonparse(json, key_name);

    if (!isdefined(value) || value == "")
        return default_value;

    return value;
}

function ee_records_path(map_name, test_mode)
{
    if (isdefined(test_mode) && test_mode)
    {
        return ee_records_test_root() + "/maps/" +
            map_name + ".json";
    }

    return ee_records_data_root() + "/maps/" + map_name + ".json";
}


function ee_records_write_json(path, json, context)
{
    if (ezz_admin_storage::write_json_safe(path, json, context))
        return true;

    ee_diag_log(
        "WRITE_FAILED",
        "path=" + path + " | context=" + context,
        true
    );

    return false;
}

function ee_records_load_json(path)
{
    return ezz_admin_storage::load_json_or_default(
        path,
        "{}",
        "ee-records-json"
    );
}

function ee_records_key(field_name, team_size, position)
{
    return field_name + "_" + team_size + "p_" + position;
}

function ee_records_create_default_json(map_name, test_mode)
{
    mode_name = "official";

    if (isdefined(test_mode) && test_mode)
        mode_name = "test";

    json = "{}";
    json = jsonset(json, "schema_version", "" + ee_records_map_schema());
    json = jsonset(json, "storage_generation", "2");
    json = jsonset(json, "identity_kind", ee_identity_kind());
    json = jsonset(json, "mode", mode_name);
    json = jsonset(json, "map", map_name);
    json = jsonset(json, "display", ee_records_map_display(map_name));
    json = jsonset(json, "next_run_id", "1");

    for (team_size = 1; team_size <= 4; team_size++)
    {
        for (position = 1;
            position <= level.pintemod_ee_max_records_per_category;
            position++)
        {
            json = jsonset(
                json,
                ee_records_key("seconds", team_size, position),
                "0"
            );
            json = jsonset(
                json,
                ee_records_key("holders", team_size, position),
                ""
            );
            json = jsonset(
                json,
                ee_records_key("holder_xuids", team_size, position),
                ""
            );
            json = jsonset(
                json,
                ee_records_key("run_id", team_size, position),
                ""
            );
            json = jsonset(
                json,
                ee_records_key("round", team_size, position),
                "0"
            );
            json = jsonset(
                json,
                ee_records_key("source", team_size, position),
                ""
            );
        }
    }

    return json;
}


function ee_records_load_map_json(map_name, test_mode)
{
    path = ee_records_path(map_name, test_mode);

    if (!fileexists(path))
        return ee_records_create_default_json(map_name, test_mode);

    json = ee_records_load_json(path);

    if (json == "{}" ||
        ee_records_json_int(json, "schema_version", 0) !=
            ee_records_map_schema() ||
        ee_records_json_string(json, "identity_kind", "") !=
            ee_identity_kind())
    {
        fresh_json = ee_records_create_default_json(map_name, test_mode);
        ee_records_write_json(path, fresh_json, "v2-schema-reset");
        return fresh_json;
    }

    return json;
}


function ee_records_create_record(
    seconds,
    holders,
    holder_xuids,
    run_id,
    completion_round,
    source
)
{
    record = SpawnStruct();
    record.seconds = seconds;
    record.holders = holders;
    record.holder_xuids = holder_xuids;
    record.run_id = run_id;
    record.round = completion_round;
    record.source = source;
    return record;
}


function ee_records_load_record(json, team_size, position)
{
    seconds = ee_records_json_int(
        json,
        ee_records_key("seconds", team_size, position),
        0
    );

    if (seconds <= 0)
        return undefined;

    return ee_records_create_record(
        seconds,
        ee_records_json_string(
            json,
            ee_records_key("holders", team_size, position),
            "Unknown"
        ),
        ee_records_json_string(
            json,
            ee_records_key("holder_xuids", team_size, position),
            ""
        ),
        ee_records_json_string(
            json,
            ee_records_key("run_id", team_size, position),
            ""
        ),
        ee_records_json_int(
            json,
            ee_records_key("round", team_size, position),
            0
        ),
        ee_records_json_string(
            json,
            ee_records_key("source", team_size, position),
            "unknown"
        )
    );
}


function ee_records_is_better(candidate, existing)
{
    if (!isdefined(existing))
        return true;

    if (candidate.seconds <= 0)
        return false;

    if (existing.seconds <= 0)
        return true;

    return candidate.seconds < existing.seconds;
}

function ee_records_load_category(json, team_size)
{
    records = [];

    for (position = 1;
        position <= level.pintemod_ee_max_records_per_category;
        position++)
    {
        record = ee_records_load_record(json, team_size, position);

        if (isdefined(record))
            records[records.size] = record;
    }

    return records;
}

function ee_records_insert_top(records, candidate, maximum)
{
    result = [];
    inserted = false;

    for (i = 0; i < records.size; i++)
    {
        existing = records[i];

        if (!inserted && ee_records_is_better(candidate, existing))
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

function ee_records_write_category(json, team_size, records)
{
    for (position = 1;
        position <= level.pintemod_ee_max_records_per_category;
        position++)
    {
        index = position - 1;
        seconds = 0;
        holders = "";
        holder_xuids = "";
        run_id = "";
        completion_round = 0;
        source = "";

        if (index < records.size && isdefined(records[index]))
        {
            record = records[index];
            seconds = record.seconds;
            holders = record.holders;
            holder_xuids = record.holder_xuids;
            run_id = record.run_id;
            completion_round = record.round;
            source = record.source;
        }

        json = jsonset(
            json,
            ee_records_key("seconds", team_size, position),
            "" + seconds
        );
        json = jsonset(
            json,
            ee_records_key("holders", team_size, position),
            holders
        );
        json = jsonset(
            json,
            ee_records_key("holder_xuids", team_size, position),
            holder_xuids
        );
        json = jsonset(
            json,
            ee_records_key("run_id", team_size, position),
            run_id
        );
        json = jsonset(
            json,
            ee_records_key("round", team_size, position),
            "" + completion_round
        );
        json = jsonset(
            json,
            ee_records_key("source", team_size, position),
            source
        );
    }

    return json;
}


function ee_records_find_position(records, run_id)
{
    for (i = 0; i < records.size; i++)
    {
        if (isdefined(records[i]) && records[i].run_id == run_id)
            return i;
    }

    return -1;
}

function ee_records_current_official_run_id(map_name, json)
{
    if (isdefined(level.pintemod_ranks_match_record_id) &&
        level.pintemod_ranks_match_record_id != "")
    {
        return "official-ee-" + level.pintemod_ranks_match_record_id;
    }

    next_run_id = ee_records_json_int(json, "next_run_id", 1);

    if (next_run_id < 1)
        next_run_id = 1;

    return "official-ee-" + map_name + "-" + next_run_id;
}

function ee_records_json_has_run_id(json, run_id)
{
    if (!isdefined(run_id) || run_id == "")
        return false;

    for (team_size = 1; team_size <= 4; team_size++)
    {
        for (position = 1;
            position <= level.pintemod_ee_max_records_per_category;
            position++)
        {
            existing_run_id = ee_records_json_string(
                json,
                ee_records_key("run_id", team_size, position),
                ""
            );

            if (existing_run_id == run_id)
                return true;
        }
    }

    return false;
}

function ee_records_insert_official_record(
    map_name,
    team_size,
    seconds,
    holders,
    holder_xuids,
    trigger_name,
    completion_round,
    completion_team_size,
    active_holder_count
)
{
    level.pintemod_ee_last_official_result = "not_attempted";
    level.pintemod_ee_last_official_modified = false;
    level.pintemod_ee_last_official_position = 0;

    if (!ee_profiles_official_enabled(map_name))
    {
        level.pintemod_ee_last_official_result =
            "profile_not_official";
        return false;
    }

    if (!isdefined(holder_xuids) || holder_xuids == "")
    {
        level.pintemod_ee_last_official_result =
            "missing_holder_xuids";
        return false;
    }

    path = ee_records_path(map_name, false);
    json = ee_records_load_map_json(map_name, false);
    run_id = ee_records_current_official_run_id(map_name, json);

    if (ee_records_json_has_run_id(json, run_id))
    {
        level.pintemod_ee_last_official_result =
            "duplicate_blocked";

        ee_diag_log(
            "OFFICIAL_RECORD_DUPLICATE_BLOCKED",
            "map=" + map_name +
            " | run_id=" + run_id +
            " | official_data_modified=false",
            true
        );
        return false;
    }

    candidate = ee_records_create_record(
        seconds,
        holders,
        holder_xuids,
        run_id,
        completion_round,
        "native_" + trigger_name + "_active_holders_" +
        active_holder_count + "of" + completion_team_size
    );

    records = ee_records_load_category(json, team_size);
    records = ee_records_insert_top(
        records,
        candidate,
        level.pintemod_ee_max_records_per_category
    );
    position = ee_records_find_position(records, run_id);

    if (position < 0)
    {
        level.pintemod_ee_last_official_result =
            "outside_top5";

        ee_diag_log(
            "OFFICIAL_RECORD_OUTSIDE_TOP5",
            "map=" + map_name +
            " | team_size=" + team_size +
            " | seconds=" + seconds +
            " | holders=" + holders +
            " | holder_xuids=" + holder_xuids +
            " | run_id=" + run_id +
            " | official_data_modified=false",
            true
        );
        return true;
    }

    next_run_id = ee_records_json_int(json, "next_run_id", 1);

    if (next_run_id < 1)
        next_run_id = 1;

    json = jsonset(json, "next_run_id", "" + (next_run_id + 1));
    json = ee_records_write_category(json, team_size, records);

    if (!ee_records_write_json(path, json, "official-top5-v2"))
    {
        level.pintemod_ee_last_official_result = "write_failed";
        return false;
    }

    level.pintemod_ee_last_official_result = "top5_written";
    level.pintemod_ee_last_official_modified = true;
    level.pintemod_ee_last_official_position = position + 1;

    ee_diag_log(
        "OFFICIAL_RECORD_TOP5",
        "map=" + map_name +
        " | team_size=" + team_size +
        " | position=" + (position + 1) +
        " | seconds=" + seconds +
        " | round=" + completion_round +
        " | holders=" + holders +
        " | holder_xuids=" + holder_xuids +
        " | active_holders=" + active_holder_count +
        " | completion_players=" + completion_team_size +
        " | excluded_players=" +
        (completion_team_size - active_holder_count) +
        " | run_id=" + run_id +
        " | trigger=" + trigger_name +
        " | official_data_modified=true",
        true
    );

    ee_records_broadcast(
        "^5[PinteMod Records]^7 " +
        ee_records_map_display(map_name) + " " + team_size +
        "P EE Top 5: ^2#" + (position + 1) + " " +
        ee_records_format_duration(seconds) +
        " ^7by " + holders +
        " ^3(" + active_holder_count + "/" +
        completion_team_size + " active holders)"
    );

    ee_records_notify_active_holders(
        map_name,
        team_size,
        completion_team_size,
        active_holder_count,
        seconds
    );

    return true;
}


function ee_records_log_official_block(
    trigger_name,
    candidate_seconds,
    reason
)
{
    active_holder_count = ee_diag_count_eligible_participants();
    holders = ee_diag_collect_eligible_names();
    holder_xuids = ee_diag_collect_eligible_xuids();
    completion_team_size = ee_diag_count_completion_participants();
    completion_players = ee_diag_collect_completion_names();
    completion_xuids = ee_diag_collect_completion_xuids();
    excluded_players = ee_diag_collect_ineligible_completion_names();
    excluded_xuids = ee_diag_collect_ineligible_completion_xuids();

    if (holders == "")
        holders = "none";

    if (holder_xuids == "")
        holder_xuids = "none";

    if (completion_players == "")
        completion_players = "none";

    if (completion_xuids == "")
        completion_xuids = "none";

    if (excluded_players == "")
        excluded_players = "none";

    if (excluded_xuids == "")
        excluded_xuids = "none";

    ee_diag_log(
        "OFFICIAL_RECORD_CANDIDATE_BLOCKED",
        "map=" + ee_diag_map_name() +
        " | trigger=" + trigger_name +
        " | seconds=" + candidate_seconds +
        " | round=" + ee_diag_round() +
        " | ranked=" + ee_diag_bool_text(ee_diag_match_ranked()) +
        " | completion_players=" + completion_team_size +
        " | completion_names=" + completion_players +
        " | completion_xuids=" + completion_xuids +
        " | active_holders=" + active_holder_count +
        " | holders=" + holders +
        " | holder_xuids=" + holder_xuids +
        " | excluded=" + excluded_players +
        " | excluded_xuids=" + excluded_xuids +
        " | profile_status=" +
        ee_profiles_get_status(ee_diag_map_name()) +
        " | reason=" + reason +
        " | official_data_modified=false",
        true
    );

    ee_candidates_store_native(
        trigger_name,
        candidate_seconds,
        reason,
        false,
        0
    );
}


function ee_records_process_native_completion(
    trigger_name,
    candidate_seconds
)
{
    map_name = ee_diag_map_name();
    status = ee_profiles_get_status(map_name);

    if (!isdefined(candidate_seconds) || candidate_seconds <= 0)
        candidate_seconds = ee_diag_elapsed_seconds();

    if (status != "OFFICIAL")
    {
        ee_records_log_official_block(
            trigger_name,
            candidate_seconds,
            "profile_not_official"
        );
        return false;
    }

    if (!ee_diag_match_ranked())
    {
        ee_records_log_official_block(
            trigger_name,
            candidate_seconds,
            "match_unranked"
        );
        return false;
    }

    if (candidate_seconds <= 0)
    {
        ee_records_log_official_block(
            trigger_name,
            candidate_seconds,
            "timer_not_started"
        );
        return false;
    }

    completion_team_size = ee_diag_count_completion_participants();
    active_holder_count = ee_diag_count_eligible_participants();
    holders = ee_diag_collect_eligible_names();
    holder_xuids = ee_diag_collect_eligible_xuids();
    completion_xuids = ee_diag_collect_completion_xuids();
    minimum_players = ee_profiles_minimum_players(map_name);
    minimum_active_holders =
        ee_profiles_minimum_active_holders(map_name);

    if (completion_team_size < 1 || completion_team_size > 4)
    {
        ee_records_log_official_block(
            trigger_name,
            candidate_seconds,
            "invalid_completion_team_size"
        );
        return false;
    }

    if (completion_xuids == "")
    {
        ee_records_log_official_block(
            trigger_name,
            candidate_seconds,
            "missing_completion_xuids"
        );
        return false;
    }

    if (active_holder_count < minimum_active_holders ||
        holders == "" || holder_xuids == "")
    {
        ee_records_log_official_block(
            trigger_name,
            candidate_seconds,
            "not_enough_active_holders"
        );
        return false;
    }

    if (active_holder_count > completion_team_size ||
        active_holder_count > 4)
    {
        ee_records_log_official_block(
            trigger_name,
            candidate_seconds,
            "invalid_active_holder_count"
        );
        return false;
    }

    if (ee_profiles_uses_fixed_completion_category(map_name))
    {
        if (completion_team_size < minimum_players)
        {
            ee_records_log_official_block(
                trigger_name,
                candidate_seconds,
                "below_required_completion_players"
            );
            return false;
        }

        record_category = minimum_players;
    }
    else
    {
        record_category = active_holder_count;
    }

    ee_diag_log(
        "ACTIVE_HOLDERS_RESOLVED",
        "map=" + map_name +
        " | completion_players=" + completion_team_size +
        " | completion_xuids=" + completion_xuids +
        " | record_category=" + record_category + "P" +
        " | active_holders=" + active_holder_count +
        " | holders=" + holders +
        " | holder_xuids=" + holder_xuids +
        " | excluded=" +
        ee_diag_collect_ineligible_completion_names() +
        " | excluded_xuids=" +
        ee_diag_collect_ineligible_completion_xuids() +
        " | required_presence=" +
        ee_diag_required_presence() + "%",
        true
    );

    official_result = ee_records_insert_official_record(
        map_name,
        record_category,
        candidate_seconds,
        holders,
        holder_xuids,
        trigger_name,
        ee_diag_round(),
        completion_team_size,
        active_holder_count
    );

    ee_candidates_store_native(
        trigger_name,
        candidate_seconds,
        level.pintemod_ee_last_official_result,
        level.pintemod_ee_last_official_modified,
        level.pintemod_ee_last_official_position
    );

    return official_result;
}


function ee_records_make_test_holders(team_size)
{
    holders = "";

    for (i = 1; i <= team_size; i++)
    {
        if (holders != "")
            holders = holders + " + ";

        holders = holders + "TEST_PLAYER_" + i;
    }

    return holders;
}

function ee_records_make_test_holder_xuids(team_size)
{
    result = "";

    for (i = 1; i <= team_size; i++)
    {
        if (result != "")
            result = result + "+";

        result = result + ee_test_xuid(i);
    }

    return result;
}

function ee_records_insert_test_record_for_map(
    map_name,
    team_size,
    seconds,
    holders,
    source,
    completion_round,
    holder_xuids = ""
)
{
    if (!ee_profiles_is_known_map(map_name))
    {
        ee_diag_log(
            "TEST_RECORD_REJECTED",
            "unknown_map=" + map_name,
            true
        );
        return false;
    }

    if (!ee_profiles_has_main_quest(map_name))
    {
        ee_diag_log(
            "TEST_RECORD_REJECTED",
            "map=" + map_name + " | reason=no_main_quest",
            true
        );
        return false;
    }

    if (team_size < 1 || team_size > 4)
    {
        ee_diag_log(
            "TEST_RECORD_REJECTED",
            "map=" + map_name +
            " | invalid_team_size=" + team_size,
            true
        );
        return false;
    }

    if (seconds <= 0)
    {
        ee_diag_log(
            "TEST_RECORD_REJECTED",
            "map=" + map_name +
            " | invalid_seconds=" + seconds,
            true
        );
        return false;
    }

    if (!isdefined(holders) || holders == "")
        holders = ee_records_make_test_holders(team_size);

    if (!isdefined(holder_xuids) || holder_xuids == "")
        holder_xuids = ee_records_make_test_holder_xuids(team_size);

    if (!isdefined(source) || source == "")
        source = "test";

    if (!isdefined(completion_round) || completion_round < 0)
        completion_round = 0;

    path = ee_records_path(map_name, true);
    json = ee_records_load_map_json(map_name, true);
    next_run_id = ee_records_json_int(json, "next_run_id", 1);
    run_id = "test-" + map_name + "-" + next_run_id;
    json = jsonset(json, "next_run_id", "" + (next_run_id + 1));

    candidate = ee_records_create_record(
        seconds,
        holders,
        holder_xuids,
        run_id,
        completion_round,
        source
    );

    records = ee_records_load_category(json, team_size);
    records = ee_records_insert_top(
        records,
        candidate,
        level.pintemod_ee_max_records_per_category
    );
    position = ee_records_find_position(records, run_id);
    json = ee_records_write_category(json, team_size, records);

    if (!ee_records_write_json(path, json, "test-top5-v2"))
        return false;

    if (position < 0)
    {
        ee_diag_log(
            "TEST_RECORD_OUTSIDE_TOP5",
            "map=" + map_name +
            " | team_size=" + team_size +
            " | seconds=" + seconds +
            " | holders=" + holders +
            " | holder_xuids=" + holder_xuids +
            " | source=" + source,
            true
        );
        return true;
    }

    ee_diag_log(
        "TEST_RECORD_TOP5",
        "map=" + map_name +
        " | team_size=" + team_size +
        " | position=" + (position + 1) +
        " | seconds=" + seconds +
        " | holders=" + holders +
        " | holder_xuids=" + holder_xuids +
        " | source=" + source +
        " | official_data_modified=false",
        true
    );

    return true;
}


function ee_records_insert_test_record(
    team_size,
    seconds,
    holders,
    source
)
{
    holder_xuids = ee_diag_collect_eligible_xuids();

    return ee_records_insert_test_record_for_map(
        ee_diag_map_name(),
        team_size,
        seconds,
        holders,
        source,
        ee_diag_round(),
        holder_xuids
    );
}


function ee_records_insert_current_simulation()
{
    match_ranked = ee_diag_match_ranked();
    seconds = ee_diag_elapsed_seconds();
    team_size = ee_diag_count_eligible_participants();
    holders = ee_diag_collect_eligible_names();

    // Simulation data is stored only under easter_eggs_v2/test/.
    // It may therefore be written while God Mode or Ignore is active.
    // Official Easter Egg records remain protected by ranked checks.
    if (!match_ranked)
    {
        ee_diag_log(
            "TEST_UNRANKED_SIMULATION_ALLOWED",
            "reason=isolated_test_storage" +
            " | official_data_modified=false",
            true
        );
    }

    if (seconds <= 0)
    {
        ee_diag_log(
            "TEST_RECORD_NOT_WRITTEN",
            "reason=timer_not_started | official_data_modified=false",
            true
        );
        return false;
    }

    if (team_size < 1 || team_size > 4 || holders == "")
    {
        ee_diag_log(
            "TEST_RECORD_NOT_WRITTEN",
            "reason=no_eligible_1p_to_4p_team" +
            " | eligible_players=" + team_size +
            " | required_presence=" + ee_diag_required_presence() + "%" +
            " | official_data_modified=false",
            true
        );
        return false;
    }

    source = "simulated_completion";

    if (!match_ranked)
        source = "simulated_completion_unranked";

    return ee_records_insert_test_record(
        team_size,
        seconds,
        holders,
        source
    );
}

function ee_records_clear_test_map_for(map_name)
{
    if (!ee_profiles_is_known_map(map_name))
        return false;

    path = ee_records_path(map_name, true);
    json = ee_records_create_default_json(map_name, true);

    if (!ee_records_write_json(path, json, "test-clear"))
        return false;

    ee_diag_log(
        "TEST_RECORDS_CLEARED",
        "map=" + map_name + " | official_data_modified=false",
        true
    );

    return true;
}

function ee_records_clear_test_map()
{
    return ee_records_clear_test_map_for(ee_diag_map_name());
}

function ee_records_print_console_for(
    map_name,
    test_mode,
    requested_team_size
)
{
    display_name = ee_records_map_display(map_name);
    json = ee_records_load_map_json(map_name, test_mode);
    mode_name = "OFFICIAL";

    if (test_mode)
        mode_name = "TEST";

    println(
        "^6========== " + mode_name + " EE RECORDS | " +
        display_name + " =========="
    );

    if (requested_team_size <= 0)
    {
        for (team_size = 1; team_size <= 4; team_size++)
        {
            record = ee_records_load_record(json, team_size, 1);

            if (!isdefined(record))
            {
                println("^7" + team_size + "P: No record");
                continue;
            }

            println(
                "^7" + team_size + "P: ^2" +
                ee_records_format_duration(record.seconds) +
                " ^7| " + record.holders +
                " ^8[xuids=" + record.holder_xuids + "]"
            );
        }

        return;
    }

    has_record = false;

    for (position = 1;
        position <= level.pintemod_ee_max_records_per_category;
        position++)
    {
        record = ee_records_load_record(
            json,
            requested_team_size,
            position
        );

        if (!isdefined(record))
            continue;

        has_record = true;

        println(
            "^7#" + position + " ^2" +
            ee_records_format_duration(record.seconds) +
            " ^7| " + record.holders +
            " ^8[xuids=" + record.holder_xuids + "]" +
            " ^3[" + record.source + "]"
        );
    }

    if (!has_record)
        println("^3No records yet");
}

function ee_records_print_console(test_mode, requested_team_size)
{
    ee_records_print_console_for(
        ee_diag_map_name(),
        test_mode,
        requested_team_size
    );
}

function ee_records_show_player_records(
    player,
    test_mode,
    requested_team_size
)
{
    if (!isdefined(player))
        return;

    map_name = ee_diag_map_name();
    display_name = ee_records_map_display(map_name);
    json = ee_records_load_map_json(map_name, test_mode);
    mode_label = "";

    if (test_mode)
        mode_label = " TEST";

    if (requested_team_size <= 0)
    {
        ee_records_private(
            player,
            "^5=== " + display_name + " EASTER EGG" +
            mode_label + " RECORDS ==="
        );

        for (team_size = 1; team_size <= 4; team_size++)
        {
            record = ee_records_load_record(json, team_size, 1);

            if (!isdefined(record))
            {
                ee_records_private(
                    player,
                    "^7" + team_size + "P: ^3No record yet"
                );
                continue;
            }

            ee_records_private(
                player,
                "^7" + team_size + "P: ^2" +
                ee_records_format_duration(record.seconds) +
                " ^7| " + record.holders
            );
        }

        if (!test_mode)
        {
            if (ee_profiles_official_enabled(map_name))
            {
                ee_records_private(
                    player,
                    "^2Official saving is active for this map."
                );
            }
            else
            {
                ee_records_private(
                    player,
                    "^3Official saving is not active for this map."
                );
            }
        }

        return;
    }

    ee_records_private(
        player,
        "^5=== " + display_name + " EE " +
        requested_team_size + "P TOP 5" + mode_label + " ==="
    );

    has_record = false;

    for (position = 1;
        position <= level.pintemod_ee_max_records_per_category;
        position++)
    {
        record = ee_records_load_record(
            json,
            requested_team_size,
            position
        );

        if (!isdefined(record))
            continue;

        has_record = true;
        ee_records_private(
            player,
            "^7#" + position + " ^2" +
            ee_records_format_duration(record.seconds) +
            " ^7| " + record.holders
        );
    }

    if (!has_record)
        ee_records_private(player, "^3No record yet");

    if (!test_mode)
    {
        ee_records_private(
            player,
            "^7Detection status: ^3" +
            level.pintemod_ee_detection_status
        );
    }
}

function ee_records_audit_map(map_name)
{
    path = ee_records_path(map_name, false);

    if (!fileexists(path))
    {
        println(
            "^7" + ee_records_map_display(map_name) +
            " | EMPTY | no v2 official file"
        );
        return true;
    }

    json = ee_records_load_json(path);

    if (json == "{}" ||
        ee_records_json_int(json, "schema_version", 0) !=
            ee_records_map_schema() ||
        ee_records_json_string(json, "identity_kind", "") !=
            ee_identity_kind())
    {
        println(
            "^1" + ee_records_map_display(map_name) +
            " | INVALID_JSON_SCHEMA_OR_IDENTITY"
        );
        return false;
    }

    valid = true;
    record_count = 0;
    seen_run_ids = [];

    for (team_size = 1; team_size <= 4; team_size++)
    {
        previous_seconds = 0;

        for (position = 1;
            position <= level.pintemod_ee_max_records_per_category;
            position++)
        {
            record = ee_records_load_record(json, team_size, position);

            if (!isdefined(record))
                continue;

            record_count++;

            if (previous_seconds > 0 &&
                record.seconds < previous_seconds)
            {
                valid = false;
            }

            previous_seconds = record.seconds;

            if (!isdefined(record.run_id) || record.run_id == "" ||
                !isdefined(record.holder_xuids) ||
                record.holder_xuids == "")
            {
                valid = false;
                continue;
            }

            for (i = 0; i < seen_run_ids.size; i++)
            {
                if (seen_run_ids[i] == record.run_id)
                    valid = false;
            }

            seen_run_ids[seen_run_ids.size] = record.run_id;
        }
    }

    result = "OK";

    if (!valid)
        result = "FAILED";

    println(
        "^7" + ee_records_map_display(map_name) +
        " | audit=^3" + result +
        "^7 | records=" + record_count +
        " | identity=" + ee_identity_kind()
    );

    ee_diag_log(
        "OFFICIAL_RECORD_AUDIT",
        "map=" + map_name +
        " | result=" + result +
        " | records=" + record_count +
        " | identity=" + ee_identity_kind(),
        true
    );

    return valid;
}


function cmd_ezzeeaudit(args)
{
    if (args.size <= 0 || toLower(args[0]) == "all")
    {
        maps = ee_profiles_maps();
        passed = 0;
        checked = 0;

        println("^6========== EE OFFICIAL RECORD AUDIT ==========");

        for (i = 0; i < maps.size; i++)
        {
            if (!ee_profiles_has_main_quest(maps[i]))
                continue;

            checked++;

            if (ee_records_audit_map(maps[i]))
                passed++;
        }

        println(
            "^7Audit summary: " + passed + "/" + checked + " passed"
        );
        println("^6==============================================");
        return;
    }

    map_name = ee_profiles_resolve_map(args[0]);

    if (!isdefined(map_name))
    {
        println("^1[PinteMod EE]^7 Unknown map alias: " + args[0]);
        return;
    }

    ee_records_audit_map(map_name);
}

function ee_records_backup_map(map_name)
{
    source_path = ee_records_path(map_name, false);

    if (!fileexists(source_path))
    {
        println(
            "^3[PinteMod EE]^7 No v2 official file to backup for " +
            ee_records_map_display(map_name) + "."
        );
        return true;
    }

    json = ee_records_load_json(source_path);

    if (json == "{}")
        return false;

    backup_path = ee_records_data_root() +
        "/backups/" + map_name + "_latest.json";

    if (!ee_records_write_json(backup_path, json, "official-v2-backup"))
        return false;

    ee_diag_log(
        "OFFICIAL_RECORD_BACKUP",
        "map=" + map_name +
        " | path=" + backup_path +
        " | identity=" + ee_identity_kind(),
        true
    );

    println(
        "^2[PinteMod EE]^7 Backup created: " + backup_path
    );
    return true;
}


function cmd_ezzeebackup(args)
{
    if (args.size <= 0 || toLower(args[0]) == "all")
    {
        maps = ee_profiles_maps();

        for (i = 0; i < maps.size; i++)
        {
            if (ee_profiles_has_main_quest(maps[i]))
                ee_records_backup_map(maps[i]);
        }
        return;
    }

    map_name = ee_profiles_resolve_map(args[0]);

    if (!isdefined(map_name))
    {
        println("^1[PinteMod EE]^7 Unknown map alias: " + args[0]);
        return;
    }

    ee_records_backup_map(map_name);
}

function cmd_ezzeereset(args)
{
    if (args.size < 2)
    {
        println(
            "^3[PinteMod EE]^7 Usage: " +
            "ezzeereset <map> CONFIRM_RESET"
        );
        return;
    }

    map_name = ee_profiles_resolve_map(args[0]);

    if (!isdefined(map_name))
    {
        println("^1[PinteMod EE]^7 Unknown map alias: " + args[0]);
        return;
    }

    if (args[1] != "CONFIRM_RESET")
    {
        println(
            "^1[PinteMod EE]^7 Reset rejected. Exact token required: " +
            "CONFIRM_RESET"
        );
        return;
    }

    if (!ee_records_backup_map(map_name))
    {
        println("^1[PinteMod EE]^7 Reset aborted: backup failed.");
        return;
    }

    path = ee_records_path(map_name, false);
    json = ee_records_create_default_json(map_name, false);

    if (!ee_records_write_json(path, json, "official-reset"))
        return;

    ee_diag_log(
        "OFFICIAL_RECORDS_RESET",
        "map=" + map_name +
        " | profile_status=" + ee_profiles_get_status(map_name),
        true
    );

    println(
        "^2[PinteMod EE]^7 Official Top 5 reset: " +
        ee_records_map_display(map_name)
    );
}

function cmd_ezzeerecord(args)
{
    if (args.size <= 0)
    {
        println("^3[PinteMod EE]^7 Usage: ezzeerecord <PlayerName|BOIII_XUID|ClientNumber>");
        return;
    }

    player_name = ee_records_join_args(args, 0);
    player = ee_records_find_player(player_name);

    if (!isdefined(player))
        return;

    ee_records_private(player, "^5=== CURRENT EASTER EGG RUN ===");
    ee_records_private(
        player,
        "^7Map: ^3" + ee_records_map_display(ee_diag_map_name())
    );
    ee_records_private(
        player,
        "^7Timer: ^2" +
        ee_records_format_duration(ee_diag_elapsed_seconds()) +
        " ^7| Round: ^2" + ee_diag_round()
    );
    match_status = "^1UNRANKED";

    if (ee_diag_match_ranked())
        match_status = "^2RANKED";

    ee_records_private(player, "^7Match: " + match_status);
    ee_records_private(
        player,
        "^7Eligible players: ^3" +
        ee_diag_count_eligible_participants() +
        " ^7| Required presence: ^3" +
        ee_diag_required_presence() + "%"
    );
    ee_records_private(
        player,
        "^7Detector: ^3" + level.pintemod_ee_detection_status
    );
    if (ee_profiles_official_enabled(ee_diag_map_name()))
    {
        ee_records_private(
            player,
            "^2Official record saving is active for this map."
        );
    }
    else
    {
        ee_records_private(
            player,
            "^3Official record saving is not active for this map."
        );
    }
}

function cmd_ezzeerecords(args)
{
    if (args.size <= 0)
    {
        println(
            "^3[PinteMod EE]^7 Usage: " +
            "ezzeerecords <PlayerName|BOIII_XUID|ClientNumber> [1-4]"
        );
        return;
    }

    requested_team_size = 0;
    player_name = ee_records_join_args(args, 0);
    player = ee_records_find_player(player_name);

    if (!isdefined(player) && args.size >= 2)
    {
        possible_team_size = int(args[args.size - 1]);

        if (possible_team_size >= 1 && possible_team_size <= 4)
        {
            requested_team_size = possible_team_size;
            player_name = ee_records_join_args_until(
                args,
                0,
                args.size - 1
            );
            player = ee_records_find_player(player_name);
        }
    }

    if (!isdefined(player))
        return;

    ee_records_show_player_records(
        player,
        false,
        requested_team_size
    );
}

function cmd_ezzeetestrecords(args)
{
    if (args.size <= 0)
    {
        println(
            "^3[PinteMod EE]^7 Usage: " +
            "ezzeetestrecords <PlayerName|BOIII_XUID|ClientNumber> [1-4]"
        );
        return;
    }

    requested_team_size = 0;
    player_name = ee_records_join_args(args, 0);
    player = ee_records_find_player(player_name);

    if (!isdefined(player) && args.size >= 2)
    {
        possible_team_size = int(args[args.size - 1]);

        if (possible_team_size >= 1 && possible_team_size <= 4)
        {
            requested_team_size = possible_team_size;
            player_name = ee_records_join_args_until(
                args,
                0,
                args.size - 1
            );
            player = ee_records_find_player(player_name);
        }
    }

    if (!isdefined(player))
        return;

    ee_records_show_player_records(
        player,
        true,
        requested_team_size
    );
}

function ee_diag_tomb_final_step_listener()
{
    level endon("game_ended");
    level endon("end_game");

    level waittill(#"tomb_sidequest_complete");

    level.pintemod_ee_diag_primary_detected = true;
    level.pintemod_ee_diag_primary_seconds = ee_diag_elapsed_seconds();

    ee_diag_snapshot("TOMB_FINAL_STEP_STARTED");
}

function ee_diag_tomb_monitor()
{
    level endon("game_ended");
    level endon("end_game");

    level thread ee_diag_tomb_final_step_listener();

    ee_diag_wait_for_ranks();

    if (!ee_diag_wait_for_flag("ee_samantha_released", 60))
    {
        ee_diag_log(
            "PROFILE_NOT_ARMED",
            "map=zm_tomb | missing_flag=ee_samantha_released",
            true
        );
        return;
    }

    ee_profiles_arm_log("zm_tomb");

    if (!level flag::get("ee_samantha_released"))
        level flag::wait_till("ee_samantha_released");

    level.pintemod_ee_diag_confirmation_detected = true;
    level.pintemod_ee_diag_confirmation_seconds =
        ee_diag_elapsed_seconds();

    ee_diag_snapshot("TOMB_COMPLETION_DETECTED");

    if (level.pintemod_ee_diag_primary_detected)
    {
        delta_seconds =
            level.pintemod_ee_diag_confirmation_seconds -
            level.pintemod_ee_diag_primary_seconds;

        ee_diag_log(
            "TOMB_SIGNAL_COMPARISON",
            "final_step_seconds=" +
            level.pintemod_ee_diag_primary_seconds +
            " | completion_seconds=" +
            level.pintemod_ee_diag_confirmation_seconds +
            " | delta_seconds=" + delta_seconds +
            " | selected_record_trigger=ee_samantha_released",
            true
        );
    }
    else
    {
        ee_diag_log(
            "TOMB_SIGNAL_COMPARISON",
            "final_step_notify_observed=false" +
            " | completion_seconds=" +
            level.pintemod_ee_diag_confirmation_seconds +
            " | selected_record_trigger=ee_samantha_released",
            true
        );
    }

    ee_profiles_mark_native_detected(
        "ee_samantha_released",
        level.pintemod_ee_diag_confirmation_seconds
    );
}

function ee_diag_castle_monitor()
{
    level endon("game_ended");
    level endon("end_game");

    ee_diag_wait_for_ranks();

    if (!ee_diag_wait_for_flag("sent_rockets_to_the_moon", 60))
    {
        ee_diag_log(
            "PROFILE_NOT_ARMED",
            "map=zm_castle | missing_flag=sent_rockets_to_the_moon",
            true
        );
        return;
    }

    if (!ee_diag_wait_for_flag("ee_outro", 60))
    {
        ee_diag_log(
            "PROFILE_NOT_ARMED",
            "map=zm_castle | missing_flag=ee_outro",
            true
        );
        return;
    }

    ee_profiles_arm_log("zm_castle");

    if (!level flag::get("sent_rockets_to_the_moon"))
        level flag::wait_till("sent_rockets_to_the_moon");

    level.pintemod_ee_diag_primary_detected = true;
    level.pintemod_ee_diag_primary_seconds = ee_diag_elapsed_seconds();

    ee_diag_snapshot("CASTLE_PRIMARY_DETECTED");

    if (!level flag::get("ee_outro"))
        level flag::wait_till("ee_outro");

    level.pintemod_ee_diag_confirmation_detected = true;
    level.pintemod_ee_diag_confirmation_seconds =
        ee_diag_elapsed_seconds();

    delta_seconds =
        level.pintemod_ee_diag_confirmation_seconds -
        level.pintemod_ee_diag_primary_seconds;

    ee_diag_snapshot("CASTLE_CONFIRMATION_DETECTED");

    ee_diag_log(
        "CASTLE_SIGNAL_COMPARISON",
        "primary_seconds=" +
        level.pintemod_ee_diag_primary_seconds +
        " | confirmation_seconds=" +
        level.pintemod_ee_diag_confirmation_seconds +
        " | delta_seconds=" + delta_seconds +
        " | selected_record_trigger=sent_rockets_to_the_moon",
        true
    );

    ee_profiles_mark_native_detected(
        "sent_rockets_to_the_moon",
        level.pintemod_ee_diag_primary_seconds
    );
}

function ee_cutover_count_map_files(root_path, candidate_mode)
{
    count = 0;
    maps = ee_profiles_maps();

    for (i = 0; i < maps.size; i++)
    {
        if (candidate_mode)
            path = root_path + "/candidates/maps/" + maps[i] + ".json";
        else
            path = root_path + "/maps/" + maps[i] + ".json";

        if (fileexists(path))
            count++;
    }

    return count;
}

function cmd_ezzeemigrationstatus(args)
{
    println("^6========== PINTEMOD EE XUID CUTOVER ==========");
    println("^7Active identity: " + ee_identity_kind());
    println("^7Profile schema: " + ee_records_profile_schema());
    println("^7Record schema: " + ee_records_map_schema());
    println("^7Candidate schema: " + ee_candidates_schema());
    println(
        "^7Active root: boiii/scriptdata/" + ee_records_data_root()
    );
    println(
        "^7Active official map files: " +
        ee_cutover_count_map_files(ee_records_data_root(), false)
    );
    println(
        "^7Active native candidate files: " +
        ee_cutover_count_map_files(ee_records_data_root(), true)
    );
    println(
        "^7Legacy root ignored: boiii/scriptdata/" +
        ee_records_legacy_root()
    );
    println(
        "^7Legacy official map files detected: " +
        ee_cutover_count_map_files(ee_records_legacy_root(), false)
    );
    println(
        "^7Legacy candidate files detected: " +
        ee_cutover_count_map_files(ee_records_legacy_root(), true)
    );
    println("^7Automatic pseudo-to-XUID merge: disabled (security)");
    println("^7Initial v2 records/candidates: neutral empty base");
    println("^6================================================");
}

function cmd_ezzeestatus(args)
{
    map_name = ee_diag_map_name();
    profile_status = ee_profiles_get_status(map_name);

    println("^6========== PINTEMOD EE v2 DIAGNOSTIC ==========");
    println("^7Version: " + level.pintemod_ee_records_version);
    println("^7Identity: " + ee_identity_kind());
    println("^7Detector core: v0.4.4 frozen");
    println("^7Mode: secure per-map official activation + TEST storage");
    println(
        "^7Official write for current map: " +
        ee_diag_bool_text(
            ee_profiles_official_enabled(map_name)
        )
    );
    println(
        "^7Map: " + map_name +
        " | " + ee_records_map_display(map_name)
    );
    println(
        "^7Profile status: ^3" + profile_status +
        "^7 | main quest: " +
        ee_diag_bool_text(ee_profiles_has_main_quest(map_name))
    );
    println(
        "^7Minimum quest players: " +
        ee_profiles_minimum_players(map_name)
    );
    println(
        "^7Trigger type: " + ee_profiles_trigger_type(map_name)
    );
    println(
        "^7Primary trigger: " +
        ee_profiles_primary_trigger(map_name)
    );
    println(
        "^7Confirmation/pre-signal: " +
        ee_profiles_confirmation_trigger(map_name)
    );
    println(
        "^7Armed: " +
        ee_diag_bool_text(level.pintemod_ee_diag_armed)
    );
    println(
        "^7Primary/pre-signal detected: " +
        ee_diag_bool_text(level.pintemod_ee_diag_primary_detected)
    );
    println(
        "^7Completion detected this map: " +
        ee_diag_bool_text(
            level.pintemod_ee_diag_confirmation_detected
        )
    );
    println(
        "^7Native completion persisted: " +
        ee_diag_bool_text(ee_profiles_native_seen(map_name))
    );

    if (ee_profiles_native_seen(map_name))
    {
        println(
            "^7Last native trigger: " +
            ee_profiles_native_trigger(map_name)
        );
        println(
            "^7Last candidate time: " +
            ee_records_format_duration(
                ee_profiles_native_seconds(map_name)
            ) +
            " | round=" + ee_profiles_native_round(map_name)
        );
    }

    println("^7Elapsed seconds: " + ee_diag_elapsed_seconds());
    println("^7Round: " + ee_diag_round());
    println(
        "^7Match ranked: " +
        ee_diag_bool_text(ee_diag_match_ranked())
    );
    println(
        "^7Completion players: " +
        ee_diag_count_completion_participants() +
        " | active holders: " +
        ee_diag_count_eligible_participants() +
        " | required presence=" +
        ee_diag_required_presence() + "%"
    );
    println(
        "^7Completion XUIDs: " + ee_diag_collect_completion_xuids()
    );
    println(
        "^7Holder XUIDs: " + ee_diag_collect_eligible_xuids()
    );
    category_rule = "category follows active holder count";

    if (ee_profiles_uses_fixed_completion_category(map_name))
    {
        category_rule =
            "fixed 4P completion / minimum 2 active holders";
    }

    println("^7Record category rule: " + category_rule);
    println(
        "^7Profiles: boiii/scriptdata/" + ee_profiles_state_path()
    );
    println(
        "^7Official: boiii/scriptdata/" +
        ee_records_data_root() + "/maps/"
    );
    println(
        "^7Test: boiii/scriptdata/" +
        ee_records_test_root() + "/maps/"
    );
    println(
        "^7Candidates: boiii/scriptdata/" +
        ee_records_data_root() + "/candidates/maps/"
    );
    println(
        "^7Legacy root ignored: boiii/scriptdata/" +
        ee_records_legacy_root()
    );
    println(
        "^7Log: boiii/scriptdata/" +
        ezz_admin_storage::get_active_log_root() +
        "/easter_eggs.log"
    );
    println("^7Cutover: ezzeemigrationstatus");
    println("^6====================================================");
}


function ee_diag_simulate_primary()
{
    level.pintemod_ee_diag_primary_detected = true;
    level.pintemod_ee_diag_primary_seconds = ee_diag_elapsed_seconds();

    ee_diag_snapshot(ee_diag_event_prefix() + "_PRIMARY_SIMULATED");
}

function ee_diag_simulate_confirmation()
{
    if (!level.pintemod_ee_diag_primary_detected)
        ee_diag_simulate_primary();

    level.pintemod_ee_diag_confirmation_detected = true;
    level.pintemod_ee_diag_confirmation_seconds =
        ee_diag_elapsed_seconds();

    delta_seconds =
        level.pintemod_ee_diag_confirmation_seconds -
        level.pintemod_ee_diag_primary_seconds;

    ee_diag_snapshot(
        ee_diag_event_prefix() + "_CONFIRMATION_SIMULATED"
    );

    ee_diag_log(
        ee_diag_event_prefix() + "_SIGNAL_COMPARISON_SIMULATED",
        "primary_seconds=" +
        level.pintemod_ee_diag_primary_seconds +
        " | confirmation_seconds=" +
        level.pintemod_ee_diag_confirmation_seconds +
        " | delta_seconds=" + delta_seconds +
        " | native_flags_modified=false",
        true
    );
}

function ee_diag_reset_simulation()
{
    level.pintemod_ee_diag_primary_detected = false;
    level.pintemod_ee_diag_confirmation_detected = false;
    level.pintemod_ee_diag_primary_seconds = 0;
    level.pintemod_ee_diag_confirmation_seconds = 0;

    ee_diag_log(
        "SIMULATION_RESET",
        "native_flags_modified=false",
        true
    );
}

function ee_records_make_active_test_holders(holder_count)
{
    holders = "";

    for (i = 1; i <= holder_count; i++)
    {
        if (holders != "")
            holders = holders + " + ";

        holders = holders + "TEST_ACTIVE_" + i;
    }

    return holders;
}

function ee_test_active_holders(
    map_name,
    completion_team_size,
    active_holder_count,
    seconds
)
{
    if (!ee_profiles_is_known_map(map_name) ||
        !ee_profiles_has_main_quest(map_name))
    {
        println("^1[PinteMod EE]^7 Unsupported main quest profile.");
        return false;
    }

    if (completion_team_size < 1 || completion_team_size > 4)
    {
        println(
            "^1[PinteMod EE]^7 Completion team must be 1 to 4."
        );
        return false;
    }

    if (active_holder_count < 0 ||
        active_holder_count > completion_team_size)
    {
        println(
            "^1[PinteMod EE]^7 Active holders must be between 0 " +
            "and the completion team size."
        );
        return false;
    }

    if (seconds <= 0)
    {
        println("^1[PinteMod EE]^7 Seconds must be greater than 0.");
        return false;
    }

    minimum_players = ee_profiles_minimum_players(map_name);
    minimum_active_holders =
        ee_profiles_minimum_active_holders(map_name);

    if (active_holder_count < minimum_active_holders)
    {
        ee_diag_log(
            "ACTIVE_HOLDERS_TEST_BLOCKED",
            "map=" + map_name +
            " | completion_players=" + completion_team_size +
            " | active_holders=" + active_holder_count +
            " | minimum_active_holders=" +
            minimum_active_holders +
            " | reason=not_enough_active_holders" +
            " | official_data_modified=false",
            true
        );

        println(
            "^3[PinteMod EE]^7 TEST blocked: at least " +
            minimum_active_holders + " active holder(s) required."
        );
        return false;
    }

    if (ee_profiles_uses_fixed_completion_category(map_name))
    {
        if (completion_team_size < minimum_players)
        {
            ee_diag_log(
                "ACTIVE_HOLDERS_TEST_BLOCKED",
                "map=" + map_name +
                " | completion_players=" + completion_team_size +
                " | required_completion_players=" + minimum_players +
                " | active_holders=" + active_holder_count +
                " | reason=below_required_completion_players" +
                " | official_data_modified=false",
                true
            );

            println(
                "^3[PinteMod EE]^7 TEST blocked: this quest " +
                "requires a " + minimum_players + "P completion."
            );
            return false;
        }

        record_category = minimum_players;
    }
    else
    {
        record_category = active_holder_count;
    }

    holders = ee_records_make_active_test_holders(active_holder_count);
    source = "active_holders_" + active_holder_count +
        "of" + completion_team_size;

    holder_xuids = ee_records_make_test_holder_xuids(
        active_holder_count
    );

    written = ee_records_insert_test_record_for_map(
        map_name,
        record_category,
        seconds,
        holders,
        source,
        1,
        holder_xuids
    );

    if (!written)
        return false;

    ee_diag_log(
        "ACTIVE_HOLDERS_TEST_ACCEPTED",
        "map=" + map_name +
        " | completion_players=" + completion_team_size +
        " | record_category=" + record_category + "P" +
        " | active_holders=" + active_holder_count +
        " | excluded_players=" +
        (completion_team_size - active_holder_count) +
        " | holders=" + holders +
        " | holder_xuids=" + holder_xuids +
        " | seconds=" + seconds +
        " | native_status_modified=false" +
        " | official_data_modified=false",
        true
    );

    println(
        "^2[PinteMod EE]^7 Active Holders TEST stored: " +
        ee_records_map_display(map_name) + " | completion=" +
        completion_team_size + "P | category=" + record_category +
        "P | holders=" + active_holder_count + "/" +
        completion_team_size + "."
    );

    return true;
}

function ee_test_profile(
    map_name,
    team_size,
    seconds,
    source
)
{
    if (!ee_profiles_is_known_map(map_name))
        return false;

    if (!ee_profiles_has_main_quest(map_name))
    {
        println(
            "^3[PinteMod EE]^7 TEST skipped: " +
            ee_records_map_display(map_name) +
            " has no supported main quest."
        );
        return false;
    }

    if (team_size < 1 || team_size > 4)
        team_size = 1;

    if (seconds <= 0)
        seconds = 600;

    holders = ee_records_make_test_holders(team_size);

    return ee_records_insert_test_record_for_map(
        map_name,
        team_size,
        seconds,
        holders,
        source,
        1
    );
}

function ee_test_all_profiles()
{
    maps = ee_profiles_maps();
    tested_profiles = 0;
    skipped_profiles = 0;
    inserted_records = 0;

    for (i = 0; i < maps.size; i++)
    {
        map_name = maps[i];
        tested_profiles++;

        if (!ee_profiles_has_main_quest(map_name))
        {
            skipped_profiles++;
            continue;
        }

        ee_records_clear_test_map_for(map_name);

        for (team_size = 1; team_size <= 4; team_size++)
        {
            seconds = 600 + (i * 60) + (team_size * 15);

            if (ee_test_profile(
                map_name,
                team_size,
                seconds,
                "all_profiles_test"
            ))
            {
                inserted_records++;
            }
        }
    }

    ee_diag_log(
        "ALL_PROFILES_TEST_COMPLETE",
        "profiles=" + tested_profiles +
        " | main_quest_profiles=" +
        (tested_profiles - skipped_profiles) +
        " | no_main_quest_profiles=" + skipped_profiles +
        " | test_records_inserted=" + inserted_records +
        " | native_status_modified=false" +
        " | official_data_modified=false",
        true
    );

    println(
        "^2[PinteMod EE]^7 All 14 profiles tested. " +
        inserted_records + " TEST records inserted. " +
        "Native validation and official data unchanged."
    );
}

function ee_test_clear_all_profiles()
{
    maps = ee_profiles_maps();
    cleared = 0;

    for (i = 0; i < maps.size; i++)
    {
        if (ee_records_clear_test_map_for(maps[i]))
            cleared++;
    }

    println(
        "^2[PinteMod EE]^7 Cleared TEST storage for " +
        cleared + " map profiles. Official data unchanged."
    );
}


// ============================================================
// Grouped runtime validation suite
// ============================================================

function ee_test_suite_file_snapshot(path)
{
    if (!fileexists(path))
        return "__PINTEMOD_FILE_MISSING__";

    contents = readfile(path);

    if (!isdefined(contents))
        return "__PINTEMOD_FILE_UNDEFINED__";

    return contents;
}

function ee_test_suite_assert(condition, test_name, details)
{
    level.pintemod_ee_suite_total++;

    if (isdefined(condition) && condition)
    {
        level.pintemod_ee_suite_passed++;
        println(
            "^2[PinteMod EE][SUITE PASS]^7 " + test_name
        );
        return true;
    }

    level.pintemod_ee_suite_failed++;

    if (!isdefined(details) || details == "")
        details = "no_details";

    println(
        "^1[PinteMod EE][SUITE FAIL]^7 " + test_name +
        " | " + details
    );

    return false;
}

function ee_test_suite_record_matches(
    map_name,
    team_size,
    seconds,
    holders,
    holder_xuids,
    source
)
{
    json = ee_records_load_map_json(map_name, true);

    if (ee_records_json_int(
        json,
        ee_records_key("seconds", team_size, 1),
        0
    ) != seconds)
    {
        return false;
    }

    if (ee_records_json_string(
        json,
        ee_records_key("holders", team_size, 1),
        ""
    ) != holders)
    {
        return false;
    }

    if (ee_records_json_string(
        json,
        ee_records_key("holder_xuids", team_size, 1),
        ""
    ) != holder_xuids)
    {
        return false;
    }

    if (ee_records_json_string(
        json,
        ee_records_key("source", team_size, 1),
        ""
    ) != source)
    {
        return false;
    }

    return true;
}


function ee_test_suite_record_category_empty(map_name, team_size)
{
    json = ee_records_load_map_json(map_name, true);

    return ee_records_json_int(
        json,
        ee_records_key("seconds", team_size, 1),
        0
    ) <= 0;
}

function ee_test_suite_candidate_matches(
    map_name,
    outcome,
    eligibility,
    would_be_recordable,
    record_category,
    active_holders,
    completion_players
)
{
    json = ee_candidates_load_json(map_name, true);

    if (ee_records_json_int(json, "candidate_count", 0) != 1 ||
        ee_records_json_int(json, "schema_version", 0) !=
            ee_candidates_schema() ||
        ee_records_json_string(json, "identity_kind", "") !=
            ee_identity_kind())
    {
        return false;
    }

    if (ee_records_json_string(
        json,
        ee_candidates_key("identity_kind", 1),
        ""
    ) != ee_identity_kind())
    {
        return false;
    }

    if (ee_records_json_string(
        json,
        ee_candidates_key("outcome", 1),
        ""
    ) != outcome)
    {
        return false;
    }

    if (ee_records_json_string(
        json,
        ee_candidates_key("eligibility_outcome", 1),
        ""
    ) != eligibility)
    {
        return false;
    }

    if (ee_records_json_string(
        json,
        ee_candidates_key("would_be_recordable", 1),
        ""
    ) != would_be_recordable)
    {
        return false;
    }

    if (ee_records_json_int(
        json,
        ee_candidates_key("record_category", 1),
        0
    ) != record_category)
    {
        return false;
    }

    if (ee_records_json_int(
        json,
        ee_candidates_key("active_holders", 1),
        -1
    ) != active_holders)
    {
        return false;
    }

    if (ee_records_json_int(
        json,
        ee_candidates_key("completion_players", 1),
        0
    ) != completion_players)
    {
        return false;
    }

    if (ee_records_json_string(
        json,
        ee_candidates_key("completion_xuids", 1),
        ""
    ) != ee_candidates_test_completion_xuids(completion_players))
    {
        return false;
    }

    if (ee_records_json_string(
        json,
        ee_candidates_key("holder_xuids", 1),
        ""
    ) != ee_candidates_test_holder_xuids(active_holders))
    {
        return false;
    }

    return true;
}


function ee_test_suite_profiles_are_complete()
{
    maps = ee_profiles_maps();
    main_quest_profiles = 0;
    no_main_quest_profiles = 0;

    if (maps.size != 14)
        return false;

    for (i = 0; i < maps.size; i++)
    {
        if (ee_profiles_has_main_quest(maps[i]))
            main_quest_profiles++;
        else
            no_main_quest_profiles++;
    }

    return main_quest_profiles == 9 &&
        no_main_quest_profiles == 5;
}

function ee_test_suite_clear_test_data()
{
    success = true;
    record_maps = [];
    record_maps[record_maps.size] = "zm_zod";
    record_maps[record_maps.size] = "zm_temple";
    record_maps[record_maps.size] = "zm_tomb";

    for (i = 0; i < record_maps.size; i++)
    {
        if (!ee_records_clear_test_map_for(record_maps[i]))
            success = false;
    }

    candidate_maps = [];
    candidate_maps[candidate_maps.size] = "zm_zod";
    candidate_maps[candidate_maps.size] = "zm_temple";
    candidate_maps[candidate_maps.size] = "zm_tomb";

    for (i = 0; i < candidate_maps.size; i++)
    {
        if (!ee_candidates_clear_test_map(candidate_maps[i]))
            success = false;
    }

    return success;
}

function ee_test_suite_test_data_is_clean()
{
    record_maps = [];
    record_maps[record_maps.size] = "zm_zod";
    record_maps[record_maps.size] = "zm_temple";
    record_maps[record_maps.size] = "zm_tomb";

    for (i = 0; i < record_maps.size; i++)
    {
        for (team_size = 1; team_size <= 4; team_size++)
        {
            if (!ee_test_suite_record_category_empty(
                record_maps[i],
                team_size
            ))
            {
                return false;
            }
        }
    }

    candidate_maps = [];
    candidate_maps[candidate_maps.size] = "zm_zod";
    candidate_maps[candidate_maps.size] = "zm_temple";
    candidate_maps[candidate_maps.size] = "zm_tomb";

    for (i = 0; i < candidate_maps.size; i++)
    {
        if (ee_candidates_count(candidate_maps[i], true) != 0)
            return false;
    }

    return true;
}

function ee_test_grouped_suite()
{
    if (isdefined(level.pintemod_ee_suite_running) &&
        level.pintemod_ee_suite_running)
    {
        println("^3[PinteMod EE]^7 Grouped suite already running.");
        return false;
    }

    level.pintemod_ee_suite_running = true;
    level.pintemod_ee_suite_total = 0;
    level.pintemod_ee_suite_passed = 0;
    level.pintemod_ee_suite_failed = 0;
    level.pintemod_ee_suite_last_result = "RUNNING";

    println(
        "^6========== PINTEMOD EE GROUPED VALIDATION SUITE =========="
    );
    println(
        "^7TEST storage only. Native profiles and official records " +
        "must remain byte-for-byte unchanged."
    );

    profiles_file_before = ee_test_suite_file_snapshot(
        ee_profiles_state_path()
    );
    profiles_memory_before = level.pintemod_ee_profiles_json;
    current_write_before =
        level.pintemod_ee_official_writes_enabled;

    official_zod_before = ee_test_suite_file_snapshot(
        ee_records_path("zm_zod", false)
    );
    official_temple_before = ee_test_suite_file_snapshot(
        ee_records_path("zm_temple", false)
    );
    official_tomb_before = ee_test_suite_file_snapshot(
        ee_records_path("zm_tomb", false)
    );

    native_zod_before = ee_test_suite_file_snapshot(
        ee_candidates_path("zm_zod", false)
    );
    native_temple_before = ee_test_suite_file_snapshot(
        ee_candidates_path("zm_temple", false)
    );
    native_tomb_before = ee_test_suite_file_snapshot(
        ee_candidates_path("zm_tomb", false)
    );

    legacy_profiles_before = ee_test_suite_file_snapshot(
        ee_records_legacy_root() + "/profiles.json"
    );
    legacy_zod_before = ee_test_suite_file_snapshot(
        ee_records_legacy_root() + "/maps/zm_zod.json"
    );
    legacy_candidates_zod_before = ee_test_suite_file_snapshot(
        ee_records_legacy_root() + "/candidates/maps/zm_zod.json"
    );

    clean_started = ee_test_suite_clear_test_data();
    ee_test_suite_assert(
        clean_started && ee_test_suite_test_data_is_clean(),
        "TEST storage reset",
        "unable_to_start_from_clean_test_storage"
    );

    ee_test_suite_assert(
        ee_test_suite_profiles_are_complete(),
        "14 map profiles / 9 quests / 5 no-main-quest maps",
        "profile_catalog_mismatch"
    );

    ee_test_suite_assert(
        ee_records_data_root() == "pintemod/easter_eggs_v2" &&
        ee_records_legacy_root() == "pintemod/easter_eggs",
        "v2 and legacy storage roots are isolated",
        "storage_root_isolation_failed"
    );

    profile_schema_json = ee_profiles_default_json();
    ee_test_suite_assert(
        ee_records_json_int(profile_schema_json, "schema_version", 0) ==
            ee_records_profile_schema() &&
        ee_records_json_string(profile_schema_json, "identity_kind", "") ==
            ee_identity_kind(),
        "Profile state uses v2 XUID schema",
        "profile_schema_or_identity_mismatch"
    );

    record_schema_json = ee_records_create_default_json("zm_tomb", true);
    record_holder_xuids_field = jsonparse(
        record_schema_json,
        ee_records_key("holder_xuids", 1, 1)
    );
    ee_test_suite_assert(
        ee_records_json_int(record_schema_json, "schema_version", 0) ==
            ee_records_map_schema() &&
        ee_records_json_string(record_schema_json, "identity_kind", "") ==
            ee_identity_kind() &&
        isdefined(record_holder_xuids_field),
        "Record Top 5 uses XUID holder schema",
        "record_schema_or_holder_xuids_missing"
    );

    candidate_schema_json = ee_candidates_default_json("zm_tomb", true);
    ee_test_suite_assert(
        ee_records_json_int(candidate_schema_json, "schema_version", 0) ==
            ee_candidates_schema() &&
        ee_records_json_string(candidate_schema_json, "identity_kind", "") ==
            ee_identity_kind(),
        "Candidate ledger uses XUID schema",
        "candidate_schema_or_identity_mismatch"
    );

    ee_test_suite_assert(
        ee_records_path("zm_tomb", false) ==
            "pintemod/easter_eggs_v2/maps/zm_tomb.json" &&
        ee_candidates_path("zm_tomb", false) ==
            "pintemod/easter_eggs_v2/candidates/maps/zm_tomb.json",
        "Runtime paths never point to legacy storage",
        "runtime_path_points_to_legacy"
    );

    holders_accepted = ee_test_active_holders(
        "zm_zod",
        4,
        2,
        3130
    );
    ee_test_suite_assert(
        holders_accepted && ee_test_suite_record_matches(
            "zm_zod",
            4,
            3130,
            "TEST_ACTIVE_1 + TEST_ACTIVE_2",
            ee_records_make_test_holder_xuids(2),
            "active_holders_2of4"
        ),
        "Fixed 4P quest credits 2 active holders",
        "shadows_4p_2of4_record_mismatch"
    );

    holders_blocked = ee_test_active_holders(
        "zm_temple",
        4,
        1,
        2000
    );
    ee_test_suite_assert(
        !holders_blocked &&
        ee_test_suite_record_category_empty("zm_temple", 4),
        "Fixed 4P quest blocks only 1 active holder",
        "shangri_la_minimum_active_holders_failed"
    );

    completion_blocked = ee_test_active_holders(
        "zm_zod",
        3,
        3,
        1800
    );
    ee_test_suite_assert(
        !completion_blocked && ee_test_suite_record_matches(
            "zm_zod",
            4,
            3130,
            "TEST_ACTIVE_1 + TEST_ACTIVE_2",
            ee_records_make_test_holder_xuids(2),
            "active_holders_2of4"
        ),
        "Fixed 4P quest blocks incomplete 3P completion",
        "shadows_required_completion_players_failed"
    );

    flexible_accepted = ee_test_active_holders(
        "zm_tomb",
        4,
        2,
        2700
    );
    ee_test_suite_assert(
        flexible_accepted && ee_test_suite_record_matches(
            "zm_tomb",
            2,
            2700,
            "TEST_ACTIVE_1 + TEST_ACTIVE_2",
            ee_records_make_test_holder_xuids(2),
            "active_holders_2of4"
        ) && ee_test_suite_record_category_empty("zm_tomb", 4),
        "Flexible quest uses active-holder category",
        "origins_4_completion_2p_category_failed"
    );

    ee_candidates_clear_test_map("zm_tomb");
    candidate_stored = ee_candidates_store_test(
        "zm_tomb",
        4,
        2,
        2700,
        true
    );
    ee_test_suite_assert(
        candidate_stored && ee_test_suite_candidate_matches(
            "zm_tomb",
            "profile_not_official",
            "eligible",
            "true",
            2,
            2,
            4
        ),
        "Eligible native candidate simulation is ledgered",
        "eligible_candidate_payload_mismatch"
    );

    duplicate_stored = ee_candidates_store_test(
        "zm_tomb",
        4,
        2,
        2700,
        true
    );
    ee_test_suite_assert(
        !duplicate_stored &&
        ee_candidates_count("zm_tomb", true) == 1,
        "Candidate signature anti-duplicate protection",
        "duplicate_candidate_was_stored"
    );

    ee_candidates_clear_test_map("zm_zod");
    blocked_candidate_stored = ee_candidates_store_test(
        "zm_zod",
        4,
        1,
        3130,
        true
    );
    ee_test_suite_assert(
        blocked_candidate_stored && ee_test_suite_candidate_matches(
            "zm_zod",
            "not_enough_active_holders",
            "not_enough_active_holders",
            "false",
            4,
            1,
            4
        ),
        "Rejected 4P candidate keeps diagnostic evidence",
        "blocked_candidate_payload_mismatch"
    );

    ee_candidates_clear_test_map("zm_tomb");
    unranked_candidate_stored = ee_candidates_store_test(
        "zm_tomb",
        2,
        2,
        1800,
        false
    );
    ee_test_suite_assert(
        unranked_candidate_stored && ee_test_suite_candidate_matches(
            "zm_tomb",
            "match_unranked",
            "match_unranked",
            "false",
            2,
            2,
            2
        ),
        "UNRANKED completion is ledgered but not recordable",
        "unranked_candidate_payload_mismatch"
    );

    profiles_unchanged =
        profiles_file_before == ee_test_suite_file_snapshot(
            ee_profiles_state_path()
        ) &&
        profiles_memory_before == level.pintemod_ee_profiles_json &&
        current_write_before ==
            level.pintemod_ee_official_writes_enabled;

    ee_test_suite_assert(
        profiles_unchanged,
        "Native profile status remains unchanged",
        "profiles_or_current_write_state_modified"
    );

    official_unchanged =
        official_zod_before == ee_test_suite_file_snapshot(
            ee_records_path("zm_zod", false)
        ) &&
        official_temple_before == ee_test_suite_file_snapshot(
            ee_records_path("zm_temple", false)
        ) &&
        official_tomb_before == ee_test_suite_file_snapshot(
            ee_records_path("zm_tomb", false)
        );

    ee_test_suite_assert(
        official_unchanged,
        "Official Top 5 storage remains byte-for-byte unchanged",
        "official_record_file_modified"
    );

    native_candidates_unchanged =
        native_zod_before == ee_test_suite_file_snapshot(
            ee_candidates_path("zm_zod", false)
        ) &&
        native_temple_before == ee_test_suite_file_snapshot(
            ee_candidates_path("zm_temple", false)
        ) &&
        native_tomb_before == ee_test_suite_file_snapshot(
            ee_candidates_path("zm_tomb", false)
        );

    ee_test_suite_assert(
        native_candidates_unchanged,
        "Native candidate ledgers remain byte-for-byte unchanged",
        "native_candidate_file_modified"
    );

    legacy_unchanged =
        legacy_profiles_before == ee_test_suite_file_snapshot(
            ee_records_legacy_root() + "/profiles.json"
        ) &&
        legacy_zod_before == ee_test_suite_file_snapshot(
            ee_records_legacy_root() + "/maps/zm_zod.json"
        ) &&
        legacy_candidates_zod_before == ee_test_suite_file_snapshot(
            ee_records_legacy_root() + "/candidates/maps/zm_zod.json"
        );

    ee_test_suite_assert(
        legacy_unchanged,
        "Legacy pseudo storage remains byte-for-byte untouched",
        "legacy_storage_modified"
    );

    cleanup_succeeded = ee_test_suite_clear_test_data();
    ee_test_suite_assert(
        cleanup_succeeded && ee_test_suite_test_data_is_clean(),
        "TEST artifacts cleaned after grouped validation",
        "test_cleanup_failed"
    );

    if (level.pintemod_ee_suite_failed <= 0)
    {
        level.pintemod_ee_suite_last_result = "PASS";

        ee_diag_log(
            "GROUPED_TEST_SUITE_PASS",
            "passed=" + level.pintemod_ee_suite_passed +
            " | failed=0" +
            " | total=" + level.pintemod_ee_suite_total +
            " | test_storage_clean=true" +
            " | profiles_modified=false" +
            " | native_candidates_modified=false" +
            " | official_data_modified=false" +
            " | identity=BOIII_XUID" +
            " | active_root=pintemod/easter_eggs_v2" +
            " | legacy_modified=false",
            true
        );

        println(
            "^2[PinteMod EE]^7 GROUPED SUITE PASSED: " +
            level.pintemod_ee_suite_passed + "/" +
            level.pintemod_ee_suite_total +
            " checks. TEST storage cleaned."
        );
    }
    else
    {
        level.pintemod_ee_suite_last_result = "FAIL";

        ee_diag_log(
            "GROUPED_TEST_SUITE_FAIL",
            "passed=" + level.pintemod_ee_suite_passed +
            " | failed=" + level.pintemod_ee_suite_failed +
            " | total=" + level.pintemod_ee_suite_total +
            " | official_data_modified=" +
            ee_diag_bool_text(!official_unchanged),
            true
        );

        println(
            "^1[PinteMod EE]^7 GROUPED SUITE FAILED: passed=" +
            level.pintemod_ee_suite_passed +
            " | failed=" + level.pintemod_ee_suite_failed +
            ". Keep the complete console output."
        );
    }

    println(
        "^6==========================================================="
    );

    level.pintemod_ee_suite_running = false;
    return level.pintemod_ee_suite_failed <= 0;
}

function cmd_ezzeetest(args)
{
    if (args.size <= 0)
    {
        println("^3[PinteMod EE]^7 Usage:");
        println("^7ezzeetest suite  (full grouped validation)");
        println("^7ezzeetest complete");
        println("^7ezzeetest seed [map] <1-4> <seconds>");
        println("^7ezzeetest top [map] [1-4]");
        println("^7ezzeetest clear [map]");
        println("^7ezzeetest profile <map> [1-4] [seconds]");
        println(
            "^7ezzeetest holders <map> <completion 1-4> " +
            "<active 0-4> <seconds>"
        );
        println(
            "^7ezzeetest candidate <map> <completion 1-4> " +
            "<active 0-4> <seconds> <ranked 0|1>"
        );
        println("^7ezzeetest candidateclear|candclear <map|all>");
        println("^7ezzeetest all / clearall");
        println("^7ezzeetest primary / confirmation / reset");
        println("^7TEST data never validates native detectors.");
        return;
    }

    action = toLower(args[0]);

    if (action == "suite" || action == "full" ||
        action == "selftest")
    {
        ee_test_grouped_suite();
        return;
    }

    if (action == "primary")
    {
        ee_diag_simulate_primary();
        println(
            "^2[PinteMod EE]^7 Primary signal simulated. " +
            "Native profile state unchanged."
        );
        return;
    }

    if (action == "confirmation")
    {
        ee_diag_simulate_confirmation();
        println(
            "^2[PinteMod EE]^7 Confirmation signal simulated. " +
            "Native profile state unchanged."
        );
        return;
    }

    if (action == "complete")
    {
        if (!ee_profiles_has_main_quest(ee_diag_map_name()))
        {
            println(
                "^3[PinteMod EE]^7 Current map has no supported " +
                "main quest profile."
            );
            return;
        }

        ee_diag_simulate_primary();
        ee_diag_simulate_confirmation();
        written = ee_records_insert_current_simulation();

        if (written)
        {
            println(
                "^2[PinteMod EE]^7 Complete chain simulated and " +
                "stored in TEST Top 5. Official records and " +
                "native validation unchanged."
            );
        }
        else
        {
            println(
                "^3[PinteMod EE]^7 Chain simulated but no TEST " +
                "record was stored. Check EE logs."
            );
        }
        return;
    }

    if (action == "candidate" || action == "cand")
    {
        if (args.size < 6)
        {
            println(
                "^3[PinteMod EE]^7 Usage: ezzeetest candidate " +
                "<map> <completion 1-4> <active 0-4> " +
                "<seconds> <ranked 0|1>"
            );
            return;
        }

        map_name = ee_profiles_resolve_map(args[1]);

        if (!isdefined(map_name))
        {
            println("^1[PinteMod EE]^7 Unknown map alias: " + args[1]);
            return;
        }

        completion_team_size = int(args[2]);
        active_holder_count = int(args[3]);
        seconds = int(args[4]);
        ranked = false;

        if (int(args[5]) > 0)
            ranked = true;

        if (completion_team_size < 1 || completion_team_size > 4 ||
            active_holder_count < 0 || active_holder_count > 4 ||
            seconds <= 0)
        {
            println("^1[PinteMod EE]^7 Invalid candidate TEST values.");
            return;
        }

        if (ee_candidates_store_test(
            map_name,
            completion_team_size,
            active_holder_count,
            seconds,
            ranked
        ))
        {
            println(
                "^2[PinteMod EE]^7 TEST candidate stored for " +
                ee_records_map_display(map_name) +
                ". Native profiles and official records unchanged."
            );
        }
        else
        {
            println(
                "^3[PinteMod EE]^7 TEST candidate not stored " +
                "(duplicate or write failure)."
            );
        }
        return;
    }

    if (action == "candidateclear" || action == "candclear")
    {
        if (args.size < 2)
        {
            println(
                "^3[PinteMod EE]^7 Usage: " +
                "ezzeetest candidateclear <map|all>"
            );
            return;
        }

        if (toLower(args[1]) == "all")
        {
            maps = ee_profiles_maps();
            cleared = 0;

            for (i = 0; i < maps.size; i++)
            {
                if (!ee_profiles_has_main_quest(maps[i]))
                    continue;

                if (ee_candidates_clear_test_map(maps[i]))
                    cleared++;
            }

            println(
                "^2[PinteMod EE]^7 Cleared TEST candidate ledgers: " +
                cleared + ". Native ledgers unchanged."
            );
            return;
        }

        map_name = ee_profiles_resolve_map(args[1]);

        if (!isdefined(map_name))
        {
            println("^1[PinteMod EE]^7 Unknown map alias: " + args[1]);
            return;
        }

        if (ee_candidates_clear_test_map(map_name))
        {
            println(
                "^2[PinteMod EE]^7 TEST candidate ledger cleared for " +
                ee_records_map_display(map_name) + "."
            );
        }
        return;
    }

    if (action == "holders")
    {
        if (args.size < 5)
        {
            println(
                "^3[PinteMod EE]^7 Usage: ezzeetest holders " +
                "<map> <completion 1-4> <active 0-4> <seconds>"
            );
            return;
        }

        map_name = ee_profiles_resolve_map(args[1]);

        if (!isdefined(map_name))
        {
            println("^1[PinteMod EE]^7 Unknown map alias: " + args[1]);
            return;
        }

        completion_team_size = int(args[2]);
        active_holder_count = int(args[3]);
        seconds = int(args[4]);

        ee_test_active_holders(
            map_name,
            completion_team_size,
            active_holder_count,
            seconds
        );
        return;
    }

    if (action == "profile")
    {
        if (args.size < 2)
        {
            println(
                "^3[PinteMod EE]^7 Usage: " +
                "ezzeetest profile <map> [1-4] [seconds]"
            );
            return;
        }

        map_name = ee_profiles_resolve_map(args[1]);

        if (!isdefined(map_name))
        {
            println("^1[PinteMod EE]^7 Unknown map alias: " + args[1]);
            return;
        }

        team_size = ee_profiles_minimum_players(map_name);

        if (team_size <= 0)
            team_size = 1;

        seconds = 600;

        if (args.size >= 3)
            team_size = int(args[2]);

        if (args.size >= 4)
            seconds = int(args[3]);

        if (ee_test_profile(
            map_name,
            team_size,
            seconds,
            "profile_simulation"
        ))
        {
            println(
                "^2[PinteMod EE]^7 Profile TEST inserted: " +
                ee_records_map_display(map_name) +
                " | " + team_size + "P | " +
                ee_records_format_duration(seconds) +
                ". Native and official state unchanged."
            );
        }
        return;
    }

    if (action == "all")
    {
        ee_test_all_profiles();
        return;
    }

    if (action == "clearall")
    {
        ee_test_clear_all_profiles();
        return;
    }

    if (action == "seed")
    {
        map_name = ee_diag_map_name();
        team_index = 1;
        seconds_index = 2;
        resolved_map = undefined;

        if (args.size >= 2)
            resolved_map = ee_profiles_resolve_map(args[1]);

        if (isdefined(resolved_map))
        {
            map_name = resolved_map;
            team_index = 2;
            seconds_index = 3;
        }

        if (args.size <= seconds_index)
        {
            println(
                "^3[PinteMod EE]^7 Usage: " +
                "ezzeetest seed [map] <1-4> <seconds>"
            );
            return;
        }

        team_size = int(args[team_index]);
        seconds = int(args[seconds_index]);

        if (ee_records_insert_test_record_for_map(
            map_name,
            team_size,
            seconds,
            ee_records_make_test_holders(team_size),
            "manual_seed",
            1
        ))
        {
            println(
                "^2[PinteMod EE]^7 TEST record inserted for " +
                ee_records_map_display(map_name) +
                ". Official records unchanged."
            );
        }
        return;
    }

    if (action == "top")
    {
        map_name = ee_diag_map_name();
        requested_team_size = 0;

        if (args.size >= 2)
        {
            resolved_map = ee_profiles_resolve_map(args[1]);

            if (isdefined(resolved_map))
            {
                map_name = resolved_map;

                if (args.size >= 3)
                    requested_team_size = int(args[2]);
            }
            else
            {
                requested_team_size = int(args[1]);
            }
        }

        if (requested_team_size < 0 || requested_team_size > 4)
        {
            println(
                "^3[PinteMod EE]^7 Usage: " +
                "ezzeetest top [map] [1-4]"
            );
            return;
        }

        ee_records_print_console_for(
            map_name,
            true,
            requested_team_size
        );
        return;
    }

    if (action == "clear")
    {
        map_name = ee_diag_map_name();

        if (args.size >= 2)
        {
            resolved_map = ee_profiles_resolve_map(args[1]);

            if (!isdefined(resolved_map))
            {
                println(
                    "^1[PinteMod EE]^7 Unknown map alias: " +
                    args[1]
                );
                return;
            }

            map_name = resolved_map;
        }

        if (ee_records_clear_test_map_for(map_name))
        {
            println(
                "^2[PinteMod EE]^7 TEST Top 5 cleared for " +
                ee_records_map_display(map_name) + "."
            );
        }
        return;
    }

    if (action == "reset")
    {
        ee_diag_reset_simulation();
        println(
            "^2[PinteMod EE]^7 Simulation signal state reset. " +
            "Native profile state unchanged."
        );
        return;
    }

    println("^1[PinteMod EE]^7 Unknown test action: " + action);
}

autoexec function init()
{
    addcommand("ezzeestatus", ::cmd_ezzeestatus);
    addcommand("ezzeemigrationstatus", ::cmd_ezzeemigrationstatus);
    addcommand("ezzeemaps", ::cmd_ezzeemaps);
    addcommand("ezzeecandidates", ::cmd_ezzeecandidates);
    addcommand("ezzeecands", ::cmd_ezzeecandidates);
    addcommand("ezzeeplayers", ::cmd_ezzeeplayers);
    addcommand("ezzeevalidate", ::cmd_ezzeevalidate);
    addcommand("ezzeeval", ::cmd_ezzeeval);
    addcommand("ezzeeofficial", ::cmd_ezzeeofficial);
    addcommand("ezzeeaudit", ::cmd_ezzeeaudit);
    addcommand("ezzeebackup", ::cmd_ezzeebackup);
    addcommand("ezzeereset", ::cmd_ezzeereset);
    addcommand("ezzeetest", ::cmd_ezzeetest);
    addcommand("ezzeerecord", ::cmd_ezzeerecord);
    addcommand("ezzeerecords", ::cmd_ezzeerecords);
    addcommand("ezzeetestrecords", ::cmd_ezzeetestrecords);

    mkdir("pintemod");
    mkdir("pintemod/logs");
    mkdir("pintemod/easter_eggs_v2");
    mkdir("pintemod/easter_eggs_v2/maps");
    mkdir("pintemod/easter_eggs_v2/backups");
    mkdir("pintemod/easter_eggs_v2/candidates");
    mkdir("pintemod/easter_eggs_v2/candidates/maps");
    mkdir("pintemod/easter_eggs_v2/test");
    mkdir("pintemod/easter_eggs_v2/test/candidates");
    mkdir("pintemod/easter_eggs_v2/test/candidates/maps");
    mkdir("pintemod/easter_eggs_v2/test/maps");

    level.pintemod_ee_records_loaded = true;
    level.pintemod_ee_records_version =
        "2.0.1";
    level.pintemod_ee_identity_kind = "BOIII_XUID";
    level.pintemod_ee_profile_schema = 3;
    level.pintemod_ee_record_schema = 2;
    level.pintemod_ee_candidate_schema = 2;
    level.pintemod_ee_max_records_per_category = 5;
    level.pintemod_ee_profiles_json = ee_profiles_load_state();
    ee_profiles_refresh_current_write_state();
    level.pintemod_ee_detection_status =
        ee_profiles_get_status(ee_diag_map_name());
    level.pintemod_ee_diag_armed = false;
    level.pintemod_ee_diag_primary_detected = false;
    level.pintemod_ee_diag_confirmation_detected = false;
    level.pintemod_ee_diag_primary_seconds = 0;
    level.pintemod_ee_diag_confirmation_seconds = 0;
    level.pintemod_ee_native_handled = false;
    level.pintemod_ee_last_candidate_id = 0;
    level.pintemod_ee_last_official_result = "not_attempted";
    level.pintemod_ee_last_official_modified = false;
    level.pintemod_ee_last_official_position = 0;
    level.pintemod_ee_suite_running = false;
    level.pintemod_ee_suite_total = 0;
    level.pintemod_ee_suite_passed = 0;
    level.pintemod_ee_suite_failed = 0;
    level.pintemod_ee_suite_last_result = "NOT_RUN";

    ee_profiles_start_current_monitor();

    println(
        "^5[PinteMod]^7 EE Records v2.0.1 " +
        "loaded"
    );

    ee_diag_log_file(
        "MODULE_LOADED",
        "version=2.0.1" +
        " | detector_core=0.4.4-EE-SEGMENT-FREEZE" +
        " | identity=BOIII_XUID" +
        " | profile_schema=3" +
        " | record_schema=2" +
        " | candidate_schema=2" +
        " | active_root=pintemod/easter_eggs_v2" +
        " | legacy_root_ignored=pintemod/easter_eggs" +
        " | legacy_merge=false" +
        " | neutral_base=true" +
        " | profiles=14" +
        " | main_quest_profiles=9" +
        " | passive_detectors=true" +
        " | official_mode=per_map_validated_only" +
        " | current_map_write=" +
        ee_diag_bool_text(level.pintemod_ee_official_writes_enabled) +
        " | ranked_required=true" +
        " | active_holders=true" +
        " | native_candidate_ledger=true" +
        " | candidate_retention_per_map=20" +
        " | candidate_signature_dedup=true" +
        " | fixed_4p_minimum_holders=2" +
        " | presence_required=" + ee_diag_required_presence() + "%" +
        " | test_storage=true" +
        " | grouped_validation_suite=true" +
        " | detector_segment_frozen=true" +
        " | max_records_per_category=5"
    );
}

