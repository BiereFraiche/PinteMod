// ============================================================
// PinteMod — Routeur Chat v0.18.0
// Fichier : ezz_admin_chat.gsc
// Créé par BiereFraiche et ChatGPT
//
// Commandes Chat, permissions par rôle et routage sécurisé vers
// les commandes console validées du framework.
// Autorisation centralisée par BOIII_XUID; pseudo = affichage uniquement.
//
// Musiques spéciales et Events Margwa/Panzer intégrés.
// ============================================================

#using custom_scripts\ezz_admin_identity;
#using custom_scripts\ezz_admin_storage;
#using custom_scripts\ezz_admin_registry;
#using custom_scripts\ezz_admin_localization;
#using custom_scripts\ezz_admin_bans;
#using custom_scripts\ezz_admin_moderation;
#using custom_scripts\ezz_admin_health;
#using custom_scripts\ezz_admin_langstats;
#using custom_scripts\ezz_admin_map_audit;


function chat_append_file(path, text)
{
    if (ezz_admin_storage::append_managed_log(path, text))
        return true;

    println(
        "^1[PinteMod Chat]^7 WRITE_FAILED | path=" + path
    );

    return false;
}

autoexec function init()
{
    addcommand("ezzchatstatus", ::cmd_ezzchatstatus);

    level.ezz_chat_prefix = ".";
    level.ezz_chat_legacy_prefix = "!";
    level.ezz_chat_loaded = true;
    level.ezz_chat_version = "0.18.0";

    mkdir("pintemod");
    mkdir("pintemod/logs");
    mkdir("pintemod/logs/chat");
    chat_append_file("pintemod/logs/chat/commands.log", "=== PinteMod CHAT v0.18.0 loaded ===\n");

    level thread chat_bootstrap();

    println("^5[PinteMod]^7 Chat v0.18.0 loaded");
}

// ------------------------------------------------------------
// Bootstrap and player monitors
// ------------------------------------------------------------

function chat_bootstrap()
{
    // Allow the stock player system and the autonomous config module
    // to finish their initialization.
    wait 1;

    players = GetPlayers();

    for (i = 0; i < players.size; i++)
    {
        player = players[i];

        if (isdefined(player))
            chat_attach_player(player);
    }

    for (;;)
    {
        level waittill("connected", player);

        if (isdefined(player))
            chat_attach_player(player);
    }
}

function chat_attach_player(player)
{
    if (!isdefined(player))
        return;

    if (isdefined(player.ezz_chat_monitor_started) &&
        player.ezz_chat_monitor_started)
    {
        return;
    }

    player.ezz_chat_monitor_started = true;
    player.pintemod_chat_history = [];
    player.pintemod_last_chat_message = "";
    player.pintemod_last_chat_time = -10000;

    // BOIII can emit the same message through several notifications.
    // All three are observed, then deduplicated by chat_log_message().
    player thread chat_watch_say();
    player thread chat_watch_say_team();
    player thread chat_watch_chat();

    xuid = ezz_admin_identity::get_player_xuid(player);

    if (isdefined(level.pintemod_server_console_verbose) &&
        level.pintemod_server_console_verbose)
    {
        println(
            "^2[PinteMod]^7 Monitoring player: " + player.name +
            " | BOIII_XUID=" + xuid
        );
    }
}

function chat_watch_say()
{
    self endon("disconnect");

    for (;;)
    {
        self waittill("say", message);
        chat_handle_message(self, message, "say");
    }
}

function chat_watch_say_team()
{
    self endon("disconnect");

    for (;;)
    {
        self waittill("say_team", message);
        chat_handle_message(self, message, "say_team");
    }
}

function chat_watch_chat()
{
    self endon("disconnect");

    for (;;)
    {
        self waittill("chat", message);
        chat_handle_message(self, message, "chat");
    }
}

// ------------------------------------------------------------
// Permissions
// ------------------------------------------------------------

function chat_get_player_role(player)
{
    return ezz_admin_identity::get_player_role(player);
}

function chat_get_role_name(role)
{
    return ezz_admin_identity::get_role_name(role);
}

function chat_role_from_text(role_name)
{
    return ezz_admin_identity::role_from_text(role_name);
}

function chat_is_admin(player)
{
    return chat_get_player_role(player) > 0;
}

function chat_get_required_role(command_name)
{
    return ezz_admin_registry::chat_required_role(command_name);
}

function chat_has_permission(player, command_name)
{
    return chat_get_player_role(player) >=
           chat_get_required_role(command_name);
}

function chat_resolve_player(input_selector)
{
    resolved = ezz_admin_identity::resolve_connected_target(input_selector);

    if (!resolved.success)
        return undefined;

    return resolved.player;
}

function chat_target_selector(player)
{
    return ezz_admin_identity::get_player_selector(player);
}

function chat_get_optional_target(sender, tokens, target_index)
{
    if (tokens.size <= target_index)
        return sender;

    return chat_resolve_player(tokens[target_index]);
}

function chat_require_target(sender, input_selector)
{
    resolved = ezz_admin_identity::resolve_connected_target(input_selector);

    if (!resolved.success)
    {
        if (resolved.reason == "ambiguous_display_name")
        {
            sender iprintln(
                "^1[PinteMod]^7 Ambiguous name. Use XUID or client number."
            );
        }
        else
        {
            sender iprintln(
                "^1[PinteMod] Player not found: ^7" + input_selector
            );
        }

        return undefined;
    }

    return resolved.player;
}

// ------------------------------------------------------------
// Logging and console routing
// ------------------------------------------------------------

function chat_route(sender, console_command, display_command)
{
    if (!isdefined(sender))
        return;

    if (ezz_admin_identity::has_dangerous_command_characters(console_command))
    {
        sender iprintln("^1[PinteMod]^7 Unsafe command text rejected.");
        println(
            "^1[PinteMod Chat]^7 UNSAFE_COMMAND_REJECTED | actor=" +
            sender.name + " | display=" + display_command
        );
        return;
    }

    sender_xuid = ezz_admin_identity::get_player_xuid(sender);
    logged_xuid = ezz_admin_identity::identity_log_xuid_value(sender_xuid);

    println(
        "^2[PinteMod]^7 " + sender.name +
        " [" + logged_xuid + "] -> " + console_command
    );

    executecommand(console_command);

    // The destination command is responsible for reporting its result.
    sender iprintln("^5[PinteMod]^7 Request sent: ^3" + display_command);
}

