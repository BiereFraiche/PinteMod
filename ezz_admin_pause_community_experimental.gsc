// ============================================================
// PinteMod — Community Pause EXPERIMENTAL v0.3
// File: ezz_admin_pause_community_experimental.gsc
//
// Base: PinteMod v2.1.1 FINAL
//
// Real-server validated foundations reused here:
// - cooperative player freeze;
// - native temporary invulnerability + health fallback;
// - zombie ignore stacking;
// - ai_DisableSpawn preservation;
// - literal waitrealtime up to 180 seconds;
// - spectator spawn blocking for ezzspawn/ezzjoin.
//
// This file is intentionally standalone and reversible:
// NO stable PinteMod file is modified.
//
// Public chat:
//   .pause / !pause   -> 20s majority vote for a 3-minute pause
//   .resume / !resume -> 15s majority vote to resume early
// Existing .yes/.no vote commands are reused.
//
// Limits:
// - 1 pause proposal per BOIII_XUID per map/match;
// - maximum 2 successful pauses per map/match;
// - 60s pause-vote cooldown after a completed pause vote;
// - 30s resume-vote cooldown after a failed/completed resume vote.
//
// Safety:
// - pause refused while a player is downed;
// - temporary God Mode protects frozen players;
// - spectator respawn is blocked while paused;
// - admin/server emergency resume: ezzresume;
// - automatic resume after 180 real seconds;
// - standard Community votes are blocked while paused.
//
// IMPORTANT:
// This remains a SOFT pause. Generic map/EE script timers are not frozen.
// ============================================================

#using scripts\shared\util_shared;
#using scripts\shared\laststand_shared;
#using scripts\zm\_zm;
#using scripts\zm\_zm_utility;

#using custom_scripts\ezz_admin_chat;
#using custom_scripts\ezz_admin_commands;
#using custom_scripts\ezz_admin_community;
#using custom_scripts\ezz_admin_identity;
#using custom_scripts\ezz_admin_localization;
#using custom_scripts\ezz_admin_moderation;


// ------------------------------------------------------------
// Init / state
// ------------------------------------------------------------

autoexec function init()
{
    addcommand("ezzvotepause", ::cmd_ezzvotepause);
    addcommand("ezzvoteresume", ::cmd_ezzvoteresume);
    addcommand("ezzresume", ::cmd_ezzresume);
    addcommand("ezzpauseforce", ::cmd_ezzpauseforce);
    addcommand("ezzpausestatus", ::cmd_ezzpausestatus);

    level.pintemod_pause_module_loaded = true;
    level.pintemod_pause_module_version = "0.3-experimental";

    level.pintemod_pause_active = false;
    level.pintemod_pause_block_spectator_spawns = false;
    level.pintemod_pause_id = 0;
    level.pintemod_pause_started_at = 0;
    level.pintemod_pause_end_at = 0;
    level.pintemod_pause_old_ai_disable_spawn = 0;

    level.pintemod_pause_duration = 180;
    level.pintemod_pause_vote_duration = 20;
    level.pintemod_resume_vote_duration = 15;

    level.pintemod_pause_max_successes = 2;
    level.pintemod_pause_success_count = 0;

    level.pintemod_pause_vote_cooldown = 60;
    level.pintemod_pause_vote_cooldown_until = 0;

    level.pintemod_resume_vote_cooldown = 30;
    level.pintemod_resume_vote_cooldown_until = 0;

    // Occasional public reminder. First reminder after 5 minutes, then
    // every 12 minutes while the feature is available and idle.
    level.pintemod_pause_tip_first_delay = 300;
    level.pintemod_pause_tip_interval = 720;

    // One entry per stable XUID. Cleared naturally on map/restart.
    level.pintemod_pause_requester_xuids = [];

    mkdir("pintemod");
    mkdir("pintemod/logs");
    mkdir("pintemod/remote");

    level thread pause_game_ended_monitor();
    level thread pause_end_game_monitor();
    level thread pause_public_tip_monitor();

    println(
        "^5[PinteMod]^7 Community Pause EXPERIMENTAL v0.3 loaded"
    );
}


// ------------------------------------------------------------
// Occasional public reminder
// ------------------------------------------------------------

function pause_public_tip_monitor()
{
    wait 300;

    for (;;)
    {
        players = GetPlayers();
        vote_active = isdefined(level.pintemod_vote) &&
            level.pintemod_vote.active;

        if (players.size > 0 &&
            !level.pintemod_pause_active &&
            !vote_active &&
            level.pintemod_pause_success_count <
                level.pintemod_pause_max_successes)
        {
            ezz_admin_community::community_broadcast_chat(
                "Besoin d'une pause ? .pause ou !pause lance un vote (3 min max)."
            );
        }

        wait 720;
    }
}


// ------------------------------------------------------------
// Generic helpers
// ------------------------------------------------------------

function pause_broadcast(message)
{
    players = GetPlayers();

    for (i = 0; i < players.size; i++)
    {
        player = players[i];

        if (isdefined(player))
            player iprintln(message);
    }
}


function pause_log(event_name, details)
{
    line = "[" + GetTime() + "] " + event_name;

    if (isdefined(details) && details != "")
        line = line + " | " + details;

    appendfile("pintemod/logs/pause.log", line + "\n");

    if (isdefined(level.pintemod_server_console_verbose) &&
        level.pintemod_server_console_verbose)
    {
        println("^5[PinteMod][PAUSE]^7 " + line);
    }
}


function pause_player_is_active(player)
{
    if (!isdefined(player))
        return false;

    if (!isdefined(player.sessionstate))
        return false;

    return player.sessionstate == "playing";
}


function pause_count_active_players()
{
    players = GetPlayers();
    count = 0;

    for (i = 0; i < players.size; i++)
    {
        if (pause_player_is_active(players[i]))
            count++;
    }

    return count;
}


function pause_any_player_downed()
{
    players = GetPlayers();

    for (i = 0; i < players.size; i++)
    {
        player = players[i];

        if (!pause_player_is_active(player))
            continue;

        if (player laststand::player_is_in_laststand())
            return true;
    }

    return false;
}


function pause_get_xuid(player)
{
    if (!isdefined(player))
        return "";

    return ezz_admin_identity::get_player_xuid(player);
}


