// ============================================================
// PinteMod — Contrôle des zombies v0.7.0
// Fichier : ezz_admin_zombies.gsc
// Créé par BiereFraiche et ChatGPT
//
// Comptage, informations, dernier zombie et élimination des IA.
// ============================================================


// ------------------------------------------------------------
// Global PinteMod message without BO3's [All]UnknownSoldier prefix
// ------------------------------------------------------------

function zombies_broadcast(message)
{
    players = GetPlayers();

    for (i = 0; i < players.size; i++)
    {
        player = players[i];

        if (isdefined(player))
            player iprintln(message);
    }
}

function zombies_mark_gameplay_command(command_name, target_name)
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
    addcommand("ezzzombies", ::cmd_ezzzombies);
    addcommand("ezzombiecount", ::cmd_ezzombiecount);
    addcommand("ezzroundinfo", ::cmd_ezzroundinfo);
    addcommand("ezzlastzombie", ::cmd_ezzlastzombie);
    addcommand("ezzkillzombies", ::cmd_ezzkillzombies);

    println("^5[PinteMod]^7 Zombies v0.7.0 loaded");
}

// ------------------------------------------------------------
// AI helpers
// ------------------------------------------------------------

function zombies_get_alive_ai()
{
    all_ai = GetAIArray();
    alive_ai = [];

    for (i = 0; i < all_ai.size; i++)
    {
        ai = all_ai[i];

        if (isdefined(ai) && IsAlive(ai))
            alive_ai[alive_ai.size] = ai;
    }

    return alive_ai;
}

function zombies_kill_actor(ai)
{
    if (!isdefined(ai))
        return false;

    if (!IsAlive(ai))
        return false;

    ai DoDamage(ai.health + 9999, ai.origin);
    return true;
}

// ------------------------------------------------------------
// Help
// ------------------------------------------------------------

function cmd_ezzzombies(args)
{
    println("^1========== PinteMod ZOMBIES v0.7.0 ==========");
    println("^7ezzombiecount  - count living AI");
    println("^7ezzroundinfo   - current round and AI count");
    println("^7ezzlastzombie  - leave one living AI");
    println("^7ezzkillzombies - eliminate all living AI");
    println("^3Existing alias: killzombies");
    println("^1========================================");
}

// ------------------------------------------------------------
// Count living AI
// ------------------------------------------------------------

function cmd_ezzombiecount(args)
{
    all_ai = GetAIArray();
    alive_count = 0;

    for (i = 0; i < all_ai.size; i++)
    {
        ai = all_ai[i];

        if (isdefined(ai) && IsAlive(ai))
            alive_count++;
    }

    println("^1[PinteMod]^7 Living AI: " + alive_count);
    println("^1[PinteMod]^7 AI entries: " + all_ai.size);
}

// ------------------------------------------------------------
// Round information
// ------------------------------------------------------------

function cmd_ezzroundinfo(args)
{
    alive_ai = zombies_get_alive_ai();

    if (isdefined(level.round_number))
        println("^1[PinteMod]^7 Current round: " + level.round_number);
    else
        println("^3[PinteMod]^7 Round number unavailable");

    println("^1[PinteMod]^7 Living AI: " + alive_ai.size);
}

// ------------------------------------------------------------
// Leave one living AI
// ------------------------------------------------------------

function cmd_ezzlastzombie(args)
{
    alive_ai = zombies_get_alive_ai();

    if (alive_ai.size <= 0)
    {
        println("^3[PinteMod]^7 No living AI found");
        return;
    }

    if (alive_ai.size == 1)
    {
        println("^2[PinteMod] One living AI already remains");
        return;
    }

    // Preserve the final actor in the current engine array.
    survivor = alive_ai[alive_ai.size - 1];
    killed = 0;

    for (i = 0; i < alive_ai.size; i++)
    {
        ai = alive_ai[i];

        if (ai == survivor)
            continue;

        if (zombies_kill_actor(ai))
            killed++;
    }

    if (killed > 0)
    {
        zombies_mark_gameplay_command(
        "last zombie",
        "all"
    );
    }

    println("^1[PinteMod]^7 Eliminated: " + killed);
    println("^2[PinteMod] One living AI preserved");
}

// ------------------------------------------------------------
// Kill all living AI
// ------------------------------------------------------------

function cmd_ezzkillzombies(args)
{
    alive_ai = zombies_get_alive_ai();
    killed = 0;

    for (i = 0; i < alive_ai.size; i++)
    {
        if (zombies_kill_actor(alive_ai[i]))
            killed++;
    }

    if (killed > 0)
    {
        zombies_mark_gameplay_command(
        "kill zombies",
        "all"
    );
    }

    println("^1[PinteMod]^7 Eliminated living AI: " + killed);
    zombies_broadcast("^1" + killed + " zombies killed");
}