function chat_deny(sender, command_text)
{
    sender_xuid = ezz_admin_identity::get_player_xuid(sender);
    sender iprintln("^1[PinteMod] Access denied");

    println(
        "^1[PinteMod] Unauthorized command from " +
        sender.name + " [" + sender_xuid + "]: " + command_text
    );

    chat_append_file(
        "pintemod/logs/chat/commands.log",
        "DENIED actor=" + sender.name +
        " actor_xuid=" + sender_xuid +
        " command=" + command_text + "\n"
    );
}


function chat_copy_without_first(values)
{
    result = [];

    if (!isdefined(values) || values.size <= 1)
        return result;

    for (i = 1; i < values.size; i++)
        result[result.size] = values[i];

    return result;
}

function chat_join_tokens(tokens, start_index)
{
    result = "";

    for (i = start_index; i < tokens.size; i++)
    {
        if (result != "")
            result = result + " ";

        result = result + tokens[i];
    }

    return result;
}

function chat_log_message(player, message, source_event, persist_message, record_history)
{
    now = GetTime();
    dedup_window = 250;
    history_size = 25;

    if (isdefined(level.pintemod_chat_dedup_window_ms))
        dedup_window = level.pintemod_chat_dedup_window_ms;

    if (isdefined(level.pintemod_chat_history_size))
        history_size = level.pintemod_chat_history_size;

    if (isdefined(player.pintemod_last_chat_message) &&
        player.pintemod_last_chat_message == message &&
        isdefined(player.pintemod_last_chat_time) &&
        now - player.pintemod_last_chat_time <= dedup_window)
    {
        return false;
    }

    player.pintemod_last_chat_message = message;
    player.pintemod_last_chat_time = now;

    player_xuid = ezz_admin_identity::get_player_xuid(player);
    entry = "[" + now + " ms][" + source_event + "] " +
        player.name + " [" + ezz_admin_identity::identity_log_xuid_value(player_xuid) + "]: " + message;

    persist_chat = persist_message &&
        isdefined(level.pintemod_log_chat_messages) &&
        level.pintemod_log_chat_messages;

    if (persist_chat)
    {
        chat_append_file(
            "pintemod/logs/chat/session.log",
            entry + "\n"
        );

        // BOIII already echoes the native [chat] line. Avoid a second
        // PinteMod copy unless explicit native-console diagnostics are enabled.
        if (isdefined(level.pintemod_server_console_verbose) &&
            level.pintemod_server_console_verbose)
        {
            println(
                "^5[PinteMod][CHAT]^7 " + player.name +
                " [" + ezz_admin_identity::identity_log_xuid_value(player_xuid) + "]: " + message
            );
        }
    }

    if (record_history)
    {
        if (!isdefined(player.pintemod_chat_history))
            player.pintemod_chat_history = [];

        player.pintemod_chat_history[
            player.pintemod_chat_history.size
        ] = entry;

        if (player.pintemod_chat_history.size > history_size)
        {
            player.pintemod_chat_history =
                chat_copy_without_first(player.pintemod_chat_history);
        }
    }

    return true;
}

// ------------------------------------------------------------
// Chat parser
// ------------------------------------------------------------


function chat_normalize_command_name(command_name)
{
    // Accept both:
    // .perk ...    -> perk
    // .ezzperk ... -> perk
    if (command_name.size > 3 &&
        GetSubStr(command_name, 0, 3) == "ezz")
    {
        command_name = GetSubStr(command_name, 3, command_name.size);
    }

    return ezz_admin_registry::canonical_chat_command(command_name);
}

function chat_handle_message(player, message, source_event)
{
    if (!isdefined(player) || !isdefined(message))
        return;

    if (message == "")
        return;

    prefix = GetSubStr(message, 0, 1);

    primary_prefix = prefix == level.ezz_chat_prefix;
    legacy_prefix =
        isdefined(level.ezz_chat_legacy_prefix) &&
        prefix == level.ezz_chat_legacy_prefix;
    is_command = primary_prefix || legacy_prefix;

    if (!is_command &&
        ezz_admin_moderation::should_block_chat(player, message))
    {
        return;
    }

    // Commands are audited in commands.log, not mixed into the normal
    // player Chat stream or vote-kick Chat evidence.
    if (!chat_log_message(
        player,
        message,
        source_event,
        !is_command,
        !is_command
    ))
    {
        return;
    }

    if (!is_command)
        return;

    if (message.size <= 1)
        return;

    command_line = GetSubStr(message, 1, message.size);

    if (command_line == "")
        return;

    tokens = StrTok(command_line, " ");

    if (tokens.size <= 0)
        return;

    command_name = chat_normalize_command_name(toLower(tokens[0]));

    if (!chat_has_permission(player, command_name))
    {
        chat_deny(player, command_line);
        player iprintln(
            "^3[PinteMod]^7 Required role: " +
            chat_get_role_name(chat_get_required_role(command_name))
        );
        return;
    }

    player_xuid = ezz_admin_identity::get_player_xuid(player);
    logged_xuid = ezz_admin_identity::identity_log_xuid_value(player_xuid);

    chat_append_file(
        "pintemod/logs/chat/commands.log",
        "actor=" + player.name +
        " actor_xuid=" + logged_xuid +
        " source=" + source_event +
        " command=" + command_line + "\n"
    );

    if (isdefined(level.pintemod_server_console_verbose) &&
        level.pintemod_server_console_verbose)
    {
        println(
            "^2[PinteMod]^7 Accepted " + source_event +
            " command from " + player.name +
            " [" + player_xuid + "]: " + command_line
        );
    }

    chat_dispatch(player, command_name, tokens);
}

