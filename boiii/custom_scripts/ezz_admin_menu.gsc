// ============================================================
// PinteMod — Menu HUD v1.0.0
// Fichier : ezz_admin_menu.gsc
// Créé par BiereFraiche et ChatGPT
//
// Menu public pour les joueurs et menu complet pour les rôles autorisés.
// Navigation : 2 monter, 3 descendre, Use/Reload valider,
// Mêlée revenir ou fermer.
// ============================================================

#using scripts\shared\hud_util_shared;
#using custom_scripts\ezz_admin_identity;
#using custom_scripts\ezz_admin_storage;
#using custom_scripts\ezz_admin_registry;
#using custom_scripts\ezz_admin_localization;
#using custom_scripts\ezz_admin_moderation;
#using custom_scripts\ezz_admin_bans;


function pintemod_menu_append_file(path, text)
{
    if (ezz_admin_storage::append_managed_log(path, text))
        return true;

    println(
        "^1[PinteMod Menu]^7 WRITE_FAILED | path=" + path
    );

    return false;
}

autoexec function init()
{
    addcommand("ezzmenu", ::cmd_ezzmenu);
    addcommand("ezzmenuclose", ::cmd_ezzmenuclose);
    addcommand("ezzmenustatus", ::cmd_ezzmenustatus);

    level.pintemod_menu_version = "1.0.0";

    println("^5[PinteMod]^7 Menu v1.0.0 loaded");
}

// ------------------------------------------------------------
// Player and permission helpers
// ------------------------------------------------------------

function pintemod_menu_find_player_exact(player_name)
{
    return ezz_admin_identity::identity_find_player(player_name);
}

function pintemod_menu_get_role(player)
{
    return ezz_admin_identity::get_player_role(player);
}

function pintemod_menu_role_name(role)
{
    return toUpper(ezz_admin_identity::get_role_name(role));
}

function pintemod_menu_get_map_name()
{
    return toLower(GetDvarString("mapname"));
}

function pintemod_menu_get_map_display_name(map_name)
{
    return ezz_admin_registry::get_map_display_name(map_name);
}

function pintemod_menu_get_target(player)
{
    if (isdefined(player.pintemod_menu_target_selector))
    {
        target = pintemod_menu_find_player_exact(
            player.pintemod_menu_target_selector
        );

        if (isdefined(target))
            return target;
    }

    player.pintemod_menu_target_selector =
        ezz_admin_identity::get_player_selector(player);

    return player;
}

// ------------------------------------------------------------
// Menu item helpers
// ------------------------------------------------------------

function pintemod_menu_add_item(
    items,
    label,
    action,
    value,
    required_role
)
{
    item = SpawnStruct();

    item.label = label;
    item.action = action;
    item.value = value;
    item.required_role = required_role;

    items[items.size] = item;

    return items;
}

function pintemod_menu_add_command(
    items,
    label,
    command_line,
    required_role
)
{
    return pintemod_menu_add_item(
        items,
        label,
        "command",
        command_line,
        required_role
    );
}

function pintemod_menu_add_open(
    items,
    label,
    category,
    required_role
)
{
    return pintemod_menu_add_item(
        items,
        label,
        "open",
        category,
        required_role
    );
}

function pintemod_menu_add_back(items)
{
    return pintemod_menu_add_item(
        items,
        "< Back",
        "back",
        "",
        0
    );
}

function pintemod_menu_filter_items(player, items)
{
    role = pintemod_menu_get_role(player);
    filtered = [];

    for (i = 0; i < items.size; i++)
    {
        if (role >= items[i].required_role)
            filtered[filtered.size] = items[i];
    }

    return filtered;
}

// ------------------------------------------------------------
// Main menu
// ------------------------------------------------------------

function pintemod_menu_build_main(player)
{
    items = [];

    items = pintemod_menu_add_open(
        items,
        "Community / Joueurs",
        "community",
        1
    );

    items = pintemod_menu_add_open(
        items,
        "Joueurs / Cible",
        "players",
        1
    );

    items = pintemod_menu_add_open(
        items,
        ezz_admin_localization::text(player, "menu_moderation"),
        "moderation",
        3
    );

    items = pintemod_menu_add_open(
        items,
        "Administration",
        "administration",
        4
    );

    items = pintemod_menu_add_open(items, "Perks", "perks", 2);
    items = pintemod_menu_add_open(items, "Weapons", "weapons", 2);
    items = pintemod_menu_add_open(items, "Rounds", "rounds", 3);
    items = pintemod_menu_add_open(items, "Power-Ups", "powerups", 2);

    items = pintemod_menu_add_open(
        items,
        "Teleport / Spawn",
        "teleport",
        1
    );

    items = pintemod_menu_add_open(items, "Map", "maps", 3);
    items = pintemod_menu_add_open(items, "Events", "events", 3);
    items = pintemod_menu_add_open(
        items,
        "Musique speciale",
        "music",
        3
    );
    items = pintemod_menu_add_open(items, "Fun", "fun", 2);

    items = pintemod_menu_add_item(
        items,
        "Close PinteMod",
        "close",
        "",
        1
    );

    return pintemod_menu_filter_items(player, items);
}

// ------------------------------------------------------------
// Player target selector
// ------------------------------------------------------------

function pintemod_menu_build_players(player)
{
    items = [];
    players = GetPlayers();
    role = pintemod_menu_get_role(player);
    current_target = pintemod_menu_get_target(player);

    for (i = 0; i < players.size; i++)
    {
        target = players[i];

        if (!isdefined(target))
            continue;

        // Helpers can target themselves only.
        if (role < 2 && target != player)
            continue;

        prefix = "";

        if (target == current_target)
            prefix = "^2> ";

        items = pintemod_menu_add_item(
            items,
            prefix + target.name,
            "target",
            ezz_admin_identity::get_player_selector(target),
            1
        );
    }

    return pintemod_menu_add_back(items);
}

// ------------------------------------------------------------
// Moderation
// ------------------------------------------------------------

function pintemod_menu_build_moderation(player)
{
    items = [];
    actor_role = pintemod_menu_get_role(player);
    target_player = pintemod_menu_get_target(player);

    if (!isdefined(target_player))
    {
        items = pintemod_menu_add_item(items, ezz_admin_localization::text(player, "menu_moderation_no_target"), "none", "", 3);
        return pintemod_menu_add_back(items);
    }

    target_role = pintemod_menu_get_role(target_player);
    target_xuid = ezz_admin_identity::get_player_xuid(target_player);
    target = ezz_admin_identity::get_player_selector(target_player);
    allowed = target_player != player &&
        target_role < actor_role &&
        !ezz_admin_moderation::moderation_is_bootstrap_owner(target_xuid);

    if (!allowed)
    {
        items = pintemod_menu_add_item(
            items,
            ezz_admin_localization::text(player, "menu_moderation_protected"),
            "none",
            "",
            3
        );
        return pintemod_menu_add_back(items);
    }

    if (ezz_admin_moderation::is_player_muted(target_player))
    {
        items = pintemod_menu_add_item(items, ezz_admin_localization::text(player, "menu_unmute"), "moderation", "unmute|" + target, 3);
    }
    else
    {
        items = pintemod_menu_add_item(items, ezz_admin_localization::text(player, "menu_mute"), "moderation", "mute|" + target, 3);
    }

    items = pintemod_menu_add_item(items, ezz_admin_localization::text(player, "menu_kick"), "moderation", "kick|" + target, 3);
    items = pintemod_menu_add_item(items, ezz_admin_localization::text(player, "menu_temp_ban_30m"), "moderation", "ban30m|" + target, 3);
    items = pintemod_menu_add_item(items, ezz_admin_localization::text(player, "menu_temp_ban_2h"), "moderation", "ban2h|" + target, 3);
    items = pintemod_menu_add_item(items, ezz_admin_localization::text(player, "menu_perm_ban"), "moderation", "banperm|" + target, 3);
    items = pintemod_menu_add_item(items, ezz_admin_localization::text(player, "menu_ban_info"), "moderation", "baninfo|" + target, 3);
    items = pintemod_menu_add_item(items, ezz_admin_localization::text(player, "menu_player_history"), "moderation", "history|" + target, 3);

    return pintemod_menu_add_back(items);
}

// ------------------------------------------------------------
// Administration
// ------------------------------------------------------------

