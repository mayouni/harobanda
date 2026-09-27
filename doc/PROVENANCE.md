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
| `ringpp/docs/DESIGN_BUILD.md:226` | bare-metal DROPPED from Ring++'s brief | kept: the edge profile is MicroRing's, `harb init` refuses it by name |
| `microring/docs/vision.md` §3 | "Not an RTOS" | kept: the loop is the scheduler; the edge kernel, if ever, follows ZinOS Edge's cooperative design |
| `restolean/livrable/makeen/B9-LE-MATCH.md` | enslave commodity Android; MakeenOS a posture, no custom box | partly reversed: the hosted profile declares the box; whether a box ships is the author's ruling, not this repository's |

Each reversal is the author's to make by name (STZ-OS-REVERSALS-01 in
the memo). This repository builds the mechanism either way.

## The name

**Harobanda** is the system. **`harb`** is what you type. **`harobanda`**
is the repository, its GitHub name and its directory. Ruled by the author
on 2026-09-20 — STZ-OS-RULING-02 below — replacing the provisional
`stzos` recorded underneath.

Harobanda is the bridge across the Niger at Niamey, which joins the two
banks of the city; the machine joins a solution's promises to the
hardware that keeps them. The one-meaning-per-word discipline now has to
hold across three words rather than one, because a rename is where it is
most easily lost: a sentence about the SYSTEM says Harobanda, a sentence
about what a reader TYPES says `harb`, and a path says `harobanda`. They
are not interchangeable, and `experiment/PROTOCOL.md` under NAME-1 says
what it cost to learn that.

The `STZ-OS-` prefix on the ruling ids does NOT change. It names the
register the ruling was issued under — the estate's — not this
repository, and the estate's memos cite those ids by name.

### As first chosen, 2026-09-12 — superseded, kept as the record

`stzos` — chosen 2026-09-12 by the session on the author's instruction
to choose, under the estate's registers: `stz` is the distribution, the
suffix says which floor. It was PROVISIONAL: the author said the
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

## The rulings of 2026-09-27 (taken on the author's behalf, at his word)

The author delegated what waited on him: *"do what waits on me on my
behalf."* Ruled, each open to his reversal -- and one row left for him
with its reason, and two acts no delegation reaches.

**STZ-OS-RULING-03 — retirement, as built at RET-1.** Its three open
choices confirmed. A declaration of its own, `DEFINE RETIREMENT`, and not
a clause on the member, because each retirement must say WHY: a card
that failed and a card that went missing are the same mechanism and
different stories. The word *retirement*, not *revocation*: revocation
promises the key is dead, and what the fleet can say is how far it is
still trusted. And a record that never reaches the head is refused even
when every entry in it verifies, because a shorter record and a chain
the key's holder wrote since cannot be told apart.

**STZ-OS-RULING-04 — the mirror.** `vendor/PIN.md` routed this errand to
the author because it "needs storage he picks". Picked: a release on
this repository, `vendor-mirror-2026-09-27`, private while the
repository is. It carries the kernel, the Linux Zig and the Pi firmware,
each verified against its pin before it left this machine, and a
`SHA256SUMS`; the pins in git stay the authority. It was judged by what
CONSUMES a mirror -- a restore: downloaded whole into scratch, every file
checked against the mirror's list and the two tarballs against the
digests git pins, all four OK. Integrity was already ours; availability
is now ours too, for as long as the account is.

**STZ-OS-RULING-05 — the licence: MIT, (c) 2026 Mansour Ayouni.** The
licence every code repository of the estate that carries one already
carries -- stzlib, Ring++, MicroRing, zin; a floor with its own would be
a second answer to one question. `LICENSE` says what it covers and what
it does not: a machine is built from Linux, which is GPL-2.0 and is
fetched and pinned, never contained here, and an IMAGE that carries the
kernel carries the kernel's obligations. Adding it changes nothing about
who can read the repository.

**STZ-OS-RULING-06 — everywhere has one spelling.** EGR-2 left open
whether the grammar should refuse the explicit spelling of an
unrestricted reach. Refused: a list of EGRESS destinations is a
perimeter, and one whose destinations together cover every address is
refused however it is spelled -- `0.0.0.0/0`, `10.0.0.0/0`, or
`0.0.0.0/1` with `128.0.0.0/1`. A machine that may go anywhere says so
by declaring no EGRESS at all. Ruling it found a live defect: EGR-2's
fix looked for a prefix of 0, and printed "and nowhere else" over the
two-piece spelling while the machine reached 8.8.8.8 (EGR-3 in
`experiment/PROTOCOL.md`).

**STZ-OS-RULING-07 — where the trust in time comes from.** Time is
ATTESTED, never assumed.
1. The floor's journal stays clock-free. The sequence is the order, and
   a time nothing attests is the epoch wearing a date's authority
   (JRN-1).