// ------------------------------------------------------------
// Help
// ------------------------------------------------------------

function chat_show_help(player)
{
    role = chat_get_player_role(player);

    player iprintln("^5=== PinteMod CHAT v0.18.0 ===");
    player iprintln("^2Use .menu for Community actions and votes.");
    player iprintln("^7Language / Langue / Idioma: .lang fr|en|es|auto");
    player iprintln("^7Shortcuts: .spawn / .yes / .no / .votestatus");
    player iprintln("^7Optional: .votemap <map> / .voterestart");
    player iprintln("^7Optional: .votekick <player> [reason]");
    player iprintln("^7Ranks: .rank / .ranks / .records [1-4]");
    player iprintln("^7Easter Eggs: .eerecord / .eerecords [1-4]");
    player iprintln("^7Information: .players / .map / .round");

    if (role <= 0)
    {
        player iprintln("^3Public commands only. No gameplay advantage.");
        return;
    }

    player iprintln("^7.adminhelp - complete staff command list");
    player iprintln(
        "^6Your role: ^7" +
        chat_get_role_name(role)
    );
}

function chat_show_admin_help(player)
{
    player iprintln("^5=== PinteMod STAFF COMMANDS ===");
    player iprintln("^7.godmode / .ignore / .respawn");
    player iprintln("^7.save / .load / .tp [player]");
    player iprintln("^7.permissions / .perm [player]");
    player iprintln("^7.ban <player|xuid> [duration] [reason] / .unban <xuid>");
    player iprintln("^7.baninfo <player|xuid> / .banlist");
    player iprintln("^7.mute / .unmute / .kick / .history <target>");
    player iprintln("^7.health [full] / .mapaudit [full] / .langstats");

    if (chat_get_player_role(player) >= 4)
    {
        player iprintln("^6Owner only: ^7.revive [player]");
        player iprintln("^7.eetestrecords [1-4] - view isolated EE TEST Top 5");
    }
    player iprintln("^7.ammo / .points / .weapon / .papweapon [target]");
    player iprintln("^7.perk / .allperks / .clearperks / .removeperk");
    player iprintln("^7.powerup / .zombiecount / .lastzombie");
    player iprintln("^7.killzombies / .nextround / .skiprounds / .setround");
    player iprintln("^7.power / .pap / .unlock / .freezepowerups");
    player iprintln("^7.music / .boss / .margwa / .panzer / .eventstatus");
    player iprintln("^7.cancelvote - administrator only");
    player iprintln("^3Use .commands for public commands.");
}

function chat_show_players(player)
{
    players = GetPlayers();

    player iprintln("^3=== CONNECTED PLAYERS: " + players.size + " ===");

    for (i = 0; i < players.size; i++)
    {
        connected_player = players[i];

        if (!isdefined(connected_player))
            continue;

        player iprintln(
            "^7" + connected_player.name + " ^3[" +
            chat_get_role_name(
                chat_get_player_role(connected_player)
            ) + "]"
        );
    }
}

function chat_show_weapons(player)
{
    player iprintln("^3=== PinteMod WEAPON ALIASES ===");
    player iprintln("^7raygun, kn44, hvk, icr, manowar");
    player iprintln("^7kuda, vmp, krm, brecci, haymaker");
    player iprintln("^7argus, brm, dingo, gorgon, dredge");
    player iprintln("^7drakon, locus, svg");
    player iprintln("^3Usage: .weapon [player] <alias>");
}

function chat_show_perks(player)
{
    player iprintln("^3=== PinteMod PERK ALIASES ===");
    player iprintln("^7jug, quick, speed, doubletap");
    player iprintln("^7staminup, deadshot, mule");
    player iprintln("^7cherry, widows");
    player iprintln("^3.perk [player] <alias>");
    player iprintln("^3.allperks [player] / .clearperks [player]");
    player iprintln("^3.removeperk [player] <alias>");
}

function chat_show_powerups(player)
{
    player iprintln("^3=== PinteMod POWER-UP ALIASES ===");
    player iprintln("^7maxammo, instakill, doublepoints");
    player iprintln("^7firesale, carpenter, nuke");
    player iprintln("^7deathmachine, freeperk, shield");
    player iprintln("^3Usage: .powerup [player] <alias>");
    player iprintln("^7The pickup appears where the target is aiming");
}

function chat_count_living_ai()
{
    all_ai = GetAIArray();
    alive_count = 0;

    for (i = 0; i < all_ai.size; i++)
    {
        ai = all_ai[i];

        if (isdefined(ai) && IsAlive(ai))
            alive_count++;
    }

    return alive_count;
}

function chat_show_zombie_count(player)
{
    player iprintln("^3[PinteMod]^7 Living AI: " + chat_count_living_ai());
}

function chat_show_zombies(player)
{
    player iprintln("^3=== PinteMod ZOMBIES ===");
    player iprintln("^7.zombiecount");
    player iprintln("^7.lastzombie");
    player iprintln("^7.killzombies");
}

function chat_show_round(player)
{
    if (isdefined(level.round_number))
        player iprintln("^3[PinteMod]^7 Current round: " + level.round_number);
    else
        player iprintln("^1[PinteMod] Round number unavailable");

    player iprintln("^3[PinteMod]^7 Living AI: " + chat_count_living_ai());

    if (isdefined(level.zombie_total))
        player iprintln("^3[PinteMod]^7 Spawn queue: " + level.zombie_total);
}

function chat_show_rounds(player)
{
    player iprintln("^3=== PinteMod ROUNDS ===");
    player iprintln("^7.round");
    player iprintln("^7.nextround");
    player iprintln("^7.skiprounds <count>");
    player iprintln("^7.setround <future round>");
}

function chat_get_map_name()
{
    return toLower(GetDvarString("mapname"));
}

function chat_get_map_display_name(map_name)
{
    return ezz_admin_registry::get_map_display_name(map_name);
}

