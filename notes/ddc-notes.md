# DDC/CI field notes

Findings from a 2026-08 debugging session with two externals on an M4 Max
(each on its own passive DP 1.4 to USB-C cable), plus the defenses Candela
ships as a result. Read this before touching DDCService or chasing a
"brightness slider does nothing" report.

## The stack

- `Candela/Services/DDCService.swift`: raw DDC/CI. On Apple Silicon this is
  IOAVService I2C against DCPAVServiceProxy registry nodes, paired to
  displays by nearest-identity traversal plus vendor/product/serial
  matching. Validates every reply's header AND checksum. Quarantines a
  display's reads after 6 consecutive raw failures (10 min expiry, fresh
  probe window after). The whole display-to-channel map is flushed on any
  display reconfiguration (IDs get reshuffled with no removal event).
- `Candela/Services/BrightnessService.swift`: routing. DDC when it works,
  full-range software gamma when `ddcAvailable` latches false (3
  consecutive failed writes), and full-range software gamma while a
  display is in HDR mode (`hdrDimmedDisplays`, pushed by
  BrightnessBoostService): a DisplayHDR monitor owns its luminance and
  silently discards DDC brightness writes while still acking them.
- `scripts/ddc-probe.swift`: read-only. Lists displays, channels, and
  raw VCP 0x10 replies with header/checksum verdicts. Run this FIRST when
  a slider goes dead; it names the failure in seconds.
- `scripts/ddc-write-probe.swift [aoc|dell] <value ... | burst>`: sends
  real brightness writes (visible on the monitor). `burst` simulates a
  slider drag (61 writes, 50ms pacing).
- `scripts/ddc-stress-probe.swift`: interleaves garbage-channel reads
  with healthy-channel writes/reads, for cross-contamination testing.

## Measured monitor behavior

**AOC Q27G3XMN** (DP, 165Hz): reads are unreliable by design defect.
Publicly documented (blog.szynalski.com/2024/06/aoc-q27g3xmn-review):
roughly half of all DDC commands are randomly ignored, across batches,
with no firmware update path. Observed reply garbage: DDC NULL frames
(`6E 80 ...`), echoes of our own request, repeated single-byte noise,
stale EDID bytes. Reads degrade further under read traffic (clean first
read after power-on, garbage within a few) and occasionally recover.
Writes are reliable except when the controller fully wedges. Treat this
monitor as write-only; that is what the quarantine effectively does.

**Dell U2412M** (DP, portrait): textbook-clean DDC in both directions,
absent from every quirk database. Two quirks anyway: (1) incoming DDC
writes auto-dismiss its OSD menu; (2) app brightness traffic while its
OSD menu is open can wedge its DDC controller completely deaf (no I2C
ack at all): this is what BetterDisplay's "does not support DDC" panel
was showing. Also: it applies each brightness write with an internal
fade, so rapid write streams (long slider drags) visibly flash as each
write restarts the fade. Seen on other Dells too; accepted as a quirk.

## Failure classes and defenses

| Failure | Symptom | Defense |
| --- | --- | --- |
| Garbage reply passes weak validation | Bogus max poisons the write scale; slider saturates partway (100/255 = top 61% dead) | Checksum validation on every reply |
| Read-hammering a fragile controller | Controller degrades into garbage/wedge | Read quarantine, 6 strikes, 10 min expiry |
| Display IDs reshuffled, no removal event | Channel map crossed: each slider drives the OTHER monitor; both look dead | Full map flush on every reconfiguration, identity re-match |
| Channel goes deaf (no ack) | Writes fail cleanly | 3-failure latch to full-range software gamma; recovery on reconnect |
| Monitor in HDR discards DDC writes (still acks) | 15-100% of slider dead, ack-based detection blind | HDR state routes the whole 0-100 range to software gamma |

## Recovery, in order of escalation

1. Open the monitor's OSD menu briefly (documented to wake a stale DDC
   handler; no power cycle needed).
2. Replug the video cable (forces re-enumeration; also clears every
   app-side cache and latch via the reconfiguration path).
3. Pull the monitor's POWER cord ~10s (standby is not enough; the DDC
   controller stays powered). This is the only cure for a fully deaf
   controller, and per ddcutil's tracker even it is not guaranteed.

## Rules of engagement

- Never trust an acked write as proof DDC works; only a checksum-valid
  read proves anything, and some monitors (AOC above) never give one.
- Never let a read result touch the write scale unless it validated.
- Avoid sending brightness from an app while a monitor's OSD menu is
  open when reproducing bugs; on some firmware that collision wedges the
  controller (undocumented anywhere else as of 2026-08).
- ddcutil (Linux) is the richest source of per-monitor DDC quirk
  knowledge: www.ddcutil.com/faq and its GitHub issues.
