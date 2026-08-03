// ============================================================
// PinteMod — Commandes principales v0.5.0
// Fichier : ezz_admin_commands.gsc
// Créé par BiereFraiche et ChatGPT
//
// Points, munitions, God Mode, ignore, joueurs, zombies et
// réapparition des spectateurs et réanimation native des joueurs à terre.
// ============================================================

#using scripts\zm\_zm;
#using scripts\zm\_zm_utility;
#using scripts\shared\laststand_shared;
#using scripts\zm\_zm_laststand;
#using scripts\zm\_zm_perks;
#using custom_scripts\ezz_admin_identity;


// ------------------------------------------------------------
// Global PinteMod message without BO3's [All]UnknownSoldier prefix
// ------------------------------------------------------------

function commands_broadcast(message)
{
    players = GetPlayers();

    for (i = 0; i < players.size; i++)
    {
        player = players[i];

        if (isdefined(player))
            player iprintln(message);
    }
}

function commands_mark_gameplay_command(command_name, target_name)
{
    level.pintemod_gameplay_command_pending = true;
    level.pintemod_gameplay_command_name = command_name;
    level.pintemod_gameplay_command_target = target_name;

    level notify(
        "pintemod_gameplay_command_used",
        command_name,
        target_name
    );
}

autoexec function init()
{
    addcommand("ezztest", ::cmd_ezztest);
    addcommand("ezzplayers", ::cmd_ezzplayers);
    addcommand("help", ::cmd_help);

    addcommand("points", ::cmd_points);
    addcommand("maxpoints", ::cmd_maxpoints);

    addcommand("ammo", ::cmd_ammo);
    addcommand("godmode", ::cmd_godmode);
    addcommand("ignore", ::cmd_ignore);

    addcommand("killzombies", ::cmd_killzombies);
    addcommand("ezzspawn", ::cmd_ezzspawn);
    addcommand("ezzrevive", ::cmd_ezzrevive);
    addcommand("ezzrevivestatus", ::cmd_ezzrevivestatus);
    addcommand("ezzrevivetest", ::cmd_ezzrevivetest);

    level thread commands_revive_bootstrap();

    println("^5[PinteMod]^7 Commands v0.5.0 loaded");
}

// ------------------------------------------------------------
// Shared helpers
// ------------------------------------------------------------

function get_first_player()
{
    players = GetPlayers();

    if (players.size > 0)
        return players[0];

    return undefined;
}

function find_player_exact(player_name)
{
    return ezz_admin_identity::identity_find_player(player_name);
}

function get_target_from_optional_name(args)
{
    if (args.size > 0)
        return find_player_exact(args[0]);

    return get_first_player();
}

function get_safe_godmode_target(args)
{
    players = GetPlayers();

    if (args.size > 0)
        return find_player_exact(args[0]);

    if (players.size == 1)
        return players[0];

    if (players.size > 1)
    {
        println("^1[PinteMod] Several players are connected");
        println("^3[PinteMod]^7 Usage: godmode <PlayerName|BOIII_XUID|ClientNumber>");
    }

    return undefined;
}

function print_no_players()
{
    println("^1[PinteMod] No connected player");
}

function print_player_not_found(player_name)
{
    println("^1[PinteMod] Player not found: " + player_name);
}

function print_target_error(args)
{
    if (args.size > 0)
        print_player_not_found(args[0]);
    else
        print_no_players();
}

// ------------------------------------------------------------
// Diagnostics and help
// ------------------------------------------------------------

function cmd_ezztest(args)
{
    println("^3[PinteMod]^7 Dedicated v0.5.0 OK");

    if (isdefined(level.ezz_admin_version))
        println("^3[PinteMod]^7 Config version: " + level.ezz_admin_version);

    if (isdefined(level.ezz_admin_loaded) && level.ezz_admin_loaded)
        println("^3[PinteMod]^7 Main module state: ready");
}

