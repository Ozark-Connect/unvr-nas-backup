# remux patches

The Docker image builds [unifi-protect-remux](https://github.com/petergeneric/unifi-protect-remux) from source at the commit pinned in the `Dockerfile` (`REMUX_COMMIT`), applies every `*.patch` in this directory with `git apply`, runs the `ubv` crate's unit tests, and builds the `remux` binary.

These patches modify AGPL-3.0-only code and are licensed under AGPL-3.0-only.

## remux-untimed-partition-header.patch

Protect 7.3.53 changed the first record of every `.ubv` file. Upstream remux (v4.2.2 and `main` as of 2026-09-30) can't read these files: it reports `Tracks: 0, Frames: 0` and writes no `.mp4`.

Before 7.3.53, a file starts with a partition header (track `0x0009`) that has a timestamp:

```
a0 00 09 a9  f9 02 00 00  0d 51 3f 37  00 00 00 20  <32 bytes>  ...
tag          fmt   seq    DTS          SIZE=32
```

Since 7.3.53, the partition header is untimed:

```
a0 00 09 a9  f1 00 00 00  00 00 00 14  <20 bytes>  00 00 00 20
tag          fmt   seq    SIZE=20                  BACK_SIZE=32
```

Format byte `0xF1` has bit 3 (clock rate present) clear, and sample rate index 0, so there is no DTS field. Upstream always reads a DTS field. It then reads the start of the payload as `SIZE=0`, lands on a zero byte at offset `0x14`, and treats that as end-of-file before it reaches any video records. The rest of the file (clock sync, then video frames) uses the old record layout.

The patch adds `FormatCode::has_dts()`, which returns false only when bit 3 is clear and the sample rate index is 0. `header_len()` and `read_record()` skip the DTS field for those records. Every format code seen in older files (`ED0C`, `CD0C`, `F902`, `FD0C`, `FD02`, `FD0A`, `FD06`) sets bit 3, so older files parse as before. Unit tests cover both cases, including the first two records of a real 7.3.70 file.

Remove this patch once an upstream release handles the new header, and bump `REMUX_COMMIT`.
