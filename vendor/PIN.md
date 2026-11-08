# vendor — pinned by digest

The hosted profile's kernel is Linux LTS, vendored BY DIGEST: the tarball
is larger than GitHub's per-file limit, so the source itself stays out of
the repository and lives in `vendor/linux/` (gitignored) beside this pin.
`experiment/os2_kernel_fetch.sh` fetches kernel.org's own `sha256sums.asc`,
takes the newest 6.12 point release, verifies the tarball against that
digest, and refuses a mismatch; `vendor/linux/PIN.txt` records what it
took. The sovereignty verdict is "keep vendored, rebuilt by our
toolchain" (`doc/ARCHITECTURE.md` §3); a mirror of the tarball inside the
estate, so that even kernel.org cannot withdraw it, is the next step of
that verdict and is not done.

*Amended 2026-09-27 (DOC-1).* The fetch now takes exactly the tarball
this file names, and refuses unless kernel.org's digest and this file's
agree. "The newest 6.12 point release" was a different kernel on every
day after the pin, and a fresh clone -- which has only this file -- was
re-pinned by it without a word, in a gitignored `PIN.txt` nobody reads.
It extracts nothing any more either: `os2_image.sh` extracts where it
builds. It reads the `tarball` and `sha256` rows of the table below, so
their shape is load-bearing; `experiment/kernel_fetch_probe.sh` judges it
both ways (the pin fetched and verified; a wrong digest, an unreleased
version and a tarball that is not the pinned one, each refused).

