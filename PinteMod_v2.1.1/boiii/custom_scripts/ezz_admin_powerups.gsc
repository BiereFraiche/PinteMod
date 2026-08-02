// ============================================================
// PinteMod — Power-Ups v0.6.1
// Fichier : ezz_admin_powerups.gsc
// Créé par BiereFraiche et ChatGPT
//
// Les Power-Ups apparaissent au point visé par le joueur ciblé.
// Les drops créés par PinteMod peuvent être rendus permanents.
// ============================================================

#using scripts\zm\_zm_powerups;
#using custom_scripts\ezz_admin_identity;


// ------------------------------------------------------------
// Global PinteMod message without BO3's [All]UnknownSoldier prefix
// ------------------------------------------------------------

function powerups_broadcast(message)
{
    players = GetPlayers();

    for (i = 0; i < players.size; i++)
    {
        player = players[i];

        if (isdefined(player))
            player iprintln(message);
    }
}

function powerups_mark_gameplay_command(command_name, target_name)
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
    addcommand("ezzpowerups", ::cmd_ezzpowerups);
    addcommand("ezzpowerup", ::cmd_ezzpowerup);
    addcommand("ezzfreezepowerups", ::cmd_ezzfreezepowerups);

    if (!isdefined(level.ezz_freeze_powerups))
        level.ezz_freeze_powerups = false;

    println("^5[PinteMod]^7 Power-Ups v0.6.1 loaded");
}

// ------------------------------------------------------------
// Player helpers
// ------------------------------------------------------------

function powerups_get_first_player()
{
    players = GetPlayers();

    if (players.size > 0)
        return players[0];

    return undefined;
}

function powerups_find_player_exact(player_name)
{
    return ezz_admin_identity::identity_find_player(player_name);
}

function powerups_get_safe_target(args)
{
    players = GetPlayers();

    if (args.size >= 2)
        return powerups_find_player_exact(args[0]);

    if (players.size == 1)
        return players[0];

    return undefined;
}

function powerups_print_usage()
{
    println("^4[PinteMod]^7 Solo: ezzpowerup <alias>");
    println("^4[PinteMod]^7 Multi: ezzpowerup <PlayerName|BOIII_XUID|ClientNumber> <alias>");
    println("^4[PinteMod]^7 Use ezzpowerups for the alias list");
}

// ------------------------------------------------------------
// Alias resolver
// ------------------------------------------------------------

function powerups_resolve_alias(alias)
{
    switch (alias)
    {
        case "maxammo":
        case "ammo":
        case "fullammo":
            return "full_ammo";

        case "instakill":
        case "insta":
        case "ik":
            return "insta_kill";

        case "doublepoints":
        case "double":
        case "dp":
            return "double_points";

        case "firesale":
        case "fire":
        case "sale":
            return "fire_sale";

        case "carpenter":
        case "carp":
        case "boards":
            return "carpenter";

        case "nuke":
        case "kaboom":
            return "nuke";

        case "deathmachine":
        case "death":
        case "minigun":
            return "minigun";

        case "freeperk":
        case "perk":
        case "bottle":
            return "free_perk";

        case "shield":
        case "shieldcharge":
        case "shield_charge":
            return "shield_charge";
    }

    return undefined;
}

// ------------------------------------------------------------
// Availability
// ------------------------------------------------------------

function powerups_is_available(powerup_name)
{
    if (!isdefined(level.zombie_powerups))
        return false;

    if (!isdefined(level.zombie_powerups[powerup_name]))
        return false;

    return true;
}

function powerups_print_availability(alias, powerup_name)
{
    if (powerups_is_available(powerup_name))
        println("^2[PinteMod] " + alias + " - available");
    else
        println("^1[PinteMod] " + alias + " - unavailable on this map");
}

function cmd_ezzpowerups(args)
{
    println("^4========== PinteMod POWERUPS v0.6.1 ==========");

    powerups_print_availability("maxammo", "full_ammo");
    powerups_print_availability("instakill", "insta_kill");
    powerups_print_availability("doublepoints", "double_points");
    powerups_print_availability("firesale", "fire_sale");
    powerups_print_availability("carpenter", "carpenter");
    powerups_print_availability("nuke", "nuke");
    powerups_print_availability("deathmachine", "minigun");
    powerups_print_availability("freeperk", "free_perk");
    powerups_print_availability("shield", "shield_charge");

    println("^3Solo: ezzpowerup <alias>");
    println("^3Multi: ezzpowerup <PlayerName|BOIII_XUID|ClientNumber> <alias>");
    println("^4=========================================");
}

// ------------------------------------------------------------
// Aim trace
// ------------------------------------------------------------

