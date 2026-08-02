// ============================================================
// PinteMod — Contrôle des manches v0.8.0
// Fichier : ezz_admin_rounds.gsc
// Créé par BiereFraiche et ChatGPT
//
// Utilise la transition native de BO3 sans verrou supplémentaire.
// Attendre la fin d'une transition avant une nouvelle commande.
// ============================================================

#using scripts\zm\_zm;


// ------------------------------------------------------------
// Global PinteMod message without BO3's [All]UnknownSoldier prefix
// ------------------------------------------------------------

function rounds_broadcast(message)
{
    players = GetPlayers();

    for (i = 0; i < players.size; i++)
    {
        player = players[i];

        if (isdefined(player))
            player iprintln(message);
    }
}

function rounds_mark_gameplay_command(command_name, target_name)
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
    addcommand("ezzrounds", ::cmd_ezzrounds);
    addcommand("ezzround", ::cmd_ezzround);
    addcommand("ezznextround", ::cmd_ezznextround);
    addcommand("ezzskiprounds", ::cmd_ezzskiprounds);
    addcommand("ezzsetround", ::cmd_ezzsetround);

    println("^5[PinteMod]^7 Rounds v0.8.0 loaded");
}

// ------------------------------------------------------------
// Diagnostics
// ------------------------------------------------------------

function rounds_count_living_ai()
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

function rounds_get_current()
{
    if (isdefined(level.round_number))
        return level.round_number;

    return 0;
}

function cmd_ezzrounds(args)
{
    println("^3========== PinteMod ROUNDS v0.8.0 ==========");
    println("^7ezzround              - current state");
    println("^7ezznextround          - finish this round");
    println("^7ezzskiprounds <count> - skip forward");
    println("^7ezzsetround <target>  - jump forward");
    println("^1Maximum target: 255");
    println("^3=======================================");
}

function cmd_ezzround(args)
{
    current_round = rounds_get_current();
    alive_count = rounds_count_living_ai();

    println("^3[PinteMod]^7 Current round: " + current_round);
    println("^3[PinteMod]^7 Living AI: " + alive_count);

    if (isdefined(level.zombie_total))
        println("^3[PinteMod]^7 Remaining spawn queue: " + level.zombie_total);
    else
        println("^1[PinteMod] Spawn queue unavailable");

    if (isdefined(level.zombie_respawns))
        println("^3[PinteMod]^7 Pending respawns: " + level.zombie_respawns);
}

// ------------------------------------------------------------
// Native round completion request
// ------------------------------------------------------------

function rounds_finish_current_round()
{
    // Stop the native round spawner from creating more standard enemies.
    if (isdefined(level.zombie_total))
        level.zombie_total = 0;

    if (isdefined(level.zombie_respawns))
        level.zombie_respawns = 0;

    all_ai = GetAIArray();
    killed = 0;

    for (i = 0; i < all_ai.size; i++)
    {
        ai = all_ai[i];

        if (isdefined(ai) && IsAlive(ai))
        {
            ai DoDamage(ai.health + 9999, ai.origin);
            killed++;
        }
    }

    println("^3[PinteMod]^7 Round completion requested");
    println("^3[PinteMod]^7 Living AI eliminated: " + killed);

    return killed;
}

// ------------------------------------------------------------
// Next round
// ------------------------------------------------------------

function cmd_ezznextround(args)
{
    current_round = rounds_get_current();

    if (current_round <= 0)
    {
        println("^1[PinteMod] Round system is not ready");
        return;
    }

    target_round = current_round + 1;

    rounds_mark_gameplay_command(
        "next round",
        "all"
    );
    rounds_finish_current_round();

    println("^2[PinteMod] Transition requested: " + current_round + " -> " + target_round);
    rounds_broadcast("^3[PinteMod]^7 Advancing to round ^2" + target_round);
}

// ------------------------------------------------------------
// Skip a relative number of rounds
// ------------------------------------------------------------

function cmd_ezzskiprounds(args)
{
    if (args.size <= 0)
    {
        println("^3[PinteMod]^7 Usage: ezzskiprounds <count>");
        return;
    }

    count = int(args[0]);

    if (count <= 0)
    {
        println("^1[PinteMod] Count must be greater than zero");
        return;
    }

    current_round = rounds_get_current();

    if (current_round <= 0)
    {
        println("^1[PinteMod] Round system is not ready");
        return;
    }

    target_round = current_round + count;

    if (target_round > 255)
        target_round = 255;

    if (target_round <= current_round)
    {
        println("^1[PinteMod] Already at the maximum supported round");
        return;
    }

    rounds_mark_gameplay_command(
        "skip rounds",
        "all"
    );

    // Native BO3 increments the round after round_wait() completes.
    // Set target - 1 so the regular increment lands on target.
    zm::set_round_number(target_round - 1);

    rounds_finish_current_round();

    println("^2[PinteMod] Transition requested: " + current_round + " -> " + target_round);
    rounds_broadcast("^3[PinteMod]^7 Jumping to round ^2" + target_round);
}

// ------------------------------------------------------------
// Jump to an absolute future round
// ------------------------------------------------------------

function cmd_ezzsetround(args)
{
    if (args.size <= 0)
    {
        println("^3[PinteMod]^7 Usage: ezzsetround <target>");
        return;
    }

    target_round = int(args[0]);
    current_round = rounds_get_current();

    if (current_round <= 0)
    {
        println("^1[PinteMod] Round system is not ready");
        return;
    }

    if (target_round < 1)
    {
        println("^1[PinteMod] Target must be at least 1");
        return;
    }

    if (target_round > 255)
        target_round = 255;

    // Backward round changes can desynchronize map-specific systems,
    // quest logic and special-round schedules. This stable version
    // intentionally supports forward jumps only.
    if (target_round <= current_round)
    {
        println("^1[PinteMod] Target must be greater than current round");
        println("^3[PinteMod]^7 Current round: " + current_round);
        return;
    }

    rounds_mark_gameplay_command(
        "set round",
        "all"
    );

    // Native BO3 increments the round after normal cleanup.
    zm::set_round_number(target_round - 1);

    rounds_finish_current_round();

    println("^2[PinteMod] Transition requested: " + current_round + " -> " + target_round);
    rounds_broadcast("^3[PinteMod]^7 Jumping to round ^2" + target_round);
}
