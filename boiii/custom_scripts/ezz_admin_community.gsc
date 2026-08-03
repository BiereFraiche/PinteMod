// ============================================================
// PinteMod — Community Features v2.1.1
// Fichier : ezz_admin_community.gsc
// Créé par BiereFraiche et ChatGPT
//
// Accueil, menu public, late-join protégé, moteur de vote unique,
// rapports de votekick et journaux de connexion.
// Votes, sanctions temporaires et présence sont liés au BOIII_XUID.
// Les fichiers sont écrits relativement à boiii/scriptdata/.
// ============================================================

#using scripts\zm\_zm;
#using custom_scripts\ezz_admin_identity;
#using custom_scripts\ezz_admin_storage;
#using custom_scripts\ezz_admin_registry;
#using custom_scripts\ezz_admin_localization;


function community_append_file(path, text)
{
    if (ezz_admin_storage::append_managed_log(path, text))
        return true;

    println(
        "^1[PinteMod Community]^7 WRITE_FAILED | path=" + path
    );

    return false;
}

function community_write_file(path, text)
{
    if (ezz_admin_storage::write_managed_log(path, text))
        return true;

    println(
        "^1[PinteMod Community]^7 WRITE_FAILED | path=" + path
    );

    return false;
}


// ------------------------------------------------------------
// Global PinteMod message without BO3's [All]UnknownSoldier prefix
// ------------------------------------------------------------

function community_broadcast(message)
{
    players = GetPlayers();

    for (i = 0; i < players.size; i++)
    {
        player = players[i];

        if (isdefined(player))
            player iprintln(message);
    }
}

// Reliable server chat path. BOIII's console say/tell commands use the
// dedicated server sender and honour sv_sayname. This avoids the custom
// GSC tell() path which was not visible on the tested dedicated server.
function community_private_chat(player, message)
{
    if (!isdefined(player) || !isdefined(message) || message == "")
        return;

    client_number = player GetEntityNumber();
    ExecuteCommand("tell " + client_number + " " + message);
}

function community_broadcast_chat(message)
{
    if (!isdefined(message) || message == "")
        return;

    ExecuteCommand("say " + message);
}

autoexec function init()
{
    addcommand("ezzcommunitystatus", ::cmd_ezzcommunitystatus);
    addcommand("ezzjoin", ::cmd_ezzjoin);
    addcommand("ezzvotemap", ::cmd_ezzvotemap);
    addcommand("ezzvoterestart", ::cmd_ezzvoterestart);
    addcommand("ezzyes", ::cmd_ezzyes);
    addcommand("ezzno", ::cmd_ezzno);
    addcommand("ezzvotestatus", ::cmd_ezzvotestatus);
    addcommand("ezzvotekick", ::cmd_ezzvotekick);
    addcommand("ezzcancelvote", ::cmd_ezzcancelvote);
    addcommand("ezzclearnextmap", ::cmd_ezzclearnextmap);
    addcommand("ezzpublicinfo", ::cmd_ezzpublicinfo);
    addcommand("ezzpublicplayers", ::cmd_ezzpublicplayers);
    addcommand("ezzpublichelp", ::cmd_ezzpublichelp);
    addcommand("ezzpresencestatus", ::cmd_ezzpresencestatus);
    addcommand("ezzcommunitytest", ::cmd_ezzcommunitytest);

    // Name displayed for messages sent through the native server chat.
    SetDvar("sv_sayname", "PinteMod");

    level.pintemod_community_loaded = true;
    level.pintemod_community_version = "2.1.1";
    level.pintemod_vote_id = 0;
    level.pintemod_vote_cooldown_until = 0;
    level.pintemod_last_vote_summary = "No vote completed yet";
    level.pintemod_next_map_code = "";
    level.pintemod_next_map_display = "";
    level.pintemod_next_map_set_by = "";
    level.pintemod_next_map_loading = false;
    level.pintemod_public_tip_sequence = 0;
    level.pintemod_public_tip_last_index = -1;

    // Cleared naturally whenever the map scripts reload.
    level.pintemod_kicked_xuids = [];
    level.pintemod_votekick_initiator_cooldowns = [];
    level.pintemod_votekick_target_cooldowns = [];
    level.pintemod_presence_registry = [];

    level.pintemod_vote = SpawnStruct();
    level.pintemod_vote.active = false;

    mkdir("pintemod");
    mkdir("pintemod/logs");
    mkdir("pintemod/logs/chat");
    mkdir("pintemod/logs/votekick");

    community_append_file(
        "pintemod/logs/community.log",
        "=== PinteMod Community v2.1.1 loaded ===\n"
    );

    community_append_file(
        "pintemod/logs/connections.log",
        "=== PinteMod connection session started ===\n"
    );

    level thread community_bootstrap();
    level thread community_public_tip_monitor();
    level thread community_next_map_game_ended_monitor();
    level thread community_next_map_end_game_monitor();

    println("^5[PinteMod]^7 Community v2.1.1 loaded");
}

// ------------------------------------------------------------
// Configuration fallbacks
// ------------------------------------------------------------

function community_apply_defaults()
{
    if (!isdefined(level.pintemod_welcome_enabled))
        level.pintemod_welcome_enabled = true;

    if (!isdefined(level.pintemod_welcome_delay))
        level.pintemod_welcome_delay = 6;

    if (!isdefined(level.pintemod_message_duration))
        level.pintemod_message_duration = 15;

    if (!isdefined(level.pintemod_welcome_message_duration))
        level.pintemod_welcome_message_duration = 25;

    if (!isdefined(level.pintemod_message_line_count))
        level.pintemod_message_line_count = 8;

    if (!isdefined(level.pintemod_public_menu_enabled))
        level.pintemod_public_menu_enabled = true;

    if (!isdefined(level.pintemod_late_join_enabled))
        level.pintemod_late_join_enabled = true;

    // New mid-round connections can briefly report a non-spectator state
    // before BOIII settles them into spectator mode. Do not confirm them as
    // active from that transient state.
    if (!isdefined(level.pintemod_late_join_state_grace_ms))
        level.pintemod_late_join_state_grace_ms = 10000;

    if (!isdefined(level.pintemod_late_join_active_confirm_ms))
        level.pintemod_late_join_active_confirm_ms = 1500;

    if (!isdefined(level.pintemod_map_vote_enabled))
        level.pintemod_map_vote_enabled = true;

    if (!isdefined(level.pintemod_next_map_vote_enabled))
        level.pintemod_next_map_vote_enabled = true;

    if (!isdefined(level.pintemod_restart_vote_enabled))
        level.pintemod_restart_vote_enabled = true;

    if (!isdefined(level.pintemod_votekick_enabled))
        level.pintemod_votekick_enabled = true;

    if (!isdefined(level.pintemod_vote_logs_enabled))
        level.pintemod_vote_logs_enabled = true;

    if (!isdefined(level.pintemod_vote_duration))
        level.pintemod_vote_duration = 45;

    if (!isdefined(level.pintemod_vote_cooldown))
        level.pintemod_vote_cooldown = 180;

    if (!isdefined(level.pintemod_map_vote_min_players))
        level.pintemod_map_vote_min_players = 1;

    if (!isdefined(level.pintemod_map_change_delay))
        level.pintemod_map_change_delay = 5;

    if (!isdefined(level.pintemod_auto_map_rotation_enabled))
        level.pintemod_auto_map_rotation_enabled = false;

    if (!isdefined(level.pintemod_votekick_min_players))
        level.pintemod_votekick_min_players = 3;

    if (!isdefined(level.pintemod_votekick_player_cooldown))
        level.pintemod_votekick_player_cooldown = 180;

    if (!isdefined(level.pintemod_votekick_target_cooldown))
        level.pintemod_votekick_target_cooldown = 300;

    if (!isdefined(level.pintemod_votekick_protect_moderators))
        level.pintemod_votekick_protect_moderators = false;

    if (!isdefined(level.pintemod_kick_delay))
        level.pintemod_kick_delay = 3;

    if (!isdefined(level.pintemod_map_command))
        level.pintemod_map_command = "map";

    if (!isdefined(level.pintemod_kick_command))
        level.pintemod_kick_command = "clientkick";

    if (!isdefined(level.pintemod_public_tips_enabled))
        level.pintemod_public_tips_enabled = true;

    if (!isdefined(level.pintemod_public_tips_min_delay))
        level.pintemod_public_tips_min_delay = 240;

    if (!isdefined(level.pintemod_public_tips_max_delay))
        level.pintemod_public_tips_max_delay = 420;
}

// ------------------------------------------------------------
// Shared player and role helpers
// ------------------------------------------------------------

function community_find_player(player_name)
{
    return ezz_admin_identity::identity_find_player(player_name);
}

function community_get_role(player)
{
    return ezz_admin_identity::get_player_role(player);
}

function community_get_role_name(role)
{
    return ezz_admin_identity::get_role_name(role);
}


function community_get_xuid(player)
{
    if (!isdefined(player))
        return "";

    return ezz_admin_identity::get_player_xuid(player);
}

function community_find_player_by_xuid(xuid)
{
    if (!ezz_admin_identity::is_valid_xuid(xuid))
        return undefined;

    wanted_xuid = ezz_admin_identity::normalize_xuid(xuid);
    players = GetPlayers();

    for (i = 0; i < players.size; i++)
    {
        player = players[i];

        if (!isdefined(player))
            continue;

        if (community_get_xuid(player) == wanted_xuid)
            return player;
    }

    return undefined;
}

function community_vote_add_voter_entry(vote, xuid, display_name)
{
    if (!isdefined(vote) ||
        !ezz_admin_identity::is_valid_xuid(xuid))
    {
        return false;
    }

    if (!isdefined(vote.voters))
        vote.voters = [];

    normalized = ezz_admin_identity::normalize_xuid(xuid);

    for (i = 0; i < vote.voters.size; i++)
    {
        entry = vote.voters[i];

        if (isdefined(entry) && entry.xuid == normalized)
        {
            entry.display = display_name;
            return true;
        }
    }

    entry = SpawnStruct();
    entry.xuid = normalized;
    entry.display = display_name;
    vote.voters[vote.voters.size] = entry;
    return true;
}

function community_vote_get_voter_name(vote, xuid)
{
    normalized = ezz_admin_identity::normalize_xuid(xuid);

    if (isdefined(vote) && isdefined(vote.voters))
    {
        for (i = 0; i < vote.voters.size; i++)
        {
            entry = vote.voters[i];

            if (isdefined(entry) && entry.xuid == normalized)
                return entry.display;
        }
    }

    if (isdefined(vote) &&
        isdefined(vote.initiator_xuid) &&
        vote.initiator_xuid == normalized)
    {
        return vote.initiator_name;
    }

    if (isdefined(vote) &&
        isdefined(vote.target_xuid) &&
        vote.target_xuid == normalized)
    {
        return vote.target_name;
    }

    return normalized;
}

function community_cooldown_get(entries, xuid)
{
    if (!isdefined(entries) ||
        !ezz_admin_identity::is_valid_xuid(xuid))
    {
        return 0;
    }

    normalized = ezz_admin_identity::normalize_xuid(xuid);

    for (i = 0; i < entries.size; i++)
    {
        entry = entries[i];

        if (isdefined(entry) && entry.xuid == normalized)
            return entry.expires_at;
    }

    return 0;
}

function community_cooldown_set(entries, xuid, display_name, until_time)
{
    if (!isdefined(entries))
        entries = [];

    if (!ezz_admin_identity::is_valid_xuid(xuid))
        return entries;

    normalized = ezz_admin_identity::normalize_xuid(xuid);

    for (i = 0; i < entries.size; i++)
    {
        entry = entries[i];

        if (isdefined(entry) && entry.xuid == normalized)
        {
            entry.display = display_name;
            entry.expires_at = until_time;
            return entries;
        }
    }

    entry = SpawnStruct();
    entry.xuid = normalized;
    entry.display = display_name;
    entry.expires_at = until_time;
    entries[entries.size] = entry;
    return entries;
}


function community_presence_find_index(entries, xuid)
{
    if (!isdefined(entries) ||
        !ezz_admin_identity::is_valid_xuid(xuid))
    {
        return -1;
    }

    normalized = ezz_admin_identity::normalize_xuid(xuid);

    for (i = 0; i < entries.size; i++)
    {
        entry = entries[i];

        if (isdefined(entry) && entry.xuid == normalized)
            return i;
    }

    return -1;
}

function community_presence_get(entries, xuid)
{
    index = community_presence_find_index(entries, xuid);

    if (index < 0)
        return undefined;

    return entries[index];
}

function community_presence_upsert(
    entries,
    xuid,
    display_name,
    has_been_active,
    late_join_consumed,
    normal_death
)
{
    if (!isdefined(entries))
        entries = [];

    if (!ezz_admin_identity::is_valid_xuid(xuid))
        return entries;

    normalized = ezz_admin_identity::normalize_xuid(xuid);
    index = community_presence_find_index(entries, normalized);

    if (index >= 0)
    {
        entry = entries[index];
    }
    else
    {
        entry = SpawnStruct();
        entry.xuid = normalized;
        entries[entries.size] = entry;
    }

    entry.display = display_name;
    entry.has_been_active = has_been_active;
    entry.late_join_consumed = late_join_consumed;
    entry.normal_death = normal_death;
    return entries;
}

