// ============================================================
// PinteMod — Stable Identity & Permissions v2.0.2
// Fichier : ezz_admin_identity.gsc
//
// Source d'identité autoritative : BOIII_XUID via player getXuid(false).
// Le pseudonyme est exclusivement un nom d'affichage et de ciblage local.
// Aucun rôle n'est accordé à partir d'un pseudonyme.
// ============================================================

#namespace ezz_admin_identity;

#using custom_scripts\ezz_admin_storage;

function identity_log_file(message)
{
    if (!ezz_admin_storage::append_managed_log(
        "pintemod/logs/identity.log",
        "[" + GetTime() + "] " + message + "\n"
    ))
    {
        println("^1[PinteMod Identity]^7 WRITE_FAILED | identity.log");
    }
}

function identity_console_verbose()
{
    return isdefined(level.pintemod_server_console_verbose) &&
        level.pintemod_server_console_verbose;
}

function identity_message_is_important(message)
{
    if (!isdefined(message))
        return false;

    return message.size >= 14 &&
        (GetSubStr(message, 0, 14) == "ROLE_REGISTRY_" ||
         GetSubStr(message, 0, 14) == "IDENTITY_UNAVA");
}

function identity_log(message)
{
    if (identity_console_verbose() || identity_message_is_important(message))
        println("^5[PinteMod Identity]^7 " + message);

    identity_log_file(message);
}

function identity_log_xuid_value(xuid)
{
    return ezz_admin_storage::log_xuid(xuid);
}

function identity_log_guid_value(guid)
{
    return ezz_admin_storage::log_guid(guid);
}

function identity_default_roles_json()
{
    json = "{}";
    json = jsonset(json, "schema_version", "1");
    json = jsonset(json, "identity_kind", "BOIII_XUID");
    json = jsonset(json, "count", "0");
    return json;
}

function identity_json_int(json, key_name, default_value)
{
    // BOIII jsonvalid() returns true when JSON contains a parse error.
    if (!isdefined(json) || json == "" || jsonvalid(json))
        return default_value;

    value = jsonparse(json, key_name);

    if (!isdefined(value) || value == "")
        return default_value;

    return int(value);
}

function identity_json_string(json, key_name, default_value)
{
    if (!isdefined(json) || json == "" || jsonvalid(json))
        return default_value;

    value = jsonparse(json, key_name);

    if (!isdefined(value) || value == "")
        return default_value;

    return value;
}

function identity_roles_path(test_mode)
{
    if (isdefined(test_mode) && test_mode)
        return "pintemod/identity/test/roles.json";

    return "pintemod/identity/roles.json";
}

function identity_load_roles_json(test_mode)
{
    if ((!isdefined(test_mode) || !test_mode) &&
        isdefined(level.pintemod_identity_roles_json))
    {
        return level.pintemod_identity_roles_json;
    }

    path = identity_roles_path(test_mode);

    if (!fileexists(path))
    {
        json = identity_default_roles_json();

        if (!isdefined(test_mode) || !test_mode)
            level.pintemod_identity_roles_json = json;

        return json;
    }

    json = ezz_admin_storage::load_json_or_default(
        path,
        identity_default_roles_json(),
        "identity-role-registry"
    );

    if (!isdefined(json) || json == "" || jsonvalid(json))
    {
        identity_log("ROLE_REGISTRY_INVALID_JSON | path=" + path);
        return identity_default_roles_json();
    }

    if (identity_json_int(json, "schema_version", 0) != 1)
    {
        identity_log("ROLE_REGISTRY_SCHEMA_MISMATCH | path=" + path);
        return identity_default_roles_json();
    }

    if (identity_json_string(json, "identity_kind", "") != "BOIII_XUID")
    {
        identity_log("ROLE_REGISTRY_IDENTITY_MISMATCH | path=" + path);
        return identity_default_roles_json();
    }

    if (!isdefined(test_mode) || !test_mode)
        level.pintemod_identity_roles_json = json;

    return json;
}

function identity_write_roles_json(json, test_mode, context)
{
    path = identity_roles_path(test_mode);

    if (ezz_admin_storage::write_json_safe(path, json, context))
    {
        if (!isdefined(test_mode) || !test_mode)
            level.pintemod_identity_roles_json = json;

        return true;
    }

    identity_log(
        "ROLE_REGISTRY_WRITE_FAILED | path=" + path +
        " | context=" + context
    );
    return false;
}

function normalize_xuid(value)
{
    if (!isdefined(value))
        return "";

    xuid = toLower("" + value);

    if (xuid.size > 2 && xuid[0] == "0" && xuid[1] == "x")
        xuid = GetSubStr(xuid, 2, xuid.size);

    return xuid;
}

