// ============================================================
// PinteMod — Musiques spéciales toutes maps v0.5.1
// Fichier : ezz_admin_music.gsc
// Créé par BiereFraiche et ChatGPT
//
// Réutilise exclusivement le registre musicCmd déjà initialisé
// par la map. Les musiques sont envoyées à tous les joueurs
// actuellement connectés.
//
// Zetsubou No Shima reste désactivée : la map ne fournit pas le
// registre musical natif attendu sur ce serveur BOIII.
// The Giant conserve son état musical natif ; aucun override personnalisé n’est forcé.
//
// COMMANDES CONSOLE
// ------------------------------------------------------------
// ezzmusicstatus
// ezzmusicstates
// ezzmusicplayall [1|2|StateName]
// ezzmusicstopall
// ============================================================


// ------------------------------------------------------------
// Global PinteMod message without BO3's [All]UnknownSoldier prefix
// ------------------------------------------------------------

#using custom_scripts\ezz_admin_identity;
#using custom_scripts\ezz_admin_registry;

function music_broadcast(message)
{
    players = GetPlayers();

    for (i = 0; i < players.size; i++)
    {
        player = players[i];

        if (isdefined(player))
            player iprintln(message);
    }
}

autoexec function init()
{
    addcommand("ezzmusicstatus", ::cmd_ezzmusicstatus);
    addcommand("ezzmusicstates", ::cmd_ezzmusicstates);
    addcommand("ezzmusicplayall", ::cmd_ezzmusicplayall);
    addcommand("ezzmusicstopall", ::cmd_ezzmusicstopall);

    level.pintemod_music_loaded = true;
    level.pintemod_music_version = "0.5.1";

    println(
        "^5[PinteMod]^7 Music v0.5.1 loaded"
    );
}


function music_feature_enabled()
{
    if (!isdefined(level.pintemod_enable_music))
        return true;

    return level.pintemod_enable_music;
}

function music_find_player_exact(player_name)
{
    return ezz_admin_identity::identity_find_player(player_name);
}

function music_get_map_name()
{
    return toLower(GetDvarString("mapname"));
}

function music_has_registry()
{
    if (!isdefined(level.musicSystem))
        return false;

    if (!isdefined(level.musicSystem.states))
        return false;

    return true;
}

function music_find_state_case_insensitive(wanted_state)
{
    if (!music_has_registry())
        return undefined;

    keys = GetArrayKeys(level.musicSystem.states);
    wanted_lower = toLower(wanted_state);

    for (i = 0; i < keys.size; i++)
    {
        if (toLower(keys[i]) == wanted_lower)
            return keys[i];
    }

    return undefined;
}

function music_create_song(label, state_name)
{
    song = spawnstruct();
    song.label = label;
    song.state = state_name;

    return song;
}

function music_get_map_display_name()
{
    return ezz_admin_registry::get_map_display_name(music_get_map_name());
}

function music_get_special_songs()
{
    songs = [];
    map_name = music_get_map_name();

    switch (map_name)
    {
        case "zm_zod":
            songs[songs.size] = music_create_song(
                "Snakeskin Boots",
                "zod_egg_snakeskin"
            );
            songs[songs.size] = music_create_song(
                "Cold Hard Cash",
                "zod_egg_coldhardcash"
            );
            break;

        case "zm_factory":
            songs[songs.size] = music_create_song(
                "Musique spéciale",
                "egg"
            );
            break;

        case "zm_castle":
            songs[songs.size] = music_create_song(
                "Dead Again",
                "dead_again"
            );
            break;

        case "zm_island":
            // Dead Flowers : registre musicCmd indisponible.
            break;

        case "zm_stalingrad":
            songs[songs.size] = music_create_song(
                "Ace of Spades",
                "ace_of_spades"
            );
            songs[songs.size] = music_create_song(
                "Dead Ended",
                "dead_ended"
            );
            break;

        case "zm_genesis":
            songs[songs.size] = music_create_song(
                "The Gift",
                "the_gift"
            );
            break;

        case "zm_prototype":
            // Aucune musique demandée.
            break;

        case "zm_asylum":
            songs[songs.size] = music_create_song(
                "Lullaby for a Dead Man",
                "lullaby_for_a_dead_man"
            );
            break;

        case "zm_sumpf":
            songs[songs.size] = music_create_song(
                "The One",
                "the_one"
            );
            break;

        case "zm_theater":
            songs[songs.size] = music_create_song(
                "115",
                "115"
            );
            break;

        case "zm_cosmodrome":
            songs[songs.size] = music_create_song(
                "Abracadavre",
                "abracadavre"
            );
            break;

        case "zm_temple":
            songs[songs.size] = music_create_song(
                "Pareidolia",
                "pareidolia"
            );
            break;

        case "zm_moon":
            songs[songs.size] = music_create_song(
                "Coming Home",
                "cominghome"
            );
            songs[songs.size] = music_create_song(
                "Nightmare",
                "nightmare"
            );
            break;

        case "zm_tomb":
            songs[songs.size] = music_create_song(
                "Archangel",
                "archangel"
            );
            break;
    }

    return songs;
}

function music_get_song_by_argument(argument)
{
    songs = music_get_special_songs();

    if (songs.size <= 0)
        return undefined;

    argument_lower = toLower(argument);

    if (argument_lower == "1")
        return songs[0];

    if (argument_lower == "2" && songs.size >= 2)
        return songs[1];

    for (i = 0; i < songs.size; i++)
    {
        if (toLower(songs[i].state) == argument_lower)
            return songs[i];
    }

    return undefined;
}