function pintemod_menu_build_administration(player)
{
    items = [];
    target = ezz_admin_identity::get_player_selector(
        pintemod_menu_get_target(player)
    );

    items = pintemod_menu_add_command(
        items,
        "Etat du routeur Chat",
        "ezzchatstatus",
        4
    );

    items = pintemod_menu_add_command(
        items,
        "Liste des joueurs",
        "ezzplayers",
        4
    );

    items = pintemod_menu_add_command(
        items,
        "Etat navigation cible",
        "ezznavstatus " + target,
        4
    );

    items = pintemod_menu_add_command(
        items,
        "Etat de la manche",
        "ezzroundinfo",
        4
    );

    items = pintemod_menu_add_command(
        items,
        "Profil de la map",
        "ezzmapstatus",
        4
    );

    items = pintemod_menu_add_command(
        items,
        "Etat du courant",
        "ezzpowerstatus",
        4
    );

    items = pintemod_menu_add_command(
        items,
        "Etat Pack-a-Punch",
        "ezzpapstatus",
        4
    );

    items = pintemod_menu_add_command(
        items,
        "Etat des passages",
        "ezzunlockstatus",
        4
    );

    items = pintemod_menu_add_command(
        items,
        "Etat du menu",
        "ezzmenustatus",
        4
    );

    return pintemod_menu_add_back(items);
}

// ------------------------------------------------------------
// Perks
// ------------------------------------------------------------

function pintemod_menu_build_perks(player)
{
    items = [];
    target = ezz_admin_identity::get_player_selector(
        pintemod_menu_get_target(player)
    );

    items = pintemod_menu_add_command(
        items,
        "Juggernog",
        "ezzperktoggle " + target + " jug",
        2
    );

    items = pintemod_menu_add_command(
        items,
        "Quick Revive",
        "ezzperktoggle " + target + " quick",
        2
    );

    items = pintemod_menu_add_command(
        items,
        "Speed Cola",
        "ezzperktoggle " + target + " speed",
        2
    );

    items = pintemod_menu_add_command(
        items,
        "Double Tap II",
        "ezzperktoggle " + target + " doubletap",
        2
    );

    items = pintemod_menu_add_command(
        items,
        "Stamin-Up",
        "ezzperktoggle " + target + " staminup",
        2
    );

    items = pintemod_menu_add_command(
        items,
        "Deadshot Daiquiri",
        "ezzperktoggle " + target + " deadshot",
        2
    );

    items = pintemod_menu_add_command(
        items,
        "Mule Kick",
        "ezzperktoggle " + target + " mule",
        2
    );

    items = pintemod_menu_add_command(
        items,
        "Electric Cherry",
        "ezzperktoggle " + target + " cherry",
        2
    );

    items = pintemod_menu_add_command(
        items,
        "Widow's Wine",
        "ezzperktoggle " + target + " widows",
        2
    );

    items = pintemod_menu_add_command(
        items,
        "Tous les perks",
        "ezzallperks " + target,
        2
    );

    items = pintemod_menu_add_command(
        items,
        "Retirer tous les perks",
        "ezzclearperks " + target,
        2
    );

    return pintemod_menu_add_back(items);
}

// ------------------------------------------------------------
// Weapons root
// ------------------------------------------------------------

function pintemod_menu_build_weapons(player)
{
    items = [];

    items = pintemod_menu_add_open(
        items,
        "Armes speciales de la map",
        "weapons_special",
        2
    );

    items = pintemod_menu_add_open(
        items,
        "Fusils d'assaut",
        "weapons_assault",
        2
    );

    items = pintemod_menu_add_open(
        items,
        "PM",
        "weapons_smg",
        2
    );

    items = pintemod_menu_add_open(
        items,
        "Fusils a pompe",
        "weapons_shotguns",
        2
    );

    items = pintemod_menu_add_open(
        items,
        "Mitrailleuses",
        "weapons_lmg",
        2
    );

    items = pintemod_menu_add_open(
        items,
        "Snipers",
        "weapons_snipers",
        2
    );

    items = pintemod_menu_add_command(
        items,
        "Pack-a-Punch arme tenue",
        "ezzpapweapon " + ezz_admin_identity::get_player_selector(
            pintemod_menu_get_target(player)
        ),
        2
    );

    return pintemod_menu_add_back(items);
}

function pintemod_menu_add_weapon(items, target, label, alias)
{
    return pintemod_menu_add_command(
        items,
        label,
        "ezzweapon " + target + " " + alias,
        2
    );
}

function pintemod_menu_build_weapons_special(player)
{
    items = [];
    target = ezz_admin_identity::get_player_selector(
        pintemod_menu_get_target(player)
    );
    map_name = pintemod_menu_get_map_name();

    items = pintemod_menu_add_weapon(
        items,
        target,
        "Ray Gun",
        "raygun"
    );

    items = pintemod_menu_add_weapon(
        items,
        target,
        "Ray Gun Mark II",
        "raygunmk2"
    );

    switch (map_name)
    {
        case "zm_zod":
            items = pintemod_menu_add_weapon(
                items,
                target,
                "Apothicon Servant",
                "apothicon"
            );
            items = pintemod_menu_add_weapon(
                items,
                target,
                "Li'l Arnies",
                "arnies"
            );
            items = pintemod_menu_add_weapon(
                items,
                target,
                "Annihilator",
                "annihilator"
            );
            break;

        case "zm_factory":
            items = pintemod_menu_add_weapon(
                items,
                target,
                "Wunderwaffe DG-2",
                "wunderwaffe"
            );
            items = pintemod_menu_add_weapon(
                items,
                target,
                "Annihilator",
                "annihilator"
            );
            break;

        case "zm_castle":
            items = pintemod_menu_add_weapon(
                items,
                target,
                "Wrath of the Ancients",
                "bow"
            );
            items = pintemod_menu_add_weapon(
                items,
                target,
                "Storm Bow",
                "stormbow"
            );
            items = pintemod_menu_add_weapon(
                items,
                target,
                "Fire Bow",
                "firebow"
            );
            items = pintemod_menu_add_weapon(
                items,
                target,
                "Wolf Bow",
                "wolfbow"
            );
            items = pintemod_menu_add_weapon(
                items,
                target,
                "Void Bow",
                "voidbow"
            );
            items = pintemod_menu_add_weapon(
                items,
                target,
                "Ragnarok DG-4",
                "ragnarok"
            );
            break;

        case "zm_island":
            items = pintemod_menu_add_weapon(
                items,
                target,
                "KT-4",
                "kt4"
            );
            items = pintemod_menu_add_weapon(
                items,
                target,
                "Masamune",
                "masamune"
            );
            items = pintemod_menu_add_weapon(
                items,
                target,
                "Skull of Nan Sapwe",
                "skull"
            );
            break;

        case "zm_stalingrad":
            items = pintemod_menu_add_weapon(
                items,
                target,
                "Ray Gun Mark III",
                "raygunmk3"
            );
            items = pintemod_menu_add_weapon(
                items,
                target,
                "Gauntlet of Siegfried",
                "gauntlet"
            );
            items = pintemod_menu_add_weapon(
                items,
                target,
                "Dragon Strike",
                "dragonstrike"
            );
            break;

        case "zm_genesis":
            items = pintemod_menu_add_weapon(
                items,
                target,
                "Apothicon Servant",
                "apothicon"
            );
            items = pintemod_menu_add_weapon(
                items,
                target,
                "Thundergun",
                "thundergun"
            );
            items = pintemod_menu_add_weapon(
                items,
                target,
                "Li'l Arnies",
                "arnies"
            );
            items = pintemod_menu_add_weapon(
                items,
                target,
                "Ragnarok DG-4",
                "ragnarok"
            );
            items = pintemod_menu_add_weapon(
                items,
                target,
                "Katana",
                "katana"
            );
            break;

        case "zm_prototype":
        case "zm_theater":
            items = pintemod_menu_add_weapon(
                items,
                target,
                "Thundergun",
                "thundergun"
            );
            break;

        case "zm_asylum":
        case "zm_sumpf":
            items = pintemod_menu_add_weapon(
                items,
                target,
                "Wunderwaffe DG-2",
                "wunderwaffe"
            );
            break;

        case "zm_cosmodrome":
            items = pintemod_menu_add_weapon(
                items,
                target,
                "Thundergun",
                "thundergun"
            );
            items = pintemod_menu_add_weapon(
                items,
                target,
                "Gersh Device",
                "gersh"
            );
            items = pintemod_menu_add_weapon(
                items,
                target,
                "Matryoshka Dolls",
                "dolls"
            );
            break;

        case "zm_temple":
            items = pintemod_menu_add_weapon(
                items,
                target,
                "31-79 JGb215",
                "babygun"
            );
            items = pintemod_menu_add_weapon(
                items,
                target,
                "Monkey Bomb",
                "monkey"
            );
            break;

        case "zm_moon":
            items = pintemod_menu_add_weapon(
                items,
                target,
                "Wave Gun",
                "wavegun"
            );
            items = pintemod_menu_add_weapon(
                items,
                target,
                "QED",
                "qed"
            );
            items = pintemod_menu_add_weapon(
                items,
                target,
                "Gersh Device",
                "gersh"
            );
            break;

        case "zm_tomb":
            items = pintemod_menu_add_weapon(
                items,
                target,
                "Wind Staff",
                "windstaff"
            );
            items = pintemod_menu_add_weapon(
                items,
                target,
                "Ice Staff",
                "icestaff"
            );
            items = pintemod_menu_add_weapon(
                items,
                target,
                "Lightning Staff",
                "lightningstaff"
            );
            items = pintemod_menu_add_weapon(
                items,
                target,
                "Fire Staff",
                "firestaff"
            );
            items = pintemod_menu_add_weapon(
                items,
                target,
                "G-Strike",
                "gstrike"
            );
            break;
    }

    return pintemod_menu_add_back(items);
}

