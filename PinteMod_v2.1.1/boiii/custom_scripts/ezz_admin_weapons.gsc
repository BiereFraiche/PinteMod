// ============================================================
// PinteMod — Armes toutes maps v0.5.2
// Fichier : ezz_admin_weapons.gsc
// Créé par BiereFraiche et ChatGPT
//
// Armes standards, armes spéciales filtrées selon la map et
// Pack-a-Punch de l'arme actuellement tenue.
// ============================================================

#using scripts\zm\_zm_weapons;
#using custom_scripts\ezz_admin_identity;
#using custom_scripts\ezz_admin_registry;

function weapons_mark_gameplay_command(command_name, target_name)
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
    addcommand("ezzweapons", ::cmd_ezzweapons);
    addcommand("ezzwonderweapons", ::cmd_ezzwonderweapons);
    addcommand("ezzweaponstatus", ::cmd_ezzweaponstatus);
    addcommand("ezzweapon", ::cmd_ezzweapon);
    addcommand("ezzhasweapon", ::cmd_ezzhasweapon);
    addcommand("ezzpapweapon", ::cmd_ezzpapweapon);

    println("^5[PinteMod]^7 Weapons v0.5.2 loaded");
}

// ------------------------------------------------------------
// Player helpers
// ------------------------------------------------------------

function weapons_get_first_player()
{
    players = GetPlayers();

    if (players.size > 0)
        return players[0];

    return undefined;
}

function weapons_find_player_exact(player_name)
{
    return ezz_admin_identity::identity_find_player(player_name);
}

function weapons_print_usage()
{
    println("^5[PinteMod]^7 Usage: ezzweapon <alias>");
    println("^5[PinteMod]^7 Usage: ezzweapon <PlayerName|BOIII_XUID|ClientNumber> <alias>");
    println("^5[PinteMod]^7 Use ezzweapons and ezzwonderweapons");
}

function weapons_print_has_usage()
{
    println("^5[PinteMod]^7 Usage: ezzhasweapon <alias>");
    println("^5[PinteMod]^7 Usage: ezzhasweapon <PlayerName|BOIII_XUID|ClientNumber> <alias>");
}

function weapons_get_map_name()
{
    return toLower(GetDvarString("mapname"));
}

function weapons_get_map_display_name(map_name)
{
    return ezz_admin_registry::get_map_display_name(map_name);
}

// ------------------------------------------------------------
// Registered-weapon discovery
// ------------------------------------------------------------

function weapons_find_registered_name(weapon_name)
{
    if (isdefined(level.zombie_weapons))
    {
        keys = GetArrayKeys(level.zombie_weapons);

        for (i = 0; i < keys.size; i++)
        {
            weapon = keys[i];

            if (isdefined(weapon) &&
                isdefined(weapon.name) &&
                weapon.name == weapon_name)
            {
                return weapon;
            }
        }
    }

    if (isdefined(level._hero_weapons))
    {
        keys = GetArrayKeys(level._hero_weapons);

        for (i = 0; i < keys.size; i++)
        {
            weapon = keys[i];

            if (isdefined(weapon) &&
                isdefined(weapon.name) &&
                weapon.name == weapon_name)
            {
                return weapon;
            }
        }
    }

    return undefined;
}

function weapons_find_first_registered(candidates)
{
    for (i = 0; i < candidates.size; i++)
    {
        weapon = weapons_find_registered_name(candidates[i]);

        if (isdefined(weapon))
            return weapon;
    }

    return undefined;
}

function weapons_is_registered_hero_weapon(weapon)
{
    if (!isdefined(weapon))
        return false;

    if (!isdefined(level._hero_weapons))
        return false;

    return isdefined(level._hero_weapons[weapon]);
}

function weapons_add_candidate(candidates, weapon_name)
{
    candidates[candidates.size] = weapon_name;
    return candidates;
}

// ------------------------------------------------------------
// Stable core resolver
// ------------------------------------------------------------

