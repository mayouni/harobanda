# OS-4 — the real box: a Raspberry Pi 4, its SD card image, and the same board emulated to judge it

Ordered by the author on 2026-09-12 ("choose the board on my behalf and
go for OS-4"). The board ruling is in `doc/PROVENANCE.md`
(STZ-OS-BOARD-01): the Raspberry Pi 4 Model B.

## What was built

- **The BOARD clause**, fixture-first: `qemu_pc`, `qemu_virt`, `rpi4`,
  defaulting by ARCH, hosted-only, coherent with ARCH; A9, R33, R34, R35
  are the board's own, A1/A3 carry the defaults, A2 is
  `machines/makeen_box.machine` verbatim with `BOARD rpi4`. **44/44**;
  the court convicted the implementation once on R35 (the ARCH check
  ran before the profile check; reordered, the fixture kept).
  `machine.stzu` carries the seat; the plan and the init print the board.
- **`stzos net <iface> <a.b.c.d>/<n>`** (`src/net.zig`): a role of the one
  binary — four ioctls on a datagram socket, every result stated, no
  DHCP, no gateway, no DNS. The box's `network_up` service is now a
  program that exists: `RUN ["/stzos", "net", "eth0", "192.168.10.1/24"]`.
- **The rpi4 target** (`src/image.zig`): the arm64 kernel with the
  BCM2711 platform, the mini-UART and PL011, the mailbox and firmware
  driver, the watchdog (which is also how the board restarts), SDHCI
  for the card, GENET for Ethernet; the device tree
  `bcm2711-rpi-4-b.dtb`; two consoles (`ttyAMA0` for the emulator's
  PL011 on the header pins, `ttyS1,115200` for the board's mini-UART
  there); `sd.list` (the card's partitions and the boot partition's
  files), `config.txt` and `cmdline.txt` written by the derivation.
- **Two device trees from mainline's, both derived** (`DTB_OPS` and
  `QEMU_DTB_OPS` in `image.env`, applied by `experiment/dtb_ops.py`,
  every op printed): the CARD's tree adds the mmc aliases mainline
  lacks, so `/dev/mmcblk0p2` is a fact and not a probe-order race; the
  EMULATOR's tree disables the two AON blocks QEMU does not model and
  opens the legacy SDHCI where QEMU plugs the card, aliased as mmc0 so
  the declared device name holds in both worlds.
- **The SD card image** (`experiment/os2_image.sh`): a 256 MiB card
  (QEMU wants a power of two), p1 FAT32 64 MiB with the firmware's
  `start4.elf`/`fixup4.dat` (raspberrypi/firmware, tag `1.20260907`,
  pinned by sha256 in `vendor/rpi-firmware/PIN.txt`, gitignored),
  `config.txt`, `cmdline.txt`, `kernel8.img`, the card's DTB, the
  initramfs; p2 ext4 64 MiB, the declared `/data`. `sd.img` is what a
  card gets `dd`'d with.
- **The judge**, unchanged: the same board under QEMU `raspi4b`, the
  transcript against `machines/makeen_box.expected`.

## What was measured

- arm64 kernel for the board: 689 options, `Image` 5.6 MB, **2m50** wall
  at two jobs for the first build; the card 256 MiB; the initramfs
  4.4 MB.
- Boot under `raspi4b` (QEMU 10.2 TCG): `Machine model: Raspberry Pi 4
  Model B`; PID 1; `proc` `sysfs` `devtmpfs` done; **`mmcblk0: p1 p2`,
  `ext4 at /data -- done`** on the card's second partition by its
  declared name; `gpio` refused as declared; `network_up` ran `stzos
  net eth0` and got **`no such interface (NODEV)`** — QEMU disables
  GENET itself, the emulator has no Ethernet — so `kds` and `poste`
  **never started** by the readiness rule, named; `reboot(RESTART)`
  through the BCM2835 watchdog; QEMU exit 0. Pinned, 17 lines: the
  emulator's truth. On the board, Ethernet exists and the worlds start;
  that difference is OS-5's first finding, expected and stated.

## What was found

