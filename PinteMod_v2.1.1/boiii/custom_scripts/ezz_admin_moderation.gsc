// ============================================================
// PinteMod — Complete XUID Moderation v2.1.1
// Hierarchy, persistent mute state, direct kick and unified history.
// No player IP is stored. Display names are metadata only.
// ============================================================

#namespace ezz_admin_moderation;

#using custom_scripts\ezz_admin_identity;
#using custom_scripts\ezz_admin_storage;
#using custom_scripts\ezz_admin_localization;

function moderation_root()
{
    return "pintemod/moderation";
}

function moderation_is_enabled()
{
    if (!isdefined(level.pintemod_moderation_enabled))
        return true;

    return level.pintemod_moderation_enabled;
}

function moderation_normalize_reason(reason)
{
    if (!isdefined(reason) || reason == "")
        return "No reason provided";

    return reason;
}

function moderation_reason_is_safe(reason)
{
    if (!isdefined(reason) || reason == "")
        return true;

    return reason.size <= 120 &&
        !ezz_admin_identity::has_dangerous_command_characters(reason);
}

function moderation_history_root()
{
    return moderation_root() + "/history";
}

function moderation_mute_root()
{
    return moderation_root() + "/mutes";
}

function moderation_safe_xuid(xuid)
{
    return ezz_admin_storage::storage_safe_component(
        ezz_admin_identity::normalize_xuid(xuid)
    );
}

function moderation_history_path(xuid, test_mode)
{
    if (isdefined(test_mode) && test_mode)
        return moderation_history_root() + "/test_" + moderation_safe_xuid(xuid) + ".json";

    return moderation_history_root() + "/" + moderation_safe_xuid(xuid) + ".json";
}

function moderation_mute_path(xuid)
{
    return moderation_mute_root() + "/" + moderation_safe_xuid(xuid) + ".json";
}

function moderation_default_history(xuid, display_name)
{
    json = "{}";
    json = jsonset(json, "schema_version", "1");
    json = jsonset(json, "identity_kind", "BOIII_XUID");
    json = jsonset(json, "xuid", ezz_admin_identity::normalize_xuid(xuid));
    json = jsonset(json, "last_display_name", ezz_admin_storage::sanitize_log_text(display_name));
    json = jsonset(json, "kicks", "0");
    json = jsonset(json, "mutes", "0");
    json = jsonset(json, "temporary_bans", "0");
    json = jsonset(json, "permanent_bans", "0");
    json = jsonset(json, "unbans", "0");
    json = jsonset(json, "last_action", "none");
    json = jsonset(json, "last_reason", "");
    json = jsonset(json, "last_actor_xuid", "server");
    json = jsonset(json, "last_gettime", "0");
    return json;
}

function moderation_json_int(json, key_name)
{
    if (!isdefined(json) || json == "" || jsonvalid(json))
        return 0;

    value = jsonparse(json, key_name);

    if (!isdefined(value) || value == "")
        return 0;

    return int(value);
}

function moderation_json_string(json, key_name, default_value)
{
    if (!isdefined(json) || json == "" || jsonvalid(json))
        return default_value;

    value = jsonparse(json, key_name);

    if (!isdefined(value) || value == "")
        return default_value;

    return value;
}

function moderation_log(event_name, actor, target_xuid, details)
{
    actor_xuid = "server";
    actor_name = "SERVER";

    if (isdefined(actor))
    {
        actor_xuid = ezz_admin_identity::identity_log_xuid_value(
            ezz_admin_identity::get_player_xuid(actor)
        );
        actor_name = ezz_admin_storage::sanitize_log_text(actor.name);
    }

    text = "[" + GetTime() + "] " + event_name +
        " | actor=" + actor_name +
        " | actor_xuid=" + actor_xuid +
        " | target_xuid=" + ezz_admin_identity::identity_log_xuid_value(target_xuid);

    if (isdefined(details) && details != "")
        text = text + " | " + ezz_admin_storage::sanitize_log_text(details);

    ezz_admin_storage::append_managed_log(
        "pintemod/logs/moderation.log",
        text + "\n"
    );

    println("^5[PinteMod Moderation]^7 " + event_name + " | " + details);
}