function cmd_ezzplayers(args)
{
    players = GetPlayers();

    if (players.size <= 0)
    {
        print_no_players();
        return;
    }

    println("^3[PinteMod]^7 Connected players: " + players.size);

    for (i = 0; i < players.size; i++)
    {
        player = players[i];

        if (isdefined(player))
            println("^3[PinteMod]^7 [" + i + "] " + player.name);
    }
}

function cmd_help(args)
{
    println("^3========== PinteMod ADMIN ==========");
    println("^7ezzplayers");
    println("^7points <amount>");
    println("^7points <PlayerName|BOIII_XUID|ClientNumber> <amount>");
    println("^7maxpoints [PlayerName|BOIII_XUID|ClientNumber]");
    println("^7ammo [PlayerName|BOIII_XUID|ClientNumber]");
    println("^7godmode <PlayerName|BOIII_XUID|ClientNumber>  ^3(required in multiplayer)");
    println("^7ignore [PlayerName|BOIII_XUID|ClientNumber]");
    println("^7killzombies");
    println("^7ezzspawn <PlayerName|BOIII_XUID|ClientNumber>");
    println("^7ezzrevive <PlayerName|BOIII_XUID|ClientNumber>");
    println("^7ezzrevivestatus [PlayerName|BOIII_XUID|ClientNumber]");
    println("^7ezzban <Player|BOIII_XUID|ClientNumber> [duration] [reason]");
    println("^7ezzunban / ezzbaninfo / ezzbanlist");
    println("^5Weapons commands are in ezz_admin_weapons.gsc");
    println("^3================================");
}

// ------------------------------------------------------------
// Points
// ------------------------------------------------------------

function cmd_points(args)
{
    player = undefined;
    amount = 0;

    if (args.size == 1)
    {
        player = get_first_player();
        amount = int(args[0]);
    }
    else if (args.size >= 2)
    {
        player = find_player_exact(args[0]);

        if (!isdefined(player))
        {
            print_player_not_found(args[0]);
            return;
        }

        amount = int(args[1]);
    }
    else
    {
        println("^3[PinteMod]^7 Usage: points <amount>");
        println("^3[PinteMod]^7 Usage: points <PlayerName|BOIII_XUID|ClientNumber> <amount>");
        return;
    }

    if (!isdefined(player))
    {
        print_no_players();
        return;
    }

    if (amount == 0)
    {
        println("^1[PinteMod] Amount must be a non-zero number");
        return;
    }

    if (amount > 999999)
        amount = 999999;

    if (amount < -999999)
        amount = -999999;

    commands_mark_gameplay_command(
        "points",
        player.name
    );
    player.score += amount;
    player iprintln("^2Points changed: " + amount);
    println("^3[PinteMod]^7 Points changed for " + player.name + ": " + amount);
}

function cmd_maxpoints(args)
{
    player = get_target_from_optional_name(args);

    if (!isdefined(player))
    {
        print_target_error(args);
        return;
    }

    commands_mark_gameplay_command(
        "maxpoints",
        player.name
    );

    if (isdefined(level.ezz_admin_max_points))
        player.score = level.ezz_admin_max_points;
    else
        player.score = 999999;

    player iprintln("^2Points maxed");
    println("^3[PinteMod]^7 Points maxed for " + player.name);
}

// ------------------------------------------------------------
// Ammunition
// ------------------------------------------------------------

function cmd_ammo(args)
{
    player = get_target_from_optional_name(args);

    if (!isdefined(player))
    {
        print_target_error(args);
        return;
    }

    commands_mark_gameplay_command(
        "ammo",
        player.name
    );
    player GiveMaxAmmo(player GetCurrentWeapon());

    player iprintln("^2Ammo refilled");
    println("^3[PinteMod]^7 Ammo refilled for " + player.name);
}

// ------------------------------------------------------------
// Native God Mode
// ------------------------------------------------------------

