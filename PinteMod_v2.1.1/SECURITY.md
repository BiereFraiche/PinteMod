# Security policy

PinteMod authenticates roles by BOIII_XUID. Display names are never trusted as persistent identities.

## Never publish

- `zone/pintemod_server_secrets.cfg`
- `boiii/tools/PinteMod_GeoIP_Bridge.secret.txt`
- `boiii/tools/*.local.json`
- `boiii/scriptdata/pintemod/`
- runtime logs, ranks, EE records, language preferences or real ban databases

These paths are excluded by the supplied `.gitignore`.

## RCON

Use a strong password distinct from any game password. For a VM or remote tools machine, prefer LAN/VPN connectivity and restrict UDP/RCON access at the firewall to the administration host. Do not expose RCON openly to the Internet.

Windows DPAPI secrets are tied to the Windows account and machine that created them. Re-run the configurator when moving GeoIP to another host or account.

## GeoIP privacy

The GeoIP bridge processes player addresses in memory and does not log or persist them. BOIII can temporarily print addresses in its native RCON `status` output.

## Ban privacy and authorization

PinteMod bans are keyed by BOIII_XUID and do not store IP addresses. Stored fields are limited to XUID, display metadata, reason, actor and UTC timestamps.

GSC enforces Owner/Admin hierarchy before writing a local request. Protect write access to `boiii/scriptdata/pintemod/bans/`; a user who can modify server runtime files already has server-level administrative access.

## Vulnerability reporting

Report security problems privately to the repository owner before public disclosure.