function weapons_resolve_core_alias(alias)
{
    switch (alias)
    {
        case "raygun":
        case "ray":
        case "rg":
            return GetWeapon("ray_gun");

        case "kn44":
        case "kn":
            return GetWeapon("ar_standard");

        case "hvk":
        case "hvk30":
            return GetWeapon("ar_cqb");

        case "icr":
        case "icr1":
            return GetWeapon("ar_accurate");

        case "manowar":
        case "mow":
            return GetWeapon("ar_damage");

        case "kuda":
            return GetWeapon("smg_standard");

        case "vmp":
            return GetWeapon("smg_versatile");

        case "krm":
        case "krm262":
            return GetWeapon("shotgun_pump");

        case "brecci":
        case "205brecci":
            return GetWeapon("shotgun_semiauto");

        case "haymaker":
        case "haymaker12":
            return GetWeapon("shotgun_fullauto");

        case "argus":
            return GetWeapon("shotgun_precision");

        case "brm":
            return GetWeapon("lmg_light");

        case "dingo":
            return GetWeapon("lmg_cqb");

        case "gorgon":
            return GetWeapon("lmg_slowfire");

        case "dredge":
        case "48dredge":
            return GetWeapon("lmg_heavy");

        case "drakon":
            return GetWeapon("sniper_fastsemi");

        case "locus":
            return GetWeapon("sniper_fastbolt");

        case "svg":
        case "svg100":
            return GetWeapon("sniper_powerbolt");
    }

    return undefined;
}

function weapons_is_core_alias(alias)
{
    return isdefined(weapons_resolve_core_alias(alias));
}

// ------------------------------------------------------------
// Candidate catalog
// ------------------------------------------------------------

function weapons_add_apothicon_candidates(candidates, upgraded)
{
    if (upgraded)
    {
        candidates = weapons_add_candidate(candidates, "idgun_upgraded_0");
        candidates = weapons_add_candidate(candidates, "idgun_upgraded_1");
        candidates = weapons_add_candidate(candidates, "idgun_upgraded_2");
        candidates = weapons_add_candidate(candidates, "idgun_upgraded_3");
        candidates = weapons_add_candidate(candidates, "idgun_upgraded");
    }
    else
    {
        candidates = weapons_add_candidate(candidates, "idgun_0");
        candidates = weapons_add_candidate(candidates, "idgun_1");
        candidates = weapons_add_candidate(candidates, "idgun_2");
        candidates = weapons_add_candidate(candidates, "idgun_3");
        candidates = weapons_add_candidate(candidates, "idgun");
    }

    return candidates;
}

function weapons_add_apothicon_sword_candidates(candidates)
{
    candidates = weapons_add_candidate(candidates, "glaive_apothicon_0");
    candidates = weapons_add_candidate(candidates, "glaive_apothicon_1");
    candidates = weapons_add_candidate(candidates, "glaive_apothicon_2");
    candidates = weapons_add_candidate(candidates, "glaive_apothicon_3");
    candidates = weapons_add_candidate(candidates, "glaive_apothicon");

    return candidates;
}

function weapons_add_keeper_sword_candidates(candidates)
{
    candidates = weapons_add_candidate(candidates, "glaive_keeper_0");
    candidates = weapons_add_candidate(candidates, "glaive_keeper_1");
    candidates = weapons_add_candidate(candidates, "glaive_keeper_2");
    candidates = weapons_add_candidate(candidates, "glaive_keeper_3");
    candidates = weapons_add_candidate(candidates, "glaive_keeper");

    return candidates;
}

