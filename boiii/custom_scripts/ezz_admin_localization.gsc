// ============================================================
// PinteMod — Localization FR / EN / ES v2.1.1
// Fichier : ezz_admin_localization.gsc
// Créé par BiereFraiche et ChatGPT
//
// Langue persistante liée au BOIII_XUID.
// Détection initiale facultative par pays via le GeoIP Bridge.
// L'adresse IP n'est jamais écrite par PinteMod et n'est jamais reçue en GSC.
// ============================================================

#namespace ezz_admin_localization;

#using custom_scripts\ezz_admin_identity;
#using custom_scripts\ezz_admin_storage;

function localization_default_language()
{
    if (isdefined(level.pintemod_default_language))
        return normalize_language(level.pintemod_default_language);

    return "en";
}

function normalize_language(language)
{
    if (!isdefined(language) || language == "")
        return "en";

    language = toLower(language);

    switch (language)
    {
        case "fr":
        case "francais":
        case "french":
            return "fr";

        case "es":
        case "espanol":
        case "spanish":
            return "es";

        case "en":
        case "english":
        case "anglais":
            return "en";
    }

    return "en";
}

function localization_contains(text_value, needle)
{
    if (!isdefined(text_value) || !isdefined(needle) || needle == "")
        return false;

    if (text_value.size < needle.size)
        return false;

    for (index = 0; index <= text_value.size - needle.size; index++)
    {
        if (GetSubStr(text_value, index, needle.size) == needle)
            return true;
    }

    return false;
}

function is_supported_language(language)
{
    language = toLower(language);
    return language == "fr" || language == "en" || language == "es";
}

function localization_json_string(json, key_name, default_value)
{
    if (!isdefined(json) || json == "" || jsonvalid(json))
        return default_value;

    value = jsonparse(json, key_name);

    if (!isdefined(value) || value == "")
        return default_value;

    return value;
}

function localization_player_key(player)
{
    if (!isdefined(player))
        return "";

    xuid = ezz_admin_identity::get_player_xuid(player);

    if (!ezz_admin_identity::is_valid_xuid(xuid))
        return "";

    return toLower(xuid);
}

function localization_manual_path(xuid)
{
    return "pintemod/localization/manual/" + toLower(xuid) + ".json";
}

function localization_auto_path(xuid)
{
    return "pintemod/localization/auto/" + toLower(xuid) + ".json";
}

function localization_request_path(xuid)
{
    return "pintemod/localization/requests/" + toLower(xuid) + ".json";
}

function localization_response_path(xuid)
{
    return "pintemod/localization/responses/" + toLower(xuid) + ".json";
}

function localization_remove_json_artifacts(path)
{
    removefile(path);
    removefile(path + ".tmp");
    removefile(path + ".bak");
}

function localization_console_verbose()
{
    return isdefined(level.pintemod_server_console_verbose) &&
        level.pintemod_server_console_verbose;
}

function localization_console_event_is_important(event_name)
{
    return event_name == "GEOIP_REQUEST_FAILED" ||
        event_name == "GEOIP_RESPONSE_REJECTED" ||
        event_name == "GEOIP_TIMEOUT";
}

function localization_log(event_name, details)
{
    line = "[" + GetTime() + "] " + event_name;

    if (isdefined(details) && details != "")
        line = line + " | " + details;

    ezz_admin_storage::append_managed_log(
        "pintemod/logs/localization.log",
        line + "\n"
    );

    if (!localization_console_verbose() &&
        !localization_console_event_is_important(event_name))
    {
        return;
    }

    console_line = "^5[PinteMod Localization]^7 " + event_name;

    if (isdefined(details) && details != "")
        console_line = console_line + " | " + details;

    println(console_line);
}

function localization_load_language_file(path, expected_xuid)
{
    if (!fileexists(path))
        return "";

    json = ezz_admin_storage::load_json_or_default(
        path,
        "{}",
        "localization-preference"
    );

    stored_xuid = toLower(localization_json_string(json, "xuid", ""));
    language = normalize_language(
        localization_json_string(json, "language", "")
    );

    if (stored_xuid != toLower(expected_xuid) ||
        !is_supported_language(language))
    {
        return "";
    }

    return language;
}

function localization_write_language_file(path, xuid, language, context)
{
    language = normalize_language(language);

    if (!ezz_admin_identity::is_valid_xuid(xuid) ||
        !is_supported_language(language))
    {
        return false;
    }

    json = "{}";
    json = jsonset(json, "xuid", toLower(xuid));
    json = jsonset(json, "language", language);

    return ezz_admin_storage::write_json_safe(path, json, context);
}

function localization_has_manual_preference(xuid)
{
    return localization_load_language_file(
        localization_manual_path(xuid),
        xuid
    ) != "";
}

function localization_get_saved_language(xuid)
{
    manual = localization_load_language_file(
        localization_manual_path(xuid),
        xuid
    );

    if (manual != "")
        return manual;

    automatic = localization_load_language_file(
        localization_auto_path(xuid),
        xuid
    );

    if (automatic != "")
        return automatic;

    return localization_default_language();
}

function get_player_language(player)
{
    if (!isdefined(player))
        return localization_default_language();

    if (isdefined(player.pintemod_language) &&
        is_supported_language(player.pintemod_language))
    {
        return player.pintemod_language;
    }

    xuid = localization_player_key(player);

    if (xuid == "")
        return localization_default_language();

    player.pintemod_language = localization_get_saved_language(xuid);
    return player.pintemod_language;
}

