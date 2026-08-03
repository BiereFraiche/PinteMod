// ============================================================
// PinteMod — Profils des maps officielles v0.11.0
// Fichier : ezz_admin_maps.gsc
// Créé par BiereFraiche et ChatGPT
//
// Courant, Pack-a-Punch et ouvertures standards sur les
// quatorze maps Zombies officielles de Black Ops III.
// ============================================================

#using scripts\shared\flag_shared;
#using scripts\shared\util_shared;

#using scripts\zm\_zm_pack_a_punch_util;
#using scripts\zm\_zm_power;
#using custom_scripts\ezz_admin_registry;


// ------------------------------------------------------------
// Global PinteMod message without BO3's [All]UnknownSoldier prefix
// ------------------------------------------------------------

function maps_broadcast(message)
{
    players = GetPlayers();

    for (i = 0; i < players.size; i++)
    {
        player = players[i];

        if (isdefined(player))
            player iprintln(message);
    }
}

function maps_mark_gameplay_command(command_name, target_name)
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
    level.pintemod_maps_loaded = true;
    level.pintemod_maps_version = "0.11.0";
    addcommand("ezzmap", ::cmd_ezzmap);
    addcommand("ezzmapstatus", ::cmd_ezzmapstatus);
    addcommand("ezzmaps", ::cmd_ezzmaps);
    addcommand("ezzpowerstatus", ::cmd_ezzpowerstatus);
    addcommand("ezzpower", ::cmd_ezzpower);

    addcommand("ezzpapstatus", ::cmd_ezzpapstatus);
    addcommand("ezzpap", ::cmd_ezzpap);

    addcommand("ezzunlockstatus", ::cmd_ezzunlockstatus);
    addcommand("ezzunlock", ::cmd_ezzunlock);

    println("^5[PinteMod]^7 Maps v0.11.0 loaded");
}

// ------------------------------------------------------------
// Map information
// ------------------------------------------------------------

function maps_get_name()
{
    return toLower(GetDvarString("mapname"));
}

function maps_profile_is_official(map_name)
{
    return ezz_admin_registry::is_official_map(map_name);
}

function maps_profile_display_name(map_name)
{
    return ezz_admin_registry::get_map_display_name(map_name);
}

function maps_profile_collection(map_name)
{
    return ezz_admin_registry::get_map_collection(map_name);
}

function maps_profile_power_mode(map_name)
{
    switch (map_name)
    {
        case "zm_prototype":
            return "none";

        case "zm_zod":
            return "local_beast";

        case "zm_island":
            return "dual_generator";

        case "zm_genesis":
            return "corruption";

        case "zm_tomb":
            return "six_generators";

        case "zm_factory":
        case "zm_castle":
        case "zm_stalingrad":
        case "zm_asylum":
        case "zm_sumpf":
        case "zm_theater":
        case "zm_cosmodrome":
        case "zm_temple":
        case "zm_moon":
            return "standard";
    }

    return "unknown";
}

function maps_profile_power_text(map_name)
{
    mode = maps_profile_power_mode(map_name);

    switch (mode)
    {
        case "none":
            return "Not applicable";

        case "standard":
            return "Standard global power";

        case "local_beast":
            return "Local Beast-mode switches";

        case "dual_generator":
            return "Map-specific dual generator system";

        case "corruption":
            return "Map-specific corruption engine system";

        case "six_generators":
            return "Six map-specific generators";
    }

    return "Unknown / custom";
}

function maps_profile_pap_mode(map_name)
{
    switch (map_name)
    {
        case "zm_prototype":
        case "zm_asylum":
        case "zm_sumpf":
            return "none";

        case "zm_zod":
            return "rituals";

        case "zm_factory":
            return "three_teleporters";

        case "zm_castle":
            return "map_specific";

        case "zm_island":
            return "machine_parts";

        case "zm_stalingrad":
            return "dragon_access";

        case "zm_genesis":
            return "apothicon_access";

        case "zm_theater":
            return "teleporter";

        case "zm_cosmodrome":
            return "rocket";

        case "zm_temple":
            return "pressure_plates";

        case "zm_moon":
            return "area51";

        case "zm_tomb":
            return "six_generators";
    }

    return "unknown";
}