function chat_get_power_profile(map_name)
{
    switch (map_name)
    {
        case "zm_prototype":
            return "Not applicable";

        case "zm_zod":
            return "Local Beast-mode switches";

        case "zm_island":
            return "Dual generator system";

        case "zm_genesis":
            return "Corruption engine system";

        case "zm_tomb":
            return "Six generators";

        case "zm_factory":
        case "zm_castle":
        case "zm_stalingrad":
        case "zm_asylum":
        case "zm_sumpf":
        case "zm_theater":
        case "zm_cosmodrome":
        case "zm_temple":
        case "zm_moon":
            return "Standard global power";
    }

    return "Unknown / custom";
}

function chat_get_pap_profile(map_name)
{
    switch (map_name)
    {
        case "zm_prototype":
        case "zm_asylum":
        case "zm_sumpf":
            return "No native Pack-a-Punch";

        case "zm_zod":
            return "Ritual access";

        case "zm_factory":
            return "Three teleporter links";

        case "zm_castle":
            return "Map-specific access";

        case "zm_island":
            return "Machine construction";

        case "zm_stalingrad":
            return "Dragon transport";

        case "zm_genesis":
            return "Apothicon access";

        case "zm_theater":
            return "Teleporter access";

        case "zm_cosmodrome":
            return "Rocket launch";

        case "zm_temple":
            return "Pressure plates";

        case "zm_moon":
            return "Area 51";

        case "zm_tomb":
            return "Six generators";
    }

    return "Unknown / custom";
}

function chat_show_map(player)
{
    map_name = chat_get_map_name();

    player iprintln(
        "^5[PinteMod]^7 " +
        chat_get_map_display_name(map_name) +
        " ^3(" + map_name + ")"
    );

    if (isdefined(level.round_number))
        player iprintln("^5[PinteMod]^7 Round: " + level.round_number);

    player iprintln("^7.mapstatus for the complete profile");
}

function chat_show_map_status(player)
{
    map_name = chat_get_map_name();

    player iprintln("^5=== PinteMod MAP PROFILE ===");
    player iprintln("^7Name: " + chat_get_map_display_name(map_name));
    player iprintln("^7Internal ID: " + map_name);
    player iprintln("^7Power: " + chat_get_power_profile(map_name));
    player iprintln("^7Pack-a-Punch: " + chat_get_pap_profile(map_name));
    player iprintln("^7Unlock: standard doors/debris");
    player iprintln("^3Quest-specific logic remains protected");
}

function chat_show_official_maps(player)
{
    player iprintln("^5=== BO3 CORE / DLC ===");
    player iprintln("^7zm_zod, zm_factory, zm_castle");
    player iprintln("^7zm_island, zm_stalingrad, zm_genesis");
    player iprintln("^5=== ZOMBIES CHRONICLES ===");
    player iprintln("^7zm_prototype, zm_asylum, zm_sumpf");
    player iprintln("^7zm_theater, zm_cosmodrome, zm_temple");
    player iprintln("^7zm_moon, zm_tomb");
}

function chat_show_wonderweapons(player)
{
    map_name = chat_get_map_name();

    player iprintln(
        "^5=== " +
        chat_get_map_display_name(map_name) +
        " SPECIAL WEAPONS ==="
    );

    switch (map_name)
    {
        case "zm_zod":
            player iprintln("^7apothicon, apothiconup, arnies");
            player iprintln("^7annihilator, apothiconsword, keepersword");
            return;

        case "zm_factory":
            player iprintln("^7wunderwaffe, wunderwaffeup, annihilator");
            return;

        case "zm_castle":
            player iprintln("^7bow, stormbow, firebow, wolfbow, voidbow");
            player iprintln("^7ragnarok");
            return;

        case "zm_island":
            player iprintln("^7kt4, masamune, skull");
            return;

        case "zm_stalingrad":
            player iprintln("^7raygunmk3, raygunmk3up");
            player iprintln("^7gauntlet, dragonstrike");
            return;

        case "zm_genesis":
            player iprintln("^7apothicon, thundergun, arnies");
            player iprintln("^7ragnarok, katana");
            return;

        case "zm_prototype":
            player iprintln("^7thundergun");
            return;

        case "zm_asylum":
        case "zm_sumpf":
            player iprintln("^7wunderwaffe");
            return;

        case "zm_theater":
            player iprintln("^7thundergun");
            return;

        case "zm_cosmodrome":
            player iprintln("^7thundergun, gersh, dolls");
            return;

        case "zm_temple":
            player iprintln("^7babygun, babygunup, monkey");
            return;

        case "zm_moon":
            player iprintln("^7wavegun, wavegunup, qed, gersh");
            return;

        case "zm_tomb":
            player iprintln("^7windstaff, icestaff, lightningstaff, firestaff");
            player iprintln("^7windstaffup, icestaffup");
            player iprintln("^7lightningstaffup, firestaffup");
            player iprintln("^7gstrike, oneinch, elemental fists");
            return;
    }

    player iprintln("^3No official special catalog for this map");
}

function chat_show_weapon_status_notice(player, alias)
{
    player iprintln("^5[PinteMod]^7 Checking alias: " + alias);
    player iprintln("^3Detailed availability is written to server console");
    player iprintln("^7Use .weapon " + alias + " to attempt a safe native give");
}

// ------------------------------------------------------------
// Dispatch helpers
// ------------------------------------------------------------


function chat_dispatch_simple_target(player, tokens, console_name)
{
    target = chat_get_optional_target(player, tokens, 1);

    if (!isdefined(target))
    {
        player iprintln("^1[PinteMod]^7 Player not found or ambiguous.");
        return;
    }

    chat_route(
        player,
        console_name + " " + chat_target_selector(target),
        tokens[0] + " " + target.name
    );
}

function chat_dispatch_item_target(player, tokens, console_name, usage_text)
{
    target = undefined;
    item_alias = "";

    if (tokens.size == 2)
    {
        target = player;
        item_alias = toLower(tokens[1]);
    }
    else if (tokens.size >= 3)
    {
        target = chat_require_target(player, tokens[1]);

        if (!isdefined(target))
            return;

        item_alias = toLower(tokens[2]);
    }
    else
    {
        player iprintln("^3[PinteMod]^7 Usage: " + usage_text);
        return;
    }

    chat_route(
        player,
        console_name + " " + chat_target_selector(target) + " " + item_alias,
        tokens[0] + " " + target.name + " " + item_alias
    );
}

