# seL4 beside the floor — a study

*Written 2026-11-13 on the author's word: "Study this alternative kernel
and what it can fit and add to Harobanda". Read that day: sel4.systems
(home, "How to use seL4", the roadmap, the licence page),
docs.sel4.systems (verified configurations, supported platforms) and the
Microkit manual on GitHub, at seL4 17.0.0 and Microkit 2.4.0, both
released 2026-10-30. Nothing was built or run for this study: every
sentence about seL4 is what its own pages say, and every sentence about
Harobanda is what this repository holds. It proposes; it rules nothing.*

## 1. What seL4 is, in plain terms

seL4 is a **microkernel**: the one program that runs with the
processor's full privilege, kept as small as a kernel can be. It
does four things — it separates programs' memory, it schedules them, it
lets them send each other messages, and it hands out **capabilities**:
unforgeable tokens, each naming one kernel object and what its holder
may do with it. A program can touch nothing it holds no capability for.

Everything else — disk drivers, the network stack, file systems — runs
as ordinary unprivileged programs. seL4's own pages say it: "seL4 is a
microkernel, it is not an operating system."

What makes it unique is a **machine-checked mathematical proof** (in the
Isabelle/HOL prover, published beside the code) that the C code does
exactly what its specification says, and, on some platforms, that the
compiled binary does too, and that the kernel enforces integrity (a
program cannot change what it holds no capability to) and
confidentiality (it cannot learn it either).

## 2. What is proven, and where — read from its own tables

| platform | what the proof covers |
|---|---|
| **Raspberry Pi 4B** (and seventeen other 64-bit Arm boards) | the C code is correct; integrity; confidentiality; the kernel runs as a **hypervisor**, so it can run Linux as a guest |
| 32-bit Arm (Pi 3, BeagleBone, ...) | all of the above, plus the compiled binary, plus the program that starts the system |
| 64-bit RISC-V boards | the C code is correct; integrity; confidentiality |
| **the PC (x86-64)** | the C code is correct — and no more; running a guest (VT-x) is outside the proven configuration |

And what its pages say no proof covers today, on any platform:

- the kernel's own start-up at boot;
- device address translation (the IOMMU);
- **several cores at once** — the multi-core proof is on the roadmap
  for the third quarter of 2028;
- **the real-time scheduling extensions (MCS)**, budgets and periods
  held by the kernel — proven on RISC-V, due on 64-bit Arm in the third
  quarter of 2027.

The proof is about the kernel. A system built on it is proven only as
far as its own components are small enough to be.

## 3. The tool that matters most here: the Microkit

The Microkit is seL4's framework for **statically structured systems**.
Its manual's words: "The system is described in a declarative
configuration file, and the Microkit tool takes this system description
as an input and produces an appropriate system image."

Its vocabulary, beside ours:

| Microkit | what it is | Harobanda's nearest word |
|---|---|---|
| system description | one file that lists every component and every connection; the tool builds the image from it | the `.machine` file |
| protection domain (at most 63) | one isolated program with its own memory | a world (`SERVICE`) |
| memory region | a named piece of memory, mapped only into the domains the file says | `MEMORY`, `STATE`, `SEES` |
| channel | a declared connection between two domains; no channel, no communication | no word yet — worlds meet through a network or a disk |
| budget and period | "the budget specifies the amount of time for which the PD is allowed to execute ... replenishment happens once every period" | `RUNTIME` and `PERIOD` (TIM-1) |
| virtual machine | a guest operating system run inside one domain | no word: `doc/CLOUD.md` says "No hypervisor in the product" |

It builds for `rpi4b_1gb` .. `rpi4b_8gb`, `x86_64_generic`, and
`qemu_virt_aarch64` — the emulator this desk already runs.

## 4. Where the two designs already agree

This is the finding that matters: **seL4's method and Harobanda's are
the same method at two depths.**

- **Declared, then built from the declaration.** Both write the whole
  system in one closed file and derive the image from it. Neither has a
  shell that changes the system afterwards.
- **What was not asked for is not given.** Harobanda derives a world's
  walls from `NEEDS` (NS-1). seL4 gives a program only the capabilities
  the description names.
- **"The architecture you designed is the architecture that is
  running."** That is seL4's sentence for its proven start-up program.
  Harobanda's is the boot compared line by line with its expectation
  (JDG-1).
- **Time is given, never taken.** A Microkit budget and period is the
  reservation of TIM-1, and PRI-1's rule — no program raises its own
  priority — is how seL4 treats time from the start.
- **A claim is published at its true size.** seL4's table of which
  platform has which proof, and its list of what no proof covers, is
  this repository's "named seams".

The difference is **who holds the walls**. Harobanda's walls are held by
the Linux kernel: a very large program, tested and never proven, where
one kernel flaw can let a world out of every wall at once. seL4's walls
are held by a small kernel with a proof.

## 5. What it could add — four fits, smallest first

### Fit A — borrow the method, take no code

Costs nothing and stands on its own.

- **A `CHANNEL` between two worlds.** Today two worlds on one machine
  talk through the loopback network or a shared disk, and the open seam
  "a directory two worlds share" is not built. Microkit's answer — a
  connection is declared between exactly two named parties, or it does
  not exist — is the shape to build it in, on Linux, with a socket pair
  PID 1 hands to both.
- **A proof column in the guarantees sheet.** `harb guarantees` says
  KEPT or not. seL4's table adds one more honest word: by what a promise
  is held — tested, measured, or proven.

### Fit B — a guard under the Linux machine (the strongest fit)