function pintemod_menu_build_weapons_assault(player)
{
    items = [];
    target = ezz_admin_identity::get_player_selector(
        pintemod_menu_get_target(player)
    );

    items = pintemod_menu_add_weapon(items, target, "KN-44", "kn44");
    items = pintemod_menu_add_weapon(items, target, "HVK-30", "hvk");
    items = pintemod_menu_add_weapon(items, target, "ICR-1", "icr");
    items = pintemod_menu_add_weapon(items, target, "Man-O-War", "manowar");

    return pintemod_menu_add_back(items);
}

function pintemod_menu_build_weapons_smg(player)
{
    items = [];
    target = ezz_admin_identity::get_player_selector(
        pintemod_menu_get_target(player)
    );

    items = pintemod_menu_add_weapon(items, target, "Kuda", "kuda");
    items = pintemod_menu_add_weapon(items, target, "VMP", "vmp");

    return pintemod_menu_add_back(items);
}

function pintemod_menu_build_weapons_shotguns(player)
{
    items = [];
    target = ezz_admin_identity::get_player_selector(
        pintemod_menu_get_target(player)
    );

    items = pintemod_menu_add_weapon(items, target, "KRM-262", "krm");
    items = pintemod_menu_add_weapon(items, target, "205 Brecci", "brecci");
    items = pintemod_menu_add_weapon(items, target, "Haymaker 12", "haymaker");
    items = pintemod_menu_add_weapon(items, target, "Argus", "argus");

    return pintemod_menu_add_back(items);
}

function pintemod_menu_build_weapons_lmg(player)
{
    items = [];
    target = ezz_admin_identity::get_player_selector(
        pintemod_menu_get_target(player)
    );

    items = pintemod_menu_add_weapon(items, target, "BRM", "brm");
    items = pintemod_menu_add_weapon(items, target, "Dingo", "dingo");
    items = pintemod_menu_add_weapon(items, target, "Gorgon", "gorgon");
    items = pintemod_menu_add_weapon(items, target, "48 Dredge", "dredge");

    return pintemod_menu_add_back(items);
}

function pintemod_menu_build_weapons_snipers(player)
{
    items = [];
    target = ezz_admin_identity::get_player_selector(
        pintemod_menu_get_target(player)
    );

    items = pintemod_menu_add_weapon(items, target, "Drakon", "drakon");
    items = pintemod_menu_add_weapon(items, target, "Locus", "locus");
    items = pintemod_menu_add_weapon(items, target, "SVG-100", "svg");

    return pintemod_menu_add_back(items);
}

// ------------------------------------------------------------
// Rounds
// ------------------------------------------------------------

function pintemod_menu_build_rounds(player)
{
    items = [];

    items = pintemod_menu_add_command(
        items,
        "Manche suivante",
        "ezznextround",
        3
    );

    items = pintemod_menu_add_command(
        items,
        "Sauter 5 manches",
        "ezzskiprounds 5",
        3
    );

    items = pintemod_menu_add_command(
        items,
        "Sauter 10 manches",
        "ezzskiprounds 10",
        3
    );

    items = pintemod_menu_add_command(
        items,
        "Conserver le dernier zombie",
        "ezzlastzombie",
        3
    );

    items = pintemod_menu_add_command(
        items,
        "Eliminer tous les zombies",
        "ezzkillzombies",
        3
    );

    items = pintemod_menu_add_command(
        items,
        "Compter les zombies",
        "ezzombiecount",
        3
    );

    items = pintemod_menu_add_command(
        items,
        "Informations manche",
        "ezzroundinfo",
        3
    );

    return pintemod_menu_add_back(items);
}

// ------------------------------------------------------------
// Power-Ups
// ------------------------------------------------------------

function pintemod_menu_build_powerups(player)
{
    items = [];
    target = ezz_admin_identity::get_player_selector(
        pintemod_menu_get_target(player)
    );

    items = pintemod_menu_add_command(
        items,
        "Max Ammo",
        "ezzpowerup " + target + " maxammo",
        2
    );

    items = pintemod_menu_add_command(
        items,
        "Insta-Kill",
        "ezzpowerup " + target + " instakill",
        2
    );

    items = pintemod_menu_add_command(
        items,
        "Double Points",
        "ezzpowerup " + target + " doublepoints",
        2
    );

    items = pintemod_menu_add_command(
        items,
        "Fire Sale",
        "ezzpowerup " + target + " firesale",
        2
    );

    items = pintemod_menu_add_command(
        items,
        "Carpenter",
        "ezzpowerup " + target + " carpenter",
        2
    );

    items = pintemod_menu_add_command(
        items,
        "Nuke",
        "ezzpowerup " + target + " nuke",
        2
    );

    items = pintemod_menu_add_command(
        items,
        "Death Machine",
        "ezzpowerup " + target + " deathmachine",
        2
    );

    items = pintemod_menu_add_command(
        items,
        "Free Perk",
        "ezzpowerup " + target + " freeperk",
        2
    );

    items = pintemod_menu_add_command(
        items,
        "Shield Charge",
        "ezzpowerup " + target + " shield",
        2
    );

    items = pintemod_menu_add_command(
        items,
        "Drops PinteMod permanents ON",
        "ezzfreezepowerups on",
        3
    );

    items = pintemod_menu_add_command(
        items,
        "Drops PinteMod permanents OFF",
        "ezzfreezepowerups off",
        3
    );

    return pintemod_menu_add_back(items);
}

// ------------------------------------------------------------
// Teleport and spectator spawn
// ------------------------------------------------------------

function pintemod_menu_build_teleport(player)
{
    items = [];
    target = ezz_admin_identity::get_player_selector(
        pintemod_menu_get_target(player)
    );

    items = pintemod_menu_add_command(
        items,
        "Sauvegarder ma position",
        "ezzsave " + ezz_admin_identity::get_player_selector(player),
        1
    );

    items = pintemod_menu_add_command(
        items,
        "Charger ma position",
        "ezzload " + ezz_admin_identity::get_player_selector(player),
        1
    );

    items = pintemod_menu_add_command(
        items,
        "Me teleporter au viseur",
        "ezztp " + ezz_admin_identity::get_player_selector(player) + " " +
            ezz_admin_identity::get_player_selector(player),
        1
    );

    items = pintemod_menu_add_command(
        items,
        "Teleporter la cible au viseur",
        "ezztp " + ezz_admin_identity::get_player_selector(player) + " " + target,
        2
    );

    items = pintemod_menu_add_command(
        items,
        "Faire apparaitre la cible",
        "ezzspawn " + target,
        1
    );

    items = pintemod_menu_add_command(
        items,
        "Etat navigation cible",
        "ezznavstatus " + target,
        1
    );

    return pintemod_menu_add_back(items);
}

// ------------------------------------------------------------
// Map control
// ------------------------------------------------------------

function pintemod_menu_build_maps(player)
{
    items = [];

    items = pintemod_menu_add_command(
        items,
        "Activer le courant",
        "ezzpower",
        3
    );

    items = pintemod_menu_add_command(
        items,
        "Activer Pack-a-Punch",
        "ezzpap",
        3
    );

    items = pintemod_menu_add_command(
        items,
        "Ouvrir les passages standards",
        "ezzunlock",
        3
    );

    items = pintemod_menu_add_command(
        items,
        "Profil de la map",
        "ezzmapstatus",
        3
    );

    items = pintemod_menu_add_command(
        items,
        "Etat du courant",
        "ezzpowerstatus",
        3
    );

    items = pintemod_menu_add_command(
        items,
        "Etat Pack-a-Punch",
        "ezzpapstatus",
        3
    );

    items = pintemod_menu_add_command(
        items,
        "Etat des passages",
        "ezzunlockstatus",
        3
    );

    return pintemod_menu_add_back(items);
}

// ------------------------------------------------------------
// Events — boss spécial selon la map
// ------------------------------------------------------------

function pintemod_menu_build_events(player)
{
    items = [];
    map_name = toLower(GetDvarString("mapname"));
    target_player = pintemod_menu_get_target(player);
    target_selector = ezz_admin_identity::get_player_selector(target_player);

    switch (map_name)
    {
        case "zm_zod":
            items = pintemod_menu_add_command(
                items,
                "Invoquer un Margwa",
                "ezzspawnmargwa " + target_selector,
                3
            );
            break;

        case "zm_tomb":
            items = pintemod_menu_add_command(
                items,
                "Invoquer un Panzer",
                "ezzspawnpanzer " + target_selector,
                3
            );
            break;

        default:
            items = pintemod_menu_add_command(
                items,
                "Aucun boss pour cette map",
                "ezzeventstatus",
                3
            );
            break;
    }

    items = pintemod_menu_add_command(
        items,
        "Statut Events",
        "ezzeventstatus",
        3
    );

    return pintemod_menu_add_back(items);
}

