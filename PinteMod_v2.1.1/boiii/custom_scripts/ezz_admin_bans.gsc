// ============================================================
// PinteMod — Persistent XUID Bans v2.1.1
// Fichier : ezz_admin_bans.gsc
//
// Permanent and UTC-based temporary bans. Authorization is
// enforced in GSC; expiration and durable marker maintenance are
// handled by the local PinteMod Ban Service. No IP is persisted.
// ============================================================

#namespace ezz_admin_bans;

#using custom_scripts\ezz_admin_identity;
#using custom_scripts\ezz_admin_storage;
#using custom_scripts\ezz_admin_moderation;

function bans_log(event_name, details)
{
    text = "[" + GetTime() + "] " + event_name;

    if (isdefined(details) && details != "")
        text = text + " | " + details;

    ezz_admin_storage::append_managed_log(
        "pintemod/logs/moderation.log",
        text + "\n"
    );

    if (isdefined(level.pintemod_server_console_verbose) &&
        level.pintemod_server_console_verbose)
    {
        println("^5[PinteMod Ban]^7 " + event_name + " | " + details);
    }
}

function bans_json_string(json, key_name, default_value)
{
    if (!isdefined(json) || json == "" || jsonvalid(json))
        return default_value;

    value = jsonparse(json, key_name);

    if (!isdefined(value) || value == "")
        return default_value;

    return "" + value;
}

function bans_request_root()
{
    return "pintemod/bans/requests";
}

function bans_response_root()
{
    return "pintemod/bans/responses";
}

function bans_active_root()
{
    return "pintemod/bans/active";
}

function bans_request_path(request_id)
{
    return bans_request_root() + "/" + request_id + ".json";
}

function bans_response_path(request_id)
{
    return bans_response_root() + "/" + request_id + ".json";
}

function bans_active_path(xuid)
{
    return bans_active_root() + "/" + toLower(xuid) + ".json";
}

function bans_remove_json_artifacts(path)
{
    removefile(path);
    removefile(path + ".tmp");
    removefile(path + ".bak");
}

function bans_join_args(args, first_index)
{
    result = "";

    for (i = first_index; i < args.size; i++)
    {
        if (result != "")
            result = result + " ";

        result = result + args[i];
    }

    return result;
}

function bans_duration_is_valid(duration)
{
    if (!isdefined(duration) || duration == "")
        return false;

    text = toLower("" + duration);

    if (text == "perm" || text == "permanent" || text == "forever")
        return true;

    if (text.size < 2 || text.size > 7)
        return false;

    suffix = GetSubStr(text, text.size - 1, text.size);

    if (suffix != "m" && suffix != "h" && suffix != "d" && suffix != "w")
        return false;

    number_text = GetSubStr(text, 0, text.size - 1);

    for (i = 0; i < number_text.size; i++)
    {
        if (!ezz_admin_identity::identity_is_decimal_character(
            GetSubStr(number_text, i, i + 1)
        ))
        {
            return false;
        }
    }

    return int(number_text) > 0;
}

function bans_normalize_duration(duration)
{
    if (!isdefined(duration) || duration == "")
        return "perm";

    text = toLower("" + duration);

    if (text == "permanent" || text == "forever")
        return "perm";

    return text;
}

function bans_role_for_xuid(xuid, connected_player)
{
    if (isdefined(connected_player))
        return ezz_admin_identity::get_player_role(connected_player);

    persistent_role = ezz_admin_identity::identity_persistent_role_for_xuid(
        xuid,
        false
    );

    if (persistent_role >= 0)
        return persistent_role;

    if (isdefined(level.ezz_owner_xuids) &&
        ezz_admin_identity::identity_xuid_in_list(xuid, level.ezz_owner_xuids))
    {
        return 4;
    }

    if (isdefined(level.ezz_admin_xuids) &&
        ezz_admin_identity::identity_xuid_in_list(xuid, level.ezz_admin_xuids))
    {
        return 3;
    }

    if (isdefined(level.ezz_moderator_xuids) &&
        ezz_admin_identity::identity_xuid_in_list(xuid, level.ezz_moderator_xuids))
    {
        return 2;
    }

    if (isdefined(level.ezz_helper_xuids) &&
        ezz_admin_identity::identity_xuid_in_list(xuid, level.ezz_helper_xuids))
    {
        return 1;
    }

    return 0;
}