// ------------------------------------------------------------
// Command allowlist
// ------------------------------------------------------------


function chat_show_permissions(player)
{
    xuid = ezz_admin_identity::get_player_xuid(player);
    source = ezz_admin_identity::get_player_role_source(player);

    player iprintln("^5=== PinteMod PERMISSION LEVELS ===");
    player iprintln("^7owner     - complete access and role management");
    player iprintln("^7admin     - maps, rounds and destructive commands");
    player iprintln("^7moderator - gameplay tools, weapons, perks, powerups");
    player iprintln("^7helper    - diagnostics, spawn, save/load and teleport");
    player iprintln(
        "^6Your role: ^7" +
        chat_get_role_name(chat_get_player_role(player))
    );
    player iprintln("^7Identity: BOIII_XUID " + xuid);
    player iprintln("^7Role source: " + source);
}

function chat_show_player_permission(sender, input_selector)
{
    target = chat_require_target(sender, input_selector);

    if (!isdefined(target))
        return;

    target_xuid = ezz_admin_identity::get_player_xuid(target);
    target_source = ezz_admin_identity::get_player_role_source(target);

    sender iprintln(
        "^5[PinteMod]^7 " + target.name +
        " role: ^6" + chat_get_role_name(chat_get_player_role(target))
    );
    sender iprintln(
        "^7BOIII_XUID: " + target_xuid +
        " | client=" + target GetEntityNumber() +
        " | source=" + target_source
    );
}

function chat_set_runtime_role(sender, target_selector, role_name)
{
    target = chat_require_target(sender, target_selector);

    if (!isdefined(target))
        return;

    role = chat_role_from_text(role_name);

    if (role < 0)
    {
        sender iprintln("^1[PinteMod]^7 Unknown role: " + role_name);
        return;
    }

    if (target == sender && role < 4)
    {
        sender iprintln("^3[PinteMod]^7 Owner cannot demote themselves");
        return;
    }

    target_xuid = ezz_admin_identity::get_player_xuid(target);
    sender_xuid = ezz_admin_identity::get_player_xuid(sender);

    if (!ezz_admin_identity::set_runtime_role_for_player(
        target,
        role,
        sender.name
    ))
    {
        sender iprintln(
            "^1[PinteMod]^7 Stable BOIII_XUID unavailable for " +
            target.name
        );
        return;
    }

    sender iprintln(
        "^2[PinteMod]^7 " + target.name +
        " is now " + chat_get_role_name(role) +
        " ^7(XUID-bound)"
    );

    target iprintln(
        "^5[PinteMod]^7 Runtime XUID role: ^6" +
        chat_get_role_name(role)
    );

    chat_append_file(
        "pintemod/logs/chat/commands.log",
        "ROLE actor=" + sender.name +
        " actor_xuid=" + ezz_admin_identity::identity_log_xuid_value(sender_xuid) +
        " target=" + target.name +
        " target_xuid=" + ezz_admin_identity::identity_log_xuid_value(target_xuid) +
        " role=" + chat_get_role_name(role) + "\n"
    );
}

function chat_route_navigation_target(sender, tokens, console_name)
{
    target = sender;

    if (tokens.size >= 2)
    {
        target = chat_require_target(sender, tokens[1]);

        if (!isdefined(target))
            return;

        // Helpers can use navigation on themselves only.
        if (target != sender && chat_get_player_role(sender) < 2)
        {
            sender iprintln("^1[PinteMod]^7 Moderator role required for others");
            return;
        }
    }

    chat_route(
        sender,
        console_name + " " + chat_target_selector(target),
        tokens[0] + " " + target.name
    );
}

function chat_route_aim_teleport(sender, tokens)
{
    target = sender;

    if (tokens.size >= 2)
    {
        target = chat_require_target(sender, tokens[1]);

        if (!isdefined(target))
            return;

        if (target != sender && chat_get_player_role(sender) < 2)
        {
            sender iprintln("^1[PinteMod]^7 Moderator role required for others");
            return;
        }
    }

    chat_route(
        sender,
        "ezztp " + chat_target_selector(sender) + " " +
            chat_target_selector(target),
        tokens[0] + " " + target.name
    );
}