function language_display_name(language)
{
    switch (normalize_language(language))
    {
        case "fr": return "Francais";
        case "es": return "Espanol";
    }

    return "English";
}

function text_for_language(language, key)
{
    language = normalize_language(language);

    if (language == "fr")
    {
        switch (key)
        {
            case "welcome_title": return "^5[PinteMod]^7 Bienvenue sur le serveur !";
            case "welcome_menu": return "^7Ouvrez le menu joueur avec ^2.menu^7.";
            case "welcome_spawn": return "^7Rejoindre en cours : ^2.spawn ^7ou Menu > Rejoindre.";
            case "welcome_community": return "^7Les commandes communautaires sont dans ^2.menu^7.";
            case "welcome_line": return "^5[PinteMod]^7 Bienvenue ! ^2.menu ^7| Rejoindre : ^2.spawn";
            case "latejoin_spectator": return "^3[PinteMod]^7 Vous avez rejoint comme spectateur pendant une manche active.";
            case "latejoin_type_spawn": return "^7Tapez ^2.spawn ^7pour rejoindre la manche.";
            case "latejoin_menu_spawn": return "^7Ou utilisez ^2.menu ^7> Menu joueur > Rejoindre.";
            case "latejoin_identity": return "^1[PinteMod]^7 Identite stable indisponible ; connexion refusee.";
            case "latejoin_normal_death": return "^1[PinteMod]^7 Rejoindre refuse : mort normale detectee.";
            case "latejoin_not_eligible": return "^3[PinteMod]^7 Rejoindre est disponible uniquement apres une connexion comme spectateur en cours de manche.";
            case "latejoin_already_active": return "^3[PinteMod]^7 Vous etes deja actif.";
            case "latejoin_not_ready": return "^1[PinteMod]^7 Le respawn n'est pas encore pret.";
            case "latejoin_success": return "^2[PinteMod]^7 Vous avez rejoint la partie active.";
            case "latejoin_failed": return "^1[PinteMod]^7 Echec du respawn. Reessayez pendant qu'un survivant est actif.";
            case "language_current": return "^5[PinteMod]^7 Langue actuelle : ^2";
            case "language_changed": return "^2[PinteMod]^7 Langue definie sur : ^7";
            case "language_auto": return "^2[PinteMod]^7 Langue automatique activee selon le pays.";
            case "language_usage": return "^7Utilisation : ^2.lang fr ^7| ^2.lang en ^7| ^2.lang es ^7| ^2.lang auto";
            case "language_invalid": return "^1[PinteMod]^7 Langue invalide. Choix : fr, en, es, auto.";
            case "country_prefix": return "^5[PinteMod]^7 ";
            case "country_suffix": return " s'est connecte depuis ^3";
            case "country_end": return "^7.";
            case "menu_role": return "ROLE";
            case "menu_target": return "CIBLE";
            case "menu_up": return "Monter";
            case "menu_down": return "Descendre";
            case "menu_select": return "Valider";
            case "menu_back": return "Retour / Fermer";
            case "menu_moderation": return "MODERATION";
            case "menu_moderation_no_target": return "Aucune cible disponible";
            case "menu_moderation_protected": return "Cible protegee / hierarchie insuffisante";
            case "menu_mute": return "Mute";
            case "menu_unmute": return "Retirer le mute";
            case "menu_kick": return "Expulser";
            case "menu_temp_ban_30m": return "Ban temporaire 30 min";
            case "menu_temp_ban_2h": return "Ban temporaire 2 h";
            case "menu_perm_ban": return "Ban permanent";
            case "menu_ban_info": return "Informations de ban";
            case "menu_player_history": return "Historique joueur";
            case "moderation_muted": return "^1[PinteMod]^7 Vous avez ete mute.";
            case "moderation_unmuted": return "^2[PinteMod]^7 Votre mute a ete retire.";
            case "moderation_refused": return "^1[PinteMod]^7 Action de moderation refusee.";
            case "moderation_target_missing": return "^1[PinteMod]^7 Cible introuvable.";
            case "moderation_admin_required": return "^1[PinteMod]^7 Role Admin requis.";
        }
    }
    else if (language == "es")
    {
        switch (key)
        {
            case "welcome_title": return "^5[PinteMod]^7 Bienvenido al servidor !";
            case "welcome_menu": return "^7Abre el menu de jugador con ^2.menu^7.";
            case "welcome_spawn": return "^7Entrar en curso: ^2.spawn ^7o Menu > Entrar.";
            case "welcome_community": return "^7Los comandos de comunidad estan en ^2.menu^7.";
            case "welcome_line": return "^5[PinteMod]^7 Bienvenido ! ^2.menu ^7| Entrar: ^2.spawn";
            case "latejoin_spectator": return "^3[PinteMod]^7 Entraste como espectador durante una ronda activa.";
            case "latejoin_type_spawn": return "^7Escribe ^2.spawn ^7para entrar en la ronda.";
            case "latejoin_menu_spawn": return "^7Tambien puedes usar ^2.menu ^7> Menu jugador > Entrar.";
            case "latejoin_identity": return "^1[PinteMod]^7 Identidad estable no disponible; entrada rechazada.";
            case "latejoin_normal_death": return "^1[PinteMod]^7 Entrada rechazada: muerte normal detectada.";
            case "latejoin_not_eligible": return "^3[PinteMod]^7 Entrar solo esta disponible tras conectarte como espectador durante una ronda.";
            case "latejoin_already_active": return "^3[PinteMod]^7 Ya estas activo.";
            case "latejoin_not_ready": return "^1[PinteMod]^7 El respawn aun no esta listo.";
            case "latejoin_success": return "^2[PinteMod]^7 Entraste en la partida activa.";
            case "latejoin_failed": return "^1[PinteMod]^7 Fallo el respawn. Intentalo mientras haya un superviviente activo.";
            case "language_current": return "^5[PinteMod]^7 Idioma actual: ^2";
            case "language_changed": return "^2[PinteMod]^7 Idioma cambiado a: ^7";
            case "language_auto": return "^2[PinteMod]^7 Idioma automatico activado segun el pais.";
            case "language_usage": return "^7Uso: ^2.lang fr ^7| ^2.lang en ^7| ^2.lang es ^7| ^2.lang auto";
            case "language_invalid": return "^1[PinteMod]^7 Idioma invalido. Opciones: fr, en, es, auto.";
            case "country_prefix": return "^5[PinteMod]^7 ";
            case "country_suffix": return " se conecto desde ^3";
            case "country_end": return "^7.";
            case "menu_role": return "ROL";
            case "menu_target": return "OBJETIVO";
            case "menu_up": return "Subir";
            case "menu_down": return "Bajar";
            case "menu_select": return "Elegir";
            case "menu_back": return "Atras / Cerrar";
            case "menu_moderation": return "MODERACION";
            case "menu_moderation_no_target": return "No hay objetivo disponible";
            case "menu_moderation_protected": return "Objetivo protegido / jerarquia insuficiente";
            case "menu_mute": return "Silenciar";
            case "menu_unmute": return "Quitar silencio";
            case "menu_kick": return "Expulsar";
            case "menu_temp_ban_30m": return "Ban temporal 30 min";
            case "menu_temp_ban_2h": return "Ban temporal 2 h";
            case "menu_perm_ban": return "Ban permanente";
            case "menu_ban_info": return "Informacion del ban";
            case "menu_player_history": return "Historial del jugador";
            case "moderation_muted": return "^1[PinteMod]^7 Has sido silenciado.";
            case "moderation_unmuted": return "^2[PinteMod]^7 Ya no estas silenciado.";
            case "moderation_refused": return "^1[PinteMod]^7 Accion de moderacion rechazada.";
            case "moderation_target_missing": return "^1[PinteMod]^7 Objetivo no encontrado.";
            case "moderation_admin_required": return "^1[PinteMod]^7 Se requiere el rol Admin.";
        }
    }

    switch (key)
    {
        case "welcome_title": return "^5[PinteMod]^7 Welcome to the server!";
        case "welcome_menu": return "^7Open the Player Menu with ^2.menu^7.";
        case "welcome_spawn": return "^7Late join: use ^2.spawn ^7or Player Menu > Join Game.";
        case "welcome_community": return "^7Community commands are available in ^2.menu^7.";
        case "welcome_line": return "^5[PinteMod]^7 Welcome! ^2.menu ^7| Late join: ^2.spawn";
        case "latejoin_spectator": return "^3[PinteMod]^7 You joined as a spectator during an active round.";
        case "latejoin_type_spawn": return "^7Type ^2.spawn ^7to join the current round.";
        case "latejoin_menu_spawn": return "^7You can also use ^2.menu ^7> Player Menu > Join Game.";
        case "latejoin_identity": return "^1[PinteMod]^7 Stable identity unavailable; join refused.";
        case "latejoin_normal_death": return "^1[PinteMod]^7 Late-join rejected: normal death detected.";
        case "latejoin_not_eligible": return "^3[PinteMod]^7 Join Game is available only after joining an active match as a spectator.";
        case "latejoin_already_active": return "^3[PinteMod]^7 You are already active.";
        case "latejoin_not_ready": return "^1[PinteMod]^7 Respawn is not ready yet.";
        case "latejoin_success": return "^2[PinteMod]^7 You joined the active game.";
        case "latejoin_failed": return "^1[PinteMod]^7 Respawn failed. Try again while a survivor is active.";
        case "language_current": return "^5[PinteMod]^7 Current language: ^2";
        case "language_changed": return "^2[PinteMod]^7 Language changed to: ^7";
        case "language_auto": return "^2[PinteMod]^7 Automatic country language enabled.";
        case "language_usage": return "^7Usage: ^2.lang fr ^7| ^2.lang en ^7| ^2.lang es ^7| ^2.lang auto";
        case "language_invalid": return "^1[PinteMod]^7 Invalid language. Choices: fr, en, es, auto.";
        case "country_prefix": return "^5[PinteMod]^7 ";
        case "country_suffix": return " connected from ^3";
        case "country_end": return "^7.";
        case "menu_role": return "ROLE";
        case "menu_target": return "TARGET";
        case "menu_up": return "Up";
        case "menu_down": return "Down";
        case "menu_select": return "Select";
        case "menu_back": return "Back / Close";
        case "menu_moderation": return "MODERATION";
        case "menu_moderation_no_target": return "No target available";
        case "menu_moderation_protected": return "Protected target / insufficient hierarchy";
        case "menu_mute": return "Mute";
        case "menu_unmute": return "Unmute";
        case "menu_kick": return "Kick";
        case "menu_temp_ban_30m": return "Temporary Ban 30m";
        case "menu_temp_ban_2h": return "Temporary Ban 2h";
        case "menu_perm_ban": return "Permanent Ban";
        case "menu_ban_info": return "Ban Information";
        case "menu_player_history": return "Player History";
        case "moderation_muted": return "^1[PinteMod]^7 You have been muted.";
        case "moderation_unmuted": return "^2[PinteMod]^7 You have been unmuted.";
        case "moderation_refused": return "^1[PinteMod]^7 Moderation action refused.";
        case "moderation_target_missing": return "^1[PinteMod]^7 Target not found.";
        case "moderation_admin_required": return "^1[PinteMod]^7 Admin role required.";
    }

    return key;
}