// ------------------------------------------------------------
// Music Origins — global playback
// ------------------------------------------------------------

function pintemod_menu_build_music(player)
{
    items = [];
    map_name = toLower(GetDvarString("mapname"));

    switch (map_name)
    {
        case "zm_zod":
            items = pintemod_menu_add_command(
                items,
                "Snakeskin Boots - Tous",
                "ezzmusicplayall 1",
                3
            );
            items = pintemod_menu_add_command(
                items,
                "Cold Hard Cash - Tous",
                "ezzmusicplayall 2",
                3
            );
            break;

        case "zm_factory":
            items = pintemod_menu_add_command(
                items,
                "Musique speciale - Tous",
                "ezzmusicplayall 1",
                3
            );
            break;

        case "zm_castle":
            items = pintemod_menu_add_command(
                items,
                "Dead Again - Tous",
                "ezzmusicplayall 1",
                3
            );
            break;

        case "zm_island":
            items = pintemod_menu_add_command(
                items,
                "Dead Flowers - indisponible",
                "ezzmusicstatus",
                3
            );
            break;

        case "zm_stalingrad":
            items = pintemod_menu_add_command(
                items,
                "Ace of Spades - Tous",
                "ezzmusicplayall 1",
                3
            );
            items = pintemod_menu_add_command(
                items,
                "Dead Ended - Tous",
                "ezzmusicplayall 2",
                3
            );
            break;

        case "zm_genesis":
            items = pintemod_menu_add_command(
                items,
                "The Gift - Tous",
                "ezzmusicplayall 1",
                3
            );
            break;

        case "zm_prototype":
            items = pintemod_menu_add_command(
                items,
                "Aucune musique configuree",
                "ezzmusicstatus",
                3
            );
            break;

        case "zm_asylum":
            items = pintemod_menu_add_command(
                items,
                "Lullaby for a Dead Man - Tous",
                "ezzmusicplayall 1",
                3
            );
            break;

        case "zm_sumpf":
            items = pintemod_menu_add_command(
                items,
                "The One - Tous",
                "ezzmusicplayall 1",
                3
            );
            break;

        case "zm_theater":
            items = pintemod_menu_add_command(
                items,
                "115 - Tous",
                "ezzmusicplayall 1",
                3
            );
            break;

        case "zm_cosmodrome":
            items = pintemod_menu_add_command(
                items,
                "Abracadavre - Tous",
                "ezzmusicplayall 1",
                3
            );
            break;

        case "zm_temple":
            items = pintemod_menu_add_command(
                items,
                "Pareidolia - Tous",
                "ezzmusicplayall 1",
                3
            );
            break;

        case "zm_moon":
            items = pintemod_menu_add_command(
                items,
                "Coming Home - Tous",
                "ezzmusicplayall 1",
                3
            );
            items = pintemod_menu_add_command(
                items,
                "Nightmare - Tous",
                "ezzmusicplayall 2",
                3
            );
            break;

        case "zm_tomb":
            items = pintemod_menu_add_command(
                items,
                "Archangel - Tous",
                "ezzmusicplayall 1",
                3
            );
            break;

        default:
            items = pintemod_menu_add_command(
                items,
                "Map non configuree",
                "ezzmusicstatus",
                3
            );
            break;
    }

    items = pintemod_menu_add_command(
        items,
        "Arreter la musique - Tous",
        "ezzmusicstopall",
        3
    );

    items = pintemod_menu_add_command(
        items,
        "Statut musique",
        "ezzmusicstatus",
        3
    );

    return pintemod_menu_add_back(items);
}

// ------------------------------------------------------------
// Fun and player assistance
// ------------------------------------------------------------

function pintemod_menu_build_fun(player)
{
    items = [];
    target_player = pintemod_menu_get_target(player);
    target = ezz_admin_identity::get_player_selector(target_player);

    items = pintemod_menu_add_command(
        items,
        "God Mode cible",
        "godmode " + target,
        2
    );

    items = pintemod_menu_add_command(
        items,
        "Munitions cible",
        "ammo " + target,
        2
    );

    items = pintemod_menu_add_command(
        items,
        "Reanimer la cible",
        "ezzrevive " + target,
        4
    );

    items = pintemod_menu_add_command(
        items,
        "Points maximum cible",
        "maxpoints " + target,
        2
    );

    items = pintemod_menu_add_command(
        items,
        "Ignorer la cible",
        "ignore " + target,
        2
    );

    return pintemod_menu_add_back(items);
}


function pintemod_menu_build_community(player)
{
    items = [];
    player_name = ezz_admin_identity::get_player_selector(player);

    items = pintemod_menu_add_command(
        items,
        "Join Game",
        "ezzjoin " + player_name,
        0
    );

    items = pintemod_menu_add_open(
        items,
        "Votes",
        "community_votes",
        0
    );

    items = pintemod_menu_add_command(
        items,
        "Players Online",
        "ezzpublicplayers " + player_name,
        0
    );

    items = pintemod_menu_add_open(
        items,
        "Rankings & Records",
        "community_ranks",
        0
    );

    items = pintemod_menu_add_command(
        items,
        "Map Information",
        "ezzpublicinfo " + player_name,
        0
    );

    items = pintemod_menu_add_command(
        items,
        "Commands / Help",
        "ezzpublichelp " + player_name,
        0
    );

    items = pintemod_menu_add_open(
        items,
        "Language / Idioma",
        "language",
        0
    );

    items = pintemod_menu_add_item(
        items,
        "< Admin Menu",
        "back",
        "",
        1
    );

    items = pintemod_menu_add_item(
        items,
        "Close",
        "close",
        "",
        0
    );

    return pintemod_menu_filter_items(player, items);
}


function pintemod_menu_build_language(player)
{
    items = [];

    items = pintemod_menu_add_item(
        items,
        "Automatic (country)",
        "language",
        "auto",
        0
    );
    items = pintemod_menu_add_item(
        items,
        "French",
        "language",
        "fr",
        0
    );
    items = pintemod_menu_add_item(
        items,
        "English",
        "language",
        "en",
        0
    );
    items = pintemod_menu_add_item(
        items,
        "Spanish",
        "language",
        "es",
        0
    );

    return pintemod_menu_add_back(items);
}

function pintemod_menu_build_community_ranks(player)
{
    items = [];
    player_name = ezz_admin_identity::get_player_selector(player);

    items = pintemod_menu_add_command(
        items,
        "My Rank",
        "ezzrank " + player_name,
        0
    );

    items = pintemod_menu_add_command(
        items,
        "Server Rankings",
        "ezzranks " + player_name,
        0
    );

    items = pintemod_menu_add_open(
        items,
        "Round Records",
        "community_records",
        0
    );

    items = pintemod_menu_add_open(
        items,
        "Easter Egg Records",
        "community_ee_records",
        0
    );

    return pintemod_menu_add_back(items);
}

function pintemod_menu_build_community_records(player)
{
    items = [];
    player_name = ezz_admin_identity::get_player_selector(player);

    for (team_size = 1; team_size <= 4; team_size++)
    {
        label = "" + team_size + " Player";

        if (team_size > 1)
            label = label + "s";

        items = pintemod_menu_add_command(
            items,
            label,
            "ezzrecords " + player_name + " " + team_size,
            0
        );
    }

    return pintemod_menu_add_back(items);
}

function pintemod_menu_build_community_ee_records(player)
{
    items = [];
    player_name = ezz_admin_identity::get_player_selector(player);

    items = pintemod_menu_add_command(
        items,
        "Current EE Run",
        "ezzeerecord " + player_name,
        0
    );

    for (team_size = 1; team_size <= 4; team_size++)
    {
        label = "" + team_size + " Player";

        if (team_size > 1)
            label = label + "s";

        items = pintemod_menu_add_command(
            items,
            label,
            "ezzeerecords " + player_name + " " + team_size,
            0
        );
    }

    return pintemod_menu_add_back(items);
}

function pintemod_menu_build_community_votes(player)
{
    items = [];
    player_name = ezz_admin_identity::get_player_selector(player);

    items = pintemod_menu_add_command(
        items,
        "Vote YES",
        "ezzyes " + player_name,
        0
    );

    items = pintemod_menu_add_command(
        items,
        "Vote NO",
        "ezzno " + player_name,
        0
    );

    items = pintemod_menu_add_command(
        items,
        "Current Vote / Next Map",
        "ezzvotestatus " + player_name,
        0
    );

    items = pintemod_menu_add_open(
        items,
        "Choose Next Map",
        "community_mapvote",
        0
    );

    items = pintemod_menu_add_command(
        items,
        "Restart Current Map",
        "ezzvoterestart " + player_name,
        0
    );

    items = pintemod_menu_add_open(
        items,
        "Vote Kick",
        "community_votekick",
        0
    );

    items = pintemod_menu_add_command(
        items,
        "Cancel Active Vote",
        "ezzcancelvote " + player_name,
        3
    );

    items = pintemod_menu_add_command(
        items,
        "Clear Scheduled Map",
        "ezzclearnextmap " + player_name,
        3
    );

    return pintemod_menu_add_back(
        pintemod_menu_filter_items(player, items)
    );
}

