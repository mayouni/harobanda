# harobanda — Claude operating notes

## What this repository is

The operating layer of the Softanza vertical: the machine beneath stz.
Public since 2026-09-27, on the author's word (`github.com/mayouni/harobanda`,
MIT); created 2026-09-12 on the author's ruling to push the sovereign
stack below Ring++ to the operating system, then MicroRing, then the
PCB. **Read `doc/VISION.md` and `doc/PROVENANCE.md` before any
strategic claim**, `doc/GROUND.md` for what the machine is FOR (the
solutions it is the floor of, and the tools that meet at that floor),
and `doc/DIVIDEND.md` for what owning the floor gives each layer above
it (the servers, the runtime, the intelligence modules, the pages, the
flagships) and what each owes it, didactic, one example per layer; the
estate-wide reflection that places the floor in the author's 2020
diagram is `softanza/vision/08-NORTH-STAR.md` (ratified 2026-09-27), and the story of
the two days that built the floor and read the diagram again is
`doc/narrations/the-floor-and-the-north-star.md`; the ratified strategy of the whole estate is the
Vision Corpus at `D:\GitHub\softanza\vision` (amended 2026-09-12 for the
Ring++ turn of 08-30 -- Amended blocks beside the superseded sentences --
and carrying the floor as `07-SYSTEM.md`, ratified 2026-09-27 by the author's delegation;
every chapter, 01 to 08, is ratified). Daily memos go to
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
  `harb init` refuses the edge profile by name and says whose it is.
- **restolean** (`livrable/makeen/`) — the customer pull: the Makeen
  box is `machines/makeen_box.machine`.
- **ringpp** — Ring++ dropped bare metal from its brief on purpose
  (`docs/DESIGN_BUILD.md:226`); Linux-class devices stay in. This
  repository does not reopen that; the edge profile is MicroRing's.

## Commands

```
zig build -j2 && zig build test -j2 && zig build court -j2 && zig build cross -j2
zig-out\bin\harb.exe check|plan machines\<name>.machine
bash experiment/judge_guarantees.sh [name]   # the four standing promises, judged twice and pinned (GRT-1)
wsl -d Ubuntu -- bash /mnt/d/GitHub/harobanda/experiment/wsl_boot.sh    # then read zig-out/wsl/*.txt
wsl -d Ubuntu -- bash /mnt/d/GitHub/harobanda/experiment/os2_image.sh qemu_hello   # image, kernel, QEMU boot, judge -> zig-out/wsl/image_qemu_hello.txt
wsl -d Ubuntu -- bash /mnt/d/GitHub/harobanda/experiment/os6_names.sh              # TWO machines on one wire: a box that serves names, a till that asks -> zig-out/wsl/names.txt
wsl -d Ubuntu -- bash /mnt/d/GitHub/harobanda/experiment/os7_fleet.sh              # a device publishes its key, a fleet enrols it, its record is verified by something that never held the secret -> zig-out/wsl/fleet.txt
zig-out\bin\harb.exe fleet machines\salle_makeen.fleet     # the roll: who is in the set, and who nobody can speak for yet
zig-out\bin\harb.exe learn                                 # the guided tour: 18 lessons, each with a command, the lines to look for, and a way to BREAK it
zig-out\bin\harb.exe learn 7                               # one lesson in full; `--all` for every one, `--words` for the vocabulary, `--run` where the command is this binary's
cd D:\GitHub\stz; zig build -Dtarget=x86_64-linux-musl -Doptimize=ReleaseSmall -j2 --prefix D:\GitHub\harobanda\zig-out\stz-x86_64-linux-musl   # stzr for the image
```

`zig build cross` is not optional: `src/init.zig` is comptime-gated on
Linux and Zig analyses only the taken side, so a Windows build proves
nothing about the init (the MicroRing injection finding, 2026-08-20).

## Doctrine (each line was paid for; the story of each is in `experiment/PROTOCOL.md` under its tag)