function bans_is_protected_owner_xuid(xuid)
{
    if (!ezz_admin_identity::is_valid_xuid(xuid))
        return false;

    return isdefined(level.ezz_owner_xuids) &&
        ezz_admin_identity::identity_xuid_in_list(xuid, level.ezz_owner_xuids);
}

function bans_find_player_by_xuid(xuid)
{
    players = GetPlayers();
    wanted = ezz_admin_identity::normalize_xuid(xuid);

    for (i = 0; i < players.size; i++)
    {
        player = players[i];

        if (!isdefined(player))
            continue;

        if (ezz_admin_identity::get_player_xuid(player) == wanted)
            return player;
    }

    return undefined;
}

function bans_actor_role(actor)
{
    if (!isdefined(actor))
        return 4;

    return ezz_admin_identity::get_player_role(actor);
}

function bans_actor_name(actor)
{
    if (!isdefined(actor))
        return "server-console";

    return actor.name;
}

function bans_actor_xuid(actor)
{
    if (!isdefined(actor))
        return "";

    return ezz_admin_identity::get_player_xuid(actor);
}

function bans_notify_actor(actor, message)
{
    if (isdefined(actor))
        actor iprintln(message);
    else
        println(message);
}

function bans_log_refusal(actor, action, target_xuid, reason)
{
    actor_xuid = bans_actor_xuid(actor);
    if (!ezz_admin_identity::is_valid_xuid(actor_xuid))
        actor_xuid = "server";

    safe_target = target_xuid;
    if (!isdefined(safe_target) || safe_target == "")
        safe_target = "unresolved";

    bans_log(
        "BAN_ACTION_REFUSED",
        "action=" + action +
        " | actor_xuid=" + ezz_admin_storage::log_xuid(actor_xuid) +
        " | target_xuid=" + ezz_admin_storage::log_xuid(safe_target) +
        " | reason=" + ezz_admin_storage::sanitize_log_text(reason)
    );
}

function bans_next_request_id(target_xuid)
{
    if (!isdefined(level.pintemod_ban_request_counter))
        level.pintemod_ban_request_counter = 0;

    level.pintemod_ban_request_counter++;

    return "req_" + GetTime() + "_" +
        level.pintemod_ban_request_counter + "_" + target_xuid;
}

function bans_write_request(actor, action, target, duration, reason)
{
    request_id = bans_next_request_id(target.xuid);
    request_path = bans_request_path(request_id);
    response_path = bans_response_path(request_id);

    bans_remove_json_artifacts(request_path);
    bans_remove_json_artifacts(response_path);

    actor_role = bans_actor_role(actor);
    actor_name = bans_actor_name(actor);
    actor_xuid = bans_actor_xuid(actor);
    target_role = bans_role_for_xuid(target.xuid, target.player);
    client_number = -1;

    if (isdefined(target.player))
        client_number = target.player GetEntityNumber();

    json = "{}";
    json = jsonset(json, "schema_version", "1");
    json = jsonset(json, "request_id", request_id);
    json = jsonset(json, "action", action);
    json = jsonset(json, "target_xuid", target.xuid);
    json = jsonset(json, "target_display", target.display);
    json = jsonset(json, "target_role", "" + target_role);
    json = jsonset(json, "target_client", "" + client_number);
    json = jsonset(json, "duration", duration);
    json = jsonset(json, "reason", reason);
    json = jsonset(json, "actor", actor_name);
    json = jsonset(json, "actor_xuid", actor_xuid);
    json = jsonset(json, "actor_role", "" + actor_role);
    json = jsonset(json, "requested_gettime", "" + GetTime());

    if (isdefined(level.pintemod_storage_session_id))
        json = jsonset(json, "session", level.pintemod_storage_session_id);

    if (!ezz_admin_storage::write_json_safe(
        request_path,
        json,
        "ban-service-request"
    ))
    {
        bans_notify_actor(actor, "^1[PinteMod Ban]^7 Request write failed");
        bans_log(
            "BAN_REQUEST_FAILED",
            "action=" + action + " | target_xuid=" +
            ezz_admin_storage::log_xuid(target.xuid) +
            " | reason=request-write"
        );
        return false;
    }

    bans_log(
        "BAN_REQUESTED",
        "action=" + action +
        " | target=" + target.display +
        " | target_xuid=" + ezz_admin_storage::log_xuid(target.xuid) +
        " | duration=" + duration +
        " | actor=" + actor_name
    );

    level thread bans_wait_for_response(
        request_id,
        action,
        target.xuid,
        target.display,
        actor_xuid,
        actor_name
    );

    return true;
}