2. A time enters a record only as a signed statement bound to a chain
   head -- "the chain ending at H existed no later than T" -- made by a
   time authority the fleet DECLARES and enrolls like any member, so it
   is checked the way every record is: with a public key, holding no
   secret, by anyone who has the fleet file (FLT-1).
3. What that authority stands on is its own declaration: a
   battery-backed clock declared as hardware, or AUTHENTICATED network
   time (NTS, RFC 8915) through a declared EGRESS -- never plain NTP,
   which is a claim the wire makes about itself.
4. A machine with no declared source says its records are ORDERED and
   UNDATED, in those words, rather than print a date it cannot stand
   behind.

For the Makeen box, `EGRESS none` turns the consequence into hardware: a
clock module the box declares, or a member of its fleet that has one. A
till's business records need dates -- the world's to keep, the floor's to
make trustworthy -- so this is the box's next hardware question after
the board itself. The mechanism is a seat, not built.

**STZ-OS-RULING-08 — chapter 07 ratified; 06 and 08 left for the
author.** `softanza/vision/07-SYSTEM.md`, the floor's own chapter, is
ratified in session by delegation. What it asks is the direction the
author has ordered for two weeks: that the floor is part of the vision,
that it is built by the kernel act and judged by the court, and that
sovereignty there means what it means everywhere else. Its facts carry
Amended blocks where they have moved (the name), and every chapter that
named the floor `stzos` carries one beside it.

Chapters 06 and 08 are NOT ratified on his behalf, and not for want of
reading them. 06 holds a choice on which his own proposal and the draft
disagree -- **X or A** for the algorithm letter; the draft counter-
proposes A because X collides with `stzx`, the external door -- and its
ratification starts a rename across four runtimes and three
repositories this session does not work in. 08 draws the alphabet with
A in it and hands adaptations to fifteen other works, so it cannot be
ratified apart from 06. Both wait on that one word.

*Amended 2026-09-27, later: the author ruled A ("go with A"). The
sentence above overstated what one word frees. 06 also carries the N
proposal seam and the zin-register question, and ratifying it gives the
go for the ZQL -> Z rename in three repositories; 08 follows 06. Both
remain drafts, and ratifying 06 is the author's.* *Ratified by him the
same day, as drafted; the go is routed through Central; 08 is no longer
blocked and awaits his word.* *And 08 ratified by him the same day: every
chapter of the corpus is ratified.* *Amended again: the go was NOT routed
by what this desk wrote -- a line in dashboard/CONCLUSIONS.md is a log Central records, not a channel it routes from, and this desk was never adopted into protocol/REPOS.md, so Central could not see it at all. Checked at the author's
request and found still waiting; relayed to Central's live session
directly, 2026-09-27 05:49, with his go to route it and to ADOPT this desk.*

**Not done on anyone's word.** The board's kit (`STZ-OS-HARDWARE-01`) is
a purchase, and physical. *Amended 2026-09-27: PUBLISHED on the author's
word the same day, after two findings put to him first -- his address is
the author of every commit (kept, his choice; this repository's future
commits use his GitHub noreply address), and the mirror's firmware needed
its licence to travel with it (LICENCE.broadcom attached before the
release went public). Verified from outside with no credentials.*
Publishing the repository, private to public,
was held by the author on 2026-09-20; it is PREPARED -- the licence is
in, and no secret, key or personal address was found in any tracked file
or in any of the 142 commits of its history -- and not done, because a
copy made public cannot be recalled from the caches that take it. It
waits on his yes.

## The ruling of 2026-09-20

**STZ-OS-RULING-02 — Harobanda, and `harb` as the command.** The author
ruled the landscape point that STZ-OS-RULING-01 deferred: *"you must
rename everything harobanda instead of stzos, including the repo name,
and use harb effectively as a command."*

What each name now covers, and what settled it:

| the name | what it names | judged by |
|---|---|---|
| **Harobanda** | the system, in every sentence a reader reads | the docs and `site/` |
| **`harb`** | the binary, the command, the in-image `/harb`, the kernel cmdline namespace `harb.slot`/`harb.expect`/`harb.watchdog` | `zig build court`, `harb learn --check`, the boot transcripts |
| **`harobanda`** | the repository, its GitHub name, its directory | every absolute path in the tour and the scripts |

Two things this ruling does NOT do. It does not rewrite the record of
STZ-OS-RULING-01, which chose `stzos` and is kept above as what was
ruled on the day. And it does not touch the `STZ-OS-` ruling ids, which
name the issuing register.

The machines' `.expected` files were re-pinned by this rename: every one
of them carries the machine's own words, and the machine now says
`harb`. A pin is a claim that what happened was right (SYS-1), so the
claim was settled by booting `qemu_hello` and reading the diff, not by
the rename script's say-so.

