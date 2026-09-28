# What the licence covers, and what it does not

The licence is [`LICENSE`](LICENSE): MIT, © 2026 Mansour Ayouni. These
notes stood at the end of that file until 2026-09-28, and moved here so
that the file is the MIT text alone -- which is what lets GitHub
recognise it as MIT. The terms did not change.

It covers this repository: the machine language, the court, the one
binary (`harb`), the scripts, the documents and the site.

It does not cover what a machine is BUILT FROM. Those are fetched from
their upstream and pinned by digest in [`vendor/PIN.md`](vendor/PIN.md);
none of them is committed:

| what a machine is built from | its licence |
|---|---|
| Linux 6.12 LTS | GPL-2.0, the kernel's own `COPYING` |
| the Linux Zig toolchain | MIT, the Zig authors |
| Raspberry Pi firmware | its binary licence, `LICENCE.broadcom` -- redistribution must carry that notice with the files |

An IMAGE that `harb image` builds contains the Linux kernel.
Distributing such an image carries the kernel's GPL-2.0 obligations --
chiefly, that its source is available -- whatever licence this
repository's own code is under. The source it was built from is the
digest-pinned tarball named in [`vendor/PIN.md`](vendor/PIN.md).
Likewise a CARD image for the Raspberry Pi carries the Pi's firmware,
and distributing one carries that firmware's licence: its notice,
`LICENCE.broadcom`, travels with the card.

The site's fonts, under `site/diagrams/fonts/`, are IBM Plex, under the
SIL Open Font License 1.1
([`site/diagrams/fonts/LICENSE-IBM-Plex.txt`](site/diagrams/fonts/LICENSE-IBM-Plex.txt)).