function bans_wait_for_response(
    request_id,
    action,
    target_xuid,
    target_display,
    actor_xuid,
    actor_name
)
{
    request_path = bans_request_path(request_id);
    response_path = bans_response_path(request_id);

    for (check = 0; check < 120; check++)
    {
        if (fileexists(response_path))
        {
            response = ezz_admin_storage::load_json_or_default(
                response_path,
                "{}",
                "ban-service-response"
            );

            status = toLower(bans_json_string(response, "status", "error"));
            message = bans_json_string(response, "message", "Unknown response");
            response_xuid = ezz_admin_identity::normalize_xuid(
                bans_json_string(response, "target_xuid", "")
            );

            bans_remove_json_artifacts(response_path);
            bans_remove_json_artifacts(request_path);

            actor = undefined;

            if (ezz_admin_identity::is_valid_xuid(actor_xuid))
                actor = bans_find_player_by_xuid(actor_xuid);

            if (status != "ok" || response_xuid != target_xuid)
            {
                bans_notify_actor(
                    actor,
                    "^1[PinteMod Ban]^7 " + message
                );
                bans_log(
                    "BAN_REQUEST_REJECTED",
                    "action=" + action +
                    " | target=" + target_display +
                    " | target_xuid=" + ezz_admin_storage::log_xuid(target_xuid) +
                    " | actor=" + actor_name +
                    " | message=" + message
                );
                return;
            }

            bans_notify_actor(actor, "^2[PinteMod Ban]^7 " + message);

            if (action == "ban")
            {
                target_player = bans_find_player_by_xuid(target_xuid);

                if (isdefined(target_player))
                {
                    target_player iprintln(
                        "^1[PinteMod]^7 You are banned from this server."
                    );

                    level notify(
                        "pintemod_gameplay_command_used",
                        "ban",
                        target_display
                    );

                    wait 0.2;
                    executecommand(
                        level.pintemod_kick_command + " " +
                        (target_player GetEntityNumber())
                    );

                    bans_log(
                        "BAN_KICK_EXECUTED",
                        "player=" + target_display +
                        " | xuid=" + ezz_admin_storage::log_xuid(target_xuid)
                    );
                }
            }

            return;
        }

        wait 0.1;
    }

    bans_remove_json_artifacts(request_path);
    bans_log(
        "BAN_SERVICE_TIMEOUT",
        "action=" + action +
        " | target=" + target_display +
        " | target_xuid=" + ezz_admin_storage::log_xuid(target_xuid)
    );

    actor = undefined;

    if (ezz_admin_identity::is_valid_xuid(actor_xuid))
        actor = bans_find_player_by_xuid(actor_xuid);

    bans_notify_actor(
        actor,
        "^1[PinteMod Ban]^7 Ban Service timeout; verify the launcher/service."
    );
}