1. **QEMU's raspi4b faults on the AON block.** The first boot printed
   nothing: `brcmstb_l2_intc_of_init` took a synchronous external abort
   at 0x7ef00100 (the AON L2 interrupt controller); with it disabled,
   `clk_disable_unused` took the same abort in `clk_gate_readl` on the
   DVP clock at 0x7ef00000. Found with `earlycon=pl011,mmio32,0xfe201000`,
   `initcall_debug`, and `System.map` (tinyconfig has no KALLSYMS;
   `experiment/os4_syms.sh` resolves the addresses). QEMU disables pcie,
   rng, thermal and genet on its own; these two it misses. Both are
   named in the emulator's tree and nowhere else.
2. **QEMU plugs the card into the legacy SDHCI**, not into emmc2 where
   the board's card sits; mainline gives that host to the Wi-Fi SDIO
   (non-removable, with a power sequence). The emulator's tree opens it
   as a plain removable host. `mmc0: SDHCI controller on fe300000.mmc`,
   `mmcblk0: mmc0:2804 QEMU! 256 MiB`.
3. **Mainline's rpi-4-b tree has no mmc aliases**, so the card's index
   is probe order once the Wi-Fi host probes too. The board's tree pins
   `mmc0` to emmc2. A declared device name must be a fact.
4. **The mini-UART driver hides behind two menus** (`SERIAL_8250_EXTENDED`,
   `SERIAL_8250_SHARE_IRQ`); the build's dropped-option check named it.
5. **QEMU's SD model wants a power-of-two card**; the first 130 MiB
   image was refused. 256 MiB, partitions at the front.
6. **The Bash tool cannot pass `$` or `&` through `wsl.exe`** in a
   one-line `bash -c`; every WSL act is a script file.

## Named seams

- The board itself: this card has not touched a Pi. The first real boot
  will differ from the pin where the emulator lacks the hardware
  (Ethernet, the AON block) and nowhere else, or that is a finding.
- The Wi-Fi firmware blob (not taken); DHCP, gateway, DNS (the NETWORK
  kind); A/B slots with watchdog rollback (the watchdog driver is in);
  `make CC="zig cc"`; the judge into `stzos judge`.

---

# OS-3 — the Makeen box: the aarch64 image, a persistent partition, and AFTER made deterministic

