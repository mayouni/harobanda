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

| what | value |
|---|---|
| tarball | `linux-6.12.109.tar.xz` |
| sha256 | `5484e552a334e15019f4aeba89e5b58f04651cf2f4e24e04de9f152f1c38e3fa` |
| source of the digest | `https://cdn.kernel.org/pub/linux/kernel/v6.x/sha256sums.asc`, fetched 2026-09-12 |
| licence | GPL-2.0 (the kernel's own `COPYING`); the image ships the kernel unmodified, built from this source |
| config | `tinyconfig` + the fragment `harb image` derives per machine (`kernel.fragment`); no modules |
| compiler | gcc from WSL Ubuntu for the first boot; `make CC="zig cc"` is the stated destination and untested |

Changing the pin means changing this file, `os2_kernel_fetch.sh`'s
version pattern, and the first boot transcript in the same commit.

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

## What is NOT pinned: availability

A digest makes a tarball's CONTENT sovereign, not its EXISTENCE. Both
tarballs are fetched from their upstream and would have to be fetched
again on a new machine. An estate mirror is a routed errand for the
author (the kernel's 148 MB exceeds a git file limit, so it needs
storage he picks); until then the honest statement is: integrity ours,
availability theirs.