function moderation_actor_role(actor)
{
    if (!isdefined(actor))
        return 4;

    return ezz_admin_identity::get_player_role(actor);
}

function moderation_bootstrap_owner_xuid()
{
    return "9cf34426f668fb8b";
}

function moderation_is_bootstrap_owner(xuid)
{
    return ezz_admin_identity::normalize_xuid(xuid) == moderation_bootstrap_owner_xuid();
}

function moderation_target_role(target)
{
    if (isdefined(target.player))
        return ezz_admin_identity::get_player_role(target.player);

    return ezz_admin_identity::identity_persistent_role_for_xuid(target.xuid, false);
}

function moderation_role_allows_action(actor_role, target_role, self_action, bootstrap_target)
{
    if (actor_role < 3)
        return false;

    if (self_action || bootstrap_target)
        return false;

    return target_role < actor_role;
}

function moderation_check(actor, target, action_name)
{
    result = SpawnStruct();
    result.allowed = false;
    result.reason = "unknown";
    result.actor_role = moderation_actor_role(actor);
    result.target_role = moderation_target_role(target);

    if (result.actor_role < 3)
    {
        result.reason = "admin_required";
        return result;
    }

    actor_xuid = "";

    if (isdefined(actor))
        actor_xuid = ezz_admin_identity::get_player_xuid(actor);

    if (actor_xuid != "" && actor_xuid == target.xuid)
    {
        result.reason = "self_action";
        return result;
    }

    if (moderation_is_bootstrap_owner(target.xuid))
    {
        result.reason = "bootstrap_owner_protected";
        return result;
    }

    if (result.target_role >= result.actor_role)
    {
        result.reason = "target_equal_or_higher";
        return result;
    }

    result.allowed = true;
    result.reason = "allowed";
    return result;
}

function moderation_resolve_target(query)
{
    return ezz_admin_identity::identity_resolve_target(query);
}

function moderation_update_history(
    xuid,
    display_name,
    action_name,
    reason,
    actor,
    counter_name,
    test_mode
)
{
    path = moderation_history_path(xuid, test_mode);
    json = ezz_admin_storage::load_json_or_default(
        path,
        moderation_default_history(xuid, display_name),
        "moderation-history-load"
    );

    if (counter_name != "")
    {
        count = moderation_json_int(json, counter_name);
        json = jsonset(json, counter_name, "" + (count + 1));
    }

    actor_xuid = "server";

    if (isdefined(actor))
        actor_xuid = ezz_admin_identity::get_player_xuid(actor);

    json = jsonset(json, "last_display_name", ezz_admin_storage::sanitize_log_text(display_name));
    json = jsonset(json, "last_action", action_name);
    json = jsonset(json, "last_reason", ezz_admin_storage::sanitize_log_text(reason));
    json = jsonset(json, "last_actor_xuid", actor_xuid);
    json = jsonset(json, "last_gettime", "" + GetTime());

    return ezz_admin_storage::write_json_safe(path, json, "moderation-history-" + action_name);
}

function record_external_action(xuid, display_name, action_name, reason, actor_xuid)
{
    counter_name = "";

    if (action_name == "temporary_ban") counter_name = "temporary_bans";
    else if (action_name == "permanent_ban") counter_name = "permanent_bans";
    else if (action_name == "unban") counter_name = "unbans";

    path = moderation_history_path(xuid, false);
    json = ezz_admin_storage::load_json_or_default(
        path,
        moderation_default_history(xuid, display_name),
        "moderation-external-history-load"
    );

    if (counter_name != "")
        json = jsonset(json, counter_name, "" + (moderation_json_int(json, counter_name) + 1));

    json = jsonset(json, "last_display_name", ezz_admin_storage::sanitize_log_text(display_name));
    json = jsonset(json, "last_action", action_name);
    json = jsonset(json, "last_reason", ezz_admin_storage::sanitize_log_text(reason));
    json = jsonset(json, "last_actor_xuid", ezz_admin_identity::normalize_xuid(actor_xuid));
    json = jsonset(json, "last_gettime", "" + GetTime());

    return ezz_admin_storage::write_json_safe(path, json, "moderation-external-" + action_name);
}