function weapons_get_special_candidates(map_name, alias)
{
    candidates = [];

    // Shared Chronicles / box weapon.
    switch (alias)
    {
        case "raygunmk2":
        case "raygun2":
        case "mk2":
        case "rgmk2":
            return weapons_add_candidate(candidates, "raygun_mark2");

        case "raygunmk2up":
        case "mk2up":
            return weapons_add_candidate(candidates, "raygun_mark2_upgraded");
    }

    switch (map_name)
    {
        // ----------------------------------------------------
        // Shadows of Evil
        // ----------------------------------------------------
        case "zm_zod":
            switch (alias)
            {
                case "apothicon":
                case "servant":
                case "apothiconservant":
                    return weapons_add_apothicon_candidates(candidates, false);

                case "apothiconup":
                case "servantup":
                    return weapons_add_apothicon_candidates(candidates, true);

                case "arnies":
                case "lilarnies":
                case "octobomb":
                    return weapons_add_candidate(candidates, "octobomb");

                case "arniesup":
                case "octobombup":
                    return weapons_add_candidate(candidates, "octobomb_upgraded");

                case "annihilator":
                    return weapons_add_candidate(candidates, "hero_annihilator");

                case "apothiconsword":
                case "sword":
                    return weapons_add_apothicon_sword_candidates(candidates);

                case "keepersword":
                    return weapons_add_keeper_sword_candidates(candidates);
            }
            break;

        // ----------------------------------------------------
        // The Giant
        // ----------------------------------------------------
        case "zm_factory":
            switch (alias)
            {
                case "wunderwaffe":
                case "waffe":
                case "dg2":
                case "tesla":
                    return weapons_add_candidate(candidates, "tesla_gun");

                case "wunderwaffeup":
                case "waffeup":
                case "dg2up":
                    return weapons_add_candidate(candidates, "tesla_gun_upgraded");

                case "annihilator":
                    return weapons_add_candidate(candidates, "hero_annihilator");
            }
            break;

        // ----------------------------------------------------
        // Der Eisendrache
        // ----------------------------------------------------
        case "zm_castle":
            switch (alias)
            {
                case "bow":
                case "wrath":
                case "wota":
                    return weapons_add_candidate(candidates, "elemental_bow");

                case "stormbow":
                case "lightningbow":
                case "storm":
                    return weapons_add_candidate(candidates, "elemental_bow_storm");

                case "firebow":
                case "magma":
                    return weapons_add_candidate(candidates, "elemental_bow_rune_prison");

                case "wolfbow":
                case "wolf":
                    return weapons_add_candidate(candidates, "elemental_bow_wolf_howl");

                case "voidbow":
                case "void":
                    return weapons_add_candidate(candidates, "elemental_bow_demongate");

                case "ragnarok":
                case "ragnaroks":
                case "dg4":
                    return weapons_add_candidate(candidates, "hero_gravityspikes_melee");
            }
            break;

        // ----------------------------------------------------
        // Zetsubou No Shima
        // ----------------------------------------------------
        case "zm_island":
            switch (alias)
            {
                case "kt4":
                    return weapons_add_candidate(candidates, "hero_mirg2000");

                case "masamune":
                case "kt4up":
                    return weapons_add_candidate(candidates, "hero_mirg2000_upgraded_2");

                case "skull":
                case "nansapwe":
                    return weapons_add_candidate(candidates, "skull_gun");
            }
            break;

        // ----------------------------------------------------
        // Gorod Krovi
        // ----------------------------------------------------
        case "zm_stalingrad":
            switch (alias)
            {
                case "raygunmk3":
                case "mk3":
                case "gkz":
                case "gkz45":
                    return weapons_add_candidate(candidates, "raygun_mark3");

                case "raygunmk3up":
                case "mk3up":
                case "gkzup":
                    return weapons_add_candidate(candidates, "raygun_mark3_upgraded");

                case "gauntlet":
                case "siegfried":
                    candidates = weapons_add_candidate(candidates, "hero_gauntlet");
                    candidates = weapons_add_candidate(candidates, "hero_siegfried");
                    return weapons_add_candidate(candidates, "hero_dragon_gauntlet");

                case "dragonstrike":
                case "dragon_strike":
                    candidates = weapons_add_candidate(candidates, "dragon_strike");
                    candidates = weapons_add_candidate(candidates, "airstrike_marker");
                    return weapons_add_candidate(candidates, "hero_dragon_strike");
            }
            break;

        // ----------------------------------------------------
        // Revelations
        // ----------------------------------------------------
        case "zm_genesis":
            switch (alias)
            {
                case "apothicon":
                case "servant":
                case "apothiconservant":
                    return weapons_add_apothicon_candidates(candidates, false);

                case "apothiconup":
                case "servantup":
                    return weapons_add_apothicon_candidates(candidates, true);

                case "thundergun":
                case "thunder":
                    return weapons_add_candidate(candidates, "thundergun");

                case "thundergunup":
                case "thunderup":
                    return weapons_add_candidate(candidates, "thundergun_upgraded");

                case "arnies":
                case "lilarnies":
                case "octobomb":
                    return weapons_add_candidate(candidates, "octobomb");

                case "arniesup":
                    return weapons_add_candidate(candidates, "octobomb_upgraded");

                case "ragnarok":
                case "ragnaroks":
                case "dg4":
                    return weapons_add_candidate(candidates, "hero_gravityspikes_melee");

                case "katana":
                    candidates = weapons_add_candidate(candidates, "hero_katana");
                    candidates = weapons_add_candidate(candidates, "katana");
                    return weapons_add_candidate(candidates, "hero_path_of_sorrows");
            }
            break;

        // ----------------------------------------------------
        // Nacht der Untoten
        // ----------------------------------------------------
        case "zm_prototype":
            switch (alias)
            {
                case "thundergun":
                case "thunder":
                    return weapons_add_candidate(candidates, "thundergun");

                case "thundergunup":
                case "thunderup":
                    return weapons_add_candidate(candidates, "thundergun_upgraded");
            }
            break;

        // ----------------------------------------------------
        // Verruckt
        // ----------------------------------------------------
        case "zm_asylum":
            switch (alias)
            {
                case "wunderwaffe":
                case "waffe":
                case "dg2":
                    return weapons_add_candidate(candidates, "tesla_gun");

                case "wunderwaffeup":
                case "waffeup":
                    return weapons_add_candidate(candidates, "tesla_gun_upgraded");
            }
            break;

        // ----------------------------------------------------
        // Shi No Numa
        // ----------------------------------------------------
        case "zm_sumpf":
            switch (alias)
            {
                case "wunderwaffe":
                case "waffe":
                case "dg2":
                    return weapons_add_candidate(candidates, "tesla_gun");

                case "wunderwaffeup":
                case "waffeup":
                    return weapons_add_candidate(candidates, "tesla_gun_upgraded");
            }
            break;

        // ----------------------------------------------------
        // Kino der Toten
        // ----------------------------------------------------
        case "zm_theater":
            switch (alias)
            {
                case "thundergun":
                case "thunder":
                    return weapons_add_candidate(candidates, "thundergun");

                case "thundergunup":
                case "thunderup":
                    return weapons_add_candidate(candidates, "thundergun_upgraded");
            }
            break;

        // ----------------------------------------------------
        // Ascension
        // ----------------------------------------------------
        case "zm_cosmodrome":
            switch (alias)
            {
                case "thundergun":
                case "thunder":
                    return weapons_add_candidate(candidates, "thundergun");

                case "thundergunup":
                case "thunderup":
                    return weapons_add_candidate(candidates, "thundergun_upgraded");

                case "gersh":
                case "gershdevice":
                    return weapons_add_candidate(candidates, "black_hole_bomb");

                case "dolls":
                case "matryoshka":
                case "nestingdolls":
                    return weapons_add_candidate(candidates, "nesting_dolls");
            }
            break;

        // ----------------------------------------------------
        // Shangri-La
        // ----------------------------------------------------
        case "zm_temple":
            switch (alias)
            {
                case "babygun":
                case "shrinkray":
                case "jgb":
                    return weapons_add_candidate(candidates, "shrink_ray");

                case "babygunup":
                case "shrinkrayup":
                case "jgbup":
                    return weapons_add_candidate(candidates, "shrink_ray_upgraded");

                case "monkey":
                case "monkeybomb":
                    return weapons_add_candidate(candidates, "cymbal_monkey");
            }
            break;

        // ----------------------------------------------------
        // Moon
        // ----------------------------------------------------
        case "zm_moon":
            switch (alias)
            {
                case "wavegun":
                case "zapgun":
                    candidates = weapons_add_candidate(candidates, "microwavegundw");
                    return weapons_add_candidate(candidates, "microwavegun");

                case "wavegunup":
                case "zapgunup":
                    candidates = weapons_add_candidate(candidates, "microwavegundw_upgraded");
                    return weapons_add_candidate(candidates, "microwavegun_upgraded");

                case "qed":
                    return weapons_add_candidate(candidates, "quantum_bomb");

                case "gersh":
                case "gershdevice":
                    return weapons_add_candidate(candidates, "black_hole_bomb");
            }
            break;

        // ----------------------------------------------------
        // Origins
        // ----------------------------------------------------
        case "zm_tomb":
            switch (alias)
            {
                case "windstaff":
                case "wind":
                case "airstaff":
                    return weapons_add_candidate(candidates, "staff_air");

                case "windstaffup":
                case "windup":
                    return weapons_add_candidate(candidates, "staff_air_upgraded");

                case "icestaff":
                case "ice":
                case "waterstaff":
                    return weapons_add_candidate(candidates, "staff_water");

                case "icestaffup":
                case "iceup":
                    return weapons_add_candidate(candidates, "staff_water_upgraded");

                case "lightningstaff":
                case "lightning":
                    return weapons_add_candidate(candidates, "staff_lightning");

                case "lightningstaffup":
                case "lightningup":
                    return weapons_add_candidate(candidates, "staff_lightning_upgraded");

                case "firestaff":
                case "fire":
                    return weapons_add_candidate(candidates, "staff_fire");

                case "firestaffup":
                case "fireup":
                    return weapons_add_candidate(candidates, "staff_fire_upgraded");

                case "gstrike":
                case "g-strike":
                case "beacon":
                    return weapons_add_candidate(candidates, "beacon");

                case "oneinch":
                case "fists":
                    return weapons_add_candidate(candidates, "one_inch_punch");

                case "firefists":
                    return weapons_add_candidate(candidates, "one_inch_punch_fire");

                case "icefists":
                    return weapons_add_candidate(candidates, "one_inch_punch_ice");

                case "windfists":
                    return weapons_add_candidate(candidates, "one_inch_punch_air");

                case "lightningfists":
                    return weapons_add_candidate(candidates, "one_inch_punch_lightning");
            }
            break;
    }

    return candidates;
}

