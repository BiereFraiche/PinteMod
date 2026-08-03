// ============================================================
// PinteMod — Shared Registry v2.1.1
// Fichier : ezz_admin_registry.gsc
// Créé par BiereFraiche et ChatGPT
//
// Source commune pour les profils de maps et les métadonnées
// d'autorisation des commandes Chat.
// ============================================================

#namespace ezz_admin_registry;

function get_current_map_code()
{
    map_name = GetDvarString("mapname");

    if (!isdefined(map_name) || map_name == "")
        return "unknown";

    return toLower(map_name);
}

function get_map_display_name(map_name)
{
    switch (toLower(map_name))
    {
        case "zm_zod": return "Shadows of Evil";
        case "zm_factory": return "The Giant";
        case "zm_castle": return "Der Eisendrache";
        case "zm_island": return "Zetsubou No Shima";
        case "zm_stalingrad": return "Gorod Krovi";
        case "zm_genesis": return "Revelations";
        case "zm_prototype": return "Nacht der Untoten";
        case "zm_asylum": return "Verruckt";
        case "zm_sumpf": return "Shi No Numa";
        case "zm_theater": return "Kino der Toten";
        case "zm_cosmodrome": return "Ascension";
        case "zm_temple": return "Shangri-La";
        case "zm_moon": return "Moon";
        case "zm_tomb": return "Origins";
    }

    return map_name;
}

function get_map_collection(map_name)
{
    switch (toLower(map_name))
    {
        case "zm_zod":
        case "zm_factory":
        case "zm_castle":
        case "zm_island":
        case "zm_stalingrad":
        case "zm_genesis":
            return "BO3 Core / DLC";

        case "zm_prototype":
        case "zm_asylum":
        case "zm_sumpf":
        case "zm_theater":
        case "zm_cosmodrome":
        case "zm_temple":
        case "zm_moon":
        case "zm_tomb":
            return "Zombies Chronicles";
    }

    return "Custom / Unprofiled";
}

function is_official_map(map_name)
{
    switch (toLower(map_name))
    {
        case "zm_zod":
        case "zm_factory":
        case "zm_castle":
        case "zm_island":
        case "zm_stalingrad":
        case "zm_genesis":
        case "zm_prototype":
        case "zm_asylum":
        case "zm_sumpf":
        case "zm_theater":
        case "zm_cosmodrome":
        case "zm_temple":
        case "zm_moon":
        case "zm_tomb":
            return true;
    }

    return false;
}

function official_map_codes()
{
    maps = [];
    maps[0] = "zm_zod";
    maps[1] = "zm_factory";
    maps[2] = "zm_castle";
    maps[3] = "zm_island";
    maps[4] = "zm_stalingrad";
    maps[5] = "zm_genesis";
    maps[6] = "zm_prototype";
    maps[7] = "zm_asylum";
    maps[8] = "zm_sumpf";
    maps[9] = "zm_theater";
    maps[10] = "zm_cosmodrome";
    maps[11] = "zm_temple";
    maps[12] = "zm_moon";
    maps[13] = "zm_tomb";
    return maps;
}

function resolve_map_alias(alias)
{
    if (!isdefined(alias) || alias == "")
        return undefined;

    switch (toLower(alias))
    {
        case "soe":
        case "shadows":
        case "shadowsofevil":
        case "zod":
        case "zm_zod":
            return "zm_zod";

        case "giant":
        case "thegiant":
        case "factory":
        case "zm_factory":
            return "zm_factory";

        case "de":
        case "castle":
        case "dereisendrache":
        case "zm_castle":
            return "zm_castle";

        case "zns":
        case "zetsubou":
        case "zetsubounoshima":
        case "island":
        case "zm_island":
            return "zm_island";

        case "gk":
        case "gorod":
        case "gorodkrovi":
        case "stalingrad":
        case "zm_stalingrad":
            return "zm_stalingrad";

        case "rev":
        case "revelations":
        case "genesis":
        case "zm_genesis":
            return "zm_genesis";

        case "nacht":
        case "nachtderuntoten":
        case "prototype":
        case "zm_prototype":
            return "zm_prototype";

        case "verruckt":
        case "asylum":
        case "zm_asylum":
            return "zm_asylum";

        case "shino":
        case "shinonuma":
        case "sumpf":
        case "zm_sumpf":
            return "zm_sumpf";

        case "kino":
        case "kinodertoten":
        case "theater":
        case "zm_theater":
            return "zm_theater";

        case "ascension":
        case "cosmodrome":
        case "zm_cosmodrome":
            return "zm_cosmodrome";

        case "shang":
        case "shangrila":
        case "temple":
        case "zm_temple":
            return "zm_temple";

        case "moon":
        case "zm_moon":
            return "zm_moon";

        case "origins":
        case "tomb":
        case "zm_tomb":
            return "zm_tomb";
    }

    return undefined;
}