function text(player, key)
{
    return text_for_language(get_player_language(player), key);
}

function menu_category_title(player, category)
{
    if (category == "moderation")
        return text(player, "menu_moderation");
    language = get_player_language(player);

    if (language == "fr")
    {
        switch (category)
        {
            case "main": return "PINTE MOD";
            case "community": return "JOUEUR / COMMUNAUTE";
            case "language": return "LANGUE";
            case "community_votes": return "VOTES COMMUNAUTAIRES";
            case "community_ranks": return "CLASSEMENTS & RECORDS";
            case "community_records": return "RECORDS DE MANCHES";
            case "community_ee_records": return "RECORDS EASTER EGG";
            case "community_mapvote": return "CHOISIR LA PROCHAINE MAP";
            case "community_votekick": return "VOTE D'EXPULSION";
            case "players": return "JOUEURS / CIBLE";
            case "moderation": return "MODERATION";
            case "weapons": return "ARMES";
            case "rounds": return "MANCHES";
            case "music": return "MUSIQUE SPECIALE";
        }
    }
    else if (language == "es")
    {
        switch (category)
        {
            case "main": return "PINTE MOD";
            case "community": return "JUGADOR / COMUNIDAD";
            case "language": return "IDIOMA";
            case "community_votes": return "VOTOS DE COMUNIDAD";
            case "community_ranks": return "CLASIFICACION Y RECORDS";
            case "community_records": return "RECORDS DE RONDAS";
            case "community_ee_records": return "RECORDS EASTER EGG";
            case "community_mapvote": return "ELEGIR SIGUIENTE MAPA";
            case "community_votekick": return "VOTO DE EXPULSION";
            case "players": return "JUGADORES / OBJETIVO";
            case "moderation": return "MODERACION";
            case "weapons": return "ARMAS";
            case "rounds": return "RONDAS";
            case "music": return "MUSICA ESPECIAL";
        }
    }

    switch (category)
    {
        case "main": return "PINTE MOD";
        case "community": return "PLAYER / COMMUNITY";
        case "language": return "LANGUAGE";
        case "community_votes": return "COMMUNITY VOTES";
        case "community_ranks": return "RANKINGS & RECORDS";
        case "community_records": return "ROUND RECORDS";
        case "community_ee_records": return "EASTER EGG RECORDS";
        case "community_mapvote": return "CHOOSE NEXT MAP";
        case "community_votekick": return "VOTE KICK";
        case "players": return "PLAYERS / TARGET";
        case "moderation": return "MODERATION";
        case "administration": return "ADMINISTRATION";
        case "perks": return "PERKS";
        case "weapons": return "WEAPONS";
        case "weapons_special": return "SPECIAL WEAPONS";
        case "weapons_assault": return "ASSAULT RIFLES";
        case "weapons_smg": return "SUBMACHINE GUNS";
        case "weapons_shotguns": return "SHOTGUNS";
        case "weapons_lmg": return "LIGHT MACHINE GUNS";
        case "weapons_snipers": return "SNIPERS";
        case "rounds": return "ROUNDS";
        case "powerups": return "POWER-UPS";
        case "teleport": return "TELEPORT / SPAWN";
        case "maps": return "MAP";
        case "events": return "EVENTS";
        case "music": return "SPECIAL MUSIC";
        case "fun": return "FUN";
    }

    return "PINTE MOD";
}

