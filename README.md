<p align="center">
  <img src="site/harobanda-logo.png" alt="Harobanda" width="420">
</p>

<p align="center">
  <b>The declared machine.</b><br>
  An operating system you write down — and that judges whether it kept its word.
</p>

---

A machine here is one text file. It says what the computer is, what it mounts,
what programs it keeps alive, and what each of them is allowed to touch. From
that file a boot plan is derived; one static binary executes the plan as PID 1
and narrates the boot as a transcript; and the transcript is judged against
what the file said. There is no shell, no package manager and no init scripts,
because **the declared machine is the system**.

It is built on the same Linux LTS kernel that Ubuntu and Red Hat ship. The
kernel is not what we set out to replace. What we rethought is everything the
industry treats as inevitable above it.

---

## A whole machine, in nine lines

```
DEFINE MACHINE hello AS (
  ARCH x86_64,
  KERNEL linux
) RATIONALE "the smallest machine that boots"

DEFINE SERVICE greet AS (
  RUN ["/app/greet"]
) RATIONALE "say hello, then exit"
```

`RATIONALE` is not a comment. The grammar requires it, so every part of a
machine has to say why it is there.

## The loop

```
declare  ─→  judge  ─→  plan  ─→  boot  ─→  it judges its own boot
   ↑                                                    │
   └────────  a change is a new file, judged again  ─────┘
```

| verb | what happens |
|---|---|
| **declare** | write a `.machine` file |
| **judge** | the court accepts it, or refuses it in plain words: `needs the network, which nothing here grants.` |
| **plan** | see the order things will happen in, before any of it does |
| **boot** | the whole machine boots in an emulator and judges its own transcript against the file |
| **break it** | change one line and watch the machine catch the difference |

A guarantee you have only ever watched succeed is a claim. One you have
watched refuse you is evidence — which is why every lesson in the guided tour
ends by showing you how to break it.

## Try it

You need [Zig](https://ziglang.org) 0.15 and, for booting images, WSL or Linux
with QEMU. No SDK, no account, nothing to install into your system.

```sh
zig build -j2                                  # builds the one binary
zig-out/bin/stzos check machines/qemu_hello.machine
zig-out/bin/stzos plan  machines/qemu_hello.machine
zig-out/bin/stzos learn                        # 18 lessons, guided
zig-out/bin/stzos learn --words                # the vocabulary
```

Then break something. Add a clause the grammar does not accept, or ask for a
capability nothing grants, and read what the court says back.

To boot a real image (Linux or WSL, first run fetches and builds a kernel):

```sh
bash experiment/os2_image.sh qemu_hello        # image, kernel, QEMU, judged
cat zig-out/wsl/image_qemu_hello.txt
```

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
  is the next seat.
- **Single-binary deployment is the goal, not yet the whole reality.**
  Declaring, judging and emulating need only this binary; producing a
  flashable image still calls a standard kernel build underneath.
- **It will never be a product you buy from a vendor**, because a vendor
  inside the system is the one thing it refuses. That is not a gap to close.

## Three profiles, one language

| profile | substrate | init | state |
|---|---|---|---|
| **hosted** | vendored Linux kernel, static musl userland, this binary as PID 1 | `stzos init` | **boots** on x86_64 and aarch64 under QEMU, and as a Raspberry Pi 4 image under `raspi4b`; transcripts judged |
| **edge** | no kernel — the binary is the device (MicroRing's substrate) | a cooperative loop | declarable and judged; not yet bootable |
| **touch** | the device's own kernel and init | the launcher is the pack | declarable and judged; unbuilt |

## Where things are

| what | where | judged by |
|---|---|---|
| the machine language — grammar, five kinds, closed menus | `declarative/machine/GRAMMAR.md` | 40 pinned fixtures, `zig build court` |
| the language, itself declared | `declarative/machine/machine.stzu` | stz's meta-court, `experiment/judge_machine_stzu.luau` |
| the parser and the court's checks | `src/machine.zig` | unit tests and fixtures |
| the boot plan, derived | `src/plan.zig` | fixtures (order, granted set) |
| PID 1 | `src/init.zig` | its own transcript, run for real under WSL |
| the image: initramfs, kernel fragment, boot line | `src/image.zig` | the QEMU transcript against `machines/*.expected` |
| the network kind — the wire is up before any service | `src/netcfg.zig`, `src/net.zig` | fixtures A10–A11, R36–R40 |
| identity: a device's key, and the record it signs | `src/init.zig`, `src/journal.zig` | `machines/qemu_identity.expected` |
| a fleet — facts about a SET, judged together | `src/fleet.zig` | `machines/fleet.expected`, `experiment/os7_fleet.sh` |
| A/B slots — an update is a trial, not a commitment | `src/init.zig`, `src/update.zig` | the card read back after a trial and after a held one |
| the edge projection | `src/project.zig` | `experiment/judge_project.sh` |
| the guided tour, judged like any other claim | `src/learn.zig` | `stzos learn --check`, in `zig build court` |
| the reference machines | `machines/` | each boots and is judged against its `.expected` |
| the vendored kernel, pinned by digest | `vendor/PIN.md` | sha256 from kernel.org's own sums |

## Commands

```sh
zig build -j2 && zig build test -j2 && zig build court -j2 && zig build cross -j2

zig-out/bin/stzos check|plan machines/<name>.machine
zig-out/bin/stzos learn [n] [--all|--words|--run|--check]
zig-out/bin/stzos fleet machines/salle_makeen.fleet

bash experiment/judge_guarantees.sh            # the four standing promises
bash experiment/os2_image.sh qemu_hello        # image, kernel, QEMU, judge
bash experiment/os6_names.sh                   # two machines, one wire
bash experiment/os7_fleet.sh                   # a device's key, a fleet's record
```

`zig build cross` is not optional: `src/init.zig` is comptime-gated on Linux
and Zig analyses only the taken branch, so a Windows build proves nothing
about the init.

## How this repository works

Every line of doctrine here was paid for by a mistake, and each is written up
under its own tag in `experiment/PROTOCOL.md`, newest first. A few of them:

- **Fixtures are the judge.** Every refusal case carries the exact words its
  refusal must contain.
- **A generated artifact is judged by what consumes it**, never by a diff
  against the same generator's earlier output — both sides can be wrong in
  the same way and the court stays green.
- **A pin is not a record of what happened; it is a claim that what happened
  was right.** Never copy a transcript over its expectation without reading
  the diff.
- **A promise the machine announces and cannot keep is worse than one it
  never made.** When the mechanism behind a declared guarantee fails, refuse
  the act and say so.
- **Evidence is what the machine said about *this* boot**, never what it
  quoted about another.

Design documents live in `doc/` — `VISION.md` for what this is for,
`ARCHITECTURE.md` for how it is put together, `PROVENANCE.md` for the rulings
that shaped it, and `GROUND.md` for the solutions it is the floor of.

## A note on names

This repository is `stzos` and its binary is `stzos`. The system is presented
publicly as **Harobanda**, named for the bridge across the Niger River that
joins the two banks of Niamey — because the machine likewise joins a
solution's promises to the hardware that keeps them.

The final naming is an open ruling, recorded in `doc/PROVENANCE.md`. Until it
is settled, `stzos` is what you type and Harobanda is what it is called. The
site under `site/` uses the public name throughout.

## Licence

Not yet chosen. Until a licence file is added, no permission to use, copy or
redistribute this work is granted — which is a gap, not an intention, given
that rebuilding it yourself is the whole point.
