# Authentication and service-access status

This is an independent third-party derivative of PCL, not an official PCL,
Mojang or Microsoft release. Launcher display name: **PCL2复活版**.
This local rename does not rename the existing Microsoft app registration or
service-review submissions. Microsoft consent screens may still show the
previously registered display name; the client ID and account storage are unchanged.

## Status

- Microsoft public client application registered; device authorization endpoint
  returned a valid response during setup. This is **not** proof of end-to-end
  Minecraft authentication or Mojang approval.
- Minecraft Services AppID application submitted on **2026-10-21**;
  **awaiting review / not approved**.
- CurseForge API application submitted on **2026-10-21**;
  **awaiting review / integration temporarily disabled**, even if a local key exists.
- Public test binaries cover the independent UI, download and update work.
  Their availability does not imply approved Minecraft service access or tested
  end-to-end Microsoft login/gameplay; those still require separate verification.

## Microsoft and Minecraft login

The public client ID is `d1652c9c-65d6-4007-86ff-cdfbe048e978`.
It is an application identifier, **not a secret**. No client secret is embedded.
Personal Microsoft accounts use the OAuth device-code flow through Microsoft;
the launcher does not ask for the Microsoft account password.

The code exchanges the Microsoft token through Xbox Live and XSTS, then obtains
a Minecraft Services token. Before permitting gameplay, it requests
`/entitlements/mcstore` and `/minecraft/profile`. Both a fresh OAuth login and
reuse of a cached Minecraft token perform these online checks. The existing
PCL entitlement check requires a non-empty entitlement list; a Java profile is
also required. Network errors, missing ownership, and invalid profiles stop the
Microsoft launch. A failed Microsoft login never automatically falls back to offline mode.

The login entry points support Microsoft and explicitly selected offline
(`Legacy`) profiles. The Java process entry checks that the resulting session
matches the selected mode. Offline profiles use the upstream local name/UUID
flow; they do not obtain a Microsoft token or count as proof of ownership.
Upstream name validation and purchase/support prompts remain unchanged.
Microsoft sessions still require the online checks above; unrelated third-party
login methods and standalone launch-script export remain disabled.

Main implementation: `Plain Craft Launcher 2/Modules/Minecraft/ModLaunch.vb`;
local guards: `PCLCS/Launch/PandaAuthenticationPolicy.cs`.

## Data and API keys

- This repository contains no game files, saves, account profiles, logs or
  developer workstation configuration. Game data is selected locally.
- Launcher configuration and token caches are local. Treat the runtime folder,
  logs and registry configuration as sensitive; do not upload them to issues or
  distribute a copy of a used runtime folder. No claim is made that upstream
  token storage is a hardened secret vault.
- `PCLPanda` identifies this edition's registry/AppData scope; the launcher also
  uses its own directory-local `PCL/config.json`. Use a separate runtime directory.
- No project telemetry endpoint is configured. Normal requests still reach
  Microsoft, Xbox, Mojang, download providers and enabled resources. The optional
  launcher update check contacts this repository's public GitHub Releases API,
  without account details or a GitHub token; it can be disabled in settings.
- Developers may override the public client ID with `PCL_MS_CLIENT_ID` for their
  own registered/approved application. Do not borrow other launchers' identifiers.
- `PCL_CURSEFORGE_API_KEY` is read only from the local environment; no key is
  stored in source or injected by a build pipeline. The header is attached only
  to the intended HTTPS `api.curseforge.com` endpoint, not CDNs or mirrors.
  Distributable CurseForge integration needs its own approval and an appropriate
  key-management plan; an empty value cannot fix an HTTP 403.
- CurseForge integration is currently disabled at search and HTTP request
  boundaries, including when a local key is configured. Background resource
  lookup skips that provider, and CF-format pack installation fails before
  extraction with a clear message. Community downloads use Modrinth instead.
  The retired MCIM fallback is disabled.
  See [download routes and verification](DOWNLOADS.md). Downloads do not grant
  Minecraft ownership or service access.

## Verification boundary

Tests check both login modes, local policy cases, source integration and compiled constants without
starting the launcher or authenticating a real player. They are **not** an
end-to-end service, ownership or game-launch test. Those checks remain manual and
require service approval and an eligible Microsoft account.