function pause_xuid_array_contains(values, xuid)
{
    if (!isdefined(values) ||
        !ezz_admin_identity::is_valid_xuid(xuid))
    {
        return false;
    }

    normalized = ezz_admin_identity::normalize_xuid(xuid);

    for (i = 0; i < values.size; i++)
    {
        if (values[i] == normalized)
            return true;
    }

    return false;
}


function pause_xuid_array_add_unique(values, xuid)
{
    if (!isdefined(values))
        values = [];

    if (!ezz_admin_identity::is_valid_xuid(xuid))
        return values;

    normalized = ezz_admin_identity::normalize_xuid(xuid);

    if (!pause_xuid_array_contains(values, normalized))
        values[values.size] = normalized;

    return values;
}


function pause_remaining_seconds(end_time)
{
    remaining = end_time - GetTime();

    if (remaining <= 0)
        return 0;

    return int((remaining + 999) / 1000);
}


function pause_majority_required(required_count)
{
    if (required_count <= 0)
        return 0;

    return int(required_count / 2) + 1;
}


function pause_vote_type_active()
{
    if (!isdefined(level.pintemod_vote) ||
        !level.pintemod_vote.active ||
        !isdefined(level.pintemod_vote.type))
    {
        return false;
    }

    return level.pintemod_vote.type == "pause" ||
        level.pintemod_vote.type == "resume";
}


// ------------------------------------------------------------
// Pause safety / player protection
// ------------------------------------------------------------

function pause_can_activate(requester, show_message)
{
    if (level.pintemod_pause_active)
    {
        if (show_message && isdefined(requester))
        {
            requester iprintln(
                "^3[PinteMod]^7 The game is already paused."
            );
        }

        return false;
    }

    if (pause_count_active_players() <= 0)
    {
        if (show_message && isdefined(requester))
        {
            requester iprintln(
                "^3[PinteMod]^7 No active player can be paused."
            );
        }

        return false;
    }

    if (pause_any_player_downed())
    {
        if (show_message && isdefined(requester))
        {
            requester iprintln(
                "^1[PinteMod]^7 Pause unavailable while a player is downed."
            );
        }

        return false;
    }

    return true;
}


function pause_apply_player(player)
{
    if (!pause_player_is_active(player))
        return;

    if (isdefined(player.pintemod_pause_applied) &&
        player.pintemod_pause_applied)
    {
        return;
    }

    player.pintemod_pause_saved_health = player.health;
    player.pintemod_pause_saved_maxhealth = player.maxhealth;

    // Preserve other ignore effects through BO3's native counter.
    player zm_utility::increment_ignoreme();

    // Validated cooperative freeze.
    player util::freeze_player_controls(true);

    // Validated temporary protection against environmental/map damage.
    player EnableInvulnerability();
    player.maxhealth = 99999;
    player.health = 99999;

    player.pintemod_pause_applied = true;
}


function pause_release_player(player)
{
    if (!isdefined(player))
        return;

    if (!isdefined(player.pintemod_pause_applied) ||
        !player.pintemod_pause_applied)
    {
        return;
    }

    player util::freeze_player_controls(false);
    player zm_utility::decrement_ignoreme();

    keep_admin_god = false;

    if (isdefined(player.admin_god) && player.admin_god)
        keep_admin_god = true;

    if (!keep_admin_god)
    {
        player DisableInvulnerability();

        if (isdefined(player.pintemod_pause_saved_maxhealth))
            player.maxhealth = player.pintemod_pause_saved_maxhealth;

        if (isdefined(player.pintemod_pause_saved_health))
            player.health = player.pintemod_pause_saved_health;

        if (player.health <= 0)
            player.health = player.maxhealth;
    }

    player.pintemod_pause_applied = false;
}


function pause_player_monitor(pause_id)
{
    while (level.pintemod_pause_active &&
           level.pintemod_pause_id == pause_id)
    {
        players = GetPlayers();

        for (i = 0; i < players.size; i++)
            pause_apply_player(players[i]);

        // Fail-safe: no survivor remains to protect.
        if (pause_count_active_players() <= 0)
        {
            pause_resume_internal("no active players remain");
            return;
        }

        wait 0.1;
    }
}


function pause_auto_resume_timer(pause_id)
{
    // 150 + 20 + 10 = 180 real seconds.
    waitrealtime 150;

    if (!level.pintemod_pause_active ||
        level.pintemod_pause_id != pause_id)
    {
        return;
    }

    pause_broadcast(
        "^3[PinteMod]^7 Pause ends automatically in ^130 seconds^7."
    );

    waitrealtime 20;

    if (!level.pintemod_pause_active ||
        level.pintemod_pause_id != pause_id)
    {
        return;
    }

    pause_broadcast(
        "^3[PinteMod]^7 Pause ends automatically in ^110 seconds^7."
    );

    waitrealtime 10;

    if (!level.pintemod_pause_active ||
        level.pintemod_pause_id != pause_id)
    {
        return;
    }

    pause_resume_internal("automatic 180-second timeout");
}


function pause_start_internal(source)
{
    if (!pause_can_activate(undefined, false))
        return false;

    level.pintemod_pause_id++;
    pause_id = level.pintemod_pause_id;

    level.pintemod_pause_old_ai_disable_spawn =
        GetDvarInt("ai_DisableSpawn");

    level.pintemod_pause_active = true;
    level.pintemod_pause_block_spectator_spawns = true;
    level.pintemod_pause_started_at = GetTime();
    level.pintemod_pause_end_at =
        GetTime() + (level.pintemod_pause_duration * 1000);

    SetDvar("ai_DisableSpawn", 1);

    players = GetPlayers();

    for (i = 0; i < players.size; i++)
        pause_apply_player(players[i]);

    pause_broadcast(
        "^5[PinteMod]^7 GAME PAUSED - maximum ^3180 seconds^7."
    );
    pause_broadcast(
        "^7Use ^2.resume ^7or ^2!resume ^7to vote for early resume."
    );

    ezz_admin_community::community_broadcast_chat(
        "GAME PAUSED for up to 3 minutes. Use .resume or !resume to vote for early resume."
    );

    pause_log(
        "PAUSE_START",
        "source=" + source +
        " | successful_before=" + level.pintemod_pause_success_count +
        "/" + level.pintemod_pause_max_successes +
        " | active_players=" + pause_count_active_players()
    );

    level thread pause_player_monitor(pause_id);
    level thread pause_auto_resume_timer(pause_id);

    return true;
}


