// ============================================================
// PinteMod — Navigation v0.1.0
// Fichier : ezz_admin_navigation.gsc
// Créé par BiereFraiche et ChatGPT
//
// Sauvegarde et chargement de position, téléportation au viseur
// et diagnostic de navigation pour le joueur ciblé.
// ============================================================

#using custom_scripts\ezz_admin_identity;

function nav_mark_gameplay_command(command_name, target_name)
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
    addcommand("ezzsave", ::cmd_ezzsave);
    addcommand("ezzload", ::cmd_ezzload);
    addcommand("ezztp", ::cmd_ezztp);
    addcommand("ezzteleport", ::cmd_ezztp);
    addcommand("ezznavstatus", ::cmd_ezznavstatus);

    println("^5[PinteMod]^7 Navigation v0.1.0 loaded");
}

// ------------------------------------------------------------
// Player helpers
// ------------------------------------------------------------

function nav_get_first_player()
{
    players = GetPlayers();

    if (players.size > 0)
        return players[0];

    return undefined;
}

function nav_find_player_exact(player_name)
{
    return ezz_admin_identity::identity_find_player(player_name);
}

function nav_get_optional_target(args)
{
    if (args.size > 0)
        return nav_find_player_exact(args[0]);

    players = GetPlayers();

    if (players.size == 1)
        return players[0];

    return undefined;
}

function nav_player_can_move(player)
{
    if (!isdefined(player))
        return false;

    if (isdefined(player.sessionstate) &&
        player.sessionstate == "spectator")
    {
        return false;
    }

    if (!IsAlive(player))
        return false;

    return true;
}

function nav_print_player_error(args)
{
    if (args.size > 0)
        println("^1[PinteMod] Player not found: " + args[0]);
    else
        println("^1[PinteMod] Select a player when several are connected");
}

// ------------------------------------------------------------
// Save current position
// ------------------------------------------------------------

function cmd_ezzsave(args)
{
    player = nav_get_optional_target(args);

    if (!isdefined(player))
    {
        nav_print_player_error(args);
        return;
    }

    if (!nav_player_can_move(player))
    {
        println("^1[PinteMod] Player must be alive and active");
        player iprintln("^1[PinteMod]^7 You cannot save while spectating");
        return;
    }

    player.ezz_saved_map = toLower(GetDvarString("mapname"));
    player.ezz_saved_origin = player.origin;
    player.ezz_saved_angles = player GetPlayerAngles();
    player.ezz_has_saved_position = true;

    println("^2[PinteMod] Position saved for " + player.name);
    player iprintln("^2[PinteMod]^7 Position saved");
}

// ------------------------------------------------------------
// Restore saved position
// ------------------------------------------------------------

function cmd_ezzload(args)
{
    player = nav_get_optional_target(args);

    if (!isdefined(player))
    {
        nav_print_player_error(args);
        return;
    }

    if (!nav_player_can_move(player))
    {
        println("^1[PinteMod] Player must be alive and active");
        player iprintln("^1[PinteMod]^7 Spawn first, then load");
        return;
    }

    if (!isdefined(player.ezz_has_saved_position) ||
        !player.ezz_has_saved_position)
    {
        println("^1[PinteMod] No saved position for " + player.name);
        player iprintln("^3[PinteMod]^7 No saved position");
        return;
    }

    current_map = toLower(GetDvarString("mapname"));

    if (!isdefined(player.ezz_saved_map) ||
        player.ezz_saved_map != current_map)
    {
        println("^1[PinteMod] Saved position belongs to another map");
        player iprintln("^1[PinteMod]^7 Saved position is from another map");
        return;
    }

    nav_mark_gameplay_command(
        "load position",
        player.name
    );
    player SetOrigin(player.ezz_saved_origin);

    if (isdefined(player.ezz_saved_angles))
        player SetPlayerAngles(player.ezz_saved_angles);

    println("^2[PinteMod] Position restored for " + player.name);
    player iprintln("^2[PinteMod]^7 Position restored");
}

// ------------------------------------------------------------
// Aim trace
// ------------------------------------------------------------

function nav_get_aim_destination(player)
{
    eye = player GetEye();
    angles = player GetPlayerAngles();
    forward = AnglesToForward(angles);

    trace_end = eye + (forward * 8192);
    aim_trace = BulletTrace(eye, trace_end, false, player);

    if (!isdefined(aim_trace["fraction"]) ||
        aim_trace["fraction"] >= 1)
    {
        return undefined;
    }

    hit_position = aim_trace["position"];

    // Prefer a floor below the aimed surface.
    floor_start = hit_position + (0, 0, 96);
    floor_end = hit_position + (0, 0, -640);
    floor_trace = BulletTrace(floor_start, floor_end, false, player);

    if (isdefined(floor_trace["fraction"]) &&
        floor_trace["fraction"] < 1)
    {
        return floor_trace["position"] + (0, 0, 24);
    }

    return hit_position + (0, 0, 24);
}

// ------------------------------------------------------------
// Teleport to the aimer's crosshair
// ------------------------------------------------------------

function cmd_ezztp(args)
{
    if (args.size <= 0)
    {
        println("^6[PinteMod]^7 Usage: ezztp <AimingPlayer> [TargetPlayer]");
        return;
    }

    aimer = nav_find_player_exact(args[0]);

    if (!isdefined(aimer))
    {
        println("^1[PinteMod] Aiming player not found: " + args[0]);
        return;
    }

    target = aimer;

    if (args.size >= 2)
        target = nav_find_player_exact(args[1]);

    if (!isdefined(target))
    {
        println("^1[PinteMod] Target player not found: " + args[1]);
        aimer iprintln("^1[PinteMod]^7 Target player not found");
        return;
    }

    if (!nav_player_can_move(aimer))
    {
        println("^1[PinteMod] Aiming player must be alive and active");
        aimer iprintln("^1[PinteMod]^7 You cannot aim while spectating");
        return;
    }

    if (!nav_player_can_move(target))
    {
        println("^1[PinteMod] Target player must be alive and active");
        aimer iprintln("^1[PinteMod]^7 Target must be active");
        return;
    }

    destination = nav_get_aim_destination(aimer);

    if (!isdefined(destination))
    {
        println("^1[PinteMod] No valid aimed surface");
        aimer iprintln("^1[PinteMod]^7 Aim at a nearby surface");
        return;
    }

    nav_mark_gameplay_command(
        "teleport",
        target.name
    );
    target SetOrigin(destination);

    println(
        "^2[PinteMod] " + target.name +
        " teleported to " + aimer.name + "'s aim"
    );

    aimer iprintln("^2[PinteMod]^7 Teleport completed");

    if (target != aimer)
        target iprintln("^6[PinteMod]^7 You were teleported by " + aimer.name);
}

// ------------------------------------------------------------
// Diagnostic
// ------------------------------------------------------------

function cmd_ezznavstatus(args)
{
    player = nav_get_optional_target(args);

    if (!isdefined(player))
    {
        nav_print_player_error(args);
        return;
    }

    println("^6========== PinteMod NAV STATUS ==========");
    println("^7Player: " + player.name);
    println("^7Map: " + GetDvarString("mapname"));

    if (isdefined(player.ezz_has_saved_position) &&
        player.ezz_has_saved_position)
    {
        println("^2Saved position: YES");
        println("^7Saved map: " + player.ezz_saved_map);
    }
    else
    {
        println("^3Saved position: NO");
    }

    if (nav_player_can_move(player))
        println("^2Movement state: ACTIVE");
    else
        println("^1Movement state: UNAVAILABLE");

    println("^6====================================");
}