function identity_is_hex_character(character)
{
    return character == "0" || character == "1" ||
        character == "2" || character == "3" ||
        character == "4" || character == "5" ||
        character == "6" || character == "7" ||
        character == "8" || character == "9" ||
        character == "a" || character == "b" ||
        character == "c" || character == "d" ||
        character == "e" || character == "f";
}

function is_valid_xuid(value)
{
    xuid = normalize_xuid(value);

    if (xuid == "" || xuid == "0" || xuid == "undefined")
        return false;

    // BOIII serializes the authenticated XUID as a hexadecimal identifier.
    // Keep it opaque, but reject display names and malformed registry values.
    if (xuid.size < 12 || xuid.size > 32)
        return false;

    for (i = 0; i < xuid.size; i++)
    {
        if (!identity_is_hex_character(xuid[i]))
            return false;
    }

    return true;
}

function identity_raw_text(value)
{
    if (!isdefined(value))
        return "<undefined>";

    text = "" + value;

    if (text == "")
        return "<empty>";

    return text;
}

function identity_raw_length(value)
{
    if (!isdefined(value))
        return 0;

    return ("" + value).size;
}

function read_native_xuid(player)
{
    if (!isdefined(player))
        return "";

    native_value = player getXuid(false);
    xuid = normalize_xuid(native_value);

    if (!is_valid_xuid(xuid))
        return "";

    return xuid;
}

function read_native_guid(player)
{
    if (!isdefined(player))
        return "";

    guid_value = player getGuid();

    if (!isdefined(guid_value))
        return "";

    return "" + guid_value;
}

function get_player_xuid(player)
{
    if (!isdefined(player))
        return "";

    xuid = read_native_xuid(player);

    if (is_valid_xuid(xuid))
    {
        player.pintemod_identity_xuid = xuid;
        player.pintemod_identity_display_name = player.name;
        return xuid;
    }

    if (isdefined(player.pintemod_identity_xuid) &&
        is_valid_xuid(player.pintemod_identity_xuid))
    {
        return normalize_xuid(player.pintemod_identity_xuid);
    }

    return "";
}

function get_player_guid(player)
{
    if (!isdefined(player))
        return "";

    guid = read_native_guid(player);

    if (guid != "")
        player.pintemod_identity_guid = guid;

    if (isdefined(player.pintemod_identity_guid))
        return player.pintemod_identity_guid;

    return "";
}

function identity_xuid_in_list(xuid, values)
{
    if (!is_valid_xuid(xuid) || !isdefined(values))
        return false;

    wanted_xuid = normalize_xuid(xuid);

    for (i = 0; i < values.size; i++)
    {
        if (!isdefined(values[i]))
            continue;

        if (normalize_xuid(values[i]) == wanted_xuid)
            return true;
    }

    return false;
}

function role_from_text(role_name)
{
    if (!isdefined(role_name))
        return -1;

    switch (toLower(role_name))
    {
        case "owner":
            return 4;

        case "admin":
            return 3;

        case "moderator":
        case "mod":
            return 2;

        case "helper":
        case "help":
            return 1;

        case "user":
        case "none":
            return 0;
    }

    return -1;
}

function get_role_name(role)
{
    switch (role)
    {
        case 4:
            return "owner";

        case 3:
            return "admin";

        case 2:
            return "moderator";

        case 1:
            return "helper";
    }

    return "user";
}

function identity_ensure_runtime_roles()
{
    if (!isdefined(level.pintemod_identity_runtime_roles))
        level.pintemod_identity_runtime_roles = [];
}

function identity_runtime_role_for_xuid(xuid)
{
    identity_ensure_runtime_roles();
    wanted_xuid = normalize_xuid(xuid);

    for (i = 0; i < level.pintemod_identity_runtime_roles.size; i++)
    {
        entry = level.pintemod_identity_runtime_roles[i];

        if (!isdefined(entry) || !isdefined(entry.xuid))
            continue;

        if (normalize_xuid(entry.xuid) == wanted_xuid)
            return entry.role;
    }

    return -1;
}

function set_runtime_role_for_xuid(xuid, role, display_name, actor_name)
{
    if (!is_valid_xuid(xuid) || role < 0 || role > 4)
        return false;

    identity_ensure_runtime_roles();
    wanted_xuid = normalize_xuid(xuid);

    for (i = 0; i < level.pintemod_identity_runtime_roles.size; i++)
    {
        entry = level.pintemod_identity_runtime_roles[i];

        if (!isdefined(entry) || !isdefined(entry.xuid))
            continue;

        if (normalize_xuid(entry.xuid) == wanted_xuid)
        {
            entry.role = role;
            entry.display = display_name;
            entry.actor = actor_name;
            entry.updated_gettime = GetTime();

            identity_log(
                "RUNTIME_ROLE_UPDATED | xuid=" + wanted_xuid +
                " | display=" + display_name +
                " | role=" + get_role_name(role) +
                " | actor=" + actor_name
            );
            return true;
        }
    }

    entry = SpawnStruct();
    entry.xuid = wanted_xuid;
    entry.role = role;
    entry.display = display_name;
    entry.actor = actor_name;
    entry.updated_gettime = GetTime();
    level.pintemod_identity_runtime_roles[
        level.pintemod_identity_runtime_roles.size
    ] = entry;

    identity_log(
        "RUNTIME_ROLE_ADDED | xuid=" + wanted_xuid +
        " | display=" + display_name +
        " | role=" + get_role_name(role) +
        " | actor=" + actor_name
    );
    return true;
}

