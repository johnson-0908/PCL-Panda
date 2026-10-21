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

PCL 熊猫启动器（第三方修改版）, maintained independently by `johnson-0908`.
Initial public-source preparation: 2026-10-21.

- Dedicated identity/configuration namespace and public-client application ID.
- Enabled download features in the source build without removing file validation.
- Microsoft-only gameplay policy with online entitlement/profile checks for
  cached sessions, final process-entry validation, and disabled script export.
- Kept license consent; replaced outdated source-build startup notices with an
  About-page service-access status. Kept attribution, purchase/support prompts.
- Restricted CurseForge API-key header attachment to the intended HTTPS host.
- Added reproducible local build/policy checks and publication safeguards.

This repository starts from a source snapshot, not the developer's private
working history. Original upstream release archives, binary delta patches and
upstream-specific automation/issue templates are not redistributed here.
Upstream source resources needed for compilation retain their original bytes.

No affiliation or endorsement by the PCL authors, Mojang or Microsoft is claimed.
Modifications remain subject to the original PCL permission boundaries and guide;
this notice does not relicense upstream material or grant additional rights.