Ordered by the author on 2026-09-12 ("take decision on my behalf on the
waiting rows, and then go for OS-3, the aarch64 image for the Makeen
box"). The three rulings are in `doc/PROVENANCE.md` ("The rulings of
2026-09-12"); the mailbox is `softanza/mailbox/stzos.md`.

## What was built

- **`stzos image` for aarch64**: one `Target` table per architecture
  (kernel ARCH and cross prefix, the kernel artifact, the QEMU machine,
  the console, the serial and block kconfig, the virtio transport —
  virtio-mmio on `virt`, virtio-pci on `pc`). The derivation now emits
  `image.env` (what the build must be told, written from the
  declaration alone before any staging check) and `disk.list` (the
  block devices the declared mounts need; one per image today, a
  second is refused by name). The boot line carries the virtio disk.
- **`experiment/os2_image.sh` made arch-aware**: one kernel tree per
  ARCH under `$HOME`, the cross compiler from the derived prefix, the
  kernel artifact by its derived path, the disks made with `mkfs` from
  `disk.list`, and a check that every option the fragment asked for
  survived `olddefconfig` — a dropped one is named as a missing
  dependency.
- **`machines/makeen_qemu.machine`**: the Makeen box as QEMU's `virt`
  can carry it — aarch64, the PL011 console, a 64 MB ext4 disk at
  `/data` on `/dev/vda`, the `kds` and `poste` worlds as stzr services.
  `makeen_box.machine` (fixture A2) stays the box's own truth with its
  SD-card partition and its network service; the two converge when the
  box is real.
- **stzr for aarch64**: stz's runtime cross-built for aarch64-linux-musl
  (764 KB static) with one flag; the toolchain in WSL gained
  `gcc-aarch64-linux-gnu`, `qemu-system-arm`, `e2fsprogs`.
- **AFTER waits for readiness** (`src/init.zig`): a one-shot (`RESTART
  never`) is ready when it has exited 0, a daemon (`always`,
  `on_failure`) as soon as it is spawned; a one-shot that fails blocks
  its dependents for good and init names them (`never started -- it
  comes AFTER x, which exited 1`). Services start when eligible, from
  the reaper loop, in plan order. `GRAMMAR.md` carries the rule.

## What was measured

- arm64 kernel: 531 options, `Image` 3,768,328 bytes, **2m01 s** wall at
  two jobs for the first build (3m27 user), 27 s for the reconfigure.
- Boot on `virt` (cortex-a53, 512 MB, TCG): PID 1, `proc` `sysfs`
  `devtmpfs` done, **`ext4 at /data -- done`** on the virtio disk,
  `gpio` refused as declared, `kds` read the machine file that rode in
  the image (7 declarations), `poste` started only after `kds` exited 0,
  both exited 0, `reboot(RESTART)`, QEMU exit 0. Pinned:
  `machines/makeen_qemu.expected`, 20 lines.
- x86 re-judged under the readiness rule: `hello` now starts after
  `self` exits, the transcript is deterministic; `qemu_hello.expected`
  re-pinned in this commit for that named reason (28 lines).

## What was found

1. **`init=` was the wrong parameter and x86 booted by accident.** The
   root IS the initramfs; with `init=` the kernel looks for `/init`,
   finds none, and goes to mount a root DEVICE. The x86 kernel had no
   block layer, so `mount_root` did nothing and the boot proceeded; the
   arm64 kernel had `CONFIG_BLOCK` for its ext4 mount and panicked
   `VFS: Unable to mount root fs on unknown-block(0,0)`. `rdinit=` is
   the honest parameter and both machines boot with it.
2. **Menus tinyconfig closes drop the fragment's drivers silently.**
   `CONFIG_VIRTIO_BLK=y` and `CONFIG_VIRTIO_MMIO=y` vanished under
   `olddefconfig` because `VIRTIO_MENU`, `BLK_DEV` and `BLOCK` were off;
   the mount failed `NOENT` with no other symptom. The fragment now
   names the three, and the build prints every requested option that
   did not survive.
3. **AFTER only ordered spawns**, and the x86 judge caught it on the
   third boot (the exit lines of `self` and `hello` swapped). The
   readiness rule replaces it; both expectations were re-pinned in the
   same commit as the rule, for that stated reason.
4. **`reboot(RESTART)` inside a pid namespace ends the namespace**: the
   kernel sends the namespace's init SIGHUP instead of rebooting, so the
   WSL PID 1 transcript stops at the `init halts the machine` line and
   `unshare` exits nonzero. The kernel's rule, not a defect; the init's
   comment says so.

## Named seams

- The real box: a board's kernel config and device tree, U-Boot, the SD
  card's partitions (`makeen_box.machine` names `/dev/mmcblk0p2`), A/B
  slots with watchdog rollback.
- The NETWORK kind (`network_up` in A2 names a program that does not
  exist); the USER seat.
- `make CC="zig cc"` for both kernels; a tarball mirror in the estate.
- The judge into `stzos judge`; one virtio disk per image today.

---

# OS-2 — the machine boots: a vendored kernel, an image derived from the plan, QEMU, the transcript judged

Ordered by the author on 2026-09-12 ("install qemu, gcc and make in WSL
and go for OS-2"), the same day as OS-1.

## What was built

- **`stzos image`** (`src/image.zig`): from a judged plan, three texts
  and no toolchain — `initramfs.list` in the kernel's own gen_init_cpio
  format (device nodes for PID 1, the mount points, `/stzos`, every
  program and file the services name taken from a staging root and
  REFUSED if absent, the declaration itself at `/etc/machine`),
  `kernel.fragment` (the kconfig the profile and the declared mounts
  need, merged over tinyconfig), `boot.cmd` (the QEMU line). Hosted and
  x86_64 only today; the rest refused by name.
- **The init's ending** (`src/init.zig`): PID 1 may not exit, so when
  every service has ended it calls `reboot(RESTART)`; under QEMU
  `-no-reboot` that closes the boot and the transcript. In a user
  namespace the kernel refuses it and the transcript says so.
- **The vendored kernel**: Linux 6.12.109 LTS, pinned by digest from
  kernel.org's own `sha256sums.asc` (`vendor/PIN.md`,
  `experiment/os2_kernel_fetch.sh`); the tarball stays out of git (over
  the file limit) and in `vendor/linux/`.
- **The imperative half** (`experiment/os2_image.sh`, WSL Ubuntu):
  stage, derive, tinyconfig + fragment + olddefconfig, `make -j2
  bzImage`, gen_init_cpio, QEMU with the serial console captured, then
  the judge: the transcript normalised (firmware banner and control
  bytes before PID 1's first line, CRs, pids → N) and diffed against
  `machines/qemu_hello.expected`.
- **stzr in the image**: stz's runtime cross-built from `D:\GitHub\stz`
  for x86_64-linux-musl (static, 776 KB, ReleaseSmall) with one flag —
  the first time the Softanza runtime ran on a machine the estate
  declared.

## What was measured

- Kernel: 496 options on, bzImage 1,217,536 bytes, **78 s wall** at two
  jobs (2m08 user) on WSL Ubuntu, gcc 15.2.
- Image: initramfs 4,232,704 bytes — stzos 3.4 MB unstripped, stzr
  776 KB, hello.luau, the machine file.
- Boot (QEMU 10.2, TCG, 256 MB): PID 1, `proc` `sysfs` `devtmpfs`
  `tmpfs` all mounted (`done` × 4 — the namespace refusals of OS-1 were
  the namespace's, not the init's), `self` (pid 15) printed the
  machine's own plan from inside the image, `hello` (pid 16) printed two
  lines from Luau under stzr, both exited 0, `reboot(RESTART)`, QEMU
  exit 0. **The transcript matches the pinned expectation line for
  line, 28 lines**, on the second run (the first run IS the pin, stated
  as such: there was no earlier oracle for a machine that had never
  booted).

## What was found

1. **Port 80 is blocked on this network**: apt over http timed out on
   every mirror address while https answered 200; the toolchain script
   switches Ubuntu's sources to https. `Acquire::ForceIPv4` was a wrong
   first diagnosis (the addresses shown were IPv6, the cause was the
   port).
2. **Extracting the kernel onto the Windows mount took longer than the
   600 s tool budget** and the build there would have been slower
   still; the pipeline extracts and builds in `$HOME` inside WSL, and
   the 1.6 GB stray extraction on the mount was removed.
3. **AFTER orders starts, not completions**: `hello` started after
   `self` was spawned, and the two outputs interleave under the
   scheduler. A completion/readiness seat is a fixture-first widening
   (`doc/ARCHITECTURE.md` §7).
4. **The Bash tool rewrites `/mnt/d/...` paths** handed to `wsl.exe`;
   WSL scripts are invoked from PowerShell.

## Named seams

- aarch64 image and real hardware (the Makeen box); block devices and
  persistent mounts (virtio-blk first); A/B slots; the bootloader.
- `make CC="zig cc"` for the kernel; a tarball mirror in the estate.
- The judge lives in a shell script today; folding it into `stzos
  judge <name>` (portable, like the court) is queued.

---

# OS-1 — the declared machine: language, plan, and PID 1

Ordered by the author on 2026-09-12: a distinct private repository for
the operating layer, designed and built in the Softanza style. This
section records what was done, what was measured, and what was found.
Newest section first, as stz's PROTOCOL.md.

## What was built

- **The machine language v0.1** (`declarative/machine/GRAMMAR.md`):
  five kinds — MACHINE, SERVICE, CAPABILITY, MOUNT, PIN — over the
  Grammar Commons' lexical form, every menu closed, the capability
  vocabulary stzlib's nine names verbatim. Judged by `fixtures.json`:
  8 accepts with structural expectations (identity, counts, service
  order, granted set, folded rationale), 32 rejects each carrying the
  fragment its refusal must contain. **40/40** after one correction
  (below). Pinned in `PINNING.md`.
- **The language declared in stzu** (`machine.stzu`) and judged by
  stz's own meta-court through `experiment/judge_machine_stzu.luau`,
  run by stz's runner from stz's directory: accepted first run —
  5 declarations, 4 forms, 0 expressions, 3 refusals, verbs
  CAPABILITY MACHINE MOUNT PIN SERVICE. Nothing forked.
- **The parser and checks** (`src/machine.zig`), **the plan**
  (`src/plan.zig`: console, implicit mounts, declared mounts, every
  capability granted or refused, pins, services in AFTER order with
  declaration order breaking ties), **the court** (`src/court.zig`),
  **the init** (`src/init.zig`: mounts by syscall with each result
  stated, services spawned as argv, PID 1's reaper with the three
  restart policies), and **the CLI** (`src/main.zig`), one static
  binary.
- **Two Linux targets by one flag** (`zig build cross`:
  x86_64-linux-musl and aarch64-linux-musl, static, ~3.4 MB unstripped).

## What was measured

- The court, probed in fresh processes with a mutated judge before its
  scoreboard was believed: a wrong count on A2 → red (`expected 99 got
  3`); a wrong fragment on R5 → red (`refused for the wrong reason`); a
  valid source posing as a reject → red (`accepted as machine 'hello'`).
  Three reds, each for its named reason, exit 1.
- The init on Windows: refuses by name (`init is a Linux act; this
  binary was built for windows`), exit 2.
- The init under WSL Ubuntu, x86_64 static binary run from the Windows
  mount (`experiment/wsl_boot.sh`, transcripts in `zig-out/wsl/`):
  1. from an ordinary pid without `--rehearse`: refused (`init is PID
     1's act; from pid N pass --rehearse`), exit 2;
  2. `--rehearse --turns 8`: the three mounts narrated and not executed,
     `once` exited 0 and stayed down, `flaky` exited 1 and was restarted
     five times then given up on, `steady` exited 0 and was restarted;
  3. **PID 1 for real** inside `unshare -Urpf --mount-proc`: pid 1,
     children pids 2–10, `proc` mounted (`done`), `sysfs` and `devtmpfs`
     refused by the kernel with `PERM` (a user namespace's rule, stated
     not hidden), the same reaper behaviour, ending `init would now halt
     the machine`.

## What was found (each a finding, not a footnote)

1. **The court's first conviction was of its own implementation.** R20
   expected the fragment `no declaration grants gpio`; the refusal said
   `needs gpio, which no declaration grants`. Same meaning, wrong
   words: the G8 gate fired exactly as designed. The message changed,
   the fixture did not.
2. **Zig 0.15's `File.Writer` writes positionally on a seekable
   stdout.** The first WSL transcript had run 2's refusal overwriting
   run 1's header and the shell's `exit` lines spliced mid-sentence:
   with stdout redirected to a regular file, the buffered writer began
   at offset 0 and `pwrite` over what the shell had already appended. A
   console is a character device and never shows it; a redirected
   transcript always does. Fixed by the streaming writer; recorded in
   CLAUDE.md as a trap.
3. **WSL output cannot be read through the PowerShell tool** (UTF-16
   decoding drops and splices lines), and a multi-command `bash -c`
   cannot be quoted through `wsl.exe` from PowerShell. The script
   writes files on the Windows mount; the session reads the files.
4. **Silence is refusal held up at the machine's altitude**: a service
   needing a capability no declaration mentions is refused at check
   time (R17), which is stzlib's `stzSystemScope` down-constrain law
   with the machine as the target.

## Named seams (stated, not hidden)

- The image (kernel + initramfs) and the QEMU boot: OS-2, blocked on a
  Linux build environment on this host.
- NETWORK as a kind; USER as a seat; restart backoff and budget; kernel-
  level enforcement of refused capabilities per service.
- The edge boot through MicroRing's substrate; the touch build.
- The name (`doc/PROVENANCE.md`).