function translate_menu_label(player, label)
{
    language = get_player_language(player);

    if (label == "Moderation")
    {
        if (language == "es") return "Moderacion";
        return "Moderation";
    }
    if (label == "Mute")
    {
        if (language == "fr") return "Rendre muet";
        if (language == "es") return "Silenciar";
        return "Mute";
    }
    if (label == "Unmute")
    {
        if (language == "fr") return "Retirer le mute";
        if (language == "es") return "Quitar silencio";
        return "Unmute";
    }
    if (label == "Kick")
    {
        if (language == "fr") return "Expulser";
        if (language == "es") return "Expulsar";
        return "Kick";
    }
    if (label == "Temporary Ban 30m")
    {
        if (language == "fr") return "Ban temporaire 30 min";
        if (language == "es") return "Ban temporal 30 min";
        return "Temporary Ban 30m";
    }
    if (label == "Temporary Ban 2h")
    {
        if (language == "fr") return "Ban temporaire 2 h";
        if (language == "es") return "Ban temporal 2 h";
        return "Temporary Ban 2h";
    }
    if (label == "Protected target / insufficient hierarchy")
    {
        if (language == "fr") return "Cible protegee / hierarchie insuffisante";
        if (language == "es") return "Objetivo protegido / jerarquia insuficiente";
        return "Protected target / insufficient hierarchy";
    }
    if (label == "Permanent Ban")
    {
        if (language == "fr") return "Ban permanent";
        if (language == "es") return "Ban permanente";
        return "Permanent Ban";
    }
    if (label == "Ban Information")
    {
        if (language == "fr") return "Informations du ban";
        if (language == "es") return "Informacion del ban";
        return "Ban Information";
    }
    if (label == "Player History")
    {
        if (language == "fr") return "Historique du joueur";
        if (language == "es") return "Historial del jugador";
        return "Player History";
    }

    if (language == "en")
    {
        switch (label)
        {
            case "Community / Joueurs": return "Community / Players";
            case "Joueurs / Cible": return "Players / Target";
            case "Musique speciale": return "Special Music";
            case "Points maximum cible": return "Maximum target points";
            case "Ignorer la cible": return "Ignore target";
            case "< Admin Menu": return "< Admin Menu";
        }
        return label;
    }

    if (language == "fr")
    {
        switch (label)
        {
            case "Community / Joueurs": return "Communaute / Joueurs";
            case "Joueurs / Cible": return "Joueurs / Cible";
            case "Perks": return "Atouts";
            case "Weapons": return "Armes";
            case "Rounds": return "Manches";
            case "Power-Ups": return "Bonus";
            case "Teleport / Spawn": return "Teleportation / Spawn";
            case "Map": return "Carte";
            case "Events": return "Evenements";
            case "Musique speciale": return "Musique speciale";
            case "Close PinteMod": return "Fermer PinteMod";
            case "Join Game": return "Rejoindre la partie";
            case "Votes": return "Votes";
            case "Players Online": return "Joueurs en ligne";
            case "Rankings & Records": return "Classements & Records";
            case "Map Information": return "Informations de la carte";
            case "Commands / Help": return "Commandes / Aide";
            case "Language / Idioma": return "Langue / Language";
            case "< Admin Menu": return "< Menu Admin";
            case "Close": return "Fermer";
            case "My Rank": return "Mon classement";
            case "Server Rankings": return "Classement du serveur";
            case "Round Records": return "Records de manches";
            case "Easter Egg Records": return "Records Easter Egg";
            case "Current EE Run": return "Tentative EE actuelle";
            case "Vote YES": return "Voter OUI";
            case "Vote NO": return "Voter NON";
            case "Current Vote / Next Map": return "Vote actuel / Prochaine map";
            case "Choose Next Map": return "Choisir la prochaine map";
            case "Restart Current Map": return "Relancer la map actuelle";
            case "Vote Kick": return "Vote d'expulsion";
            case "Cancel Active Vote": return "Annuler le vote actif";
            case "Clear Scheduled Map": return "Annuler la prochaine map";
            case "Vote Status": return "Statut du vote";
            case "No target available": return "Aucune cible disponible";
            case "Automatic (country)": return "Automatique (pays)";
            case "French": return "Francais";
            case "English": return "English";
            case "Spanish": return "Espanol";
            case "< Back": return "< Retour";
        }
    }
    else if (language == "es")
    {
        switch (label)
        {
            case "Community / Joueurs": return "Comunidad / Jugadores";
            case "Joueurs / Cible": return "Jugadores / Objetivo";
            case "Administration": return "Administracion";
            case "Perks": return "Ventajas";
            case "Weapons": return "Armas";
            case "Rounds": return "Rondas";
            case "Power-Ups": return "Bonificaciones";
            case "Teleport / Spawn": return "Teletransporte / Spawn";
            case "Map": return "Mapa";
            case "Events": return "Eventos";
            case "Musique speciale": return "Musica especial";
            case "Close PinteMod": return "Cerrar PinteMod";
            case "Join Game": return "Entrar en la partida";
            case "Votes": return "Votos";
            case "Players Online": return "Jugadores conectados";
            case "Rankings & Records": return "Clasificacion y Records";
            case "Map Information": return "Informacion del mapa";
            case "Commands / Help": return "Comandos / Ayuda";
            case "Language / Idioma": return "Idioma / Language";
            case "< Admin Menu": return "< Menu Admin";
            case "Close": return "Cerrar";
            case "My Rank": return "Mi clasificacion";
            case "Server Rankings": return "Clasificacion del servidor";
            case "Round Records": return "Records de rondas";
            case "Easter Egg Records": return "Records Easter Egg";
            case "Current EE Run": return "Intento EE actual";
            case "Vote YES": return "Votar SI";
            case "Vote NO": return "Votar NO";
            case "Current Vote / Next Map": return "Voto actual / Siguiente mapa";
            case "Choose Next Map": return "Elegir siguiente mapa";
            case "Restart Current Map": return "Reiniciar mapa actual";
            case "Vote Kick": return "Voto de expulsion";
            case "Cancel Active Vote": return "Cancelar voto activo";
            case "Clear Scheduled Map": return "Cancelar siguiente mapa";
            case "Vote Status": return "Estado del voto";
            case "No target available": return "No hay objetivo disponible";
            case "Automatic (country)": return "Automatico (pais)";
            case "French": return "Francais";
            case "English": return "English";
            case "Spanish": return "Espanol";
            case "< Back": return "< Atras";
        }
    }

    if (label.size >= 7 && GetSubStr(label, 0, 7) == "Start: ")
    {
        suffix = GetSubStr(label, 7, label.size);

        if (language == "fr") return "Demarrer : " + suffix;
        if (language == "es") return "Iniciar: " + suffix;
    }

    if (label.size >= 8 && GetSubStr(label, 1, 7) == " Player")
    {
        count_text = GetSubStr(label, 0, 1);

        if (language == "fr") return count_text + " Joueur(s)";
        if (language == "es") return count_text + " Jugador(es)";
    }

    return label;
}

