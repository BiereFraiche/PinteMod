# PinteMod v1.3 FINAL

PinteMod is a server-side administration and community framework for **Call of Duty: Black Ops III Zombies** on **BOIII/Ezz**.

Created by **BiereFraiche and ChatGPT**.

No compiled mod and no client download are required. Players can join the server normally.

## Main features

- Complete server-side HUD administration menu
- Public Player Menu opened with `.menu`
- Role-based permissions
- Primary chat-command prefix `.` with legacy `!` compatibility
- Large welcome HUD with `.menu` and late-join instructions
- Safe public late join using `.spawn` or the Player Menu
- Administrative respawn using `.respawn`
- Next-map voting without interrupting the current match
- Restart voting with a five-second warning
- Protected and logged vote-kick system
- Vote-kicked players blocked from reconnecting until the next map
- Automatic map change at the end of the match
- Live Console with connection, chat, menu, community, vote and record logs
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
- Persistent Ranks & Records system
- Personal activity statistics and leaderboards
- Round records separated into 1P, 2P, 3P and 4P categories
- Top 5 records per map and player-count category
- Record eligibility based on at least 70% match presence
- Faster time used as the tie-breaker for identical round records
- Automatic unranked-match protection after gameplay-affecting admin commands
- Record announcements in chat and Live Console
- Rank backup, audit and protected reset tools

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

### Main menu sections

- Administration
- Perks
- Weapons
- Rounds
- Power-Ups
- Fun
- Community
- Rankings & Records

The menu contents depend on the player's role and the current map.

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
.rank
.ranks
.record
.records [1-4]
```

`.spawn` is reserved for public late join.

Administrative respawn uses:

```text
.respawn [player]
```

## Ranks & Records

PinteMod v1.3 includes a persistent Ranks & Records system.

### Personal statistics

```text
.rank
```

Displays the current player's:

- total playtime
- number of sessions
- global activity position
- best round
- current-match presence percentage
- ranked or unranked match status

### Activity leaderboard

```text
.ranks
```

Displays the most active players and their best-round statistics.

### Map records

```text
.record
.records
.records 1
.records 2
.records 3
.records 4
```

Records are separated into:

- 1 Player
- 2 Players
- 3 Players
- 4 Players

Each map and category stores a maximum of five records.

Records are ordered by:

1. highest round;
2. shortest time to reach that round.

A player must have been present for at least 70% of the current match duration to be included in a record.

A disconnected player can still remain eligible if their recorded presence still represents at least 70% of the match duration when the record is reached.

### Ranked and unranked matches

A match automatically becomes **UNRANKED** when a PinteMod command that directly affects gameplay is successfully used.

Examples include:

- points
- ammunition
- God Mode
- Ignore
- administrative respawn
- weapon or Pack-a-Punch grants
- perk grants
- teleportation
- forced round changes
- zombie elimination
- map unlocks
- permanent drops
- administrative boss spawning

When a match becomes unranked:

- no further records are saved;
- records already created during that match are restored to their previous values;
- playtime and session statistics continue to be counted;
- the reason is announced in chat and Live Console.

Public voting, menu access, music, diagnostics and public late join do not make a match unranked.

### Persistent storage

Ranks & Records data is stored in:

```text
boiii/scriptdata/pintemod/
```

Main folders:

```text
ranks/players/
ranks/maps/
logs/
backups/ranks/
```

## Rank maintenance commands

These commands are intended for the dedicated-server console.

### Audit rank data

```text
ezzrankaudit
```

Checks player and map JSON files, Top 5 ordering, missing fields and invalid records.

### Create a backup

```text
ezzrankbackup
ezzrankbackup before_update
```

Creates a numbered backup in:

```text
boiii/scriptdata/pintemod/backups/ranks/
```

### Protected reset

Prepare a reset:

```text
ezzrankreset prepare
```

The server must be empty. A backup is created automatically and a temporary confirmation token is displayed.

Confirm with:

```text
ezzrankreset confirm <token>
```

Cancel with:

```text
ezzrankreset cancel
```

## Validated community features

The following features have been validated on a real dedicated BOIII server:

- Large welcome HUD
- Public and administrator menus
- Late join and `.spawn`
- Administrative respawn
- Next-map vote
- Automatic map change after the match
- Restart vote
- Solo next-map and restart votes
- Player leave logging
- Perk toggles
- Live Console and real-time logs
- Music module
- Events module
- `ezzspawn`
- `ezzpapweapon`
- Permanent drops
- Ranks & Records module loading and persistent storage
- Record announcements in chat
- Record announcements in Live Console
- Ranked and unranked match status

Vote-kick is included, protected and now blocks reconnection until the next map. Broader testing with at least three players is still recommended.

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
2. Back up the current `boiii/custom_scripts/` folder.
3. Remove the previous PinteMod files to avoid loading obsolete or duplicate scripts.
4. Copy the `custom_scripts` folder from the package directly into the `boiii` folder.

The result must be:

```text
boiii/custom_scripts/*.gsc
```

5. Edit:

```text
boiii/custom_scripts/ezz_admin_config.gsc
```

6. Configure the Owner and Admin display names.
7. Fully restart the server.
8. Check the server console for the module loading messages.

The Live Console is optional. Copy the files from `tools/` to a convenient location inside the server folder and run:

```text
Launch_PinteMod_LiveConsole.bat
```

## Noclip

Noclip is intentionally disabled.

The command remains registered only to display an unavailable message.

## Authentication and security

PinteMod v1.3 still assigns roles and player records using the player's **display name**, with case-insensitive comparison.

This is intended for private friends-only servers, preferably protected with:

```text
g_password
```

It is **not secure authentication for an open public server** because another player can use a configured administrator name.

Before public deployment, display-name authentication must be replaced with XUID, SteamID64 or another reliable permanent identifier.

The future SteamID64/XUID migration will include a full reset of existing player records to prevent identity conflicts.

Player names containing spaces are not uniformly supported by every administrative command.

A player blocked after a vote-kick can currently bypass the map-level block by changing their display name.

## Default owner

The default Owner name in the package is:

```text
BiereFraiche
```

Change it in `ezz_admin_config.gsc` before deployment when necessary.

## Excluded from this stable release

The following features are intentionally not included in PinteMod v1.3 FINAL:

- Easter Egg speed records
- generic Easter Egg completion detection
- SteamID64/XUID authentication
- public-server-grade identity security
- AFK commands
- round-transition locking
- functional noclip

Easter Egg records will be developed map by map and only when a reliable quest-completion event can be identified.

Origins and Revelations will require the record to be saved immediately before their quest completion ends the match.

## Credits

Created by **BiereFraiche and ChatGPT**.