function chat_dispatch(player, command_name, tokens)
{
    switch (command_name)
    {
        // Diagnostics
        case "ping":
            player iprintln("^2[PinteMod] Chat parser OK");
            println("^2[PinteMod]^7 Ping from " + player.name);
            return;

        case "help":
        case "commands":
            chat_show_help(player);
            return;

        case "adminhelp":
            chat_show_admin_help(player);
            return;

        case "players":
            chat_show_players(player);
            return;

        case "health":
            if (tokens.size >= 2 && toLower(tokens[1]) == "full")
                ezz_admin_health::health_print_full();
            else
                ezz_admin_health::health_print_short();
            return;

        case "mapaudit":
            ezz_admin_map_audit::map_audit_print(
                tokens.size >= 2 && toLower(tokens[1]) == "full"
            );
            return;

        case "langstats":
            mode = "all";
            if (tokens.size >= 2) mode = toLower(tokens[1]);

            if (mode == "reset")
            {
                if (tokens.size >= 3 && toLower(tokens[2]) == "prepare")
                    ezz_admin_langstats::langstats_prepare_reset(player);
                else if (tokens.size >= 4 && toLower(tokens[2]) == "confirm")
                    ezz_admin_langstats::langstats_confirm_reset(player, tokens[3]);
                else
                    player iprintln("^7.langstats reset prepare|confirm <token>");
                return;
            }

            ezz_admin_langstats::langstats_show(player, mode);
            return;

        case "lang":
            if (tokens.size < 2)
            {
                ezz_admin_localization::show_player_language(player);
                return;
            }

            ezz_admin_localization::set_player_language_choice(
                player,
                tokens[1]
            );
            return;

        case "rank":
            chat_route(
                player,
                "ezzrank " + chat_target_selector(player),
                ".rank"
            );
            return;

        case "ranks":
            chat_route(
                player,
                "ezzranks " + chat_target_selector(player),
                ".ranks"
            );
            return;

        case "record":
        case "records":
            if (tokens.size >= 2)
            {
                team_size = int(tokens[1]);

                if (team_size < 1 || team_size > 4)
                {
                    player iprintln("^3[PinteMod]^7 Usage: .records [1-4]");
                    return;
                }

                chat_route(
                    player,
                    "ezzrecords " + chat_target_selector(player) + " " + team_size,
                    ".records " + team_size
                );
                return;
            }

            chat_route(
                player,
                "ezzrecords " + chat_target_selector(player),
                ".records"
            );
            return;

        case "eerecord":
            chat_route(
                player,
                "ezzeerecord " + chat_target_selector(player),
                ".eerecord"
            );
            return;

        case "eerecords":
            if (tokens.size >= 2)
            {
                team_size = int(tokens[1]);

                if (team_size < 1 || team_size > 4)
                {
                    player iprintln(
                        "^3[PinteMod]^7 Usage: .eerecords [1-4]"
                    );
                    return;
                }

                chat_route(
                    player,
                    "ezzeerecords " + chat_target_selector(player) + " " + team_size,
                    ".eerecords " + team_size
                );
                return;
            }

            chat_route(
                player,
                "ezzeerecords " + chat_target_selector(player),
                ".eerecords"
            );
            return;

        case "eetestrecords":
        case "ezzeetestrecords":
            if (tokens.size >= 2)
            {
                team_size = int(tokens[1]);

                if (team_size < 1 || team_size > 4)
                {
                    player iprintln(
                        "^3[PinteMod]^7 Usage: .eetestrecords [1-4]"
                    );
                    return;
                }

                chat_route(
                    player,
                    "ezzeetestrecords " + chat_target_selector(player) + " " + team_size,
                    ".eetestrecords " + team_size
                );
                return;
            }

            chat_route(
                player,
                "ezzeetestrecords " + chat_target_selector(player),
                ".eetestrecords"
            );
            return;

        // Permissions
        case "permissions":
        case "permission":
            chat_show_permissions(player);
            return;

        case "perm":
            if (tokens.size < 2)
                chat_show_permissions(player);
            else
                chat_show_player_permission(player, tokens[1]);
            return;

        case "setrole":
            if (tokens.size < 3)
            {
                player iprintln("^3[PinteMod]^7 Usage: .setrole <player> <role>");
                return;
            }

            chat_set_runtime_role(player, tokens[1], tokens[2]);
            return;

        case "removerole":
            if (tokens.size < 2)
            {
                player iprintln("^3[PinteMod]^7 Usage: .removerole <player>");
                return;
            }

            chat_set_runtime_role(player, tokens[1], "user");
            return;

        // Persistent XUID moderation
        case "ban":
            if (tokens.size < 2)
            {
                player iprintln("^3[PinteMod Ban]^7 Usage: .ban <player|xuid> [30m|2h|7d|4w|perm] [reason]");
                return;
            }

            duration = "perm";
            reason_start = 2;

            if (tokens.size >= 3 && ezz_admin_bans::bans_duration_is_valid(tokens[2]))
            {
                duration = tokens[2];
                reason_start = 3;
            }

            reason = "";
            for (ban_token = reason_start; ban_token < tokens.size; ban_token++)
            {
                if (reason != "")
                    reason = reason + " ";

                reason = reason + tokens[ban_token];
            }

            ezz_admin_bans::request_ban(
                player,
                tokens[1],
                duration,
                reason
            );
            return;

        case "unban":
            if (tokens.size < 2)
            {
                player iprintln("^3[PinteMod Ban]^7 Usage: .unban <player|xuid>");
                return;
            }

            ezz_admin_bans::request_unban(player, tokens[1]);
            return;

        case "baninfo":
            if (tokens.size < 2)
            {
                player iprintln("^3[PinteMod Ban]^7 Usage: .baninfo <player|xuid>");
                return;
            }

            ezz_admin_bans::show_ban_info(player, tokens[1]);
            return;

        case "banlist":
            ezz_admin_bans::show_ban_list(player);
            return;

        case "mute":
            if (tokens.size < 2)
            {
                player iprintln("^3[PinteMod]^7 Usage: .mute <player|xuid|client> [reason]");
                return;
            }
            ezz_admin_moderation::request_mute(
                player, tokens[1], chat_join_tokens(tokens, 2)
            );
            return;

        case "unmute":
            if (tokens.size < 2)
            {
                player iprintln("^3[PinteMod]^7 Usage: .unmute <player|xuid|client>");
                return;
            }
            ezz_admin_moderation::request_unmute(player, tokens[1]);
            return;

        case "kick":
            if (tokens.size < 2)
            {
                player iprintln("^3[PinteMod]^7 Usage: .kick <player|xuid|client> [reason]");
                return;
            }
            ezz_admin_moderation::request_kick(
                player, tokens[1], chat_join_tokens(tokens, 2)
            );
            return;

        case "history":
            if (tokens.size < 2)
            {
                player iprintln("^3[PinteMod]^7 Usage: .history <player|xuid|client>");
                return;
            }
            ezz_admin_moderation::show_history(player, tokens[1]);
            return;

        // Musique spéciale de la map
        case "music":
            mode = "1";

            if (tokens.size >= 2)
                mode = toLower(tokens[1]);

            if (mode == "stop" || mode == "off")
            {
                chat_route(
                    player,
                    "ezzmusicstopall",
                    ".music stop"
                );
                return;
            }

            if (mode == "status")
            {
                chat_route(
                    player,
                    "ezzmusicstatus",
                    ".music status"
                );
                return;
            }

            if (mode == "states")
            {
                chat_route(
                    player,
                    "ezzmusicstates",
                    ".music states"
                );
                return;
            }

            chat_route(
                player,
                "ezzmusicplayall " + mode,
                ".music " + mode
            );
            return;

        case "musicstatus":
            chat_route(
                player,
                "ezzmusicstatus",
                ".musicstatus"
            );
            return;

        // Events
        case "boss":
            target = player;

            if (tokens.size >= 2)
            {
                target = chat_require_target(player, tokens[1]);

                if (!isdefined(target))
                    return;
            }

            chat_route(
                player,
                "ezzspawnboss " + chat_target_selector(target),
                ".boss " + target.name
            );
            return;

        case "margwa":
            target = player;

            if (tokens.size >= 2)
            {
                target = chat_require_target(player, tokens[1]);

                if (!isdefined(target))
                    return;
            }

            chat_route(
                player,
                "ezzspawnmargwa " + chat_target_selector(target),
                ".margwa " + target.name
            );
            return;

        case "panzer":
            target = player;

            if (tokens.size >= 2)
            {
                target = chat_require_target(player, tokens[1]);

                if (!isdefined(target))
                    return;
            }

            chat_route(
                player,
                "ezzspawnpanzer " + chat_target_selector(target),
                ".panzer " + target.name
            );
            return;

        case "eventstatus":
            chat_route(
                player,
                "ezzeventstatus",
                ".eventstatus"
            );
            return;

        // Navigation
        case "save":
            chat_route_navigation_target(player, tokens, "ezzsave");
            return;

        case "load":
            chat_route_navigation_target(player, tokens, "ezzload");
            return;

        case "tp":
        case "teleport":
            chat_route_aim_teleport(player, tokens);
            return;

        // Core player commands
        case "god":
        case "godmode":
            chat_dispatch_simple_target(player, tokens, "godmode");
            return;

        case "ignore":
            chat_dispatch_simple_target(player, tokens, "ignore");
            return;

        case "respawn":
            chat_dispatch_simple_target(player, tokens, "ezzspawn");
            return;

        case "revive":
            chat_dispatch_simple_target(player, tokens, "ezzrevive");
            return;

        case "ammo":
        case "maxammo":
            chat_dispatch_simple_target(player, tokens, "ammo");
            return;

        case "maxpoints":
            chat_dispatch_simple_target(player, tokens, "maxpoints");
            return;

        case "points":
            if (tokens.size == 2)
            {
                chat_route(
                    player,
                    "points " + chat_target_selector(player) + " " + tokens[1],
                    ".points " + player.name + " " + tokens[1]
                );
                return;
            }

            if (tokens.size >= 3)
            {
                target = chat_require_target(player, tokens[1]);

                if (!isdefined(target))
                    return;

                chat_route(
                    player,
                    "points " + chat_target_selector(target) + " " + tokens[2],
                    ".points " + target.name + " " + tokens[2]
                );
                return;
            }

            player iprintln("^3[PinteMod]^7 Usage: .points [player] <amount>");
            return;

        // Weapons
        case "weapons":
            chat_show_weapons(player);
            return;

        case "wonderweapons":
        case "wonderweapon":
        case "wonders":
            chat_show_wonderweapons(player);
            return;

        case "weaponstatus":
            if (tokens.size < 2)
            {
                player iprintln("^3[PinteMod]^7 Usage: .weaponstatus <alias>");
                return;
            }

            chat_show_weapon_status_notice(player, toLower(tokens[1]));
            chat_route(
                player,
                "ezzweaponstatus " + toLower(tokens[1]),
                ".weaponstatus " + toLower(tokens[1])
            );
            return;

        case "weapon":
        case "gun":
            chat_dispatch_item_target(
                player,
                tokens,
                "ezzweapon",
                ".weapon [player] <alias>"
            );
            return;

        case "papweapon":
        case "packweapon":
            chat_dispatch_simple_target(player, tokens, "ezzpapweapon");
            return;

        case "hasweapon":
            chat_dispatch_item_target(
                player,
                tokens,
                "ezzhasweapon",
                ".hasweapon [player] <alias>"
            );
            return;

        // Perks
        case "perks":
            chat_show_perks(player);
            return;

        case "perk":
            chat_dispatch_item_target(
                player,
                tokens,
                "ezzperk",
                ".perk [player] <alias>"
            );
            return;

        case "hasperk":
            chat_dispatch_item_target(
                player,
                tokens,
                "ezzhasperk",
                ".hasperk [player] <alias>"
            );
            return;

        case "allperks":
            target = chat_get_optional_target(player, tokens, 1);

            if (!isdefined(target))
            {
                player iprintln("^1[PinteMod] Player not found: ^7" + tokens[1]);
                return;
            }

            chat_route(
                player,
                "ezzallperks " + chat_target_selector(target),
                ".allperks " + target.name
            );
            return;

        case "clearperks":
            target = chat_get_optional_target(player, tokens, 1);

            if (!isdefined(target))
            {
                player iprintln("^1[PinteMod] Player not found: ^7" + tokens[1]);
                return;
            }

            chat_route(
                player,
                "ezzclearperks " + chat_target_selector(target),
                ".clearperks " + target.name
            );
            return;

        case "removeperk":
            chat_dispatch_item_target(
                player,
                tokens,
                "ezzremoveperk",
                ".removeperk [player] <alias>"
            );
            return;

        // Power-Ups use the target player's aim
        case "powerups":
            chat_show_powerups(player);
            return;

        case "powerup":
            chat_dispatch_item_target(
                player,
                tokens,
                "ezzpowerup",
                ".powerup [player] <alias>"
            );
            return;

        // Zombies
        case "zombies":
            chat_show_zombies(player);
            return;

        case "zombiecount":
            chat_show_zombie_count(player);
            return;

        case "roundinfo":
            chat_show_round(player);
            return;

        case "lastzombie":
            chat_route(player, "ezzlastzombie", ".lastzombie");
            return;

        case "killzombies":
            chat_route(player, "ezzkillzombies", ".killzombies");
            return;

        // Rounds
        case "rounds":
            chat_show_rounds(player);
            return;

        case "round":
            chat_show_round(player);
            return;

        case "nextround":
            chat_route(player, "ezznextround", ".nextround");
            return;

        case "skiprounds":
            if (tokens.size < 2)
            {
                player iprintln("^3[PinteMod]^7 Usage: .skiprounds <count>");
                return;
            }

            chat_route(
                player,
                "ezzskiprounds " + tokens[1],
                ".skiprounds " + tokens[1]
            );
            return;

        case "setround":
            if (tokens.size < 2)
            {
                player iprintln("^3[PinteMod]^7 Usage: .setround <target>");
                return;
            }

            chat_route(
                player,
                "ezzsetround " + tokens[1],
                ".setround " + tokens[1]
            );
            return;


        case "freezepowerups":
            mode = "toggle";

            if (tokens.size >= 2)
                mode = toLower(tokens[1]);

            chat_route(
                player,
                "ezzfreezepowerups " + mode,
                ".freezepowerups " + mode
            );
            return;

        // Community v1.2 public commands
        // .spawn is the public late-join command. .join remains an alias.
        case "spawn":
        case "join":
            chat_route(
                player,
                "ezzjoin " + chat_target_selector(player),
                ".spawn"
            );
            return;

        case "votemap":
            if (tokens.size < 2)
            {
                player iprintln("^3[PinteMod]^7 Usage: .votemap <map>");
                return;
            }

            chat_route(
                player,
                "ezzvotemap " + chat_target_selector(player) + " " + tokens[1],
                ".votemap " + tokens[1]
            );
            return;

        case "voterestart":
            chat_route(
                player,
                "ezzvoterestart " + chat_target_selector(player),
                ".voterestart"
            );
            return;

        case "yes":
            chat_route(player, "ezzyes " + chat_target_selector(player), ".yes");
            return;

        case "no":
            chat_route(player, "ezzno " + chat_target_selector(player), ".no");
            return;

        case "votestatus":
            chat_route(
                player,
                "ezzvotestatus " + chat_target_selector(player),
                ".votestatus"
            );
            return;

        case "votekick":
            if (tokens.size < 2)
            {
                player iprintln(
                    "^3[PinteMod]^7 Usage: " +
                    ".votekick <PlayerName|XUID|ClientNumber> [reason]"
                );
                return;
            }

            target = chat_require_target(player, tokens[1]);

            if (!isdefined(target))
                return;

            reason = chat_join_tokens(tokens, 2);

            if (ezz_admin_identity::has_dangerous_command_characters(reason))
            {
                player iprintln(
                    "^1[PinteMod]^7 Unsafe characters in vote-kick reason."
                );
                return;
            }

            kick_command =
                "ezzvotekick " + chat_target_selector(player) + " " +
                chat_target_selector(target);

            if (reason != "")
                kick_command = kick_command + " " + reason;

            chat_route(player, kick_command, ".votekick " + target.name);
            return;

        case "cancelvote":
            chat_route(
                player,
                "ezzcancelvote " + chat_target_selector(player),
                ".cancelvote"
            );
            return;

        case "clearnextmap":
            chat_route(
                player,
                "ezzclearnextmap " + chat_target_selector(player),
                ".clearnextmap"
            );
            return;

        // Validated server-side HUD menu
        case "menu":
            chat_route(
                player,
                "ezzmenu " + chat_target_selector(player),
                ".menu"
            );
            return;

        // Maps / Power / Pack-a-Punch / Unlock
        case "map":
            chat_show_map(player);
            return;

        case "mapstatus":
            chat_show_map_status(player);
            return;

        case "maps":
            chat_show_official_maps(player);
            return;

        case "power":
            chat_route(player, "ezzpower", ".power");
            return;

        case "powerstatus":
            player iprintln(
                "^5[PinteMod]^7 Power profile: " +
                chat_get_power_profile(chat_get_map_name())
            );
            chat_route(player, "ezzpowerstatus", ".powerstatus");
            return;

        case "pap":
            chat_route(player, "ezzpap", ".pap");
            return;

        case "papstatus":
            player iprintln(
                "^5[PinteMod]^7 PaP profile: " +
                chat_get_pap_profile(chat_get_map_name())
            );
            chat_route(player, "ezzpapstatus", ".papstatus");
            return;

        case "unlock":
            chat_route(player, "ezzunlock", ".unlock");
            return;

        case "unlockstatus":
            player iprintln("^5[PinteMod]^7 Checking standard doors/debris");
            chat_route(player, "ezzunlockstatus", ".unlockstatus");
            return;

    }

    player iprintln("^1[PinteMod] Unknown command: ^7." + command_name);
    player iprintln("^3Type .help for the command list");
}