function moderation_write_mute(target, actor, reason)
{
    json = "{}";
    json = jsonset(json, "schema_version", "1");
    json = jsonset(json, "identity_kind", "BOIII_XUID");
    json = jsonset(json, "xuid", target.xuid);
    json = jsonset(json, "display_name", ezz_admin_storage::sanitize_log_text(target.display));
    json = jsonset(json, "reason", ezz_admin_storage::sanitize_log_text(reason));
    json = jsonset(json, "created_gettime", "" + GetTime());

    actor_xuid = "server";
    if (isdefined(actor)) actor_xuid = ezz_admin_identity::get_player_xuid(actor);
    json = jsonset(json, "actor_xuid", actor_xuid);

    return ezz_admin_storage::write_json_safe(
        moderation_mute_path(target.xuid),
        json,
        "moderation-mute"
    );
}

function is_xuid_muted(xuid)
{
    if (!moderation_is_enabled())
        return false;

    if (!ezz_admin_identity::is_valid_xuid(xuid))
        return false;

    path = moderation_mute_path(xuid);

    if (!fileexists(path))
        return false;

    json = readfile(path);
    return ezz_admin_storage::storage_json_is_valid(json) &&
        moderation_json_string(json, "identity_kind", "") == "BOIII_XUID";
}

function is_player_muted(player)
{
    if (!isdefined(player))
        return false;

    if (isdefined(player.pintemod_muted) && player.pintemod_muted)
        return true;

    return is_xuid_muted(ezz_admin_identity::get_player_xuid(player));
}

function moderation_apply_native_adapter(player, enabled)
{
    if (!isdefined(player))
        return;

    player.pintemod_muted = enabled;

    if (!isdefined(level.pintemod_native_mute_command) ||
        level.pintemod_native_mute_command == "")
    {
        if (enabled)
        {
            moderation_log(
                "MUTE_NATIVE_ADAPTER_PENDING",
                undefined,
                ezz_admin_identity::get_player_xuid(player),
                "state=true | runtime_validation_required=true"
            );
        }
        return;
    }

    command_line = level.pintemod_native_mute_command + " " +
        player GetEntityNumber() + " " + enabled;

    if (!ezz_admin_identity::has_dangerous_command_characters(command_line))
        executecommand(command_line);
}

function request_mute(actor, query, reason)
{
    if (!moderation_is_enabled())
    {
        moderation_log("MODERATION_REFUSED", actor, "", "action=mute | reason=disabled");
        if (isdefined(actor)) actor iprintln("^3[PinteMod]^7 Moderation is disabled.");
        return false;
    }

    reason = moderation_normalize_reason(reason);

    if (!moderation_reason_is_safe(reason))
    {
        moderation_log("MODERATION_REFUSED", actor, "", "action=mute | reason=unsafe_reason");
        if (isdefined(actor)) actor iprintln("^1[PinteMod]^7 Unsafe/long reason rejected.");
        return false;
    }

    target = moderation_resolve_target(query);

    if (!isdefined(target) || !target.success || !isdefined(target.xuid))
    {
        moderation_log("MODERATION_REFUSED", actor, "", "action=mute | reason=target_not_resolved");
        if (isdefined(actor)) actor iprintln(ezz_admin_localization::text(actor, "moderation_target_missing"));
        println("^1[PinteMod Moderation]^7 Target not found: " + query);
        return false;
    }

    check = moderation_check(actor, target, "mute");

    if (!check.allowed)
    {
        moderation_log("MODERATION_REFUSED", actor, target.xuid, "action=mute | reason=" + check.reason);
        if (isdefined(actor)) actor iprintln("^1[PinteMod]^7 Mute refused: " + check.reason);
        return false;
    }

    if (is_xuid_muted(target.xuid))
    {
        if (isdefined(actor)) actor iprintln("^3[PinteMod]^7 Player is already muted.");
        return true;
    }

    if (!moderation_write_mute(target, actor, reason))
        return false;

    moderation_update_history(target.xuid, target.display, "mute", reason, actor, "mutes", false);

    if (isdefined(target.player))
    {
        moderation_apply_native_adapter(target.player, true);
        target.player iprintln(ezz_admin_localization::text(target.player, "moderation_muted") + " Reason: " + reason);
    }

    moderation_log("MUTE", actor, target.xuid, "target=" + target.display + " | reason=" + reason);
    return true;
}