function set_runtime_role_for_player(player, role, actor_name)
{
    if (!isdefined(player))
        return false;

    xuid = get_player_xuid(player);

    if (!is_valid_xuid(xuid))
        return false;

    return set_runtime_role_for_xuid(
        xuid,
        role,
        player.name,
        actor_name
    );
}

function identity_persistent_role_for_xuid(xuid, test_mode)
{
    if (!is_valid_xuid(xuid))
        return -1;

    json = identity_load_roles_json(test_mode);
    count = identity_json_int(json, "count", 0);
    wanted_xuid = normalize_xuid(xuid);

    if (count < 0)
        count = 0;

    if (count > 64)
        count = 64;

    for (position = 1; position <= count; position++)
    {
        stored_xuid = identity_json_string(
            json,
            "xuid_" + position,
            ""
        );

        if (normalize_xuid(stored_xuid) != wanted_xuid)
            continue;

        role = identity_json_int(json, "role_" + position, -1);

        if (role >= 1 && role <= 4)
            return role;
    }

    return -1;
}

function identity_persistent_display_for_xuid(xuid, test_mode)
{
    if (!is_valid_xuid(xuid))
        return "";

    json = identity_load_roles_json(test_mode);
    count = identity_json_int(json, "count", 0);
    wanted_xuid = normalize_xuid(xuid);

    if (count > 64)
        count = 64;

    for (position = 1; position <= count; position++)
    {
        stored_xuid = identity_json_string(
            json,
            "xuid_" + position,
            ""
        );

        if (normalize_xuid(stored_xuid) == wanted_xuid)
        {
            return identity_json_string(
                json,
                "display_" + position,
                ""
            );
        }
    }

    return "";
}

function identity_set_persistent_role(
    xuid,
    role,
    display_name,
    actor_name,
    test_mode
)
{
    if (!is_valid_xuid(xuid) || role < 0 || role > 4)
        return false;

    old_json = identity_load_roles_json(test_mode);
    old_count = identity_json_int(old_json, "count", 0);
    wanted_xuid = normalize_xuid(xuid);
    new_json = identity_default_roles_json();
    new_count = 0;

    if (old_count > 64)
        old_count = 64;

    for (position = 1; position <= old_count; position++)
    {
        stored_xuid = normalize_xuid(identity_json_string(
            old_json,
            "xuid_" + position,
            ""
        ));
        stored_role = identity_json_int(
            old_json,
            "role_" + position,
            -1
        );

        if (!is_valid_xuid(stored_xuid) ||
            stored_role < 1 || stored_role > 4 ||
            stored_xuid == wanted_xuid)
        {
            continue;
        }

        new_count++;
        new_json = jsonset(
            new_json,
            "xuid_" + new_count,
            stored_xuid
        );
        new_json = jsonset(
            new_json,
            "role_" + new_count,
            "" + stored_role
        );
        new_json = jsonset(
            new_json,
            "display_" + new_count,
            identity_json_string(
                old_json,
                "display_" + position,
                ""
            )
        );
    }

    // role 0 means removal from persistent authorization.
    if (role > 0)
    {
        if (new_count >= 64)
        {
            identity_log("ROLE_REGISTRY_FULL | max=64");
            return false;
        }

        new_count++;
        new_json = jsonset(new_json, "xuid_" + new_count, wanted_xuid);
        new_json = jsonset(new_json, "role_" + new_count, "" + role);
        new_json = jsonset(
            new_json,
            "display_" + new_count,
            display_name
        );
    }

    new_json = jsonset(new_json, "count", "" + new_count);
    new_json = jsonset(new_json, "updated_gettime", "" + GetTime());
    new_json = jsonset(new_json, "updated_by", actor_name);

    if (!identity_write_roles_json(
        new_json,
        test_mode,
        "set-persistent-role"
    ))
    {
        return false;
    }

    identity_log(
        "PERSISTENT_ROLE_CHANGED | xuid=" + wanted_xuid +
        " | display=" + display_name +
        " | role=" + get_role_name(role) +
        " | actor=" + actor_name +
        " | test=" + test_mode
    );
    return true;
}

