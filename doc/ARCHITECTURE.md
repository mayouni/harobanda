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
(`rdinit=/stzos` with the machine file as its argument -- the root IS the initramfs). Cross-compiling
it for the machine is one flag (`zig build cross`), Ring++'s P8 kept: no
C toolchain is required of anyone.

The multi-call shape is deliberate: the image's boot path holds exactly
two binaries, stzos and stzr, and the declared services. There is no
third program on the path for a declaration to reach.

## 3. The hosted image (OS-2 — built and booted 2026-09-12)

| part | source | verdict |
|---|---|---|
| kernel | Linux LTS, vendored as source and pinned by digest; config minimal per machine (no modules: the declared FS, NIC, console only). Built by the host's **gcc**. `make CC="zig cc"` was attempted on 2026-09-12 (ZIGCC-1) and is behind `STZOS_CC=zigcc`: after four named concessions the tree builds, and the image does not boot — it dies in the 16-bit setup code | **keep vendored**, rebuilt from source by a compiler we do not yet own; the instrument for owning it is kept |
| init | `stzos init` | **own** |
| runtime | `stzr` (stz's static binary) | **own** |
| userland | none: no shell, no coreutils, no busybox | **none** |
| filesystem | initramfs (cpio) holding `/stzos`, `/stzr`, `/app/*.luau`, `/etc/machine`; declared mounts for persistent data | **own** (the builder writes it) |
| network | the NETWORK kind: PID 1 brings each declared interface up before any service — static (four ioctls and the route) or dhcp (a client in `src/netcfg.zig`); judged against QEMU's user-mode DHCP server | **own** |
| updates | two slots on the boot partition (`SLOTS`), `config.txt` naming the committed one and the firmware's `[tryboot]` naming the other; PID 1 commits a trial only once every service has started, under the hardware watchdog; `stzos update` writes the other slot and asks for one trial (the tryboot flag waits on a driver patch, AB-1) | **own**, governed by refine |
| emulator | QEMU (`-kernel bzImage -initrd initramfs.cpio -append "rdinit=/stzos ..." -nographic`) | **borrow** for the court; not shipped |
| bootloader | the board's: the Raspberry Pi 4's own firmware (`start4.elf`, `fixup4.dat` — a vendor blob pinned by sha256 in `vendor/rpi-firmware/PIN.txt`, fetched, never committed) reads `config.txt` and loads `kernel8.img` + the initramfs; on x86 the emulator loads the kernel itself | **borrow**, stated per board in the target table |
| device tree | mainline's `bcm2711-rpi-4-b.dtb`, plus the derived mmc aliases (`DTB_OPS`) for the card and the derived emulator ops (`QEMU_DTB_OPS`) for the court; `experiment/dtb_ops.py` applies, every op printed | **keep vendored**, two derived variants |
| Wi-Fi | not taken: a second vendor blob; the box speaks Ethernet (GENET, mainline) | **none** |

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

**The Makeen box, emulated (OS-3, 2026-09-12):** the same pipeline for
aarch64 — `make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu-`, the
`virt` machine, the PL011 console, virtio-mmio — with a 64 MB ext4 disk
declared as `MOUNT data` on `/dev/vda`: 531 options, a 3.8 MB `Image` in
2m01 at two jobs, the disk mounted by PID 1 before any world spoke, the
`kds` and `poste` worlds run by stzr (764 KB, aarch64 static). The real
box differs in what `makeen_box.machine` already says: the SD card's
partition and a network service; those are OS-4's.

**The board (OS-4, 2026-09-12):** `BOARD rpi4` in `makeen_box.machine`
selects the target: the BCM2711 platform in the kernel fragment (689
options; the mini-UART, the mailbox and firmware driver, the watchdog
that restarts the board, SDHCI, GENET), the device tree, two consoles
(the emulator's PL011 on the header pins as `ttyAMA0`, the board's
mini-UART there as `ttyS1`), and `sd.list`: a 256 MiB card, p1 FAT32
with the firmware, `config.txt`, `cmdline.txt`, `kernel8.img`, the DTB
and the initramfs, p2 ext4 as the declared `/data`. QEMU's `raspi4b`
boots the same image and finds `mmcblk0: p1 p2` by the declared name.
The emulator has no Ethernet, so the pinned transcript shows `stzos
net` refused with NODEV and the two worlds never started; the board
will show them start. That is the one place the two are allowed to
differ.

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
| the language | `fixtures.json`, 14 accepts + 50 rejects, sha256-pinned (BOARD, NETWORK, SLOTS, READY and USER widened it fixture-first) | 64/64 |
| the language's own declaration | `machine.stzu` judged by stz's `Stzu.luau` | accepted, 6/5/0/3 |
| the mechanism | Zig unit tests with negative siblings; the court probed with a mutated judge (3 reds) | green |
| the Linux-only code | `zig build cross` (two static targets) | builds |
| the boot | the transcript, run as PID 1 in a user namespace under WSL | ran: pids 1–10, proc mounted, sysfs/devtmpfs refused PERM, all policies exercised |
| the image, x86_64 | the QEMU serial transcript, normalised, diffed against `machines/qemu_hello.expected` | matches, 28 lines |
| the image, aarch64 (the Makeen box on `virt`) | the same against `machines/makeen_qemu.expected`: `virt`, PL011, a virtio ext4 disk mounted at `/data`, two stzr worlds | matches, 20 lines |
| the board's card (the Makeen box on `raspi4b`) | the same against `machines/makeen_box.expected`: the card's second partition mounted by its declared name, `stzos net` refused NODEV (no Ethernet in the emulator), the worlds never started by the readiness rule | matches, 17 lines |
| the wire | `makeen_qemu.expected` carries the dhcp lease from QEMU's server; `makeen_box.expected` the static network refused NODEV in the emulator | 22 lines; part of 49 |
| the slots | `makeen_box.expected`: a trial of B committed, the card read back boots B; the same trial held on a pristine card, not committed, that card still boots A | 49 lines |

## 7. Boundaries

- Capability ENFORCEMENT is the service's scope on stzr (the runtime
  refuses what its machine did not grant — stzlib's down-constrain law);
  init records the envelope and starts the processes. Kernel-level
  enforcement (seccomp, namespaces per service, cgroups) is a named
  widening, not a v0.1 claim.
- Restart policy is a cap of 5 in v0.1 (a rehearsal guard); backoff and
  a declared budget are queued. A real machine's `always` service is
  expected to run, not to exit.
- AFTER waits for READINESS: a `RESTART never` service is ready when it
  has exited 0 (a one-shot); a daemon when spawned, or — if it declares
  `READY "<path>"` — when it creates that path, its own word that it is
  serving (RDY-1). A failed one-shot and a daemon that never signals
  both block their dependents, and init names them. No timer: a daemon
  that never comes up keeps an A/B trial uncommitted, which is the safe
  outcome. A bounded window for the TRIAL is a named seam.
- Identities: a service runs as a declared USER when it names one, and
  as the machine itself when it says nothing (USR-1). uid 0 cannot be
  declared, so root is visible as the absence of a line rather than as
  a choice. The per-DEVICE identity — an Ed25519 key that never leaves
  the board (MicroRing's ALIGNMENT.md finding: hardware custody and
  algorithm are coupled) — is a different thing and still queued.