function pintemod_menu_add_map_vote(
    items,
    label,
    player_name,
    map_alias
)
{
    return pintemod_menu_add_command(
        items,
        label,
        "ezzvotemap " + player_name + " " + map_alias,
        0
    );
}

function pintemod_menu_build_community_mapvote(player)
{
    items = [];
    player_name = ezz_admin_identity::get_player_selector(player);

    items = pintemod_menu_add_map_vote(
        items, "Shadows of Evil", player_name, "shadows"
    );
    items = pintemod_menu_add_map_vote(
        items, "The Giant", player_name, "giant"
    );
    items = pintemod_menu_add_map_vote(
        items, "Der Eisendrache", player_name, "de"
    );
    items = pintemod_menu_add_map_vote(
        items, "Zetsubou No Shima", player_name, "zns"
    );
    items = pintemod_menu_add_map_vote(
        items, "Gorod Krovi", player_name, "gk"
    );
    items = pintemod_menu_add_map_vote(
        items, "Revelations", player_name, "rev"
    );
    items = pintemod_menu_add_map_vote(
        items, "Nacht der Untoten", player_name, "nacht"
    );
    items = pintemod_menu_add_map_vote(
        items, "Verruckt", player_name, "verruckt"
    );
    items = pintemod_menu_add_map_vote(
        items, "Shi No Numa", player_name, "shino"
    );
    items = pintemod_menu_add_map_vote(
        items, "Kino der Toten", player_name, "kino"
    );
    items = pintemod_menu_add_map_vote(
        items, "Ascension", player_name, "ascension"
    );
    items = pintemod_menu_add_map_vote(
        items, "Shangri-La", player_name, "shang"
    );
    items = pintemod_menu_add_map_vote(
        items, "Moon", player_name, "moon"
    );
    items = pintemod_menu_add_map_vote(
        items, "Origins", player_name, "origins"
    );

    return pintemod_menu_add_back(items);
}

function pintemod_menu_build_community_votekick(player)
{
    items = [];
    players = GetPlayers();

    items = pintemod_menu_add_command(
        items,
        "Vote YES",
        "ezzyes " + ezz_admin_identity::get_player_selector(player),
        0
    );

    items = pintemod_menu_add_command(
        items,
        "Vote NO",
        "ezzno " + ezz_admin_identity::get_player_selector(player),
        0
    );

    items = pintemod_menu_add_command(
        items,
        "Vote Status",
        "ezzvotestatus " + ezz_admin_identity::get_player_selector(player),
        0
    );

    target_count = 0;

    for (i = 0; i < players.size; i++)
    {
        target = players[i];

        if (!isdefined(target) || target == player)
            continue;

        items = pintemod_menu_add_command(
            items,
            "Start: " + target.name,
            "ezzvotekick " + ezz_admin_identity::get_player_selector(player) + " " +
                ezz_admin_identity::get_player_selector(target),
            0
        );

        target_count++;
    }

    if (target_count <= 0)
    {
        items = pintemod_menu_add_item(
            items,
            "No target available",
            "none",
            "",
            0
        );
    }

    return pintemod_menu_add_back(items);
}

// ------------------------------------------------------------
// Category dispatcher and parent hierarchy
// ------------------------------------------------------------

function pintemod_menu_get_parent_category(category)
{
    switch (category)
    {
        case "weapons_special":
        case "weapons_assault":
        case "weapons_smg":
        case "weapons_shotguns":
        case "weapons_lmg":
        case "weapons_snipers":
            return "weapons";

        case "community_mapvote":
        case "community_votekick":
            return "community_votes";

        case "community_records":
        case "community_ee_records":
            return "community_ranks";

        case "community_votes":
        case "community_ranks":
            return "community";

        case "community":
            return "main";

        case "language":
            return "community";
    }

    return "main";
}

function pintemod_menu_build_category(player, category)
{
    switch (category)
    {
        case "main":
            return pintemod_menu_build_main(player);

        case "community":
            return pintemod_menu_build_community(player);

        case "language":
            return pintemod_menu_build_language(player);

        case "community_votes":
            return pintemod_menu_build_community_votes(player);

        case "community_ranks":
            return pintemod_menu_build_community_ranks(player);

        case "community_records":
            return pintemod_menu_build_community_records(player);

        case "community_ee_records":
            return pintemod_menu_build_community_ee_records(player);

        case "community_mapvote":
            return pintemod_menu_build_community_mapvote(player);

        case "community_votekick":
            return pintemod_menu_build_community_votekick(player);

        case "players":
            return pintemod_menu_build_players(player);

        case "moderation":
            return pintemod_menu_build_moderation(player);

        case "administration":
            return pintemod_menu_build_administration(player);

        case "perks":
            return pintemod_menu_build_perks(player);

        case "weapons":
            return pintemod_menu_build_weapons(player);

        case "weapons_special":
            return pintemod_menu_build_weapons_special(player);

        case "weapons_assault":
            return pintemod_menu_build_weapons_assault(player);

        case "weapons_smg":
            return pintemod_menu_build_weapons_smg(player);

        case "weapons_shotguns":
            return pintemod_menu_build_weapons_shotguns(player);

        case "weapons_lmg":
            return pintemod_menu_build_weapons_lmg(player);

        case "weapons_snipers":
            return pintemod_menu_build_weapons_snipers(player);

        case "rounds":
            return pintemod_menu_build_rounds(player);

        case "powerups":
            return pintemod_menu_build_powerups(player);

        case "teleport":
            return pintemod_menu_build_teleport(player);

        case "maps":
            return pintemod_menu_build_maps(player);

        case "events":
            return pintemod_menu_build_events(player);

        case "music":
            return pintemod_menu_build_music(player);

        case "fun":
            return pintemod_menu_build_fun(player);
    }

    if (pintemod_menu_get_role(player) <= 0)
        return pintemod_menu_build_community(player);

    return pintemod_menu_build_main(player);
}

function pintemod_menu_category_title(category)
{
    switch (category)
    {
        case "main":
            return "PINTE MOD";

        case "community":
            return "PLAYER / COMMUNITY";

        case "community_votes":
            return "COMMUNITY VOTES";

        case "community_ranks":
            return "RANKINGS & RECORDS";

        case "community_records":
            return "ROUND RECORDS";

        case "community_ee_records":
            return "EASTER EGG RECORDS";

        case "community_mapvote":
            return "CHOOSE NEXT MAP";

        case "community_votekick":
            return "VOTE KICK";

        case "players":
            return "JOUEURS / CIBLE";

        case "moderation":
            return "MODERATION";

        case "administration":
            return "ADMINISTRATION";

        case "perks":
            return "PERKS";

        case "weapons":
            return "WEAPONS";

        case "weapons_special":
            return "ARMES SPECIALES";

        case "weapons_assault":
            return "FUSILS D'ASSAUT";

        case "weapons_smg":
            return "PISTOLETS-MITRAILLEURS";

        case "weapons_shotguns":
            return "FUSILS A POMPE";

        case "weapons_lmg":
            return "MITRAILLEUSES";

        case "weapons_snipers":
            return "SNIPERS";

        case "rounds":
            return "ROUNDS";

        case "powerups":
            return "POWER-UPS";

        case "teleport":
            return "TELEPORT / SPAWN";

        case "maps":
            return "MAP";

        case "events":
            return "EVENTS";

        case "music":
            return "MUSIQUE SPECIALE";

        case "fun":
            return "FUN";
    }

    return "PINTE MOD";
}

// ------------------------------------------------------------
// HUD creation
// ------------------------------------------------------------