function get_player_role(player)
{
    if (!isdefined(player))
        return 0;

    xuid = get_player_xuid(player);

    // Fail closed: no stable XUID means no privileged role.
    if (!is_valid_xuid(xuid))
        return 0;

    runtime_role = identity_runtime_role_for_xuid(xuid);

    if (runtime_role >= 0)
        return runtime_role;

    persistent_role = identity_persistent_role_for_xuid(xuid, false);

    if (persistent_role >= 0)
        return persistent_role;

    if (identity_xuid_in_list(xuid, level.ezz_owner_xuids))
        return 4;

    if (identity_xuid_in_list(xuid, level.ezz_admin_xuids))
        return 3;

    if (identity_xuid_in_list(xuid, level.ezz_moderator_xuids))
        return 2;

    if (identity_xuid_in_list(xuid, level.ezz_helper_xuids))
        return 1;

    return 0;
}

function get_player_role_source(player)
{
    if (!isdefined(player))
        return "none";

    xuid = get_player_xuid(player);

    if (!is_valid_xuid(xuid))
        return "missing-xuid";

    if (identity_runtime_role_for_xuid(xuid) >= 0)
        return "runtime-xuid";

    if (identity_persistent_role_for_xuid(xuid, false) >= 0)
        return "registry-xuid";

    if (identity_xuid_in_list(xuid, level.ezz_owner_xuids) ||
        identity_xuid_in_list(xuid, level.ezz_admin_xuids) ||
        identity_xuid_in_list(xuid, level.ezz_moderator_xuids) ||
        identity_xuid_in_list(xuid, level.ezz_helper_xuids))
    {
        return "config-xuid";
    }

    return "none";
}

function identity_is_decimal_character(character)
{
    return character == "0" || character == "1" ||
        character == "2" || character == "3" ||
        character == "4" || character == "5" ||
        character == "6" || character == "7" ||
        character == "8" || character == "9";
}

function identity_parse_client_number(query)
{
    if (!isdefined(query) || query == "")
        return -1;

    text = toLower("" + query);

    if (text.size > 7 && GetSubStr(text, 0, 7) == "client:")
        text = GetSubStr(text, 7, text.size);
    else if (text.size > 1 && GetSubStr(text, 0, 1) == "#")
        text = GetSubStr(text, 1, text.size);

    if (text == "" || text.size > 3)
        return -1;

    for (i = 0; i < text.size; i++)
    {
        if (!identity_is_decimal_character(GetSubStr(text, i, i + 1)))
            return -1;
    }

    client_number = int(text);

    if (client_number < 0 || client_number > 63)
        return -1;

    return client_number;
}

function has_dangerous_command_characters(value)
{
    if (!isdefined(value))
        return false;

    text = "" + value;

    for (i = 0; i < text.size; i++)
    {
        character = GetSubStr(text, i, i + 1);

        if (character == "\"" || character == ";" ||
            character == "\n" || character == "\r")
        {
            return true;
        }
    }

    return false;
}

function get_player_selector(player)
{
    if (!isdefined(player))
        return "";

    xuid = get_player_xuid(player);

    if (is_valid_xuid(xuid))
        return xuid;

    return "#" + player GetEntityNumber();
}

function resolve_connected_target(query)
{
    result = SpawnStruct();
    result.success = false;
    result.player = undefined;
    result.reason = "not_found";
    result.matches = 0;
    result.query = query;

    if (!isdefined(query) || query == "")
    {
        result.reason = "empty";
        return result;
    }

    players = GetPlayers();
    normalized_query = normalize_xuid(query);

    if (is_valid_xuid(normalized_query))
    {
        for (i = 0; i < players.size; i++)
        {
            player = players[i];

            if (!isdefined(player))
                continue;

            if (get_player_xuid(player) == normalized_query)
            {
                result.player = player;
                result.success = true;
                result.reason = "xuid";
                result.matches = 1;
                return result;
            }
        }

        result.reason = "xuid_not_connected";
        return result;
    }

    client_number = identity_parse_client_number(query);

    if (client_number >= 0)
    {
        for (i = 0; i < players.size; i++)
        {
            player = players[i];

            if (isdefined(player) &&
                player GetEntityNumber() == client_number)
            {
                result.player = player;
                result.success = true;
                result.reason = "client_number";
                result.matches = 1;
                return result;
            }
        }

        result.reason = "client_not_connected";
        return result;
    }

    wanted_name = toLower("" + query);

    for (i = 0; i < players.size; i++)
    {
        player = players[i];

        if (!isdefined(player) || !isdefined(player.name))
            continue;

        if (toLower(player.name) != wanted_name)
            continue;

        result.matches++;
        result.player = player;
    }

    if (result.matches == 1)
    {
        result.success = true;
        result.reason = "display_name";
        return result;
    }

    if (result.matches > 1)
    {
        result.player = undefined;
        result.reason = "ambiguous_display_name";
        identity_log(
            "TARGET_AMBIGUOUS | query=" + query +
            " | matches=" + result.matches +
            " | use=BOIII_XUID_or_client_number"
        );
    }

    return result;
}