function community_presence_apply_to_player(player)
{
    if (!isdefined(player))
        return false;

    xuid = community_get_xuid(player);

    if (!ezz_admin_identity::is_valid_xuid(xuid))
        return false;

    if (!isdefined(level.pintemod_presence_registry))
        level.pintemod_presence_registry = [];

    entry = community_presence_get(
        level.pintemod_presence_registry,
        xuid
    );

    if (!isdefined(entry))
    {
        level.pintemod_presence_registry = community_presence_upsert(
            level.pintemod_presence_registry,
            xuid,
            player.name,
            false,
            false,
            false
        );

        entry = community_presence_get(
            level.pintemod_presence_registry,
            xuid
        );
    }

    if (!isdefined(entry))
        return false;

    player.pintemod_has_been_active = entry.has_been_active;
    player.pintemod_late_join_consumed = entry.late_join_consumed;
    player.pintemod_late_join_normal_death = entry.normal_death;
    return true;
}

function community_presence_sync_from_player(player)
{
    if (!isdefined(player))
        return false;

    xuid = community_get_xuid(player);

    if (!ezz_admin_identity::is_valid_xuid(xuid))
        return false;

    if (!isdefined(level.pintemod_presence_registry))
        level.pintemod_presence_registry = [];

    level.pintemod_presence_registry = community_presence_upsert(
        level.pintemod_presence_registry,
        xuid,
        player.name,
        player.pintemod_has_been_active,
        player.pintemod_late_join_consumed,
        player.pintemod_late_join_normal_death
    );

    return true;
}


function community_get_round()
{
    if (isdefined(level.round_number))
        return level.round_number;

    return 0;
}

function community_get_map_name()
{
    return toLower(GetDvarString("mapname"));
}

function community_get_map_display(map_name)
{
    return ezz_admin_registry::get_map_display_name(map_name);
}

function community_resolve_map_alias(alias)
{
    return ezz_admin_registry::resolve_map_alias(alias);
}

// ------------------------------------------------------------
// Array and text helpers
// ------------------------------------------------------------

function community_array_contains(values, wanted_value)
{
    if (!isdefined(values) || !isdefined(wanted_value))
        return false;

    wanted_lower = toLower(wanted_value);

    for (i = 0; i < values.size; i++)
    {
        if (toLower(values[i]) == wanted_lower)
            return true;
    }

    return false;
}

function community_array_add_unique(values, value)
{
    if (!isdefined(values))
        values = [];

    if (!community_array_contains(values, value))
        values[values.size] = value;

    return values;
}

function community_array_remove(values, value)
{
    result = [];

    if (!isdefined(values))
        return result;

    wanted_lower = toLower(value);

    for (i = 0; i < values.size; i++)
    {
        if (toLower(values[i]) != wanted_lower)
            result[result.size] = values[i];
    }

    return result;
}

function community_is_kicked_for_current_map(player_xuid)
{
    if (!ezz_admin_identity::is_valid_xuid(player_xuid))
        return false;

    if (!isdefined(level.pintemod_kicked_xuids))
        level.pintemod_kicked_xuids = [];

    return community_array_contains(
        level.pintemod_kicked_xuids,
        ezz_admin_identity::normalize_xuid(player_xuid)
    );
}

function community_mark_kicked_for_current_map(player_xuid, display_name)
{
    if (!ezz_admin_identity::is_valid_xuid(player_xuid))
        return false;

    if (!isdefined(level.pintemod_kicked_xuids))
        level.pintemod_kicked_xuids = [];

    normalized = ezz_admin_identity::normalize_xuid(player_xuid);
    level.pintemod_kicked_xuids = community_array_add_unique(
        level.pintemod_kicked_xuids,
        normalized
    );

    community_append_file(
        "pintemod/logs/community.log",
        "[" + GetTime() + "] KICK_REJOIN_BLOCK_ADDED | display=" +
        display_name + " | xuid=" + normalized + " | until=map_reload\n"
    );

    return true;
}

function community_reject_kicked_player()
{
    self endon("disconnect");

    player_name = "Unknown";
    player_xuid = "";

    // The connected notification may arrive before name/XUID are ready.
    for (ready_check = 0; ready_check < 50; ready_check++)
    {
        if (isdefined(self.name) && self.name != "")
            player_name = self.name;

        player_xuid = community_get_xuid(self);

        if (player_name != "Unknown" &&
            ezz_admin_identity::is_valid_xuid(player_xuid))
        {
            break;
        }

        wait 0.1;
    }

    if (!community_is_kicked_for_current_map(player_xuid))
        return;

    client_number = self GetEntityNumber();

    println(
        "^1[PinteMod][KICK]^7 Rejoin blocked until map reload | display=" +
        player_name + " | xuid=" + player_xuid +
        " | client=" + client_number
    );

    community_append_file(
        "pintemod/logs/community.log",
        "[" + GetTime() + "] KICK_REJOIN_BLOCKED | display=" +
        player_name + " | xuid=" + player_xuid +
        " | client=" + client_number + "\n"
    );

    community_private_chat(
        self,
        "^1[PinteMod]^7 You were vote-kicked and cannot rejoin until the next map."
    );

    wait 0.2;

    command_line = level.pintemod_kick_command +
        " " + client_number;
    executecommand(command_line);
}

function community_copy_array(values)
{
    result = [];

    if (!isdefined(values))
        return result;

    for (i = 0; i < values.size; i++)
        result[result.size] = values[i];

    return result;
}

function community_join_args(args, start_index)
{
    result = "";

    for (i = start_index; i < args.size; i++)
    {
        if (result != "")
            result = result + " ";

        result = result + args[i];
    }

    return result;
}

function community_get_remaining_seconds(end_time)
{
    remaining = end_time - GetTime();

    if (remaining <= 0)
        return 0;

    return int((remaining + 999) / 1000);
}

function community_vote_add_event(text)
{
    if (!isdefined(level.pintemod_vote) ||
        !level.pintemod_vote.active)
    {
        return;
    }

    entry = "[" + GetTime() + " ms] " + text;
    level.pintemod_vote.events[
        level.pintemod_vote.events.size
    ] = entry;
}

// ------------------------------------------------------------
// Occasional public reminders
// ------------------------------------------------------------

function community_public_tip_delay()
{
    minimum_delay = level.pintemod_public_tips_min_delay;
    maximum_delay = level.pintemod_public_tips_max_delay;

    if (minimum_delay < 60)
        minimum_delay = 60;

    if (maximum_delay < minimum_delay)
        maximum_delay = minimum_delay;

    spread = maximum_delay - minimum_delay + 1;
    seed = int(GetTime() / 1000) +
        (level.pintemod_public_tip_sequence * 37);
    offset = seed - (int(seed / spread) * spread);

    return minimum_delay + offset;
}

function community_public_tip_index()
{
    tip_count = 3;
    seed = int(GetTime() / 1000) +
        (level.pintemod_public_tip_sequence * 17);
    index = seed - (int(seed / tip_count) * tip_count);

    if (index == level.pintemod_public_tip_last_index)
    {
        index++;

        if (index >= tip_count)
            index = 0;
    }

    level.pintemod_public_tip_last_index = index;
    level.pintemod_public_tip_sequence++;
    return index;
}

function community_public_tip_message(tip_index)
{
    switch (tip_index)
    {
        case 0:
            return "^3[PinteMod]^7 Player trolling? Start a votekick from ^2.menu^7.";

        case 1:
            return "^3[PinteMod]^7 Choose the next map in the cycle from ^2.menu ^7> Community > Votes.";
    }

    return "^3[PinteMod]^7 Votes, rankings and map records are available in ^2.menu^7.";
}

function community_public_tip_plain_message(tip_index)
{
    switch (tip_index)
    {
        case 0:
            return "Player trolling? Start a votekick from .menu.";

        case 1:
            return "Choose the next map in the cycle from .menu > Community > Votes.";
    }

    return "Votes, rankings and map records are available in .menu.";
}

function community_public_tip_monitor()
{
    // First reminder after two minutes. Later reminders use the configured
    // variable delay. If no player is present or a vote is active, retry
    // after one minute instead of postponing the message for another
    // complete 4-7 minute interval.
    wait 120;

    for (;;)
    {
        community_apply_defaults();

        if (!level.pintemod_public_tips_enabled)
        {
            wait 60;
            continue;
        }

        players = GetPlayers();

        if (!isdefined(players) || players.size <= 0)
        {
            wait 60;
            continue;
        }

        if (isdefined(level.pintemod_vote) &&
            level.pintemod_vote.active)
        {
            wait 60;
            continue;
        }

        tip_index = community_public_tip_index();
        message = community_public_tip_message(tip_index);
        plain_message = community_public_tip_plain_message(tip_index);
        community_broadcast_chat(message);

        community_log_action(
            "PUBLIC_TIP_CHAT",
            "server",
            "index=" + tip_index + " | message=" + plain_message
        );

        wait community_public_tip_delay();
    }
}

// ------------------------------------------------------------
// Player connection, welcome and late-join state
// ------------------------------------------------------------

function community_bootstrap()
{
    wait 1;
    community_apply_defaults();

    players = GetPlayers();

    for (i = 0; i < players.size; i++)
    {
        player = players[i];

        if (isdefined(player))
            community_attach_player(player, true);
    }

    for (;;)
    {
        level waittill("connected", player);

        if (isdefined(player))
            community_attach_player(player, false);
    }
}

function community_attach_player(player, initial_player)
{
    if (!isdefined(player))
        return;

    if (isdefined(player.pintemod_community_monitor_started) &&
        player.pintemod_community_monitor_started)
    {
        return;
    }

    player.pintemod_community_monitor_started = true;
    player.pintemod_connection_name = player.name;
    player.pintemod_connection_xuid = community_get_xuid(player);
    player.pintemod_connection_client_number = player GetEntityNumber();

    player thread community_reject_kicked_player();

    if (community_is_kicked_for_current_map(
        player.pintemod_connection_xuid
    ))
    {
        return;
    }

    player.pintemod_late_join_eligible = false;
    player.pintemod_late_join_consumed = false;
    player.pintemod_late_join_normal_death = false;
    player.pintemod_late_join_spawned = false;
    player.pintemod_join_in_progress = false;
    player.pintemod_spectator_wait_logged = false;
    player.pintemod_spawn_prompt_sent = false;
    player.pintemod_has_been_active = false;
    player.pintemod_late_join_candidate = !initial_player;
    player.pintemod_late_join_attach_time = GetTime();
    player.pintemod_late_join_attach_round = community_get_round();
    player.pintemod_late_join_non_spectator_since = -1;
    player.pintemod_presence_ready =
        community_presence_apply_to_player(player);

    player.pintemod_connected_during_active_game =
        !initial_player &&
        player.pintemod_presence_ready &&
        !player.pintemod_has_been_active &&
        !player.pintemod_late_join_consumed &&
        !player.pintemod_late_join_normal_death &&
        community_get_round() >= 1 &&
        community_count_active_players(player) > 0;

    community_apply_message_settings(player);

    if (initial_player)
        community_log_player_event(player, "ACTIVE", false);
    else
        community_log_player_event(player, "JOIN", false);

    player thread community_disconnect_monitor();
    player thread community_welcome_monitor(initial_player);
    player thread community_late_join_state_monitor();

    if (!initial_player &&
        isdefined(level.pintemod_vote) &&
        level.pintemod_vote.active)
    {
        community_vote_add_event(
            player.name + " [" + player.pintemod_connection_xuid +
            "] joined after vote start; not eligible"
        );
    }
}

function community_apply_message_settings(player)
{
    if (!isdefined(player))
        return;

    community_apply_defaults();

    // BOIII method form accepts one complete "dvar value" string.
    // iPrintLn uses game message window 0 at the bottom-left.
    player SetClientDvar(
        "con_gameMsgWindow0MsgTime " +
        level.pintemod_message_duration
    );
    player SetClientDvar(
        "con_gameMsgWindow0LineCount " +
        level.pintemod_message_line_count
    );
    player SetClientDvar("con_gameMsgWindow0FadeInTime 0.15");
    player SetClientDvar("con_gameMsgWindow0FadeOutTime 1.0");
    player SetClientDvar("con_gameMsgWindow0ScrollTime 0.15");
}

function community_restore_message_duration_after_welcome()
{
    self endon("disconnect");

    wait level.pintemod_welcome_message_duration;

    self SetClientDvar(
        "con_gameMsgWindow0MsgTime " +
        level.pintemod_message_duration
    );
}