function maps_profile_pap_text(map_name)
{
    mode = maps_profile_pap_mode(map_name);

    switch (mode)
    {
        case "none":
            return "No native Pack-a-Punch machine";

        case "rituals":
            return "Ritual access";

        case "three_teleporters":
            return "Three teleporter links";

        case "map_specific":
            return "Map-specific access sequence";

        case "machine_parts":
            return "Machine construction / parts";

        case "dragon_access":
            return "Dragon transport access";

        case "apothicon_access":
            return "Apothicon access";

        case "teleporter":
            return "Teleporter access";

        case "rocket":
            return "Rocket launch access";

        case "pressure_plates":
            return "Pressure-plate access";

        case "area51":
            return "Area 51 machine";

        case "six_generators":
            return "Six generator access";
    }

    return "Unknown / custom";
}

function maps_profile_unlock_text(map_name)
{
    if (!maps_profile_is_official(map_name))
        return "Generic safe scan; custom logic skipped";

    return "Standard doors/debris supported; quest logic skipped";
}

function maps_profile_wonders(map_name)
{
    switch (map_name)
    {
        case "zm_zod":
            return "Apothicon Servant, Lil Arnies, Apothicon Sword";

        case "zm_factory":
            return "Wunderwaffe DG-2, Annihilator";

        case "zm_castle":
            return "Wrath bow family, Ragnarok DG-4";

        case "zm_island":
            return "KT-4, Masamune, Skull of Nan Sapwe";

        case "zm_stalingrad":
            return "GKZ-45 Mk3, Gauntlet, Dragon Strike";

        case "zm_genesis":
            return "Apothicon Servant, Thundergun, Ragnarok, special melee";

        case "zm_prototype":
            return "Chronicles box wonder-weapon profile";

        case "zm_asylum":
            return "Chronicles box wonder-weapon profile";

        case "zm_sumpf":
            return "Wunderwaffe profile";

        case "zm_theater":
            return "Thundergun profile";

        case "zm_cosmodrome":
            return "Thundergun, Gersh Device, Matryoshka";

        case "zm_temple":
            return "31-79 JGb215, Monkey Bomb";

        case "zm_moon":
            return "Wave Gun, QED, Gersh Device";

        case "zm_tomb":
            return "Four Staffs, G-Strike, Ray Gun Mark II";
    }

    return "Dynamic weapon availability only";
}

function maps_profile_power_is_partial(map_name)
{
    mode = maps_profile_power_mode(map_name);

    return mode != "standard" &&
           mode != "none" &&
           mode != "unknown";
}

function maps_profile_pap_is_custom(map_name)
{
    mode = maps_profile_pap_mode(map_name);

    return mode != "none" &&
           mode != "area51" &&
           mode != "unknown";
}

function maps_print_profile_status()
{
    map_name = maps_get_name();

    println("^5========== PinteMod MAP PROFILE ==========");
    println("^7Name: " + maps_profile_display_name(map_name));
    println("^7Internal ID: " + map_name);
    println("^7Collection: " + maps_profile_collection(map_name));

    if (maps_profile_is_official(map_name))
        println("^2Profile: OFFICIAL / LOADED");
    else
        println("^3Profile: CUSTOM / GENERIC FALLBACK");

    println("^7Power handler: " + maps_profile_power_text(map_name));
    println("^7Pack-a-Punch handler: " + maps_profile_pap_text(map_name));
    println("^7Unlock handler: " + maps_profile_unlock_text(map_name));
    println("^7Wonder profile: " + maps_profile_wonders(map_name));

    println("^2Core admin: supported");
    println("^2Perks: native dynamic support");
    println("^2Power-Ups: native dynamic support");
    println("^2Zombies / rounds: supported");

    if (maps_profile_power_is_partial(map_name))
        println("^3Power completion: PARTIAL until map adapter");
    else if (maps_profile_power_mode(map_name) == "none")
        println("^7Power completion: NOT APPLICABLE");
    else
        println("^2Power completion: GENERIC SUPPORTED");

    if (maps_profile_pap_mode(map_name) == "none")
        println("^7Pack-a-Punch completion: NOT APPLICABLE");
    else if (map_name == "zm_factory")
        println("^2Pack-a-Punch completion: VALIDATED");
    else if (maps_profile_pap_is_custom(map_name))
        println("^3Pack-a-Punch access: PARTIAL until map adapter");
    else
        println("^2Pack-a-Punch machine: GENERIC SUPPORTED");

    println("^5=====================================");
}