function pause_cancel_resume_vote_if_active(reason)
{
    if (!pause_vote_type_active())
        return;

    if (level.pintemod_vote.type != "resume")
        return;

    pause_finish_vote(false, reason);
}


function pause_resume_internal(reason)
{
    if (!level.pintemod_pause_active)
        return false;

    // Prevent a stale resume vote surviving after automatic/admin resume.
    pause_cancel_resume_vote_if_active("Pause ended before resume vote result");

    level.pintemod_pause_active = false;
    level.pintemod_pause_block_spectator_spawns = false;
    level.pintemod_pause_end_at = 0;

    players = GetPlayers();

    for (i = 0; i < players.size; i++)
        pause_release_player(players[i]);

    SetDvar(
        "ai_DisableSpawn",
        level.pintemod_pause_old_ai_disable_spawn
    );

    pause_broadcast("^2[PinteMod]^7 GAME RESUMED.");
    ezz_admin_community::community_broadcast_chat("GAME RESUMED.");

    pause_log(
        "PAUSE_END",
        "reason=" + reason +
        " | active_players=" + pause_count_active_players()
    );

    return true;
}


function pause_game_ended_monitor()
{
    level waittill("game_ended");

    if (level.pintemod_pause_active)
        pause_resume_internal("game transition: game_ended");
}


function pause_end_game_monitor()
{
    level waittill("end_game");

    if (level.pintemod_pause_active)
        pause_resume_internal("game transition: end_game");
}


// ------------------------------------------------------------
// Community vote electorate / result
// ------------------------------------------------------------

function pause_vote_add_active_players()
{
    players = GetPlayers();

    for (i = 0; i < players.size; i++)
    {
        player = players[i];

        if (!pause_player_is_active(player))
            continue;

        xuid = pause_get_xuid(player);

        if (!ezz_admin_identity::is_valid_xuid(xuid))
            continue;

        level.pintemod_vote.required_xuids =
            ezz_admin_community::community_array_add_unique(
                level.pintemod_vote.required_xuids,
                xuid
            );

        ezz_admin_community::community_vote_add_voter_entry(
            level.pintemod_vote,
            xuid,
            player.name
        );
    }
}


function pause_vote_summary_text(vote, passed)
{
    threshold = pause_majority_required(vote.required_xuids.size);

    if (passed)
    {
        return "^2[PinteMod]^7 " + toUpper(vote.type) +
            " vote passed: ^2" + vote.yes_xuids.size +
            "/" + vote.required_xuids.size +
            " YES ^7(majority " + threshold + ")";
    }

    return "^1[PinteMod]^7 " + toUpper(vote.type) +
        " vote failed: ^2" + vote.yes_xuids.size +
        " YES^7, ^1" + vote.no_xuids.size +
        " NO ^7(majority " + threshold + ")";
}


function pause_finish_vote(passed, result_reason)
{
    if (!pause_vote_type_active())
        return;

    vote = level.pintemod_vote;
    vote_type = vote.type;

    // Revalidate the gameplay state at the exact moment a pause is applied.
    if (passed && vote_type == "pause" &&
        !pause_can_activate(undefined, false))
    {
        passed = false;
        result_reason = "Pause became unsafe before activation";
    }

    if (passed && vote_type == "resume" &&
        !level.pintemod_pause_active)
    {
        passed = false;
        result_reason = "Game is no longer paused";
    }

    ezz_admin_community::community_vote_add_event(
        "Result: " + result_reason + " | passed=" + passed
    );

    vote.active = false;

    result_text = "FAILED";

    if (passed)
        result_text = "PASSED";

    summary = result_text + " | type=" + vote_type +
        " | initiator=" + vote.initiator_name +
        " [" + vote.initiator_xuid + "]" +
        " | yes=" + vote.yes_xuids.size +
        "/" + vote.required_xuids.size +
        " | no=" + vote.no_xuids.size +
        " | reason=" + result_reason;

    level.pintemod_last_vote_summary = summary;

    appendfile(
        "pintemod/logs/vote_summary.log",
        "[" + GetTime() + "] " + summary + "\n"
    );

    pause_log(
        "VOTE_RESULT",
        summary
    );

    pause_broadcast(pause_vote_summary_text(vote, passed));

    if (!passed)
        pause_broadcast("^7Reason: " + result_reason);

    level.pintemod_vote = SpawnStruct();
    level.pintemod_vote.active = false;

    if (vote_type == "pause")
    {
        level.pintemod_pause_vote_cooldown_until =
            GetTime() + (level.pintemod_pause_vote_cooldown * 1000);

        if (passed)
        {
            if (pause_start_internal("community majority vote"))
            {
                level.pintemod_pause_success_count++;

                pause_log(
                    "PAUSE_COUNT",
                    "successful=" + level.pintemod_pause_success_count +
                    "/" + level.pintemod_pause_max_successes
                );
            }
        }

        return;
    }

    if (vote_type == "resume")
    {
        level.pintemod_resume_vote_cooldown_until =
            GetTime() + (level.pintemod_resume_vote_cooldown * 1000);

        if (passed)
            pause_resume_internal("community majority resume vote");
    }
}


function pause_check_vote_resolution()
{
    if (!pause_vote_type_active())
        return;

    required = level.pintemod_vote.required_xuids.size;
    yes_count = level.pintemod_vote.yes_xuids.size;
    no_count = level.pintemod_vote.no_xuids.size;
    threshold = pause_majority_required(required);

    if (required <= 0 || threshold <= 0)
    {
        pause_finish_vote(false, "No eligible active voters");
        return;
    }

    if (yes_count >= threshold)
    {
        pause_finish_vote(true, "Majority approval");
        return;
    }

    // Enough NO votes that reaching the majority is mathematically impossible.
    if (no_count > (required - threshold))
    {
        pause_finish_vote(false, "Majority can no longer be reached");
    }
}


function pause_vote_timer(vote_id)
{
    for (;;)
    {
        wait 1;

        if (!pause_vote_type_active() ||
            level.pintemod_vote.id != vote_id)
        {
            return;
        }

        remaining = pause_remaining_seconds(
            level.pintemod_vote.end_time
        );

        if (remaining <= 0)
        {
            pause_finish_vote(false, "Vote timed out");
            return;
        }

        if ((remaining == 10 || remaining == 5) &&
            level.pintemod_vote.last_notice != remaining)
        {
            level.pintemod_vote.last_notice = remaining;

            threshold = pause_majority_required(
                level.pintemod_vote.required_xuids.size
            );

            pause_broadcast(
                "^5[PinteMod]^7 " + toUpper(level.pintemod_vote.type) +
                " vote: ^2" + level.pintemod_vote.yes_xuids.size +
                " YES ^7| majority=" + threshold +
                " | " + remaining + "s"
            );
        }
    }
}


