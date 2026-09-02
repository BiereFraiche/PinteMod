# PinteMod

[Read this guide in French](README_FR.md)

PinteMod is a server-side framework for **Call of Duty: Black Ops III Zombies** servers using BOIII/Ezz. It adds moderation, community features, localization, records and practical server health information.

Players have nothing to install. PinteMod runs on the server.

The stable PinteMod baseline is **v2.1.1**. The easiest way to install and manage it is the companion app **PinteMod Control Center v2.4.5**.

## Start a server in a few clicks — recommended

1. Download a ready-to-use blank BOIII/Ezz server from [the shared Mega folder](https://mega.nz/folder/MYsTGa6I#gJviuei7G6XuFicNy_L9BQ).
2. Download [PinteMod Control Center](https://github.com/BiereFraiche/PinteModControlCenter/releases/tag/v2.4.5).
3. Open the Control Center and add the folder that contains `boiii` and `Server.bat`.
4. Choose **Install PinteMod**. The Control Center detects the server and prepares the supported local files.
5. Set the RCON password when requested, then start the server from the Control Center.
6. Run the PinteMod health check once the server is online.

That is all that is required for a normal local server. The Control Center can also manage several servers and show players, logs, records and service health.

[![Download PinteMod Control Center](https://img.shields.io/badge/Download-Control%20Center%20v2.4.5-168BFF)](https://github.com/BiereFraiche/PinteModControlCenter/releases/tag/v2.4.5)

[![PinteMod Control Center dashboard](https://raw.githubusercontent.com/BiereFraiche/PinteModControlCenter/main/design/pintemod-control-center-reference.png)](https://github.com/BiereFraiche/PinteModControlCenter)

## What PinteMod adds

- a clean in-game administration and community menu;
- owner, admin, moderator, helper and player roles;
- persistent XUID-based bans, mutes and moderation history;
- player language preferences and anonymous language statistics;
- GeoIP country information, with privacy-conscious local storage;
- ranks, round records and Easter Egg records;
- map compatibility checks, health diagnostics and local service status;
- optional Windows tools for the Ban Service, GeoIP Bridge and Live Console.

The stable framework supports the BO3 Zombies maps and Zombies Chronicles. Custom maps can use the generic framework, but map-specific quests, music and gameplay features are not guaranteed.

## Manual installation — advanced users

Use this route only when you do not want to use the Control Center.

1. Stop BOIII and every PinteMod tool.
2. Back up `boiii/custom_scripts/` and `boiii/scriptdata/pintemod/`.
3. Extract this package into the existing server folder containing `boiii` and `zone`.
4. Run `Verify_PinteMod_Installation.bat` and resolve every `ERROR`.
5. Start with `Launch_PinteMod_Server.bat`.
6. Configure RCON locally when requested; never share its password.

Useful launchers:

- `Launch_PinteMod_Server.bat` — local all-in-one server and optional tools;
- `Launch_PinteMod_Server_Only.bat` — BOIII only;
- `Launch_PinteMod_Remote_Tools.bat` — tools on another trusted Windows PC;
- `Configure_PinteMod_RCON.bat` — manual RCON setup;
- `Test_PinteMod_v2.1.1.bat` — manual verification.

## Safe use

- Never publish RCON passwords, `*.secret` files, player XUIDs, runtime data or logs.
- Keep RCON and SMB accessible only from a trusted local network or VPN.
- Do not expose SMB/TCP 445 directly to the Internet.
- Use the Control Center for the first setup whenever possible: it guides the required steps and avoids manual file edits.

## Further help

- [French manual installation guide](docs/INSTALLATION_FR.txt)
- [French VM and remote deployment guide](docs/DEPLOIEMENT_LOCAL_VM_DISTANT_FR.txt)
- [French console command reference](docs/COMMANDES_CONSOLE_FR.txt)
- [French bans and moderation guide](docs/BANNISSEMENTS_FR.txt)
- [PinteMod Control Center](https://github.com/BiereFraiche/PinteModControlCenter)
- [Security policy](SECURITY.md)
- [Changelog](CHANGELOG.md)

## Stable versus experimental

PinteMod **v2.1.1** is the public stable foundation. Community Soft Pause and some remote-control feedback additions remain experimental: test them on a private server before relying on them for public events.

Created and maintained by **BiereFraiche**, with development assistance from ChatGPT and Codex.

## License

See [LICENSE](LICENSE).