function request_ban(actor, target_query, duration, reason)
{
    if (!isdefined(level.pintemod_bans_enabled) ||
        !level.pintemod_bans_enabled)
    {
        bans_notify_actor(actor, "^3[PinteMod Ban]^7 Ban system disabled");
        bans_log_refusal(actor, "ban", "", "disabled");
        return false;
    }

    actor_role = bans_actor_role(actor);

    if (actor_role < 3)
    {
        bans_notify_actor(actor, "^1[PinteMod]^7 Admin role required");
        bans_log_refusal(actor, "ban", "", "admin_required");
        return false;
    }

    target = ezz_admin_identity::identity_resolve_target(target_query);

    if (!target.success)
    {
        bans_notify_actor(
            actor,
            "^1[PinteMod Ban]^7 Target/XUID not resolved: " + target_query
        );
        bans_log_refusal(actor, "ban", "", "target_not_resolved");
        return false;
    }

    if (bans_is_protected_owner_xuid(target.xuid))
    {
        bans_notify_actor(
            actor,
            "^1[PinteMod Ban]^7 Bootstrap Owner is protected"
        );
        bans_log_refusal(actor, "ban", target.xuid, "bootstrap_owner_protected");
        return false;
    }

    actor_xuid = bans_actor_xuid(actor);

    if (ezz_admin_identity::is_valid_xuid(actor_xuid) &&
        actor_xuid == target.xuid)
    {
        bans_notify_actor(actor, "^1[PinteMod Ban]^7 Self-ban refused");
        bans_log_refusal(actor, "ban", target.xuid, "self_action");
        return false;
    }

    target_role = bans_role_for_xuid(target.xuid, target.player);

    if (target_role >= actor_role)
    {
        bans_notify_actor(
            actor,
            "^1[PinteMod Ban]^7 You cannot ban an equal or higher role"
        );
        bans_log_refusal(actor, "ban", target.xuid, "target_equal_or_higher");
        return false;
    }

    duration = bans_normalize_duration(duration);

    if (!bans_duration_is_valid(duration))
    {
        bans_notify_actor(
            actor,
            "^3[PinteMod Ban]^7 Duration: 30m, 2h, 7d, 4w or perm"
        );
        bans_log_refusal(actor, "ban", target.xuid, "invalid_duration");
        return false;
    }

    if (!isdefined(reason) || reason == "")
        reason = "No reason provided";

    if (reason.size > 120 ||
        ezz_admin_identity::has_dangerous_command_characters(reason))
    {
        bans_notify_actor(actor, "^1[PinteMod Ban]^7 Unsafe/long reason rejected");
        bans_log_refusal(actor, "ban", target.xuid, "unsafe_reason");
        return false;
    }

    if (!bans_write_request(actor, "ban", target, duration, reason))
        return false;

    bans_notify_actor(
        actor,
        "^5[PinteMod Ban]^7 Ban queued: " + target.display +
        " ^7(" + duration + ")"
    );
    return true;
}

function request_unban(actor, target_query)
{
    actor_role = bans_actor_role(actor);

    if (actor_role < 3)
    {
        bans_notify_actor(actor, "^1[PinteMod]^7 Admin role required");
        bans_log_refusal(actor, "unban", "", "admin_required");
        return false;
    }

    target = ezz_admin_identity::identity_resolve_target(target_query);

    if (!target.success)
    {
        bans_notify_actor(
            actor,
            "^1[PinteMod Ban]^7 XUID not resolved: " + target_query
        );
        bans_log_refusal(actor, "unban", "", "target_not_resolved");
        return false;
    }

    if (bans_is_protected_owner_xuid(target.xuid))
    {
        bans_notify_actor(actor, "^1[PinteMod Ban]^7 Bootstrap Owner is protected");
        bans_log_refusal(actor, "unban", target.xuid, "bootstrap_owner_protected");
        return false;
    }

    target_role = bans_role_for_xuid(target.xuid, target.player);
    if (target_role >= actor_role)
    {
        bans_notify_actor(actor, "^1[PinteMod Ban]^7 You cannot act on an equal or higher role");
        bans_log_refusal(actor, "unban", target.xuid, "target_equal_or_higher");
        return false;
    }

    if (!bans_write_request(actor, "unban", target, "none", "manual-unban"))
        return false;

    bans_notify_actor(
        actor,
        "^5[PinteMod Ban]^7 Unban queued: " + target.display
    );
    return true;
}

