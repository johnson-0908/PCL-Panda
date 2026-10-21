# Source provenance and modification notice

## Upstream

- PCL: <https://github.com/Meloong-Git/PCL>
  - Snapshot commit: `6b9a50df911c9d68b69b24c979efba477fb14b67`
  - Base version: `2.99.0.0`
  - Original developer: 龙腾猫跃 (LTCat), with upstream contributors.
  - Original copyright notices and `LICENCE` are retained.
- MeloongCore: the PCL submodule snapshot
  `98157d65c7627721c816c02e8be96ac4fe61d615`.
  - Vendored source, not a live submodule; `MeloongCore/LICENSE.txt` retained.

## Independent modifications

PCL2复活版（第三方修改版）, maintained independently by `johnson-0908`.
Initial public-source preparation: 2026-10-21.

- Dedicated identity/configuration namespace and public-client application ID.
- Enabled download features in the source build without removing file validation.
- Restored explicit offline login alongside Microsoft login. Kept online
  entitlement/profile checks for Microsoft sessions, mode-specific process-entry
  validation, and disabled script export. Microsoft failures never auto-downgrade.
- Kept license consent; replaced outdated source-build startup notices with an
  documentation of service-access status. Kept attribution, purchase/support prompts.
- Restricted CurseForge API-key header attachment to the intended HTTPS host.
- Temporarily disabled CurseForge integration; use Modrinth for community downloads
  and BMCLAPI mirror-first defaults for Minecraft files.
- Removed the More navigation, help/about/toolbox pages, their bundled resources,
  feedback/voting flows and obsolete feature toggles. Kept a compact attribution
  and license section in settings.
- Added independent local color palettes and custom HSL controls without a donation
  overlay or unlock state. This does not reproduce upstream closed-source effects.
- Added reproducible local build/policy checks and publication safeguards.
- Added an independent GitHub Releases updater, exact-file packaging, SHA-256
  validation, explicit download/restart consent, and single-backup rollback.
  Release versioning starts at 1.0.0 independently of the upstream assembly version.

This repository starts from a source snapshot, not the developer's private
working history. Original upstream release archives, binary delta patches and
upstream-specific automation/issue templates are not redistributed here.
Unused More-page artwork and the bundled help archive have been removed. Other
upstream source resources needed for compilation retain their original bytes.

No affiliation or endorsement by the PCL authors, Mojang or Microsoft is claimed.
Modifications remain subject to the original PCL permission boundaries and guide;
this notice does not relicense upstream material or grant additional rights.
