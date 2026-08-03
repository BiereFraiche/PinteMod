// ============================================================
// PinteMod — Events Validated Bosses v0.6.2
// Fichier : ezz_admin_events.gsc
// Créé par BiereFraiche et ChatGPT
//
// Boss natifs pris en charge selon la map : Margwa, Panzer, Thrasher,
// Mechz, Astronaut et variantes compatibles.
//
// Aucun import de script stock.
// Aucun enregistrement de ClientField.
// Aucun appel direct aux systèmes de spawner de la map.
//
// COMMANDES CONSOLE
// ------------------------------------------------------------
// ezzeventstatus
// ezzspawnboss <PlayerName|BOIII_XUID|ClientNumber>
// ezzspawnmargwa <PlayerName|BOIII_XUID|ClientNumber>
// ezzspawnpanzer <PlayerName|BOIII_XUID|ClientNumber>
// ============================================================


// ------------------------------------------------------------
// Global PinteMod message without BO3's [All]UnknownSoldier prefix
// ------------------------------------------------------------

#using custom_scripts\ezz_admin_identity;

function events_broadcast(message)
{
    players = GetPlayers();

    for (i = 0; i < players.size; i++)
    {
        player = players[i];

        if (isdefined(player))
            player iprintln(message);
    }
}

function events_mark_gameplay_command(command_name, target_name)
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
    addcommand("ezzeventstatus", ::cmd_ezzeventstatus);
    addcommand("ezzspawnmargwa", ::cmd_ezzspawnmargwa);
    addcommand("ezzspawnpanzer", ::cmd_ezzspawnpanzer);
    addcommand("ezzspawnboss", ::cmd_ezzspawnboss);
    addcommand("ezzspawncastlepanzer", ::cmd_ezzspawncastlepanzer);
    addcommand("ezzspawnthrasher", ::cmd_ezzspawnthrasher);
    addcommand("ezzspawnstalingradpanzer", ::cmd_ezzspawnstalingradpanzer);
    addcommand("ezzspawngenesismargwa", ::cmd_ezzspawngenesismargwa);
    addcommand("ezzspawngenesisshadow", ::cmd_ezzspawngenesisshadow);
    addcommand("ezzspawngenesisfire", ::cmd_ezzspawngenesisfire);
    addcommand("ezzspawngenesispanzer", ::cmd_ezzspawngenesispanzer);
    addcommand("ezzspawnastro", ::cmd_ezzspawnastro);

    level.pintemod_events_loaded = true;
    level.pintemod_events_version = "0.6.2";

    println(
        "^5[PinteMod]^7 Events v0.6.2 loaded"
    );
}


function events_feature_enabled()
{
    if (!isdefined(level.pintemod_enable_events))
        return true;

    return level.pintemod_enable_events;
}

function events_register_boss(actor)
{
    if (!isdefined(actor))
        return;

    if (!isdefined(level.pintemod_spawned_bosses))
        level.pintemod_spawned_bosses = [];

    level.pintemod_spawned_bosses[
        level.pintemod_spawned_bosses.size
    ] = actor;
}

function events_count_spawned_bosses()
{
    alive = [];
    count = 0;

    if (!isdefined(level.pintemod_spawned_bosses))
    {
        level.pintemod_spawned_bosses = [];
        return 0;
    }

    for (i = 0; i < level.pintemod_spawned_bosses.size; i++)
    {
        actor = level.pintemod_spawned_bosses[i];

        if (!isdefined(actor) || !IsAlive(actor))
            continue;

        alive[alive.size] = actor;
        count++;
    }

    level.pintemod_spawned_bosses = alive;
    return count;
}

