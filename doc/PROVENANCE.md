# Provenance — what was read, what stands in the way, the name

*2026-09-12. The assessment memo is `softanza/memos/2026-09-12.md`
(stamp 11:02); this file is its repository-side record.*

## What was read before a line was written

- The Vision Corpus (`softanza/vision/01..06`) and the memos
  2026-08-29 → 09-12, the Ring++ design charter and the S3 decision.
- `ringpp/CLAUDE.md`, `docs/DESIGN_BUILD.md`, `docs/BUILD-OPTIONS.md`,
  `docs/SIBLINGS.md` — Ring++ is a sovereign register VM and compiler in
  Zig; Haro is its destination; bare metal is MicroRing's by design.
- `microring/` — the device runtime: tiers, the Zig substrate, "not an
  RTOS", the gpio-sim proof, the Ed25519 identity finding.
- `restolean/livrable/makeen/` — the Makeen box, MakeenOS as "a posture,
  never a marriage", the B9 verdict to enslave commodity Android.
- `stzlib/libraries/stzlib/base/system` and
  `base/doc/design/SOFTANZA_SYSTEM_FOUNDATION.md` — the OS model as a
  virtual twin, complete, 335 assertions.
- `zin/doc/vision/ZIN_OS_VISION_v1_0.md`,
  `zin/doc/architecture/ZINOS_ARCHITECTURE_v1_0.md`,
  `zin/doc/design/ZINOS_EDGE_DESIGN.md`, `ZIN_AGENTIC_OS.md`,
  `zin/doc/vision/ZIN_HARDWARE_VISION_v1_0.md`, the Zos pillar spec.
- Omarchy (basecamp/omarchy), adios (adityarajIITj/adios), Arch Linux.

## Three standing refusals the OS turn reverses or must live beside

| where | ruling | this repository's stance |
|---|---|---|
| `ringpp/docs/DESIGN_BUILD.md:226` | bare-metal DROPPED from Ring++'s brief | kept: the edge profile is MicroRing's, `stzos init` refuses it by name |
| `microring/docs/vision.md` §3 | "Not an RTOS" | kept: the loop is the scheduler; the edge kernel, if ever, follows ZinOS Edge's cooperative design |
| `restolean/livrable/makeen/B9-LE-MATCH.md` | enslave commodity Android; MakeenOS a posture, no custom box | partly reversed: the hosted profile declares the box; whether a box ships is the author's ruling, not this repository's |

Each reversal is the author's to make by name (STZ-OS-REVERSALS-01 in
the memo). This repository builds the mechanism either way.

## The name

`stzos` — chosen 2026-09-12 by the session on the author's instruction
to choose, under the estate's registers: `stz` is the distribution, the
suffix says which floor. It is PROVISIONAL: the author said the
landscape's final shape, structure and naming are decided at a later
critical point. Names already in the estate for adjacent things, so the
ruling can be one-meaning-per-word:

- **ZinOS** — zin's May 2026 OS (Edge + Touch); its designs are this
  repository's donors for two of the three profiles.
- **Zos** — zin's pillar 19, Platform Capabilities ("declares what the
  platform IS") — the same idea as `DEFINE MACHINE`, at zin's altitude.
- **MakeenOS** — RestoLean's posture over a host OS; the hosted profile
  is what would make it real.
- **Device** — the L2 language (ex-MicroRing's seam); PIN here is its
  first seat, and the two must converge or one must yield.

## What this repository is NOT

Not a kernel project. Not a distribution of packages. Not a fork of
Arch or Omarchy. Not a product. It is the mechanism by which a machine
becomes a declared, judged, narrated world — the capability line of the
rule of three; the projection (stzp) and the experience (commercial)
stay outside.