function request_unmute(actor, query)
{
    if (!moderation_is_enabled())
    {
        moderation_log("MODERATION_REFUSED", actor, "", "action=unmute | reason=disabled");
        if (isdefined(actor)) actor iprintln("^3[PinteMod]^7 Moderation is disabled.");
        return false;
    }

    target = moderation_resolve_target(query);

    if (!isdefined(target) || !target.success || !isdefined(target.xuid))
    {
        moderation_log("MODERATION_REFUSED", actor, "", "action=unmute | reason=target_not_resolved");
        if (isdefined(actor)) actor iprintln(ezz_admin_localization::text(actor, "moderation_target_missing"));
        return false;
    }

    check = moderation_check(actor, target, "unmute");

    if (!check.allowed)
    {
        moderation_log("MODERATION_REFUSED", actor, target.xuid, "action=unmute | reason=" + check.reason);
        if (isdefined(actor)) actor iprintln("^1[PinteMod]^7 Unmute refused: " + check.reason);
        return false;
    }

    path = moderation_mute_path(target.xuid);

    if (fileexists(path))
        removefile(path);

    if (isdefined(target.player))
    {
        moderation_apply_native_adapter(target.player, false);
        target.player iprintln(ezz_admin_localization::text(target.player, "moderation_unmuted"));
    }

    moderation_update_history(target.xuid, target.display, "unmute", "", actor, "", false);
    moderation_log("UNMUTE", actor, target.xuid, "target=" + target.display);
    return true;
}

function moderation_delayed_kick(client_number)
{
    wait 0.2;
    executecommand(level.pintemod_kick_command + " " + client_number);
}

function request_kick(actor, query, reason)
{
    if (!moderation_is_enabled())
    {
        moderation_log("MODERATION_REFUSED", actor, "", "action=kick | reason=disabled");
        if (isdefined(actor)) actor iprintln("^3[PinteMod]^7 Moderation is disabled.");
        return false;
    }

    reason = moderation_normalize_reason(reason);

    if (!moderation_reason_is_safe(reason))
    {
        moderation_log("MODERATION_REFUSED", actor, "", "action=kick | reason=unsafe_reason");
        if (isdefined(actor)) actor iprintln("^1[PinteMod]^7 Unsafe/long reason rejected.");
        return false;
    }

    target = moderation_resolve_target(query);

    if (!isdefined(target) || !target.success || !isdefined(target.player))
    {
        moderation_log("MODERATION_REFUSED", actor, "", "action=kick | reason=connected_target_not_resolved");
        if (isdefined(actor)) actor iprintln("^1[PinteMod]^7 Kick target must be connected.");
        return false;
    }

    check = moderation_check(actor, target, "kick");

    if (!check.allowed)
    {
        moderation_log("MODERATION_REFUSED", actor, target.xuid, "action=kick | reason=" + check.reason);
        if (isdefined(actor)) actor iprintln("^1[PinteMod]^7 Kick refused: " + check.reason);
        return false;
    }

    moderation_update_history(target.xuid, target.display, "kick", reason, actor, "kicks", false);
    moderation_log("KICK", actor, target.xuid, "target=" + target.display + " | reason=" + reason);

    client_number = target.player GetEntityNumber();
    target.player iprintln("^1[PinteMod]^7 You were kicked. Reason: " + reason);
    level thread moderation_delayed_kick(client_number);
    return true;
}