function events_can_spawn()
{
    if (!events_feature_enabled())
    {
        println("^3[PinteMod]^7 Events feature is disabled");
        return false;
    }

    max_bosses = 2;

    if (isdefined(level.pintemod_max_spawned_bosses))
        max_bosses = level.pintemod_max_spawned_bosses;

    current = events_count_spawned_bosses();

    if (max_bosses > 0 && current >= max_bosses)
    {
        println(
            "^3[PinteMod]^7 Boss limit reached: " +
            current + "/" + max_bosses
        );
        return false;
    }

    return true;
}

function events_find_player_exact(player_name)
{
    return ezz_admin_identity::identity_find_player(player_name);
}

function events_is_shadows()
{
    return toLower(GetDvarString("mapname")) == "zm_zod";
}


function events_is_origins()
{
    return toLower(GetDvarString("mapname")) == "zm_tomb";
}

function events_get_aim_position(player)
{
    eye = player GetEye();
    angles = player GetPlayerAngles();
    forward = AnglesToForward(angles);

    trace_end = eye + (forward * 8192);
    aim_trace = BulletTrace(eye, trace_end, false, player);

    if (aim_trace["fraction"] >= 1)
        return undefined;

    hit_position = aim_trace["position"];

    floor_start = hit_position + (0, 0, 128);
    floor_end = hit_position + (0, 0, -768);
    floor_trace = BulletTrace(
        floor_start,
        floor_end,
        false,
        player
    );

    if (floor_trace["fraction"] < 1)
        return floor_trace["position"] + (0, 0, 8);

    return hit_position + (0, 0, 8);
}

function events_position_is_safe(player, position)
{
    if (!isdefined(position))
        return false;

    if (Distance(player.origin, position) < 200)
        return false;

    return true;
}

function cmd_ezzeventstatus(args)
{
    max_bosses = 2;

    if (isdefined(level.pintemod_max_spawned_bosses))
        max_bosses = level.pintemod_max_spawned_bosses;

    println("^5========== PINTEMOD EVENTS ==========");
    println("^7Enabled: " + events_feature_enabled());
    println("^7Map: " + GetDvarString("mapname"));
    println("^7Backend: native SpawnActor");
    println("^7Added ClientFields: none");
    println(
        "^7Active PinteMod bosses: " +
        events_count_spawned_bosses() + "/" + max_bosses
    );
    println("^7Margwa: spawner_zm_zod_margwa");
    println("^7Origins Panzer: spawner_zm_tomb_mechz");
    println("^7Castle Panzer: spawner_zm_castle_mechz");
    println("^5=====================================");
}

function cmd_ezzspawnmargwa(args)
{
    if (!events_can_spawn())
        return;

    if (args.size < 1)
    {
        println(
            "^5[PinteMod]^7 Usage: " +
            "ezzspawnmargwa <PlayerName|BOIII_XUID|ClientNumber>"
        );
        return;
    }

    player = events_find_player_exact(args[0]);

    if (!isdefined(player))
    {
        println("^1[PinteMod] Player not found: " + args[0]);
        return;
    }

    spawn_position = events_get_aim_position(player);

    if (!events_position_is_safe(player, spawn_position))
    {
        println(
            "^1[PinteMod] Point visé invalide ou trop proche"
        );

        player iprintln(
            "^1[PinteMod]^7 Vise le sol à plus de 200 unités"
        );
        return;
    }

    player_angles = player GetPlayerAngles();
    spawn_angles = (0, player_angles[1], 0);

    actor = SpawnActor(
        "spawner_zm_zod_margwa",
        spawn_position,
        spawn_angles,
        undefined,
        true,
        true
    );

    if (!isdefined(actor))
    {
        println("^1[PinteMod] SpawnActor n'a retourné aucun acteur");

        player iprintln(
            "^1[PinteMod]^7 Échec de création du Margwa"
        );
        return;
    }

    events_mark_gameplay_command(
        "spawn margwa",
        player.name
    );
    events_register_boss(actor);
    actor.pintemod_spawned_event = true;
    actor.pintemod_event_type = "margwa";

    println(
        "^2[PinteMod] Margwa spawned" +
        " | map=" + GetDvarString("mapname") +
        " | player=" + player.name +
        " | position=" + spawn_position
    );

    events_broadcast(
        "^6[PinteMod]^7 Un Margwa a été invoqué par ^2" +
        player.name
    );
}

