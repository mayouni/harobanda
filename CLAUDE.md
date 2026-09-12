# stzos — Claude operating notes

## What this repository is

The operating layer of the Softanza vertical: the machine beneath stz.
Private; created 2026-09-12 on the author's ruling to push the sovereign
stack below Ring++ to the operating system, then MicroRing, then the
PCB. **Read `doc/VISION.md` and `doc/PROVENANCE.md` before any
strategic claim**; the ratified strategy of the whole estate is the
Vision Corpus at `D:\GitHub\softanza\vision` (its README still says the
stack is Luau; the memos of 2026-08-30 onward supersede it with Ring++,
and the memo of 2026-09-12 11:02 opens the OS turn). Daily memos go to
`D:\GitHub\softanza\memos\YYYY-MM-DD.md` in the estate's yaml style,
`by:` stamp read from the clock, never composed.

**The name is provisional.** The author said the landscape's final
shape, structure and naming are decided later at a critical point.
Never rename on your own; never let two names for one thing coexist
silently (ZinOS, Zos, MakeenOS and Device all exist in the estate —
`doc/PROVENANCE.md` lists them).

## Relations (donors, not dependencies)

- **stz** (`D:\GitHub\stz`) — the distribution this machine boots;
  stzr is what the services run. `machine.stzu` is judged by stz's
  `face/stz/Stzu.luau` through `experiment/judge_machine_stzu.luau`,
  run from stz's directory. Nothing is forked.
- **stzlib's System Foundation** (`stzlib/libraries/stzlib/base/system`,
  design in `base/doc/design/SOFTANZA_SYSTEM_FOUNDATION.md`) — the OS
  model as a virtual twin: the capability vocabulary here is its nine
  names verbatim; rehearse-plan-commit is its law.
- **zin's ZinOS documents** (`zin/doc/vision/ZIN_OS_VISION_v1_0.md`,
  `zin/doc/architecture/ZINOS_ARCHITECTURE_v1_0.md`,
  `zin/doc/design/ZINOS_EDGE_DESIGN.md`) — the Edge and Touch profiles
  are theirs, kept; the hosted profile is this repository's addition.
- **microring** — the edge substrate (MicroZig, littlefs, the tiers);
  `stzos init` refuses the edge profile by name and says whose it is.
- **restolean** (`livrable/makeen/`) — the customer pull: the Makeen
  box is `machines/makeen_box.machine`.
- **ringpp** — Ring++ dropped bare metal from its brief on purpose
  (`docs/DESIGN_BUILD.md:226`); Linux-class devices stay in. This
  repository does not reopen that; the edge profile is MicroRing's.

## Commands

```
zig build -j2 && zig build test -j2 && zig build court -j2 && zig build cross -j2
zig-out\bin\stzos.exe check|plan machines\<name>.machine
wsl -d Ubuntu -- bash /mnt/d/GitHub/stzos/experiment/wsl_boot.sh    # then read zig-out/wsl/*.txt
wsl -d Ubuntu -- bash /mnt/d/GitHub/stzos/experiment/os2_image.sh qemu_hello   # image, kernel, QEMU boot, judge -> zig-out/wsl/image_qemu_hello.txt
cd D:\GitHub\stz; zig build -Dtarget=x86_64-linux-musl -Doptimize=ReleaseSmall -j2 --prefix D:\GitHub\stzos\zig-out\stz-x86_64-linux-musl   # stzr for the image
```

`zig build cross` is not optional: `src/init.zig` is comptime-gated on
Linux and Zig analyses only the taken side, so a Windows build proves
nothing about the init (the MicroRing injection finding, 2026-08-20).

## Doctrine (each line was paid for, here or upstream)

- **Fixtures are the judge**; re-pin `declarative/machine/PINNING.md`
  (sha256) in the same commit that changes `fixtures.json`. Every
  reject carries the fragment its refusal must contain.
- **Assert the mechanism** — the court was probed with a mutated judge
  in fresh processes (wrong count, wrong fragment, valid source posing
  as reject → three reds) before its scoreboard was written.
- **Closed grammars have no host escape.** A shell is refused by name
  in RUN; do not add a command-string form, an env-expansion, a hook.
- **The transcript is the fixture; it is never stored.** Rendered from
  the run into `zig-out/`, gitignored.
- **One binary, every role.** The CLI and PID 1 are the same static
  executable; do not split them.

## Machine and shell traps (cost real time)

- **This machine freezes under memory pressure.** Always `-j2`, one
  heavy job at a time, never background a build.
- **WSL output through the PowerShell tool is mangled** (UTF-16 chars
  dropped, lines spliced). Never read a WSL run's stdout; have the
  script write to `zig-out/wsl/*.txt` on the Windows-visible mount and
  read the files. Quoting a multi-command `bash -c` through wsl.exe
  also breaks: put the commands in a `.sh` file with LF endings.