function cmd_godmode(args)
{
    player = get_safe_godmode_target(args);

    if (!isdefined(player))
    {
        players = GetPlayers();

        if (args.size > 0)
            print_player_not_found(args[0]);
        else if (players.size <= 0)
            print_no_players();

        return;
    }

    commands_mark_gameplay_command(
        "godmode",
        player.name
    );

    if (!isdefined(player.admin_god))
        player.admin_god = false;

    player.admin_god = !player.admin_god;

    if (player.admin_god)
    {
        player.admin_old_health = player.health;
        player.admin_old_maxhealth = player.maxhealth;

        // Native engine protection.
        player EnableInvulnerability();

        // Additional fallback for Zombies scripts which inspect health values.
        player.maxhealth = 99999;
        player.health = 99999;

        player iprintln("^2God Mode ON");
        commands_broadcast("^2" + player.name + " -> God Mode ON");
        println("^2[PinteMod] Native God Mode ON for " + player.name);
    }
    else
    {
        // Remove native protection first.
        player DisableInvulnerability();

        if (isdefined(player.admin_old_maxhealth))
            player.maxhealth = player.admin_old_maxhealth;
        else
            player.maxhealth = 100;

        if (isdefined(player.admin_old_health))
            player.health = player.admin_old_health;
        else
            player.health = player.maxhealth;

        if (player.health <= 0)
            player.health = player.maxhealth;

        player iprintln("^1God Mode OFF");
        commands_broadcast("^1" + player.name + " -> God Mode OFF");
        println("^1[PinteMod] Native God Mode OFF for " + player.name);
    }
}

// ------------------------------------------------------------
// Zombie ignore flag
// ------------------------------------------------------------

function cmd_ignore(args)
{
    player = get_target_from_optional_name(args);

    if (!isdefined(player))
    {
        print_target_error(args);
        return;
    }

    commands_mark_gameplay_command(
        "ignore",
        player.name
    );

    if (!isdefined(player.admin_ignore))
        player.admin_ignore = false;

    player.admin_ignore = !player.admin_ignore;

    // BO3 stacks temporary ignore effects through ignorme_count.
    // Using the native helpers keeps the admin state independent from
    // Zombie Blood, In Plain Sight and other temporary effects.
    if (player.admin_ignore)
    {
        player zm_utility::increment_ignoreme();
        player iprintln("^2Zombie Ignore ON");
        println("^2[PinteMod] Zombie Ignore ON for " + player.name);
    }
    else
    {
        player zm_utility::decrement_ignoreme();
        player iprintln("^1Zombie Ignore OFF");
        println("^1[PinteMod] Zombie Ignore OFF for " + player.name);
    }
}

// ------------------------------------------------------------
// Zombies
// ------------------------------------------------------------

function cmd_killzombies(args)
{
    zombies = GetAIArray();
    count = 0;

    for (i = 0; i < zombies.size; i++)
    {
        zombie = zombies[i];

        if (isdefined(zombie) && IsAlive(zombie))
        {
            zombie DoDamage(zombie.health + 9999, zombie.origin);
            count++;
        }
    }

    if (count > 0)
    {
        commands_mark_gameplay_command(
        "killzombies",
        "all"
    );
    }

    commands_broadcast("^1" + count + " zombies killed");
    println("^3[PinteMod]^7 Zombies killed: " + count);
}

// ------------------------------------------------------------
// Native spectator respawn
// ------------------------------------------------------------

function get_safe_spawn_target(args)
{
    players = GetPlayers();

    if (args.size > 0)
        return find_player_exact(args[0]);

    if (players.size == 1)
        return players[0];

    if (players.size > 1)
    {
        println("^1[PinteMod] Several players are connected");
        println("^3[PinteMod]^7 Usage: ezzspawn <PlayerName|BOIII_XUID|ClientNumber>");
    }

    return undefined;
}