function identity_find_player(query)
{
    resolved = resolve_connected_target(query);

    if (resolved.success)
        return resolved.player;

    return undefined;
}

function identity_join_args(args, first, last_exclusive)
{
    result = "";

    for (i = first; i < last_exclusive; i++)
    {
        if (i > first)
            result = result + " ";

        result = result + args[i];
    }

    return result;
}

function identity_resolve_target(query)
{
    result = SpawnStruct();
    result.success = false;
    result.player = undefined;
    result.xuid = "";
    result.display = query;

    connected = resolve_connected_target(query);

    if (connected.success)
    {
        player = connected.player;
        result.player = player;
        result.xuid = get_player_xuid(player);
        result.display = player.name;
        result.success = is_valid_xuid(result.xuid);
        return result;
    }

    if (connected.reason == "ambiguous_display_name")
        return result;

    possible_xuid = normalize_xuid(query);

    if (is_valid_xuid(possible_xuid))
    {
        result.xuid = possible_xuid;
        result.display = identity_persistent_display_for_xuid(
            possible_xuid,
            false
        );

        if (result.display == "")
            result.display = "offline";

        result.success = true;
    }

    return result;
}

function identity_attach_player(player)
{
    if (!isdefined(player))
        return false;

    xuid = get_player_xuid(player);

    if (!is_valid_xuid(xuid))
        return false;

    client_number = player GetEntityNumber();
    player.pintemod_identity_kind = "BOIII_XUID";
    player.pintemod_identity_guid = get_player_guid(player);
    player.pintemod_identity_display_name = player.name;

    if (!isdefined(player.pintemod_identity_logged) ||
        !player.pintemod_identity_logged)
    {
        player.pintemod_identity_logged = true;
        identity_log(
            "IDENTITY_ATTACHED | display=" + player.name +
            " | client=" + client_number +
            " | xuid=" + identity_log_xuid_value(xuid) +
            " | guid=" + identity_log_guid_value(get_player_guid(player)) +
            " | role=" + get_role_name(get_player_role(player)) +
            " | source=" + get_player_role_source(player)
        );
    }

    return true;
}

function identity_attach_when_ready()
{
    self endon("disconnect");

    for (attempt = 0; attempt < 40; attempt++)
    {
        if (identity_attach_player(self))
            return;

        wait 0.25;
    }

    client_number = self GetEntityNumber();
    identity_log(
        "IDENTITY_UNAVAILABLE | display=" + self.name +
        " | client=" + client_number
    );
}

function identity_bootstrap()
{
    wait 1;
    players = GetPlayers();

    for (i = 0; i < players.size; i++)
    {
        if (isdefined(players[i]))
            players[i] thread identity_attach_when_ready();
    }

    for (;;)
    {
        level waittill("connected", player);

        if (isdefined(player))
            player thread identity_attach_when_ready();
    }
}

function identity_print_player(player)
{
    if (!isdefined(player))
        return;

    xuid = get_player_xuid(player);
    guid = get_player_guid(player);
    role = get_player_role(player);
    client_number = player GetEntityNumber();

    println(
        "^7" + player.name +
        " | client=" + client_number +
        " | BOIII_XUID=" + xuid +
        " | GUID=" + guid +
        " | role=" + get_role_name(role) +
        " | source=" + get_player_role_source(player)
    );
}

function cmd_ezzidentity(args)
{
    if (args.size <= 0)
    {
        println("^3[PinteMod Identity]^7 Usage: ezzidentity <PlayerName|BOIII_XUID|ClientNumber>");
        return;
    }

    query = identity_join_args(args, 0, args.size);
    player = identity_find_player(query);

    if (!isdefined(player))
    {
        println("^1[PinteMod Identity]^7 Connected player not found: " + query);
        return;
    }

    identity_print_player(player);
}

function cmd_ezzidentities(args)
{
    players = GetPlayers();
    println("^5===== PINTEMOD STABLE IDENTITIES =====");
    println("^7Identity kind: BOIII_XUID");
    println("^7Connected players: " + players.size);

    for (i = 0; i < players.size; i++)
    {
        if (isdefined(players[i]))
            identity_print_player(players[i]);
    }

    println("^5=======================================");
}