function pintemod_menu_create_hud(player)
{
    player.pintemod_menu_elements = [];
    player.pintemod_menu_lines = [];

    shadow = NewClientHudElem(player);
    shadow.horzAlign = "left";
    shadow.vertAlign = "top";
    shadow.alignX = "left";
    shadow.alignY = "top";
    shadow.x = 363;
    shadow.y = 63;
    shadow.sort = 998;
    shadow.alpha = 0.35;
    shadow.color = (0, 0, 0);
    shadow SetShader("white", 255, 330);

    player.pintemod_menu_elements[
        player.pintemod_menu_elements.size
    ] = shadow;

    background = NewClientHudElem(player);
    background.horzAlign = "left";
    background.vertAlign = "top";
    background.alignX = "left";
    background.alignY = "top";
    background.x = 357;
    background.y = 57;
    background.sort = 1000;
    background.alpha = 0.95;
    background.color = (0.018, 0.022, 0.029);
    background SetShader("white", 255, 330);

    player.pintemod_menu_elements[
        player.pintemod_menu_elements.size
    ] = background;

    border_top = NewClientHudElem(player);
    border_top.horzAlign = "left";
    border_top.vertAlign = "top";
    border_top.alignX = "left";
    border_top.alignY = "top";
    border_top.x = 357;
    border_top.y = 57;
    border_top.sort = 1001;
    border_top.alpha = 1;
    border_top.color = (0.93, 0.49, 0.12);
    border_top SetShader("white", 255, 3);

    player.pintemod_menu_elements[
        player.pintemod_menu_elements.size
    ] = border_top;

    border_left = NewClientHudElem(player);
    border_left.horzAlign = "left";
    border_left.vertAlign = "top";
    border_left.alignX = "left";
    border_left.alignY = "top";
    border_left.x = 357;
    border_left.y = 57;
    border_left.sort = 1001;
    border_left.alpha = 1;
    border_left.color = (0.93, 0.49, 0.12);
    border_left SetShader("white", 3, 330);

    player.pintemod_menu_elements[
        player.pintemod_menu_elements.size
    ] = border_left;

    border_right = NewClientHudElem(player);
    border_right.horzAlign = "left";
    border_right.vertAlign = "top";
    border_right.alignX = "left";
    border_right.alignY = "top";
    border_right.x = 609;
    border_right.y = 57;
    border_right.sort = 1001;
    border_right.alpha = 0.78;
    border_right.color = (0.93, 0.49, 0.12);
    border_right SetShader("white", 3, 330);

    player.pintemod_menu_elements[
        player.pintemod_menu_elements.size
    ] = border_right;

    border_bottom = NewClientHudElem(player);
    border_bottom.horzAlign = "left";
    border_bottom.vertAlign = "top";
    border_bottom.alignX = "left";
    border_bottom.alignY = "top";
    border_bottom.x = 357;
    border_bottom.y = 384;
    border_bottom.sort = 1001;
    border_bottom.alpha = 0.78;
    border_bottom.color = (0.93, 0.49, 0.12);
    border_bottom SetShader("white", 255, 3);

    player.pintemod_menu_elements[
        player.pintemod_menu_elements.size
    ] = border_bottom;

    header_tint = NewClientHudElem(player);
    header_tint.horzAlign = "left";
    header_tint.vertAlign = "top";
    header_tint.alignX = "left";
    header_tint.alignY = "top";
    header_tint.x = 360;
    header_tint.y = 60;
    header_tint.sort = 1001;
    header_tint.alpha = 0.23;
    header_tint.color = (0.30, 0.12, 0.025);
    header_tint SetShader("white", 249, 84);

    player.pintemod_menu_elements[
        player.pintemod_menu_elements.size
    ] = header_tint;

    footer_tint = NewClientHudElem(player);
    footer_tint.horzAlign = "left";
    footer_tint.vertAlign = "top";
    footer_tint.alignX = "left";
    footer_tint.alignY = "top";
    footer_tint.x = 360;
    footer_tint.y = 324;
    footer_tint.sort = 1001;
    footer_tint.alpha = 0.34;
    footer_tint.color = (0.055, 0.060, 0.072);
    footer_tint SetShader("white", 249, 58);

    player.pintemod_menu_elements[
        player.pintemod_menu_elements.size
    ] = footer_tint;

    // The diagnostic established that 1.0 is the smallest reliable
    // scale on this BOIII installation.
    title = player hud::createFontString("default", 1.0);
    title.horzAlign = "left";
    title.vertAlign = "top";
    title.alignX = "left";
    title.alignY = "top";
    title.x = 373;
    title.y = 70;
    title.sort = 1004;
    title.alpha = 1;
    title.color = (1, 0.76, 0.36);
    title SetText("PINTE MOD");

    player.pintemod_menu_title = title;
    player.pintemod_menu_elements[
        player.pintemod_menu_elements.size
    ] = title;

    role_label = player hud::createFontString("default", 1.0);
    role_label.horzAlign = "left";
    role_label.vertAlign = "top";
    role_label.alignX = "left";
    role_label.alignY = "top";
    role_label.x = 373;
    role_label.y = 100;
    role_label.sort = 1004;
    role_label.alpha = 0.9;
    role_label.color = (0.70, 0.42, 0.95);
    role_label SetText(ezz_admin_localization::text(player, "menu_role"));

    player.pintemod_menu_role_label = role_label;
    player.pintemod_menu_elements[
        player.pintemod_menu_elements.size
    ] = role_label;

    role_value = player hud::createFontString("default", 1.0);
    role_value.horzAlign = "left";
    role_value.vertAlign = "top";
    role_value.alignX = "left";
    role_value.alignY = "top";
    role_value.x = 425;
    role_value.y = 100;
    role_value.sort = 1004;
    role_value.alpha = 1;
    role_value.color = (0.86, 0.89, 0.95);
    role_value SetText("");

    player.pintemod_menu_role_value = role_value;
    player.pintemod_menu_elements[
        player.pintemod_menu_elements.size
    ] = role_value;

    target_label = player hud::createFontString("default", 1.0);
    target_label.horzAlign = "left";
    target_label.vertAlign = "top";
    target_label.alignX = "left";
    target_label.alignY = "top";
    target_label.x = 373;
    target_label.y = 120;
    target_label.sort = 1004;
    target_label.alpha = 0.9;
    target_label.color = (0.70, 0.42, 0.95);
    target_label SetText(ezz_admin_localization::text(player, "menu_target"));

    player.pintemod_menu_target_label = target_label;
    player.pintemod_menu_elements[
        player.pintemod_menu_elements.size
    ] = target_label;

    target_value = player hud::createFontString("default", 1.0);
    target_value.horzAlign = "left";
    target_value.vertAlign = "top";
    target_value.alignX = "left";
    target_value.alignY = "top";
    target_value.x = 425;
    target_value.y = 120;
    target_value.sort = 1004;
    target_value.alpha = 1;
    target_value.color = (0.60, 0.86, 0.10);
    target_value SetText("");

    player.pintemod_menu_target_value = target_value;
    player.pintemod_menu_elements[
        player.pintemod_menu_elements.size
    ] = target_value;

    separator = NewClientHudElem(player);
    separator.horzAlign = "left";
    separator.vertAlign = "top";
    separator.alignX = "left";
    separator.alignY = "top";
    separator.x = 371;
    separator.y = 145;
    separator.sort = 1002;
    separator.alpha = 0.55;
    separator.color = (0.32, 0.34, 0.39);
    separator SetShader("white", 225, 1);

    player.pintemod_menu_elements[
        player.pintemod_menu_elements.size
    ] = separator;

    selector = NewClientHudElem(player);
    selector.horzAlign = "left";
    selector.vertAlign = "top";
    selector.alignX = "left";
    selector.alignY = "top";
    selector.x = 369;
    selector.y = 154;
    selector.sort = 1002;
    selector.alpha = 0.88;
    selector.color = (0.48, 0.22, 0.04);
    selector SetShader("white", 229, 22);

    player.pintemod_menu_selector = selector;
    player.pintemod_menu_elements[
        player.pintemod_menu_elements.size
    ] = selector;

    selector_accent = NewClientHudElem(player);
    selector_accent.horzAlign = "left";
    selector_accent.vertAlign = "top";
    selector_accent.alignX = "left";
    selector_accent.alignY = "top";
    selector_accent.x = 369;
    selector_accent.y = 154;
    selector_accent.sort = 1003;
    selector_accent.alpha = 1;
    selector_accent.color = (1, 0.55, 0.13);
    selector_accent SetShader("white", 3, 22);

    player.pintemod_menu_selector_accent = selector_accent;
    player.pintemod_menu_elements[
        player.pintemod_menu_elements.size
    ] = selector_accent;

    for (i = 0; i < 6; i++)
    {
        line = player hud::createFontString("default", 1.0);
        line.horzAlign = "left";
        line.vertAlign = "top";
        line.alignX = "left";
        line.alignY = "top";
        line.x = 380;
        line.y = 157 + (i * 27);
        line.sort = 1004;
        line.alpha = 1;
        line.color = (0.78, 0.82, 0.88);
        line SetText("");

        player.pintemod_menu_lines[i] = line;
        player.pintemod_menu_elements[
            player.pintemod_menu_elements.size
        ] = line;
    }

    footer_separator = NewClientHudElem(player);
    footer_separator.horzAlign = "left";
    footer_separator.vertAlign = "top";
    footer_separator.alignX = "left";
    footer_separator.alignY = "top";
    footer_separator.x = 371;
    footer_separator.y = 323;
    footer_separator.sort = 1003;
    footer_separator.alpha = 0.55;
    footer_separator.color = (0.32, 0.34, 0.39);
    footer_separator SetShader("white", 225, 1);

    player.pintemod_menu_elements[
        player.pintemod_menu_elements.size
    ] = footer_separator;

    footer = player hud::createFontString("default", 1.0);
    footer.horzAlign = "left";
    footer.vertAlign = "top";
    footer.alignX = "left";
    footer.alignY = "top";
    footer.x = 373;
    footer.y = 335;
    footer.sort = 1004;
    footer.alpha = 0.9;
    footer.color = (0.72, 0.76, 0.82);
    footer SetText(
        "^32 ^7" + ezz_admin_localization::text(player, "menu_up") +
        "  ^33 ^7" + ezz_admin_localization::text(player, "menu_down") +
        "  ^3Use ^7" + ezz_admin_localization::text(player, "menu_select")
    );

    player.pintemod_menu_footer = footer;
    player.pintemod_menu_elements[
        player.pintemod_menu_elements.size
    ] = footer;

    footer_back = player hud::createFontString("default", 1.0);
    footer_back.horzAlign = "left";
    footer_back.vertAlign = "top";
    footer_back.alignX = "left";
    footer_back.alignY = "top";
    footer_back.x = 373;
    footer_back.y = 356;
    footer_back.sort = 1004;
    footer_back.alpha = 0.9;
    footer_back.color = (0.72, 0.76, 0.82);
    footer_back SetText(
        "^3Melee ^7" + ezz_admin_localization::text(player, "menu_back")
    );

    player.pintemod_menu_footer_back = footer_back;
    player.pintemod_menu_elements[
        player.pintemod_menu_elements.size
    ] = footer_back;
}