function cmd_ezzmapstatus(args)
{
    maps_print_profile_status();
}

function cmd_ezzmaps(args)
{
    println("^5========== OFFICIAL BO3 ZOMBIES MAPS ==========");
    println("^7zm_zod        - Shadows of Evil");
    println("^7zm_factory    - The Giant");
    println("^7zm_castle     - Der Eisendrache");
    println("^7zm_island     - Zetsubou No Shima");
    println("^7zm_stalingrad - Gorod Krovi");
    println("^7zm_genesis    - Revelations");
    println("^7zm_prototype  - Nacht der Untoten");
    println("^7zm_asylum     - Verruckt");
    println("^7zm_sumpf      - Shi No Numa");
    println("^7zm_theater    - Kino der Toten");
    println("^7zm_cosmodrome - Ascension");
    println("^7zm_temple     - Shangri-La");
    println("^7zm_moon       - Moon");
    println("^7zm_tomb       - Origins");
    println("^5==============================================");
}

// ------------------------------------------------------------
// Global power helpers
// ------------------------------------------------------------

function maps_power_flag_exists()
{
    return level flag::exists("power_on");
}

function maps_power_is_on()
{
    if (!maps_power_flag_exists())
        return false;

    return level flag::get("power_on");
}

// ------------------------------------------------------------
// Pack-a-Punch helpers
// ------------------------------------------------------------

function maps_get_pap_triggers()
{
    return zm_pap_util::get_triggers();
}

function maps_count_powered_pap()
{
    triggers = maps_get_pap_triggers();
    powered_count = 0;

    for (i = 0; i < triggers.size; i++)
    {
        trigger = triggers[i];

        if (!isdefined(trigger))
            continue;

        if (!isdefined(trigger.powered))
            continue;

        if (isdefined(trigger.powered.power) && trigger.powered.power)
            powered_count++;
    }

    return powered_count;
}

function maps_giant_link_flag_is_set(flag_name)
{
    if (!level flag::exists(flag_name))
        return false;

    return level flag::get(flag_name);
}

function maps_giant_pap_is_unlocked()
{
    if (maps_get_name() != "zm_factory")
        return true;

    return maps_giant_link_flag_is_set("teleporter_pad_link_3");
}

function maps_print_pap_status()
{
    map_name = maps_get_name();
    triggers = maps_get_pap_triggers();
    powered_count = maps_count_powered_pap();

    println("^5[PinteMod]^7 Pack-a-Punch triggers: " + triggers.size);
    println("^5[PinteMod]^7 Powered machines: " + powered_count);

    if (triggers.size <= 0)
    {
        println("^1[PinteMod] No registered Pack-a-Punch machine");
        return;
    }

    if (powered_count == triggers.size)
        println("^2[PinteMod] Pack-a-Punch machine power: ON");
    else
        println("^1[PinteMod] Pack-a-Punch machine power: OFF");

    if (map_name == "zm_factory")
    {
        if (maps_giant_link_flag_is_set("teleporter_pad_link_1"))
            println("^2[PinteMod] The Giant link 1: ON");
        else
            println("^1[PinteMod] The Giant link 1: OFF");

        if (maps_giant_link_flag_is_set("teleporter_pad_link_2"))
            println("^2[PinteMod] The Giant link 2: ON");
        else
            println("^1[PinteMod] The Giant link 2: OFF");

        if (maps_giant_link_flag_is_set("teleporter_pad_link_3"))
            println("^2[PinteMod] The Giant link 3 / PaP access: ON");
        else
            println("^1[PinteMod] The Giant link 3 / PaP access: OFF");
    }
    else if (map_name == "zm_tomb")
    {
        println("^3[PinteMod]^7 Origins generators are not modified");
    }
}

