# Development Log

This tool was built iteratively to solve a concrete problem: a Mac whose
**"System Data" had ballooned to roughly 280 GB**, with only ~18 GB of real
free space, and no way to see what was responsible. macOS Storage settings
showed the giant "System Data" bar but offered no breakdown.

What follows is the honest path from "scan and delete the obvious junk" to
"find the actual cause." It's kept here because the dead-ends are instructive —
the obvious explanations were all wrong, and the real one was invisible to the
tools you'd reach for first. Specific personal numbers have been generalized.

## The investigation

1. **It's not the usual caches.** The first version scanned and cleaned the
   well-known spots — `~/Library/Caches`, logs, Trash, Xcode DerivedData,
   device backups, Homebrew/npm caches — with per-item confirmation. On the
   target machine this recovered only ~1.6 GB. The 280 GB was elsewhere.

2. **It's not in any folder.** A full `du` folder scan of the home directory
   plus system roots accounted for only ~170–200 GB of a disk reporting ~390 GB
   used. A large chunk of space simply wasn't in any visible folder.

3. **It's not Time Machine snapshots.** A common cause of inflated "System
   Data" is local APFS/Time Machine snapshots, which `du` can't see. Checking
   `tmutil listlocalsnapshots` found **zero**. Another dead-end.

4. **The volume layer reveals it.** Looking at the APFS *container* with
   `diskutil apfs list` and `df` showed the answer: Xcode stores each
   **simulator runtime** (iOS/watchOS/tvOS) as its **own mounted APFS volume**.
   `du` with `-x` stays on one filesystem, so it had been silently skipping all
   of them. A dozen runtimes across several OS versions were the bulk of the
   mystery space.

5. **Measure it correctly.** An early estimate over-counted by summing the
   *mounted* (sealed, read-only) runtime volumes. Xcode's own
   `simctl runtime list` reports the true on-disk image footprint, which is what
   the tool now uses. Removing the unused older runtimes freed roughly 100 GB on
   the target machine.

## Version history

- **v1 — Quick Clean.** Double-click `.app` (Bash + AppleScript dialogs).
  Scans common cache/junk locations, confirm-per-item deletion. Established the
  safety model: nothing deleted without an explicit click.
- **v2 — Deep Scan.** Added a read-only mode that `du`-walks the disk and
  reports the biggest folders to the Desktop.
- **v3 — Robust system scan.** Privileged scan writes results to a file rather
  than returning huge output through AppleScript (which silently truncated);
  added snapshot/purgeable reporting.
- **v4 — Disk Map + targeted caches.** Added the read-only APFS volume/snapshot
  map (the mode that ultimately cracked the case) and cache categories for
  Chrome/Cursor/Teams/Steam with a strict "recognized cache folders only" guard.
- **v5 — Simulator Runtimes mode.** First cut at listing and removing simulator
  runtimes via `simctl`.
- **v6 — JSON detection.** Switched runtime enumeration to `simctl … -j` JSON
  for resilience across Xcode output formats; added a text fallback.
- **v7 — Real "Disk Images" format.** Modern Xcode lists runtimes as UUID-keyed
  "Disk Images"; parser rewritten to match, deletion by image UUID, sizes taken
  from `sizeBytes`. Corrected the over-counted size estimate.
- **v8 — Bugfix: multi-path payloads.** Cache categories store many folder
  paths; these had been written with embedded newlines, splitting one category
  into dozens of bogus "0 KB" prompts. Switched to a single-line encoding (ASCII
  Unit Separator). Added a **Delete all** fast path to Quick Clean.
- **v9 — Neutral & shareable.** Sim Runtimes now lists **every** installed
  runtime and lets you Skip/Delete each (default Skip) instead of baking in one
  user's platform preferences. Verified no hardcoded paths; generalized docs.

## Lessons

- "System Data" is a catch-all; the space is often on **separate APFS volumes**
  (simulator runtimes, disk images) that folder-size tools skip by design.
- `du -x` deliberately does not cross mount points — invaluable, but it means a
  folder scan alone can never explain a full disk.
- The authoritative view of where space went is the **APFS container**
  (`diskutil apfs list`), not folder sizes.
- Let the platform's own tooling do destructive work where it exists
  (`simctl runtime delete`, `tmutil`) rather than `rm`-ing files blindly.