function map_has_main_quest(map_name)
{
    switch (toLower(map_name))
    {
        case "zm_zod":
        case "zm_castle":
        case "zm_island":
        case "zm_stalingrad":
        case "zm_genesis":
        case "zm_cosmodrome":
        case "zm_temple":
        case "zm_moon":
        case "zm_tomb":
            return true;
    }

    return false;
}

function map_min_ee_players(map_name)
{
    switch (toLower(map_name))
    {
        case "zm_zod":
        case "zm_cosmodrome":
        case "zm_temple":
            return 4;
    }

    if (map_has_main_quest(map_name))
        return 1;

    return 0;
}


function canonical_chat_command(command_name)
{
    if (!isdefined(command_name) || command_name == "")
        return "";

    command_name = toLower(command_name);

    switch (command_name)
    {
        case "commands": return "help";
        case "records": return "record";
        case "permission": return "permissions";
        case "ezzeetestrecords": return "eetestrecords";
        case "teleport": return "tp";
        case "godmode": return "god";
        case "maxammo": return "ammo";
        case "wonderweapon":
        case "wonders": return "wonderweapons";
        case "gun": return "weapon";
        case "packweapon": return "papweapon";
        case "join": return "spawn";
        case "language":
        case "langue":
        case "idioma": return "lang";
    }


    switch (command_name)
    {
        case "healthfull": return "health";
        case "history":
        case "playerhistory": return "history";
        case "mute": return "mute";
        case "unmute": return "unmute";
        case "kick": return "kick";
        case "langstats": return "langstats";
        case "mapaudit": return "mapaudit";
    }
    return command_name;
}

function chat_console_command(command_name)
{
    switch (canonical_chat_command(command_name))
    {
        case "lang": return "ezzlang";
        case "rank": return "ezzrank";
        case "ranks": return "ezzranks";
        case "record": return "ezzrecords";
        case "eerecord": return "ezzeerecord";
        case "eerecords": return "ezzeerecords";
        case "eetestrecords": return "ezzeetestrecords";
        case "music": return "ezzmusic";
        case "musicstatus": return "ezzmusicstatus";
        case "boss": return "ezzspawnboss";
        case "margwa": return "ezzspawnmargwa";
        case "panzer": return "ezzspawnpanzer";
        case "eventstatus": return "ezzeventstatus";
        case "save": return "ezzsave";
        case "load": return "ezzload";
        case "tp": return "ezztp";
        case "god": return "godmode";
        case "ignore": return "ignore";
        case "respawn": return "ezzspawn";
        case "revive": return "ezzrevive";
        case "ammo": return "ammo";
        case "maxpoints": return "maxpoints";
        case "points": return "points";
        case "weapon": return "ezzweapon";
        case "weaponstatus": return "ezzweaponstatus";
        case "papweapon": return "ezzpapweapon";
        case "hasweapon": return "ezzhasweapon";
        case "perk": return "ezzperk";
        case "hasperk": return "ezzhasperk";
        case "allperks": return "ezzallperks";
        case "clearperks": return "ezzclearperks";
        case "removeperk": return "ezzremoveperk";
        case "powerup": return "ezzpowerup";
        case "lastzombie": return "ezzlastzombie";
        case "killzombies": return "ezzkillzombies";
        case "nextround": return "ezznextround";
        case "skiprounds": return "ezzskiprounds";
        case "setround": return "ezzsetround";
        case "freezepowerups": return "ezzfreezepowerups";
        case "spawn": return "ezzjoin";
        case "votemap": return "ezzvotemap";
        case "voterestart": return "ezzvoterestart";
        case "yes": return "ezzyes";
        case "no": return "ezzno";
        case "votestatus": return "ezzvotestatus";
        case "votekick": return "ezzvotekick";
        case "cancelvote": return "ezzcancelvote";
        case "clearnextmap": return "ezzclearnextmap";
        case "menu": return "ezzmenu";
        case "power": return "ezzpower";
        case "powerstatus": return "ezzpowerstatus";
        case "pap": return "ezzpap";
        case "papstatus": return "ezzpapstatus";
        case "unlock": return "ezzunlock";
        case "unlockstatus": return "ezzunlockstatus";
        case "ban": return "ezzban";
        case "unban": return "ezzunban";
        case "baninfo": return "ezzbaninfo";
        case "banlist": return "ezzbanlist";
    }

    return "";
}