function show_history(actor, query)
{
    target = moderation_resolve_target(query);

    if (!isdefined(target) || !target.success || !isdefined(target.xuid))
    {
        if (isdefined(actor)) actor iprintln(ezz_admin_localization::text(actor, "moderation_target_missing"));
        println("^1[PinteMod Moderation]^7 Target not found: " + query);
        return;
    }

    actor_role = moderation_actor_role(actor);

    if (actor_role < 3)
    {
        moderation_log("MODERATION_REFUSED", actor, target.xuid, "action=history | reason=admin_required");
        if (isdefined(actor)) actor iprintln(ezz_admin_localization::text(actor, "moderation_admin_required"));
        return;
    }

    path = moderation_history_path(target.xuid, false);
    json = ezz_admin_storage::load_json_or_default(
        path,
        moderation_default_history(target.xuid, target.display),
        "moderation-history-show"
    );

    println("^5========== PinteMod Player History ==========");
    println("^7Player          " + moderation_json_string(json, "last_display_name", target.display));
    println("^7BOIII_XUID      " + target.xuid);
    println("^7Kicks           " + moderation_json_int(json, "kicks"));
    println("^7Mutes           " + moderation_json_int(json, "mutes"));
    println("^7Temporary bans  " + moderation_json_int(json, "temporary_bans"));
    println("^7Permanent bans  " + moderation_json_int(json, "permanent_bans"));
    println("^7Unbans          " + moderation_json_int(json, "unbans"));
    println("^7Last action     " + moderation_json_string(json, "last_action", "none") +
        " — " + moderation_json_string(json, "last_reason", ""));
    println("^7Muted now       " + is_xuid_muted(target.xuid));
    println("^5=============================================");
}

function should_block_chat(player, message)
{
    if (!moderation_is_enabled())
        return false;

    if (!is_player_muted(player))
        return false;

    if (!isdefined(message) || message == "")
        return true;

    prefix = GetSubStr(message, 0, 1);

    // Administrative commands remain available; native public text
    // suppression is delegated to the configured BOIII adapter.
    if (prefix == "." || prefix == "!")
        return false;

    player iprintln(ezz_admin_localization::text(player, "moderation_muted"));
    moderation_log(
        "MUTE_BLOCK",
        player,
        ezz_admin_identity::get_player_xuid(player),
        "source=chat_router"
    );
    return true;
}

function moderation_attach(player)
{
    if (!isdefined(player))
        return;

    wait 1;
    muted = is_xuid_muted(ezz_admin_identity::get_player_xuid(player));
    moderation_apply_native_adapter(player, muted);

    moderation_log(
        "MODERATION_STATE",
        undefined,
        ezz_admin_identity::get_player_xuid(player),
        "client=" + player GetEntityNumber() + " | muted=" + muted +
        " | role=" + ezz_admin_identity::get_role_name(ezz_admin_identity::get_player_role(player))
    );
}

function moderation_bootstrap()
{
    if (!moderation_is_enabled())
        return;

    wait 2;
    players = GetPlayers();

    for (i = 0; i < players.size; i++)
        if (isdefined(players[i])) players[i] thread moderation_attach(players[i]);

    for (;;)
    {
        level waittill("connected", player);
        if (isdefined(player)) player thread moderation_attach(player);
    }
}

function moderation_join_args(args, start_index)
{
    value = "";

    for (i = start_index; i < args.size; i++)
    {
        if (value != "") value = value + " ";
        value = value + args[i];
    }

    return value;
}

function cmd_ezzmute(args)
{
    if (args.size < 1)
    {
        println("^7ezzmute <player|xuid|client> [reason]");
        return;
    }

    request_mute(undefined, args[0], moderation_join_args(args, 1));
}

function cmd_ezzunmute(args)
{
    if (args.size < 1)
    {
        println("^7ezzunmute <player|xuid|client>");
        return;
    }

    request_unmute(undefined, args[0]);
}

function cmd_ezzkick(args)
{
    if (args.size < 1)
    {
        println("^7ezzkick <player|xuid|client> [reason]");
        return;
    }

    request_kick(undefined, args[0], moderation_join_args(args, 1));
}

function cmd_ezzhistory(args)
{
    if (args.size < 1)
    {
        println("^7ezzhistory <player|xuid|client>");
        return;
    }

    show_history(undefined, args[0]);
}