// ------------------------------------------------------------
// Combined map information
// ------------------------------------------------------------

function cmd_ezzmap(args)
{
    map_name = maps_get_name();

    println("^5========== PinteMod MAP INFO v0.11.0 ==========");
    println("^7Map: " + map_name);

    if (!maps_power_flag_exists())
    {
        println("^1Global power flag: unavailable");
    }
    else if (maps_power_is_on())
    {
        println("^2Global power: ON");
    }
    else
    {
        println("^1Global power: OFF");
    }

    if (isdefined(level.round_number))
        println("^7Round: " + level.round_number);

    maps_print_pap_status();
    println("^7Profile power: " + maps_profile_power_text(map_name));
    println("^7Profile PaP: " + maps_profile_pap_text(map_name));

    println("^5==========================================");
}

// ------------------------------------------------------------
// Global power status
// ------------------------------------------------------------

function cmd_ezzpowerstatus(args)
{
    map_name = maps_get_name();
    mode = maps_profile_power_mode(map_name);

    println("^5[PinteMod]^7 Profile: " + maps_profile_power_text(map_name));

    if (mode == "none")
    {
        println("^7[PinteMod] Power is not applicable on this map");
        return;
    }

    if (!maps_power_flag_exists())
    {
        println("^1[PinteMod] Global power flag is unavailable");
        println("^3[PinteMod]^7 Map-specific logic may still be active");
        return;
    }

    if (maps_power_is_on())
        println("^2[PinteMod] Global power flag is ON");
    else
        println("^1[PinteMod] Global power flag is OFF");

    if (maps_profile_power_is_partial(map_name))
    {
        println(
            "^3[PinteMod]^7 Map objectives are not necessarily complete"
        );
    }
}

// ------------------------------------------------------------
// Turn global power on
// ------------------------------------------------------------

function cmd_ezzpower(args)
{
    map_name = maps_get_name();
    mode = maps_profile_power_mode(map_name);

    if (mode == "none")
    {
        println("^3[PinteMod]^7 No power system to enable on this map");
        return;
    }

    if (!maps_power_flag_exists())
    {
        println("^1[PinteMod] Cannot enable global power");
        println("^3[PinteMod]^7 Standard power_on flag is unavailable");
        return;
    }

    if (maps_power_is_on())
    {
        println("^3[PinteMod]^7 Global power flag is already ON");

        if (maps_profile_power_is_partial(map_name))
        {
            println(
                "^3[PinteMod]^7 Map-specific objectives may remain incomplete"
            );
        }

        return;
    }

    level zm_power::turn_power_on_and_open_doors(undefined);

    wait 0.1;

    if (maps_power_is_on())
    {
        maps_mark_gameplay_command(
        "power",
        "map"
    );
        println("^2[PinteMod] Global power flag enabled");
        maps_broadcast("^5[PinteMod]^7 ^2Power enabled");

        if (maps_profile_power_is_partial(map_name))
        {
            println(
                "^3[PinteMod]^7 Generic power only: " +
                maps_profile_power_text(map_name)
            );
            println(
                "^3[PinteMod]^7 Map-specific objectives remain unchanged"
            );
        }
    }
    else
    {
        println("^1[PinteMod] Power request executed but flag is still OFF");
    }
}

// ------------------------------------------------------------
// Pack-a-Punch status
// ------------------------------------------------------------

function cmd_ezzpapstatus(args)
{
    println("^5========== PinteMod PACK-A-PUNCH ==========");
    map_name = maps_get_name();
    println("^7Map: " + maps_profile_display_name(map_name));
    println("^7Access profile: " + maps_profile_pap_text(map_name));

    maps_print_pap_status();

    println("^5======================================");
}