function cmd_ezzidroles(args)
{
    json = identity_load_roles_json(false);
    count = identity_json_int(json, "count", 0);

    if (count > 64)
        count = 64;

    println("^5===== PINTEMOD PERSISTENT XUID ROLES =====");
    println("^7Entries: " + count);

    for (position = 1; position <= count; position++)
    {
        xuid = identity_json_string(json, "xuid_" + position, "");
        role = identity_json_int(json, "role_" + position, 0);
        display = identity_json_string(
            json,
            "display_" + position,
            ""
        );

        println(
            "^7" + position + ". " + display +
            " | xuid=" + xuid +
            " | role=" + get_role_name(role)
        );
    }

    println("^5==========================================");
}

function cmd_ezzidsetrole(args)
{
    if (args.size < 2)
    {
        println("^3[PinteMod Identity]^7 Usage:");
        println("^7ezzidsetrole <PlayerName|BOIII_XUID|ClientNumber> <owner|admin|moderator|helper>");
        return;
    }

    role_text = args[args.size - 1];
    role = role_from_text(role_text);

    if (role <= 0)
    {
        println("^1[PinteMod Identity]^7 Invalid privileged role: " + role_text);
        return;
    }

    query = identity_join_args(args, 0, args.size - 1);
    target = identity_resolve_target(query);

    if (!target.success)
    {
        println("^1[PinteMod Identity]^7 Target/XUID not resolved: " + query);
        return;
    }

    if (!identity_set_persistent_role(
        target.xuid,
        role,
        target.display,
        "server-console",
        false
    ))
    {
        println("^1[PinteMod Identity]^7 Persistent role update failed");
        return;
    }

    println(
        "^2[PinteMod Identity]^7 Persistent role set" +
        " | display=" + target.display +
        " | xuid=" + target.xuid +
        " | role=" + get_role_name(role)
    );
}

function cmd_ezzidremoverole(args)
{
    if (args.size <= 0)
    {
        println("^3[PinteMod Identity]^7 Usage: ezzidremoverole <PlayerName|BOIII_XUID|ClientNumber>");
        return;
    }

    query = identity_join_args(args, 0, args.size);
    target = identity_resolve_target(query);

    if (!target.success)
    {
        println("^1[PinteMod Identity]^7 Target/XUID not resolved: " + query);
        return;
    }

    if (!identity_set_persistent_role(
        target.xuid,
        0,
        target.display,
        "server-console",
        false
    ))
    {
        println("^1[PinteMod Identity]^7 Persistent role removal failed");
        return;
    }

    println(
        "^2[PinteMod Identity]^7 Persistent role removed" +
        " | display=" + target.display +
        " | xuid=" + target.xuid
    );
}

function identity_test_assert(result, condition, test_name, details)
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

