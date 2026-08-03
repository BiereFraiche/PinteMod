// ============================================================
// PinteMod — Perks v0.5.3
// Fichier : ezz_admin_perks.gsc
// Créé par BiereFraiche et ChatGPT
//
// Ajout, vérification, retrait et suppression complète des perks.
// ============================================================

#using scripts\zm\_zm_perks;
#using custom_scripts\ezz_admin_identity;

function perks_mark_gameplay_command(command_name, target_name)
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
    addcommand("ezzperks", ::cmd_ezzperks);
    addcommand("ezzperk", ::cmd_ezzperk);
    addcommand("ezzperktoggle", ::cmd_ezzperktoggle);
    addcommand("ezzhasperk", ::cmd_ezzhasperk);
    addcommand("ezzallperks", ::cmd_ezzallperks);
    addcommand("ezzremoveperk", ::cmd_ezzremoveperk);
    addcommand("ezzclearperks", ::cmd_ezzclearperks);

    println("^5[PinteMod]^7 Perks v0.5.3 loaded");
}

// ------------------------------------------------------------
// Player helpers
// ------------------------------------------------------------

function perks_get_first_player()
{
    players = GetPlayers();

    if (players.size > 0)
        return players[0];

    return undefined;
}

function perks_find_player_exact(player_name)
{
    return ezz_admin_identity::identity_find_player(player_name);
}

function perks_get_target_optional(args)
{
    if (args.size > 0)
        return perks_find_player_exact(args[0]);

    return perks_get_first_player();
}

function perks_print_usage()
{
    println("^6[PinteMod]^7 Usage: ezzperk <alias>");
    println("^6[PinteMod]^7 Usage: ezzperk <PlayerName|BOIII_XUID|ClientNumber> <alias>");
    println("^6[PinteMod]^7 Use ezzperks for the alias list");
}

function perks_print_has_usage()
{
    println("^6[PinteMod]^7 Usage: ezzhasperk <alias>");
    println("^6[PinteMod]^7 Usage: ezzhasperk <PlayerName|BOIII_XUID|ClientNumber> <alias>");
}

// ------------------------------------------------------------
// Alias resolver
// ------------------------------------------------------------

function perks_resolve_alias(alias)
{
    switch (alias)
    {
        case "jug":
        case "jugg":
        case "juggernog":
            return "specialty_armorvest";

        case "quick":
        case "qr":
        case "quickrevive":
            return "specialty_quickrevive";

        case "speed":
        case "speedcola":
        case "reload":
            return "specialty_fastreload";

        case "doubletap":
        case "dt":
        case "dt2":
            return "specialty_doubletap2";

        case "staminup":
        case "stamina":
        case "stamin":
            return "specialty_staminup";

        case "deadshot":
        case "dead":
        case "daiquiri":
            return "specialty_deadshot";

        case "mule":
        case "mulekick":
        case "thirdgun":
            return "specialty_additionalprimaryweapon";

        case "cherry":
        case "electriccherry":
        case "ec":
            return "specialty_electriccherry";

        case "widows":
        case "widow":
        case "widowswine":
            return "specialty_widowswine";
    }

    return undefined;
}

function perks_alias_display(perk)
{
    switch (perk)
    {
        case "specialty_armorvest":
            return "jug";

        case "specialty_quickrevive":
            return "quick";

        case "specialty_fastreload":
            return "speed";

        case "specialty_doubletap2":
            return "doubletap";

        case "specialty_staminup":
            return "staminup";

        case "specialty_deadshot":
            return "deadshot";

        case "specialty_additionalprimaryweapon":
            return "mule";

        case "specialty_electriccherry":
            return "cherry";

        case "specialty_widowswine":
            return "widows";
    }

    return perk;
}

// ------------------------------------------------------------
// Perk list
// ------------------------------------------------------------

function cmd_ezzperks(args)
{
    println("^6========== PinteMod PERKS v0.5.3 ==========");
    println("^7jug        - Juggernog");
    println("^7quick      - Quick Revive");
    println("^7speed      - Speed Cola");
    println("^7doubletap  - Double Tap II");
    println("^7staminup   - Stamin-Up");
    println("^7deadshot   - Deadshot Daiquiri");
    println("^7mule       - Mule Kick");
    println("^7cherry     - Electric Cherry");
    println("^7widows     - Widow's Wine");
    println("^3Usage: ezzperk <alias>");
    println("^3Usage: ezzperk <PlayerName|BOIII_XUID|ClientNumber> <alias>");
    println("^3Usage: ezzallperks [PlayerName|BOIII_XUID|ClientNumber]");
    println("^3Usage: ezzremoveperk [PlayerName|BOIII_XUID|ClientNumber] <alias>");
    println("^3Usage: ezzclearperks [PlayerName|BOIII_XUID|ClientNumber]");
    println("^6======================================");
}