function cmd_ezzspawnpanzer(args)
{
    if (!events_can_spawn())
        return;

    if (args.size < 1)
    {
        println(
            "^5[PinteMod]^7 Usage: " +
            "ezzspawnpanzer <PlayerName|BOIII_XUID|ClientNumber>"
        );
        return;
    }

    player = events_find_player_exact(args[0]);

    if (!isdefined(player))
    {
        println("^1[PinteMod] Player not found: " + args[0]);
        return;
    }

    spawn_position = events_get_aim_position(player);

    if (!events_position_is_safe(player, spawn_position))
    {
        println(
            "^1[PinteMod] Point visé invalide ou trop proche"
        );

        player iprintln(
            "^1[PinteMod]^7 Vise le sol à plus de 200 unités"
        );
        return;
    }

    player_angles = player GetPlayerAngles();
    spawn_angles = (0, player_angles[1], 0);

    actor = SpawnActor(
        "spawner_zm_tomb_mechz",
        spawn_position,
        spawn_angles,
        undefined,
        true,
        true
    );

    if (!isdefined(actor))
    {
        println("^1[PinteMod] SpawnActor n'a retourné aucun acteur");

        player iprintln(
            "^1[PinteMod]^7 Échec de création du Panzer"
        );
        return;
    }

    events_mark_gameplay_command(
        "spawn panzer",
        player.name
    );
    events_register_boss(actor);
    actor.pintemod_spawned_event = true;
    actor.pintemod_event_type = "panzer";

    println(
        "^2[PinteMod] Panzer spawned" +
        " | map=" + GetDvarString("mapname") +
        " | player=" + player.name +
        " | position=" + spawn_position
    );

    events_broadcast(
        "^6[PinteMod]^7 Un Panzer a été invoqué par ^2" +
        player.name
    );
}

function cmd_ezzspawnboss(args)
{
    println(
        "^3[PinteMod]^7 Cross-map probe: use " +
        "ezzspawnmargwa or ezzspawnpanzer"
    );
}

function cmd_ezzspawncastlepanzer(args)
{
    if (!events_can_spawn())
        return;

    if (args.size < 1)
    {
        println(
            "^5[PinteMod]^7 Usage: " +
            "ezzspawncastlepanzer <PlayerName|BOIII_XUID|ClientNumber>"
        );
        return;
    }

    if (toLower(GetDvarString("mapname")) != "zm_castle")
    {
        println(
            "^3[PinteMod]^7 Castle Panzer available " +
            "only on Der Eisendrache"
        );
        return;
    }

    player = events_find_player_exact(args[0]);

    if (!isdefined(player))
    {
        println("^1[PinteMod] Player not found: " + args[0]);
        return;
    }

    spawn_position = events_get_aim_position(player);

    if (!events_position_is_safe(player, spawn_position))
    {
        println(
            "^1[PinteMod] Invalid or too close aimed position"
        );

        player iprintln(
            "^1[PinteMod]^7 Aim at the ground over 200 units away"
        );
        return;
    }

    player_angles = player GetPlayerAngles();
    spawn_angles = (0, player_angles[1], 0);

    actor = SpawnActor(
        "spawner_zm_castle_mechz",
        spawn_position,
        spawn_angles,
        undefined,
        true,
        true
    );

    if (!isdefined(actor))
    {
        println(
            "^1[PinteMod] SpawnActor returned no Castle Panzer"
        );

        player iprintln(
            "^1[PinteMod]^7 Castle Panzer spawn failed"
        );
        return;
    }

    events_mark_gameplay_command(
        "spawn castle panzer",
        player.name
    );
    events_register_boss(actor);
    actor.pintemod_spawned_event = true;
    actor.pintemod_event_type = "castle_panzer";

    println(
        "^2[PinteMod] Castle Panzer spawned" +
        " | player=" + player.name +
        " | position=" + spawn_position
    );

    events_broadcast(
        "^6[PinteMod]^7 A Castle Panzer was spawned by ^2" +
        player.name
    );
}