function identity_run_grouped_suite(player)
{
    result = SpawnStruct();
    result.total = 0;
    result.passed = 0;
    result.failed = 0;

    println("^5===== PINTEMOD IDENTITY GROUPED SUITE =====");

    identity_test_assert(
        result,
        isdefined(player),
        "01 connected target resolved",
        "Use ezzidentitytest suite <PlayerName|BOIII_XUID|ClientNumber>"
    );

    if (!isdefined(player))
    {
        println("^1[PinteMod Identity]^7 Suite aborted: no target");
        return result;
    }

    raw_xuid_true = player getXuid(true);
    raw_xuid_false = player getXuid(false);
    raw_guid = player getGuid();
    native_xuid_a = read_native_xuid(player);
    native_xuid_b = read_native_xuid(player);
    cached_xuid = get_player_xuid(player);
    original_name = player.name;
    role_before = get_player_role(player);
    source_before = get_player_role_source(player);
    official_roles_path = identity_roles_path(false);
    official_roles_before = "";
    official_roles_existed = fileexists(official_roles_path);

    if (official_roles_existed)
        official_roles_before = readfile(official_roles_path);

    identity_test_assert(
        result,
        is_valid_xuid(native_xuid_a),
        "02 native BOIII_XUID hex available",
        "true=" + identity_raw_text(raw_xuid_true) +
        " (len=" + identity_raw_length(raw_xuid_true) + ")" +
        " | false=" + identity_raw_text(raw_xuid_false) +
        " (len=" + identity_raw_length(raw_xuid_false) + ")" +
        " | guid=" + identity_log_guid_value(raw_guid)
    );
    identity_test_assert(
        result,
        native_xuid_a == native_xuid_b,
        "03 repeated native reads stable",
        native_xuid_a + " != " + native_xuid_b
    );
    identity_test_assert(
        result,
        cached_xuid == native_xuid_a,
        "04 cached identity equals native identity",
        cached_xuid + " != " + native_xuid_a
    );
    identity_test_assert(
        result,
        normalize_xuid(toUpper(native_xuid_a)) == native_xuid_a,
        "05 XUID normalization deterministic",
        "case normalization mismatch"
    );
    identity_test_assert(
        result,
        !identity_xuid_in_list(original_name, level.ezz_owner_xuids),
        "06 display name cannot match XUID role list",
        "name was accepted as stable identity"
    );
    identity_test_assert(
        result,
        get_player_role(player) == role_before &&
        get_player_role_source(player) == source_before,
        "07 role lookup deterministic",
        "role/source changed during suite"
    );

    test_xuid = "1111111111111111";
    test_json = identity_default_roles_json();
    identity_write_roles_json(test_json, true, "suite-clean-start");
    identity_test_assert(
        result,
        identity_set_persistent_role(
            test_xuid,
            2,
            "IdentitySuite",
            "grouped-suite",
            true
        ),
        "08 isolated TEST registry write",
        "write failed"
    );
    identity_test_assert(
        result,
        identity_persistent_role_for_xuid(test_xuid, true) == 2,
        "09 isolated TEST registry read",
        "stored moderator role not recovered"
    );
    identity_test_assert(
        result,
        identity_set_persistent_role(
            test_xuid,
            0,
            "IdentitySuite",
            "grouped-suite",
            true
        ),
        "10 isolated TEST registry removal",
        "removal write failed"
    );
    identity_test_assert(
        result,
        identity_persistent_role_for_xuid(test_xuid, true) == -1,
        "11 isolated TEST registry cleaned",
        "test role still present"
    );

    if (fileexists(identity_roles_path(true)))
        removefile(identity_roles_path(true));

    official_unchanged = true;

    if (official_roles_existed != fileexists(official_roles_path))
        official_unchanged = false;
    else if (official_roles_existed &&
        official_roles_before != readfile(official_roles_path))
    {
        official_unchanged = false;
    }

    identity_test_assert(
        result,
        official_unchanged,
        "12 official role registry unchanged",
        "suite touched official data"
    );

    duplicate_xuid = false;
    players = GetPlayers();

    for (i = 0; i < players.size; i++)
    {
        if (!isdefined(players[i]))
            continue;

        xuid_i = get_player_xuid(players[i]);

        if (!is_valid_xuid(xuid_i))
            continue;

        for (j = i + 1; j < players.size; j++)
        {
            if (!isdefined(players[j]))
                continue;

            if (xuid_i == get_player_xuid(players[j]))
                duplicate_xuid = true;
        }
    }

    identity_test_assert(
        result,
        !duplicate_xuid,
        "13 connected BOIII_XUID values unique",
        "two connected players share one XUID"
    );
    identity_test_assert(
        result,
        isdefined(level.ezz_owner_xuids) &&
        isdefined(level.ezz_admin_xuids) &&
        isdefined(level.ezz_moderator_xuids) &&
        isdefined(level.ezz_helper_xuids),
        "14 XUID permission configuration loaded",
        "one or more role arrays are undefined"
    );

    resolved_by_xuid = resolve_connected_target(native_xuid_a);
    identity_test_assert(
        result,
        resolved_by_xuid.success && resolved_by_xuid.player == player,
        "15 connected target resolves by BOIII_XUID",
        "XUID selector did not return the expected entity"
    );

    client_selector = "#" + player GetEntityNumber();
    resolved_by_client = resolve_connected_target(client_selector);
    identity_test_assert(
        result,
        resolved_by_client.success && resolved_by_client.player == player,
        "16 connected target resolves by client number",
        "selector=" + client_selector
    );

    identity_test_assert(
        result,
        get_player_selector(player) == native_xuid_a,
        "17 internal selector prefers BOIII_XUID",
        "selector=" + get_player_selector(player)
    );

    identity_test_assert(
        result,
        has_dangerous_command_characters("unsafe;quit") &&
        has_dangerous_command_characters("unsafe\"quote") &&
        !has_dangerous_command_characters("safe_reason-123"),
        "18 command text safety filter",
        "separator or quote validation mismatch"
    );

    resolved_by_name = resolve_connected_target(original_name);
    identity_test_assert(
        result,
        resolved_by_name.success && resolved_by_name.player == player,
        "19 unambiguous display-name fallback",
        "display-name fallback did not resolve exactly once"
    );

    println(
        "^5[PinteMod Identity]^7 RESULT " +
        result.passed + "/" + result.total + " PASS" +
        " | failed=" + result.failed
    );
    println("^5============================================");

    identity_log(
        "GROUPED_SUITE | target=" + player.name +
        " | xuid=" + native_xuid_a +
        " | passed=" + result.passed +
        " | total=" + result.total +
        " | failed=" + result.failed
    );

    return result;
}

function cmd_ezzidentitytest(args)
{
    if (args.size <= 0 || toLower(args[0]) != "suite")
    {
        println("^3[PinteMod Identity]^7 Usage: ezzidentitytest suite [PlayerName|BOIII_XUID|ClientNumber]");
        return;
    }

    player = undefined;

    if (args.size >= 2)
    {
        query = identity_join_args(args, 1, args.size);
        player = identity_find_player(query);
    }
    else
    {
        players = GetPlayers();

        if (players.size > 0)
            player = players[0];
    }

    identity_run_grouped_suite(player);
}