function community_clear_welcome_hud()
{
    if (isdefined(self.pintemod_welcome_hud_title))
    {
        self.pintemod_welcome_hud_title destroy();
        self.pintemod_welcome_hud_title = undefined;
    }

    if (isdefined(self.pintemod_welcome_hud_menu))
    {
        self.pintemod_welcome_hud_menu destroy();
        self.pintemod_welcome_hud_menu = undefined;
    }

    if (isdefined(self.pintemod_welcome_hud_spawn))
    {
        self.pintemod_welcome_hud_spawn destroy();
        self.pintemod_welcome_hud_spawn = undefined;
    }
}

function community_welcome_hud_timeout()
{
    self notify("pintemod_welcome_hud_refresh");
    self endon("pintemod_welcome_hud_refresh");
    self endon("disconnect");

    wait level.pintemod_welcome_message_duration;

    if (isdefined(self.pintemod_welcome_hud_title))
    {
        self.pintemod_welcome_hud_title fadeovertime(1);
        self.pintemod_welcome_hud_title.alpha = 0;
    }

    if (isdefined(self.pintemod_welcome_hud_menu))
    {
        self.pintemod_welcome_hud_menu fadeovertime(1);
        self.pintemod_welcome_hud_menu.alpha = 0;
    }

    if (isdefined(self.pintemod_welcome_hud_spawn))
    {
        self.pintemod_welcome_hud_spawn fadeovertime(1);
        self.pintemod_welcome_hud_spawn.alpha = 0;
    }

    wait 1;
    self community_clear_welcome_hud();
}

function community_show_welcome_hud()
{
    if (!isdefined(self))
        return;

    self community_clear_welcome_hud();

    // Dedicated bottom-left HUD: independent from iPrintLn window timing.
    self.pintemod_welcome_hud_title = newclienthudelem(self);
    self.pintemod_welcome_hud_title.horzalign = "left";
    self.pintemod_welcome_hud_title.vertalign = "bottom";
    self.pintemod_welcome_hud_title.alignx = "left";
    self.pintemod_welcome_hud_title.aligny = "bottom";
    self.pintemod_welcome_hud_title.x = 20;
    self.pintemod_welcome_hud_title.y = -205;
    self.pintemod_welcome_hud_title.fontscale = 1.35;
    self.pintemod_welcome_hud_title.alpha = 1;
    self.pintemod_welcome_hud_title.sort = 1000;
    self.pintemod_welcome_hud_title setText(
        ezz_admin_localization::text(self, "welcome_title")
    );

    self.pintemod_welcome_hud_menu = newclienthudelem(self);
    self.pintemod_welcome_hud_menu.horzalign = "left";
    self.pintemod_welcome_hud_menu.vertalign = "bottom";
    self.pintemod_welcome_hud_menu.alignx = "left";
    self.pintemod_welcome_hud_menu.aligny = "bottom";
    self.pintemod_welcome_hud_menu.x = 20;
    self.pintemod_welcome_hud_menu.y = -180;
    self.pintemod_welcome_hud_menu.fontscale = 1.15;
    self.pintemod_welcome_hud_menu.alpha = 1;
    self.pintemod_welcome_hud_menu.sort = 1000;
    self.pintemod_welcome_hud_menu setText(
        ezz_admin_localization::text(self, "welcome_menu")
    );

    self.pintemod_welcome_hud_spawn = newclienthudelem(self);
    self.pintemod_welcome_hud_spawn.horzalign = "left";
    self.pintemod_welcome_hud_spawn.vertalign = "bottom";
    self.pintemod_welcome_hud_spawn.alignx = "left";
    self.pintemod_welcome_hud_spawn.aligny = "bottom";
    self.pintemod_welcome_hud_spawn.x = 20;
    self.pintemod_welcome_hud_spawn.y = -155;
    self.pintemod_welcome_hud_spawn.fontscale = 1.15;
    self.pintemod_welcome_hud_spawn.alpha = 1;
    self.pintemod_welcome_hud_spawn.sort = 1000;

    if (level.pintemod_late_join_enabled)
    {
        self.pintemod_welcome_hud_spawn setText(
            ezz_admin_localization::text(self, "welcome_spawn")
        );
    }
    else
    {
        self.pintemod_welcome_hud_spawn setText(
            ezz_admin_localization::text(self, "welcome_community")
        );
    }

    self thread community_welcome_hud_timeout();
}

function community_disconnect_monitor()
{
    player_name = "Unknown";
    player_xuid = "";
    client_number = -1;

    if (isdefined(self.pintemod_connection_name))
        player_name = self.pintemod_connection_name;
    else if (isdefined(self.name))
        player_name = self.name;

    if (isdefined(self.pintemod_connection_xuid))
        player_xuid = self.pintemod_connection_xuid;
    else
        player_xuid = ezz_admin_identity::get_player_xuid(self);

    if (isdefined(self.pintemod_connection_client_number))
        client_number = self.pintemod_connection_client_number;
    else
        client_number = self GetEntityNumber();

    self waittill("disconnect");
    community_handle_disconnect_snapshot(
        player_name,
        player_xuid,
        client_number
    );
}

function community_welcome_monitor(initial_player)
{
    self endon("disconnect");

    community_apply_defaults();
    wait level.pintemod_welcome_delay;

    // The connected event can fire while the client is still loading.
    // Wait for a usable player state, then send the welcome several times.
    for (ready_check = 0; ready_check < 60; ready_check++)
    {
        if (isdefined(self.name) && self.name != "" &&
            isdefined(self.sessionstate))
        {
            break;
        }

        wait 0.25;
    }

    if (level.pintemod_welcome_enabled)
    {
        // Keep the normal bottom-left window configured for other messages.
        community_apply_message_settings(self);
        wait 0.5;

        // Main delivery: dedicated HUD for 25 seconds with native iPrintLn fallback.
        self community_show_welcome_hud();
        self iprintln(
            ezz_admin_localization::text(self, "welcome_line")
        );
        community_append_file(
            "pintemod/logs/community.log",
            "[" + GetTime() + "] WELCOME_SENT_HUD | " +
            self.name + " | hud=custom+iprintln | chat=disabled\n"
        );
    }

    if (initial_player || !level.pintemod_late_join_enabled)
        return;

    if (!self.pintemod_connected_during_active_game)
        return;

    for (check = 0; check < 40; check++)
    {
        if (isdefined(self.sessionstate) &&
            self.sessionstate == "spectator" &&
            community_get_round() >= 1 &&
            community_count_active_players(self) > 0)
        {
            community_mark_late_join_eligible(self, "welcome");
            return;
        }

        // A new connection can transiently look active before BOIII moves
        // it to spectator. Only stop waiting after activity was confirmed by
        // the stabilized state monitor.
        if (isdefined(self.sessionstate) &&
            self.sessionstate != "spectator" &&
            self.pintemod_has_been_active)
        {
            return;
        }

        wait 0.5;
    }
}

function community_late_join_should_confirm_active(
    late_join_candidate,
    attach_round,
    current_round,
    attach_time,
    non_spectator_since,
    now_time
)
{
    if (!late_join_candidate || attach_round < 1)
        return true;

    // A natural spawn on the next round is authoritative.
    if (current_round > attach_round)
        return true;

    if (non_spectator_since < 0)
        return false;

    if ((now_time - attach_time) <
        level.pintemod_late_join_state_grace_ms)
    {
        return false;
    }

    return (now_time - non_spectator_since) >=
        level.pintemod_late_join_active_confirm_ms;
}

function community_late_join_state_is_eligible(
    candidate,
    presence_ready,
    has_been_active,
    consumed,
    normal_death,
    is_spectator,
    round_number,
    active_survivors
)
{
    return candidate &&
        presence_ready &&
        !has_been_active &&
        !consumed &&
        !normal_death &&
        is_spectator &&
        round_number >= 1 &&
        active_survivors > 0;
}

function community_refresh_late_join_eligibility(player, source)
{
    if (!isdefined(player))
        return false;

    is_spectator = isdefined(player.sessionstate) &&
        player.sessionstate == "spectator";
    active_survivors = community_count_active_players(player);

    if (!community_late_join_state_is_eligible(
        player.pintemod_late_join_candidate,
        player.pintemod_presence_ready,
        player.pintemod_has_been_active,
        player.pintemod_late_join_consumed,
        player.pintemod_late_join_normal_death,
        is_spectator,
        community_get_round(),
        active_survivors
    ))
    {
        return false;
    }

    player.pintemod_connected_during_active_game = true;
    community_mark_late_join_eligible(player, source);
    return player.pintemod_late_join_eligible;
}

function community_late_join_state_details(player, reason)
{
    state = "undefined";
    candidate = false;
    connected_midgame = false;
    active = false;
    eligible = false;
    consumed = false;
    normal_death = false;
    presence_ready = false;
    attach_round = -1;
    attach_elapsed = -1;

    if (isdefined(player.sessionstate))
        state = player.sessionstate;

    if (isdefined(player.pintemod_late_join_candidate))
        candidate = player.pintemod_late_join_candidate;

    if (isdefined(player.pintemod_connected_during_active_game))
        connected_midgame = player.pintemod_connected_during_active_game;

    if (isdefined(player.pintemod_has_been_active))
        active = player.pintemod_has_been_active;

    if (isdefined(player.pintemod_late_join_eligible))
        eligible = player.pintemod_late_join_eligible;

    if (isdefined(player.pintemod_late_join_consumed))
        consumed = player.pintemod_late_join_consumed;

    if (isdefined(player.pintemod_late_join_normal_death))
        normal_death = player.pintemod_late_join_normal_death;

    if (isdefined(player.pintemod_presence_ready))
        presence_ready = player.pintemod_presence_ready;

    if (isdefined(player.pintemod_late_join_attach_round))
        attach_round = player.pintemod_late_join_attach_round;

    if (isdefined(player.pintemod_late_join_attach_time))
        attach_elapsed = GetTime() - player.pintemod_late_join_attach_time;

    return "reason=" + reason +
        " | sessionstate=" + state +
        " | candidate=" + candidate +
        " | connected_midgame=" + connected_midgame +
        " | presence_ready=" + presence_ready +
        " | active=" + active +
        " | eligible=" + eligible +
        " | consumed=" + consumed +
        " | normal_death=" + normal_death +
        " | attach_round=" + attach_round +
        " | current_round=" + community_get_round() +
        " | attach_elapsed_ms=" + attach_elapsed +
        " | active_survivors=" +
        community_count_active_players(player);
}

function community_late_join_state_monitor()
{
    self endon("disconnect");

    was_active_after_join = false;

    for (;;)
    {
        is_active = false;
        now_time = GetTime();
        current_round = community_get_round();

        if (isdefined(self.sessionstate) &&
            self.sessionstate != "spectator")
        {
            is_active = true;

            if (!isdefined(self.pintemod_late_join_non_spectator_since) ||
                self.pintemod_late_join_non_spectator_since < 0)
            {
                self.pintemod_late_join_non_spectator_since = now_time;
            }

            if (!self.pintemod_has_been_active &&
                community_late_join_should_confirm_active(
                    self.pintemod_late_join_candidate,
                    self.pintemod_late_join_attach_round,
                    current_round,
                    self.pintemod_late_join_attach_time,
                    self.pintemod_late_join_non_spectator_since,
                    now_time
                ))
            {
                self.pintemod_has_been_active = true;
                self.pintemod_late_join_eligible = false;
                community_presence_sync_from_player(self);

                if (self.pintemod_late_join_candidate)
                {
                    community_log_action(
                        "LATE_JOIN_ACTIVE_CONFIRMED",
                        self.name,
                        "round=" + current_round +
                        " | attach_round=" +
                        self.pintemod_late_join_attach_round +
                        " | stable_ms=" +
                        (now_time -
                        self.pintemod_late_join_non_spectator_since)
                    );
                }
            }
        }
        else
        {
            self.pintemod_late_join_non_spectator_since = -1;
        }

        // Re-evaluate the real state continuously. This also recovers from
        // a transient non-spectator state observed during connection.
        community_refresh_late_join_eligibility(
            self,
            "state-monitor"
        );

        if (is_active && self.pintemod_late_join_spawned)
            was_active_after_join = true;

        if (was_active_after_join && !is_active &&
            !self.pintemod_join_in_progress)
        {
            self.pintemod_late_join_normal_death = true;
            self.pintemod_late_join_spawned = false;
            was_active_after_join = false;
            community_presence_sync_from_player(self);

            community_append_file(
                "pintemod/logs/community.log",
                "[" + GetTime() + "] NORMAL_DEATH_AFTER_LATE_JOIN | " +
                self.name + "\n"
            );
        }

        wait 0.25;
    }
}

function community_log_action(event_name, player_name, details)
{
    line = event_name + " | " + player_name;

    if (isdefined(details) && details != "")
        line = line + " | " + details;

    community_append_file(
        "pintemod/logs/community.log",
        "[" + GetTime() + "] " + line + "\n"
    );

    if (isdefined(level.pintemod_server_console_verbose) &&
        level.pintemod_server_console_verbose)
    {
        println("^5[PinteMod][COMMUNITY]^7 " + line);
    }
}