// ------------------------------------------------------------
// Native Pack-a-Punch machine power
// ------------------------------------------------------------

function maps_power_all_pap_triggers()
{
    triggers = maps_get_pap_triggers();
    changed = 0;

    for (i = 0; i < triggers.size; i++)
    {
        trigger = triggers[i];

        if (!isdefined(trigger))
            continue;

        if (!isdefined(trigger.powered))
            continue;

        if (isdefined(trigger.powered.power) && trigger.powered.power)
            continue;

        // Native powered-item transition:
        // - marks the powered struct as active;
        // - invokes the Pack-a-Punch power_on callback;
        // - sends the stock Pack_A_Punch_on notification;
        // - updates the machine's normal visual and use state.
        trigger.powered zm_power::change_power(1, trigger.origin, 1);
        changed++;
    }

    return changed;
}

// ------------------------------------------------------------
// The Giant Pack-a-Punch access
// ------------------------------------------------------------

function maps_unlock_giant_pap()
{
    if (maps_get_name() != "zm_factory")
        return false;

    if (!level flag::exists("teleporter_pad_link_1") ||
        !level flag::exists("teleporter_pad_link_2") ||
        !level flag::exists("teleporter_pad_link_3"))
    {
        println("^1[PinteMod] The Giant teleporter flags are unavailable");
        return false;
    }

    changed = false;

    if (!level flag::get("teleporter_pad_link_1"))
    {
        level flag::set("teleporter_pad_link_1");
        changed = true;
    }

    if (!level flag::get("teleporter_pad_link_2"))
    {
        level flag::set("teleporter_pad_link_2");
        changed = true;
    }

    if (!level flag::get("teleporter_pad_link_3"))
    {
        level flag::set("teleporter_pad_link_3");
        changed = true;
    }

    if (!isdefined(level.active_links) || level.active_links < 3)
        level.active_links = 3;

    if (changed)
    {
        // Stock client event for the fully linked mainframe / PaP door.
        level util::clientNotify("pap1");

        println("^2[PinteMod] The Giant PaP access sequence started");
        println("^3[PinteMod]^7 Allow several seconds for the staged door animation");
    }

    return true;
}

// ------------------------------------------------------------
// Enable Pack-a-Punch
// ------------------------------------------------------------

function cmd_ezzpap(args)
{
    map_name = maps_get_name();
    pap_mode = maps_profile_pap_mode(map_name);

    if (pap_mode == "none")
    {
        println("^3[PinteMod]^7 No native Pack-a-Punch on this map");
        return;
    }

    triggers = maps_get_pap_triggers();

    if (triggers.size <= 0)
    {
        println("^1[PinteMod] No registered Pack-a-Punch machine");
        println("^3[PinteMod]^7 The map may use a completely custom system");
        return;
    }

    powered_before = maps_count_powered_pap();
    access_before = maps_giant_pap_is_unlocked();

    changed = maps_power_all_pap_triggers();

    if (maps_get_name() == "zm_factory")
        maps_unlock_giant_pap();

    wait 0.1;

    powered_after = maps_count_powered_pap();
    access_after = maps_giant_pap_is_unlocked();
    pap_changed = changed > 0 || (!access_before && access_after);

    if (pap_changed)
    {
        maps_mark_gameplay_command(
        "enable pack-a-punch",
        "map"
    );
    }

    if (powered_after == triggers.size && access_after)
    {
        if (changed <= 0 && powered_before == triggers.size && access_before)
        {
            println("^3[PinteMod]^7 Pack-a-Punch is already enabled");
        }
        else
        {
            println("^2[PinteMod] Pack-a-Punch enabled");
            maps_broadcast("^5[PinteMod]^7 ^2Pack-a-Punch enabled");
        }

        if (maps_profile_pap_is_custom(map_name) &&
            map_name != "zm_factory")
        {
            println(
                "^3[PinteMod]^7 Machine power changed, but access profile is: " +
                maps_profile_pap_text(map_name)
            );
            println(
                "^3[PinteMod]^7 Map-specific access or quest state may remain"
            );
        }

        return;
    }

    println("^1[PinteMod] Pack-a-Punch activation is incomplete");
    maps_print_pap_status();
}

