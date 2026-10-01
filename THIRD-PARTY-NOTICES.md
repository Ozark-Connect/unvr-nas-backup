# Third-Party Notices

This project uses the following third-party software:

## unifi-protect-remux

- **Project**: UBV Remux Tool
- **Author**: Peter Wright
- **Copyright**: Copyright (C) 2020-2026 Peter Wright
- **License**: GNU Affero General Public License v3.0 (AGPL-3.0-only)
- **Source**: https://github.com/petergeneric/unifi-protect-remux
- **Usage**: Built from source (v4.2.2, commit `9f2cf0906d5baca92d327831ad778d950764bed5`) at Docker image build time and invoked as an external tool to convert `.ubv` surveillance video files to `.mp4` format.
- **Modifications**: The image includes a modified version. The patches in [patches/](patches/) are applied before building, and are licensed under AGPL-3.0-only like the code they modify. See [patches/README.md](patches/README.md) for what each patch changes.

The full text of the AGPL-3.0 license can be found at:
https://www.gnu.org/licenses/agpl-3.0.html

The complete source code for unifi-protect-remux is available at:
https://github.com/petergeneric/unifi-protect-remux

The corresponding source for the modified version in the image is the upstream commit above plus the patches in this repository.