function community_mark_late_join_eligible(player, source)
{
    if (!isdefined(player) ||
        !isdefined(player.pintemod_presence_ready) ||
        !player.pintemod_presence_ready ||
        player.pintemod_has_been_active ||
        player.pintemod_late_join_consumed ||
        player.pintemod_late_join_normal_death)
    {
        return;
    }

    player.pintemod_late_join_eligible = true;

    if (!isdefined(player.pintemod_spawn_prompt_sent) ||
        !player.pintemod_spawn_prompt_sent)
    {
        player.pintemod_spawn_prompt_sent = true;

        player iprintln(
            ezz_admin_localization::text(player, "latejoin_spectator")
        );
        player iprintln(
            ezz_admin_localization::text(player, "latejoin_type_spawn")
        );

        if (level.pintemod_public_menu_enabled)
        {
            player iprintln(
                ezz_admin_localization::text(player, "latejoin_menu_spawn")
            );
        }

        community_private_chat(
            player,
            ezz_admin_localization::text(player, "latejoin_type_spawn")
        );

        community_log_action(
            "SPECTATOR_SPAWN_PROMPT",
            player.name,
            "round=" + community_get_round() +
            " | source=" + source
        );
    }

    if (isdefined(player.pintemod_spectator_wait_logged) &&
        player.pintemod_spectator_wait_logged)
    {
        return;
    }

    player.pintemod_spectator_wait_logged = true;

    community_log_action(
        "SPECTATOR_WAITING",
        player.name,
        "round=" + community_get_round() +
        " | join=available | source=" + source
    );
}

function community_count_connected_players_excluding_identity(
    excluded_xuid,
    excluded_client_number
)
{
    count = 0;
    players = GetPlayers();
    valid_excluded_xuid = ezz_admin_identity::is_valid_xuid(excluded_xuid);

    for (i = 0; i < players.size; i++)
    {
        connected_player = players[i];

        if (!isdefined(connected_player))
            continue;

        connected_client = connected_player GetEntityNumber();
        connected_xuid = community_get_xuid(connected_player);

        if (valid_excluded_xuid && connected_xuid == excluded_xuid)
            continue;

        if (!valid_excluded_xuid &&
            connected_client == excluded_client_number)
        {
            continue;
        }

        count++;
    }

    return count;
}

function community_count_connected_players(excluded_player)
{
    count = 0;
    players = GetPlayers();

    for (i = 0; i < players.size; i++)
    {
        connected_player = players[i];

        if (!isdefined(connected_player))
            continue;

        if (isdefined(excluded_player) &&
            connected_player == excluded_player)
        {
            continue;
        }

        count++;
    }

    return count;
}

function community_count_active_players(excluded_player)
{
    count = 0;
    players = GetPlayers();

    for (i = 0; i < players.size; i++)
    {
        player = players[i];

        if (!isdefined(player) || player == excluded_player)
            continue;

        if (isdefined(player.sessionstate) &&
            player.sessionstate != "spectator")
        {
            count++;
        }
    }

    return count;
}

function community_log_player_event_values(
    player_name,
    player_xuid,
    client_number,
    event_name,
    player_count
)
{
    round_number = community_get_round();
    time_ms = GetTime();

    logged_xuid = ezz_admin_storage::log_xuid(player_xuid);

    plain_line =
        "[" + time_ms + " ms]" +
        "[round " + round_number + "]" +
        "[" + event_name + "] " +
        player_name +
        " | xuid=" + logged_xuid +
        " | client=" + client_number +
        " | players=" + player_count;

    community_append_file(
        "pintemod/logs/connections.log",
        plain_line + "\n"
    );

    if (isdefined(level.pintemod_vote) &&
        level.pintemod_vote.active)
    {
        community_vote_add_event(
            event_name + " | " + player_name +
            " | xuid=" + player_xuid +
            " | client=" + client_number +
            " | players=" + player_count
        );
    }

    if (!isdefined(level.pintemod_server_console_verbose) ||
        !level.pintemod_server_console_verbose)
    {
        return;
    }

    if (event_name == "JOIN")
    {
        println(
            "^2[PinteMod][JOIN]^7 " + player_name +
            " ^7| xuid=" + player_xuid +
            " | client=" + client_number +
            " | players=" + player_count
        );
        return;
    }

    if (event_name == "LEAVE")
    {
        println(
            "^1[PinteMod][LEAVE]^7 " + player_name +
            " ^7| xuid=" + player_xuid +
            " | client=" + client_number +
            " | players=" + player_count
        );
        return;
    }

    println(
        "^5[PinteMod][ACTIVE]^7 " + player_name +
        " ^7| xuid=" + player_xuid +
        " | client=" + client_number +
        " | players=" + player_count
    );
}

function community_log_player_event(
    player,
    event_name,
    exclude_player_from_count
)
{
    if (!isdefined(player))
        return;

    player_name = "Unknown";
    player_xuid = "";
    client_number = -1;

    if (isdefined(player.pintemod_connection_name))
        player_name = player.pintemod_connection_name;
    else if (isdefined(player.name))
        player_name = player.name;

    if (isdefined(player.pintemod_connection_xuid))
        player_xuid = player.pintemod_connection_xuid;
    else
        player_xuid = ezz_admin_identity::get_player_xuid(player);

    if (isdefined(player.pintemod_connection_client_number))
        client_number = player.pintemod_connection_client_number;
    else
        client_number = player GetEntityNumber();

    excluded_player = undefined;

    if (exclude_player_from_count)
        excluded_player = player;

    player_count = community_count_connected_players(excluded_player);

    community_log_player_event_values(
        player_name,
        player_xuid,
        client_number,
        event_name,
        player_count
    );
}

function community_handle_disconnect_snapshot(player_name, player_xuid, client_number)
{
    player_count = community_count_connected_players_excluding_identity(
        player_xuid,
        client_number
    );

    community_log_player_event_values(
        player_name,
        player_xuid,
        client_number,
        "LEAVE",
        player_count
    );

    if (!isdefined(level.pintemod_vote) ||
        !level.pintemod_vote.active)
    {
        return;
    }

    if (ezz_admin_identity::is_valid_xuid(player_xuid) &&
        level.pintemod_vote.initiator_xuid == player_xuid)
    {
        community_finish_vote(false, "Initiator disconnected");
        return;
    }

    if (level.pintemod_vote.type == "kick" &&
        ezz_admin_identity::is_valid_xuid(player_xuid) &&
        level.pintemod_vote.target_xuid == player_xuid)
    {
        community_finish_vote(
            false,
            "Target disconnected before the result"
        );
        return;
    }

    if (community_array_contains(
        level.pintemod_vote.required_xuids,
        player_xuid
    ))
    {
        level.pintemod_vote.required_xuids =
            community_array_remove(
                level.pintemod_vote.required_xuids,
                player_xuid
            );

        level.pintemod_vote.yes_xuids = community_array_remove(
            level.pintemod_vote.yes_xuids,
            player_xuid
        );

        level.pintemod_vote.no_xuids = community_array_remove(
            level.pintemod_vote.no_xuids,
            player_xuid
        );

        community_broadcast(
            "^5[PinteMod]^7 Required voter left. Vote: ^2" +
            level.pintemod_vote.yes_xuids.size + "/" +
            level.pintemod_vote.required_xuids.size
        );

        community_check_unanimity();
    }
}

// ------------------------------------------------------------
// Late-join spawn
// ------------------------------------------------------------

function cmd_ezzjoin(args)
{
    community_apply_defaults();

    if (!level.pintemod_late_join_enabled)
    {
        println("^3[PinteMod]^7 Late-join spawn is disabled");
        return;
    }

    if (args.size < 1)
    {
        println("^5[PinteMod]^7 Usage: ezzjoin <PlayerName|BOIII_XUID|ClientNumber>");
        return;
    }

    player = community_find_player(args[0]);

    if (!isdefined(player))
    {
        println("^1[PinteMod] Player not found: " + args[0]);
        return;
    }

    community_log_action(
        "LATE_JOIN_ATTEMPT",
        player.name,
        "xuid=" + community_get_xuid(player) +
        " | round=" + community_get_round()
    );

    if (!isdefined(player.pintemod_presence_ready) ||
        !player.pintemod_presence_ready)
    {
        player iprintln(
            ezz_admin_localization::text(player, "latejoin_identity")
        );
        community_log_action(
            "LATE_JOIN_REJECTED",
            player.name,
            "reason=identity-unavailable"
        );
        return;
    }

    // Recalculate from the current BOIII state at command time instead of
    // depending only on a flag produced by the asynchronous state monitor.
    community_refresh_late_join_eligibility(
        player,
        "command-refresh"
    );

    if (player.pintemod_late_join_normal_death)
    {
        player iprintln(
            ezz_admin_localization::text(player, "latejoin_normal_death")
        );
        community_log_action(
            "LATE_JOIN_REJECTED",
            player.name,
            community_late_join_state_details(
                player,
                "normal-death"
            )
        );
        return;
    }

    if (!player.pintemod_late_join_eligible ||
        player.pintemod_late_join_consumed)
    {
        player iprintln(
            ezz_admin_localization::text(player, "latejoin_not_eligible")
        );
        community_log_action(
            "LATE_JOIN_REJECTED",
            player.name,
            community_late_join_state_details(
                player,
                "not-eligible"
            )
        );
        return;
    }

    if (!isdefined(player.sessionstate) ||
        player.sessionstate != "spectator")
    {
        player.pintemod_late_join_eligible = false;
        player.pintemod_late_join_consumed = true;
        player.pintemod_has_been_active = true;
        community_presence_sync_from_player(player);
        player iprintln(ezz_admin_localization::text(player, "latejoin_already_active"));
        community_log_action(
            "LATE_JOIN_REJECTED",
            player.name,
            community_late_join_state_details(
                player,
                "already-active"
            )
        );
        return;
    }

    if (!isdefined(player.spectator_respawn))
    {
        player iprintln(ezz_admin_localization::text(player, "latejoin_not_ready"));
        community_log_action(
            "LATE_JOIN_REJECTED",
            player.name,
            community_late_join_state_details(
                player,
                "respawn-not-ready"
            )
        );
        return;
    }

    player.pintemod_join_in_progress = true;
    player zm::spectator_respawn_player();

    wait 0.25;

    if (isdefined(player.sessionstate) &&
        player.sessionstate != "spectator")
    {
        player.pintemod_late_join_eligible = false;
        player.pintemod_late_join_consumed = true;
        player.pintemod_late_join_spawned = true;
        player.pintemod_has_been_active = true;
        player.pintemod_join_in_progress = false;
        community_presence_sync_from_player(player);

        player iprintln(ezz_admin_localization::text(player, "latejoin_success"));
        community_broadcast("^2[PinteMod]^7 " + player.name + " joined the game.");

        community_log_action(
            "LATE_JOIN_SUCCESS",
            player.name,
            "map=" + community_get_map_name() +
            " | round=" + community_get_round()
        );
    }
    else
    {
        player.pintemod_join_in_progress = false;
        player iprintln(
            ezz_admin_localization::text(player, "latejoin_failed")
        );

        community_log_action(
            "LATE_JOIN_FAILED",
            player.name,
            community_late_join_state_details(
                player,
                "respawn-verification"
            )
        );
    }
}

// ------------------------------------------------------------
// Vote lifecycle
// ------------------------------------------------------------

function community_vote_is_available(requester)
{
    community_apply_defaults();

    if (isdefined(level.pintemod_vote) &&
        level.pintemod_vote.active)
    {
        requester iprintln("^3[PinteMod]^7 A vote is already active.");
        return false;
    }

    if (GetTime() < level.pintemod_vote_cooldown_until)
    {
        remaining = community_get_remaining_seconds(
            level.pintemod_vote_cooldown_until
        );

        requester iprintln(
            "^3[PinteMod]^7 Vote cooldown: " + remaining + "s"
        );
        return false;
    }

    return true;
}

function community_create_vote(vote_type, initiator)
{
    initiator_xuid = community_get_xuid(initiator);

    if (!ezz_admin_identity::is_valid_xuid(initiator_xuid))
    {
        initiator iprintln(
            "^1[PinteMod]^7 Stable identity unavailable; vote refused."
        );
        return false;
    }

    level.pintemod_vote_id++;

    vote = SpawnStruct();
    vote.active = true;
    vote.id = level.pintemod_vote_id;
    vote.type = vote_type;
    vote.initiator_name = initiator.name;
    vote.initiator_xuid = initiator_xuid;
    vote.initiator_role = community_get_role_name(
        community_get_role(initiator)
    );
    vote.target_name = "";
    vote.target_xuid = "";
    vote.target_role = "unavailable";
    vote.reason = "Not provided";
    vote.map_code = "";
    vote.map_display = "";
    vote.required_xuids = [];
    vote.yes_xuids = [];
    vote.no_xuids = [];
    vote.voters = [];
    vote.events = [];
    vote.start_time = GetTime();
    vote.end_time = GetTime() +
        (level.pintemod_vote_duration * 1000);
    vote.last_notice = -1;
    vote.initiator_chat_start = community_capture_chat(initiator);
    vote.target_chat_start = [];

    community_vote_add_voter_entry(
        vote,
        initiator_xuid,
        initiator.name
    );

    level.pintemod_vote = vote;

    community_vote_add_event(
        vote_type + " vote started by " + initiator.name +
        " [" + initiator_xuid + "]"
    );

    return true;
}