function cmd_ezzidentityprobe(args)
{
    if (args.size <= 0)
    {
        println("^3[PinteMod Identity]^7 Usage: ezzidentityprobe <PlayerName|BOIII_XUID|ClientNumber>");
        return;
    }

    query = identity_join_args(args, 0, args.size);
    player = identity_find_player(query);

    if (!isdefined(player))
    {
        println("^1[PinteMod Identity]^7 Connected player not found: " + query);
        return;
    }

    raw_xuid_true = player getXuid(true);
    raw_xuid_false = player getXuid(false);
    raw_guid = player getGuid();
    normalized_true = normalize_xuid(raw_xuid_true);
    normalized_false = normalize_xuid(raw_xuid_false);

    println("^5===== PINTEMOD XUID RAW PROBE =====");
    println("^7Player: " + player.name + " | client=" + player GetEntityNumber());
    println("^7getXuid(true)  raw=" + identity_raw_text(raw_xuid_true) +
        " | length=" + identity_raw_length(raw_xuid_true) +
        " | normalized=" + normalized_true +
        " | accepted=" + is_valid_xuid(normalized_true));
    println("^7getXuid(false) raw=" + identity_raw_text(raw_xuid_false) +
        " | length=" + identity_raw_length(raw_xuid_false) +
        " | normalized=" + normalized_false +
        " | accepted=" + is_valid_xuid(normalized_false));
    println("^7getGuid()       raw=" + identity_log_guid_value(raw_guid) +
        " | length=" + identity_raw_length(raw_guid));
    println("^7Authoritative identity source: getXuid(false) hexadecimal output.");
    println("^5===================================");

    identity_log(
        "XUID_RAW_PROBE | display=" + player.name +
        " | client=" + player GetEntityNumber() +
        " | xuid_true=" + identity_raw_text(raw_xuid_true) +
        " | xuid_true_len=" + identity_raw_length(raw_xuid_true) +
        " | xuid_false=" + identity_raw_text(raw_xuid_false) +
        " | xuid_false_len=" + identity_raw_length(raw_xuid_false) +
        " | guid=" + identity_log_guid_value(raw_guid)
    );
}

function cmd_ezzidentitystatus(args)
{
    json = identity_load_roles_json(false);
    role_count = identity_json_int(json, "count", 0);

    println("^5===== PINTEMOD IDENTITY v2.0.2 =====");
    println("^7Identity kind: BOIII_XUID");
    println("^7Native API: player getXuid(false) [stable hexadecimal BOIII_XUID]");
    println("^7Diagnostic mirror: getXuid(true) [same 64-bit value, signed decimal]");
    println("^7Fail-closed authorization: enabled");
    println("^7Persistent XUID roles: " + role_count);
    println("^7Runtime XUID overrides: " + level.pintemod_identity_runtime_roles.size);
    println("^7Registry: boiii/scriptdata/pintemod/identity/roles.json");
    println("^7Log: boiii/scriptdata/" +
        ezz_admin_storage::get_active_log_root() + "/identity.log");
    println("^5=========================================");
}

autoexec function init()
{
    // BOIII may execute an auto-loaded custom script again when it is also #using-imported.
    // Guard initialization so commands and runtime state are registered exactly once.
    if (isdefined(level.pintemod_identity_initialized) && level.pintemod_identity_initialized)
        return;

    level.pintemod_identity_initialized = true;
    level.pintemod_identity_version = "2.0.2";
    level.pintemod_identity_kind = "BOIII_XUID";
    level.pintemod_identity_runtime_roles = [];
    level.pintemod_identity_roles_json = undefined;

    mkdir("pintemod");
    mkdir("pintemod/logs");
    mkdir("pintemod/identity");
    mkdir("pintemod/identity/test");

    addcommand("ezzidentity", ::cmd_ezzidentity);
    addcommand("ezzidentities", ::cmd_ezzidentities);
    addcommand("ezzidroles", ::cmd_ezzidroles);
    addcommand("ezzidsetrole", ::cmd_ezzidsetrole);
    addcommand("ezzidremoverole", ::cmd_ezzidremoverole);
    addcommand("ezzidentitytest", ::cmd_ezzidentitytest);
    addcommand("ezzidentitystatus", ::cmd_ezzidentitystatus);
    addcommand("ezzidentityprobe", ::cmd_ezzidentityprobe);

    identity_log_file("MODULE_LOADED | version=2.0.2 | kind=BOIII_XUID | native=getXuid(false)");
    level thread identity_bootstrap();

    println("^5[PinteMod]^7 Identity v2.0.2 loaded");
}