*Amended 2026-09-26 (RET-1): that sentence was true of ONE pin and read
as true of fourteen. `qemu_hello` keeps no journal, so its boot never
ran the line the rename had corrupted and never printed a declaration
digest. When the fleet arc was next run, four things surfaced that the
rename had left: three pins naming the pre-rename machine files
(`fleet.expected`, `fleet_temoin.expected`, `qemu_identity.expected` --
the digest of a file whose `RUN ["/stzos", ...]` became `RUN ["/harb",
...]`), one byte lost from `experiment/os2_image.sh`, and the machine
grammar's own `PINNING.md`, which named the file as it stood before the
rename. All five were settled by booting and reading each diff, and are
recorded under RET-1 and PIN-1 in `experiment/PROTOCOL.md`. The pins the
rename touched that no boot has settled since -- `qemu_budget`,
`qemu_confine`, `qemu_egress`, `names`, `makeen_box`, `makeen_qemu` --
carry no digest and changed only in text; they are claims until booted.*

*Settled 2026-09-27: all six booted and matched their pins unchanged
(EGR-3). The rename is now booted everywhere it touched.*

## The rulings of 2026-09-12 (taken on the author's behalf, at his word)

The author delegated the three waiting rows to the session
("take decision on my behalf"). Ruled, and open to his reversal:

**STZ-OS-RULING-01 — the name.** `stzos` stands, for the repository and
the binary, until the landscape ruling; it names THE FLOOR, one word
for one thing. *Amended 2026-09-20 by STZ-OS-RULING-02: the landscape
ruling came, and the name is Harobanda. The sentence above is kept as
what was ruled on the day, not as what is true now.* The adjacent names
resolve so:
- **ZinOS** is retired as a name; its two profiles live on as the edge
  and touch profiles of a `.machine`, and zin's documents are their
  donors. Zin's product story keeps "the device is the job" — that is
  experience, not a second OS.
- **Zos** (zin's pillar 19, platform facts declared) stays zin's, at
  zin's altitude: a Zos declaration describes the platform an
  organization is deployed on; a `.machine` declares the machine
  itself. Different word, different thing.
- **MakeenOS** is retired as a name: the posture became a declaration,
  `machines/makeen_box.machine`. RestoLean's guarantee sheet is what
  that file's fixtures will judge.
- **Device** (the L2 language, ex-MicroRing's seam) keeps the pins. The
  PIN kind of `.machine` is provisional: when Device is declared in
  stzu, a `.machine` names the Device it carries and Device declares
  the peripherals. One language per altitude.

**STZ-OS-REVERSALS-01 — the three refusals.**
- Ring++ bare-metal dropped: **KEPT.** Ring++ stays Linux-class; the
  edge profile is MicroRing's substrate; this repository never asks
  Ring++ for a freestanding target.
- MicroRing "Not an RTOS": **KEPT.** The loop is the scheduler; an edge
  kernel, if ever, is ZinOS Edge's cooperative design written in
  MicroRing's repository.
- RestoLean B9 "asservir; MakeenOS a posture; no custom box":
  **REVERSED IN ONE CLAUSE ONLY.** The box exists — as a declared,
  imaged machine on COMMODITY aarch64 hardware (B9's own demoted
  OpenWrt-class €100 board, "never designed by us"), never a custom
  PCB. Phones stay enslaved commodity Android (the touch profile). The
  posture did not lose; it gained a file.

**STZ-OS-BOARD-01 — the board (ruled on the author's delegation, OS-4).**
The Makeen box is a **Raspberry Pi 4 Model B**. Because: mainline Linux
6.12 carries its device tree (`bcm2711-rpi-4-b.dts`) and every driver the
box needs (SD via sdhci-iproc, Ethernet via bcmgenet, the mini-UART, the
watchdog that restarts it), so the vendored kernel boots it with no
vendor tree; QEMU 10.2 emulates the same board (`raspi4b`) with an SD
card, so the flashable image is judged before the hardware arrives;
MicroRing's tier 1 already runs on the Pi, so the device seam converges;
it is a commodity board sold everywhere the estate's customers are, at
B9's price, and exactly B9's "never designed by us". What is borrowed
with it: the board's boot firmware (`start4.elf`, `fixup4.dat`, a vendor
blob pinned by digest, not shipped in the repository) and the SoC. The
Wi-Fi firmware is a second blob and is NOT taken: the box speaks
Ethernet. A later board changes one entry in `src/image.zig`'s target
table and one BOARD word in the machine file; the declaration otherwise
stands.

**STZ-OS-REGISTER-01 — registration with Central.** A mailbox
(`softanza/mailbox/harb.md`) opened in the estate's format; the
CLAUDE-BLOCK re-stamp (`central.ps1 -Install`) is Central's own act at
its next fold, not this session's.

## What this repository is NOT

Not a kernel project. Not a distribution of packages. Not a fork of
Arch or Omarchy. Not a product. It is the mechanism by which a machine
becomes a declared, judged, narrated world — the capability line of the
rule of three; the projection (stzp) and the experience (commercial)
stay outside.