function community_capture_chat(player)
{
    empty_history = [];

    if (!isdefined(level.pintemod_log_chat_messages) ||
        !level.pintemod_log_chat_messages)
    {
        return empty_history;
    }

    if (!isdefined(player) ||
        !isdefined(player.pintemod_chat_history))
    {
        return empty_history;
    }

    return community_copy_array(player.pintemod_chat_history);
}

function community_add_all_players_to_required(excluded_player)
{
    players = GetPlayers();

    for (i = 0; i < players.size; i++)
    {
        player = players[i];

        if (!isdefined(player) || player == excluded_player)
            continue;

        player_xuid = community_get_xuid(player);

        if (!ezz_admin_identity::is_valid_xuid(player_xuid))
        {
            community_vote_add_event(
                player.name + " excluded: stable identity unavailable"
            );
            continue;
        }

        level.pintemod_vote.required_xuids =
            community_array_add_unique(
                level.pintemod_vote.required_xuids,
                player_xuid
            );

        community_vote_add_voter_entry(
            level.pintemod_vote,
            player_xuid,
            player.name
        );
    }
}

function community_start_vote_timer()
{
    vote_id = level.pintemod_vote.id;
    level thread community_vote_timer(vote_id);
}

function community_vote_timer(vote_id)
{
    for (;;)
    {
        wait 1;

        if (!isdefined(level.pintemod_vote) ||
            !level.pintemod_vote.active ||
            level.pintemod_vote.id != vote_id)
        {
            return;
        }

        remaining = community_get_remaining_seconds(
            level.pintemod_vote.end_time
        );

        if (remaining <= 0)
        {
            community_finish_vote(false, "Vote timed out");
            return;
        }

        if ((remaining == 15 || remaining == 5) &&
            level.pintemod_vote.last_notice != remaining)
        {
            level.pintemod_vote.last_notice = remaining;

            community_broadcast(
                "^5[PinteMod]^7 Vote: ^2" +
                level.pintemod_vote.yes_xuids.size + "/" +
                level.pintemod_vote.required_xuids.size +
                " YES ^7| " + remaining + "s remaining"
            );

            if (remaining == 15 &&
                (level.pintemod_vote.type == "nextmap" ||
                 level.pintemod_vote.type == "restart"))
            {
                community_broadcast_chat(
                    "Vote still open: use .yes or .no, or open .menu."
                );
            }
        }
    }
}

function community_check_unanimity()
{
    if (!isdefined(level.pintemod_vote) ||
        !level.pintemod_vote.active)
    {
        return;
    }

    required = level.pintemod_vote.required_xuids.size;
    yes_count = level.pintemod_vote.yes_xuids.size;

    if (required > 0 && yes_count >= required)
        community_finish_vote(true, "Unanimous approval");
}

function community_cast_vote(player, vote_yes)
{
    if (!isdefined(level.pintemod_vote) ||
        !level.pintemod_vote.active)
    {
        player iprintln("^3[PinteMod]^7 No vote is active.");
        return;
    }

    player_xuid = community_get_xuid(player);

    if (!ezz_admin_identity::is_valid_xuid(player_xuid))
    {
        player iprintln(
            "^1[PinteMod]^7 Stable identity unavailable; vote refused."
        );
        return;
    }

    if (!community_array_contains(
        level.pintemod_vote.required_xuids,
        player_xuid
    ))
    {
        player iprintln(
            "^3[PinteMod]^7 You are not an eligible voter for " +
            "this vote."
        );
        return;
    }

    if (community_array_contains(
        level.pintemod_vote.yes_xuids,
        player_xuid
    ) || community_array_contains(
        level.pintemod_vote.no_xuids,
        player_xuid
    ))
    {
        player iprintln("^3[PinteMod]^7 You already voted.");
        return;
    }

    community_vote_add_voter_entry(
        level.pintemod_vote,
        player_xuid,
        player.name
    );

    if (!vote_yes)
    {
        level.pintemod_vote.no_xuids =
            community_array_add_unique(
                level.pintemod_vote.no_xuids,
                player_xuid
            );

        community_vote_add_event(
            player.name + " [" + player_xuid + "] voted NO"
        );

        community_broadcast(
            "^1[PinteMod]^7 " + player.name +
            " voted NO. Unanimity was not reached."
        );

        community_finish_vote(false, player.name + " voted NO");
        return;
    }

    level.pintemod_vote.yes_xuids = community_array_add_unique(
        level.pintemod_vote.yes_xuids,
        player_xuid
    );

    community_vote_add_event(
        player.name + " [" + player_xuid + "] voted YES"
    );

    community_broadcast(
        "^2[PinteMod]^7 " + player.name + " voted YES. ^2" +
        level.pintemod_vote.yes_xuids.size + "/" +
        level.pintemod_vote.required_xuids.size
    );

    community_check_unanimity();
}

function community_get_pending_vote_count(vote)
{
    pending = vote.required_xuids.size -
        vote.yes_xuids.size - vote.no_xuids.size;

    if (pending < 0)
        pending = 0;

    return pending;
}

function community_build_vote_chat_summary(vote, passed)
{
    if (passed)
    {
        return "^2[PinteMod]^7 Vote passed: ^2" +
            vote.yes_xuids.size + "/" +
            vote.required_xuids.size + " YES";
    }

    summary = "^1[PinteMod]^7 Vote failed: ^2" +
        vote.yes_xuids.size + " YES^7, ^1" +
        vote.no_xuids.size + " NO";

    pending = community_get_pending_vote_count(vote);

    if (pending > 0)
        summary = summary + "^7, ^3" + pending + " missing";

    return summary;
}

function community_finish_vote(passed, result_reason)
{
    if (!isdefined(level.pintemod_vote) ||
        !level.pintemod_vote.active)
    {
        return;
    }

    community_vote_add_event(
        "Result: " + result_reason +
        " | passed=" + passed
    );

    vote = level.pintemod_vote;
    vote.active = false;

    level.pintemod_vote_cooldown_until = GetTime() +
        (level.pintemod_vote_cooldown * 1000);

    result_text = "FAILED";

    if (passed)
        result_text = "PASSED";

    summary = result_text + " | type=" + vote.type +
        " | initiator=" + vote.initiator_name +
        " [" + vote.initiator_xuid + "]" +
        " | yes=" + vote.yes_xuids.size + "/" +
        vote.required_xuids.size +
        " | reason=" + result_reason;

    level.pintemod_last_vote_summary = summary;

    if (level.pintemod_vote_logs_enabled)
    {
        community_append_file(
            "pintemod/logs/vote_summary.log",
            "[" + GetTime() + "] " + summary + "\n"
        );
    }

    report_path = "";

    if (vote.type == "kick" && level.pintemod_vote_logs_enabled)
    {
        report_path = community_write_kick_report(
            vote,
            passed,
            result_reason
        );
    }

    community_broadcast(community_build_vote_chat_summary(vote, passed));

    if (!passed)
        community_broadcast("^7Reason: " + result_reason);

    map_code = vote.map_code;
    map_display = vote.map_display;
    target_name = vote.target_name;
    target_xuid = vote.target_xuid;
    initiator_name = vote.initiator_name;

    level.pintemod_vote = SpawnStruct();
    level.pintemod_vote.active = false;

    if (passed && vote.type == "nextmap")
    {
        community_schedule_next_map(
            map_code,
            map_display,
            initiator_name
        );
    }

    if (passed && vote.type == "restart")
        level thread community_apply_map(map_code, map_display);

    if (passed && vote.type == "kick")
    {
        level thread community_apply_kick(
            target_xuid,
            target_name,
            report_path
        );
    }
}

function community_schedule_next_map(
    map_code,
    map_display,
    initiator_name
)
{
    level.pintemod_next_map_code = map_code;
    level.pintemod_next_map_display = map_display;
    level.pintemod_next_map_set_by = initiator_name;

    community_broadcast(
        "^2[PinteMod]^7 Next map scheduled: ^2" +
        map_display + "^7. Current game continues."
    );
    community_broadcast("^7It will load automatically when the game ends.");

    community_append_file(
        "pintemod/logs/community.log",
        "[" + GetTime() + "] NEXT_MAP_SCHEDULED | " +
        map_code + " | by=" + initiator_name + "\n"
    );
}

function community_clear_scheduled_next_map(cleared_by)
{
    if (!isdefined(level.pintemod_next_map_code) ||
        level.pintemod_next_map_code == "")
    {
        return false;
    }

    old_code = level.pintemod_next_map_code;
    old_display = level.pintemod_next_map_display;

    level.pintemod_next_map_code = "";
    level.pintemod_next_map_display = "";
    level.pintemod_next_map_set_by = "";

    community_append_file(
        "pintemod/logs/community.log",
        "[" + GetTime() + "] NEXT_MAP_CLEARED | " +
        old_code + " | by=" + cleared_by + "\n"
    );

    community_broadcast(
        "^3[PinteMod]^7 Scheduled next map cleared: " +
        old_display
    );

    return true;
}

function community_next_map_game_ended_monitor()
{
    level waittill("game_ended");
    community_handle_game_end("game_ended");
}

function community_next_map_end_game_monitor()
{
    level waittill("end_game");
    community_handle_game_end("end_game");
}

function community_handle_game_end(trigger_name)
{
    // BOIII may emit both end notifications for the same game.
    // The transition flag guarantees that only one command is executed.
    if (level.pintemod_next_map_loading)
        return;

    // A map selected by the community always overrides automatic rotation.
    if (isdefined(level.pintemod_next_map_code) &&
        level.pintemod_next_map_code != "")
    {
        community_apply_scheduled_next_map(trigger_name);
        return;
    }

    if (!level.pintemod_auto_map_rotation_enabled)
        return;

    level.pintemod_next_map_loading = true;
    level thread community_apply_auto_map_rotation(trigger_name);
}

function community_apply_auto_map_rotation(trigger_name)
{
    delay = level.pintemod_map_change_delay;
    previous_map = community_get_map_name();

    community_broadcast(
        "^5[PinteMod]^7 Loading the next map in the server rotation in " +
        delay + " seconds..."
    );

    community_append_file(
        "pintemod/logs/community.log",
        "[" + GetTime() + "] AUTO_MAP_ROTATE_TRIGGER | " +
        trigger_name + " | current=" + previous_map + "\n"
    );

    wait delay;

    community_append_file(
        "pintemod/logs/community.log",
        "[" + GetTime() + "] MAP_ROTATE_COMMAND | map_rotate\n"
    );

    println("^5[PinteMod]^7 Executing: map_rotate");
    executecommand("map_rotate");

    // A successful map_rotate unloads this script. Reaching this check
    // while the old map is still active means the command was rejected.
    wait 3;

    if (community_get_map_name() == previous_map)
    {
        level.pintemod_next_map_loading = false;
        println("^1[PinteMod] map_rotate command failed");
        community_broadcast(
            "^1[PinteMod]^7 Automatic map rotation failed."
        );
        community_append_file(
            "pintemod/logs/community.log",
            "[" + GetTime() + "] MAP_ROTATE_FAILED | current=" +
            previous_map + "\n"
        );
    }
}

function community_apply_scheduled_next_map(trigger_name)
{
    if (!isdefined(level.pintemod_next_map_code) ||
        level.pintemod_next_map_code == "" ||
        level.pintemod_next_map_loading)
    {
        return;
    }

    level.pintemod_next_map_loading = true;

    map_code = level.pintemod_next_map_code;
    map_display = level.pintemod_next_map_display;

    community_append_file(
        "pintemod/logs/community.log",
        "[" + GetTime() + "] NEXT_MAP_TRIGGER | " +
        trigger_name + " | map=" + map_code + "\n"
    );

    level.pintemod_next_map_code = "";
    level.pintemod_next_map_display = "";
    level.pintemod_next_map_set_by = "";

    level thread community_apply_map(map_code, map_display);
}

function community_apply_map(map_code, map_display)
{
    // Prevent the automatic end-of-game rotation from racing a PinteMod
    // map change or restart that is already waiting on its delay.
    level.pintemod_next_map_loading = true;

    delay = level.pintemod_map_change_delay;
    previous_map = community_get_map_name();

    community_broadcast(
        "^5[PinteMod]^7 Loading ^2" + map_display +
        " ^7in " + delay + " seconds..."
    );

    wait delay;

    command_line = level.pintemod_map_command + " " + map_code;

    community_append_file(
        "pintemod/logs/community.log",
        "[" + GetTime() + "] MAP_COMMAND | " +
        command_line + "\n"
    );

    println("^5[PinteMod]^7 Executing: " + command_line);
    executecommand(command_line);

    // A valid map command unloads this script. Reaching this check
    // with the old map still active means the command was rejected.
    wait 3;

    if (community_get_map_name() == previous_map)
    {
        level.pintemod_next_map_loading = false;
        println("^1[PinteMod] Vote passed but map command failed");
        community_broadcast("^1[PinteMod]^7 Vote passed but map command failed.");
        community_append_file(
            "pintemod/logs/community.log",
            "[" + GetTime() + "] MAP_COMMAND_FAILED | " +
            command_line + "\n"
        );
    }
}