// ------------------------------------------------------------
// Standard doors and debris helpers
// ------------------------------------------------------------

function maps_string_in_array(values, value)
{
    for (i = 0; i < values.size; i++)
    {
        if (values[i] == value)
            return true;
    }

    return false;
}

function maps_get_unlock_actor()
{
    players = GetPlayers();

    if (players.size <= 0)
        return undefined;

    return players[0];
}

function maps_get_door_type(door)
{
    if (!isdefined(door.script_noteworthy))
        return "default";

    return door.script_noteworthy;
}

function maps_is_standard_unlock_door(door)
{
    if (!isdefined(door))
        return false;

    if (!isdefined(door.target))
        return false;

    door_type = maps_get_door_type(door);

    switch (door_type)
    {
        case "default":
        case "delay_door":
            return true;

        case "electric_buyable_door":
            // Its native door_think waits for the trigger's power_on
            // notification before it starts waiting for a purchase.
            if (isdefined(door.power_on) && door.power_on)
                return true;

            return false;
    }

    return false;
}

function maps_is_buyable_debris(debris)
{
    if (!isdefined(debris))
        return false;

    if (!isdefined(debris.target))
        return false;

    // Standard buyable debris carries a cost. This deliberately avoids
    // firing arbitrary targetname="zombie_debris" quest objects.
    if (!isdefined(debris.zombie_cost))
        return false;

    if (debris.zombie_cost < 0)
        return false;

    return true;
}

function maps_collect_unlock_status()
{
    result = [];
    result[0] = 0; // opened standard doors
    result[1] = 0; // closed standard doors
    result[2] = 0; // remaining standard debris
    result[3] = 0; // custom / unsupported unique doors
    result[4] = 0; // powered buyable doors waiting for power

    processed_targets = [];
    doors = GetEntArray("zombie_door", "targetname");

    for (i = 0; i < doors.size; i++)
    {
        door = doors[i];

        if (!isdefined(door) || !isdefined(door.target))
            continue;

        if (maps_string_in_array(processed_targets, door.target))
            continue;

        processed_targets[processed_targets.size] = door.target;
        door_type = maps_get_door_type(door);

        if (door_type == "electric_buyable_door" &&
            (!isdefined(door.power_on) || !door.power_on))
        {
            result[4]++;
            continue;
        }

        if (!maps_is_standard_unlock_door(door))
        {
            result[3]++;
            continue;
        }

        if (isdefined(door._door_open) && door._door_open)
            result[0]++;
        else
            result[1]++;
    }

    processed_targets = [];
    debris_array = GetEntArray("zombie_debris", "targetname");

    for (i = 0; i < debris_array.size; i++)
    {
        debris = debris_array[i];

        if (!maps_is_buyable_debris(debris))
            continue;

        if (maps_string_in_array(processed_targets, debris.target))
            continue;

        processed_targets[processed_targets.size] = debris.target;

        if (!isdefined(debris.ezz_unlock_queued) ||
            !debris.ezz_unlock_queued)
        {
            result[2]++;
        }
    }

    return result;
}

function maps_print_unlock_status()
{
    status = maps_collect_unlock_status();

    println("^5[PinteMod]^7 Standard doors open: " + status[0]);
    println("^5[PinteMod]^7 Standard doors closed: " + status[1]);
    println("^5[PinteMod]^7 Buyable debris remaining: " + status[2]);
    println("^3[PinteMod]^7 Custom/quest doors skipped: " + status[3]);

    if (status[4] > 0)
    {
        println(
            "^3[PinteMod]^7 Powered buyable doors waiting for power: " +
            status[4]
        );
    }
}