// ------------------------------------------------------------
// Pause / resume vote creation
// ------------------------------------------------------------

function pause_requester_is_valid(player)
{
    if (!isdefined(player))
        return false;

    if (!pause_player_is_active(player))
    {
        player iprintln(
            "^3[PinteMod]^7 Spectators cannot start a pause/resume vote."
        );
        return false;
    }

    xuid = pause_get_xuid(player);

    if (!ezz_admin_identity::is_valid_xuid(xuid))
    {
        player iprintln(
            "^1[PinteMod]^7 Stable identity unavailable; vote refused."
        );
        return false;
    }

    return true;
}


function pause_start_pause_vote(requester)
{
    if (!pause_requester_is_valid(requester))
        return;

    if (level.pintemod_pause_active)
    {
        requester iprintln(
            "^3[PinteMod]^7 Game already paused. Use .resume / !resume."
        );
        return;
    }

    if (level.pintemod_pause_success_count >=
        level.pintemod_pause_max_successes)
    {
        requester iprintln(
            "^3[PinteMod]^7 Match pause limit reached: " +
            level.pintemod_pause_max_successes
        );
        return;
    }

    if (!pause_can_activate(requester, true))
        return;

    requester_xuid = pause_get_xuid(requester);

    if (pause_xuid_array_contains(
        level.pintemod_pause_requester_xuids,
        requester_xuid
    ))
    {
        requester iprintln(
            "^3[PinteMod]^7 You already used your pause proposal this match."
        );
        return;
    }

    if (GetTime() < level.pintemod_pause_vote_cooldown_until)
    {
        remaining = pause_remaining_seconds(
            level.pintemod_pause_vote_cooldown_until
        );

        requester iprintln(
            "^3[PinteMod]^7 Pause vote cooldown: " + remaining + "s"
        );
        return;
    }

    if (isdefined(level.pintemod_vote) &&
        level.pintemod_vote.active)
    {
        requester iprintln(
            "^3[PinteMod]^7 Another Community vote is already active."
        );
        return;
    }

    // Proposal quota is consumed when the vote is actually started.
    level.pintemod_pause_requester_xuids =
        pause_xuid_array_add_unique(
            level.pintemod_pause_requester_xuids,
            requester_xuid
        );

    if (!ezz_admin_community::community_create_vote(
        "pause",
        requester
    ))
    {
        return;
    }

    level.pintemod_vote.end_time =
        GetTime() + (level.pintemod_pause_vote_duration * 1000);
    level.pintemod_vote.last_notice = -1;

    pause_vote_add_active_players();

    level.pintemod_vote.yes_xuids =
        ezz_admin_community::community_array_add_unique(
            level.pintemod_vote.yes_xuids,
            requester_xuid
        );

    ezz_admin_community::community_vote_add_event(
        requester.name + " [" + requester_xuid +
        "] automatically voted YES"
    );

    threshold = pause_majority_required(
        level.pintemod_vote.required_xuids.size
    );

    pause_broadcast(
        "^5[PinteMod]^7 " + requester.name +
        " started a ^3PAUSE vote^7: maximum 3 minutes."
    );
    pause_broadcast(
        "^7Vote with ^2.yes ^7/ ^1.no^7 | majority=" +
        threshold + "/" + level.pintemod_vote.required_xuids.size +
        " | " + level.pintemod_pause_vote_duration + "s"
    );

    ezz_admin_community::community_broadcast_chat(
        "PAUSE vote: use .yes/.no or !yes/!no. Majority required."
    );

    pause_log(
        "PAUSE_VOTE_START",
        "initiator=" + requester.name +
        " | xuid=" +
        ezz_admin_identity::identity_log_xuid_value(requester_xuid) +
        " | required=" + level.pintemod_vote.required_xuids.size +
        " | majority=" + threshold
    );

    vote_id = level.pintemod_vote.id;
    level thread pause_vote_timer(vote_id);
    pause_check_vote_resolution();
}


function pause_start_resume_vote(requester)
{
    if (!pause_requester_is_valid(requester))
        return;

    if (!level.pintemod_pause_active)
    {
        requester iprintln(
            "^3[PinteMod]^7 The game is not paused."
        );
        return;
    }

    if (GetTime() < level.pintemod_resume_vote_cooldown_until)
    {
        remaining = pause_remaining_seconds(
            level.pintemod_resume_vote_cooldown_until
        );

        requester iprintln(
            "^3[PinteMod]^7 Resume vote cooldown: " + remaining + "s"
        );
        return;
    }

    if (isdefined(level.pintemod_vote) &&
        level.pintemod_vote.active)
    {
        requester iprintln(
            "^3[PinteMod]^7 Another Community vote is already active."
        );
        return;
    }

    requester_xuid = pause_get_xuid(requester);

    if (!ezz_admin_community::community_create_vote(
        "resume",
        requester
    ))
    {
        return;
    }

    level.pintemod_vote.end_time =
        GetTime() + (level.pintemod_resume_vote_duration * 1000);
    level.pintemod_vote.last_notice = -1;

    pause_vote_add_active_players();

    level.pintemod_vote.yes_xuids =
        ezz_admin_community::community_array_add_unique(
            level.pintemod_vote.yes_xuids,
            requester_xuid
        );

    ezz_admin_community::community_vote_add_event(
        requester.name + " [" + requester_xuid +
        "] automatically voted YES"
    );

    threshold = pause_majority_required(
        level.pintemod_vote.required_xuids.size
    );

    pause_broadcast(
        "^5[PinteMod]^7 " + requester.name +
        " started an ^2EARLY RESUME vote^7."
    );
    pause_broadcast(
        "^7Vote with ^2.yes ^7/ ^1.no^7 | majority=" +
        threshold + "/" + level.pintemod_vote.required_xuids.size +
        " | " + level.pintemod_resume_vote_duration + "s"
    );

    pause_log(
        "RESUME_VOTE_START",
        "initiator=" + requester.name +
        " | xuid=" +
        ezz_admin_identity::identity_log_xuid_value(requester_xuid) +
        " | required=" + level.pintemod_vote.required_xuids.size +
        " | majority=" + threshold
    );

    vote_id = level.pintemod_vote.id;
    level thread pause_vote_timer(vote_id);
    pause_check_vote_resolution();
}


