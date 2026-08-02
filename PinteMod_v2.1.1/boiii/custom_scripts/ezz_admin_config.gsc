// ============================================================
// PinteMod — Configuration centralisée v2.1.1
// Fichier : ezz_admin_config.gsc
// Créé par BiereFraiche et ChatGPT
//
// Rôles : Owner 4, Admin 3, Moderator 2, Helper 1, User 0.
// Autorisation exclusivement par BOIII_XUID stable.
// Le pseudonyme reste un nom d'affichage et un sélecteur local.
// Les changements effectués avec .setrole restent temporaires et liés au XUID.
// ============================================================

autoexec function init()
{
    level.ezz_admin_version = "2.1.1";
    level.ezz_admin_debug = false;

    // --------------------------------------------------------
    // Central chat/HUD color theme
    // --------------------------------------------------------
    level.ezz_color_success = "^2";
    level.ezz_color_error = "^1";
    level.ezz_color_warning = "^3";
    level.ezz_color_admin = "^5";
    level.ezz_color_info = "^6";
    level.ezz_color_normal = "^7";
    level.ezz_admin_prefix = "^5[PinteMod]^7";

    // --------------------------------------------------------
    // Stable role configuration — BOIII_XUID only
    // --------------------------------------------------------
    // No display-name fallback is accepted. The public PinteMod package
    // keeps the project owner as the default bootstrap Owner. Server owners
    // should replace or remove this XUID using the installation tutorial,
    // then assign their own account with:
    //   ezzidsetrole <PlayerName|BOIII_XUID> owner
    // Persistent console assignments are stored in
    // boiii/scriptdata/pintemod/identity/roles.json.
    level.ezz_owner_xuids = [];
    level.ezz_owner_xuids[0] = "9cf34426f668fb8b"; // BiereFraiche

    level.ezz_admin_xuids = [];
    // level.ezz_admin_xuids[0] = "admin_boiii_xuid";

    level.ezz_moderator_xuids = [];
    // level.ezz_moderator_xuids[0] = "moderator_boiii_xuid";

    level.ezz_helper_xuids = [];
    // level.ezz_helper_xuids[0] = "helper_boiii_xuid";

    level.ezz_admin_max_points = 999999;

    // --------------------------------------------------------
    // Community features
    // --------------------------------------------------------
    level.pintemod_welcome_enabled = true;
    level.pintemod_welcome_delay = 6;

    level.pintemod_public_menu_enabled = true;
    level.pintemod_late_join_enabled = true;

    // .votemap now schedules the next map without interrupting
    // the current Zombies game. The current map may be selected
    // again to allow a community retry.
    level.pintemod_map_vote_enabled = true;
    level.pintemod_next_map_vote_enabled = true;
    level.pintemod_restart_vote_enabled = true;
    level.pintemod_votekick_enabled = true;
    level.pintemod_vote_logs_enabled = true;

    // Occasional native chat reminders. The delay is recalculated between
    // messages to keep them useful without becoming repetitive.
    level.pintemod_public_tips_enabled = true;
    level.pintemod_public_tips_min_delay = 240;
    level.pintemod_public_tips_max_delay = 420;

    level.pintemod_vote_duration = 45;
    level.pintemod_vote_cooldown = 180;
    // Solo players may schedule the next map or restart at 1/1.
    // Vote kick keeps its separate minimum of three players.
    level.pintemod_map_vote_min_players = 1;
    level.pintemod_map_change_delay = 5;

    level.pintemod_votekick_min_players = 3;
    level.pintemod_votekick_player_cooldown = 180;
    level.pintemod_votekick_target_cooldown = 300;
    level.pintemod_votekick_protect_moderators = false;
    level.pintemod_kick_delay = 3;

    // Commands exposed by the BOIII dedicated server.
    // Map votes only resolve to the 14 official BO3 Zombies map codes.
    // clientkick receives the current numeric client slot, never a display name.
    // Vote ownership, sanctions, reconnect blocking and presence are bound
    // to BOIII_XUID; the pseudonym is display metadata only.
    level.pintemod_map_command = "map";
    level.pintemod_kick_command = "clientkick";

    // --------------------------------------------------------
    // Existing validated modules
    // --------------------------------------------------------
    level.pintemod_enable_music = true;
    level.pintemod_enable_events = true;
    level.pintemod_max_spawned_bosses = 2;

    // Chat capture used by reports and the Live Console.
    level.pintemod_chat_history_size = 25;
    level.pintemod_chat_dedup_window_ms = 250;

    // --------------------------------------------------------
    // Localization FR / EN / ES and GeoIP privacy
    // --------------------------------------------------------
    // The GeoIP Bridge receives the IP only in memory through RCON status,
    // converts it to a country, then discards it. PinteMod persists only
    // BOIII_XUID + language. Manual .lang choices have priority over GeoIP.
    level.pintemod_default_language = "en";
    level.pintemod_geoip_enabled = true;
    level.pintemod_country_announce_enabled = true;

    // Persistent XUID bans. UTC expiration is maintained by the local Ban Service.
    level.pintemod_bans_enabled = true;

    // Moderation v2.1.1. Empty by default until a native BOIII mute
    // adapter is validated on the target dedicated-server build.
    level.pintemod_moderation_enabled = true;
    level.pintemod_native_mute_command = "";

    // Anonymous population counters. Only aggregate country/language
    // totals are stored; no IP or public player-country association.
    level.pintemod_langstats_enabled = true;

    // --------------------------------------------------------
    // Managed logs and privacy
    // --------------------------------------------------------
    // Normal player Chat is persisted for the read-only Live Console and
    // vote-kick evidence. XUID/GUID privacy settings still apply below.
    level.pintemod_log_chat_messages = true;
    level.pintemod_log_xuids = true;
    level.pintemod_log_guids = false;
    level.pintemod_log_max_size_kb = 2048;

    // The native BOIII console keeps only module startup, warnings and
    // explicit command output. Detailed runtime events remain available
    // in the PinteMod Live Console and managed session logs.
    level.pintemod_server_console_verbose = false;

    println("^5[PinteMod]^7 Configuration v2.1.1 loaded");
}