| what | value |
|---|---|
| tarball | `linux-6.12.115.tar.xz` |
| sha256 | `0ec90fe4b20422b1b664b77e6d2dde22b40bd41e7eb2cad8ac8739a4749cb1bb` |
| source of the digest | `https://cdn.kernel.org/pub/linux/kernel/v6.x/sha256sums.asc`, fetched 2026-11-05 |
| licence | GPL-2.0 (the kernel's own `COPYING`); the image ships the kernel unmodified, built from this source |
| config | `tinyconfig` + the fragment `harb image` derives per machine (`kernel.fragment`); no modules |
| compiler | gcc from WSL Ubuntu for the first boot; `make CC="zig cc"` is the stated destination and untested |

*Amended 2026-11-05 (TCPUAF-1, HAROBANDA-TCPUAF-01).* The pin moved
from `linux-6.12.109` (sha256 `5484e552...e3fa`, fetched 2026-09-12) to
`linux-6.12.115`, the newest 6.12 longterm release on that day (released
2026-10-30), because 6.12.109 predates the fix for CVE-2026-98432: a
use-after-free of a socket's IP options in IPv4 TCP connection setup,
reachable from the network without authentication, and built into every
machine here that declares a network (`CONFIG_INET`, `src/image.zig`). The
fix ("ipv4: free inet_opt and ireq_opt after an RCU grace period") is
first in 6.12.113: OSV's record for the CVE says so, and so does
kernel.org's `ChangeLog-6.12.113` -- and no other changelog from 110 to
115 -- read on 2026-11-05. The finding was stzlib-security's; the release
was checked here, not taken from the report.

**The rule for moving the pin** (it was never written, and a pin with no
rule for moving it reproduces a vulnerable kernel faithfully): the pin
moves to a newer 6.12 point release when a fix in it reaches a
configuration this repository can build -- the kernel's own advisory, read
against what `harb image` derives -- and in the same commit every pinned
boot is re-run against its pin and every reference image is rebuilt.
Nobody watches the advisories for this desk yet: until something does
(`harb advisories`, HAROBANDA-ONEHOUR-01, not built), a move happens when
a reading like stzlib-security's reaches the mailbox.

*Amended 2026-11-08 (ONEHOUR-1).* `harb advisories <machine> <records>`
is built: it reads the kernel's own CVE records against the release
this pin names and the source files a machine's kernel compiled
(`kernel.sources`, written by `os2_image.sh` beside the image), and
says which reach that machine -- the reading this rule asks for, made
by a program. What is still a person's act is BRINGING the records:
nothing on this desk fetches them, on a schedule or otherwise, so
"who watches" is whoever runs the verb over the records they brought,
and "how fast" is how often they do.

Changing the pin means changing this file, `os2_kernel_fetch.sh`'s
version pattern, and the first boot transcript in the same commit.
*(Amended 2026-09-27: the fetch has no version pattern now -- it reads
the two rows above -- so changing the pin is changing those rows, and
re-judging every boot against its pin in the same commit.)*

## The Linux Zig, pinned the same way (ZIGCC-1)

`experiment/zigcc_fetch.sh` fetches the Linux zig toolchain once and
verifies it before anything runs; `vendor/zig/PIN.txt` records what it
took. It exists for the experiment of building the kernel with our own
compiler, which today builds but does not boot (`experiment/PROTOCOL.md`,
ZIGCC-1); nothing in the shipped images depends on it.

| what | value |
|---|---|
| tarball | `zig-x86_64-linux-0.15.2.tar.xz` |
| sha256 | `02aa270f183da276e5b5920b1dac44a63f1a49e55050ebde3aecc9eb82f93239` |
| source of the digest | ziglang.org's own `download/index.json`, fetched 2026-09-12 |
| version | 0.15.2, the same the Windows toolchain builds `harb` with; its C front end reports clang 20.1.2 |

## The Windows Zig, pinned the same way (the source mirror)

The compiler that builds `harb` itself -- every binary this repository
ships, the CLI and PID 1 alike -- is the Windows Zig in `D:\Zig` on this
desk, 0.15.2. It was installed and never pinned; the source mirror's seat
pinned it, fetched the official archive once and found its `zig.exe`
byte-identical to the installed one (sha256 `d408dd38...c018`, both).

| what | value |
|---|---|
| archive | `zig-x86_64-windows-0.15.2.zip` |
| sha256 | `3a0ed1e8799a2f8ce2a6e6290a9ff22e6906f8227865911fb7ddedc3cc14cb0c` |
| source of the digest | ziglang.org's own `download/index.json`, fetched 2026-11-08 |
| licence | MIT (Zig's own `LICENSE`, in the archive), and the licences of what it bundles, listed in the archive |

## The Pi firmware, pinned by tag and digest (the source mirror)

The board's two firmware files, read by `os2_image.sh` for an SD card.
Until 2026-11-08 they were fetched from the NEWEST release of
`raspberrypi/firmware` on the day of the first fetch and the digests
written only into a gitignored `PIN.txt`, so a fresh clone took whatever
was newest that day -- DOC-1's defect, one table over. The fetch now
takes exactly this tag and refuses files whose digests are not these.

| what | value |
|---|---|
| tag | `1.20260907` |
| start4.elf sha256 | `43a5993684a46a65280d128ce9b8c68bcde1e83e2e5791c9bb0271e4a2aa0e39` |
| fixup4.dat sha256 | `f5e57d4f49d8eaf5381e0f83b0171f03a938931fc6c79f36a93df0d67910a098` |
| LICENCE.broadcom sha256 | `c7283ff51f863d93a275c66e3b4cb08021a5dd4d8c1e7acc47d872fbe52d3d6b` |
| source | `https://raw.githubusercontent.com/raspberrypi/firmware/<tag>/boot/<file>` |
| licence | Broadcom's redistribution licence, `LICENCE.broadcom`, which travels with the files |

## RingServ, pinned by SOURCE (SRV-2)

The first real server a pack places (`machines/ringserv.pack`) is RingServ,
the application server of the estate, built from its own repository and
staged by `machines/ringserv.stage`. Unlike the two above it is pinned by
the git ref of its SOURCE and not by a digest of what is built, because the
build is not byte-reproducible across folders: two builds of this ref in two
folders differ by 160 bytes (24,313,280 and 24,313,440; measured 2026-10-04).
In the same folder it is: `experiment/ringserv_build.ps1` builds in a fixed
one, and a rebuild there gave the same digest.

| what | value |
|---|---|
| source | `https://github.com/mayouni/ringserv.git` (public) |
| ref | `002ba2126bb78681b2aae40e365dd19385ca4d9f`, origin/main on 2026-10-04, committed 2026-08-29: "Write down the data-and-compute position, and put it on the front page" |
| what was read | that ref only, through git objects. The ringserv working tree holds uncommitted work of its own desk and was not read or touched (CENTRAL-READONLYPIN-01) |
| built with | `zig build -j2 -Dtarget=x86_64-linux-musl`, Zig 0.15.2, ReleaseFast (RingServ's default): one static x86-64 ELF with no interpreter, 24,313,280 bytes, sha256 `d172da3e7471675ac8f2d4895bc7b017879606d6278480ae45ab0bce03829e69` in `zig-out/ringserv/src` (for the record, not the pin) |
| reports itself as | `RingServ 0.9.0 (Ring 1.27, resident, ReleaseFast)`, vendored SQLite 3.53.4 |
| licence | MIT (RingServ's own `LICENSE`); the binary is not committed here and not redistributed |

*Amended 2026-11-08 (the source mirror).* The source is mirrored as a git
bundle of this ref, `ringserv-002ba212.bundle`, made from a scratch clone
of the ringserv repository's objects (its working tree not read) with one
branch, `ringserv-pin`, at the ref. `git clone <bundle> -b ringserv-pin`
gives the ref back, and `ringserv_build.ps1 -Source <bundle>` builds from
it. A bundle's bytes are not the pin -- the ref is -- so its digest is
recorded in the mirror's `SHA256SUMS` and not here. RingServ declares no
fetched packages (no `build.zig.zon` at this ref), so its build needs
nothing else from the network.

Changing the pin means changing the `$Ref` in `experiment/ringserv_build.ps1`,
this table, and the pinned boot `machines/qemu_cloud_ringserv.expected` in the
same commit, because that transcript quotes the server's own banner line.

## Caddy, pinned by DIGEST (FRONT-1)

The proxy that terminates TLS in front of a cloud (STZ-OS-RULING-18): the
estate's rule is that no repository vendors a TLS or crypto stack, so the
front is a program placed by a pack (`machines/front.pack`), and the
program is Caddy, one static binary that manages its own certificates.
Pinned the way the kernel is: the release archive is fetched by
`experiment/caddy_fetch.sh`, refused unless its digest is the one below,
and the `caddy` binary inside it is staged by `machines/front.stage`;
`vendor/caddy/` keeps the archive and `PIN.txt` (gitignored). Caddy
publishes sha512 beside its releases, so the pin is sha512 and the fetch
reads the `tarball` and `sha512` rows of this table: their shape is
load-bearing.

| what | value |
|---|---|
| tarball | `caddy_2.11.7_linux_amd64.tar.gz` |
| sha512 | `a7a433a1b133efc3c8d10eb0b99d52a24b5ef5c322dc77f5282182b1c0402139ab83f3a99f0c52409df77d20123fb0b523edad8a66d8f5e49136197bf61ef0e7` |
| source of the digest | `https://github.com/caddyserver/caddy/releases/download/v2.11.7/caddy_2.11.7_checksums.txt`, fetched 2026-10-19; the release is dated 2026-10-03 |
| version | 2.11.7, the newest release on the day of the pin |
| licence | Apache-2.0 (Caddy's own `LICENSE`); the binary is not committed here and not redistributed |

Changing the pin means changing the two rows above and the pinned boot
of the front in the same commit.

## What is NOT pinned: availability

A digest makes a tarball's CONTENT sovereign, not its EXISTENCE. Both
tarballs are fetched from their upstream and would have to be fetched
again on a new machine. An estate mirror was a routed errand for the
author (the kernel's 148 MB exceeds a git file limit, so it needed
storage he picks); until then the honest statement was: integrity ours,
availability theirs.

**Mirrored 2026-09-27 (STZ-OS-RULING-04).** Every file above, and the Pi
firmware with its licence (`LICENCE.broadcom`, fetched from the same tag
as the firmware, 1,594 bytes, sha256 `c7283ff5...`), is a release asset of
this repository -- public since the repository is, and the licence was
attached before it was, because redistributing the firmware requires its
notice to travel with it:

    gh release download vendor-mirror-2026-09-27 -R mayouni/harobanda
    sha256sum -c SHA256SUMS

Each was verified against its pin before upload, and the mirror was
judged by a RESTORE -- downloaded whole, every digest checked, the two
tarballs against the pins in this file. The pins here stay the
authority; the mirror carries a copy of them so it can be checked on its
own. Integrity ours, availability ours, for as long as the account is.

*Amended 2026-11-08 (the source mirror, STZ-OS-RULING-19's last item, on
the author's "go (a)").* The 2026-09-27 mirror had fallen behind its own
pins: it held `linux-6.12.109` when the pin had moved to 6.12.115, and it
never held Caddy, RingServ or the Windows Zig. It is kept as it was, a
record of that day. The mirror is now `vendor-mirror-2026-11-08`, made by
`experiment/mirror_make.sh`, which takes every file from `vendor/`,
checks each against THIS file before it is staged, and writes `SHA256SUMS`
and `MIRROR.txt` (what each file is, which pin judges it, its licence):
the kernel, the Linux and the Windows Zig, Caddy, RingServ's bundle, and
the Pi firmware with its licence. Every fetch script takes `HARB_MIRROR=
<dir>` -- a restored mirror -- and then copies from it and asks the
network nothing (`os2_kernel_fetch.sh` does not consult kernel.org then:
the pin is the judge). It is judged by `experiment/mirror_restore.sh`:
the release downloaded whole into an empty directory, every digest
checked, and then, with the network taken away (a namespace with no
interface but loopback), a copy of what this repository publishes is
given every file from the restore alone, builds `harb` with the restored
Zig, builds the kernel from the restored tarball and boots `qemu_egress`
against its pin, and builds RingServ from the bundle. A move of any pin
above is a new mirror, made the same day.

**Not mirrored, and named: the host's build tools.** The kernel is built
with gcc, make, flex, bison and bc, and booted by QEMU -- Ubuntu's
packages, installed by `experiment/os2_env.sh` and pinned by nothing
here. Mirroring their compiled packages publicly is a redistribution of
GPL binaries, which owes their source beside them. **Ruled by the author
2026-11-08: "(b) leave them out and say so."** So they stay out, and this
is the saying: a cloud rebuilt from this mirror alone still needs an
Ubuntu archive for those tools, and the toolchain this mirror carries is
the one that builds `harb` and RingServ (Zig), not the one that builds the
kernel (gcc).