function localization_country_name(json, language)
{
    key = "country_en";

    if (language == "fr") key = "country_fr";
    else if (language == "es") key = "country_es";

    country = localization_json_string(json, key, "");

    if (country == "")
        country = localization_json_string(json, "country_code", "Unknown");

    return country;
}

function localization_broadcast_country(player, response_json)
{
    players = GetPlayers();

    for (i = 0; i < players.size; i++)
    {
        recipient = players[i];

        if (!isdefined(recipient))
            continue;

        language = get_player_language(recipient);
        country = localization_country_name(response_json, language);

        recipient tell(
            text_for_language(language, "country_prefix") +
            player.name +
            text_for_language(language, "country_suffix") +
            country +
            text_for_language(language, "country_end")
        );
    }

    country_code = localization_json_string(
        response_json,
        "country_code",
        "UNKNOWN"
    );

    localization_log(
        "COUNTRY_ANNOUNCED",
        "player=" + player.name +
        " | xuid=" + ezz_admin_storage::log_xuid(
            localization_player_key(player)
        ) +
        " | country_code=" + country_code +
        " | language=" + get_player_language(player)
    );
}

function localization_write_geoip_request(player)
{
    xuid = localization_player_key(player);

    if (xuid == "")
        return false;

    request_path = localization_request_path(xuid);
    response_path = localization_response_path(xuid);
    localization_remove_json_artifacts(request_path);
    localization_remove_json_artifacts(response_path);

    json = "{}";
    json = jsonset(json, "xuid", xuid);
    json = jsonset(json, "client", "" + (player GetEntityNumber()));
    json = jsonset(json, "requested_gettime", "" + GetTime());

    if (isdefined(level.pintemod_storage_session_id))
        json = jsonset(json, "session", level.pintemod_storage_session_id);

    if (!ezz_admin_storage::write_json_safe(
        request_path,
        json,
        "localization-geoip-request"
    ))
    {
        localization_log(
            "GEOIP_REQUEST_FAILED",
            "xuid=" + ezz_admin_storage::log_xuid(xuid)
        );
        return false;
    }

    localization_log(
        "GEOIP_REQUESTED",
        "xuid=" + ezz_admin_storage::log_xuid(xuid) +
        " | client=" + (player GetEntityNumber())
    );
    return true;
}