// ------------------------------------------------------------
// RCON / console commands
// ------------------------------------------------------------

function cmd_ezzvotepause(args)
{
    if (args.size < 1)
    {
        println(
            "^5[PinteMod]^7 Usage: ezzvotepause " +
            "<PlayerName|BOIII_XUID|ClientNumber>"
        );
        return;
    }

    requester =
        ezz_admin_identity::identity_find_player(args[0]);

    if (!isdefined(requester))
    {
        println("^1[PinteMod] Player not found: " + args[0]);
        return;
    }

    pause_start_pause_vote(requester);
}


function cmd_ezzvoteresume(args)
{
    if (args.size < 1)
    {
        println(
            "^5[PinteMod]^7 Usage: ezzvoteresume " +
            "<PlayerName|BOIII_XUID|ClientNumber>"
        );
        return;
    }

    requester =
        ezz_admin_identity::identity_find_player(args[0]);

    if (!isdefined(requester))
    {
        println("^1[PinteMod] Player not found: " + args[0]);
        return;
    }

    pause_start_resume_vote(requester);
}


function cmd_ezzresume(args)
{
    if (!level.pintemod_pause_active)
    {
        println("^3[PinteMod]^7 Game is not paused");
        return;
    }

    pause_resume_internal("server/admin emergency resume");
}


function cmd_ezzpauseforce(args)
{
    if (level.pintemod_pause_active)
    {
        println("^3[PinteMod]^7 Game is already paused");
        return;
    }

    if (isdefined(level.pintemod_vote) &&
        level.pintemod_vote.active)
    {
        println("^3[PinteMod]^7 Force pause refused: a Community vote is active");
        return;
    }

    if (!pause_can_activate(undefined, false))
    {
        println(
            "^1[PinteMod]^7 Force pause refused: no active player or a player is downed"
        );
        return;
    }

    pause_start_internal("server/admin force");
}


function pause_write_remote_status_feedback()
{
    remaining = 0;
    temp_god = "OFF";
    spawn_guard = "OFF";
    ai_spawn = "normal";
    vote_status = "none";

    if (level.pintemod_pause_active)
    {
        remaining = pause_remaining_seconds(
            level.pintemod_pause_end_at
        );
        temp_god = "ON";
        spawn_guard = "ON";
        ai_spawn = "blocked";
    }

    if (pause_vote_type_active())
    {
        threshold = pause_majority_required(
            level.pintemod_vote.required_xuids.size
        );

        vote_status =
            level.pintemod_vote.type +
            " | YES=" + level.pintemod_vote.yes_xuids.size +
            " | NO=" + level.pintemod_vote.no_xuids.size +
            " | majority=" + threshold;
    }

    feedback =
        "PINTEMOD_REMOTE_FEEDBACK_V1\n" +
        "command=ezzpausestatus\n" +
        "generated_gettime=" + GetTime() + "\n" +
        "---\n" +
        "PinteMod Community Pause - EXPERIMENTAL v0.3\n" +
        "Active: " + level.pintemod_pause_active + "\n" +
        "Automatic resume in: " + remaining + "s\n" +
        "Successful pauses: " +
            level.pintemod_pause_success_count + "/" +
            level.pintemod_pause_max_successes + "\n" +
        "Pause proposals used: " +
            level.pintemod_pause_requester_xuids.size + "\n" +
        "Pause vote: " +
            level.pintemod_pause_vote_duration +
            "s | majority\n" +
        "Resume vote: " +
            level.pintemod_resume_vote_duration +
            "s | majority\n" +
        "Public reminder: first=" +
            level.pintemod_pause_tip_first_delay +
            "s | every=" +
            level.pintemod_pause_tip_interval + "s\n" +
        "Active vote: " + vote_status + "\n" +
        "Temporary God Mode: " + temp_god + "\n" +
        "Spectator spawn guard: " + spawn_guard + "\n" +
        "New AI spawning: " + ai_spawn + "\n" +
        "Soft pause: map/EE script timers are NOT frozen\n" +
        "END\n";

    writefile(
        "pintemod/remote/feedback.latest.txt",
        feedback
    );
}


function cmd_ezzpausestatus(args)
{
    remaining = 0;

    if (level.pintemod_pause_active)
    {
        remaining = pause_remaining_seconds(
            level.pintemod_pause_end_at
        );
    }

    println("^5===== PINTEMOD COMMUNITY PAUSE =====");
    println("^7Module: EXPERIMENTAL v0.3");
    println("^7Active: " + level.pintemod_pause_active);
    println(
        "^7Successful pauses: " +
        level.pintemod_pause_success_count + "/" +
        level.pintemod_pause_max_successes
    );
    println(
        "^7Pause proposals used: " +
        level.pintemod_pause_requester_xuids.size
    );
    println(
        "^7Pause vote: " +
        level.pintemod_pause_vote_duration + "s | majority"
    );
    println(
        "^7Resume vote: " +
        level.pintemod_resume_vote_duration + "s | majority"
    );
    println(
        "^7Public reminder: first=" +
        level.pintemod_pause_tip_first_delay + "s | every=" +
        level.pintemod_pause_tip_interval + "s"
    );

    if (level.pintemod_pause_active)
    {
        println(
            "^7Automatic resume in: " + remaining + "s"
        );
        println("^7Temporary God Mode: ON");
        println("^7Spectator spawn guard: ON");
        println("^7New AI spawning: blocked");
    }
    else
    {
        println("^7Temporary God Mode: OFF");
        println("^7Spectator spawn guard: OFF");
    }

    if (pause_vote_type_active())
    {
        threshold = pause_majority_required(
            level.pintemod_vote.required_xuids.size
        );

        println(
            "^7Active vote: " + level.pintemod_vote.type +
            " | YES=" + level.pintemod_vote.yes_xuids.size +
            " | NO=" + level.pintemod_vote.no_xuids.size +
            " | majority=" + threshold
        );
    }

    println("^7Log: boiii/scriptdata/pintemod/logs/pause.log");
    println("^7Remote feedback: boiii/scriptdata/pintemod/remote/feedback.latest.txt");
    println("^3Soft pause: map/EE script timers are NOT frozen");
    println("^5====================================");

    pause_write_remote_status_feedback();

    pause_log(
        "STATUS",
        "active=" + level.pintemod_pause_active +
        " | remaining=" + remaining +
        " | successful=" +
        level.pintemod_pause_success_count + "/" +
        level.pintemod_pause_max_successes +
        " | proposals=" +
        level.pintemod_pause_requester_xuids.size
    );
}


