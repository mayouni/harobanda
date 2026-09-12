# Architecture — the pipeline, the profiles, the sovereignty table, the court

## 1. The pipeline

```
 .machine ──declare──▶ judged structure ──derive──▶ boot plan ──image──▶ bootable artifact ──boot──▶ transcript
   (text)   src/machine.zig                src/plan.zig     (OS-2)        hosted: kernel+initramfs   src/init.zig
                │                                                          edge:   firmware (MicroRing)
                └── judged by declarative/machine/fixtures.json            touch:  AOSP build
                └── itself declared in machine.stzu, judged by stz's Stzu.luau
```

Every arrow is text-before-act: a declaration is judged before a plan
exists, a plan is printed before an image is built, an image boots in
an emulator before a board. Nothing on the right can be reached without
passing the court on the left.

## 2. One binary, every role

`stzos` is one static executable (Zig, no libc on Linux via musl static,
~3.4 MB unstripped). On the host it is the CLI — `check`, `plan`,
`court`, later `image`. On a hosted machine the same file is PID 1 —
`stzos init <file.machine>`, passed by the kernel command line
(`init=/stzos` with the machine file as its argument). Cross-compiling
it for the machine is one flag (`zig build cross`), Ring++'s P8 kept: no
C toolchain is required of anyone.

The multi-call shape is deliberate: the image's boot path holds exactly
two binaries, stzos and stzr, and the declared services. There is no
third program on the path for a declaration to reach.

## 3. The hosted image (OS-2 — built and booted 2026-09-12)

| part | source | verdict |
|---|---|---|
| kernel | Linux LTS, vendored as source, built with `make CC="zig cc"` on a Linux host; config minimal per machine (no modules: the declared FS, NIC, console only) | **keep vendored** — rebuilt by our toolchain, as Ring 1.27's VM was |
| init | `stzos init` | **own** |
| runtime | `stzr` (stz's static binary) | **own** |
| userland | none: no shell, no coreutils, no busybox | **none** |
| filesystem | initramfs (cpio) holding `/stzos`, `/stzr`, `/app/*.luau`, `/etc/machine`; declared mounts for persistent data | **own** (the builder writes it) |
| network | `stzos-net` — a service, not init's job; DHCP/static per a NETWORK kind (queued) | **own** (small) |
| updates | A/B image partitions, atomic pointer swap, watchdog rollback (ZinOS Edge's OTA design) | **own**, governed by refine |
| emulator | QEMU (`-kernel bzImage -initrd initramfs.cpio -append "init=/stzos ..." -nographic`) | **borrow** for the court; not shipped |
| bootloader | the board's (U-Boot on ARM SBCs, the firmware's EFI stub on x86) | **borrow**; declared per machine later |

`stzos image <file.machine> --root <staging> --out <dir>` judges the
file and DERIVES three texts, touching no toolchain: `initramfs.list`
(the kernel's own gen_init_cpio description — device nodes, mount
points, `/stzos`, every program and file the services name, each taken
from the staging root and refused if absent, and the declaration itself
at `/etc/machine`), `kernel.fragment` (the kconfig options the profile
and the declared mounts require), and `boot.cmd` (the QEMU line). The
imperative half is `experiment/os2_image.sh` on a Linux host: tinyconfig
plus the fragment, `make -j2 bzImage`, gen_init_cpio, QEMU with the
serial console captured, and the judge — the transcript normalised
(firmware banner, CRs, pids) and diffed against
`machines/<name>.expected`.

**First boot, measured (2026-09-12, WSL Ubuntu, QEMU 10.2 TCG):**
Linux 6.12.109 at 496 options → a 1.2 MB bzImage in 78 s wall at two
jobs; a 4.2 MB initramfs of two binaries (stzos 3.4 MB unstripped, stzr
776 KB), one Luau file and the machine file; the boot ran PID 1 through
four mounts, two services and a clean `reboot(RESTART)`, QEMU exiting 0
under `-no-reboot`. The transcript matches the pinned expectation line
for line.

## 4. The edge profile (declared; MicroRing's substrate)

The `.machine` file declares the sensor; the projection is MicroRing's:
MicroZig HAL, littlefs on SPI flash, the cooperative loop as the
scheduler, comptime board selection, A/B slots. `stzos init` refuses
the edge profile by name and says whose it is. The edge kernel of
ZinOS Edge's design (scheduler, page+arena allocator, HAL, littlefs,
optional lwIP) is the ONLY kernel this estate would ever write, because
no Linux fits a Cortex-M4; it is written in MicroRing's repository, not
here, when the RP2350 board work resumes.

## 5. The touch profile (declared; ZinOS Touch's design)

AOSP fork; kernel and HAL untouched; GApps, Play, browser removed;
Launcher3 replaced by the pack's launcher rendered by stzr; a
persistent service loads the pack and speaks the telemetry channel.
Ring++ already ships signed APKs (`ringpp build --target android`); the
runtime's road to the phone exists. The profile is declarable and
judged so that one file describes the fleet, phone included.

## 6. The court

| altitude | instrument | today |
|---|---|---|
| the language | `fixtures.json`, 8 accepts + 32 rejects, sha256-pinned | 40/40 |
| the language's own declaration | `machine.stzu` judged by stz's `Stzu.luau` | accepted, 5/4/0/3 |
| the mechanism | Zig unit tests with negative siblings; the court probed with a mutated judge (3 reds) | green |
| the Linux-only code | `zig build cross` (two static targets) | builds |
| the boot | the transcript, run as PID 1 in a user namespace under WSL | ran: pids 1–10, proc mounted, sysfs/devtmpfs refused PERM, all policies exercised |
| the image | the QEMU serial transcript, normalised, diffed against `machines/qemu_hello.expected` | matches, 28 lines |

## 7. Boundaries

- Capability ENFORCEMENT is the service's scope on stzr (the runtime
  refuses what its machine did not grant — stzlib's down-constrain law);
  init records the envelope and starts the processes. Kernel-level
  enforcement (seccomp, namespaces per service, cgroups) is a named
  widening, not a v0.1 claim.
- Restart policy is a cap of 5 in v0.1 (a rehearsal guard); backoff and
  a declared budget are queued. A real machine's `always` service is
  expected to run, not to exit.
- AFTER orders STARTS, not completions: `hello` starts after `self` has
  been spawned, not after it has finished (the first boot shows both
  outputs interleaved by the kernel's scheduling). A readiness or
  completion seat is a fixture-first widening.
- Users and identities: every service runs as the machine. The USER
  seat with a per-device Ed25519 identity (MicroRing's ALIGNMENT.md
  finding: hardware custody and algorithm are coupled) is queued.