// ------------------------------------------------------------
// Dedicated console diagnostic
// ------------------------------------------------------------

function cmd_ezzchatstatus(args)
{
    println("^5========== PinteMod CHAT v0.18.0 ==========");
    println("^7Primary prefix: " + level.ezz_chat_prefix);

    if (isdefined(level.ezz_chat_legacy_prefix))
        println("^7Legacy prefix: " + level.ezz_chat_legacy_prefix);

    players = GetPlayers();
    println("^7Connected players: " + players.size);

    for (i = 0; i < players.size; i++)
    {
        player = players[i];

        if (!isdefined(player))
            continue;

        role = chat_get_player_role(player);

        xuid = ezz_admin_identity::get_player_xuid(player);
        source = ezz_admin_identity::get_player_role_source(player);

        if (role > 0)
        {
            println(
                "^2" + toUpper(chat_get_role_name(role)) +
                ": " + player.name +
                " | xuid=" + xuid +
                " | source=" + source
            );
        }
        else
        {
            println(
                "^7USER: " + player.name +
                " | xuid=" + xuid +
                " | source=" + source
            );
        }
    }

    println("^7Chat log: boiii/scriptdata/" +
        ezz_admin_storage::get_active_log_root() +
        "/chat/session.log");
    println("^3Runtime .setrole changes are XUID-bound and reset on map/restart");
    println("^5=======================================");
}