function weapons_resolve_alias(alias)
{
    core_weapon = weapons_resolve_core_alias(alias);

    if (isdefined(core_weapon))
        return core_weapon;

    candidates = weapons_get_special_candidates(
        weapons_get_map_name(),
        alias
    );

    return weapons_find_first_registered(candidates);
}

function weapons_alias_known(alias)
{
    if (weapons_is_core_alias(alias))
        return true;

    candidates = weapons_get_special_candidates(
        weapons_get_map_name(),
        alias
    );

    return candidates.size > 0;
}

// ------------------------------------------------------------
// Map-specific alias displays
// ------------------------------------------------------------

function weapons_print_special_aliases(map_name)
{
    switch (map_name)
    {
        case "zm_zod":
            println("^7apothicon, apothiconup, arnies, arniesup");
            println("^7annihilator, apothiconsword, keepersword");
            return;

        case "zm_factory":
            println("^7wunderwaffe, wunderwaffeup, annihilator");
            return;

        case "zm_castle":
            println("^7bow, stormbow, firebow, wolfbow, voidbow");
            println("^7ragnarok");
            return;

        case "zm_island":
            println("^7kt4, masamune, skull");
            return;

        case "zm_stalingrad":
            println("^7raygunmk3, raygunmk3up, gauntlet, dragonstrike");
            return;

        case "zm_genesis":
            println("^7apothicon, apothiconup, thundergun, arnies");
            println("^7ragnarok, katana");
            return;

        case "zm_prototype":
            println("^7thundergun");
            return;

        case "zm_asylum":
        case "zm_sumpf":
            println("^7wunderwaffe");
            return;

        case "zm_theater":
            println("^7thundergun");
            return;

        case "zm_cosmodrome":
            println("^7thundergun, gersh, dolls");
            return;

        case "zm_temple":
            println("^7babygun, babygunup, monkey");
            return;

        case "zm_moon":
            println("^7wavegun, wavegunup, qed, gersh");
            return;

        case "zm_tomb":
            println("^7windstaff, icestaff, lightningstaff, firestaff");
            println("^7windstaffup, icestaffup, lightningstaffup, firestaffup");
            println("^7gstrike, oneinch, firefists, icefists");
            println("^7windfists, lightningfists");
            return;
    }

    println("^3No official special catalog for this map");
}

