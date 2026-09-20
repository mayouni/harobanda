# The Declared Machine — the OS chapter

*Proposed as 07-SYSTEM of the Vision Corpus. Provenance: the author's
ruling of 2026-09-12 (push the sovereign vertical below Ring++ to the
operating system, then MicroRing, then the PCB); the memo of
2026-09-12 11:02 in softanza/memos; zin's ZinOS and Zhw documents of
May 2026; stzlib's System Foundation of July 2026. Unratified until the
author says so.*

## The act, one floor down

The kernel of the Softanza vision is one generative act: DECLARE A
LANGUAGE. Everything above the hardware is a declared world — an
application is "a living world of meaning", a constellation is a
governed set of worlds, an organization is a federation under a
constitution. What was never declared is the floor those worlds stand
on: the machine. It was borrowed — a Linux someone else configures, an
Android someone else governs, a box someone else designs — and every
borrowed floor is a decision the estate does not own.

The OS chapter says: **the machine is a declared world too.** Its
language is small and closed. Its sentences are a profile, the
capabilities it grants and refuses, its mounts, its pins, the services
it keeps alive. It is judged by fixtures before it boots, its boot is a
plan before it is an act, and the act narrates itself as a transcript.
The family sentence gains one clause: *YOU write your language in stzu,
stzf forges it, stzr runs it, stzp projects it, stzx reaches out — all
on stzg, all judged — stzn narrates it back,* **and the machine it all
runs on is declared the same way.**

## What an operating system is, in Softanza's terms

Not a kernel. A kernel is one dependency among several, decided like
every other. The operating system is **the declared envelope a world
runs inside**: which effects the world may have (stzlib's
`stzSystemCapabilities`, nine names on a four-kind lattice), what
storage and pins it sees, which processes exist and in what order, what
happens when one dies. stzlib built this envelope in July 2026 as a
VIRTUAL TWIN — `stzSystemProfile`, `stzSystemScope`, `stzVirtualSystem`,
`stzSystemActor`, the `.stzsystem` and `.stzplatform` files — and stated
its law: rehearse, plan, commit; "there is no wire to cut, because no
wire was ever laid." The twin was written so that an agent could not
hurt the machine it runs on. Harobanda is the same envelope one floor down:
the twin's declaration becomes the machine's declaration, the update
plan becomes the boot plan, and the commit becomes PID 1.

## The rule of three lines, applied

- **CAPABILITY — open, in Harobanda**: the machine language, the court, the
  planner, the init, the image builder. Mechanisms with conformance, no
  delivery opinion.
- **PROJECTION — open, stzp**: a declared machine projected to a
  profile — a hosted image (the counter box), an edge firmware (the
  sensor), a touch build (the phone). The same declaration, three
  substrates; the projector decides nothing the declaration did not say.
- **EXPERIENCE — commercial**: the device that IS the job (zin's phrase):
  no app drawer, one pack, PIN per shift, the fleet governed by the
  constitution, the box that a restaurant plugs in and forgets. Softanza
  Studio's device lens; zin's OS agents (fleet health, rollout, HACCP
  evidence) as the commercial layer over the open mechanism.

## Three profiles, one language

**Hosted** — a vendored Linux kernel rebuilt by our toolchain, a static
musl userland of exactly two binaries (harb as PID 1, stzr as the
runtime), the declared services, nothing else: no shell, no package
manager, no init scripts, no service manager. This is the Omarchy
lesson taken to its end: Omarchy owns the experience of an operating
system with zero kernel lines by DECLARING an opinionated system over
Arch; it does so in bash, imperatively, with no court. The hosted
profile declares the system in a closed language, judges it, rehearses
it, and commits it — Omarchy with a court, and without the shell.

**Edge** — no kernel: the binary is the device. ZinOS Edge's design of
May 2026 (a cooperative tick loop, no preemption, no heap after boot,
comptime board selection, atomic A/B updates) on MicroRing's substrate
(MicroZig, littlefs, the RP2350 "heart of the project"). MicroRing's
refusal "not an RTOS" stands and is compatible: the loop is the
scheduler. The same `.machine` file declares it; only the projection
differs.

**Touch** — Android's kernel, drivers and telephony kept (writing phone
drivers is a decade; LightOS, Graphene and Calyx all forked AOSP),
everything above the HAL replaced: the launcher is the pack. ZinOS
Touch's design, kept whole.

## Sovereignty, decided per dependency

Sovereignty in this estate has one meaning: **nothing anyone else can
withdraw.** It has never meant "every line is ours." Ring++ kept Ring
1.27's VM as vendored source rebuilt by zig and used it as the oracle;
the machine keeps the Linux kernel the same way. Each dependency gets a
verdict — keep vendored, own, borrow, none — and the table lives in
`ARCHITECTURE.md`. A kernel is written where no Linux fits (a
Cortex-M4), and nowhere else. adios is the counter-example kept
visible: a from-scratch kernel, scheduler, memory manager and
compositor, all running as a Python simulation, whose author had to
audit which claims were modeled and which verified. Bangalo would
convict it. Its one good idea — the whole machine boots in an emulator
before any board — is this repository's court.

## The court, at the machine's altitude

- **fixtures** judge the language (pinned, sha256, rejects carrying the
  fragment their refusal must contain);
- **the plan** judges the declaration before any act (order, granted
  set, implicit mounts);
- **the transcript** judges the boot — a machine that boots differently
  prints differently; the emulator (QEMU for hosted, the vendored board
  simulator for edge) runs it before a board does;
- **contracts C1–C9** still judge the foundation the services run on;
- **zin's constitution** judges the fleet; **refine's gate** judges the
  change to a machine (a migration is a governed refinement, never a
  shell script — Omarchy's `migrations/` directory, judged);
- **Bangalo** judges the building minds, this one included.

## What is refused, by design

- No shell on the boot path, and no clause that could put one there.
- No package manager: what a machine runs is its closed SERVICE list,
  shipped in the image; the pack registry (registry.json, no server,
  PR-as-review — ringscript-registry's design) is how declarations
  travel, not how machines mutate at run time.
- No configuration drift: the machine is its file; a change is a new
  image through refine's gate, applied atomically (A/B), rolled back by
  watchdog.
- No monorepo: Harobanda stays a thin repository consuming stz; products
  (the Studio's device lens, the fleet agents) stay out of it.

## The ladder below

The Device language (ex-MicroRing's seam, already in L2) declares
peripherals; a PIN here is its first seat. A PCB is a projection of a
Device declaration — a netlist is declarable, and stzlib's DN5 electric
drawing notation already renders schematics. zin's Zhw vision goes one
floor further (declared peripherals to synthesized silicon, comptime to
Verilog). None of that is built; all of it is the same act repeated:
declare, judge, project, narrate.

## What is real today (2026-09-12, evening)

The machine language v0.1 with 40 pinned fixtures, declared in stzu and
accepted by stz's meta-court; a boot plan derived and rendered; one
static binary for the host and for two Linux targets. Two declared
machines boot in QEMU over a vendored Linux 6.12 LTS pinned by digest:
`qemu_hello` on x86_64, and `makeen_qemu` — the Makeen box as the
emulator carries it — on aarch64 with a persistent ext4 partition
mounted by PID 1 before any world spoke, and the kitchen-display and
counter worlds run by stzr, the Softanza runtime, inside the image. Each
boot's serial transcript is judged line for line against a pinned
expectation. What remains between this and a box on a counter is a
board: its kernel config, its bootloader, its SD card, and the A/B
slots that make an update a governed refinement rather than a risk.