// ------------------------------------------------------------
// Detour: existing .yes/.no vote casting
//
// Existing next-map/restart/kick behaviour is preserved.
// Pause/resume votes use majority instead of unanimity.
// ------------------------------------------------------------

detour custom_scripts\ezz_admin_community::community_cast_vote(
    player,
    vote_yes
)
{
    if (!isdefined(level.pintemod_vote) ||
        !level.pintemod_vote.active)
    {
        player iprintln("^3[PinteMod]^7 No vote is active.");
        return;
    }

    player_xuid =
        ezz_admin_community::community_get_xuid(player);

    if (!ezz_admin_identity::is_valid_xuid(player_xuid))
    {
        player iprintln(
            "^1[PinteMod]^7 Stable identity unavailable; vote refused."
        );
        return;
    }

    if (!ezz_admin_community::community_array_contains(
        level.pintemod_vote.required_xuids,
        player_xuid
    ))
    {
        player iprintln(
            "^3[PinteMod]^7 You are not an eligible voter for this vote."
        );
        return;
    }

    if (ezz_admin_community::community_array_contains(
        level.pintemod_vote.yes_xuids,
        player_xuid
    ) || ezz_admin_community::community_array_contains(
        level.pintemod_vote.no_xuids,
        player_xuid
    ))
    {
        player iprintln("^3[PinteMod]^7 You already voted.");
        return;
    }

    ezz_admin_community::community_vote_add_voter_entry(
        level.pintemod_vote,
        player_xuid,
        player.name
    );

    if (!vote_yes)
    {
        level.pintemod_vote.no_xuids =
            ezz_admin_community::community_array_add_unique(
                level.pintemod_vote.no_xuids,
                player_xuid
            );

        ezz_admin_community::community_vote_add_event(
            player.name + " [" + player_xuid + "] voted NO"
        );

        if (pause_vote_type_active())
        {
            threshold = pause_majority_required(
                level.pintemod_vote.required_xuids.size
            );

            pause_broadcast(
                "^1[PinteMod]^7 " + player.name +
                " voted NO. ^2" +
                level.pintemod_vote.yes_xuids.size +
                " YES^7 / ^1" +
                level.pintemod_vote.no_xuids.size +
                " NO ^7| majority=" + threshold
            );

            pause_check_vote_resolution();
            return;
        }

        // Original PinteMod behaviour: standard Community votes are unanimous.
        ezz_admin_community::community_broadcast(
            "^1[PinteMod]^7 " + player.name +
            " voted NO. Unanimity was not reached."
        );

        ezz_admin_community::community_finish_vote(
            false,
            player.name + " voted NO"
        );
        return;
    }

    level.pintemod_vote.yes_xuids =
        ezz_admin_community::community_array_add_unique(
            level.pintemod_vote.yes_xuids,
            player_xuid
        );

    ezz_admin_community::community_vote_add_event(
        player.name + " [" + player_xuid + "] voted YES"
    );

    if (pause_vote_type_active())
    {
        threshold = pause_majority_required(
            level.pintemod_vote.required_xuids.size
        );

        pause_broadcast(
            "^2[PinteMod]^7 " + player.name +
            " voted YES. ^2" +
            level.pintemod_vote.yes_xuids.size +
            "/" + level.pintemod_vote.required_xuids.size +
            " ^7| majority=" + threshold
        );

        pause_check_vote_resolution();
        return;
    }

    // Original PinteMod behaviour for all existing vote types.
    ezz_admin_community::community_broadcast(
        "^2[PinteMod]^7 " + player.name + " voted YES. ^2" +
        level.pintemod_vote.yes_xuids.size + "/" +
        level.pintemod_vote.required_xuids.size
    );

    ezz_admin_community::community_check_unanimity();
}


// ------------------------------------------------------------
// Detour: unanimity checker
//
// Disconnect handling in Community calls this helper. For pause/resume,
// recalculate majority after the electorate changes.
// ------------------------------------------------------------

detour custom_scripts\ezz_admin_community::community_check_unanimity()
{
    if (!isdefined(level.pintemod_vote) ||
        !level.pintemod_vote.active)
    {
        return;
    }

    if (pause_vote_type_active())
    {
        pause_check_vote_resolution();
        return;
    }

    required = level.pintemod_vote.required_xuids.size;
    yes_count = level.pintemod_vote.yes_xuids.size;

    if (required > 0 && yes_count >= required)
    {
        ezz_admin_community::community_finish_vote(
            true,
            "Unanimous approval"
        );
    }
}


// ------------------------------------------------------------
// Detour: standard Community vote availability
//
// While gameplay is paused, only the dedicated resume vote may start.
// ------------------------------------------------------------

detour custom_scripts\ezz_admin_community::community_vote_is_available(
    requester
)
{
    ezz_admin_community::community_apply_defaults();

    if (level.pintemod_pause_active)
    {
        requester iprintln(
            "^3[PinteMod]^7 Standard votes are unavailable while paused. " +
            "Use .resume / !resume."
        );
        return false;
    }

    if (isdefined(level.pintemod_vote) &&
        level.pintemod_vote.active)
    {
        requester iprintln(
            "^3[PinteMod]^7 A vote is already active."
        );
        return false;
    }

    if (GetTime() < level.pintemod_vote_cooldown_until)
    {
        remaining =
            ezz_admin_community::community_get_remaining_seconds(
                level.pintemod_vote_cooldown_until
            );

        requester iprintln(
            "^3[PinteMod]^7 Vote cooldown: " + remaining + "s"
        );
        return false;
    }

    return true;
}


// ------------------------------------------------------------
// Detour: player-facing vote status
// ------------------------------------------------------------

