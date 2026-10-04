# Architecture — the pipeline, the profiles, the sovereignty table, the court

## 1. The pipeline

```
.machine  (text)
   │
   │  declare  src/machine.zig
   │           ├─ judged by declarative/machine/fixtures.json
   │           └─ itself declared in machine.stzu, judged by
   │              stz's Stzu.luau
   ▼
judged structure
   │
   │  derive   src/plan.zig
   ▼
boot plan
   │
   │  image    (OS-2)
   ▼
bootable artifact  hosted: kernel+initramfs
   │               edge:   firmware (MicroRing)
   │               touch:  AOSP build
   │  boot     src/init.zig
   ▼
transcript
```

Every arrow is text-before-act: a declaration is judged before a plan
exists, a plan is printed before an image is built, an image boots in
an emulator before a board. Nothing on the right can be reached without
passing the court on the left. And the last arrow judges itself: the
image carries the boot it EXPECTS (`/etc/expected`, derived from the
plan), PID 1 records what it says and judges the two when every service
is ready, and an A/B trial commits only on a match (JDG-1).

## 2. One binary, every role

`harb` is one static executable (Zig, no libc on Linux via musl static,
~3.4 MB unstripped). On the host it is the CLI — `check`, `plan`,
`court`, later `image`. On a hosted machine the same file is PID 1 —
`harb init <file.machine>`, passed by the kernel command line
(`rdinit=/harb` with the machine file as its argument -- the root IS the initramfs). Cross-compiling
it for the machine is one flag (`zig build cross`), Ring++'s P8 kept: no
C toolchain is required of anyone.

The multi-call shape is deliberate: the image's boot path holds exactly
two binaries, `harb` and `stzr`, and the declared services. There is no
third program on the path for a declaration to reach.

## 3. The hosted image (OS-2 — built and booted 2026-09-12)