function powerups_get_aim_position(player)
{
    eye = player GetEye();
    angles = player GetPlayerAngles();
    forward = AnglesToForward(angles);

    trace_end = eye + (forward * 8192);
    aim_trace = BulletTrace(eye, trace_end, false, player);

    // Do not spawn thousands of units away when aiming into the sky.
    if (aim_trace["fraction"] >= 1)
        return undefined;

    hit_position = aim_trace["position"];

    // Prefer the floor below the aimed point so the pickup does not
    // remain embedded in a wall or object.
    floor_start = hit_position + (0, 0, 64);
    floor_end = hit_position + (0, 0, -512);
    floor_trace = BulletTrace(floor_start, floor_end, false, player);

    if (floor_trace["fraction"] < 1)
        return floor_trace["position"];

    // Fallback: the native powerup movement thread may still settle it.
    return hit_position;
}

// ------------------------------------------------------------
// Spawn selected Power-Up at aim point
// ------------------------------------------------------------

function cmd_ezzpowerup(args)
{
    player = undefined;
    alias = "";

    if (args.size == 1)
    {
        players = GetPlayers();

        // If the only argument is an exact player name, the alias is missing.
        named_player = powerups_find_player_exact(args[0]);

        if (isdefined(named_player))
        {
            println("^1[PinteMod] Missing Power-Up alias after player: " + args[0]);
            powerups_print_usage();
            return;
        }

        if (players.size > 1)
        {
            println("^1[PinteMod] Several players are connected");
            println("^4[PinteMod]^7 Choose whose aim should be used");
            powerups_print_usage();
            return;
        }

        player = powerups_get_first_player();
        alias = args[0];
    }
    else if (args.size >= 2)
    {
        player = powerups_find_player_exact(args[0]);
        alias = args[1];
    }
    else
    {
        powerups_print_usage();
        return;
    }

    if (!isdefined(player))
    {
        if (args.size >= 2)
            println("^1[PinteMod] Player not found: " + args[0]);
        else
            println("^1[PinteMod] No connected player");

        return;
    }

    powerup_name = powerups_resolve_alias(alias);

    if (!isdefined(powerup_name))
    {
        println("^1[PinteMod] Unknown alias: " + alias);
        println("^4[PinteMod]^7 Use ezzpowerups for the alias list");
        return;
    }

    if (!powerups_is_available(powerup_name))
    {
        println("^1[PinteMod] " + alias + " is unavailable on this map");
        return;
    }

    spawn_position = powerups_get_aim_position(player);

    if (!isdefined(spawn_position))
    {
        println("^1[PinteMod] " + player.name + " must aim at a surface");
        player iprintln("^1Aim at a floor, wall or nearby object");
        return;
    }

    // Native Zombies selected Power-Up drop.
    // powerup_name, position, team, location, pickup delay,
    // player-specific owner, stay forever
    drop = zm_powerups::specific_powerup_drop(
        powerup_name,
        spawn_position,
        player.team,
        undefined,
        0,
        undefined,
        level.ezz_freeze_powerups
    );

    if (!isdefined(drop))
    {
        println("^1[PinteMod] Spawn failed for " + alias);
        return;
    }

    powerups_mark_gameplay_command(
        "powerup " + alias,
        player.name
    );
    println("^4[PinteMod]^7 " + alias + " spawned at " + player.name + "'s aim");
    player iprintln("^2Power-Up spawned: ^7" + alias);
}

// ------------------------------------------------------------
// Permanent PinteMod Power-Up mode
// ------------------------------------------------------------

function powerups_print_freeze_status()
{
    if (isdefined(level.ezz_freeze_powerups) &&
        level.ezz_freeze_powerups)
    {
        println("^2[PinteMod] Permanent PinteMod drops: ON");
    }
    else
    {
        println("^3[PinteMod]^7 Permanent PinteMod drops: OFF");
    }

    if (isdefined(level.active_powerups))
    {
        println(
            "^4[PinteMod]^7 Active Power-Ups: " +
            level.active_powerups.size
        );
    }

    println(
        "^3[PinteMod]^7 Native random drops already running a timeout " +
        "cannot be safely converted in place"
    );
}

function cmd_ezzfreezepowerups(args)
{
    mode = "toggle";

    if (args.size > 0)
        mode = toLower(args[0]);

    if (mode == "status")
    {
        powerups_print_freeze_status();
        return;
    }

    if (mode == "on" || mode == "1" || mode == "true")
    {
        level.ezz_freeze_powerups = true;
    }
    else if (mode == "off" || mode == "0" || mode == "false")
    {
        level.ezz_freeze_powerups = false;
    }
    else if (mode == "toggle")
    {
        level.ezz_freeze_powerups = !level.ezz_freeze_powerups;
    }
    else
    {
        println(
            "^4[PinteMod]^7 Usage: " +
            "ezzfreezepowerups [on|off|status]"
        );
        return;
    }

    powerups_mark_gameplay_command(
        "freezepowerups " + mode,
        "all"
    );

    powerups_print_freeze_status();

    if (level.ezz_freeze_powerups)
        powerups_broadcast("^5[PinteMod]^7 PinteMod Power-Up drops are now ^2permanent");
    else
        powerups_broadcast("^5[PinteMod]^7 PinteMod Power-Up drops use ^3normal timeout");
}