function community_append_kick_summary(text)
{
    if (!level.pintemod_vote_logs_enabled)
        return;

    community_append_file(
        "pintemod/logs/votekick_summary.log",
        text + "\n"
    );
}

function community_apply_kick(target_xuid, target_name, report_path)
{
    if (!community_mark_kicked_for_current_map(
        target_xuid,
        target_name
    ))
    {
        community_broadcast(
            "^1[PinteMod]^7 Kick cancelled: stable target identity missing."
        );
        return;
    }

    community_broadcast(
        "^5[PinteMod]^7 Kick approved. Verification in " +
        level.pintemod_kick_delay + " seconds."
    );

    wait level.pintemod_kick_delay;

    target = community_find_player_by_xuid(target_xuid);

    if (!isdefined(target))
    {
        if (report_path != "")
        {
            community_append_file(
                report_path,
                "\nKick action: target already disconnected.\n"
            );
        }

        community_append_kick_summary(
            "[" + GetTime() + "] ACTION_SKIPPED | display=" +
            target_name + " | xuid=" + target_xuid +
            " | already disconnected"
        );
        return;
    }

    current_name = target.name;
    target_client_number = target GetEntityNumber();
    command_line = level.pintemod_kick_command +
        " " + target_client_number;

    if (report_path != "")
    {
        community_append_file(
            report_path,
            "\nKick command issued: " + command_line +
            " | target_xuid=" + target_xuid + "\n"
        );
    }

    community_append_file(
        "pintemod/logs/community.log",
        "[" + GetTime() + "] KICK_COMMAND | display=" +
        current_name + " | xuid=" + target_xuid +
        " | command=" + command_line + "\n"
    );

    println("^5[PinteMod]^7 Executing: " + command_line);
    executecommand(command_line);

    wait 1.5;

    target_after = community_find_player_by_xuid(target_xuid);

    if (isdefined(target_after))
    {
        println(
            "^1[PinteMod] Kick vote passed but target could not " +
            "be removed"
        );
        community_broadcast(
            "^1[PinteMod]^7 Kick vote passed but target could " +
            "not be removed."
        );

        if (report_path != "")
        {
            community_append_file(
                report_path,
                "Kick verification: XUID is still connected. " +
                "The configured command may be unsupported.\n"
            );
        }

        community_append_kick_summary(
            "[" + GetTime() + "] ACTION_FAILED | display=" +
            target_name + " | xuid=" + target_xuid +
            " | still connected"
        );
        return;
    }

    community_broadcast("^2[PinteMod]^7 " + target_name + " was removed.");

    if (report_path != "")
    {
        community_append_file(
            report_path,
            "Kick verification: target XUID disconnected.\n"
        );
    }

    community_append_kick_summary(
        "[" + GetTime() + "] ACTION_SUCCESS | display=" +
        target_name + " | xuid=" + target_xuid +
        " | disconnected"
    );
}

// ------------------------------------------------------------
// Vote reports
// ------------------------------------------------------------

function community_get_vote_state_for_player(vote, player_xuid)
{
    if (community_array_contains(vote.yes_xuids, player_xuid))
        return "YES";

    if (community_array_contains(vote.no_xuids, player_xuid))
        return "NO";

    return "PENDING";
}

function community_append_history(report, title, history)
{
    report = report +
        "\n------------------------------------------------------------\n";
    report = report + title + "\n";
    report = report +
        "------------------------------------------------------------\n";

    if (!isdefined(history) || history.size <= 0)
    {
        report = report + "No captured chat messages.\n";
        return report;
    }

    for (i = 0; i < history.size; i++)
        report = report + history[i] + "\n";

    return report;
}

function community_write_kick_report(vote, passed, result_reason)
{
    map_name = community_get_map_name();
    round_number = community_get_round();

    report_path = "pintemod/logs/votekick/votekick_" +
        map_name + "_r" + round_number + "_" +
        vote.start_time + "_" + vote.id + ".txt";

    initiator = community_find_player_by_xuid(vote.initiator_xuid);
    target = community_find_player_by_xuid(vote.target_xuid);

    chat_history_enabled = isdefined(level.pintemod_log_chat_messages) &&
        level.pintemod_log_chat_messages;
    initiator_history = [];
    target_history = [];

    if (chat_history_enabled)
    {
        initiator_history = vote.initiator_chat_start;
        target_history = vote.target_chat_start;

        if (isdefined(initiator))
            initiator_history = community_capture_chat(initiator);

        if (isdefined(target))
            target_history = community_capture_chat(target);
    }

    result_text = "FAILED";

    if (passed)
        result_text = "PASSED";

    report = "============================================================\n";
    report = report + "PinteMod Vote Kick Report — v2.1.1\n";
    report = report + "============================================================\n\n";
    report = report + "Server: " + GetDvarString("sv_hostname") + "\n";
    report = report + "Date/time: use the Windows file timestamp\n";
    report = report + "Game time at start: " + vote.start_time + " ms\n";
    report = report + "Game time at result: " + GetTime() + " ms\n";
    report = report + "Map: " + community_get_map_display(map_name) +
        " (" + map_name + ")\n";
    report = report + "Round: " + round_number + "\n";
    report = report + "Player count at result: " +
        GetPlayers().size + "\n\n";

    report = report + "Initiator: " + vote.initiator_name + "\n";
    report = report + "Initiator BOIII_XUID: " +
        vote.initiator_xuid + "\n";
    report = report + "Initiator role: " +
        vote.initiator_role + "\n";
    report = report + "Target: " + vote.target_name + "\n";
    report = report + "Target BOIII_XUID: " + vote.target_xuid + "\n";
    report = report + "Target role: " + vote.target_role + "\n";
    report = report + "Reason: " + vote.reason + "\n\n";

    report = report + "Result: " + result_text + "\n";
    report = report + "Result reason: " + result_reason + "\n";
    report = report + "YES votes: " + vote.yes_xuids.size + "\n";
    report = report + "NO votes: " + vote.no_xuids.size + "\n";
    report = report + "Required voters: " +
        vote.required_xuids.size + "\n";

    report = report +
        "\n------------------------------------------------------------\n";
    report = report + "Individual votes (BOIII_XUID bound)\n";
    report = report +
        "------------------------------------------------------------\n";

    for (i = 0; i < vote.required_xuids.size; i++)
    {
        voter_xuid = vote.required_xuids[i];
        voter_name = community_vote_get_voter_name(vote, voter_xuid);
        report = report + voter_name + " [" + voter_xuid + "]: " +
            community_get_vote_state_for_player(
                vote,
                voter_xuid
            ) + "\n";
    }

    report = report +
        "\n------------------------------------------------------------\n";
    report = report + "Vote and connection events\n";
    report = report +
        "------------------------------------------------------------\n";

    for (i = 0; i < vote.events.size; i++)
        report = report + vote.events[i] + "\n";

    if (chat_history_enabled)
    {
        report = community_append_history(
            report,
            "Recent chat — Initiator: " + vote.initiator_name +
            " [" + vote.initiator_xuid + "]",
            initiator_history
        );

        report = community_append_history(
            report,
            "Recent chat — Target: " + vote.target_name +
            " [" + vote.target_xuid + "]",
            target_history
        );
    }
    else
    {
        report = report +
            "\nChat history omitted: pintemod_log_chat_messages=false.\n";
    }

    if (passed)
    {
        report = report +
            "\nAction result is appended after command verification.\n";
    }
    else
    {
        report = report + "\nAction: not executed because vote failed.\n";
    }

    report = report + "============================================================\n";
    report = report + "End of initial report\n";
    report = report + "============================================================\n";

    community_write_file(report_path, report);

    community_append_file(
        "pintemod/logs/votekick_summary.log",
        "[" + GetTime() + "] " + result_text +
        " | " + vote.initiator_name + " [" + vote.initiator_xuid +
        "] -> " + vote.target_name + " [" + vote.target_xuid +
        "] | reason=" + vote.reason +
        " | report=" + report_path + "\n"
    );

    println("^5[PinteMod]^7 Vote kick report: " + report_path);

    return report_path;
}

// ------------------------------------------------------------
// Vote commands
// ------------------------------------------------------------

function cmd_ezzvotemap(args)
{
    community_apply_defaults();

    if (!level.pintemod_map_vote_enabled ||
        !level.pintemod_next_map_vote_enabled)
    {
        println("^3[PinteMod]^7 Next-map voting is disabled");
        return;
    }

    if (args.size < 2)
    {
        println(
            "^5[PinteMod]^7 Usage: " +
            "ezzvotemap <PlayerName|BOIII_XUID|ClientNumber> <MapAlias>"
        );
        return;
    }

    initiator = community_find_player(args[0]);

    if (!isdefined(initiator))
    {
        println("^1[PinteMod] Player not found: " + args[0]);
        return;
    }

    if (!community_vote_is_available(initiator))
        return;

    if (GetPlayers().size < level.pintemod_map_vote_min_players)
    {
        initiator iprintln(
            "^3[PinteMod]^7 At least " +
            level.pintemod_map_vote_min_players +
            " players are required."
        );
        return;
    }

    map_code = community_resolve_map_alias(args[1]);

    if (!isdefined(map_code))
    {
        initiator iprintln("^1[PinteMod]^7 Unknown map alias: " + args[1]);
        initiator iprintln(
            "^3Aliases: shadows, giant, de, zns, gk, rev, " +
            "nacht, verruckt, shino, kino, ascension, shang, " +
            "moon, origins"
        );
        return;
    }

    if (!community_create_vote("nextmap", initiator))
        return;
    level.pintemod_vote.map_code = map_code;
    level.pintemod_vote.map_display =
        community_get_map_display(map_code);

    community_add_all_players_to_required(undefined);

    level.pintemod_vote.yes_xuids = community_array_add_unique(
        level.pintemod_vote.yes_xuids,
        community_get_xuid(initiator)
    );

    community_vote_add_event(
        initiator.name + " [" + community_get_xuid(initiator) +
        "] automatically voted YES"
    );

    community_broadcast(
        "^5[PinteMod]^7 " + initiator.name +
        " started a NEXT MAP vote for ^2" +
        level.pintemod_vote.map_display + "^7."
    );

    community_broadcast(
        "^7Current game will continue. Open ^2.menu ^7or vote " +
        "with ^2.yes ^7/ ^1.no^7."
    );

    community_broadcast_chat(
        "NEXT MAP vote for " + level.pintemod_vote.map_display +
        ". Vote with .yes or .no, or open .menu."
    );

    community_append_file(
        "pintemod/logs/community.log",
        "[" + GetTime() + "] NEXT_MAP_VOTE_START | " +
        initiator.name + " [" + community_get_xuid(initiator) + "] | map=" + map_code + "\n"
    );

    community_start_vote_timer();
    community_check_unanimity();
}

function cmd_ezzvoterestart(args)
{
    community_apply_defaults();

    if (!level.pintemod_restart_vote_enabled)
    {
        println("^3[PinteMod]^7 Restart voting is disabled");
        return;
    }

    if (args.size < 1)
    {
        println(
            "^5[PinteMod]^7 Usage: " +
            "ezzvoterestart <PlayerName|BOIII_XUID|ClientNumber>"
        );
        return;
    }

    initiator = community_find_player(args[0]);

    if (!isdefined(initiator))
    {
        println("^1[PinteMod] Player not found: " + args[0]);
        return;
    }

    if (!community_vote_is_available(initiator))
        return;

    if (GetPlayers().size < level.pintemod_map_vote_min_players)
    {
        initiator iprintln(
            "^3[PinteMod]^7 At least " +
            level.pintemod_map_vote_min_players +
            " players are required."
        );
        return;
    }

    map_code = community_get_map_name();
    map_display = community_get_map_display(map_code);

    if (!community_create_vote("restart", initiator))
        return;
    level.pintemod_vote.map_code = map_code;
    level.pintemod_vote.map_display = map_display;

    community_add_all_players_to_required(undefined);

    level.pintemod_vote.yes_xuids = community_array_add_unique(
        level.pintemod_vote.yes_xuids,
        community_get_xuid(initiator)
    );

    community_vote_add_event(
        initiator.name + " [" + community_get_xuid(initiator) +
        "] automatically voted YES"
    );

    community_broadcast(
        "^5[PinteMod]^7 " + initiator.name +
        " started a RESTART vote for ^2" + map_display + "^7."
    );
    community_broadcast(
        "^7Open ^2.menu ^7or vote with ^2.yes ^7/ ^1.no^7."
    );
    community_broadcast_chat(
        "RESTART vote. Vote with .yes or .no, or open .menu."
    );

    community_append_file(
        "pintemod/logs/community.log",
        "[" + GetTime() + "] RESTART_VOTE_START | " +
        initiator.name + " [" + community_get_xuid(initiator) + "] | map=" + map_code + "\n"
    );

    community_start_vote_timer();
    community_check_unanimity();
}