| part | source | verdict |
|---|---|---|
| kernel | Linux LTS, vendored as source and pinned by digest; config minimal per machine (no modules: the declared FS, NIC, console only). Built by the host's **gcc**. `make CC="zig cc"` was attempted on 2026-09-12 (ZIGCC-1) and is behind `HARB_CC=zigcc`: after four named concessions the tree builds, and the image does not boot — it dies in the 16-bit setup code | **keep vendored**, rebuilt from source by a compiler we do not yet own; the instrument for owning it is kept |
| init | `harb init` | **own** |
| runtime | `stzr` (stz's static binary) | **own** |
| userland | none: no shell, no coreutils, no busybox | **none** |
| filesystem | initramfs (cpio) holding `/harb`, `/stzr`, `/app/*.luau`, `/etc/machine`; declared mounts for persistent data | **own** (the builder writes it) |
| network | the NETWORK kind: PID 1 brings each declared interface up before any service — static (four ioctls and the route) or dhcp (a client in `src/netcfg.zig`); judged against QEMU's user-mode DHCP server. `EGRESS` says how far a granted network REACHES: the routing table is written from the declaration, and with a declared reach there is no default route at all (EGR-1) | **own** |
| updates | two slots on the boot partition (`SLOTS`), `config.txt` naming the committed one and the firmware's `[tryboot]` naming the other; PID 1 commits a trial only once every service is ready AND its own boot matches the expectation the image carries (JDG-1), under the hardware watchdog; a boot that differs names the lines and holds itself; `harb update` writes the other slot and asks for one trial (the tryboot flag waits on a driver patch, AB-1) | **own**, governed by refine |
| the machine's own record | `JOURNAL`, one line per boot: `seq`, `prev`, the machine, the digest of the declaration that ran, the verdict, the entry's hash and the device's signature over its exact bytes. Plain text, append-only, never rewritten; no timestamp, because the board has no clock of its own and the sequence is the order (JRN-1) | **own** |
| the floor's own refusals | Not derived from `NEEDS` at all: twenty-five calls that would let a world change the machine it was declared to run on -- mount, the module and kexec calls, reboot, the clock setters, the host name, unshare and setns, ptrace, swap, bpf, syslog, acct, mknod -- refused with EPERM to EVERY world on every machine, including one that declared everything. The filter is installed last, after PID 1 has used those calls to build the envelope (SYS-1) | **own** |
| the envelope at the kernel | Derived from `NEEDS` and declared nowhere: a world that did not ask for `network` runs in its own empty network namespace, one that did not ask for `process` is refused `fork` and `clone`-without-`CLONE_THREAD` by a seccomp filter installed before its exec, one that did not ask for `filesystem` runs in a mount namespace with every declared MOUNT detached, and one that did not ask for `process` is pid 1 of a table of its own with `/proc` remounted inside it, reached through a stand-in process that carries the world's exit or signal back unchanged -- the tree made `MS_PRIVATE` first, or the umounts would take the machine's storage from PID 1 too. A world whose envelope the kernel cannot build is NOT STARTED (NS-1, MNT-1) | **own** |
| a member's device | `HARDWARE` on a MEMBER: which physical unit it is, beside the enrolled key, because both are facts a DEPLOYMENT learns and neither is a fact a design states. It lets the court hold the server's promise against the machine that will claim it -- the correspondence that used to live in a shell-script constant (HDW-1) | **own** |
| the fleet | `FLEET`, `MEMBER` and `ROUTE` in a second file of the same language: the checks no single machine can fail (two servers on one link, two claims on one address, somebody asking where nobody serves, a box that is the way between links nobody declared joined, a till whose way there has no way back) and the enrolled PUBLIC key that lets any holder of the file verify any member's signed record. Enrolment is manual and a member without a key is reported, never guessed (FLT-1) | **own** |
| the network's names | `DOMAIN` on a NETWORK and the `PEER` kind: the machine is its link's own server of addresses and names. No pool and no range — the declaration IS the register, so it cannot be lost at a reboot; the lease is infinite because the address was declared, not timed. A router option only if the box forwards (`FORWARD`, FWD-1), and no referral: it speaks for its own link and for the links it is the way to, by their full names, and for nothing else (NAM-1) | **own** |
| the expected boot | `/etc/expected`, derived by `harb image` from the plan: the init lines a faithful boot prints, pids as `N`, a dhcp lease as `*`; for a board the court emulates, `/etc/expected.emulator` through the emulator's lens, and the diff of the two is the emulator's lacks, printed at build time | **own**, derived |
| emulator | QEMU (`-kernel bzImage -initrd initramfs.cpio -append "rdinit=/harb ..." -nographic`) | **borrow** for the court; not shipped |
| bootloader | the board's: the Raspberry Pi 4's own firmware (`start4.elf`, `fixup4.dat` — a vendor blob pinned by sha256 in `vendor/rpi-firmware/PIN.txt`, fetched, never committed) reads `config.txt` and loads `kernel8.img` + the initramfs; on x86 the emulator loads the kernel itself | **borrow**, stated per board in the target table |
| device tree | mainline's `bcm2711-rpi-4-b.dtb`, plus the derived mmc aliases (`DTB_OPS`) for the card and the derived emulator ops (`QEMU_DTB_OPS`) for the court; `experiment/dtb_ops.py` applies, every op printed | **keep vendored**, two derived variants |
| Wi-Fi | not taken: a second vendor blob; the box speaks Ethernet (GENET, mainline) | **none** |

`harb image <file.machine> --root <staging> --out <dir>` judges the
file and DERIVES three texts, touching no toolchain: `initramfs.list`
(the kernel's own gen_init_cpio description — device nodes, mount
points, `/harb`, every program and file the services name, each taken
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
jobs; a 4.2 MB initramfs of two binaries (harb 3.4 MB unstripped, stzr
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
The emulator has no Ethernet, so the pinned transcript shows the
declared network refused with NODEV; the worlds run anyway, because a
network is brought up like a mount and a refused one does not hold a
service back (NET-1). The board will show the interface up and the
watchdog armed -- the two lines the build prints as the emulator's
lacks, and the only place the two are allowed to differ. *(Amended
2026-09-28, CON-1: three lines. The board's console is its mini-UART on
the header pins, and QEMU cannot carry it, so the emulator's kernel
speaks on the PL011 and PID 1 says so: `console /dev/ttyS1 -- declared,
and the kernel speaks on /dev/ttyAMA0`.)*

## 4. The edge profile (declared here, projected onto MicroRing)

**`harb project <file.machine> --out <dir>` (PRJ-1, 2026-09-12).** A
MicroRing project is a folder with a `device.ring` in it, whose
`Device([...])` declaration carries a board and the pins — exactly the
half a `.machine` file declares. The verb writes that file and nothing
MicroRing owns, and it prints what did NOT cross over and why: a flash
MOUNT (the substrate mounts it), the capabilities (the machine's
envelope, which MicroRing has no gate for), and each service's
BEHAVIOUR (the Device language's, an L2 member; until that language
exists the every/on handlers are the author's Ring code beside the
generated file, and the generated file names them rather than
inventing them). The edge boards are MicroRing's own words: `sim`,
`pico2`, `pico2w`, `esp32c6`. Judged by
`machines/cold_room_sensor.device.ring.expected` AND by MicroRing
itself (`experiment/judge_project.sh` runs the binary when it is beside
this repository), with both refusals as its negatives: projecting a
hosted machine, and imaging an edge one. The consumer joined the judge
in PRJ-2, when a projection that passed the diff was refused by Ring
for a comment character.

The `.machine` file declares the sensor; the rest of the projection is
MicroRing's:
MicroZig HAL, littlefs on SPI flash, the cooperative loop as the
scheduler, comptime board selection, A/B slots. `harb init` refuses
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
| the image, x86_64 | the QEMU serial transcript, normalised, diffed against `machines/qemu_hello.expected` | matches, 33 lines |
| the image, aarch64 (the Makeen box on `virt`) | the same against `machines/makeen_qemu.expected`: `virt`, PL011, a virtio ext4 disk mounted at `/data`, two stzr worlds that SERVE and signal | matches, 25 lines |
| the board's card (the Makeen box on `raspi4b`) | the same against `machines/makeen_box.expected`: the card's second partition mounted by its declared name, the network refused NODEV (no Ethernet in the emulator), the two worlds run | matches, part of 75 |
| the wire | `makeen_qemu.expected` carries the dhcp lease from QEMU's server; `makeen_box.expected` the static network refused NODEV in the emulator | part of 23 and 75 |
| the slots | `makeen_box.expected`: a trial of B committed, the card read back boots B; the same trial held on a pristine card, not committed, that card still boots A | part of 75 |
| the machine's record | `JOURNAL`: one line per boot, hash-chained and signed by the device's key, carrying the declaration digest and the boot's own verdict. Verified before it is extended and never extended when it does not verify; a machine that cannot keep its record holds the trial that would have committed (JRN-1) | 46 lines twice-booted; 121 across four card boots |
| what a world may see and do | `machines/qemu_confine.machine`: four worlds, four questions, and the only difference between them is what their own NEEDS say -- one cannot see the interface at all, one is refused its fork with EPERM, one is held to nothing, and one that asked for nothing but the right to run has neither a network nor the machine's storage, and one that never asked for `process` is alone in a process table of its own. `makeen_box` runs both its worlds that way across four card boots (NS-1, MNT-1, PID-1) | matches, 39 lines |
| attribution across machines | `machines/fleet_temoin.machine` publishes its public key and its record; `experiment/os7_fleet.sh` enrols the key by hand and verifies the record with no secret taking part, then lets three negatives decide it -- one word changed, the record offered as another device's, and a member nobody enrolled (FLT-1) | matches, 26 lines |
| the network's names | `machines/makeen_names.machine` serving and `machines/caisse_makeen.machine` asking, booted TOGETHER on one QEMU socket netdev by `experiment/os6_names.sh` — the first time two of these machines met on a wire. The till learns its address, the domain and the resolver from the link, then asks for the printer by name; a third round boots the same image with a hardware address nobody declared and it gets nothing (NAM-1) | matches, 66 lines |
| the device's name | `machines/qemu_identity.machine`: an Ed25519 key made on first boot and kept on a declared partition; `harb attest` signs, verifies, and shows a tampered message refused. `makeen_box.expected` boots the same card twice, so the key is CREATED once and LOADED after -- and a pristine card makes its own (IDN-1) | 18 lines; 117 across four card boots |
| the perimeter | `machines/qemu_egress.machine` on `qemu_pc`: `EGRESS ["10.9.0.0/16"]` writes one route and no default route, and two witnesses ask the kernel -- a way to the declared range, no way to the open internet, and no packet sent to find out (EGR-1) | matches, 19 lines |
| the board, prepared | `experiment/os5_board.sh` -- the card's digests, the check that its cmdline carries no instrument of the court, the wiring, the capture, and three judges on one boot (the board's own verdict, `harb judge` from the host, the four promises); `rehearse` proves the pipeline with no hardware (OS-5-PREP) | rehearsed; OS-5 waits on a board |
| the four promises | `harb guarantees` judges the hosted profile's four standing promises by name against a machine's own evidence, quoting the line that keeps each; `experiment/judge_guarantees.sh` does it twice for the box and pins both reports (GRT-1) | 39 lines; 3 of 4 on the board's expectation, 1 of 4 on the emulator's transcript |
| budgets | `machines/qemu_budget.machine` on `qemu_pc`: two worlds, one inside its ceiling and one over it. `modest` holds 8 MiB of its 64 and ends; `greedy` asks for far more than its 32 and is killed by signal 9 five times inside its own group, its neighbour untouched, the box carrying on to a clean halt (BDG-1) | matches, 35 lines |
| health | `makeen_box.expected` and `makeen_qemu.expected` carry the standing rule (`health -- kds every 5s, poste every 5s`) and a commit line that says the window was held; the NEGATIVE is the WSL rehearsal's `signals`, a `flock` that creates its path once and never refreshes it, caught in seconds (HLT-1) | 84 and 26 lines; the rehearsal |
| the served machine | `makeen_qemu.expected` and `makeen_box.expected`: each world is a daemon with a declared READY path, PID 1 starts what comes after only once the signal appears, and the boot ends on `--halt-on-verdict` (derived onto the emulator's line, never the card's). A daemon never exits, so the loop polls rather than blocking on `wait4` (SRV-1) | 25 and 81 lines |
| the machine's own judge | every transcript carries PID 1's verdict on its own boot against `/etc/expected` (`matches ... 14 lines`, `15`, `16`); `makeen_box.expected` adds the negative: the trial judged through the board's lens differs on exactly the emulator's two lacks, holds itself, and the card still boots A; `src/expect.zig` pins the derivation and the judge's negatives in five unit tests | 81 lines; 11/11 tests |

## 7. Boundaries

- Capability ENFORCEMENT is the service's scope on stzr (the runtime
  refuses what its machine did not grant — stzlib's down-constrain law);
  init records the envelope and starts the processes. RESOURCES are the
  exception since BDG-1: `MEMORY` and `CPU` are held by the KERNEL, in a
  cgroup v2 group per world, written from the declaration before the
  world's first instruction. The rest of kernel-level enforcement
  (seccomp, a namespace per service) is still a named widening, not a
  v0.1 claim.
- Restart policy is a cap of 5 in v0.1 (a rehearsal guard); backoff and
  a declared budget are queued. A real machine's `always` service is
  expected to run, not to exit.
- AFTER waits for READINESS: a `RESTART never` service is ready when it
  has exited 0 (a one-shot); a daemon when spawned, or — if it declares
  `READY "<path>"` — when it creates that path, its own word that it is
  serving (RDY-1). A failed one-shot and a daemon that never signals
  both block their dependents, and init names them. No timer: a daemon
  that never comes up keeps an A/B trial uncommitted, which is the safe
  outcome. A world that declares `HEALTH <seconds>` owes more than a
  signal: it must REFRESH that path within every window, PID 1 feeds the
  hardware watchdog only while every such world is fresh, and a trial
  commits only once each has been ready through one full window
  (HLT-1). Staleness latches, because a feed that resumed on recovery
  would hide the fault the watchdog exists for. A bounded window for the
  TRIAL itself -- a cap on how long a trial may take to become ready --
  is still a named seam.
- The machine judges its own BOOT, not its life: the verdict comes once,
  when every service is ready, over what init said about the machine
  until then (mounts, capabilities, networks, the watchdog, starts,
  exits). The card's state (a trial, or steady), the instrument, the
  verdict itself and everything after readiness are not judged by the
  machine; the court's transcript judges those. Order is not judged
  (AFTER enforces it); count is. No expectation in the image is no
  verdict, and a trial without a verdict is not committed. A health
  seat beyond the boot -- a service's own word later in its life -- is a
  named seam (JDG-1).
- Identities: a service runs as a declared USER when it names one, and
  as the machine itself when it says nothing (USR-1). uid 0 cannot be
  declared, so root is visible as the absence of a line rather than as
  a choice. The per-DEVICE identity is a different thing and exists
  since IDN-1: `IDENTITY <path>` on a hosted machine, an Ed25519 pair
  made on first boot and kept on a declared persistent mount, with the
  algorithm and the custody SAID in the transcript rather than implied
  (MicroRing's finding: hardware custody and algorithm are coupled, and
  a key held in silicon may be a P-256 key). What is not claimed: the
  private half is never sent because no code here sends it, and the file
  is the machine's own -- not because hardware prevents reading it. A
  key in a secure element is the seam, and it is the edge profile's
  question first.
