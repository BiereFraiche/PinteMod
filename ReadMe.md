# PinteMod v1.2 FINAL

PinteMod is a server-side administration and community framework for **Call of Duty: Black Ops III Zombies** on **BOIII/Ezz**.

Created by **BiereFraiche and ChatGPT**.

No compiled mod and no client download are required. Players can join the server normally.

## Main features

- Complete server-side HUD administration menu
- Role-based permissions
- Primary chat-command prefix `.` with legacy `!` compatibility
- Public Player Menu opened with `.menu`
- Large welcome HUD with `.menu` and late-join instructions
- Safe late join using `.spawn` or the Player Menu
- Next-map voting without interrupting the current match
- Restart voting with a five-second warning
- Protected and logged vote-kick system
- Live Console with connection, chat, menu, community and vote logs
- Player targeting, points, ammo, God Mode and ignore controls
- Weapon management and Pack-a-Punch
- Toggleable perks from the menu
- Power-Ups and permanent drops
- Zombie and round controls
- Map power, Pack-a-Punch and standard unlock tools
- Position save/load and teleportation
- Map-specific music
- Dynamic native boss events
- All 14 official BO3 Zombies map profiles

## Menu

Open the menu with:

```text
.menu
```

The older `!menu` syntax remains accepted for compatibility.

### Controls

- **Key 2 / Action Slot 2:** Up
- **Key 4 / Action Slot 3:** Down
- **Use or Reload:** Select
- **Melee:** Back / Close

## Community commands

```text
.menu
.spawn
.yes
.no
.votestatus
.votemap <map>
.voterestart
.votekick <player> [reason]
```

`.spawn` is reserved for public late join. Administrative respawn uses `.respawn [player]`.

## Validated community features

The following were validated on a real dedicated BOIII server:

- Large welcome HUD
- Public and administrator menus
- Late join and `.spawn`
- Next-map vote
- Automatic map change after the match
- Restart vote
- Solo next-map and restart votes
- Player leave logging
- Perk toggles
- Live Console and real-time logs

Vote-kick is included and protected, but still requires broader three-player testing.

## Validated boss events

- Shadows of Evil: Margwa
- Origins: Panzer
- Der Eisendrache: Panzer
- Zetsubou No Shima: Thrasher
- Gorod Krovi: Mechz
- Revelations: Margwa variants and Panzer
- Moon: Astronaut

Bosses spawn at the targeted player's aimed ground position and retain native behavior and statistics.

## Special music

Configured music includes:

- Shadows of Evil: Snakeskin Boots / Cold Hard Cash
- Der Eisendrache: Dead Again
- Gorod Krovi: Ace of Spades / Dead Ended
- Revelations: The Gift
- Verrückt: Lullaby for a Dead Man
- Shi No Numa: The One
- Kino der Toten: 115
- Ascension: Abracadavre
- Shangri-La: Pareidolia
- Moon: Coming Home / Nightmare
- Origins: Archangel

Dead Flowers on Zetsubou No Shima is not enabled because the expected native music registry was unavailable on the tested BOIII server.

## Installation

1. Fully stop the dedicated server.
2. Copy the `custom_scripts` folder from the package directly into your `boiii` folder. The result must be:

```text
boiii/custom_scripts/*.gsc
```

3. Edit `boiii/custom_scripts/ezz_admin_config.gsc` and configure the Owner/Admin names.
4. Fully restart the server.

The Live Console is optional. Copy the two files from `Tools/` to a convenient location inside the server folder and run `Launch_PinteMod_LiveConsole.bat`.

## Noclip

Noclip is intentionally disabled. The command remains registered but only displays an unavailable message.

## Authentication and security

PinteMod v1.2 assigns roles using the player's **display name**, with case-insensitive comparison.

This is intended for private friends-only servers, preferably protected with `g_password`. It is **not secure authentication for an open public server** because another player can use a configured administrator name.

Before public deployment, replace display-name authentication with XUID, SteamID or another reliable permanent identifier.

The default Owner name in this package is:

```text
BiereFraiche
```

Change it in `ezz_admin_config.gsc` before deployment.

## Excluded from this stable release

Ranks, activity leaderboards and Easter Egg records are **not included** in v1.2 FINAL. They remain experimental work for a later release.