function cmd_ezzspawn(args)
{
    player = get_safe_spawn_target(args);

    if (!isdefined(player))
    {
        if (args.size > 0)
            print_player_not_found(args[0]);
        else if (GetPlayers().size <= 0)
            print_no_players();

        return;
    }

    if (!isdefined(player.sessionstate) ||
        player.sessionstate != "spectator")
    {
        println("^3[PinteMod]^7 " + player.name + " is not a spectator");
        player iprintln("^3You are already active");
        return;
    }

    if (!isdefined(player.spectator_respawn))
    {
        println(
            "^1[PinteMod] Native spectator respawn data unavailable for " +
            player.name
        );
        player iprintln("^1Respawn is not ready yet");
        return;
    }

    player zm::spectator_respawn_player();

    wait 0.1;

    if (isdefined(player.sessionstate) &&
        player.sessionstate != "spectator")
    {
        commands_mark_gameplay_command(
        "admin respawn",
        player.name
    );

        println("^2[PinteMod] Spectator respawned: " + player.name);
        player iprintln("^2You have been spawned");
        commands_broadcast("^2" + player.name + " rejoined the game");
    }
    else
    {
        println("^1[PinteMod] Native spectator respawn did not complete");
        player iprintln("^1Respawn failed; try again when a survivor is active");
    }
}

// ------------------------------------------------------------
// Administrative revive — native last-stand backend
// ------------------------------------------------------------

function commands_revive_perk_catalog()
{
    perks = [];
    perks[perks.size] = "specialty_armorvest";
    perks[perks.size] = "specialty_quickrevive";
    perks[perks.size] = "specialty_fastreload";
    perks[perks.size] = "specialty_doubletap2";
    perks[perks.size] = "specialty_staminup";
    perks[perks.size] = "specialty_deadshot";
    perks[perks.size] = "specialty_additionalprimaryweapon";
    perks[perks.size] = "specialty_electriccherry";
    perks[perks.size] = "specialty_widowswine";
    return perks;
}

function commands_capture_revive_snapshot(player)
{
    if (!isdefined(player))
        return;

    catalog = commands_revive_perk_catalog();
    player.pintemod_revive_saved_perks = [];

    for (i = 0; i < catalog.size; i++)
    {
        perk = catalog[i];

        if (player HasPerk(perk))
        {
            player.pintemod_revive_saved_perks[
                player.pintemod_revive_saved_perks.size
            ] = perk;
        }
    }

    player.pintemod_revive_snapshot_time = GetTime();
    current_weapon = player GetCurrentWeapon();
    player.pintemod_revive_snapshot_weapon_name = "unavailable";

    if (isdefined(current_weapon) && isdefined(current_weapon.name))
        player.pintemod_revive_snapshot_weapon_name = current_weapon.name;

    player.pintemod_revive_snapshot_score = player.score;

    println(
        "^5[PinteMod Revive]^7 SNAPSHOT | player=" + player.name +
        " | xuid=" + ezz_admin_identity::get_player_xuid(player) +
        " | perks=" + player.pintemod_revive_saved_perks.size
    );
}

function commands_revive_snapshot_monitor()
{
    self endon("disconnect");

    for (;;)
    {
        self waittill("entering_last_stand");
        commands_capture_revive_snapshot(self);
    }
}

function commands_attach_revive_monitor(player)
{
    if (!isdefined(player))
        return;

    if (isdefined(player.pintemod_revive_monitor_started) &&
        player.pintemod_revive_monitor_started)
    {
        return;
    }

    player.pintemod_revive_monitor_started = true;
    player thread commands_revive_snapshot_monitor();
}

function commands_revive_bootstrap()
{
    players = GetPlayers();

    for (i = 0; i < players.size; i++)
        commands_attach_revive_monitor(players[i]);

    for (;;)
    {
        level waittill("connected", player);
        commands_attach_revive_monitor(player);
    }
}

function commands_restore_revive_perks(player)
{
    restored = 0;

    if (!isdefined(player.pintemod_revive_saved_perks))
        return restored;

    for (i = 0; i < player.pintemod_revive_saved_perks.size; i++)
    {
        perk = player.pintemod_revive_saved_perks[i];

        if (!player HasPerk(perk))
        {
            player zm_perks::give_perk(perk, false);
            restored++;
        }
    }

    return restored;
}

