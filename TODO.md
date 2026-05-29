# TODO

## Granular retention

Basic retention is implemented (`RETENTION_DAYS` and `RETENTION_PERCENT`). Remaining work:

- Per-camera overrides (keep front door longer than backyard)
- Per-channel overrides (shorter retention for low-quality streams)
- Dry-run mode to preview what would be deleted

## Protect device cleanup

After recordings are successfully backed up to the NAS, optionally remove them from the Protect device to free up space. This means deleting both the `.ubv` files from the filesystem and the corresponding rows from the `recordingFiles` table in PostgreSQL.

This is high-risk and must be heavily configurable:

- Off by default (opt-in only)
- Minimum age before cleanup (e.g. only delete recordings older than 7 days)
- Require N successful backup confirmations before deleting the source
- Per-camera enable/disable
- Dry-run mode
- Safety check: never delete if the archive copy fails verification (file size, existence)
- Safety check: never delete recordings newer than a configurable threshold

The main benefit is extending the Protect device's effective recording capacity. Since the remux is just a container copy (not a transcode), the NAS is already doing the heavy lifting. Cleaning up the source device is the natural next step, especially for devices with limited internal storage. If UniFi ever adds native continuous archival with source cleanup, this becomes unnecessary.