function cmd_ezzmoderationstatus(args)
{
    println("^5===== PinteMod Moderation v2.1.1 =====");
    println("^7Identity: BOIII_XUID");
    println("^7Hierarchy: Owner > Admin > Moderator > Helper > User");
    println("^7Bootstrap Owner protected: " + moderation_bootstrap_owner_xuid());
    println("^7Native mute adapter configured: " +
        (isdefined(level.pintemod_native_mute_command) && level.pintemod_native_mute_command != ""));
    println("^7History root: boiii/scriptdata/" + moderation_history_root());
    println("^7Privacy: no IP persisted");
}

function moderation_test_assert(result, condition, name)
{
    result.total++;
    if (condition) { result.passed++; println("^2[PASS]^7 " + name); }
    else { result.failed++; println("^1[FAIL]^7 " + name); }
}

function moderation_run_grouped_suite()
{
    result = SpawnStruct();
    result.total = 0;
    result.passed = 0;
    result.failed = 0;
    xuid = "1111111111111111";
    path = moderation_history_path(xuid, true);
    removefile(path); removefile(path + ".tmp"); removefile(path + ".bak");

    moderation_test_assert(result, moderation_is_bootstrap_owner(moderation_bootstrap_owner_xuid()), "Bootstrap owner protection");
    moderation_test_assert(result, !moderation_is_bootstrap_owner(xuid), "Synthetic XUID is not owner");
    moderation_test_assert(result, moderation_role_allows_action(4, 3, false, false), "Owner can act on Admin");
    moderation_test_assert(result, moderation_role_allows_action(3, 2, false, false), "Admin can act on Moderator");
    moderation_test_assert(result, moderation_role_allows_action(3, 1, false, false), "Admin can act on Helper");
    moderation_test_assert(result, moderation_role_allows_action(3, 0, false, false), "Admin can act on User");
    moderation_test_assert(result, !moderation_role_allows_action(3, 3, false, false), "Equal role is protected");
    moderation_test_assert(result, !moderation_role_allows_action(3, 4, false, false), "Higher role is protected");
    moderation_test_assert(result, !moderation_role_allows_action(2, 0, false, false), "Moderator cannot sanction");
    moderation_test_assert(result, !moderation_role_allows_action(4, 0, true, false), "Self-action is protected");
    moderation_test_assert(result, !moderation_role_allows_action(4, 0, false, true), "Bootstrap target is protected");
    moderation_test_assert(result, moderation_update_history(xuid, "Synthetic", "kick", "test", undefined, "kicks", true), "History test write");
    json = readfile(path);
    moderation_test_assert(result, moderation_json_int(json, "kicks") == 1, "Kick history counter");
    moderation_test_assert(result, moderation_json_string(json, "identity_kind", "") == "BOIII_XUID", "History identity kind");

    removefile(path); removefile(path + ".tmp"); removefile(path + ".bak");
    return result;
}

function cmd_ezzmoderationtest(args)
{
    result = moderation_run_grouped_suite();
    println("^5[PinteMod Moderation]^7 RESULT " + result.passed + "/" + result.total + " PASS | failed=" + result.failed);
}

autoexec function init()
{
    if (isdefined(level.pintemod_moderation_loaded) && level.pintemod_moderation_loaded)
        return;

    level.pintemod_moderation_loaded = true;
    level.pintemod_moderation_version = "2.1.1";

    if (!isdefined(level.pintemod_moderation_enabled))
        level.pintemod_moderation_enabled = true;

    if (!isdefined(level.pintemod_native_mute_command))
        level.pintemod_native_mute_command = "";

    mkdir("pintemod");
    mkdir(moderation_root());
    mkdir(moderation_history_root());
    mkdir(moderation_mute_root());

    addcommand("ezzmute", ::cmd_ezzmute);
    addcommand("ezzunmute", ::cmd_ezzunmute);
    addcommand("ezzkick", ::cmd_ezzkick);
    addcommand("ezzhistory", ::cmd_ezzhistory);
    addcommand("ezzmoderationstatus", ::cmd_ezzmoderationstatus);
    addcommand("ezzmoderationtest", ::cmd_ezzmoderationtest);

    level thread moderation_bootstrap();
    println("^5[PinteMod]^7 Moderation v2.1.1 loaded");
}