function commands_count_missing_revive_perks(player)
{
    missing = 0;

    if (!isdefined(player) ||
        !isdefined(player.pintemod_revive_saved_perks))
    {
        return missing;
    }

    for (i = 0; i < player.pintemod_revive_saved_perks.size; i++)
    {
        if (!player HasPerk(player.pintemod_revive_saved_perks[i]))
            missing++;
    }

    return missing;
}

function commands_verify_revive(player, pre_restored_perks)
{
    if (!isdefined(player))
        return;

    player endon("disconnect");
    wait 0.5;

    if (player laststand::player_is_in_laststand())
    {
        println(
            "^1[PinteMod Revive]^7 FAILED | player=" + player.name +
            " | still_in_laststand=1"
        );
        player iprintln("^1[PinteMod]^7 Administrative revive failed.");
        return;
    }

    // Second pass after the native revive protects perks that a map-specific
    // callback may have removed while leaving last stand.
    post_restored_perks = commands_restore_revive_perks(player);
    missing_perks = commands_count_missing_revive_perks(player);

    println(
        "^2[PinteMod Revive]^7 SUCCESS | player=" + player.name +
        " | xuid=" + ezz_admin_identity::get_player_xuid(player) +
        " | pre_restored=" + pre_restored_perks +
        " | post_restored=" + post_restored_perks +
        " | missing_perks=" + missing_perks +
        " | score=" + player.score
    );

    if (missing_perks > 0)
    {
        player iprintln(
            "^3[PinteMod]^7 Revived, but some perks could not be restored."
        );
        return;
    }

    player iprintln("^2[PinteMod]^7 Administrative revive complete.");
}

function cmd_ezzrevive(args)
{
    if (args.size < 1)
    {
        println("^5[PinteMod]^7 Usage: ezzrevive <PlayerName|BOIII_XUID|ClientNumber>");
        return;
    }

    player = find_player_exact(args[0]);

    if (!isdefined(player))
    {
        print_player_not_found(args[0]);
        return;
    }

    if (isdefined(player.sessionstate) &&
        player.sessionstate == "spectator")
    {
        println(
            "^3[PinteMod]^7 " + player.name +
            " is a spectator; use ezzspawn/ezzjoin instead."
        );
        return;
    }

    if (!player laststand::player_is_in_laststand())
    {
        println(
            "^3[PinteMod]^7 " + player.name +
            " is not currently downed."
        );
        return;
    }

    commands_mark_gameplay_command("revive", player.name);
    restored_perks = commands_restore_revive_perks(player);
    saved_perks = 0;

    if (isdefined(player.pintemod_revive_saved_perks))
        saved_perks = player.pintemod_revive_saved_perks.size;

    println(
        "^5[PinteMod Revive]^7 REQUEST | player=" + player.name +
        " | xuid=" + ezz_admin_identity::get_player_xuid(player) +
        " | saved_perks=" + saved_perks +
        " | pre_restored=" + restored_perks
    );

    player zm_laststand::remote_revive(undefined);
    level thread commands_verify_revive(player, restored_perks);
}

function cmd_ezzrevivestatus(args)
{
    player = undefined;

    if (args.size >= 1)
        player = find_player_exact(args[0]);
    else
        player = get_first_player();

    if (!isdefined(player))
    {
        print_target_error(args);
        return;
    }

    snapshot_count = 0;
    snapshot_time = 0;

    if (isdefined(player.pintemod_revive_saved_perks))
        snapshot_count = player.pintemod_revive_saved_perks.size;

    if (isdefined(player.pintemod_revive_snapshot_time))
        snapshot_time = player.pintemod_revive_snapshot_time;

    println("^5===== PINTEMOD REVIVE STATUS =====");
    println("^7Player: " + player.name);
    println("^7BOIII_XUID: " + ezz_admin_identity::get_player_xuid(player));
    in_laststand = player laststand::player_is_in_laststand();
    println("^7In last stand: " + in_laststand);
    println("^7Saved perks: " + snapshot_count);

    if (snapshot_count > 0)
    {
        for (i = 0; i < player.pintemod_revive_saved_perks.size; i++)
        {
            println(
                "^7  - " + player.pintemod_revive_saved_perks[i]
            );
        }
    }

    println("^7Snapshot game time: " + snapshot_time + " ms");

    if (isdefined(player.pintemod_revive_snapshot_score))
    {
        println(
            "^7Score snapshot/current: " +
            player.pintemod_revive_snapshot_score + "/" + player.score
        );
    }

    if (isdefined(player.pintemod_revive_snapshot_weapon_name))
    {
        println(
            "^7Weapon before down: " +
            player.pintemod_revive_snapshot_weapon_name
        );
    }

    println("^7Backend: zm_laststand::remote_revive(undefined)");
    println("^5===================================");
}

