# stzos — the declared machine

The operating layer of the Softanza vertical: the machine beneath
[stz](../stz). A machine is DECLARED — its profile, the capabilities it
grants and refuses, its mounts, its pins, the services it keeps alive —
in a closed language (`.machine`) that is itself declared in stzu and
judged by pinned fixtures. From the judged declaration a boot plan is
derived; on a hosted machine one static binary, `stzos`, executes that
plan as PID 1 and narrates the boot as a transcript. No shell, no
package manager, no init scripts: the declared machine IS the system.

**Status: OS-4, the box has a board and a card.** The Makeen box is a
Raspberry Pi 4 Model B (`doc/PROVENANCE.md`, the board ruling). Its
`.machine` file names the board, and from it the pipeline derives the
BCM2711 kernel, the card's device tree (mainline plus the mmc aliases
that make `/dev/mmcblk0p2` a fact), the emulator's tree, and a flashable
256 MiB SD image with the board's firmware, the kernel, the initramfs
and an ext4 `/data`. The same board emulated by QEMU (`raspi4b`) boots
that image and is judged against a pinned transcript; two other
declared machines (x86_64 and aarch64 `virt`) boot and are judged the
same way, with stzr running Luau worlds inside. Private. The name `stzos` is
provisional until the landscape ruling (`doc/PROVENANCE.md`). The
strategy that this repository serves is the Vision Corpus
(`D:\GitHub\softanza\vision`); the OS chapter it proposes is
`doc/VISION.md`.

## What exists today

| piece | where | judged by |
|---|---|---|
| the machine language v0.1 — grammar, five kinds, closed menus | `declarative/machine/GRAMMAR.md` | 40 pinned fixtures, `zig build court` |
| the language declared in stzu | `declarative/machine/machine.stzu` | stz's own meta-court (`experiment/judge_machine_stzu.luau`) |
| the parser and the court-side checks | `src/machine.zig` | unit tests + fixtures |
| the boot plan, derived and rendered | `src/plan.zig` | fixtures (order, granted set) |
| the init — PID 1 of a hosted machine | `src/init.zig` | its own boot transcript, run as PID 1 under WSL (`experiment/wsl_boot.sh`) |
| one static binary, every role, two Linux targets by one flag | `build.zig` (`zig build cross`) | the cross build is the gate on the Linux-only code |
| the image, derived: initramfs list, kernel fragment, boot line | `src/image.zig` (`stzos image`) | the QEMU boot transcript against `machines/qemu_hello.expected` |
| the vendored kernel, pinned by digest | `vendor/PIN.md`, `experiment/os2_kernel_fetch.sh` | sha256 from kernel.org's own sums |
| the imperative half: kernel build, cpio, QEMU, the judge | `experiment/os2_image.sh` (WSL Ubuntu) | `zig-out/wsl/image_<name>.txt` |
| the reference machines | `machines/` | `makeen_box.machine` (BOARD rpi4, fixture A2 verbatim), `qemu_hello.machine` (x86_64) and `makeen_qemu.machine` (aarch64 `virt`) all boot and are judged against their `.expected` |
| the board's card: firmware pinned, two derived device trees, the SD image | `experiment/os2_image.sh`, `experiment/dtb_ops.py`, `vendor/rpi-firmware/PIN.txt` | the `raspi4b` boot transcript, 17 lines |
| `stzos net`, the box's own interface bring-up | `src/net.zig` | unit tests; the boot transcript (NODEV in the emulator, by design) |

## Three profiles, one language

| profile | substrate | init | state |
|---|---|---|---|
| **hosted** | a vendored Linux kernel, static musl userland, this binary as PID 1 | `stzos init` | **boots** on x86_64 and aarch64 in QEMU and as the Raspberry Pi 4 image under `raspi4b`, transcripts judged; the card has not met a Pi yet |
| **edge** | no kernel: the binary is the device (MicroRing's substrate — MicroZig, littlefs) | the cooperative loop | declarable, judged; not yet bootable |
| **touch** | Android's kernel and init (AOSP fork, ZinOS Touch's design) | Android's, the launcher is the pack | declarable, judged; unbuilt |

## Commands

```
zig build -j2                       # zig-out/bin/stzos (host CLI)
zig build test -j2                  # the unit tests
zig build court -j2                 # the fixture court: 40/40
zig build cross -j2                 # zig-out/cross/{x86_64,aarch64}-linux-musl/stzos, static
zig-out\bin\stzos.exe plan machines\makeen_box.machine
wsl -d Ubuntu -- bash /mnt/d/GitHub/stzos/experiment/wsl_boot.sh   # rehearsal + PID 1 in a namespace, transcripts in zig-out/wsl/
wsl -d Ubuntu -- bash /mnt/d/GitHub/stzos/experiment/os2_env.sh    # once: gcc, make, qemu, flex, bison...
wsl -d Ubuntu -- bash /mnt/d/GitHub/stzos/experiment/os2_kernel_fetch.sh   # once: the pinned kernel tarball
wsl -d Ubuntu -- bash /mnt/d/GitHub/stzos/experiment/os2_image.sh qemu_hello   # x86_64: image + kernel + QEMU boot + judge
wsl -d Ubuntu -- bash /mnt/d/GitHub/stzos/experiment/os2_image.sh makeen_qemu  # aarch64: the Makeen box on virt, with its ext4 /data
wsl -d Ubuntu -- bash /mnt/d/GitHub/stzos/experiment/os2_image.sh makeen_box   # the Raspberry Pi 4 card: zig-out/image/makeen_box/sd.img, judged under raspi4b
```

To flash the card (from any Linux, the device being the whole card):

```
dd if=zig-out/image/makeen_box/sd.img of=/dev/sdX bs=4M conv=fsync
```

The runtime the services run is stz's, cross-built for each image from
`D:\GitHub\stz` (the triple is derived from the machine's ARCH):

```
zig build -Dtarget=x86_64-linux-musl -Doptimize=ReleaseSmall -j2 --prefix D:\GitHub\stzos\zig-out\stz-x86_64-linux-musl
zig build -Dtarget=aarch64-linux-musl -Doptimize=ReleaseSmall -j2 --prefix D:\GitHub\stzos\zig-out\stz-aarch64-linux-musl
```

From `D:\GitHub\stz`, the language's own declaration judged by the
family's meta-court:

```
zig-out\bin\stzr.exe ..\stzos\experiment\judge_machine_stzu.luau
```

## Doctrine (inherited whole from the estate)

- **Fixtures are the judge.** Expectations are never adapted to pass;
  the court's first run convicted this implementation on one refusal's
  wording and the implementation changed, not the fixture.
- **Coverage is stated by the mechanism.** The init prints which pid it
  is, which mounts the kernel refused and why, which policy restarted
  what. A skipped gate is named.
- **Closed grammars have no host escape.** A service is an argv, never
  a shell line; the boot path ships no shell.
- **Sovereignty is decided per dependency**, never claimed wholesale:
  `doc/ARCHITECTURE.md` carries the table (kernel: vendored source
  rebuilt by our toolchain; init: ours; package manager: none).
- **The transcript is the fixture.** A machine that boots differently
  prints differently; outputs are rendered from the run, never stored.

## Reading order

`doc/VISION.md` (why an OS, and what one is in Softanza's terms) →
`doc/ARCHITECTURE.md` (the pipeline, the profiles, the sovereignty
table, the court) → `declarative/machine/GRAMMAR.md` (the language) →
`experiment/PROTOCOL.md` (what was done, measured, and found) →
`doc/PROVENANCE.md` (what was read, what stands in the way, the name).