function cmd_ezzvotekick(args)
{
    community_apply_defaults();

    if (!level.pintemod_votekick_enabled)
    {
        println("^3[PinteMod]^7 Vote kick is disabled");
        return;
    }

    if (args.size < 2)
    {
        println(
            "^5[PinteMod]^7 Usage: " +
            "ezzvotekick <Initiator|XUID|Client> <Target|XUID|Client> [Reason]"
        );
        return;
    }

    initiator = community_find_player(args[0]);
    target = community_find_player(args[1]);

    if (!isdefined(initiator))
    {
        println("^1[PinteMod] Player not found: " + args[0]);
        return;
    }

    if (!isdefined(target))
    {
        initiator iprintln("^1[PinteMod]^7 Player not found: " + args[1]);
        return;
    }

    if (initiator == target)
    {
        initiator iprintln("^1[PinteMod]^7 You cannot target yourself.");
        return;
    }

    if (GetPlayers().size < level.pintemod_votekick_min_players)
    {
        initiator iprintln(
            "^3[PinteMod]^7 At least " +
            level.pintemod_votekick_min_players +
            " players are required."
        );
        return;
    }

    target_role = community_get_role(target);

    if (target_role >= 3)
    {
        initiator iprintln("^1[PinteMod]^7 Owner and Admin are protected.");
        return;
    }

    if (target_role == 2 &&
        level.pintemod_votekick_protect_moderators)
    {
        initiator iprintln("^1[PinteMod]^7 Moderators are protected.");
        return;
    }

    initiator_xuid = community_get_xuid(initiator);
    target_xuid = community_get_xuid(target);

    if (!ezz_admin_identity::is_valid_xuid(initiator_xuid) ||
        !ezz_admin_identity::is_valid_xuid(target_xuid))
    {
        initiator iprintln(
            "^1[PinteMod]^7 Stable identity unavailable; vote refused."
        );
        return;
    }

    initiator_cooldown = community_cooldown_get(
        level.pintemod_votekick_initiator_cooldowns,
        initiator_xuid
    );

    if (GetTime() < initiator_cooldown)
    {
        remaining = community_get_remaining_seconds(initiator_cooldown);
        initiator iprintln(
            "^3[PinteMod]^7 Personal vote-kick cooldown: " +
            remaining + "s"
        );
        return;
    }

    target_cooldown = community_cooldown_get(
        level.pintemod_votekick_target_cooldowns,
        target_xuid
    );

    if (GetTime() < target_cooldown)
    {
        remaining = community_get_remaining_seconds(target_cooldown);
        initiator iprintln(
            "^3[PinteMod]^7 This identity was recently targeted. " +
            "Protection: " + remaining + "s"
        );
        return;
    }

    if (!community_vote_is_available(initiator))
        return;

    reason = "Not provided";

    if (args.size >= 3)
        reason = community_join_args(args, 2);

    if (ezz_admin_identity::has_dangerous_command_characters(reason))
    {
        initiator iprintln(
            "^1[PinteMod]^7 Unsafe vote-kick reason rejected."
        );
        println(
            "^1[PinteMod Community]^7 UNSAFE_REASON_REJECTED" +
            " | initiator=" + initiator.name +
            " | target=" + target.name
        );
        return;
    }

    level.pintemod_votekick_initiator_cooldowns =
        community_cooldown_set(
            level.pintemod_votekick_initiator_cooldowns,
            initiator_xuid,
            initiator.name,
            GetTime() +
                (level.pintemod_votekick_player_cooldown * 1000)
        );

    level.pintemod_votekick_target_cooldowns =
        community_cooldown_set(
            level.pintemod_votekick_target_cooldowns,
            target_xuid,
            target.name,
            GetTime() +
                (level.pintemod_votekick_target_cooldown * 1000)
        );

    if (!community_create_vote("kick", initiator))
        return;
    level.pintemod_vote.target_name = target.name;
    level.pintemod_vote.target_xuid = community_get_xuid(target);
    community_vote_add_voter_entry(
        level.pintemod_vote,
        level.pintemod_vote.target_xuid,
        target.name
    );
    level.pintemod_vote.target_role =
        community_get_role_name(target_role);
    level.pintemod_vote.reason = reason;
    level.pintemod_vote.target_chat_start =
        community_capture_chat(target);

    community_add_all_players_to_required(target);

    level.pintemod_vote.yes_xuids = community_array_add_unique(
        level.pintemod_vote.yes_xuids,
        community_get_xuid(initiator)
    );

    community_vote_add_event(
        initiator.name + " [" + community_get_xuid(initiator) +
        "] automatically voted YES"
    );

    community_broadcast(
        "^5[PinteMod]^7 " + initiator.name +
        " started a vote kick against ^1" +
        target.name + "^7."
    );

    community_broadcast("^7Reason: ^3" + reason);
    community_broadcast(
        "^7Target cannot vote. Type ^2.yes ^7or ^1.no^7. " +
        "Vote: ^2" + level.pintemod_vote.yes_xuids.size +
        "/" + level.pintemod_vote.required_xuids.size
    );

    target iprintln("^1[PinteMod]^7 A vote kick was started against you.");
    target iprintln("^7Reason: ^3" + reason);

    community_append_file(
        "pintemod/logs/community.log",
        "[" + GetTime() + "] KICK_VOTE_START | " +
        initiator.name + " [" + initiator_xuid + "] -> " +
        target.name + " [" + target_xuid + "] | reason=" + reason + "\n"
    );

    community_start_vote_timer();
    community_check_unanimity();
}

function cmd_ezzyes(args)
{
    if (args.size < 1)
    {
        println("^5[PinteMod]^7 Usage: ezzyes <PlayerName|BOIII_XUID|ClientNumber>");
        return;
    }

    player = community_find_player(args[0]);

    if (isdefined(player))
        community_cast_vote(player, true);
}

function cmd_ezzno(args)
{
    if (args.size < 1)
    {
        println("^5[PinteMod]^7 Usage: ezzno <PlayerName|BOIII_XUID|ClientNumber>");
        return;
    }

    player = community_find_player(args[0]);

    if (isdefined(player))
        community_cast_vote(player, false);
}

function community_show_vote_status(player)
{
    if (!isdefined(level.pintemod_vote) ||
        !level.pintemod_vote.active)
    {
        player iprintln("^3[PinteMod]^7 No vote is active.");

        if (isdefined(level.pintemod_next_map_code) &&
            level.pintemod_next_map_code != "")
        {
            player iprintln(
                "^5[PinteMod]^7 Scheduled next map: ^2" +
                level.pintemod_next_map_display
            );
        }

        player iprintln("^7Last result: " + level.pintemod_last_vote_summary);
        return;
    }

    vote = level.pintemod_vote;
    remaining = community_get_remaining_seconds(vote.end_time);

    if (vote.type == "nextmap")
    {
        player iprintln(
            "^5[PinteMod]^7 NEXT MAP VOTE: ^2" + vote.map_display
        );
    }
    else if (vote.type == "restart")
    {
        player iprintln(
            "^5[PinteMod]^7 RESTART VOTE: ^2" + vote.map_display
        );
    }
    else
    {
        player iprintln(
            "^5[PinteMod]^7 KICK VOTE: ^1" + vote.target_name
        );
        player iprintln("^7Reason: ^3" + vote.reason);
    }

    player iprintln(
        "^7YES: ^2" + vote.yes_xuids.size + "/" +
        vote.required_xuids.size + " ^7| NO: ^1" +
        vote.no_xuids.size + " ^7| Time: " + remaining + "s"
    );
}

function cmd_ezzvotestatus(args)
{
    if (args.size >= 1)
    {
        player = community_find_player(args[0]);

        if (isdefined(player))
            community_show_vote_status(player);

        return;
    }

    println("^5========== PINTEMOD VOTE STATUS ==========");

    if (!isdefined(level.pintemod_vote) ||
        !level.pintemod_vote.active)
    {
        println("^7No active vote");

        if (isdefined(level.pintemod_next_map_code) &&
            level.pintemod_next_map_code != "")
        {
            println(
                "^7Scheduled next map: " +
                level.pintemod_next_map_display + " (" +
                level.pintemod_next_map_code + ")"
            );
        }

        println("^7Last: " + level.pintemod_last_vote_summary);
    }
    else
    {
        println("^7Type: " + level.pintemod_vote.type);
        println("^7Initiator: " + level.pintemod_vote.initiator_name);
        println(
            "^7YES: " + level.pintemod_vote.yes_xuids.size +
            "/" + level.pintemod_vote.required_xuids.size
        );
    }

    println("^5===========================================");
}

function cmd_ezzcancelvote(args)
{
    if (!isdefined(level.pintemod_vote) ||
        !level.pintemod_vote.active)
    {
        println("^3[PinteMod]^7 No vote is active");
        return;
    }

    if (args.size <= 0)
    {
        community_finish_vote(false, "Cancelled by server console");
        return;
    }

    player = community_find_player(args[0]);

    if (!isdefined(player))
        return;

    if (community_get_role(player) < 3)
    {
        player iprintln("^1[PinteMod]^7 Admin role required.");
        return;
    }

    community_finish_vote(
        false,
        "Cancelled by administrator " + player.name
    );
}

function cmd_ezzclearnextmap(args)
{
    if (args.size <= 0)
    {
        if (!community_clear_scheduled_next_map("server console"))
            println("^3[PinteMod]^7 No next map is scheduled");

        return;
    }

    player = community_find_player(args[0]);

    if (!isdefined(player))
        return;

    if (community_get_role(player) < 3)
    {
        player iprintln("^1[PinteMod]^7 Admin role required.");
        return;
    }

    if (!community_clear_scheduled_next_map(player.name))
        player iprintln("^3[PinteMod]^7 No next map is scheduled.");
}

// ------------------------------------------------------------
// Public information commands
// ------------------------------------------------------------

function cmd_ezzpublicinfo(args)
{
    if (args.size < 1)
        return;

    player = community_find_player(args[0]);

    if (!isdefined(player))
        return;

    player iprintln(
        "^5[PinteMod]^7 Map: ^2" +
        community_get_map_display(community_get_map_name())
    );
    player iprintln("^5[PinteMod]^7 Round: ^2" + community_get_round());
    player iprintln("^5[PinteMod]^7 Players: ^2" + GetPlayers().size);

    if (isdefined(level.pintemod_next_map_code) &&
        level.pintemod_next_map_code != "")
    {
        player iprintln(
            "^5[PinteMod]^7 Next map: ^2" +
            level.pintemod_next_map_display
        );
    }
    else
    {
        player iprintln("^5[PinteMod]^7 Next map: ^3not scheduled");
    }

    if (player.pintemod_late_join_eligible &&
        !player.pintemod_late_join_consumed)
    {
        player iprintln("^5[PinteMod]^7 Join Game: ^2available");
    }
    else
    {
        player iprintln("^5[PinteMod]^7 Join Game: ^3unavailable");
    }
}

function cmd_ezzpublicplayers(args)
{
    if (args.size < 1)
        return;

    requester = community_find_player(args[0]);

    if (!isdefined(requester))
        return;

    players = GetPlayers();
    requester iprintln("^5=== PLAYERS ONLINE: " + players.size + " ===");

    for (i = 0; i < players.size; i++)
    {
        player = players[i];

        if (!isdefined(player))
            continue;

        requester iprintln(
            "^7" + player.name + " ^3[" +
            community_get_role_name(community_get_role(player)) +
            "]"
        );
    }
}

function cmd_ezzpublichelp(args)
{
    if (args.size < 1)
        return;

    player = community_find_player(args[0]);

    if (!isdefined(player))
        return;

    player iprintln("^5=== PinteMod PLAYER HELP ===");
    player iprintln("^2Use .menu for all Community actions.");
    player iprintln("^7Votes: next map, restart, kick, YES / NO, status.");
    player iprintln("^7Shortcuts: .spawn / .yes / .no / .votestatus");
    player iprintln("^7Optional: .votemap <map> / .voterestart");
    player iprintln("^7Optional: .votekick <player> [reason]");
    player iprintln(
        "^3Map aliases: shadows, giant, de, zns, gk, rev, " +
        "nacht, verruckt, shino, kino, ascension, shang, " +
        "moon, origins"
    );
}