- **Zig 0.15 `File.Writer` writes POSITIONALLY on a seekable stdout.**
  Redirect `stzos ... > file` and the writer starts at offset 0,
  overwriting whatever the shell wrote before. Found on the first WSL
  transcript (`experiment/PROTOCOL.md`, OS-1). The fix is the
  streaming writer; keep it.
- **Inside `unshare -Urpf`** (a user namespace without root) `proc`
  mounts, `sysfs` and `devtmpfs` are refused with PERM. That is the
  kernel's rule, not a defect; the transcript states it.
- **WSL Ubuntu has the OS-2 toolchain since 2026-09-12** (gcc 15.2,
  make 4.4, QEMU 10.2, flex, bison, bc, libelf, libssl, cpio), installed
  by `experiment/os2_env.sh` on the author's ruling. **Port 80 is blocked
  on this network** (http times out, https answers): apt's sources were
  switched to https by that script; `curl -4` over https works.
- **Never extract or build the kernel on the Windows mount.** drvfs is
  an order of magnitude slower; `os2_image.sh` extracts into `$HOME`
  inside WSL. The tarball and its pin stay in `vendor/linux/`
  (gitignored, 142 MB; `vendor/PIN.md` is the record).
- **`rdinit=`, never `init=`, on the boot line**: the root is the
  initramfs; `init=` sends the kernel to mount a root device, which
  panics as soon as the kernel has a block layer (OS-3 finding 1).
- **A kconfig fragment must open the MENUS its drivers live under**
  (`BLOCK`, `BLK_DEV`, `VIRTIO_MENU`), or `olddefconfig` drops the
  drivers silently; the build prints every requested option that did
  not survive. Read that list before reading a mount refusal.
- **QEMU's raspi4b does not model the AON block at 0x7ef00000** (the L2
  interrupt controller, the DVP clock): a driver touching it takes a
  synchronous external abort with NO console output. The emulator's
  device tree (`QEMU_DTB_OPS`, derived) disables those nodes; the
  card's tree does not. To diagnose a silent raspi4b boot:
  `experiment/os4_diag.sh` (earlycon, full log, `initcall_debug`) and
  `experiment/os4_syms.sh <addr>` against `System.map`.
- **QEMU plugs the SD card into the legacy SDHCI at 0x7e300000**, not
  emmc2; mainline gives that host to the Wi-Fi SDIO. The emulator's
  tree opens it and aliases mmc0 to it; the card's tree aliases mmc0 to
  emmc2. Both derived, both printed at build time.
- **A one-line `bash -c` through `wsl.exe` loses `$` and `&`** whichever
  tool sends it. Every WSL act is a script file under `experiment/`.
- **QEMU under `timeout` from a real terminal STOPS silently.** With a
  tty on stdin, `-nographic` sets raw mode; in `timeout`'s background
  process group that is SIGTTOU, and QEMU sits stopped until the timeout
  kills it -- the author's first run showed nothing for three minutes.
  `os2_image.sh` now runs QEMU with stdin from /dev/null under `timeout
  --foreground`, streams its log to the terminal through `tee`, and
  `experiment/os2_tty_probe.sh` proves it under a pseudo-terminal (22 s).
  `experiment/wsl_cleanup.sh` ends what a closed terminal left behind.
- **Invoke WSL scripts from PowerShell, never from the Bash tool** —
  git-bash rewrites `/mnt/d/...` into `C:/Git/mnt/...`
  (`MSYS_NO_PATHCONV=1 wsl.exe ...` is the workaround if you must).

## Next steps (author-ordered, one per session)

- **OS-5 — the card meets the board**: flash `zig-out/image/makeen_box/
  sd.img` to a card, boot a Raspberry Pi 4 with the mini-UART on the
  header pins (GPIO 14/15, 115200), and judge the real transcript
  against `machines/makeen_box.expected` — it is expected to differ
  exactly where the emulator lacks the hardware (Ethernet up, the
  worlds starting) and nowhere else. Then A/B slots with watchdog
  rollback (the watchdog driver is in), and the NETWORK kind (DHCP,
  gateway, DNS) beyond `stzos net`'s static address.
- The kernel rebuilt with `make CC="zig cc"` (the stated sovereignty
  destination; gcc did the first boot) and a tarball mirror inside the
  estate.
- The NETWORK kind and the USER seat (fixture-first widenings); a
  readiness/completion seat beside AFTER (which orders starts only).
- The edge profile's boot through MicroRing's substrate (Device seam).
- The OS chapter into the Vision Corpus, with the 08-30 Ring++ turn the
  corpus still lacks; the three standing refusals ruled on by name.