function events_spawn_type_for_player(
    args,
    required_map,
    type_name,
    display_name
)
{
    if (!events_can_spawn())
        return;

    if (args.size < 1)
    {
        println(
            "^5[PinteMod]^7 Usage: command <PlayerName|BOIII_XUID|ClientNumber>"
        );
        return;
    }

    current_map = toLower(GetDvarString("mapname"));

    if (current_map != required_map)
    {
        println(
            "^3[PinteMod]^7 " + display_name +
            " is not configured for this map"
        );
        return;
    }

    player = events_find_player_exact(args[0]);

    if (!isdefined(player))
    {
        println("^1[PinteMod] Player not found: " + args[0]);
        return;
    }

    spawn_position = events_get_aim_position(player);

    if (!events_position_is_safe(player, spawn_position))
    {
        println(
            "^1[PinteMod] Invalid or too close aimed position"
        );

        player iprintln(
            "^1[PinteMod]^7 Aim at the ground over 200 units away"
        );
        return;
    }

    player_angles = player GetPlayerAngles();
    spawn_angles = (0, player_angles[1], 0);

    actor = SpawnActor(
        type_name,
        spawn_position,
        spawn_angles,
        undefined,
        true,
        true
    );

    if (!isdefined(actor))
    {
        println(
            "^1[PinteMod] SpawnActor returned no " +
            display_name
        );

        player iprintln(
            "^1[PinteMod]^7 " + display_name +
            " spawn failed"
        );
        return;
    }

    events_mark_gameplay_command(
        "spawn " + display_name,
        player.name
    );
    events_register_boss(actor);
    actor.pintemod_spawned_event = true;
    actor.pintemod_event_type = type_name;

    println(
        "^2[PinteMod] " + display_name + " spawned" +
        " | map=" + current_map +
        " | player=" + player.name +
        " | type=" + type_name
    );

    events_broadcast(
        "^6[PinteMod]^7 " + display_name +
        " was spawned by ^2" + player.name
    );
}

function cmd_ezzspawnthrasher(args)
{
    events_spawn_type_for_player(
        args,
        "zm_island",
        "spawner_zm_island_thrasher",
        "Thrasher"
    );
}

function cmd_ezzspawnstalingradpanzer(args)
{
    events_spawn_type_for_player(
        args,
        "zm_stalingrad",
        "spawner_zm_stalingrad_mechz",
        "Stalingrad Mechz"
    );
}

function cmd_ezzspawngenesismargwa(args)
{
    events_spawn_type_for_player(
        args,
        "zm_genesis",
        "spawner_zm_genesis_margwa",
        "Genesis Margwa"
    );
}

function cmd_ezzspawngenesisshadow(args)
{
    events_spawn_type_for_player(
        args,
        "zm_genesis",
        "spawner_zm_genesis_margwa_shadow",
        "Shadow Margwa"
    );
}

function cmd_ezzspawngenesisfire(args)
{
    events_spawn_type_for_player(
        args,
        "zm_genesis",
        "spawner_zm_genesis_margwa_fire",
        "Fire Margwa"
    );
}

function cmd_ezzspawngenesispanzer(args)
{
    events_spawn_type_for_player(
        args,
        "zm_genesis",
        "spawner_zm_genesis_mechz",
        "Genesis Panzer"
    );
}

function cmd_ezzspawnastro(args)
{
    events_spawn_type_for_player(
        args,
        "zm_moon",
        "spawner_zm_moon_astro",
        "Astronaut"
    );
}
