# Authentication and service-access status

This is an independent third-party derivative of PCL, not an official PCL,
Mojang or Microsoft release. Application display name: **熊猫启动器**.

## Status

- Microsoft public client application registered; device authorization endpoint
  returned a valid response during setup. This is **not** proof of end-to-end
  Minecraft authentication or Mojang approval.
- Minecraft Services AppID application submitted on **2026-10-21**;
  **awaiting review / not approved**.
- CurseForge API application submitted on **2026-10-21**;
  **awaiting review / no key received or configured**.
- No public binary release is promised until authentication has been tested with
  an authorized account after the required service approvals.

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
launch. There is no offline fallback in this edition, even for offline-mode servers.

Only the Microsoft login type is accepted by the login entry points, and the
Java process entry checks the resulting session again. This last local check
validates session structure; it does not replace the preceding server checks.
Legacy and third-party authentication code inherited from upstream remains in
the source for traceability, but is not an enabled gameplay route in this edition.
Standalone launch-script export is disabled.

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
  Microsoft, Xbox, Mojang, download providers and enabled resources.
- Developers may override the public client ID with `PCL_MS_CLIENT_ID` for their
  own registered/approved application. Do not borrow other launchers' identifiers.
- `PCL_CURSEFORGE_API_KEY` is read only from the local environment; no key is
  stored in source or injected by a build pipeline. The header is attached only
  to the intended HTTPS `api.curseforge.com` endpoint, not CDNs or mirrors.
  Distributable CurseForge integration needs its own approval and an appropriate
  key-management plan; an empty value cannot fix an HTTP 403.

## Verification boundary

Tests check local policy cases, source integration and compiled constants without
starting the launcher or authenticating a real player. They are **not** an
end-to-end service, ownership or game-launch test. Those checks remain manual and
require service approval and an eligible Microsoft account.