detour custom_scripts\ezz_admin_community::community_show_vote_status(
    player
)
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

        player iprintln(
            "^7Last result: " + level.pintemod_last_vote_summary
        );
        return;
    }

    vote = level.pintemod_vote;
    remaining =
        ezz_admin_community::community_get_remaining_seconds(
            vote.end_time
        );

    if (vote.type == "pause" || vote.type == "resume")
    {
        threshold = pause_majority_required(
            vote.required_xuids.size
        );

        player iprintln(
            "^5[PinteMod]^7 " + toUpper(vote.type) +
            " VOTE ^7| majority=" + threshold
        );

        player iprintln(
            "^7YES: ^2" + vote.yes_xuids.size +
            "^7 | NO: ^1" + vote.no_xuids.size +
            "^7 | voters: " + vote.required_xuids.size +
            " | Time: " + remaining + "s"
        );
        return;
    }

    // Original PinteMod display for existing vote types.
    if (vote.type == "nextmap")
    {
        player iprintln(
            "^5[PinteMod]^7 NEXT MAP VOTE: ^2" +
            vote.map_display
        );
    }
    else if (vote.type == "restart")
    {
        player iprintln(
            "^5[PinteMod]^7 RESTART VOTE: ^2" +
            vote.map_display
        );
    }
    else
    {
        player iprintln(
            "^5[PinteMod]^7 KICK VOTE: ^1" +
            vote.target_name
        );
        player iprintln("^7Reason: ^3" + vote.reason);
    }

    player iprintln(
        "^7YES: ^2" + vote.yes_xuids.size + "/" +
        vote.required_xuids.size + " ^7| NO: ^1" +
        vote.no_xuids.size + " ^7| Time: " + remaining + "s"
    );
}


// ------------------------------------------------------------
// Detour: public chat parser
//
// Adds only pause/resume before the normal role permission check.
// Every other PinteMod chat command follows the original v0.18.0 path.
// ------------------------------------------------------------

detour custom_scripts\ezz_admin_chat::chat_handle_message(
    player,
    message,
    source_event
)
{
    if (!isdefined(player) || !isdefined(message))
        return;

    if (message == "")
        return;

    prefix = GetSubStr(message, 0, 1);

    primary_prefix = prefix == level.ezz_chat_prefix;
    legacy_prefix =
        isdefined(level.ezz_chat_legacy_prefix) &&
        prefix == level.ezz_chat_legacy_prefix;
    is_command = primary_prefix || legacy_prefix;

    if (!is_command &&
        ezz_admin_moderation::should_block_chat(player, message))
    {
        return;
    }

    if (!ezz_admin_chat::chat_log_message(
        player,
        message,
        source_event,
        !is_command,
        !is_command
    ))
    {
        return;
    }

    if (!is_command)
        return;

    if (message.size <= 1)
        return;

    command_line = GetSubStr(message, 1, message.size);

    if (command_line == "")
        return;

    tokens = StrTok(command_line, " ");

    if (tokens.size <= 0)
        return;

    command_name =
        ezz_admin_chat::chat_normalize_command_name(
            toLower(tokens[0])
        );

    // Public Community Pause commands bypass staff-role metadata on purpose.
    if (command_name == "pause" || command_name == "resume")
    {
        player_xuid =
            ezz_admin_identity::get_player_xuid(player);
        logged_xuid =
            ezz_admin_identity::identity_log_xuid_value(player_xuid);

        ezz_admin_chat::chat_append_file(
            "pintemod/logs/chat/commands.log",
            "actor=" + player.name +
            " actor_xuid=" + logged_xuid +
            " source=" + source_event +
            " command=" + command_line + "\n"
        );

        if (isdefined(level.pintemod_server_console_verbose) &&
            level.pintemod_server_console_verbose)
        {
            println(
                "^2[PinteMod]^7 Accepted " + source_event +
                " command from " + player.name +
                " [" + player_xuid + "]: " + command_line
            );
        }

        if (command_name == "pause")
        {
            ezz_admin_chat::chat_route(
                player,
                "ezzvotepause " +
                    ezz_admin_chat::chat_target_selector(player),
                ".pause"
            );
            return;
        }

        ezz_admin_chat::chat_route(
            player,
            "ezzvoteresume " +
                ezz_admin_chat::chat_target_selector(player),
            ".resume"
        );
        return;
    }

    // Original v0.18.0 permission + audit path.
    if (!ezz_admin_chat::chat_has_permission(
        player,
        command_name
    ))
    {
        ezz_admin_chat::chat_deny(player, command_line);
        player iprintln(
            "^3[PinteMod]^7 Required role: " +
            ezz_admin_chat::chat_get_role_name(
                ezz_admin_chat::chat_get_required_role(command_name)
            )
        );
        return;
    }

    player_xuid =
        ezz_admin_identity::get_player_xuid(player);
    logged_xuid =
        ezz_admin_identity::identity_log_xuid_value(player_xuid);

    ezz_admin_chat::chat_append_file(
        "pintemod/logs/chat/commands.log",
        "actor=" + player.name +
        " actor_xuid=" + logged_xuid +
        " source=" + source_event +
        " command=" + command_line + "\n"
    );

    if (isdefined(level.pintemod_server_console_verbose) &&
        level.pintemod_server_console_verbose)
    {
        println(
            "^2[PinteMod]^7 Accepted " + source_event +
            " command from " + player.name +
            " [" + player_xuid + "]: " + command_line
        );
    }

    ezz_admin_chat::chat_dispatch(
        player,
        command_name,
        tokens
    );
}


// ------------------------------------------------------------
// Detour: .help / !help
// ------------------------------------------------------------

detour custom_scripts\ezz_admin_chat::chat_show_help(player)
{
    role = ezz_admin_chat::chat_get_player_role(player);

    player iprintln("^5=== PinteMod CHAT v0.18.0 ===");
    player iprintln("^2Use .menu for Community actions and votes.");
    player iprintln(
        "^7Pause: .pause / !pause | early resume: .resume / !resume"
    );
    player iprintln(
        "^7Language / Langue / Idioma: .lang fr|en|es|auto"
    );
    player iprintln(
        "^7Shortcuts: .spawn / .yes / .no / .votestatus"
    );
    player iprintln(
        "^7Optional: .votemap <map> / .voterestart"
    );
    player iprintln(
        "^7Optional: .votekick <player> [reason]"
    );
    player iprintln("^7Ranks: .rank / .ranks / .records [1-4]");
    player iprintln(
        "^7Easter Eggs: .eerecord / .eerecords [1-4]"
    );
    player iprintln(
        "^7Information: .players / .map / .round"
    );

    if (role <= 0)
    {
        player iprintln(
            "^3Public commands only. No gameplay advantage."
        );
        return;
    }

    player iprintln(
        "^7.adminhelp - complete staff command list"
    );
    player iprintln(
        "^6Your role: ^7" +
        ezz_admin_chat::chat_get_role_name(role)
    );
}