function pintemod_menu_destroy(player)
{
    if (isdefined(player.pintemod_menu_elements))
    {
        for (i = 0; i < player.pintemod_menu_elements.size; i++)
        {
            element = player.pintemod_menu_elements[i];

            if (isdefined(element))
                element Destroy();
        }
    }

    player.pintemod_menu_elements = undefined;
    player.pintemod_menu_lines = undefined;
    player.pintemod_menu_title = undefined;
    player.pintemod_menu_role_value = undefined;
    player.pintemod_menu_target_value = undefined;
    player.pintemod_menu_selector = undefined;
    player.pintemod_menu_selector_accent = undefined;
    player.pintemod_menu_items = undefined;
    player.pintemod_menu_category = undefined;
    player.pintemod_menu_open = false;
    player.pintemod_menu_selected = 0;

    player EnableOffhandWeapons();
    player SetBlur(0, 0.15);
}

// ------------------------------------------------------------
// Rendering
// ------------------------------------------------------------

function pintemod_menu_render(player)
{
    items = player.pintemod_menu_items;

    if (!isdefined(items) || items.size <= 0)
        return;

    selected = player.pintemod_menu_selected;

    if (selected < 0)
        selected = items.size - 1;

    if (selected >= items.size)
        selected = 0;

    player.pintemod_menu_selected = selected;

    first_visible = 0;

    if (selected >= 6)
        first_visible = selected - 5;

    target = pintemod_menu_get_target(player);
    role_name = pintemod_menu_role_name(
        pintemod_menu_get_role(player)
    );
    map_display = pintemod_menu_get_map_display_name(
        pintemod_menu_get_map_name()
    );

    player.pintemod_menu_title SetText(
        ezz_admin_localization::menu_category_title(
            player,
            player.pintemod_menu_category
        )
    );

    if (isdefined(player.pintemod_menu_role_label))
    {
        player.pintemod_menu_role_label SetText(
            ezz_admin_localization::text(player, "menu_role")
        );
    }

    if (isdefined(player.pintemod_menu_target_label))
    {
        player.pintemod_menu_target_label SetText(
            ezz_admin_localization::text(player, "menu_target")
        );
    }

    if (isdefined(player.pintemod_menu_footer))
    {
        player.pintemod_menu_footer SetText(
            "^32 ^7" + ezz_admin_localization::text(player, "menu_up") +
            "  ^33 ^7" + ezz_admin_localization::text(player, "menu_down") +
            "  ^3Use ^7" + ezz_admin_localization::text(player, "menu_select")
        );
    }

    if (isdefined(player.pintemod_menu_footer_back))
    {
        player.pintemod_menu_footer_back SetText(
            "^3Melee ^7" + ezz_admin_localization::text(player, "menu_back")
        );
    }

    player.pintemod_menu_role_value SetText(role_name);

    player.pintemod_menu_target_value SetText(target.name);

    visible_selected = selected - first_visible;

    player.pintemod_menu_selector.y =
        154 + (visible_selected * 27);

    player.pintemod_menu_selector_accent.y =
        154 + (visible_selected * 27);

    for (i = 0; i < 6; i++)
    {
        item_index = first_visible + i;
        line = player.pintemod_menu_lines[i];

        if (item_index >= items.size)
        {
            line SetText("");
            continue;
        }

        item = items[item_index];

        if (item_index == selected)
        {
            line.color = (1, 1, 1);
            line SetText(
                "^7> " +
                ezz_admin_localization::translate_menu_label(
                    player,
                    item.label
                )
            );
        }
        else
        {
            line.color = (0.70, 0.75, 0.82);
            line SetText(
                "^7  " +
                ezz_admin_localization::translate_menu_label(
                    player,
                    item.label
                )
            );
        }
    }
}

function pintemod_menu_open_category(player, category)
{
    player.pintemod_menu_category = category;
    player.pintemod_menu_selected = 0;
    player.pintemod_menu_items = pintemod_menu_build_category(
        player,
        category
    );

    pintemod_menu_render(player);
}

// ------------------------------------------------------------
// Menu action logging
// ------------------------------------------------------------

function pintemod_menu_log_selection(player, item)
{
    if (!isdefined(player) || !isdefined(item))
        return;

    category = pintemod_menu_category_title(
        player.pintemod_menu_category
    );
    role_name = pintemod_menu_role_name(
        pintemod_menu_get_role(player)
    );
    target = pintemod_menu_get_target(player);
    target_name = player.name;

    if (isdefined(target))
        target_name = target.name;

    details =
        player.name +
        " | role=" + role_name +
        " | menu=" + category +
        " | selected=" + item.label +
        " | action=" + item.action +
        " | target=" + target_name;

    println("^5[PinteMod][MENU]^7 " + details);

    pintemod_menu_append_file(
        "pintemod/logs/menu.log",
        "[" + GetTime() + "][MENU] " + details + "\n"
    );
}

// ------------------------------------------------------------
// Item execution
// ------------------------------------------------------------

function pintemod_menu_execute_selected(player)
{
    items = player.pintemod_menu_items;

    if (!isdefined(items) || items.size <= 0)
        return;

    item = items[player.pintemod_menu_selected];

    required_role = 0;

    if (isdefined(item.required_role))
        required_role = item.required_role;

    current_role = pintemod_menu_get_role(player);

    if (current_role < required_role)
    {
        println(
            "^1[PinteMod][MENU]^7 Permission denied at execution | " +
            player.name + " | required=" + required_role +
            " | current=" + current_role +
            " | action=" + item.action
        );

        pintemod_menu_append_file(
            "pintemod/logs/menu.log",
            "[" + GetTime() + "][MENU] PERMISSION_DENIED | " +
            player.name + " | required=" + required_role +
            " | current=" + current_role +
            " | action=" + item.action + "\n"
        );

        player iprintln(
            "^1[PinteMod]^7 Your permissions changed. Menu refreshed."
        );

        pintemod_menu_open_category(
            player,
            player.pintemod_menu_category
        );
        return;
    }

    pintemod_menu_log_selection(player, item);

    switch (item.action)
    {
        case "open":
            pintemod_menu_open_category(player, item.value);
            return;

        case "back":
            parent = pintemod_menu_get_parent_category(
                player.pintemod_menu_category
            );

            pintemod_menu_open_category(player, parent);
            return;

        case "close":
            player notify("pintemod_menu_close");
            return;

        case "target":
            target = pintemod_menu_find_player_exact(item.value);

            if (!isdefined(target))
            {
                player iprintln("^1[PinteMod]^7 Target is no longer connected.");
                player.pintemod_menu_target_selector =
                    ezz_admin_identity::get_player_selector(player);
            }
            else
            {
                player.pintemod_menu_target_selector = item.value;
                player iprintln(
                    "^2[PinteMod]^7 Cible selectionnee : " + target.name
                );
            }

            pintemod_menu_open_category(player, "main");
            return;

        case "language":
            ezz_admin_localization::set_player_language_choice(
                player,
                item.value
            );
            pintemod_menu_open_category(player, "language");
            return;

        case "moderation":
            parts = StrTok(item.value, "|");

            if (parts.size < 2)
            {
                player iprintln("^1[PinteMod]^7 Invalid moderation menu action.");
                return;
            }

            moderation_action = parts[0];
            moderation_target = parts[1];

            switch (moderation_action)
            {
                case "mute":
                    ezz_admin_moderation::request_mute(player, moderation_target, "menu");
                    break;
                case "unmute":
                    ezz_admin_moderation::request_unmute(player, moderation_target);
                    break;
                case "kick":
                    ezz_admin_moderation::request_kick(player, moderation_target, "menu");
                    break;
                case "ban30m":
                    ezz_admin_bans::request_ban(player, moderation_target, "30m", "menu");
                    break;
                case "ban2h":
                    ezz_admin_bans::request_ban(player, moderation_target, "2h", "menu");
                    break;
                case "banperm":
                    ezz_admin_bans::request_ban(player, moderation_target, "perm", "menu");
                    break;
                case "baninfo":
                    ezz_admin_bans::show_ban_info(player, moderation_target);
                    break;
                case "history":
                    ezz_admin_moderation::show_history(player, moderation_target);
                    break;
            }

            pintemod_menu_open_category(player, "moderation");
            return;

        case "command":
            if (ezz_admin_identity::has_dangerous_command_characters(item.value))
            {
                player iprintln("^1[PinteMod]^7 Unsafe menu command rejected.");
                println(
                    "^1[PinteMod Menu]^7 UNSAFE_COMMAND_REJECTED | actor=" +
                    player.name + " | item=" + item.label
                );
                return;
            }

            executecommand(item.value);

            player iprintln(
                "^5[PinteMod]^7 Request sent: ^3" +
                item.label
            );
            return;

    }
}