function cmd_ezzweapons(args)
{
    println("^5========== PinteMod WEAPONS v0.5.2 ==========");
    println("^7Assault: kn44, hvk, icr, manowar");
    println("^7SMG: kuda, vmp");
    println("^7Shotguns: krm, brecci, haymaker, argus");
    println("^7LMG: brm, dingo, gorgon, dredge");
    println("^7Snipers: drakon, locus, svg");
    println("^7Universal: raygun, raygunmk2");
    println("^3Use ezzwonderweapons for current-map specials");
    println("^3Use ezzweaponstatus <alias> before testing");
    println("^5========================================");
}

function cmd_ezzwonderweapons(args)
{
    map_name = weapons_get_map_name();

    println("^5========== MAP SPECIAL WEAPONS ==========");
    println("^7Map: " + weapons_get_map_display_name(map_name));
    println("^7Internal ID: " + map_name);
    println("^7Shared when registered: raygun, raygunmk2");

    weapons_print_special_aliases(map_name);

    println("^3Availability is checked against map registries");
    println("^5=========================================");
}

function cmd_ezzweaponstatus(args)
{
    if (args.size <= 0)
    {
        println("^5[PinteMod]^7 Usage: ezzweaponstatus <alias>");
        return;
    }

    alias = toLower(args[0]);
    weapon = weapons_resolve_alias(alias);

    if (isdefined(weapon))
    {
        println("^2[PinteMod] AVAILABLE: " + alias);
        println("^5[PinteMod]^7 Internal name: " + weapon.name);

        if (weapons_is_registered_hero_weapon(weapon))
            println("^3[PinteMod]^7 Type: registered hero weapon");
        else
            println("^5[PinteMod]^7 Type: standard/special weapon");

        return;
    }

    if (weapons_alias_known(alias))
    {
        println("^1[PinteMod] UNAVAILABLE ON THIS MAP: " + alias);
        println("^3[PinteMod]^7 Weapon was not found in native registries");
        return;
    }

    println("^1[PinteMod] UNKNOWN ALIAS: " + alias);
    println("^5[PinteMod]^7 Use ezzweapons and ezzwonderweapons");
}

