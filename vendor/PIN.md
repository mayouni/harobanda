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
| config | `tinyconfig` + the fragment `stzos image` derives per machine (`kernel.fragment`); no modules |
| compiler | gcc from WSL Ubuntu for the first boot; `make CC="zig cc"` is the stated destination and untested |

Changing the pin means changing this file, `os2_kernel_fetch.sh`'s
version pattern, and the first boot transcript in the same commit.