function cmd_ezzpresencestatus(args)
{
    player = undefined;

    if (args.size >= 1)
    {
        player = community_find_player(args[0]);
    }
    else
    {
        players = GetPlayers();

        if (players.size > 0)
            player = players[0];
    }

    if (!isdefined(player))
    {
        println("^1[PinteMod Community]^7 No connected target.");
        return;
    }

    xuid = community_get_xuid(player);
    entry = community_presence_get(
        level.pintemod_presence_registry,
        xuid
    );

    entity_active = false;
    entity_consumed = false;
    entity_normal_death = false;
    entity_eligible = false;

    if (isdefined(player.pintemod_has_been_active))
        entity_active = player.pintemod_has_been_active;

    if (isdefined(player.pintemod_late_join_consumed))
        entity_consumed = player.pintemod_late_join_consumed;

    if (isdefined(player.pintemod_late_join_normal_death))
        entity_normal_death = player.pintemod_late_join_normal_death;

    if (isdefined(player.pintemod_late_join_eligible))
        entity_eligible = player.pintemod_late_join_eligible;

    println("^5===== PINTEMOD XUID PRESENCE STATUS =====");
    println("^7Player: " + player.name);
    println("^7BOIII_XUID: " + xuid);
    println(
        "^7Entity: active=" + entity_active +
        " | consumed=" + entity_consumed +
        " | normal_death=" + entity_normal_death +
        " | eligible=" + entity_eligible
    );

    if (isdefined(entry))
    {
        println(
            "^7Registry: active=" + entry.has_been_active +
            " | consumed=" + entry.late_join_consumed +
            " | normal_death=" + entry.normal_death +
            " | display=" + entry.display
        );
    }
    else
    {
        println("^1Registry: no stable presence entry");
    }

    println("^7Scope: current map (survives reconnect/name change)");
    println("^5==========================================");
}


function community_test_assert(result, condition, test_name, details)
{
    result.total++;

    if (condition)
    {
        result.passed++;
        println("^2[PASS]^7 " + result.total + " " + test_name);
        return;
    }

    result.failed++;
    println(
        "^1[FAIL]^7 " + result.total + " " + test_name +
        " | " + details
    );
}

function community_run_grouped_suite(player)
{
    println("^5===== PINTEMOD COMMUNITY GROUPED SUITE =====");
    println("");

    result = SpawnStruct();
    result.total = 0;
    result.passed = 0;
    result.failed = 0;

    community_test_assert(
        result,
        isdefined(player),
        "connected target resolved",
        "Use ezzcommunitytest suite <PlayerName|BOIII_XUID|ClientNumber>"
    );

    if (!isdefined(player))
    {
        println("^1[PinteMod Community]^7 Suite aborted: no target");
        return;
    }

    xuid = community_get_xuid(player);
    xuid_repeat = community_get_xuid(player);
    official_blocks_before = level.pintemod_kicked_xuids.size;
    official_presence_before = level.pintemod_presence_registry.size;
    official_initiator_cooldowns_before =
        level.pintemod_votekick_initiator_cooldowns.size;
    official_target_cooldowns_before =
        level.pintemod_votekick_target_cooldowns.size;

    community_test_assert(
        result,
        ezz_admin_identity::is_valid_xuid(xuid),
        "stable BOIII_XUID available",
        "xuid=" + xuid
    );
    community_test_assert(
        result,
        xuid == xuid_repeat,
        "identity reads deterministic",
        "first=" + xuid + " second=" + xuid_repeat
    );

    values = [];
    values = community_array_add_unique(values, xuid);
    values = community_array_add_unique(values, xuid);

    community_test_assert(
        result,
        values.size == 1 && community_array_contains(values, xuid),
        "XUID array deduplicates identities",
        "size=" + values.size
    );
    community_test_assert(
        result,
        !community_array_contains(values, player.name),
        "display name cannot impersonate voter identity",
        "display=" + player.name
    );

    removed = community_array_remove(values, xuid);
    community_test_assert(
        result,
        removed.size == 0,
        "XUID array removal deterministic",
        "size=" + removed.size
    );

    synthetic_vote = SpawnStruct();
    synthetic_vote.voters = [];
    synthetic_vote.initiator_xuid = "1111111111111111";
    synthetic_vote.initiator_name = "SameName";
    synthetic_vote.target_xuid = "2222222222222222";
    synthetic_vote.target_name = "SameName";

    community_vote_add_voter_entry(
        synthetic_vote,
        synthetic_vote.initiator_xuid,
        "SameName"
    );
    community_vote_add_voter_entry(
        synthetic_vote,
        synthetic_vote.target_xuid,
        "SameName"
    );

    community_test_assert(
        result,
        synthetic_vote.voters.size == 2,
        "identical display names keep distinct XUID entries",
        "entries=" + synthetic_vote.voters.size
    );
    community_test_assert(
        result,
        community_vote_get_voter_name(
            synthetic_vote,
            synthetic_vote.target_xuid
        ) == "SameName",
        "voter display lookup preserved",
        "lookup failed"
    );

    cooldowns = [];
    cooldowns = community_cooldown_set(
        cooldowns,
        synthetic_vote.initiator_xuid,
        "SameName",
        123456
    );
    community_test_assert(
        result,
        community_cooldown_get(
            cooldowns,
            synthetic_vote.initiator_xuid
        ) == 123456,
        "initiator cooldown keyed by XUID",
        "readback failed"
    );
    community_test_assert(
        result,
        community_cooldown_get(
            cooldowns,
            synthetic_vote.target_xuid
        ) == 0,
        "cooldown does not leak across XUIDs",
        "unexpected target cooldown"
    );

    test_blocks = [];
    test_blocks = community_array_add_unique(
        test_blocks,
        synthetic_vote.target_xuid
    );
    community_test_assert(
        result,
        community_array_contains(
            test_blocks,
            synthetic_vote.target_xuid
        ),
        "map rejoin block is XUID-compatible",
        "block missing"
    );
    community_test_assert(
        result,
        !community_array_contains(test_blocks, "SameName"),
        "map block rejects display-name spoofing",
        "display name matched XUID block"
    );

    vote_model = SpawnStruct();
    vote_model.required_xuids = [];
    vote_model.yes_xuids = [];
    vote_model.no_xuids = [];
    vote_model.required_xuids = community_array_add_unique(
        vote_model.required_xuids,
        synthetic_vote.initiator_xuid
    );
    vote_model.yes_xuids = community_array_add_unique(
        vote_model.yes_xuids,
        synthetic_vote.initiator_xuid
    );

    community_test_assert(
        result,
        vote_model.required_xuids.size == 1 &&
        vote_model.yes_xuids.size == 1,
        "vote electorate and ballot use XUID",
        "vote model invalid"
    );

    synthetic_presence = [];
    synthetic_presence = community_presence_upsert(
        synthetic_presence,
        synthetic_vote.initiator_xuid,
        "OldName",
        true,
        true,
        false
    );
    presence_entry = community_presence_get(
        synthetic_presence,
        synthetic_vote.initiator_xuid
    );

    community_test_assert(
        result,
        isdefined(presence_entry) &&
        presence_entry.has_been_active &&
        presence_entry.late_join_consumed &&
        !presence_entry.normal_death,
        "map presence state stored by XUID",
        "presence state invalid"
    );

    synthetic_presence = community_presence_upsert(
        synthetic_presence,
        synthetic_vote.initiator_xuid,
        "RenamedPlayer",
        true,
        true,
        true
    );
    presence_entry = community_presence_get(
        synthetic_presence,
        synthetic_vote.initiator_xuid
    );

    community_test_assert(
        result,
        synthetic_presence.size == 1 &&
        presence_entry.display == "RenamedPlayer" &&
        presence_entry.normal_death,
        "renaming cannot reset XUID presence state",
        "entry duplicated or state lost"
    );

    synthetic_presence = community_presence_upsert(
        synthetic_presence,
        synthetic_vote.target_xuid,
        "RenamedPlayer",
        false,
        false,
        false
    );

    community_test_assert(
        result,
        synthetic_presence.size == 2,
        "same display keeps distinct presence identities",
        "XUID entries collided"
    );

    community_test_assert(
        result,
        level.pintemod_presence_registry.size == official_presence_before,
        "official presence registry unchanged by suite",
        "unexpected mutation"
    );

    community_test_assert(
        result,
        level.pintemod_kicked_xuids.size == official_blocks_before,
        "official map blocks unchanged by suite",
        "unexpected mutation"
    );
    community_test_assert(
        result,
        isdefined(level.pintemod_votekick_initiator_cooldowns) &&
        isdefined(level.pintemod_votekick_target_cooldowns) &&
        isdefined(level.pintemod_presence_registry),
        "XUID cooldown and presence registries initialized",
        "registry missing"
    );
    community_test_assert(
        result,
        level.pintemod_votekick_initiator_cooldowns.size ==
            official_initiator_cooldowns_before &&
        level.pintemod_votekick_target_cooldowns.size ==
            official_target_cooldowns_before,
        "official cooldown registries unchanged by suite",
        "unexpected mutation"
    );

    community_test_assert(
        result,
        !community_late_join_should_confirm_active(
            true, 14, 14, 1000, 1000, 5000
        ),
        "transient mid-round active state stays provisional",
        "activity confirmed inside connection grace"
    );
    community_test_assert(
        result,
        community_late_join_should_confirm_active(
            true, 14, 14, 1000, 1000, 12000
        ),
        "stable mid-round active state can be confirmed",
        "stable activity was not confirmed"
    );
    community_test_assert(
        result,
        community_late_join_should_confirm_active(
            true, 14, 15, 1000, 11000, 11100
        ),
        "next-round natural spawn confirms activity",
        "round transition did not confirm activity"
    );
    community_test_assert(
        result,
        community_late_join_state_is_eligible(
            true, true, false, false, false, true, 14, 2
        ),
        "mid-round spectator state is late-join eligible",
        "eligible spectator model was rejected"
    );

    println("");
    println(
        "^5[PinteMod Community]^7 RESULT " + result.passed + "/" +
        result.total + " PASS | failed=" + result.failed
    );
    println("^5=====================================================");

    community_append_file(
        "pintemod/logs/community.log",
        "[" + GetTime() + "] GROUPED_SUITE | target=" +
        player.name + " | xuid=" + xuid + " | passed=" +
        result.passed + " | total=" + result.total +
        " | failed=" + result.failed + "\n"
    );
}

function cmd_ezzcommunitytest(args)
{
    if (args.size < 1 || toLower(args[0]) != "suite")
    {
        println(
            "^5[PinteMod]^7 Usage: " +
            "ezzcommunitytest suite [PlayerName|BOIII_XUID|ClientNumber]"
        );
        return;
    }

    player = undefined;

    if (args.size >= 2)
    {
        player = community_find_player(args[1]);
    }
    else
    {
        players = GetPlayers();

        if (players.size > 0)
            player = players[0];
    }

    community_run_grouped_suite(player);
}

function cmd_ezzcommunitystatus(args)
{
    community_apply_defaults();

    println("^5===== PINTEMOD COMMUNITY v2.1.1 =====");
    println("^7Welcome: " + level.pintemod_welcome_enabled);
    println("^7Public menu: " + level.pintemod_public_menu_enabled);
    println("^7Late join: " + level.pintemod_late_join_enabled);
    println(
        "^7Late-join state grace: " +
        level.pintemod_late_join_state_grace_ms + "ms"
    );
    println(
        "^7Late-join active confirmation: " +
        level.pintemod_late_join_active_confirm_ms + "ms"
    );
    println("^7Next-map vote: " + level.pintemod_next_map_vote_enabled);
    println("^7Restart vote: " + level.pintemod_restart_vote_enabled);
    println("^7Vote kick: " + level.pintemod_votekick_enabled);
    println("^7Vote logs: " + level.pintemod_vote_logs_enabled);
    println("^7Public tips: " + level.pintemod_public_tips_enabled);
    println(
        "^7Public tip delay: " +
        level.pintemod_public_tips_min_delay + "-" +
        level.pintemod_public_tips_max_delay + "s"
    );
    println("^7Vote duration: " + level.pintemod_vote_duration + "s");
    println("^7Global cooldown: " + level.pintemod_vote_cooldown + "s");
    println(
        "^7Map/restart minimum players: " +
        level.pintemod_map_vote_min_players
    );
    println("^7Map command: " + level.pintemod_map_command);
    println(
        "^7Automatic map rotation: " +
        level.pintemod_auto_map_rotation_enabled
    );
    println("^7Kick command: " + level.pintemod_kick_command);
    println("^7Role identity: BOIII_XUID (centralized)");
    println("^7Vote electorate: BOIII_XUID");
    println("^7Kick/rejoin blocks: BOIII_XUID until map reload");
    println(
        "^7Map blocks=" + level.pintemod_kicked_xuids.size +
        " | initiator cooldowns=" +
        level.pintemod_votekick_initiator_cooldowns.size +
        " | target cooldowns=" +
        level.pintemod_votekick_target_cooldowns.size +
        " | presence entries=" +
        level.pintemod_presence_registry.size
    );

    if (isdefined(level.pintemod_next_map_code) &&
        level.pintemod_next_map_code != "")
    {
        println(
            "^7Scheduled next map: " +
            level.pintemod_next_map_display + " (" +
            level.pintemod_next_map_code + ")"
        );
    }
    else
    {
        println("^7Scheduled next map: none");
    }

    println("^7Logs: boiii/scriptdata/" +
        ezz_admin_storage::get_active_log_root() + "/");
    println("^5=============================================");
}