// ------------------------------------------------------------
// Give one perk
// ------------------------------------------------------------

function cmd_ezzperk(args)
{
    player = undefined;
    alias = "";

    if (args.size == 1)
    {
        named_player = perks_find_player_exact(args[0]);

        if (isdefined(named_player))
        {
            println("^1[PinteMod] Missing perk alias after player: " + args[0]);
            perks_print_usage();
            return;
        }

        player = perks_get_first_player();
        alias = args[0];
    }
    else if (args.size >= 2)
    {
        player = perks_find_player_exact(args[0]);
        alias = args[1];
    }
    else
    {
        perks_print_usage();
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

    perk = perks_resolve_alias(alias);

    if (!isdefined(perk))
    {
        println("^1[PinteMod] Unknown or unavailable alias: " + alias);
        println("^6[PinteMod]^7 Use ezzperks for the alias list");
        return;
    }

    if (player HasPerk(perk))
    {
        println("^3[PinteMod]^7 " + player.name + " already has " + alias);
        return;
    }

    perks_mark_gameplay_command(
        "perk " + alias,
        player.name
    );
    player zm_perks::give_perk(perk, false);

    println("^6[PinteMod]^7 " + alias + " given to " + player.name);
    player iprintln("^2Perk added: ^7" + alias);
}

// ------------------------------------------------------------
// Toggle one perk (menu-safe: select again to remove)
// ------------------------------------------------------------

function cmd_ezzperktoggle(args)
{
    player = undefined;
    alias = "";

    if (args.size == 1)
    {
        named_player = perks_find_player_exact(args[0]);

        if (isdefined(named_player))
        {
            println("^1[PinteMod] Missing perk alias after player: " + args[0]);
            perks_print_usage();
            return;
        }

        player = perks_get_first_player();
        alias = args[0];
    }
    else if (args.size >= 2)
    {
        player = perks_find_player_exact(args[0]);
        alias = args[1];
    }
    else
    {
        perks_print_usage();
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

    perk = perks_resolve_alias(alias);

    if (!isdefined(perk))
    {
        println("^1[PinteMod] Unknown or unavailable alias: " + alias);
        println("^6[PinteMod]^7 Use ezzperks for the alias list");
        return;
    }

    if (player HasPerk(perk))
    {
        perks_mark_gameplay_command(
        "perk toggle " + alias,
        player.name
    );
        player notify(perk + "_stop");
        println("^6[PinteMod]^7 " + alias + " removed from " + player.name);
        player iprintln("^1Perk removed: ^7" + alias);
        return;
    }

    perks_mark_gameplay_command(
        "perk toggle " + alias,
        player.name
    );
    player zm_perks::give_perk(perk, false);
    println("^6[PinteMod]^7 " + alias + " given to " + player.name);
    player iprintln("^2Perk added: ^7" + alias);
}

// ------------------------------------------------------------
// Perk diagnostic
// ------------------------------------------------------------

function cmd_ezzhasperk(args)
{
    player = undefined;
    alias = "";

    if (args.size == 1)
    {
        named_player = perks_find_player_exact(args[0]);

        if (isdefined(named_player))
        {
            println("^1[PinteMod] Missing perk alias after player: " + args[0]);
            perks_print_has_usage();
            return;
        }

        player = perks_get_first_player();
        alias = args[0];
    }
    else if (args.size >= 2)
    {
        player = perks_find_player_exact(args[0]);
        alias = args[1];
    }
    else
    {
        perks_print_has_usage();
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

    perk = perks_resolve_alias(alias);

    if (!isdefined(perk))
    {
        println("^1[PinteMod] Unknown or unavailable alias: " + alias);
        return;
    }

    if (player HasPerk(perk))
        println("^2[PinteMod] " + player.name + " has " + alias);
    else
        println("^1[PinteMod] " + player.name + " does not have " + alias);
}

// ------------------------------------------------------------
// Give all classic perks
// ------------------------------------------------------------

function perks_give_if_missing(player, perk)
{
    if (player HasPerk(perk))
        return false;

    player zm_perks::give_perk(perk, false);
    return true;
}

function cmd_ezzallperks(args)
{
    player = perks_get_target_optional(args);

    if (!isdefined(player))
    {
        if (args.size > 0)
            println("^1[PinteMod] Player not found: " + args[0]);
        else
            println("^1[PinteMod] No connected player");

        return;
    }

    count = 0;

    if (perks_give_if_missing(player, "specialty_armorvest"))
        count++;

    if (perks_give_if_missing(player, "specialty_quickrevive"))
        count++;

    if (perks_give_if_missing(player, "specialty_fastreload"))
        count++;

    if (perks_give_if_missing(player, "specialty_doubletap2"))
        count++;

    if (perks_give_if_missing(player, "specialty_staminup"))
        count++;

    if (perks_give_if_missing(player, "specialty_deadshot"))
        count++;

    if (perks_give_if_missing(player, "specialty_additionalprimaryweapon"))
        count++;

    if (perks_give_if_missing(player, "specialty_electriccherry"))
        count++;

    if (perks_give_if_missing(player, "specialty_widowswine"))
        count++;

    if (count > 0)
    {
        perks_mark_gameplay_command(
        "allperks",
        player.name
    );
    }

    println("^6[PinteMod]^7 All classic perks processed for " + player.name);
    println("^6[PinteMod]^7 Newly added perks: " + count);

    player iprintln("^2All classic perks processed");
}

// ------------------------------------------------------------
// Remove one perk through the native perk stop event
// ------------------------------------------------------------

function cmd_ezzremoveperk(args)
{
    player = undefined;
    alias = "";

    if (args.size == 1)
    {
        named_player = perks_find_player_exact(args[0]);

        if (isdefined(named_player))
        {
            println("^1[PinteMod] Missing perk alias after player: " + args[0]);
            println("^6[PinteMod]^7 Usage: ezzremoveperk <alias>");
            println("^6[PinteMod]^7 Usage: ezzremoveperk <PlayerName|BOIII_XUID|ClientNumber> <alias>");
            return;
        }

        player = perks_get_first_player();
        alias = args[0];
    }
    else if (args.size >= 2)
    {
        player = perks_find_player_exact(args[0]);
        alias = args[1];
    }
    else
    {
        println("^6[PinteMod]^7 Usage: ezzremoveperk <alias>");
        println("^6[PinteMod]^7 Usage: ezzremoveperk <PlayerName|BOIII_XUID|ClientNumber> <alias>");
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

    perk = perks_resolve_alias(alias);

    if (!isdefined(perk))
    {
        println("^1[PinteMod] Unknown or unavailable alias: " + alias);
        return;
    }

    if (!player HasPerk(perk))
    {
        println("^3[PinteMod]^7 " + player.name + " does not have " + alias);
        return;
    }

    // The native perk_think() thread waits for "<perk>_stop".
    // It then performs UnsetPerk, HUD/clientfield cleanup and
    // the perk-specific take callback.
    perks_mark_gameplay_command(
        "remove perk " + alias,
        player.name
    );
    player notify(perk + "_stop");

    println("^6[PinteMod]^7 Removal requested: " + alias + " from " + player.name);
    player iprintln("^1Perk removed: ^7" + alias);
}

// ------------------------------------------------------------
// Remove all classic perks
// ------------------------------------------------------------

function perks_remove_if_owned(player, perk)
{
    if (!player HasPerk(perk))
        return false;

    player notify(perk + "_stop");
    return true;
}

function cmd_ezzclearperks(args)
{
    player = perks_get_target_optional(args);

    if (!isdefined(player))
    {
        if (args.size > 0)
            println("^1[PinteMod] Player not found: " + args[0]);
        else
            println("^1[PinteMod] No connected player");

        return;
    }

    count = 0;

    if (perks_remove_if_owned(player, "specialty_armorvest"))
        count++;

    if (perks_remove_if_owned(player, "specialty_quickrevive"))
        count++;

    if (perks_remove_if_owned(player, "specialty_fastreload"))
        count++;

    if (perks_remove_if_owned(player, "specialty_doubletap2"))
        count++;

    if (perks_remove_if_owned(player, "specialty_staminup"))
        count++;

    if (perks_remove_if_owned(player, "specialty_deadshot"))
        count++;

    if (perks_remove_if_owned(player, "specialty_additionalprimaryweapon"))
        count++;

    if (perks_remove_if_owned(player, "specialty_electriccherry"))
        count++;

    if (perks_remove_if_owned(player, "specialty_widowswine"))
        count++;

    if (count > 0)
    {
        perks_mark_gameplay_command(
        "clearperks",
        player.name
    );
    }

    println("^6[PinteMod]^7 Clear requested for " + player.name);
    println("^6[PinteMod]^7 Perks targeted: " + count);

    player iprintln("^1All classic perks removed");
}
