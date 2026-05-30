<p align="center">
  <img src="docs/images/ozark-connect-logo.png" alt="Ozark Connect" width="200">
</p>

# unvr-nas-backup

[![GitHub Release](https://img.shields.io/github/v/release/Ozark-Connect/unvr-nas-backup)](https://github.com/Ozark-Connect/unvr-nas-backup/releases)
[![GitHub last commit](https://img.shields.io/github/last-commit/Ozark-Connect/unvr-nas-backup)](https://github.com/Ozark-Connect/unvr-nas-backup/commits)
[![GitHub Stars](https://img.shields.io/github/stars/Ozark-Connect/unvr-nas-backup)](https://github.com/Ozark-Connect/unvr-nas-backup/stargazers)
[![License](https://img.shields.io/badge/license-MIT-green)](https://github.com/Ozark-Connect/unvr-nas-backup/blob/main/LICENSE)

Dockerized backup system that pulls continuous surveillance video from a UniFi Protect device (CloudKey, UCG, UDM, UNVR, etc.), remuxes `.ubv` files to `.mp4`, renames them with camera names, and archives them to a NAS.

> **Note:** Recordings can only be backed up after the Protect device finishes writing them. UniFi Protect writes ~1 GB `.ubv` segments; busy cameras close segments quickly, but **low-activity cameras may take many hours** to fill a segment, so there can be a significant delay before those recordings appear in the archive. This is **not** real-time replication - it is near-real-time archival. For the best coverage, pair this tool with UniFi Protect's built-in **Continuous Archiving** (UI Labs) feature, which handles detection event clips. As far as we know, this is the only open-source tool that backs up continuous recording video.

## How it works

```
NAS (Docker)                        Protect Device (CloudKey, UCG, UDM, UNVR, etc.)
┌────────────────────────┐          ┌─────────────────────────┐
│  cron → backup.sh      │── SSH -> │  PostgreSQL :5433       │
│                        │          │  .ubv video files       │
│  1. Query DB for files │          └─────────────────────────┘
│  2. SCP .ubv to staging│
│  3. Remux → .mp4       │
│  4. Rename with camera │
│     name + timestamps  │
│  5. Archive to         │
│     /CamName/date/     │
└────────────────────────┘
```

## Prerequisites

- Docker and Docker Compose on the NAS (x86_64 or ARM64)
- Network connectivity from the NAS to the Protect device
- SSH enabled on the Protect device (the installer can set up key auth for you)
- A UniFi Protect device with active recordings

### Setting up SSH access

1. **Enable SSH on your Protect device**: In your UniFi Console, go to **Settings -> Control Plane -> Console -> SSH** and enable it. Note the password you set here. The default SSH username is root for Console devices.

2. **Run the installer** - it will detect that SSH key auth isn't set up and offer to configure it automatically. It generates a key if needed and copies it to your Protect device using `ssh-copy-id`. You just need to enter the SSH password once.

   If you prefer to set up SSH manually:
   ```bash
   ssh-keygen -t ed25519                  # generate a key (if you don't have one)
   ssh-copy-id root@<protect-host>        # copy it to the Protect device
   ssh root@<protect-host>                # verify it works (no password prompt)
   ```

The container mounts your key from `SSH_KEY_PATH` (defaults to `~/.ssh`) and uses it automatically.

## Quick start

**Option 1** - Standalone install (no git required):
```bash
mkdir -p /opt/unvr-nas-backup && cd /opt/unvr-nas-backup
curl -fsSLO https://raw.githubusercontent.com/Ozark-Connect/unvr-nas-backup/main/install.sh
chmod +x install.sh && ./install.sh
```

**Option 2** - Clone the repo (includes helper scripts for status, updates, etc.):
```bash
git clone https://github.com/Ozark-Connect/unvr-nas-backup.git /opt/unvr-nas-backup
cd /opt/unvr-nas-backup
./install.sh
```

The installer prompts for your Protect device host, archive path, and other settings. It downloads `compose.yml` if needed, pulls the pre-built image from GHCR, and starts the container.

**Manual setup** (no installer):
```bash
mkdir -p /opt/unvr-nas-backup && cd /opt/unvr-nas-backup
curl -fsSLO https://raw.githubusercontent.com/Ozark-Connect/unvr-nas-backup/main/compose.yml
curl -fsSLO https://raw.githubusercontent.com/Ozark-Connect/unvr-nas-backup/main/.env.example
cp .env.example .env
# Edit .env - set PROTECT_HOST and ARCHIVE_PATH at minimum
docker compose up -d
```

## Helper scripts

| Script | Description |
|---|---|
| `./install.sh` | First-time setup - creates `.env`, tests SSH, pulls image and starts the container |
| `./scripts/status.sh` | Shows backup health: last run, archive stats, disk usage, container/cron status |
| `./scripts/run-now.sh` | Triggers an immediate backup without waiting for cron |
| `./scripts/update.sh` | Pulls latest code and image, and restarts the container |

## Updating

If you cloned the repo:
```bash
cd /opt/unvr-nas-backup
./scripts/update.sh
```

Standalone install:
```bash
cd /opt/unvr-nas-backup
docker compose pull && docker compose up -d
```

Your `.env` and archive are preserved in both cases.

## Stopping

```bash
cd /opt/unvr-nas-backup
docker compose down
```

This stops the container. Your archive and `.env` are not affected. Run `docker compose up -d` to start it again.

## Uninstalling

```bash
cd /opt/unvr-nas-backup
docker compose down -v              # stop container and remove staging volume
docker rmi ghcr.io/ozark-connect/unvr-nas-backup:latest   # remove the image
cd / && rm -rf /opt/unvr-nas-backup # remove install directory
```

Your archive directory is **not** deleted automatically. Remove it manually if you no longer need the recordings.

## Configuration

| Variable | Default | Description |
|---|---|---|
| `PROTECT_HOST` | *(required)* | Hostname or IP of your Protect device |
| `PROTECT_SSH_USER` | `root` | SSH user (`root` on most devices, may differ on standalone UNVRs) |
| `PROTECT_VIDEO_PATH` | `/srv/unifi-protect/video` | Fallback video path if the DB-reported folder is not accessible |
| `PROTECT_DB_PORT` | `5433` | PostgreSQL port |
| `PROTECT_DB_NAME` | `unifi-protect` | PostgreSQL database name |
| `BACKUP_HOURS` | `1` | How many hours back to look for completed recordings (based on end time). Set this to at least 2x your cron interval so recordings that finish between runs are not missed. |
| `BACKUP_CHANNELS` | `0` | Which recording channels to back up (comma-separated). `0` = main high-res stream, `2` = low-quality sub-stream. Most users only need `0`. |
| `BATCH_SIZE` | `5` | Number of files to SCP before pausing |
| `BATCH_DELAY` | `30` | Seconds to pause between SCP batches |
| `ARCHIVE_PATH` | *(required)* | Host path for the archive volume mount |
| `SSH_KEY_PATH` | `~/.ssh` | Host path to SSH keys (mounted read-only) |
| `CRON_SCHEDULE` | `*/15 * * * *` | Cron expression for backup frequency (do not quote this value) |
| `RUN_ON_START` | `true` | Run a backup immediately on container start |
| `TZ` | `UTC` | Timezone for log messages. Archive filenames always use UTC regardless of this setting. |
| `LOG_LEVEL` | `info` | Log level: `debug`, `info`, `warn`, `error` |
| `RETENTION_DAYS` | *(disabled)* | Delete footage older than N days. Runs after each backup. |
| `MAX_ARCHIVE_SIZE` | *(disabled)* | Maximum archive size in GB. Prune oldest footage when the archive exceeds this. Measures the archive directory only - safe on shared volumes. Runs after each backup. |
| `RETENTION_PERCENT` | *(disabled)* | When **total disk usage** exceeds N%, prune oldest footage until it drops below. Note: this measures the entire filesystem, not just the archive - on shared volumes, other data counts toward the threshold. Runs after each backup. |

> **Disk usage**: Continuous recording generates roughly 10-20 GB per camera per day depending on resolution and scene activity. Plan your archive storage accordingly.
>
> **Retention**: All retention settings are disabled by default (the archive grows indefinitely). When multiple are set, they run in order: age-based pruning (`RETENTION_DAYS`) first, then archive size (`MAX_ARCHIVE_SIZE`), then disk usage (`RETENTION_PERCENT`). Pruning always deletes the oldest dates first. On shared volumes, prefer `MAX_ARCHIVE_SIZE` over `RETENTION_PERCENT` so other data on the drive doesn't eat into your footage budget.

## Compatibility

Tested and confirmed working on:

| Device | Status |
|---|---|
| UniFi CloudKey Gen2+ | Tested |
| UniFi Cloud Gateway (UCG-Fiber, UCG-Ultra, UCG-Max, etc.) | Tested |
| UniFi Dream Machine (UDM, UDM-Pro, UDM-SE, etc.) | Likely compatible - testers welcome |
| UniFi Dream Router (UDR, etc.) | Likely compatible - testers welcome |
| UniFi NVR (UNVR, UNVR-Pro, etc.) | Likely compatible - testers welcome |

Should work on any device running UniFi Protect with SSH access, PostgreSQL on port 5433, and `.ubv` video files at `/srv/unifi-protect/video`. If you've tested on a device not listed here, please [open an issue](https://github.com/Ozark-Connect/unvr-nas-backup/issues) to let us know.

## Archive structure

Files are stored canonically by camera, with date-based symlinks for browsing by date:

```
/archive/
├── by-camera/                          # Canonical storage
│   ├── Front-Door/
│   │   ├── 2026-02-19/
│   │   │   ├── Front-Door_2026-02-19_08-00-00_to_08-05-00.mp4
│   │   │   └── Front-Door_2026-02-19_08-05-00_to_08-10-00.mp4
│   │   ├── 2026-02-20/
│   │   │   └── ...
│   │   └── low-quality/                # Only if BACKUP_CHANNELS includes 2
│   │       └── 2026-02-19/
│   │           └── Front-Door_2026-02-19_00-00-00_to_10-00-00_low-quality.mp4
│   └── Backyard/
│       └── ...
└── by-date/                            # Symlinks
    ├── 2026-02-19/
    │   ├── Front-Door             → ../../by-camera/Front-Door/2026-02-19
    │   ├── Front-Door-low-quality → ../../by-camera/Front-Door/low-quality/2026-02-19
    │   └── Backyard               → ../../by-camera/Backyard/2026-02-19
    └── 2026-02-20/
        └── ...
```

> **Note:** The `by-date` directory uses symlinks, which may not be visible when browsing via SMB/Windows shares. The `by-camera` directory always works directly.

## Troubleshooting

- **SSH fails**: Ensure your SSH key is in `SSH_KEY_PATH` and is authorized on the Protect device. The container copies keys to fix permissions automatically.
- **No recordings found**: Increase `BACKUP_HOURS` or check that the device has active recordings. Only `type=rotating` and `active=false` files are selected.
- **Remux fails**: Verify the `.ubv` file is complete (not still being recorded). The query filters `active=false` to prevent this.
- **Container shows unhealthy**: This is normal until the first successful backup completes. With `RUN_ON_START=true` (the default), this resolves within a few minutes of starting.
- **Disk space**: The backup script logs two levels of disk space warnings that you can use to set up alerts (e.g., Docker log monitoring, webhook, etc.):
  - `[backup] ... WARN: Archive volume has less than 100 GB free` - time to plan cleanup
  - `[backup] ... WARN: CRITICAL: Archive volume has less than 10 GB free` - backups may start failing

  Use `RETENTION_DAYS` and/or `RETENTION_PERCENT` to manage archive size automatically (see [Configuration](#configuration)). Staging is cleaned after each run.
- **Permissions**: The installer needs Docker access and write permissions to the archive path - on most NAS systems you're already root. The container runs as root internally for cron, SSH key handling, and volume writes. It does not expose any ports or accept inbound connections.

## Performance

The backup process has negligible impact on the Protect device. We profiled a CloudKey Gen2+ while backups ran every minute and the device sat at 70-90% CPU idle throughout. The database query finishes so fast it doesn't even register at 10-second sampling intervals, and the SCP file transfer (the heaviest part) briefly uses one core for SSH encryption before dropping back to baseline. Memory, swap, and PostgreSQL activity are unchanged during backups.

The project defaults to AES-128-GCM for SSH encryption, which takes advantage of hardware AES extensions present on CloudKey Gen2+, UCG-Fiber, and likely all current UniFi Protect devices. Peak CPU during transfers is about the same either way (one core doing cipher work), but AES-GCM finishes ~27% faster - so the device spends less total time under load per backup cycle.

See [docs/performance.md](docs/performance.md) for the full profiling data, cipher benchmarks, and methodology.

## Future features

- **Granular retention** - Per-camera and per-channel retention overrides, dry-run mode to preview what would be deleted.
- **Protect device cleanup** - After recordings are safely backed up, optionally remove them from the Protect device (both `.ubv` files and DB rows) to free up space. Off by default, with safety checks and configurable minimum age before cleanup.

See [TODO.md](TODO.md) for details.

## Acknowledgments

This project uses [unifi-protect-remux](https://github.com/petergeneric/unifi-protect-remux) by Peter Wright for converting `.ubv` video files to `.mp4`. The remux binary is licensed under [AGPL-3.0](https://www.gnu.org/licenses/agpl-3.0.html) and is downloaded at build time - see [THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md) for details.

## Related projects

**[unifi-protect-backup](https://github.com/ep1cman/unifi-protect-backup)** by ep1cman is an excellent tool for backing up UniFi Protect event clips in real time via the Protect API. It captures motion events, smart detections (person, vehicle, animal, etc.), and supports rclone backends so you can archive directly to cloud storage. It's well maintained and worth checking out.

The two tools are complementary. ep1cman's tool handles **events**: the clips Protect generates when it detects something. This tool handles the **continuous 24/7 recordings between events** that the Protect API doesn't expose. Together they give you full off-box coverage of everything your cameras record.

Why does that matter? Event-based backup has an inherent blind spot: if Protect's detection doesn't fire (common at night, in low contrast conditions, with unusual angles, or just edge cases where the AI doesn't trigger), that footage never gets exported. It's still on the Protect device's drive, but it's not in your backup. This tool pulls the complete recording history directly from the device regardless of whether an event was generated, so nothing falls through the cracks.

## Also from Ozark Connect

<p align="center">
  <a href="https://github.com/Ozark-Connect/NetworkOptimizer"><img src="https://github.com/Ozark-Connect/NetworkOptimizer/raw/main/docs/images/app-logo-v2.png" alt="Network Optimizer" width="200"></a>
</p>

If you find this useful, check out **[Network Optimizer](https://github.com/Ozark-Connect/NetworkOptimizer)** - a self-hosted UniFi network analysis platform with security auditing, Wi-Fi optimization, LAN speed testing with Layer 2 path tracing, adaptive SQM, coverage mapping, and more.

## Sponsor

If you find this project useful, consider [sponsoring the maintainer](https://github.com/sponsors/tvancott42).

## License

MIT - see [LICENSE](LICENSE) for details.

---

<sub>unvr-nas-backup is an independent project by Ozark Connect and is not affiliated with, endorsed by, or sponsored by Ubiquiti, Inc. Ubiquiti, UniFi, UniFi Protect, UCG, UDM, UDR, UNVR, and Cloud Key are trademarks or registered trademarks of Ubiquiti, Inc. All other trademarks are the property of their respective owners.</sub>