seL4 runs as the hypervisor on the Pi 4; **the Harobanda machine,
unchanged, is its guest**; and beside it sit a few small native
components that Linux cannot reach, each closing a seam this repository
already names:

| native component | the named seam it closes |
|---|---|
| **the key keeper**: holds the device's secret key and signs journal entries on request | the boot line says "custody a file at /data/device.key" (IDN-1). A flaw in Linux reads that file, and the fleet, the mirror, the roll and the time statements all rest on that key. Held outside Linux, a compromised Linux can ask for a signature and can never copy the key |
| **the packet filter**: every packet in or out of the guest passes through it | "A packet filter is a named seam, never claimed" (EGR-1): today `EGRESS` writes the routing table -- "the machine knows no way there; it is not prevented from finding one". A filter outside Linux cannot be bypassed from inside it |
| **the watcher**: feeds the hardware watchdog, and holds the safe state | "PID 1's quarter-second loop cannot stop a motor" (the real-time ladder, rung 4), and WDG-1 was a world holding the watchdog. Outside Linux, no world can hold it, and the watcher's loop is short enough to bound |
| **the record keeper**: appends the journal to storage Linux can read and not rewrite | "Inalterability is that a change cannot go unnoticed, not that a file cannot be changed" (JRN-1). This makes the second half true as well |

This is seL4's own "cyber retrofit" path: first the whole existing
system as one guest, which adds nothing, then one component at a time
moved out of it.

What it costs: a second kernel under the first. That touches two
sentences this repository holds — "no second kernel"
(`doc/REALTIME.md`) and "No hypervisor in the product"
(`doc/CLOUD.md`). Both were written against a different thing (an RTOS
beside Linux; virtual machines rented to tenants), and both are the
author's to reopen by name, never this desk's.

### Fit C — a fourth projection of the same file

`harb project` already turns an edge machine into another substrate's
input. The same act could turn a `.machine` into a Microkit system
description: a `SERVICE` becomes a protection domain, `MEMORY` a
region, `PERIOD` and `RUNTIME` a period and a budget, a `CHANNEL` a
channel. The court stays the judge before the build, and the Microkit
tool is the consumer that judges the generated file (PRJ-2).

What it costs is everything above the kernel. A native seL4 program has
no files, no sockets and no Linux system calls unless a component
provides them. `harb` as PID 1, the Haro runtime, Caddy and the
application server are all Linux programs. So Fit C serves only
programs written for it — small, critical ones — which is why it comes
after Fit B and not instead of it.

### Fit D — the body's brain on one board

The real-time ladder needs two boards for a robot: a hosted brain and a
microcontroller body, because "no worst-case analysis of the Linux
kernel exists" (`doc/REALTIME.md`). With seL4 under Linux, a
hard-real-time loop can run as a native component **on the brain's own
board**, with a budget and a period the kernel holds, beside the Linux
guest that cannot delay it. It does not replace the microcontroller
for pulse-exact work, and its proof on the Pi 4 is not due before the
third quarter of 2027; until then it is measured, like TCK-1.

## 6. What it does not give — read before any promise

- **It is not a replacement for the hosted profile's kernel.** No
  Linux drivers, no file system, no network stack of its own. Its
  driver framework and the operating system built on the Microkit
  (LionsOS) are, in the roadmap's words, "ongoing research &
  development".
- **The PC gets the least.** On x86-64 the proof is correctness only,
  and running a guest is outside it. Fit B is a Pi 4 story first —
  which is the board OS-5 already names, and that board is not here.
- **Several cores are not in the proof.** The roadmap dates the
  multi-core proof to 2028, so `CORES 2` under a proven kernel waits
  for it. (How many cores the proven Pi 4 configuration runs today was
  not read on a page for this study; it is the first thing step 1
  below reads.)
- **The guest stays unproven.** Linux under seL4 has exactly the flaws
  it has today. What changes is what a flaw can reach.
- **The proof does not cover the boot.** The judged boot keeps its job.
- **The licence fits.** The kernel is GPL version 2, as Linux is, and
  its licence page says the clause "stops at the kernel/user code
  boundary". It would be vendored and pinned by digest like the kernel
  we keep; nothing in it can be withdrawn.

## 7. Verdict

Linux stays the hosted kernel: `doc/VISION.md` says "a kernel is
written where no Linux fits, and nowhere else", and seL4 does not
change where Linux fits.

seL4 is the first kernel studied here that **fits under** the floor
without replacing it, and it would let Harobanda say of four things —
the device key, the packet filter, the watchdog and the record — a
sentence it cannot say today: *no flaw in Linux reaches this.* On the
Pi 4, that sentence would rest on a proof.

## 8. A way to find out, in the order things depend on each other

Each step ends with something judged; none is started by this study.

1. **The first boot.** The Microkit kit in WSL, one hello-world domain
   on `qemu_virt_aarch64`, its transcript pinned like any machine's.
   Shows the tool runs on this desk and what a build costs in minutes
   and memory. Needs one download, which is the author's to allow.
2. **The projection.** `harb project` writes a system description from
   a two-world `.machine`; the Microkit tool accepts it or the
   projection is wrong.
3. **The guest.** A pinned Harobanda machine (`qemu_egress`, which runs
   only `harb`) boots as a guest and prints the transcript its pin
   already holds — the same boot, judged the same, with a proven kernel
   beneath it.
4. **The key keeper.** The first native component: the boot line's
   "custody a file" becomes custody outside the guest, and a witness
   inside the guest asks for the key and is refused.
5. **The board.** With OS-5, on the Pi 4 itself.

Steps 1 and 2 touch no ruling. Step 3 is where "no second kernel" and
"No hypervisor in the product" are reopened or kept, by the author.