// ------------------------------------------------------------
// Detour: ezzspawn guard
// ------------------------------------------------------------

detour custom_scripts\ezz_admin_commands::cmd_ezzspawn(args)
{
    player =
        ezz_admin_commands::get_safe_spawn_target(args);

    if (!isdefined(player))
    {
        if (args.size > 0)
            ezz_admin_commands::print_player_not_found(args[0]);
        else if (GetPlayers().size <= 0)
            ezz_admin_commands::print_no_players();

        return;
    }

    if (level.pintemod_pause_active &&
        level.pintemod_pause_block_spectator_spawns)
    {
        player iprintln(
            "^3[PinteMod]^7 Respawn blocked while the game is paused."
        );
        println(
            "^3[PinteMod]^7 Spectator respawn blocked by pause | source=ezzspawn"
        );
        return;
    }

    if (!isdefined(player.sessionstate) ||
        player.sessionstate != "spectator")
    {
        println(
            "^3[PinteMod]^7 " + player.name +
            " is not a spectator"
        );
        player iprintln("^3You are already active");
        return;
    }

    if (!isdefined(player.spectator_respawn))
    {
        println(
            "^1[PinteMod] Native spectator respawn data unavailable for " +
            player.name
        );
        player iprintln("^1Respawn is not ready yet");
        return;
    }

    player zm::spectator_respawn_player();

    wait 0.1;

    if (isdefined(player.sessionstate) &&
        player.sessionstate != "spectator")
    {
        ezz_admin_commands::commands_mark_gameplay_command(
            "admin respawn",
            player.name
        );

        println(
            "^2[PinteMod] Spectator respawned: " + player.name
        );
        player iprintln("^2You have been spawned");

        ezz_admin_commands::commands_broadcast(
            "^2" + player.name + " rejoined the game"
        );
    }
    else
    {
        println(
            "^1[PinteMod] Native spectator respawn did not complete"
        );
        player iprintln(
            "^1Respawn failed; try again when a survivor is active"
        );
    }
}


// ------------------------------------------------------------
// Detour: public late-join guard
// ------------------------------------------------------------

detour custom_scripts\ezz_admin_community::cmd_ezzjoin(args)
{
    ezz_admin_community::community_apply_defaults();

    if (!level.pintemod_late_join_enabled)
    {
        println("^3[PinteMod]^7 Late-join spawn is disabled");
        return;
    }

    if (args.size < 1)
    {
        println(
            "^5[PinteMod]^7 Usage: ezzjoin " +
            "<PlayerName|BOIII_XUID|ClientNumber>"
        );
        return;
    }

    player =
        ezz_admin_community::community_find_player(args[0]);

    if (!isdefined(player))
    {
        println("^1[PinteMod] Player not found: " + args[0]);
        return;
    }

    if (level.pintemod_pause_active &&
        level.pintemod_pause_block_spectator_spawns)
    {
        player iprintln(
            "^3[PinteMod]^7 Respawn blocked while the game is paused."
        );

        ezz_admin_community::community_log_action(
            "LATE_JOIN_REJECTED",
            player.name,
            "reason=pause-active | round=" +
            ezz_admin_community::community_get_round()
        );

        return;
    }

    ezz_admin_community::community_log_action(
        "LATE_JOIN_ATTEMPT",
        player.name,
        "xuid=" +
        ezz_admin_community::community_get_xuid(player) +
        " | round=" +
        ezz_admin_community::community_get_round()
    );

    if (!isdefined(player.pintemod_presence_ready) ||
        !player.pintemod_presence_ready)
    {
        player iprintln(
            ezz_admin_localization::text(
                player,
                "latejoin_identity"
            )
        );

        ezz_admin_community::community_log_action(
            "LATE_JOIN_REJECTED",
            player.name,
            "reason=identity-unavailable"
        );
        return;
    }

    ezz_admin_community::community_refresh_late_join_eligibility(
        player,
        "command-refresh"
    );

    if (player.pintemod_late_join_normal_death)
    {
        player iprintln(
            ezz_admin_localization::text(
                player,
                "latejoin_normal_death"
            )
        );

        ezz_admin_community::community_log_action(
            "LATE_JOIN_REJECTED",
            player.name,
            ezz_admin_community::community_late_join_state_details(
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
            ezz_admin_localization::text(
                player,
                "latejoin_not_eligible"
            )
        );

        ezz_admin_community::community_log_action(
            "LATE_JOIN_REJECTED",
            player.name,
            ezz_admin_community::community_late_join_state_details(
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

        ezz_admin_community::community_presence_sync_from_player(
            player
        );

        player iprintln(
            ezz_admin_localization::text(
                player,
                "latejoin_already_active"
            )
        );

        ezz_admin_community::community_log_action(
            "LATE_JOIN_REJECTED",
            player.name,
            ezz_admin_community::community_late_join_state_details(
                player,
                "already-active"
            )
        );
        return;
    }

    if (!isdefined(player.spectator_respawn))
    {
        player iprintln(
            ezz_admin_localization::text(
                player,
                "latejoin_not_ready"
            )
        );

        ezz_admin_community::community_log_action(
            "LATE_JOIN_REJECTED",
            player.name,
            ezz_admin_community::community_late_join_state_details(
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

        ezz_admin_community::community_presence_sync_from_player(
            player
        );

        player iprintln(
            ezz_admin_localization::text(
                player,
                "latejoin_success"
            )
        );

        ezz_admin_community::community_broadcast(
            "^2[PinteMod]^7 " + player.name + " joined the game."
        );

        ezz_admin_community::community_log_action(
            "LATE_JOIN_SUCCESS",
            player.name,
            "map=" +
            ezz_admin_community::community_get_map_name() +
            " | round=" +
            ezz_admin_community::community_get_round()
        );
    }
    else
    {
        player.pintemod_join_in_progress = false;

        player iprintln(
            ezz_admin_localization::text(
                player,
                "latejoin_failed"
            )
        );

        ezz_admin_community::community_log_action(
            "LATE_JOIN_FAILED",
            player.name,
            ezz_admin_community::community_late_join_state_details(
                player,
                "respawn-verification"
            )
        );
    }
}