function localization_start_geoip(player, announce_country)
{
    if (!isdefined(player))
        return false;

    if (isdefined(player.pintemod_geoip_waiter_active) &&
        player.pintemod_geoip_waiter_active)
    {
        return false;
    }

    if (!localization_write_geoip_request(player))
        return false;

    player.pintemod_geoip_waiter_active = true;
    player.pintemod_geoip_announce_on_response = announce_country;
    player thread localization_geoip_waiter();
    return true;
}

function localization_geoip_waiter()
{
    self endon("disconnect");

    xuid = localization_player_key(self);

    if (xuid == "")
    {
        self.pintemod_geoip_waiter_active = false;
        self.pintemod_geoip_announce_on_response = false;
        return;
    }

    request_path = localization_request_path(xuid);
    response_path = localization_response_path(xuid);

    for (check = 0; check < 240; check++)
    {
        if (fileexists(response_path))
        {
            json = ezz_admin_storage::load_json_or_default(
                response_path,
                "{}",
                "localization-geoip-response"
            );

            response_xuid = toLower(
                localization_json_string(json, "xuid", "")
            );
            automatic_language = normalize_language(
                localization_json_string(json, "language", "en")
            );
            localization_remove_json_artifacts(response_path);
            localization_remove_json_artifacts(request_path);

            if (response_xuid != xuid)
            {
                localization_log(
                    "GEOIP_RESPONSE_REJECTED",
                    "reason=xuid-mismatch"
                );
                self.pintemod_geoip_waiter_active = false;
                self.pintemod_geoip_announce_on_response = false;
                return;
            }

            localization_write_language_file(
                localization_auto_path(xuid),
                xuid,
                automatic_language,
                "localization-auto-language"
            );

            if (!localization_has_manual_preference(xuid))
                self.pintemod_language = automatic_language;

            announce_country = false;

            if (isdefined(self.pintemod_geoip_announce_on_response))
                announce_country = self.pintemod_geoip_announce_on_response;

            if (announce_country &&
                (!isdefined(level.pintemod_country_announce_enabled) ||
                level.pintemod_country_announce_enabled))
            {
                localization_broadcast_country(self, json);
            }

            source_name = "geoip";

            if (localization_has_manual_preference(xuid))
                source_name = "manual";

            localization_log(
                "LANGUAGE_ASSIGNED",
                "player=" + self.name +
                " | xuid=" + ezz_admin_storage::log_xuid(xuid) +
                " | language=" + get_player_language(self) +
                " | source=" + source_name
            );
            self.pintemod_geoip_waiter_active = false;
            self.pintemod_geoip_announce_on_response = false;
            return;
        }

        wait 0.25;
    }

    localization_remove_json_artifacts(request_path);
    localization_log(
        "GEOIP_TIMEOUT",
        "player=" + self.name +
        " | xuid=" + ezz_admin_storage::log_xuid(xuid) +
        " | fallback=" + get_player_language(self)
    );
    self.pintemod_geoip_waiter_active = false;
    self.pintemod_geoip_announce_on_response = false;
}

