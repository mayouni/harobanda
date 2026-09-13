# stzos — Claude operating notes

## What this repository is

The operating layer of the Softanza vertical: the machine beneath stz.
Private; created 2026-09-12 on the author's ruling to push the sovereign
stack below Ring++ to the operating system, then MicroRing, then the
PCB. **Read `doc/VISION.md` and `doc/PROVENANCE.md` before any
strategic claim**, `doc/GROUND.md` for what the machine is FOR (the
solutions it is the floor of, and the tools that meet at that floor),
and `doc/DIVIDEND.md` for what owning the floor gives each layer above
it (the servers, the runtime, the intelligence modules, the pages, the
flagships) and what each owes it, didactic, one example per layer; the
estate-wide reflection that places the floor in the author's 2020
diagram is `softanza/vision/08-NORTH-STAR.md` (draft), and the story of
the two days that built the floor and read the diagram again is
`doc/narrations/the-floor-and-the-north-star.md`; the ratified strategy of the whole estate is the
Vision Corpus at `D:\GitHub\softanza\vision` (amended 2026-09-12 for the
Ring++ turn of 08-30 -- Amended blocks beside the superseded sentences --
and carrying the floor as `07-SYSTEM.md`, v0.1 DRAFT, unratified). Daily memos go to
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
- **A generated artifact is judged by what CONSUMES it**, never only by
  a diff against the same generator's earlier output: both sides can be
  wrong in the same way and the court stays green. QEMU judges the
  images; MicroRing judges the projection (PRJ-2, where a diff passed a
  file Ring could not parse).
- **The machine judges its own boot** (JDG-1): the image carries
  `/etc/expected`, derived from the plan; PID 1 records what it says
  and judges the two when every service is ready; a trial commits only
  on a match, and no expectation is no commit. Each judged line is
  worded ONCE in `src/expect.zig` for init and the derivation alike --
  never reword one side. The emulator's lacks are a `Lens` per board
  (`qemu_lens`), never a loosened comparison.
- **Alive is not serving** (HLT-1): a world with `HEALTH <seconds>`
  must refresh its READY path within every window; PID 1 feeds the
  hardware watchdog ONLY while every such world is fresh, and a trial
  commits only once each has been ready through one full window.
  Staleness LATCHES -- never resume the feed on recovery, or the
  watchdog guards nothing.
- **A daemon never exits, so an init that waits for an exit learns
  nothing more** (SRV-1): PID 1 POLLS while the watchdog needs feeding,
  a declared signal is outstanding, a service has not started yet, or a
  verdict is owed -- never blocks on `wait4` on a served machine. A
  world's READY path is its LAST act (a print after it lets PID 1's own
  line overtake it, and an order that depends on a 250 ms poll is not a
  fixture). `--halt-on-verdict` is DERIVED onto the emulator's boot line
  for any machine with a non-one-shot service; the card's cmdline.txt
  never carries it.
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
- **QEMU's raspi4b resets the board the moment `/dev/watchdog` is
  opened**: its power-management model has no countdown and reads the
  driver's "full reset on expiry" bit as "reset now". The emulator's
  boot line carries `stzos.watchdog=off` (derived; never the card's
  cmdline.txt) and PID 1 flushes before arming. A boot that ends
  silently right after the capability lines is this.
- **mtools asks on stdin when a name clashes** (`mmd` on an existing
  directory, `mcopy` over a file): on a pipe that never closes it hangs
  forever (33 minutes, AB-1). Every mtools call runs with `-D s`/`-D o`
  and `< /dev/null`; `wsl_cleanup.sh` ends a stuck one.
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
  header pins (GPIO 14/15, 115200), and read two verdicts: the board's
  own (`judge -- the boot matches its expectation (/etc/expected, 16
  lines)`, the text `zig-out/image/makeen_box/expected` derived through
  the board's lens), and the court's, the real transcript against
  `machines/makeen_box.expected` — expected to differ exactly where the
  emulator lacks the hardware (the network up, the watchdog armed: the
  two lines the build prints as the emulator's lacks) and nowhere else,
  which the board's own verdict now states; the hardware watchdog's real
  countdown (the emulator cannot arm it); and the tryboot flag, which
  needs a small vendored patch to `bcm2835_wdt.c` (mainline ignores the
  restart argument) -- until then a trial is requested by hand.
- (attempted 2026-09-12, ZIGCC-1) The kernel with `make CC="zig cc"`:
  behind `STZOS_CC=zigcc`, four concessions named in
  `experiment/zigcc_wrapper.sh`, the tree builds, **the image does not
  boot** (it dies in the 16-bit setup code). gcc stays. Do not reopen
  without a newer zig or an LLVM-shaped attempt; the instrument and the
  six probes are kept. The estate's tarball MIRROR is a routed errand
  for the author (availability, not integrity: the digests are pinned).
- (done 2026-09-12, USR-1) The USER seat. The NETWORK kind exists
  since NET-1 (dhcp and static; lease renewal, a resolver, the box as
  DHCP server and IPv6 are its named seams) and READY since RDY-1 (a
  daemon's own signal, no timer). The health seat is HEALTH since
  HLT-1 (2026-09-13); a bounded window for the TRIAL itself is still a
  seam.
- (done 2026-09-12, PRJ-1) The edge profile's projection onto
  MicroRing's substrate: `stzos project` writes a real `device.ring`,
  judged by `experiment/judge_project.sh`. What remains is the Device
  LANGUAGE (behaviour: the every/on handlers), which is an L2 member
  and not this repository's to invent.
- (done 2026-09-12) The OS chapter is `softanza/vision/07-SYSTEM.md`
  (v0.1 DRAFT, unratified) with the corpus amended for the 08-30 Ring++
  turn; the three refusals are ruled in `doc/PROVENANCE.md`. Both wait
  on the author's ratification; the author reverses by name.