function show_ban_info(actor, target_query)
{
    if (bans_actor_role(actor) < 3)
    {
        bans_notify_actor(actor, "^1[PinteMod]^7 Admin role required");
        return;
    }

    target = ezz_admin_identity::identity_resolve_target(target_query);

    if (!target.success)
    {
        bans_notify_actor(actor, "^1[PinteMod Ban]^7 XUID not resolved");
        return;
    }

    path = bans_active_path(target.xuid);

    if (!fileexists(path))
    {
        bans_notify_actor(
            actor,
            "^3[PinteMod Ban]^7 No active ban for " + target.xuid
        );
        return;
    }

    json = readfile(path);
    duration = bans_json_string(json, "duration", "unknown");
    expires = bans_json_string(json, "expires_utc", "never");
    reason = bans_json_string(json, "reason", "unknown");
    display = bans_json_string(json, "display", target.display);

    bans_notify_actor(
        actor,
        "^5[PinteMod Ban]^7 " + display +
        " | xuid=" + target.xuid +
        " | duration=" + duration
    );
    bans_notify_actor(actor, "^7Expires UTC: " + expires);
    bans_notify_actor(actor, "^7Reason: " + reason);
}

function show_ban_list(actor)
{
    if (bans_actor_role(actor) < 3)
    {
        bans_notify_actor(actor, "^1[PinteMod]^7 Admin role required");
        return;
    }

    path = "pintemod/bans/bans_summary.txt";

    if (!fileexists(path))
    {
        bans_notify_actor(
            actor,
            "^3[PinteMod Ban]^7 Ban summary unavailable; start Ban Service"
        );
        return;
    }

    summary = readfile(path);

    if (!isdefined(summary) || summary == "")
        summary = "No active bans";

    if (isdefined(actor))
        actor iprintln("^5[PinteMod Ban]^7 See server console for the ban list.");

    println("^5===== PINTEMOD ACTIVE BANS =====");
    println(summary);
    println("^5================================");
}

function bans_check_connected_player()
{
    self endon("disconnect");

    for (attempt = 0; attempt < 40; attempt++)
    {
        xuid = ezz_admin_identity::get_player_xuid(self);

        if (ezz_admin_identity::is_valid_xuid(xuid))
            break;

        wait 0.25;
    }

    xuid = ezz_admin_identity::get_player_xuid(self);

    if (!ezz_admin_identity::is_valid_xuid(xuid))
        return;

    marker_path = bans_active_path(xuid);

    if (!fileexists(marker_path))
        return;

    marker_json = readfile(marker_path);
    marker_xuid = ezz_admin_identity::normalize_xuid(
        bans_json_string(marker_json, "xuid", "")
    );

    if (marker_xuid != xuid)
    {
        bans_log(
            "BAN_MARKER_REJECTED",
            "reason=xuid-mismatch | player=" + self.name
        );
        return;
    }

    reason = bans_json_string(marker_json, "reason", "Banned");
    expires = bans_json_string(marker_json, "expires_utc", "never");
    client_number = self GetEntityNumber();

    bans_log(
        "BANNED_PLAYER_REJECTED",
        "player=" + self.name +
        " | xuid=" + ezz_admin_storage::log_xuid(xuid) +
        " | expires_utc=" + expires +
        " | reason=" + reason
    );

    self iprintln("^1[PinteMod]^7 You are banned from this server.");
    self iprintln("^7Reason: " + reason);
    wait 0.3;
    executecommand(level.pintemod_kick_command + " " + client_number);
}

function bans_bootstrap()
{
    wait 0.5;
    players = GetPlayers();

    for (i = 0; i < players.size; i++)
    {
        if (isdefined(players[i]))
            players[i] thread bans_check_connected_player();
    }

    for (;;)
    {
        level waittill("connected", player);

        if (isdefined(player))
            player thread bans_check_connected_player();
    }
}