function localization_disconnect_cleanup(xuid)
{
    self waittill("disconnect");
    wait 2;
    localization_remove_json_artifacts(localization_request_path(xuid));
    localization_remove_json_artifacts(localization_response_path(xuid));
}

function localization_attach_player(player, request_country)
{
    if (!isdefined(player))
        return;

    if (isdefined(player.pintemod_localization_attached) &&
        player.pintemod_localization_attached)
    {
        return;
    }

    player.pintemod_localization_attached = true;

    for (check = 0; check < 40; check++)
    {
        xuid = localization_player_key(player);

        if (xuid != "")
            break;

        wait 0.25;
    }

    xuid = localization_player_key(player);

    if (xuid == "")
    {
        player.pintemod_language = localization_default_language();
        return;
    }

    player.pintemod_language = localization_get_saved_language(xuid);

    localization_log(
        "PLAYER_LANGUAGE_ATTACHED",
        "player=" + player.name +
        " | xuid=" + ezz_admin_storage::log_xuid(xuid) +
        " | language=" + player.pintemod_language +
        " | manual=" + localization_has_manual_preference(xuid)
    );

    player thread localization_disconnect_cleanup(xuid);

    if (request_country &&
        isdefined(level.pintemod_geoip_enabled) &&
        level.pintemod_geoip_enabled)
    {
        localization_start_geoip(player, true);
    }
}

function localization_bootstrap()
{
    wait 1;

    players = GetPlayers();

    for (i = 0; i < players.size; i++)
    {
        if (isdefined(players[i]))
            localization_attach_player(players[i], false);
    }

    for (;;)
    {
        level waittill("connected", player);

        if (isdefined(player))
            localization_attach_player(player, true);
    }
}

function set_player_language_choice(player, choice)
{
    if (!isdefined(player))
        return false;

    xuid = localization_player_key(player);

    if (xuid == "")
        return false;

    choice = toLower(choice);

    if (choice == "auto" || choice == "automatic")
    {
        localization_remove_json_artifacts(localization_manual_path(xuid));
        player.pintemod_language = localization_get_saved_language(xuid);
        player iprintln(text(player, "language_auto"));

        if (isdefined(level.pintemod_geoip_enabled) &&
            level.pintemod_geoip_enabled)
        {
            localization_start_geoip(player, false);
        }

        localization_log(
            "LANGUAGE_CHANGED",
            "player=" + player.name +
            " | xuid=" + ezz_admin_storage::log_xuid(xuid) +
            " | language=" + player.pintemod_language +
            " | source=auto"
        );
        return true;
    }

    if (!is_supported_language(choice))
    {
        player iprintln(text(player, "language_invalid"));
        return false;
    }

    language = normalize_language(choice);

    if (!localization_write_language_file(
        localization_manual_path(xuid),
        xuid,
        language,
        "localization-manual-language"
    ))
    {
        player iprintln("^1[PinteMod]^7 Language preference write failed.");
        return false;
    }

    player.pintemod_language = language;
    player iprintln(
        text(player, "language_changed") + language_display_name(language)
    );

    localization_log(
        "LANGUAGE_CHANGED",
        "player=" + player.name +
        " | xuid=" + ezz_admin_storage::log_xuid(xuid) +
        " | language=" + language +
        " | source=manual"
    );
    return true;
}

function show_player_language(player)
{
    if (!isdefined(player))
        return;

    player iprintln(
        text(player, "language_current") +
        language_display_name(get_player_language(player))
    );
    player iprintln(text(player, "language_usage"));
}

function cmd_ezzlang(args)
{
    if (args.size < 1)
    {
        println("^5[PinteMod]^7 Usage: ezzlang <PlayerName|BOIII_XUID|ClientNumber> [fr|en|es|auto]");
        return;
    }

    resolved = ezz_admin_identity::resolve_connected_target(args[0]);

    if (!resolved.success)
    {
        println("^1[PinteMod Localization]^7 Player not found: " + args[0]);
        return;
    }

    player = resolved.player;

    if (args.size < 2)
    {
        show_player_language(player);
        return;
    }

    set_player_language_choice(player, args[1]);
}

function cmd_ezzlocalizationstatus(args)
{
    println("^5===== PINTEMOD LOCALIZATION v2.1.1 =====");
    println("^7Languages: fr / en / es");
    println("^7Default: " + localization_default_language());
    println("^7GeoIP enabled: " + level.pintemod_geoip_enabled);
    println("^7Country announcement: " + level.pintemod_country_announce_enabled);
    println("^7Persistent data: BOIII_XUID + language only");
    println("^7Player IP storage: disabled / never received by GSC");
    println("^7Requests: boiii/scriptdata/pintemod/localization/requests/");
    println("^7Responses: boiii/scriptdata/pintemod/localization/responses/");
    println("^5===============================================");
}