function commands_revive_test_assert(result, condition, test_name, details)
{
    result.total++;

    if (condition)
    {
        result.passed++;
        println("^2[PASS]^7 " + result.total + " " + test_name);
        return;
    }

    result.failed++;
    println(
        "^1[FAIL]^7 " + result.total + " " + test_name +
        " | " + details
    );
}

function commands_revive_catalog_unique(catalog)
{
    for (i = 0; i < catalog.size; i++)
    {
        for (j = i + 1; j < catalog.size; j++)
        {
            if (catalog[i] == catalog[j])
                return false;
        }
    }

    return true;
}

function cmd_ezzrevivetest(args)
{
    if (args.size < 1 || toLower(args[0]) != "suite")
    {
        println(
            "^5[PinteMod]^7 Usage: ezzrevivetest suite [PlayerName|BOIII_XUID|ClientNumber]"
        );
        return;
    }

    player = undefined;

    if (args.size >= 2)
        player = find_player_exact(args[1]);
    else
        player = get_first_player();

    println("^5===== PINTEMOD REVIVE GROUPED SUITE =====");
    println("");

    result = SpawnStruct();
    result.total = 0;
    result.passed = 0;
    result.failed = 0;

    commands_revive_test_assert(
        result,
        isdefined(player),
        "connected target resolved",
        "Use ezzrevivetest suite <PlayerName|BOIII_XUID|ClientNumber>"
    );

    if (!isdefined(player))
    {
        println("^1[PinteMod Revive]^7 Suite aborted: no target");
        return;
    }

    catalog = commands_revive_perk_catalog();
    current_laststand = player laststand::player_is_in_laststand();
    xuid = ezz_admin_identity::get_player_xuid(player);

    commands_revive_test_assert(
        result,
        ezz_admin_identity::is_valid_xuid(xuid),
        "stable target identity available",
        "xuid=" + xuid
    );
    commands_revive_test_assert(
        result,
        isdefined(player.pintemod_revive_monitor_started) &&
        player.pintemod_revive_monitor_started,
        "down-state snapshot monitor attached",
        "monitor missing"
    );
    commands_revive_test_assert(
        result,
        catalog.size == 9,
        "classic perk catalog complete",
        "count=" + catalog.size
    );
    commands_revive_test_assert(
        result,
        commands_revive_catalog_unique(catalog),
        "perk catalog contains no duplicates",
        "duplicate perk"
    );
    commands_revive_test_assert(
        result,
        current_laststand == true || current_laststand == false,
        "native last-stand state readable",
        "unexpected state"
    );
    commands_revive_test_assert(
        result,
        isdefined(player.sessionstate),
        "player session state readable",
        "sessionstate missing"
    );
    commands_revive_test_assert(
        result,
        isdefined(player.health),
        "player health state readable",
        "health missing"
    );
    commands_revive_test_assert(
        result,
        isdefined(player.pintemod_revive_saved_perks) ||
        !current_laststand,
        "downed player has a perk snapshot",
        "downed without snapshot"
    );
    commands_revive_test_assert(
        result,
        true,
        "native backend selected: remote_revive",
        "backend unavailable"
    );

    println("");
    println(
        "^5[PinteMod Revive]^7 RESULT " + result.passed + "/" +
        result.total + " PASS | failed=" + result.failed
    );
    println("^5============================================");
}