function pintemod_menu_delayed_command(command_line)
{
    self endon("disconnect");

    // Allow the HUD cleanup to restore menu-specific controls first.
    wait 0.2;

    if (ezz_admin_identity::has_dangerous_command_characters(command_line))
    {
        println("^1[PinteMod Menu]^7 UNSAFE_DELAYED_COMMAND_REJECTED");
        return;
    }

    executecommand(command_line);
}

// ------------------------------------------------------------
// Input loop
// ------------------------------------------------------------

function pintemod_menu_refresh_selection(player, previous_selected)
{
    selected = player.pintemod_menu_selected;
    previous_first = 0;
    selected_first = 0;

    if (previous_selected >= 6)
        previous_first = previous_selected - 5;

    if (selected >= 6)
        selected_first = selected - 5;

    // A scroll boundary changes all six visible rows. Only then is a
    // complete HUD redraw necessary. Ordinary moves update two rows.
    if (previous_first != selected_first)
    {
        pintemod_menu_render(player);
        return;
    }

    visible_selected = selected - selected_first;

    player.pintemod_menu_selector.y =
        154 + (visible_selected * 27);
    player.pintemod_menu_selector_accent.y =
        154 + (visible_selected * 27);

    previous_visible = previous_selected - selected_first;

    if (previous_visible >= 0 && previous_visible < 6 &&
        previous_selected >= 0 &&
        previous_selected < player.pintemod_menu_items.size)
    {
        previous_line = player.pintemod_menu_lines[previous_visible];
        previous_item =
            player.pintemod_menu_items[previous_selected];

        previous_line.color = (0.70, 0.75, 0.82);
        previous_line SetText("^7  " + previous_item.label);
    }

    if (visible_selected >= 0 && visible_selected < 6)
    {
        selected_line = player.pintemod_menu_lines[visible_selected];
        selected_item = player.pintemod_menu_items[selected];

        selected_line.color = (1, 1, 1);
        selected_line SetText("^7> " + selected_item.label);
    }
}

function pintemod_menu_move_selection(player, direction)
{
    previous_selected = player.pintemod_menu_selected;
    player.pintemod_menu_selected += direction;

    if (player.pintemod_menu_selected < 0)
    {
        player.pintemod_menu_selected =
            player.pintemod_menu_items.size - 1;
    }

    if (player.pintemod_menu_selected >=
        player.pintemod_menu_items.size)
    {
        player.pintemod_menu_selected = 0;
    }

    pintemod_menu_refresh_selection(player, previous_selected);
}

function pintemod_menu_input_loop()
{
    self endon("disconnect");
    self endon("pintemod_menu_close");

    up_was_down = false;
    down_was_down = false;
    use_was_down = false;
    reload_was_down = false;
    melee_was_down = false;

    up_hold_ticks = 0;
    down_hold_ticks = 0;

    for (;;)
    {
        up_is_down = self ActionSlotTwoButtonPressed();
        down_is_down = self ActionSlotThreeButtonPressed();
        use_is_down = self UseButtonPressed();
        reload_is_down = self ReloadButtonPressed();
        melee_is_down = self MeleeButtonPressed();

        if (up_is_down)
        {
            if (!up_was_down || up_hold_ticks >= 12)
            {
                pintemod_menu_move_selection(self, -1);

                if (up_hold_ticks >= 12)
                    up_hold_ticks = 7;
            }

            up_hold_ticks++;
        }
        else
        {
            up_hold_ticks = 0;
        }

        if (down_is_down)
        {
            if (!down_was_down || down_hold_ticks >= 12)
            {
                pintemod_menu_move_selection(self, 1);

                if (down_hold_ticks >= 12)
                    down_hold_ticks = 7;
            }

            down_hold_ticks++;
        }
        else
        {
            down_hold_ticks = 0;
        }

        if ((use_is_down && !use_was_down) ||
            (reload_is_down && !reload_was_down))
        {
            pintemod_menu_execute_selected(self);
        }

        if (melee_is_down && !melee_was_down)
        {
            role = pintemod_menu_get_role(self);

            if (self.pintemod_menu_category == "main" ||
                (self.pintemod_menu_category == "community" &&
                 role <= 0))
            {
                self notify("pintemod_menu_close");
                return;
            }

            parent = pintemod_menu_get_parent_category(
                self.pintemod_menu_category
            );

            pintemod_menu_open_category(self, parent);
        }

        up_was_down = up_is_down;
        down_was_down = down_is_down;
        use_was_down = use_is_down;
        reload_was_down = reload_is_down;
        melee_was_down = melee_is_down;

        wait 0.02;
    }
}

// ------------------------------------------------------------
// Lifecycle
// ------------------------------------------------------------

function pintemod_menu_run()
{
    self endon("disconnect");

    self notify("pintemod_menu_close");
    wait 0.05;

    self.pintemod_menu_open = true;
    self.pintemod_menu_target_selector =
        ezz_admin_identity::get_player_selector(self);

    self DisableOffhandWeapons();

    pintemod_menu_create_hud(self);
    self SetBlur(1.6, 0.15);

    if (pintemod_menu_get_role(self) <= 0)
        pintemod_menu_open_category(self, "community");
    else
        pintemod_menu_open_category(self, "main");

    self thread pintemod_menu_input_loop();

    self waittill("pintemod_menu_close");

    pintemod_menu_destroy(self);
}

function cmd_ezzmenu(args)
{
    if (args.size <= 0)
    {
        println("^5[PinteMod]^7 Usage: ezzmenu <PlayerName|BOIII_XUID|ClientNumber>");
        return;
    }

    player = pintemod_menu_find_player_exact(args[0]);

    if (!isdefined(player))
    {
        println("^1[PinteMod] Player not found: " + args[0]);
        return;
    }

    role = pintemod_menu_get_role(player);
    public_enabled = true;

    if (isdefined(level.pintemod_public_menu_enabled))
        public_enabled = level.pintemod_public_menu_enabled;

    if (role <= 0 && !public_enabled)
    {
        println("^3[PinteMod]^7 Public menu is disabled");
        player iprintln("^3[PinteMod]^7 Player Menu is disabled.");
        return;
    }

    if (isdefined(player.pintemod_menu_open) &&
        player.pintemod_menu_open)
    {
        player notify("pintemod_menu_close");
        return;
    }

    if (role <= 0)
    {
        println(
            "^5[PinteMod]^7 Opening Player Menu for " +
            player.name
        );
    }
    else
    {
        println(
            "^5[PinteMod]^7 Opening administrator menu for " +
            player.name
        );
    }

    player thread pintemod_menu_run();
}

function cmd_ezzmenuclose(args)
{
    if (args.size <= 0)
    {
        println("^5[PinteMod]^7 Usage: ezzmenuclose <PlayerName|BOIII_XUID|ClientNumber>");
        return;
    }

    player = pintemod_menu_find_player_exact(args[0]);

    if (!isdefined(player))
    {
        println("^1[PinteMod] Player not found: " + args[0]);
        return;
    }

    player notify("pintemod_menu_close");

    println("^5[PinteMod]^7 Menu close requested for " + player.name);
}

function cmd_ezzmenustatus(args)
{
    players = GetPlayers();

    println("^5========== PINTE MOD MENU ==========");
    println("^7Version: " + level.pintemod_menu_version);

    for (i = 0; i < players.size; i++)
    {
        player = players[i];

        if (!isdefined(player))
            continue;

        state = "CLOSED";

        if (isdefined(player.pintemod_menu_open) &&
            player.pintemod_menu_open)
        {
            state = "OPEN";
        }

        println(
            "^7" + player.name +
            " | " +
            pintemod_menu_role_name(
                pintemod_menu_get_role(player)
            ) +
            " | " + state
        );
    }

    println("^5====================================");
}