function localization_test_assert(result, condition, name, details)
{
    result.total++;

    if (condition)
    {
        result.passed++;
        println("^2[PASS]^7 " + name);
        return;
    }

    result.failed++;
    println("^1[FAIL]^7 " + name + " | " + details);
}

function localization_run_suite()
{
    result = SpawnStruct();
    result.total = 0;
    result.passed = 0;
    result.failed = 0;

    println("^5===== PINTEMOD LOCALIZATION GROUPED SUITE =====");

    test_xuid = "1111111111111111";
    manual_path = localization_manual_path(test_xuid);
    auto_path = localization_auto_path(test_xuid);
    request_path = localization_request_path(test_xuid);
    response_path = localization_response_path(test_xuid);
    localization_remove_json_artifacts(manual_path);
    localization_remove_json_artifacts(auto_path);
    localization_remove_json_artifacts(request_path);
    localization_remove_json_artifacts(response_path);

    localization_test_assert(result, normalize_language("fr") == "fr", "01 French normalization", "fr failed");
    localization_test_assert(result, normalize_language("ENGLISH") == "en", "02 English normalization", "english failed");
    localization_test_assert(result, normalize_language("espanol") == "es", "03 Spanish normalization", "espanol failed");
    localization_test_assert(result, normalize_language("unknown") == "en", "04 Unknown language falls back to English", "fallback failed");

    write_manual = localization_write_language_file(
        manual_path,
        test_xuid,
        "fr",
        "localization-test-manual"
    );
    localization_test_assert(result, write_manual, "05 Manual preference write", "write failed");
    localization_test_assert(
        result,
        localization_load_language_file(manual_path, test_xuid) == "fr",
        "06 Manual preference read",
        "read failed"
    );

    write_auto = localization_write_language_file(
        auto_path,
        test_xuid,
        "es",
        "localization-test-auto"
    );
    localization_test_assert(result, write_auto, "07 Automatic preference write", "write failed");
    localization_test_assert(
        result,
        localization_get_saved_language(test_xuid) == "fr",
        "08 Manual preference has priority over GeoIP",
        "priority failed"
    );

    manual_json = readfile(manual_path);
    localization_test_assert(
        result,
        manual_json.size > 0 &&
        localization_json_string(manual_json, "xuid", "") == test_xuid &&
        localization_json_string(manual_json, "language", "") == "fr",
        "09 Persistent schema contains XUID and language",
        "missing fields"
    );
    localization_test_assert(
        result,
        !localization_contains(toLower(manual_json), "\"ip\"") &&
        localization_json_string(manual_json, "country", "") == "",
        "10 Persistent preference contains no IP or country",
        "privacy field found"
    );

    request_json = "{}";
    request_json = jsonset(request_json, "xuid", test_xuid);
    request_json = jsonset(request_json, "client", "2");
    request_write = ezz_admin_storage::write_json_safe(
        request_path,
        request_json,
        "localization-test-request"
    );
    localization_test_assert(result, request_write, "11 GeoIP request write", "write failed");
    localization_test_assert(
        result,
        localization_json_string(readfile(request_path), "ip", "") == "",
        "12 GSC request never contains player IP",
        "ip field found"
    );

    localization_remove_json_artifacts(manual_path);
    localization_test_assert(
        result,
        localization_get_saved_language(test_xuid) == "es",
        "13 Automatic preference used after manual removal",
        "automatic fallback failed"
    );

    localization_remove_json_artifacts(auto_path);
    localization_remove_json_artifacts(request_path);
    localization_remove_json_artifacts(response_path);

    clean = !fileexists(manual_path) && !fileexists(auto_path) &&
        !fileexists(request_path) && !fileexists(response_path);
    localization_test_assert(result, clean, "14 TEST artifacts cleaned", "cleanup failed");

    println(
        "^5[PinteMod Localization]^7 RESULT " +
        result.passed + "/" + result.total +
        " PASS | failed=" + result.failed
    );
    println("^5================================================");
    return result;
}

function cmd_ezzlocalizationtest(args)
{
    if (args.size < 1 || toLower(args[0]) != "suite")
    {
        println("^5[PinteMod]^7 Usage: ezzlocalizationtest suite");
        return;
    }

    localization_run_suite();
}

autoexec function init()
{
    if (isdefined(level.pintemod_localization_initialized) &&
        level.pintemod_localization_initialized)
    {
        return;
    }

    level.pintemod_localization_initialized = true;

    mkdir("pintemod");
    mkdir("pintemod/localization");
    mkdir("pintemod/localization/manual");
    mkdir("pintemod/localization/auto");
    mkdir("pintemod/localization/requests");
    mkdir("pintemod/localization/responses");

    addcommand("ezzlang", ::cmd_ezzlang);
    addcommand("ezzlocalizationstatus", ::cmd_ezzlocalizationstatus);
    addcommand("ezzlocalizationtest", ::cmd_ezzlocalizationtest);

    level.pintemod_localization_version = "2.1.1";
    level thread localization_bootstrap();

    println("^5[PinteMod]^7 Localization v2.1.1 loaded");
}