- **A check that asks how a claim is SPELLED is narrower than one that
  asks what it COVERS** (EGR-3): EGR-2 recognised "everywhere" by a
  prefix of 0, and `EGRESS ["0.0.0.0/1", "128.0.0.0/1"]` walked past it
  while the boot announced "nowhere else" over a machine that reached
  8.8.8.8. The grammar now refuses any list whose NETWORKS together cover
  every address (STZ-OS-RULING-06: everywhere is said by declaring no
  EGRESS), and the boot line asks the same `coversEverything` -- never a
  second reading that has to agree. When a guard recognises a claim by
  its shape, ask the question the claim is ABOUT.
- **A key a device no longer holds is trusted THROUGH one entry, and the
  chain draws the line** (RET-1): a card that DIED needs its old records
  checkable; a card that was STOLEN goes on signing with the same key. A
  date would separate them and this floor has no trusted clock, so a
  `RETIREMENT` names the hash of the last entry the fleet verified -- one
  hash fixes every entry before it, and whatever the key signs after can
  only EXTEND the chain, which is refused by position. A record that
  never REACHES the head is refused too: a shorter record and a chain the
  key's holder wrote since both verify, and cannot be told apart. The
  head is printed by the verifier, and only after the chain verifies.
  Proven on a real device: the saved first card, booted again, signed
  entry 2 with the retired key and was refused at entry 2. **A
  verification of nothing is not one** (RET-1, NS-1): an empty record
  said "0 entries verified" and exited 0, so when the arc lost its record
  every negative passed as an attribution.