function chat_command_available_on_map(command_name, map_name)
{
    command_name = canonical_chat_command(command_name);

    // Commands with map-specific implementations stay visible; their
    // destination module reports unsupported aliases/events explicitly.
    if (command_name == "music" || command_name == "musicstatus" ||
        command_name == "boss" || command_name == "margwa" ||
        command_name == "panzer" || command_name == "eventstatus")
    {
        return is_official_map(map_name);
    }

    return true;
}

function chat_required_role(command_name)
{
    command_name = canonical_chat_command(command_name);

    switch (command_name)
    {
        case "ping":
        case "lang":
        case "language":
        case "langue":
        case "idioma":
        case "help":
        case "commands":
        case "players":
        case "rank":
        case "ranks":
        case "record":
        case "records":
        case "eerecord":
        case "eerecords":
        case "menu":
        case "spawn":
        case "join":
        case "votemap":
        case "voterestart":
        case "yes":
        case "no":
        case "votestatus":
        case "votekick":
        case "map":
        case "mapstatus":
        case "round":
            return 0;

        case "permissions":
        case "permission":
        case "perm":
        case "setrole":
        case "removerole":
        case "eetestrecords":
        case "ezzeetestrecords":
        case "revive":
            return 4;

        case "killzombies":
        case "nextround":
        case "skiprounds":
        case "setround":
        case "power":
        case "pap":
        case "unlock":
        case "freezepowerups":
        case "music":
        case "musicstatus":
        case "boss":
        case "margwa":
        case "panzer":
        case "eventstatus":
        case "cancelvote":
        case "clearnextmap":
        case "ban":
        case "unban":
        case "baninfo":
        case "banlist":
        case "mute":
        case "unmute":
        case "kick":
        case "history":
        case "langstats":
        case "health":
        case "mapaudit":
            return 3;

        case "god":
        case "godmode":
        case "ignore":
        case "ammo":
        case "maxammo":
        case "points":
        case "maxpoints":
        case "weapon":
        case "gun":
        case "papweapon":
        case "packweapon":
        case "perk":
        case "allperks":
        case "clearperks":
        case "removeperk":
        case "powerup":
        case "lastzombie":
            return 2;

        case "adminhelp":
        case "respawn":
        case "save":
        case "load":
        case "tp":
        case "teleport":
        case "weapons":
        case "wonderweapons":
        case "wonderweapon":
        case "wonders":
        case "weaponstatus":
        case "hasweapon":
        case "perks":
        case "hasperk":
        case "powerups":
        case "zombies":
        case "zombiecount":
        case "roundinfo":
        case "rounds":
        case "maps":
        case "powerstatus":
        case "papstatus":
        case "unlockstatus":
            return 1;
    }

    return 1;
}

function chat_command_affects_gameplay(command_name)
{
    command_name = canonical_chat_command(command_name);

    switch (command_name)
    {
        case "god":
        case "godmode":
        case "ignore":
        case "ammo":
        case "maxammo":
        case "points":
        case "maxpoints":
        case "weapon":
        case "gun":
        case "papweapon":
        case "packweapon":
        case "perk":
        case "allperks":
        case "clearperks":
        case "removeperk":
        case "powerup":
        case "lastzombie":
        case "killzombies":
        case "nextround":
        case "skiprounds":
        case "setround":
        case "power":
        case "pap":
        case "unlock":
        case "freezepowerups":
        case "boss":
        case "margwa":
        case "panzer":
        case "respawn":
        case "revive":
        case "load":
        case "tp":
        case "teleport":
            return true;
    }

    return false;
}


function cmd_ezzregistrystatus(args)
{
    map_name = get_current_map_code();
    println("^5===== PINTEMOD SHARED REGISTRY v2.1.1 =====");
    println("^7Map code: " + map_name);
    println("^7Display: " + get_map_display_name(map_name));
    println("^7Official: " + is_official_map(map_name));
    println("^7Main quest: " + map_has_main_quest(map_name));
    println("^7Minimum EE players: " + map_min_ee_players(map_name));
    println("^7Profiles: 14 official BO3 Zombies maps");
    println("^7Command metadata: aliases + console route + role + gameplay impact");
    println("^7Map availability: " +
        chat_command_available_on_map("music", map_name));
    println("^5=============================================");
}

autoexec function init()
{
    if (isdefined(level.pintemod_registry_initialized) &&
        level.pintemod_registry_initialized)
    {
        return;
    }

    addcommand("ezzregistrystatus", ::cmd_ezzregistrystatus);

    level.pintemod_registry_initialized = true;
    level.pintemod_registry_version = "2.1.1";
    println("^5[PinteMod]^7 Registry v2.1.1 loaded");
}