function music_send_existing_state(player, state_name)
{
    scripts\shared\util_shared::setClientSysState(
        "musicCmd",
        state_name,
        player
    );

    player.pintemod_music_state = state_name;

    return true;
}

function music_send_state_to_all(state_name)
{
    players = GetPlayers();
    sent = 0;

    for (i = 0; i < players.size; i++)
    {
        player = players[i];

        if (!isdefined(player))
            continue;

        music_send_existing_state(player, state_name);
        sent++;
    }

    return sent;
}

function music_stop_for_all()
{
    players = GetPlayers();
    stopped = 0;

    for (i = 0; i < players.size; i++)
    {
        player = players[i];

        if (!isdefined(player))
            continue;

        scripts\shared\util_shared::setClientSysState(
            "musicCmd",
            "none",
            player
        );

        player.pintemod_music_state = "none";
        stopped++;
    }

    return stopped;
}

function music_print_state(state_name)
{
    state = level.musicSystem.states[state_name];

    if (!isdefined(state.musArray) || state.musArray.size <= 0)
    {
        println("^3" + state_name + " -> structure alternative");
        return;
    }

    music_sets = "";

    for (i = 0; i < state.musArray.size; i++)
    {
        if (i > 0)
            music_sets = music_sets + ", ";

        music_sets = music_sets + state.musArray[i];
    }

    println("^7" + state_name + " -> " + music_sets);
}

function cmd_ezzmusicstatus(args)
{
    songs = music_get_special_songs();
    map_name = music_get_map_name();

    println("^5========== PINTEMOD MUSIC ==========");
    println("^7Enabled: " + music_feature_enabled());
    println("^7Map: " + music_get_map_display_name());
    println("^7Backend: existing musicCmd");

    if (!music_feature_enabled())
    {
        println("^3Music feature disabled in ezz_admin_config.gsc");
        println("^5====================================");
        return;
    }
    println(
        "^7Registry: " +
        music_has_registry()
    );

    if (map_name == "zm_island")
    {
        println("^3Dead Flowers: registre natif indisponible");
        println("^3Lecture désactivée par sécurité");
        println("^5====================================");
        return;
    }

    if (map_name == "zm_prototype")
    {
        println("^3Aucune musique configurée");
        println("^5====================================");
        return;
    }

    if (songs.size <= 0)
    {
        println("^3Aucune musique spéciale configurée");
        println("^5====================================");
        return;
    }

    for (i = 0; i < songs.size; i++)
    {
        resolved = music_find_state_case_insensitive(
            songs[i].state
        );

        status = "^1ABSENT";

        if (isdefined(resolved))
            status = "^2OK";

        println(
            "^7" + (i + 1) + ". " +
            songs[i].label +
            " | " + songs[i].state +
            " | " + status
        );
    }

    println("^5====================================");
}

function cmd_ezzmusicstates(args)
{
    if (!music_feature_enabled())
    {
        println("^3[PinteMod]^7 Music feature is disabled");
        return;
    }

    if (!music_has_registry())
    {
        println("^1[PinteMod] Native music registry unavailable");
        return;
    }

    keys = GetArrayKeys(level.musicSystem.states);

    println("^5========== REGISTERED MUSIC STATES ==========");
    println("^7Count: " + keys.size);

    for (i = 0; i < keys.size; i++)
        music_print_state(keys[i]);

    println("^5=============================================");
}

function cmd_ezzmusicplayall(args)
{
    if (!music_feature_enabled())
    {
        println("^3[PinteMod]^7 Music feature is disabled");
        return;
    }

    map_name = music_get_map_name();

    if (map_name == "zm_island")
    {
        println(
            "^3[PinteMod]^7 Dead Flowers indisponible : " +
            "registre musical absent"
        );
        return;
    }

    if (!music_has_registry())
    {
        println("^1[PinteMod] Native music registry unavailable");
        return;
    }

    songs = music_get_special_songs();

    if (songs.size <= 0)
    {
        println(
            "^3[PinteMod]^7 Aucune musique configurée pour " +
            music_get_map_display_name()
        );
        return;
    }

    song = songs[0];

    if (args.size >= 1)
    {
        song = music_get_song_by_argument(args[0]);

        if (!isdefined(song))
        {
            println("^1[PinteMod] Musique inconnue pour cette map");
            println("^3[PinteMod]^7 Utiliser 1, 2 ou le nom d'état");
            return;
        }
    }

    state_name = music_find_state_case_insensitive(song.state);

    if (!isdefined(state_name))
    {
        println(
            "^1[PinteMod] État musical absent : " +
            song.state
        );
        return;
    }

    sent = music_send_state_to_all(state_name);

    music_broadcast(
        "^6[PinteMod]^7 " +
        song.label +
        " lancée pour tous (" +
        sent + " joueur(s))"
    );
}

function cmd_ezzmusicstopall(args)
{
    if (!music_feature_enabled())
    {
        println("^3[PinteMod]^7 Music feature is disabled");
        return;
    }

    if (!music_has_registry())
    {
        println("^1[PinteMod] Native music registry unavailable");
        return;
    }

    stopped = music_stop_for_all();

    music_broadcast(
        "^3[PinteMod]^7 Musique arrêtée pour tous (" +
        stopped + " joueur(s))"
    );
}