function cmd_ezzban(args)
{
    if (args.size < 1)
    {
        println("^7ezzban <Player|BOIII_XUID|ClientNumber> [30m|2h|7d|4w|perm] [reason]");
        return;
    }

    duration = "perm";
    reason_start = 1;

    if (args.size >= 2 && bans_duration_is_valid(args[1]))
    {
        duration = args[1];
        reason_start = 2;
    }

    reason = bans_join_args(args, reason_start);
    request_ban(undefined, args[0], duration, reason);
}

function cmd_ezzunban(args)
{
    if (args.size < 1)
    {
        println("^7ezzunban <Player|BOIII_XUID|ClientNumber>");
        return;
    }

    request_unban(undefined, args[0]);
}

function cmd_ezzbaninfo(args)
{
    if (args.size < 1)
    {
        println("^7ezzbaninfo <Player|BOIII_XUID|ClientNumber>");
        return;
    }

    show_ban_info(undefined, args[0]);
}

function cmd_ezzbanlist(args)
{
    show_ban_list(undefined);
}

function cmd_ezzbanstatus(args)
{
    status_path = "pintemod/bans/service_status.json";

    println("^5===== PINTEMOD BAN STATUS =====");
    println("^7Enabled: " + level.pintemod_bans_enabled);
    println("^7Identity: BOIII_XUID");
    println("^7Persistent IP storage: disabled");

    if (fileexists(status_path))
        println("^7Service: " + readfile(status_path));
    else
        println("^3Service status file not found");

    println("^5================================");
}

function bans_test_assert(result, condition, name, failure)
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
        println("^1[FAIL]^7 " + name + " | " + failure);
    }
}

function bans_run_grouped_suite()
{
    result = SpawnStruct();
    result.total = 0;
    result.passed = 0;
    result.failed = 0;

    bans_test_assert(result, bans_duration_is_valid("30m"), "01 minute duration", "30m rejected");
    bans_test_assert(result, bans_duration_is_valid("2h"), "02 hour duration", "2h rejected");
    bans_test_assert(result, bans_duration_is_valid("7d"), "03 day duration", "7d rejected");
    bans_test_assert(result, bans_duration_is_valid("4w"), "04 week duration", "4w rejected");
    bans_test_assert(result, bans_duration_is_valid("perm"), "05 permanent duration", "perm rejected");
    bans_test_assert(result, !bans_duration_is_valid("0h"), "06 zero duration rejected", "0h accepted");
    bans_test_assert(result, !bans_duration_is_valid("abc"), "07 malformed duration rejected", "abc accepted");
    bans_test_assert(
        result,
        bans_is_protected_owner_xuid("9cf34426f668fb8b"),
        "08 bootstrap owner protected",
        "owner not protected"
    );

    println(
        "^5[PinteMod Ban]^7 RESULT " + result.passed + "/" +
        result.total + " PASS | failed=" + result.failed
    );

    return result;
}

function cmd_ezzbantest(args)
{
    bans_run_grouped_suite();
}

autoexec function init()
{
    if (isdefined(level.pintemod_bans_initialized) &&
        level.pintemod_bans_initialized)
    {
        return;
    }

    level.pintemod_bans_initialized = true;
    level.pintemod_bans_version = "2.1.1";
    level.pintemod_ban_request_counter = 0;

    if (!isdefined(level.pintemod_bans_enabled))
        level.pintemod_bans_enabled = true;

    if (!isdefined(level.pintemod_kick_command) ||
        level.pintemod_kick_command == "")
    {
        level.pintemod_kick_command = "clientkick";
    }

    mkdir("pintemod");
    mkdir("pintemod/bans");
    mkdir(bans_request_root());
    mkdir(bans_response_root());
    mkdir(bans_active_root());

    addcommand("ezzban", ::cmd_ezzban);
    addcommand("ezzunban", ::cmd_ezzunban);
    addcommand("ezzbaninfo", ::cmd_ezzbaninfo);
    addcommand("ezzbanlist", ::cmd_ezzbanlist);
    addcommand("ezzbanstatus", ::cmd_ezzbanstatus);
    addcommand("ezzbantest", ::cmd_ezzbantest);

    level thread bans_bootstrap();

    println("^5[PinteMod]^7 Bans v2.1.1 loaded");
}