- **A pin nobody reads is a verdict nobody receives** (PIN-1): the rule
  "re-pin in the commit that changes `fixtures.json`" was kept by people
  remembering, and the rename forgot it -- fixture A3 changed, and the
  pin named the old file for six days of green courts. The court now
  hashes the fixtures before it judges a case and fails on a stale pin
  even when every case passes. Likewise **a log is THIS run's on every
  path, or absent**: `os7_fleet.sh` copied its log as its LAST act, so
  every early `exit 1` left the previous run's green log beside a
  command that said FAIL. And **a verdict a script discards is not
  received** (NAM-2 again): the arc ran the device's own boot with `>
  /dev/null` and never read its exit code.
- **A rename is not a search-and-replace, because a name is not a
  string** (NAME-1): `stzos` named the command you TYPE, the DIRECTORY
  you clone into, and the SYSTEM itself, and one mapping gave all three
  `harb`. Sort by WHAT THE WORD NAMES before replacing any of it and
  expect a different new name for each: **Harobanda** the system,
  **`harb`** the command, **`harobanda`** the repository. Shape is not
  meaning -- `/stzos`, `stzos.slot` and `stzos` sorted cleanly by shape
  and still put two meanings in the wrong place, leaving 94 paths to a
  directory that does not exist. Build, test, both courts and `learn
  --check` were all green over it, because `--check` read a lesson's
  declared `paths` and never the `run` string it tells a reader to type,
  nor the two header lines every lesson prints. **A judge that reads the
  DECLARATION does not judge what is PRINTED** (NAME-1): closed by
  deriving every path in `src/learn.zig` from one `repo` constant, and
  by `--check` asking what origin's URL says this repository is CALLED
  (not what the folder happens to be named -- MNT-1) and scanning the
  RENDERED tour for any `GitHub/` that is not it. Probed with three
  mutations in fresh builds, one finding each.
  **A rename does not touch a dated record, it amends beside it**
  (NAME-1): STZ-OS-RULING-01 chose `stzos` on 2026-09-12 and the rename
  rewrote it, leaving "`stz` is the distribution, the suffix says which
  floor" standing over a name with neither. When a record's own
  reasoning stops fitting its subject, the record was edited.
- **A TUTORIAL is a claim about the system, so it is judged like one**
  (LRN-1): the guided tour lives in `src/learn.zig` beside the verbs it
  teaches, every lesson declares the paths it names, and `zig build
  court` runs `harb learn --check` over them. Anything that tells a
  reader what they will see must fail loudly when that stops being true.
  Each lesson carries a BREAK IT step, because a guarantee only ever
  seen to succeed is a claim and not evidence. **A step that cannot name
  its file, its exact text, its command, its expected answer and its
  UNDO is not a step, it is an assumption about what the reader already
  knows** -- two unit tests hold that shape. Its first reader hit all
  five gaps within the hour and was left with a dirty working tree. And
  a BREAK IT step is RUN before it is promised: three of the first nine
  refused for a different reason than the lesson claimed. **A step that
  boots a machine the reader has EDITED always ends with the pin
  refusing the transcript** -- the loudest thing on their screen, and the
  tour described only the machine's own judge until they reported it.
  That warning is DERIVED from the step (a `.machine` file plus
  `os2_image.sh`), not written per lesson: six needed it.
  **A quotation is the machine's words or it is not a quotation**
  (LRN-2): `--check` now requires every LOOK FOR line that begins like a
  transcript line to appear verbatim in some `machines/*.expected`,
  whitespace normalised. Twenty-three did not, across four lessons --
  trimmed prefixes, dropped paths, a word capitalised for emphasis
  INSIDE the quotation. Wrap it, elide it visibly with `...`, or put the
  emphasis in the prose. A BREAK IT's `expect` is exempt by
  construction: it is what the reader sees after changing the machine,
  so it is verified by RUNNING it and nothing else can.
- **Fixtures are the judge**; re-pin `declarative/machine/PINNING.md`
  (sha256) in the same commit that changes `fixtures.json`. Every
  reject carries the fragment its refusal must contain.
- **A generated artifact is judged by what CONSUMES it**, never by a
  diff against the same generator's earlier output: both sides can be
  wrong in the same way and the court stays green (PRJ-2, where a diff
  passed a file Ring could not parse).
- **The machine judges its own boot** (JDG-1): a trial commits only on a
  match, and no expectation is no commit. Each judged line is worded
  ONCE in `src/expect.zig` -- never reword one side. The emulator's
  lacks are a `Lens` per board, never a loosened comparison.
- **A PIN is not a record of what happened, it is a claim that what
  happened was RIGHT** (SYS-1): never copy a transcript over its
  expectation without reading the diff. Doing it blindly pinned four
  machines -- three whose worlds a new filter had broken, one whose
  filter had silently failed while the boot judged itself a match.
- **Assert the mechanism**: the court was probed with a mutated judge in
  fresh processes (wrong count, wrong fragment, valid source posing as
  reject -> three reds) before its scoreboard was written. **A test
  named for a property must ASSERT that property** (JRN-2): the journal's
  "an altered entry is named by its position" checked only `broken_at !=
  null`, and tampered with a whole-text replace that hit entry one as
  well -- so it broke at 1 while the name said 2, and passed. When a
  test's name, its comment and its assertions disagree, the assertions
  are what runs.
- **A verdict that does not reach the EXIT CODE only convicts someone who
  is WATCHING** (VDCT-1): `os2_image.sh`, `os6_names.sh` and
  `os7_fleet.sh` each ended `} | tee "$LOG"`, and a pipeline exits with
  its LAST command's status -- so all three printed `JUDGED: FAIL` with
  a diff and returned 0, as did every `exit 1` inside those blocks (a
  failed kernel build, a missing cross binary, a refused derive).
  `exit "${PIPESTATUS[0]}"`; never let `tee` answer for the run. Probed
  both ways on all three -- broken pin exits 1, clean pin exits 0 --
  because a judge that always convicts is as useless as one that never
  does. `judge_guarantees.sh` was already right and is the shape.
  **A verdict must be RETURNED and RECEIVED; either alone is decoration**
  (NAM-2): `os6_names.sh` captured `harb fleet ... hardware` and tested
  whether the answer was EMPTY. A refused fleet prints its refusal on
  STDOUT and exits 1, so the guard passed, a whole sentence became a MAC,
  and the run failed two minutes later with a symptom. `if ! VAR=$(...)`.
  When a caller tests the CONTENT of an answer, ask what that variable
  holds when the thing that produced it refused.
- **A promise the machine ANNOUNCES and cannot keep is worse than one it
  never made** (NS-1): when the mechanism behind a declared guarantee
  fails, refuse the act and say so. PID 1 does not start a world whose
  envelope the kernel could not build; the boot then differs from its
  expectation and a trial holds.
- **Ask the question that DECIDES, not the one next to it** (MNT-1): the
  witness is part of the evidence. `access()` on a detached mount
  answers about the empty directory left behind, and reported a kept
  promise as broken. A witness answering an adjacent question gives the
  wrong verdict with full confidence.
- **A witness must not damage the machine in the case where the guard it
  tests has FAILED** (SYS-1): the floor's witness tries `unshare`, whose
  worst case is a world getting a namespace it does not need, never
  `reboot`.
- **When a question cannot be ANSWERED, check whether it is the right
  question** (THR-1): "whose thread is this" has no answer at the kernel,
  so `threads` is read and never enforced here; "how many tasks will
  this machine hold" has an exact one. The capability asks who asked and
  belongs to the runtime; the budget asks how many and belongs to the
  kernel.
- **When a policy grows a DIMENSION, grep every condition that
  enumerates the old ones** (THR-1): a join that ran only for MEMORY or
  CPU left the first TASKS world outside the group its ceiling was
  written on. Third guard in two days narrower than the thing it
  guarded.
- **Derive while the declaration already knows; add a CLAUSE when it
  does not** (SEE-1): four envelope seats came out of `NEEDS` with no
  new grammar. Which mounts a world keeps was in no clause, so `SEES`
  was added rather than derived from a proxy -- which would be a guess
  wearing a derivation's clothes.
- **The envelope is DERIVED from NEEDS, never declared** (NS-1): what a
  world did not ask for, the kernel does not give it. A claim that would
  be EMPTY is not made -- a machine with no declared network confines
  nobody off one, and `CONFIG_NET_NS` cannot be built without
  `CONFIG_NET`.
- **Some things are refused by what a world IS, not by what it
  declared** (SYS-1): the calls that would let a world change the machine
  it runs on are refused to EVERY world, whatever its NEEDS. When no
  declaration should ever ask for something, do not add a clause that
  could grant it. It is a named closed DENY list, never a claim that
  everything else is safe.
- **A namespace the caller does not ENTER is a namespace nobody is in**
  (PID-1): `unshare` makes the caller's CHILDREN the inhabitants, so a
  world that unshared and exec'd would still stand in the old one. Check
  which side of an `unshare` the guarantee lands on; a stand-in process
  must carry the world's exit or signal back unchanged.
- **A mount namespace is made PRIVATE before anything is detached**
  (MNT-1): without `MS_REC | MS_PRIVATE` the umounts propagate back and
  one confined world takes the storage from every other world and from
  PID 1. Isolation that shares propagation is a way to break the box
  from inside a world.
- **A budget is the KERNEL's to hold** (BDG-1, THR-1): `MEMORY`, `CPU`
  and `TASKS` become a cgroup per world -- memory kills, cpu throttles,
  tasks refuse with EAGAIN. A machine that declares no budget mounts no
  cgroup filesystem and asks for no controller.
- **Alive is not serving** (HLT-1): a world with `HEALTH` must refresh
  its READY path within every window, and PID 1 feeds the watchdog only
  while every such world is fresh. Staleness LATCHES -- never resume the
  feed on recovery, or the watchdog guards nothing.
- **A daemon never exits, so an init that waits for an exit learns
  nothing more** (SRV-1): PID 1 POLLS while anything is owed and never
  blocks on `wait4` on a served machine. A world's READY path is its
  LAST act. `--halt-on-verdict` is DERIVED onto the emulator's boot line
  only; the card's cmdline.txt never carries it.
- **A transcript whose order depends on which process reaches the
  console first is a margin, not a fixture** (BDG-1): a world is forked
  HELD at a gate and released only after PID 1 has spoken. ONE spawn
  path for every world, with or without a declared USER. Never widen the
  judge's normalisation to hide an ordering race -- close the race.
- **Evidence is what the machine said about THIS boot, never what it
  quoted about another** (GRT-1): a transcript carries other boots and
  PID 1's own quotations of lines it did NOT say, so a judge that
  searches the whole text finds the words it wants inside the sentence
  that denies them.
- **A record is the FLOOR's or a world's, never both** (JRN-1): the
  machine's journal says what the machine was and what it judged of
  itself; what a business record IS belongs to the world that keeps it.
  Verify a chain BEFORE extending it and never extend a broken one.
  Inalterability is that a change cannot go unnoticed, not that a file
  cannot be changed; claim the first and never the second.
- **A device's name is its KEY, and it must survive the power** (IDN-1):
  `IDENTITY` must sit inside a declared persistent mount, or the box is
  a new device every morning. The transcript SAYS the algorithm and the
  custody rather than implying them. The judge maps each DISTINCT
  fingerprint to `KEY1`, `KEY2`, … -- never to a constant, which would
  hide the claim that a card keeps its key.
- **A claim only its author can check is not evidence** (FLT-1): the
  floor holds the secret, the fleet holds the public half anyone may
  check, and the two never meet in one place. Enrolment stays MANUAL --
  a fleet that enrolled whatever key answered would attribute records to
  whatever device was plugged in -- and a member with no key is
  REPORTED, never guessed at.
- **Some facts are about a SET and belong in a file about a set**
  (FLT-1): two boxes that each serve `makeen` are each faultless and
  together they are a broken network. One language, two files, and a
  file is judged by which kinds it may contain.
- **A fact about a DEPLOYMENT lives in a declaration, or it is not a
  fact anyone can check** (HDW-1): when one turns up in a script, move
  it and DELETE the constant -- never a second place that has to agree.
  A machine file is a design that images many devices, so facts about
  ONE of them belong on a fleet member.
- **A machine that SERVES a link is not finished when its services are**
  (NAM-1): serving is a state of the machine, not a task that completes.
  A server declares who it serves -- no pool, no range, the declaration
  IS the register, which is why it cannot be lost at a reboot. Never
  send an option the machine cannot honour, and never answer for a name
  the link does not own.
- **A reach is the declaration's to say** (EGR-1): `EGRESS` writes the
  routing table. Say precisely what that is and is not -- the machine
  knows no way there; it is not prevented from finding one. A packet
  filter is a named seam, never claimed.
- **A sentence worded for one case and printed for two is a lie in the
  second** (EGR-2): `egressLine` appended "and nowhere else: no default
  route" to every declared destination list, so `EGRESS ["0.0.0.0/0"]`
  -- which installs exactly what `unrestricted` installs -- announced a
  perimeter while the witness four lines down reached 8.8.8.8. NS-1 with
  the sign flipped: the mechanism obeyed and the SENTENCE lied, in the
  direction that reassures. When a branch grows a value it was not
  written for, re-read what it prints. Whether the grammar should REFUSE
  the explicit spelling is the author's ruling and is left open; that
  `boot: network` names the gateway for one branch and not the other is
  a named seam, not widened.
- **Closed grammars have no host escape.** A shell is refused by name in
  RUN; do not add a command-string form, an env-expansion, a hook.
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
  Redirect `harb ... > file` and the writer starts at offset 0,
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
- **One kernel SOURCE tree per arch, one BUILD directory per CONFIG**
  (KCACHE-1): `$K/src/<arch>` extracted once, `$K/build/<arch>-<frag
  sha>` built out-of-tree with `make O=`. Every machine asks for a
  different kernel, so a single build directory per arch meant each
  machine rebuilt what the one before it had just built -- 1m16, 1m31,
  2m07, then SIX SECONDS for the one machine that happened to follow
  another wanting the same config. The boot log says HIT or MISS. The
  old dirty `$K/<arch>` trees are superseded and can be deleted; `make
  O=` refuses a tree that was ever built in.
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
  boot line carries `harb.watchdog=off` (derived; never the card's
  cmdline.txt) and PID 1 flushes before arming. A boot that ends
  silently right after the capability lines is this.
- **mtools asks on stdin when a name clashes** (`mmd` on an existing
  directory, `mcopy` over a file): on a pipe that never closes it hangs
  forever (33 minutes, AB-1). Every mtools call runs with `-D s`/`-D o`
  and `< /dev/null`; `wsl_cleanup.sh` ends a stuck one.
- **A heredoc body is not part of an `&&` chain, and the line after the
  terminator is a NEW command.** `A && python3 - <<PY` runs the chain on
  its own line; everything after the terminator runs UNCONDITIONALLY,
  with `$?` still showing the chain's failure, so a guarded script that
  refused to run is followed by a `git add` that runs anyway on the full
  file. Probed (`experiment/heredoc_probe.sh`): a command
  on the same line as the redirect is correctly skipped; one on the next
  line is not. Cost two sessions one wrong commit each on 2026-09-14 --
  stzlib-graphics staged a file its own assertion had just refused, and
  committed another desk's memo under its subject. Put the program in a
  FILE and `&&` the file.
- **Never put a program inline in a shell argument. Write it to the
  scratchpad with the file tool and run it by path.** Three different
  ways it has been eaten on 2026-09-14 alone:
  - `\\` inside a heredoc becomes a real newline even with a quoted
    terminator (`<<'PY'`), so a Python replacement carrying a Zig
    `"...\n"` arrives as a string literal with a line break in it and
    Zig refuses it ("string literal contains invalid byte"). Twice.
  - ```backticks``` inside a double-quoted `python3 -c "..."` are COMMAND
    SUBSTITUTION: the shell runs them and splices the (empty) output in,
    so a markdown table lost four words to "command not found" and the
    edit still reported success. Build them from `chr(96)` if they must
    be inline.
  - a one-line `bash -c` through `wsl.exe` loses `$` and `&`.
  The scratchpad file has none of these failure modes and is the
  standing fix; reach for it FIRST, not after the second repair. Every
  WSL act is likewise a script file under `experiment/`, never a
  one-liner sent through `wsl.exe`.
- **QEMU under `timeout` from a real terminal STOPS silently.** With a
  tty on stdin, `-nographic` sets raw mode; in `timeout`'s background
  process group that is SIGTTOU, and QEMU sits stopped until the timeout
  kills it -- the author's first run showed nothing for three minutes.
  `os2_image.sh` now runs QEMU with stdin from /dev/null under `timeout
  --foreground`, streams its log to the terminal through `tee`, and
  `experiment/os2_tty_probe.sh` proves it under a pseudo-terminal (22 s).
  `experiment/wsl_cleanup.sh` ends what a closed terminal left behind.
- **Python's `read_text()` is not a faithful read** (RET-1): it opens in
  universal-newline mode and turns a lone CR into LF. The rename's
  script read `sed -e 's/<CR>$//'` in `os2_image.sh` and wrote back a
  sed command split over two lines; it failed silently inside a
  pipeline, and every non-SD JOURNAL machine's second boot vanished from
  its transcript for a week. Never put a literal control byte in a
  script -- write `\r` -- and edit a file you have not checked for CR in
  bytes (`read_bytes`), or open it with `newline=''`.
- **Invoke WSL scripts from PowerShell, never from the Bash tool** —
  git-bash rewrites `/mnt/d/...` into `C:/Git/mnt/...`
  (`MSYS_NO_PATHCONV=1 wsl.exe ...` is the workaround if you must).

## Next steps (author-ordered, one per session)

- **OS-5 — the card meets the board. PARKED** on the author's word
  (2026-09-26: plan it for later, advance on other fronts) until the
  hardware exists. PREPARED and rehearsed (OS-5-PREP): one script,
  `experiment/os5_board.sh`, four acts (`card`, `listen <dev> [s]`,
  `judge <file>`, `rehearse`) and three judges on one boot (the board's
  own verdict, `harb judge`, the four promises). **When the hardware
  arrives, take it in this order** -- steps 2 and 3 were found on
  2026-09-26 and are why the order matters:
  1. **The kit.** `STZ-OS-HARDWARE-01` names a Pi 4 Model B, a micro-SD
     card and a 3.3 V USB-serial adapter (3.3 V, never 5 V: the Pi's
     GPIO is 3.3 V). It does not name what a first boot also needs and a
     desk may not have: the Pi 4's USB-C supply (5.1 V, 3 A) and a way
     to write a micro-SD card from this PC.
  2. ~~**Rebuild the card before anything reads it.**~~ **Done
     2026-09-27** (EGR-3): `makeen_box` was booted to settle its pin and
     the card was rebuilt with it -- `harb.slot=A rdinit=/harb`. What
     follows is why it mattered, and why step 3 still stands. The image in
     `zig-out/image/makeen_box/` had been built 2026-09-15, before the
     rename, and its boot line said `stzos.slot=A rdinit=/stzos`.
     Flashed as it is, the three judges SPLIT: the board judges itself
     against the stale `/etc/expected` it carries and passes, `harb
     judge` derives from today's source and fails, and the first real
     boot is spent diagnosing a build date.
  3. **Then make `card` refuse a stale card**, because step 2 is a
     person remembering. Its clean-boot-line guard matches instruments
     by their CURRENT spelling (`harb.watchdog=off`, `harb.expect=`), so
     a card carrying `stzos.watchdog=off` passes it -- NAME-1 one layer
     down. The question that decides is whether the card was built from
     these sources: judge the card's own `expected` against a fresh
     derive, and refuse on any difference.
  4. **Close "hardware declared, never observed"** (the fleet grammar's
     own named seam) before the first boot, so the board is judged on it
     too. In the emulator QEMU is HANDED the member's declared MAC, so
     declared and actual agree by construction; a board's NIC has its
     address burned in. Build the witness that reads the address the
     device actually has, and probe it on the x86 till by handing QEMU a
     MAC the member does not declare -- it must refuse.
  5. **Then the board**: `card`, flash (the author runs the command the
     script prints -- it never writes to a device), `listen
     /dev/ttyUSB0 120`, `judge <file>`. It should differ from the
     emulator on exactly the two lines the build prints as the
     emulator's lacks; the watchdog's real countdown and the tryboot
     flag (a vendored patch to `bcm2835_wdt.c`) are the two things only
     a board can show.
- **Do not reopen ZIGCC-1** without a newer zig or an LLVM-shaped
  attempt: behind `HARB_CC=zigcc` the kernel builds with `make CC="zig
  cc"` and the image does NOT boot (it dies in the 16-bit setup code).
  gcc stays; the instrument and its six probes are kept.
- **Open seams, none blocking.** A trusted CLOCK (the journal carries no
  timestamp because the board has no clock, and a box with `EGRESS none`
  cannot ask the network -- where the trust comes from was the author's
  ruling -- ruled 2026-09-27, STZ-OS-RULING-07: attested by a declared
  time authority, never assumed; the seat is not built). ~~REVOCATION in
  a fleet~~ -- built as RETIREMENT (RET-1);
  what remains is retiring the RECORDS a retired card signed. Hardware
  DECLARED but never observed (in the OS-5 plan, step 4). Forwarding
  between two links. A bounded window for the TRIAL itself. The Commons
  as the first declared server world. Haro's runtime as the image's
  second binary. `makeen_box` gets its own `DOMAIN` at OS-5, when there
  is a NIC to serve.
- **Waiting on the author.** Delegated 2026-09-27 ("do what waits on me
  on my behalf") and ruled in `doc/PROVENANCE.md` as STZ-OS-RULING-03..08:
  retirement's three choices, the MIRROR (a private release, restored
  and verified), the LICENCE (MIT, the estate's), EGRESS (everywhere has
  one spelling), the CLOCK (time is attested, never assumed -- the seat
  is not built), and chapter 07 ratified. What still waits on him, and
  why no delegation reaches it: ~~one word for 06 -- X or A~~ **ruled A
  by the author, 2026-09-27**, and ~~ratifying 06~~ **ratified by him as
  drafted** the same day, and **08 ratified by him** too. The ZQL -> Z
  go did NOT reach Central through a CONCLUSIONS line -- a log it records,
  not a queue it routes -- and this desk is NOT IN `protocol/REPOS.md`, so
  Central cannot see it: relayed to Central's live session directly
  (2026-09-27 05:49) with the author's go to route it and to adopt this desk; the Pi kit, a purchase; and
  ~~PUBLISHING~~ -- **published 2026-09-27 on his word**: the
  commit history keeps his address as author (his choice; this repo's
  future commits use his GitHub noreply address), and the firmware's
  licence was attached to the mirror before the mirror went public.
- **What is built, and where its story is.** Every seat is written up in
  `experiment/PROTOCOL.md`, newest first, under the tag its doctrine
  line carries: EGR-3, RET-1, PIN-1, NAME-1, LRN-2, NAM-2, JRN-2, EGR-2, VDCT-1, LRN-1, THR-1, SEE-1, KCACHE-1, SYS-1, PID-1, MNT-1, NS-1,
  HDW-1, FLT-1, NAM-1, JRN-1, IDN-1, EGR-1, GRT-1, BDG-1, HLT-1, SRV-1,
  JDG-1, AB-1, PRJ-1/2, USR-1, RDY-1, NET-1 and OS-1..5. The two
  grammars and their pins are `declarative/machine/` and
  `declarative/fleet/`.