// ------------------------------------------------------------
// Unlock status
// ------------------------------------------------------------

function cmd_ezzunlockstatus(args)
{
    println("^5========== PinteMod UNLOCK STATUS ==========");
    map_name = maps_get_name();
    println("^7Map: " + maps_profile_display_name(map_name));
    println("^7Profile: " + maps_profile_unlock_text(map_name));

    maps_print_unlock_status();

    println("^5=======================================");
}

// ------------------------------------------------------------
// Open standard doors through their native forced trigger
// ------------------------------------------------------------

function maps_force_standard_doors(actor)
{
    result = [];
    result[0] = 0; // queued
    result[1] = 0; // skipped custom
    result[2] = 0; // waiting power

    processed_targets = [];
    doors = GetEntArray("zombie_door", "targetname");

    for (i = 0; i < doors.size; i++)
    {
        door = doors[i];

        if (!isdefined(door) || !isdefined(door.target))
            continue;

        if (maps_string_in_array(processed_targets, door.target))
            continue;

        processed_targets[processed_targets.size] = door.target;
        door_type = maps_get_door_type(door);

        if (door_type == "electric_buyable_door" &&
            (!isdefined(door.power_on) || !door.power_on))
        {
            result[2]++;
            continue;
        }

        if (!maps_is_standard_unlock_door(door))
        {
            result[1]++;
            continue;
        }

        if (isdefined(door._door_open) && door._door_open)
            continue;

        // The native door_buy() path accepts force=true and bypasses
        // UseButtonPressed, score checks and point deductions.
        door notify("trigger", actor, true);
        result[0]++;

        // Spread the native animations across server frames.
        wait 0.05;
    }

    return result;
}

// ------------------------------------------------------------
// Remove standard buyable debris through its native forced trigger
// ------------------------------------------------------------

function maps_force_standard_debris(actor)
{
    queued = 0;
    processed_targets = [];
    debris_array = GetEntArray("zombie_debris", "targetname");

    for (i = 0; i < debris_array.size; i++)
    {
        debris = debris_array[i];

        if (!maps_is_buyable_debris(debris))
            continue;

        if (maps_string_in_array(processed_targets, debris.target))
            continue;

        processed_targets[processed_targets.size] = debris.target;

        if (isdefined(debris.ezz_unlock_queued) &&
            debris.ezz_unlock_queued)
        {
            continue;
        }

        debris.ezz_unlock_queued = true;

        // Native debris_think() bypasses the purchase when force=true,
        // then sets flags, moves/deletes pieces, reconnects navigation,
        // removes clips and deletes all linked use triggers.
        debris notify("trigger", actor, true);
        queued++;

        wait 0.05;
    }

    return queued;
}

// ------------------------------------------------------------
// Unlock all supported standard passages
// ------------------------------------------------------------

function cmd_ezzunlock(args)
{
    actor = maps_get_unlock_actor();

    if (!isdefined(actor))
    {
        println("^1[PinteMod] A connected player is required");
        return;
    }

    door_result = maps_force_standard_doors(actor);
    debris_queued = maps_force_standard_debris(actor);

    println("^2[PinteMod] Standard unlock requested");
    println("^5[PinteMod]^7 Doors queued: " + door_result[0]);
    println("^5[PinteMod]^7 Debris queued: " + debris_queued);
    println("^3[PinteMod]^7 Custom/quest doors skipped: " + door_result[1]);
    println(
        "^3[PinteMod]^7 Profile rule: " +
        maps_profile_unlock_text(maps_get_name())
    );

    if (door_result[2] > 0)
    {
        println(
            "^3[PinteMod]^7 Powered doors waiting for ezzpower: " +
            door_result[2]
        );
    }

    if (door_result[0] <= 0 && debris_queued <= 0)
    {
        println("^3[PinteMod]^7 Nothing new to unlock");
    }
    else
    {
        maps_mark_gameplay_command(
        "unlock passages",
        "map"
    );
        maps_broadcast("^5[PinteMod]^7 ^2Standard passages unlocked");
    }
}