// ------------------------------------------------------------
// Give weapon
// ------------------------------------------------------------

function cmd_ezzweapon(args)
{
    player = undefined;
    alias = "";

    if (args.size == 1)
    {
        named_player = weapons_find_player_exact(args[0]);

        if (isdefined(named_player))
        {
            println("^1[PinteMod] Missing weapon alias after player: " + args[0]);
            weapons_print_usage();
            return;
        }

        player = weapons_get_first_player();
        alias = toLower(args[0]);
    }
    else if (args.size >= 2)
    {
        player = weapons_find_player_exact(args[0]);
        alias = toLower(args[1]);
    }
    else
    {
        weapons_print_usage();
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

    weapon = weapons_resolve_alias(alias);

    if (!isdefined(weapon))
    {
        if (weapons_alias_known(alias))
            println("^1[PinteMod] Alias unavailable on this map: " + alias);
        else
            println("^1[PinteMod] Unknown alias: " + alias);

        println("^5[PinteMod]^7 Use ezzweaponstatus " + alias);
        return;
    }

    given_weapon = player zm_weapons::weapon_give(
        weapon,
        false,
        false,
        true,
        true
    );

    if (!isdefined(given_weapon))
    {
        println("^1[PinteMod] Native weapon_give failed: " + alias);
        return;
    }

    weapons_mark_gameplay_command(
        "weapon " + alias,
        player.name
    );

    if (weapons_is_registered_hero_weapon(weapon))
    {
        player GadgetPowerSet(0, 100);
        println("^3[PinteMod]^7 Hero power filled to 100");
    }

    println("^5[PinteMod]^7 " + alias + " given to " + player.name);
    println("^5[PinteMod]^7 Internal: " + weapon.name);
    player iprintln("^2Weapon added: ^7" + alias);
}

// ------------------------------------------------------------
// Inventory diagnostic
// ------------------------------------------------------------

function cmd_ezzhasweapon(args)
{
    player = undefined;
    alias = "";

    if (args.size == 1)
    {
        named_player = weapons_find_player_exact(args[0]);

        if (isdefined(named_player))
        {
            println("^1[PinteMod] Missing weapon alias after player: " + args[0]);
            weapons_print_has_usage();
            return;
        }

        player = weapons_get_first_player();
        alias = toLower(args[0]);
    }
    else if (args.size >= 2)
    {
        player = weapons_find_player_exact(args[0]);
        alias = toLower(args[1]);
    }
    else
    {
        weapons_print_has_usage();
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

    weapon = weapons_resolve_alias(alias);

    if (!isdefined(weapon))
    {
        if (weapons_alias_known(alias))
            println("^1[PinteMod] Alias unavailable on this map: " + alias);
        else
            println("^1[PinteMod] Unknown alias: " + alias);

        return;
    }

    if (player zm_weapons::has_weapon_or_upgrade(weapon))
        println("^2[PinteMod] " + player.name + " has " + alias);
    else
        println("^1[PinteMod] " + player.name + " does not have " + alias);
}

// ------------------------------------------------------------
// Pack-a-Punch the currently held weapon
// ------------------------------------------------------------

function weapons_get_optional_target(args)
{
    if (args.size > 0)
        return weapons_find_player_exact(args[0]);

    return weapons_get_first_player();
}

function cmd_ezzpapweapon(args)
{
    player = weapons_get_optional_target(args);

    if (!isdefined(player))
    {
        if (args.size > 0)
            println("^1[PinteMod] Player not found: " + args[0]);
        else
            println("^1[PinteMod] No connected player");

        return;
    }

    current_weapon = player GetCurrentWeapon();

    if (!isdefined(current_weapon) ||
        current_weapon == level.weaponNone ||
        current_weapon == level.weaponZMFists)
    {
        println("^1[PinteMod] No valid current weapon for " + player.name);
        player iprintln("^1Hold a primary weapon first");
        return;
    }

    if (zm_weapons::is_weapon_upgraded(current_weapon))
    {
        println("^3[PinteMod]^7 Current weapon is already upgraded");
        player iprintln("^3Current weapon is already Pack-a-Punched");
        return;
    }

    if (!zm_weapons::can_upgrade_weapon(current_weapon))
    {
        println(
            "^1[PinteMod] Weapon cannot be upgraded: " +
            current_weapon.name
        );
        player iprintln("^1This weapon cannot be Pack-a-Punched");
        return;
    }

    upgraded_weapon = zm_weapons::get_upgrade_weapon(
        current_weapon,
        false
    );

    if (!isdefined(upgraded_weapon) ||
        upgraded_weapon == level.weaponNone ||
        upgraded_weapon == current_weapon)
    {
        println("^1[PinteMod] Native upgrade resolver failed");
        player iprintln("^1Pack-a-Punch upgrade failed");
        return;
    }

    // Remove the base weapon through the native take callback so the
    // upgraded version occupies the same effective inventory slot.
    player zm_weapons::weapon_take(current_weapon);

    given_weapon = player zm_weapons::weapon_give(
        upgraded_weapon,
        true,
        false,
        true,
        true
    );

    if (!isdefined(given_weapon))
    {
        println("^1[PinteMod] Upgraded weapon give failed");

        // Best-effort restoration of the original weapon.
        player zm_weapons::weapon_give(
            current_weapon,
            false,
            false,
            true,
            true
        );

        player iprintln("^1Pack-a-Punch failed; base weapon restored");
        return;
    }

    weapons_mark_gameplay_command(
        "pap weapon",
        player.name
    );
    player GiveMaxAmmo(given_weapon);

    println(
        "^2[PinteMod] Pack-a-Punched for " + player.name +
        ": " + current_weapon.name + " -> " + given_weapon.name
    );

    player iprintln("^2Current weapon Pack-a-Punched");
}
