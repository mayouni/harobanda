<p align="center">
  <img src="site/harobanda-logo.png" alt="Harobanda" width="420">
</p>

<p align="center">
  <b>The declared machine.</b><br>
  You describe the whole computer in one text file. It boots exactly that, and checks every boot against the file.
</p>

---

## Why it exists

Every operating system you can buy is shaped by its vendor: the account you
sign in with, the store you cannot remove, the telemetry you cannot see, the
update you cannot refuse, the support that ends on a date someone else picks.
Even a free system is shaped by whoever curates it — its package repositories,
its defaults, its release calendar.

Harobanda began with real solutions for shops, clinics, banks and public
services in West Africa, where the power cuts out, the network comes and goes,
and a cloud you cannot reach is a liability rather than a help. What those
solutions needed was simple to say: **a box that survives the power cut, a
name that never moves, records that never leave the room.** Those guarantees
turned out to live one floor below the application — in the operating system.

So Harobanda turns the relationship around: **the operating system is shaped
by your solution, not by a vendor.**

<p align="center">
  <img src="site/harobanda-diagram-7.png" width="820" alt="Two columns. A general-purpose OS is built for everyone: your job plus everything else you did not choose; you adapt and subtract, and are left with your job plus drivers, logins and packages. A declared machine starts from what the job must guarantee — a fixed address, a name that never moves, a record that survives, a clean restart — and the machine is derived from it, with nothing more.">
</p>

## The idea

You write down what the machine must be, in one text file:

- what the computer is — its board and its architecture;
- what storage it mounts;
- which programs it keeps running;
- what each of those programs is allowed to touch.

Every part must say **why** it is there: the grammar requires a reason.

Harobanda derives everything else from that file — the boot order, the kernel
configuration, the disk image. The machine then boots as that description,
narrates each step as it takes it, and at the end **checks what it did against
what you wrote**. If the two differ, it says where.

There is no shell, no package manager, no login and no store on the machine.
Nothing is installed afterwards: to change the machine, you change the file,
and the new file is judged again.

### A whole machine, in nine lines

```
DEFINE MACHINE hello AS (
  PROFILE hosted,
  ARCH x86_64,
  KERNEL linux
) RATIONALE "the smallest machine that boots"

DEFINE SERVICE greet AS (
  RUN ["/app/greet"]
) RATIONALE "say hello, then exit"
```

`RATIONALE` is not a comment. The court refuses any part of a machine that
does not say why it is there — and it accepts this one, which the repository
checks on every build.

## How it works

<p align="center">
  <img src="site/harobanda-diagram-9.png" width="820" alt="Four steps from left to right: declare one file, judge it with harb check, plan it with harb plan, boot it in QEMU. An arrow returns from the boot to the declaration: the boot is judged against the file, and a change is a new file, judged again.">
</p>

| step | what happens |
|---|---|
| **declare** | you write a `.machine` file |
| **judge** | `harb check` accepts it, or refuses it in plain words, such as *needs the network, which nothing here grants* |
| **plan** | `harb plan` shows the order things will happen in, before any of it does |
| **boot** | the machine boots in QEMU and judges its own transcript against the file |
| **break it** | change one line and watch the machine catch the difference |

A guarantee you have only ever watched succeed is a claim. One you have
watched refuse you is evidence — which is why every lesson in the guided tour
ends by showing you how to break it.

## Not a new kernel

<p align="center">
  <img src="site/harobanda-diagram-4.png" width="820" alt="The kernel is the same, everything above it is not. An ordinary distribution stacks a shell, a package manager, a service manager, mutable configuration, a login and a store on Linux LTS. Harobanda puts only the declaration, where every line says why, and the court, which judges it before it runs, on the same Linux LTS.">
</p>

Underneath runs the same Linux LTS kernel as Ubuntu and Red Hat — the same
drivers, the same hardware support, the same years of hardening. What was
rethought is everything the industry treats as inevitable above it. For an IT
team that is the reassuring part: no exotic kernel to certify; what is new is
the discipline above it.

## What it changes, in practice

| on an ordinary OS | on a declared machine |
|---|---|
| the box's address can move after a power cut | its address and name come from the file, and it serves them itself |
| a bad update can leave it unable to boot | an update is a trial, committed only if its boot matches the file |
| a shell and packages to patch and guard | no shell and no packages: most of what you usually secure is not there |
| "the data stays here" is a policy on paper | one declared line leaves the box no route out, and every boot says so |
| you hope it behaves as intended | it checks its own boot against its file, every time |
| records are whatever the software kept | a device signs its own boot record; anyone with the fleet file can check it |

An update, concretely — two copies of the system, and a trial:

<p align="center">
  <img src="site/harobanda-diagram-5.png" width="820" alt="Two slots, a trial, and a timer that is not software. Slot A runs; the update is written to slot B, not yet trusted; slot B boots with the watchdog armed. If its boot matches what the file declared, it is committed and the watchdog keeps being fed. If not, the feed stops and the board boots slot A again.">
</p>

The emulator proves the trial and the rollback today; the Raspberry Pi's own
hardware watchdog is the next step (see [What is real today](#what-is-real-today)).

**Who it is for.** Whoever answers for a whole solution, not only its code.
The programmer, whose machine is its own configuration and its own
documentation. The administrator, who has no shell to secure and no packages
to patch. The auditor, who can read the whole machine in one file and check a
signed record of every boot.

Two real engagements shaped the design: a restaurant in Lyon whose whole
service runs on one box behind the counter, and a national NGO in Niger whose
offline hub must never let its data leave the building. Neither runs on
Harobanda yet; both are why it is built the way it is.

## Try it

You need [Zig](https://ziglang.org) 0.15. No account, no sign-up.

Build the one binary:

```sh
zig build -j2
```

Let the court rule on a machine, then read its plan. This one
declares a single network destination, and not the open internet:

```sh
zig-out/bin/harb check machines/qemu_egress.machine
zig-out/bin/harb plan machines/qemu_egress.machine
```

Take the guided tour — eighteen lessons, each ending with a way to break it:

```sh
zig-out/bin/harb learn
```

### Boot it

Booting needs Linux (on Windows, WSL's Ubuntu), QEMU, and the tools that
build a Linux kernel. On Ubuntu:

```sh
sudo apt install qemu-system-x86 gcc make flex bison bc \
  libelf-dev libssl-dev cpio xz-utils curl
```

Then, from the repository root:

```sh
zig build cross -j2
bash experiment/os2_kernel_fetch.sh
bash experiment/os2_image.sh qemu_egress
```

The first line builds `harb` for the machine itself. The second fetches
the kernel source this repository pins, and refuses it unless its digest
matches. The third builds a kernel and an image, boots it in QEMU, and
judges the boot; the first run takes a few minutes. The machine says,
as it boots, what the kernel will and will not let it reach:

```
boot: egress lan -- 10.9.0.0/16 and nowhere else:
    no default route
reach 10.9.0.1 -- a route exists: this machine knows a way there
reach 8.8.8.8 -- no route: this machine knows no way there
boot: judge -- the boot matches its expectation
    (/etc/expected, 14 lines)
```

(An indented line continues the one above it.) The whole transcript, and
the verdict against the transcript this repository pins, land in
`zig-out/wsl/image_qemu_egress.txt`.

Then break something: add a clause the grammar does not accept, or ask for a
capability nothing grants, and read what the court says back.

The reference machines that run only `harb` need nothing outside this
repository. Four also run a Luau world under `stzr`, the runtime from the
stz repository, which is private today: `qemu_hello`, `qemu_budget`,
`makeen_box` and `makeen_qemu`. Without it they boot, and judge
themselves different from their pins.

## What is real today

Honesty is part of the design, so these are the plain limits.

- **It is a working system, and a young one.** Declared machines boot and
  judge themselves in an emulator today. No customer yet runs a critical
  production workload on one.
- **The kernel underneath is borrowed on purpose** — the same Linux LTS the
  major distributions ship, pinned by digest and rebuilt by your own
  toolchain. Borrowed is not the same as withdrawable.
- **The card has not met a Pi yet.** The Raspberry Pi 4 image boots under
  QEMU's `raspi4b` and is judged against a pinned transcript; the real board
  is the next step.
- **Single-binary deployment is the goal, not yet the whole reality.**
  Declaring, judging and emulating need only this binary; producing a
  flashable image still calls a standard kernel build underneath.
- **It will never be a product you buy from a vendor**, because a vendor
  inside the system is the one thing it refuses. That is not a gap to close.

## Three profiles, one language

| profile | substrate | state |
|---|---|---|
| **hosted** | the Linux kernel, a static userland, this binary as PID 1 | **boots** on x86_64 and aarch64 under QEMU, and as a Raspberry Pi 4 image; judged |
| **edge** | no kernel — the binary is the device (MicroRing's substrate) | declared and judged; projected to MicroRing; not yet booted |
| **touch** | a tablet's own kernel, with the app as its launcher | declared and judged; not built |

## Where things are

| what | where | judged by |
|---|---|---|
| the machine language: its kinds and their closed menus | `declarative/machine/GRAMMAR.md` | every case pinned, in `zig build court` |
| the parser and the court's checks | `src/machine.zig` | unit tests and fixtures |
| the boot plan, derived | `src/plan.zig` | fixtures |
| PID 1 | `src/init.zig` | its own transcript, run for real |
| the image: initramfs, kernel fragment, boot line | `src/image.zig` | QEMU transcripts against `machines/*.expected` |
| the network: the wire is up before any service | `src/netcfg.zig`, `src/net.zig` | fixtures and a two-machine boot |
| identity: a device's key, and the record it signs | `src/journal.zig` | `machines/qemu_identity.expected` |
| a fleet: facts about a set, and the keys a device used to have | `src/fleet.zig` | `declarative/fleet/`, `experiment/os7_fleet.sh` |
| updates: two slots, and a trial before any commit | `src/update.zig` | the card read back after a trial |
| the guided tour, judged like any other claim | `src/learn.zig` | `harb learn --check` |
| the pages: every code line fits GitHub's column, and every machine a page shows in full is one the court accepts | `src/docs.zig` | `harb docs --check`, in `zig build court` |
| the reference machines | `machines/` | each boots and is judged against its pin |
| the illustrated long version | `site/` — open `site/index.html` | the court judges every machine it shows in full |
| the vendored kernel, pinned by digest | `vendor/PIN.md` | kernel.org's own sums |

Design documents live in `doc/`: `VISION.md` for what this is for,
`ARCHITECTURE.md` for how it is put together, `GROUND.md` for the solutions it
is the floor of, and `PROVENANCE.md` for the rulings that shaped it.

## For contributors

Every change passes the same four gates:

```sh
zig build -j2
zig build test -j2
zig build court -j2
zig build cross -j2
```

`zig build cross` is not optional: `src/init.zig` only compiles for Linux, and
Zig analyses only the side of a compile-time branch it takes, so a Windows
build proves nothing about PID 1.

The experiments that boot real machines, each judged against a pinned
transcript:

- `bash experiment/os2_image.sh <name>` — image, kernel, QEMU boot, judged
  against `machines/<name>.expected`;
- `bash experiment/judge_guarantees.sh` — the four standing promises;
- `bash experiment/os6_names.sh` — two machines on one wire: a box that serves
  names, and a till that asks;
- `bash experiment/os7_fleet.sh` — a device's key, a fleet that enrols it, a
  rebuilt card and a stolen one.

Every line of doctrine here was paid for by a mistake, and each is written up
under its own tag in `experiment/PROTOCOL.md`, newest first. A few of them:

- **Fixtures are the judge.** Every refusal case carries the exact words its
  refusal must contain.
- **A pin is not a record of what happened; it is a claim that what happened
  was right.** Never copy a transcript over its expectation without reading
  the diff.
- **A promise the machine announces and cannot keep is worse than one it
  never made.** When the mechanism behind a declared guarantee fails, refuse
  the act and say so.
- **A tutorial is a claim about the system**, so it is judged like one — and
  so is every example on this page.

## A note on names

Three names, one thing, and they are not interchangeable:

| **Harobanda** | the system — what it is called, in every sentence |
|---|---|
| **`harb`** | the binary and the command — what you type |
| **`harobanda`** | the repository, and the directory you clone it into |

It is named for the bridge across the Niger River that joins the two banks of
Niamey, because the machine likewise joins a solution's promises to the
hardware that keeps them.

It was called `stzos` until 2026-09-20, which is the name the git history
carries. The ruling that changed it is STZ-OS-RULING-02 in
`doc/PROVENANCE.md`, beside the one it supersedes.

## Licence

MIT, © 2026 Mansour Ayouni — the licence the estate's other code already
carries (stzlib, Ring++, MicroRing, zin). [`LICENSE`](LICENSE) says what it
covers and what it does not: a machine is built from Linux, which is GPL-2.0
and is fetched and pinned by digest rather than contained here, so an image
that carries the kernel carries the kernel's obligations.
